#pragma once
#include <ian/core.hpp>
#include "input.hpp"
#include "solver.hpp"

namespace ian::detail {
using Clock = std::chrono::steady_clock;
struct ObserverFailure : std::runtime_error { using std::runtime_error::runtime_error; };
struct Cancelled : std::runtime_error { using std::runtime_error::runtime_error; };
struct Engine {
    ian::Result &result;
    ian::Observer *observer;
    Mat input_distances;
    const ian::RestartState* restart;
    Vec last_stats;
    std::string input_hash;
    Mat D, D2;
    Edges edges;
    Ids deg;
    Vec upper;
    double scl = 1, C = 0;
    int iteration = 0, solves = 0;
    bool cache = false;
    std::string phase = "initial", inject;
    Engine(ian::Result &value, ian::Observer *sink, std::string injection, const ian::RestartState* saved = nullptr)
        : result(value), observer(sink), restart(saved), inject(std::move(injection)) {}
    template<class Payload> void emit(Payload payload) {
        if (observer) {
            try { observer->on_event({ian::event_name(payload), phase, iteration, std::move(payload)}); }
            catch (const std::exception &e) { throw ObserverFailure(e.what()); }
            catch (...) { throw ObserverFailure("nonstandard_callback_exception"); }
        }
    }
    #include "restart_methods.inc"
    ian::GraphSnapshot graph_data() {
        return {edges, deg, upper, components(D.size(), edges), isolates(deg)};
    }
    // Each stage commits typed values before notifying the observer.
    void notify_stage(ian::Stage which) {
        result.solves = solves;
        result.last_iteration = iteration;
        if (observer) {
            try { observer->on_stage(which, result); }
            catch (const std::exception &e) { throw ObserverFailure(e.what()); }
            catch (...) { throw ObserverFailure("nonstandard_callback_exception"); }
        }
    }
    Vec solve(bool parameterized) {
        auto r =
            solve_lp(D, edges, upper, C, parameterized, inject == "invalid_solver" && solves == 0);
        r.record.number = solves++;
        emit(r.record);
        require(r.record.accepted, "invalid_solver_result");
        return r.x;
    }
    Mat kernel(const Vec &s) {
        Mat K = affinity(D2, s, deg);
        emit(ian::KernelEvent{K,s});
        return K;
    }
    Vec volume(const Vec &s, const Mat *K) {
        Vec v = volumes(D2, s, deg, K);
        emit(ian::VolumeEvent{v,s,deg,K != nullptr});
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
        emit(ian::TuneStartEvent{graph_data(),C,lo,hi,cache});
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
            emit(ian::RetuneEvalEvent{C,result.mu,lo,hi,index,
                std::abs(result.mu - 1) - .1,
                std::abs(C - lo) - (1e-8 + 1e-5 * std::abs(lo)),
                std::abs(C - hi) - (1e-8 + 1e-5 * std::abs(hi))});
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
            emit(ian::RetuneStopEvent{C,result.mu,lo,hi,centered(),boundary(),nits >= 20,nits});
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
    void run(const ian::Input &input) {
        auto p = preprocess(input);
        result.mapping = p.mapping;
        input_distances = p.D;
        if (!restart) emit(ian::MappingEvent{p.mapping});
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
        if (!restart) emit(ian::ProcessedEvent{D,D2,scl,edges});
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
        if (restart) restore(*restart);
        bool graph_restored = restart && restart->boundary == "graph";
        bool converged = graph_restored;
        // Each iteration solves, evaluates the pruning threshold, then removes edges.
        for (iteration = restart ? restart->iteration + (graph_restored ? 0 : 1) : 0;
             !graph_restored && iteration < (inject == "pruning_cap" ? 1 : 2000); iteration++) {
            phase = iteration == 0 ? "initial" : "post_prune";
            emit(ian::IterationEvent{graph_data(),scl});
            auto t = tune(false);
            last_stats = t.ratios;
            auto dec = decision(t.ratios, t.mu);
            emit(dec);
            Ids candidates = dec.candidates;
            if (candidates.empty()) {
                converged = true;
                break;
            }
            size_t limit = std::max(1, int(.1 * candidates.size()));
            candidates.resize(std::min(limit, candidates.size()));
            auto removed = prune(edges, D, candidates);
            deg = degrees(D.size(), edges);
            upper = upper_bounds(D, edges);
            emit(ian::PrunedEvent{graph_data(),candidates,removed});
            boundary("pruning");
        }
        if (!converged && iteration > 0)
            --iteration; // match adapter STATE.it: last visited iteration
        // A converged graph is durable before weighted retuning or affinity output.
        phase = "final_affinity_retuning";
        if (!graph_restored) emit(ian::GraphStopEvent{graph_data(),converged,
            converged ? "no_pruning_candidates" : "pruning_iteration_cap"});
        require(converged, "pruning_iteration_cap");
        result.graph.edges = edges;
        result.graph.degrees = deg;
        result.graph.internal_upper = upper;
        result.graph.components = components(D.size(),edges);
        result.graph.isolates = isolates(deg);
        result.graph.distance_multiplier = scl;
        for(auto e:edges) result.graph.edge_lengths.push_back(input_distances[e[0]][e[1]]);
        result.graph_valid = true;
        notify_stage(ian::Stage::graph);
        if (!graph_restored) boundary("graph");
        if (inject == "after_graph")
            throw std::runtime_error("injected_after_graph");
        auto final = tune(true);
        Vec original = final.scales;
        for (double &x : original)
            x /= scl;
        result.scales = original;
        result.internal_scales = final.scales;
        result.multiplier = C;
        result.scales_valid = true;
        notify_stage(ian::Stage::scales);
        if (inject == "after_scales")
            throw std::runtime_error("injected_after_scales");
        for (size_t i = 0; i < D.size(); i++)
            for (size_t j = 0; j < D.size(); j++)
                require(std::isfinite(final.K[i][j]) && final.K[i][j] >= 0 && final.K[i][j] <= 1 &&
                            final.K[i][j] == final.K[j][i] &&
                            (i != j || final.K[i][i] == (deg[i] ? 1 : 0)),
                        "invalid_affinity");
        result.affinity = final.K;
        result.affinity_valid = true;
        notify_stage(ian::Stage::affinity);
        if (inject == "after_affinity")
            throw std::runtime_error("injected_after_affinity");
        emit(ian::CompleteEvent{edges,original,final.K,last_stats,final.ratios,isolates(deg)});
        result.stats = last_stats;
        result.weighted_stats = final.ratios;
        result.complete = true;
        result.solves = solves;
        result.last_iteration = iteration;
    }
};

} // namespace ian::detail
