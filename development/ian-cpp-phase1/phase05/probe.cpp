// Diagnostic entry points only; accepted phase04 algorithm headers are unchanged.
#include "../phase04/engine.hpp"
#include <iostream>

Json one_pruning_step(Engine &e, const Vec &stats, double mu) {
    auto dec = decision(stats, mu);
    e.emit(dec);
    Ids selected = dec["candidates"].get<Ids>();
    selected.resize(std::min(selected.size(), size_t(std::max(1, int(.1 * selected.size())))));
    auto removed = prune(e.edges, e.D, selected);
    e.deg = degrees(e.D.size(), e.edges);
    e.upper = upper_bounds(e.D, e.edges);
    Json event = e.graph_data();
    event.update(Json{{"event", "pruned"}, {"selected", selected}, {"removed", removed}});
    e.emit(event);
    return Json{{"decision", dec}, {"selected", selected}, {"removed", removed}};
}

int main(int argc, char **argv) {
    if (argc != 3)
        return 2;
    fs::path out = argv[2];
    if (!fs::create_directories(out))
        return 2;
    try {
        std::ifstream stream(argv[1]);
        Json input;
        stream >> input;
        if (input.contains("cases")) {
            Json results = Json::array();
            for (auto &c : input["cases"]) {
                auto d = decision(c["stats"].get<Vec>(), c["median"].get<double>());
                auto selected = d["candidates"].get<Ids>();
                selected.resize(
                    std::min(selected.size(), size_t(std::max(1, int(.1 * selected.size())))));
                auto edges = c["edges"].get<Edges>();
                auto removed = prune(edges, c["D1"].get<Mat>(), selected);
                results.push_back(Json{{"name", c["name"]},
                                       {"decision", d},
                                       {"selected", selected},
                                       {"removed", removed},
                                       {"edges", edges}});
            }
            atomic_json(out / "stages.json", results);
            return 0;
        }
        Engine e(out, "none");
        e.phase = "fixed";
        e.D = input["D1"].get<Mat>();
        e.D2 = input["D2"].get<Mat>();
        e.edges = input["edges"].get<Edges>();
        e.deg = input["degrees"].get<Ids>();
        e.upper = input["upper"].get<Vec>();
        e.scl = input["scl"];
        e.C = input["C"];
        Json mapping = input["mapping"];
        mapping["event"] = "mapping";
        e.emit(mapping);
        e.emit(Json{{"event", "processed"},
                    {"D1", e.D},
                    {"D2", e.D2},
                    {"scl", e.scl},
                    {"initial_edges", e.edges}});
        Json initial = e.graph_data();
        initial.update(Json{{"event", "iteration"}, {"scl", e.scl}});
        e.emit(initial);
        Vec scales, stats;
        double mu;
        if (input["action"] == "tune") {
            auto t = e.tune(false);
            scales = t.scales;
            stats = t.ratios;
            mu = t.mu;
        } else {
            scales = e.solve(true);
            stats = e.volume(scales, nullptr);
            Vec positive;
            for (double v : stats)
                if (v > 0)
                    positive.push_back(v);
            mu = median(positive);
            bool stop = std::abs(mu - 1) <= .1 || (mu - 1 > .1 && close(e.C, std::min(e.C, .5))) ||
                        (mu - 1 < -.1 && close(e.C, std::max(e.C, 1.)));
            e.emit(Json{{"event", "predicate"},
                        {"C", e.C},
                        {"median", mu},
                        {"median_margin", std::abs(mu - 1) - .1},
                        {"converged", stop}});
        }
        Json result = one_pruning_step(e, stats, mu);
        result.update(e.graph_data());
        result.update(Json{{"C", e.C},
                           {"scales", scales},
                           {"ratios", stats},
                           {"median", mu},
                           {"solves", e.solves}});
        atomic_json(out / "result.json", result);
        atomic_json(out / "status.json",
                    Json{{"complete", true}, {"solves", e.solves}, {"diagnostic_only", true}});
        return 0;
    } catch (const std::exception &exc) {
        atomic_json(out / "status.json",
                    Json{{"complete", false}, {"error", exc.what()}, {"diagnostic_only", true}});
        std::cerr << exc.what() << '\n';
        return 1;
    }
}
