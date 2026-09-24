#pragma once
#include "input.hpp"
#include "solver.hpp"
#include "events_json.hpp"
#include "json_adapter.hpp"
// Small targeted stages retained alongside complete-run regression tests.
namespace ian::detail {
using io::Json;
Json stages(const Json &in) {
    Json results;
    auto dup = preprocess(io::parse_input(in["duplicate"]));
    results["duplicate"] = io::mapping_json(dup.mapping);
    results["gabriel"] = Json::array();
    for (auto f : in["gabriel"])
        results["gabriel"].push_back(
            Json{{"name", f["name"]}, {"edges", gabriel(f["D2"].get<Mat>())}});
    results["decisions"] = Json::array();
    for (auto d : in["decisions"]) {
        auto out = io::payload_json(decision(d["stats"].get<Vec>(), d["median"].get<double>()));
        out["name"] = d["name"];
        results["decisions"].push_back(out);
    }
    auto e = in["pruning"]["edges"].get<Edges>();
    auto removed =
        prune(e, in["pruning"]["distances"].get<Mat>(), in["pruning"]["candidates"].get<Ids>());
    results["pruning"] = {{"removed", removed}, {"edges", e}};
    auto c = in["disconnected"];
    Mat D = c["distances"].get<Mat>(), D2 = D;
    for (auto &row : D2)
        for (auto &x : row)
            x = x * x;
    Edges edges = c["edges"].get<Edges>();
    Ids deg = degrees(D.size(), edges);
    Vec u = upper_bounds(D, edges);
    auto sol = solve_lp(D, edges, u, c["C"].get<double>(), true);
    require(sol.record.accepted, "stage_solve_invalid");
    Mat K = affinity(D2, sol.x, deg);
    results["disconnected"] = {{"solve", io::payload_json(sol.record)},
                               {"components", components(D.size(), edges)},
                               {"ratios", volumes(D2, sol.x, deg)},
                               {"affinity", K},
                               {"weighted_ratios", volumes(D2, sol.x, deg, &K)}};
    auto cut = in["affinity_cutoffs"];
    results["affinity_cutoffs"] =
        affinity(cut["D2"].get<Mat>(), cut["scales"].get<Vec>(), cut["degrees"].get<Ids>());
    return results;
}

} // namespace ian::detail
