#pragma once
#include "checkpoint.hpp"
#include "input.hpp"
#include "solver.hpp"
using Clock = std::chrono::steady_clock;
struct Engine {
    fs::path out;
    std::ofstream trace;
    Json metadata, status = {{"graph", false},
                             {"scales", false},
                             {"affinity", false},
                             {"complete", false},
                             {"error", nullptr}};
    Mat D, D2;
    Edges edges;
    Ids deg;
    Vec upper;
    double scl = 1, C = 0;
    int iteration = 0, solves = 0;
    bool cache = false;
    std::string phase = "initial", inject;
    Engine(fs::path folder, std::string injection)
        : out(folder), trace(folder / "trace.jsonl"), inject(injection) {}
    void emit(Json event) {
        event["iteration"] = iteration;
        event["phase"] = phase;
        trace << event.dump() << '\n';
        trace.flush();
        require(bool(trace), "trace_write");
    }
    Json graph_data() {
        return Json{{"edges", edges},
                    {"degrees", deg},
                    {"upper", upper},
                    {"components", components(D.size(), edges)},
                    {"isolates", isolates(deg)}};
    }
    void checkpoint(const std::string &stage, Json data) {
        for (auto it = metadata.begin(); it != metadata.end(); ++it)
            data[it.key()] = it.value();
        data["stage"] = stage;
        data["status"] = "validated";
        auto path = out / (stage + ".json");
        require(!fs::exists(path), "checkpoint_exists");
        atomic_json(path, data);
        status[stage] = true;
        status[stage + "_sha256"] = file_hash(path);
        atomic_json(out / "status.json", status);
    }
    Vec solve(bool parameterized) {
        auto r =
            solve_lp(D, edges, upper, C, parameterized, inject == "invalid_solver" && solves == 0);
        r.record["number"] = solves++;
        emit(r.record);
        require(r.record["accepted"].get<bool>(), "invalid_solver_result");
        return r.x;
    }
    Mat kernel(const Vec &s) {
        Mat K = affinity(D2, s, deg);
        emit(Json{{"event", "kernel"}, {"affinity", K}, {"scales", s}});
        return K;
    }
    Vec volume(const Vec &s, const Mat *K) {
        Vec v = volumes(D2, s, deg, K);
        emit(Json{{"event", "volume"},
                  {"ratios", v},
                  {"scales", s},
                  {"degrees", deg},
                  {"multiscale", K != nullptr}});
        return v;
    }
    // Retuning uses the original fresh/recycled expression order and stop rules.
    struct Tune {
        Vec scales, ratios;
        double mu;
        Mat K;
    };
    Tune tune(bool weighted) {
        if (weighted)
            phase = "final_affinity_retuning";
        double lo = std::min(C, .5), hi = std::max(C, 1.);
        Json begin = graph_data();
        begin.update(Json{
            {"event", "tune_start"}, {"C", C}, {"minC", lo}, {"maxC", hi}, {"recycled", cache}});
        emit(begin);
        Tune result;
        int nits = 0;
        auto evaluate = [&](bool parameterized, int index) {
            result.scales = solve(parameterized);
            if (weighted)
                result.K = kernel(result.scales);
            result.ratios = volume(result.scales, weighted ? &result.K : nullptr);
            Vec positive;
            for (double x : result.ratios)
                if (x > 0)
                    positive.push_back(x);
            result.mu = median(positive);
            emit(Json{{"event", "retune_eval"},
                      {"C", C},
                      {"median", result.mu},
                      {"minC", lo},
                      {"maxC", hi},
                      {"bisection_index", index},
                      {"median_margin", std::abs(result.mu - 1) - .1},
                      {"lower_margin", std::abs(C - lo) - (1e-8 + 1e-5 * std::abs(lo))},
                      {"upper_margin", std::abs(C - hi) - (1e-8 + 1e-5 * std::abs(hi))}});
        };
        auto centered = [&]() { return std::abs(result.mu - 1) <= .1; };
        auto boundary = [&]() {
            return (result.mu - 1 > .1 && close(C, lo)) || (result.mu - 1 < -.1 && close(C, hi));
        };
        auto advance = [&]() {
            if (result.mu - 1 > 0)
                hi = C;
            else
                lo = C;
            C = lo + .5 * (hi - lo);
        };
        auto stop = [&]() {
            emit(Json{{"event", "retune_stop"},
                      {"C", C},
                      {"median", result.mu},
                      {"minC", lo},
                      {"maxC", hi},
                      {"median_target_met", centered()},
                      {"boundary_stop", boundary()},
                      {"cap_reached", nits >= 20},
                      {"bisection_updates", nits}});
            require(nits < 20, "retuning_cap");
        };
        if (cache) {
            evaluate(false, -1);
            if (centered() || boundary()) {
                stop();
                return result;
            }
            advance();
        }
        for (nits = 0; nits < 20;) {
            evaluate(true, nits);
            if (centered() || boundary())
                break;
            advance();
            nits++;
        }
        cache = true;
        stop();
        return result;
    }
    // Complete construction: input, graph/pruning, then durable output stages.
    void run(const Json &input, const fs::path &file) {
        auto began = Clock::now();
        Input p = preprocess(input);
        metadata = {{"input_sha256", file_hash(file)},
                    {"source_sha256", SOURCE_HASH},
                    {"configuration_sha256", CONFIG_HASH},
                    {"mapping", p.mapping}};
        Json map = p.mapping;
        map["event"] = "mapping";
        emit(map);
        D = p.D;
        D2 = D;
        double minimum = std::numeric_limits<double>::infinity();
        for (size_t i = 0; i < D.size(); i++)
            for (size_t j = i + 1; j < D.size(); j++)
                minimum = std::min(minimum, D[i][j]);
        scl = 1 / minimum;
        double scl2 = scl * scl;
        for (size_t i = 0; i < D.size(); i++)
            for (size_t j = 0; j < D.size(); j++) {
                D2[i][j] = (D[i][j] * D[i][j]) * scl2;
                D[i][j] *= scl;
            }
        edges = gabriel(D2);
        deg = degrees(D.size(), edges);
        upper = upper_bounds(D, edges);
        emit(Json{
            {"event", "processed"}, {"D1", D}, {"D2", D2}, {"scl", scl}, {"initial_edges", edges}});
        require(isolates(deg).empty(), "unsupported_initial_isolate");
        // Initialize the multiplier from ordered furthest-neighbor ratios.
        auto nbr = neighbors(D, edges);
        Vec ratios(D.size());
        for (size_t i = 0; i < D.size(); i++) {
            int k = deg[i];
            int mid = std::min(k - 1, std::max(1, int(std::ceil(k / 2.)) - 1));
            ratios[i] = D[i][nbr[i][k - mid - 1]] / upper[i];
        }
        C = std::min(std::max(.55, median(ratios)), .95);
        bool converged = false;
        Vec last_stats;
        // Each iteration solves, evaluates the pruning threshold, then removes edges.
        for (iteration = 0; iteration < (inject == "pruning_cap" ? 1 : 2000); iteration++) {
            phase = iteration == 0 ? "initial" : "post_prune";
            Json event = graph_data();
            event.update(Json{{"event", "iteration"}, {"scl", scl}});
            emit(event);
            auto t = tune(false);
            last_stats = t.ratios;
            auto dec = decision(t.ratios, t.mu);
            emit(dec);
            Ids candidates = dec["candidates"].get<Ids>();
            if (candidates.empty()) {
                converged = true;
                break;
            }
            size_t limit = std::max(1, int(.1 * candidates.size()));
            candidates.resize(std::min(limit, candidates.size()));
            auto removed = prune(edges, D, candidates);
            deg = degrees(D.size(), edges);
            upper = upper_bounds(D, edges);
            event = graph_data();
            event.update(Json{{"event", "pruned"}, {"selected", candidates}, {"removed", removed}});
            emit(event);
        }
        if (!converged && iteration > 0)
            --iteration; // match adapter STATE.it: last visited iteration
        // A converged graph is durable before weighted retuning or affinity output.
        phase = "final_affinity_retuning";
        Json stop = graph_data();
        stop.update(
            Json{{"event", "graph_stop"},
                 {"converged", converged},
                 {"reason", converged ? "no_pruning_candidates" : "pruning_iteration_cap"}});
        emit(stop);
        require(converged, "pruning_iteration_cap");
        Json graph = graph_data();
        graph["scl"] = scl;
        graph["upper_units"] = "internal_distance = input_distance * scl";
        graph["upper_to_input_distance"] = 1 / scl;
        checkpoint("graph", graph);
        if (inject == "after_graph")
            throw std::runtime_error("injected_after_graph");
        auto final = tune(true);
        Vec original = final.scales;
        for (double &x : original)
            x /= scl;
        checkpoint(
            "scales",
            Json{{"scales", original}, {"internal_scales", final.scales}, {"scl", scl}, {"C", C}});
        if (inject == "after_scales")
            throw std::runtime_error("injected_after_scales");
        for (size_t i = 0; i < D.size(); i++)
            for (size_t j = 0; j < D.size(); j++)
                require(std::isfinite(final.K[i][j]) && final.K[i][j] >= 0 && final.K[i][j] <= 1 &&
                            final.K[i][j] == final.K[j][i] &&
                            (i != j || final.K[i][i] == (deg[i] ? 1 : 0)),
                        "invalid_affinity");
        checkpoint("affinity", Json{{"affinity", final.K}, {"scales", original}, {"C", C}});
        if (inject == "after_affinity")
            throw std::runtime_error("injected_after_affinity");
        emit(Json{{"event", "complete"},
                  {"edges", edges},
                  {"scales", original},
                  {"affinity", final.K},
                  {"stats", last_stats},
                  {"wstats", final.ratios},
                  {"isolates", isolates(deg)}});
        status["complete"] = true;
        status["solves"] = solves;
        status["seconds"] = std::chrono::duration<double>(Clock::now() - began).count();
        atomic_json(out / "status.json", status);
    }
};
