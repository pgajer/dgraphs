#include <ian/core.hpp>
#include "engine.hpp"
#include "stages.hpp"
#include "testing.hpp"

namespace ian {
std::string source_identity() { return SOURCE_HASH; }
std::string configuration_identity() { return CONFIG_HASH; }
const char* error_kind_name(ErrorKind kind) {
    switch (kind) {
    case ErrorKind::none: return "none";
    case ErrorKind::input: return "input";
    case ErrorKind::unsupported: return "unsupported";
    case ErrorKind::numerical: return "numerical";
    case ErrorKind::observer: return "observer";
    case ErrorKind::cancelled: return "cancelled";
    default: return "internal";
    }
}
namespace {
ErrorKind classify(const std::string& code) {
    if (code == "unsupported_initial_isolate" || code == "unsupported_schema" || code == "unsupported_policy")
        return ErrorKind::unsupported;
    if (code == "invalid_restart" || code == "incompatible_restart") return ErrorKind::input;
    if (code == "input_shape_or_identity" || code == "invalid_distances_or_features" ||
        code == "duplicate_distance_inconsistency" || code == "fewer_than_two_unique_profiles" ||
        code == "nearly_identical_distinct_profiles" || code == "participant_shape_or_identity")
        return ErrorKind::input;
    if (code == "invalid_solver_result" || code == "solver_construction" || code == "invalid_affinity" ||
        code == "retuning_cap" || code == "pruning_iteration_cap") return ErrorKind::numerical;
    return ErrorKind::internal;
}
Result execute(const Input& input, Observer* observer, const std::string& fault, const RestartState* saved = nullptr) {
    Result result;
    detail::Engine engine(result, observer, fault, saved);
    try {
        detail::require(input.version == schema_version, "unsupported_schema");
        detail::require(input.policy == numerical_policy, "unsupported_policy");
        detail::require(input.participant_ids.empty() || input.participant_ids.size() == input.specimen_ids.size(),
                        "participant_shape_or_identity");
        for (const auto& id : input.participant_ids)
            detail::require(!id.empty(), "participant_shape_or_identity");
        result.mapping.participant_ids = input.participant_ids;
        engine.input_hash = digest(detail::Json{{"version",input.version},{"policy",input.policy},
            {"features",input.features},{"distances",input.distances},{"ids",input.specimen_ids},
            {"participants",input.participant_ids}}.dump());
        // Binary doubles are copied into the unchanged private input validator.
        // No decimal serialization, distance recomputation or policy conversion.
        engine.run(detail::Json{{"features", input.features}, {"distances", input.distances},
                                {"ids", input.specimen_ids}});
    } catch (const detail::Cancelled& e) {
        result.error = {ErrorKind::cancelled, "cancelled", e.what()};
    } catch (const detail::ObserverFailure& e) {
        result.error = {ErrorKind::observer, "observer_failure", e.what()};
    } catch (const std::exception& e) {
        result.error = {classify(e.what()), e.what(), e.what()};
    }
    result.solves = engine.solves;
    result.last_iteration = engine.iteration;
    return result;
}
}
Result run(const Input& input, Observer* observer) { return execute(input, observer, "none"); }
Result resume(const Input& input, const RestartState& state, Observer* observer) {
    return execute(input, observer, "none", &state);
}
namespace testing {
Result run_with_fault(const Input& input, Observer* observer, const std::string& fault) {
    const std::vector<std::string> supported{"none", "invalid_solver", "after_graph", "after_scales", "after_affinity", "pruning_cap"};
    if (std::find(supported.begin(), supported.end(), fault) == supported.end())
        throw std::invalid_argument("unknown_test_fault");
    return execute(input, observer, fault);
}
std::string legacy_stages(const std::string& input) {
    return detail::stages(detail::Json::parse(input)).dump();
}
std::string fixed_probe(const std::string& text, Observer* observer) {
    using namespace detail;
    const Json input = Json::parse(text);
    if (input.contains("cases")) {
        Json results = Json::array();
        for (auto &c : input["cases"]) {
            auto d = decision(c["stats"].get<Vec>(), c["median"].get<double>());
            auto selected = d["candidates"].get<Ids>();
            selected.resize(std::min(selected.size(), size_t(std::max(1, int(.1 * selected.size())))));
            auto edges = c["edges"].get<Edges>();
            auto removed = prune(edges, c["D1"].get<Mat>(), selected);
            results.push_back(Json{{"name", c["name"]}, {"decision", d}, {"selected", selected},
                                   {"removed", removed}, {"edges", edges}});
        }
        return results.dump();
    }
    Result ignored;
    Engine e(ignored, observer, "none");
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
    e.emit(Json{{"event", "processed"}, {"D1", e.D}, {"D2", e.D2}, {"scl", e.scl}, {"initial_edges", e.edges}});
    Json initial = e.graph_data();
    initial.update(Json{{"event", "iteration"}, {"scl", e.scl}});
    e.emit(initial);
    Vec scales, stats;
    double mu;
    if (input["action"] == "tune") {
        auto t = e.tune(false);
        scales = t.scales; stats = t.ratios; mu = t.mu;
    } else {
        scales = e.solve(true);
        stats = e.volume(scales, nullptr);
        Vec positive;
        for (double v : stats) if (v > 0) positive.push_back(v);
        mu = median(positive);
        bool stop = std::abs(mu - 1) <= .1 || (mu - 1 > .1 && close(e.C, std::min(e.C, .5))) ||
                    (mu - 1 < -.1 && close(e.C, std::max(e.C, 1.)));
        e.emit(Json{{"event", "predicate"}, {"C", e.C}, {"median", mu},
                    {"median_margin", std::abs(mu - 1) - .1}, {"converged", stop}});
    }
    auto dec = decision(stats, mu);
    e.emit(dec);
    auto selected = dec["candidates"].get<Ids>();
    selected.resize(std::min(selected.size(), size_t(std::max(1, int(.1 * selected.size())))));
    auto removed = prune(e.edges, e.D, selected);
    e.deg = degrees(e.D.size(), e.edges);
    e.upper = upper_bounds(e.D, e.edges);
    Json event = e.graph_data();
    event.update(Json{{"event", "pruned"}, {"selected", selected}, {"removed", removed}});
    e.emit(event);
    Json result = e.graph_data();
    result.update(Json{{"decision", dec}, {"selected", selected}, {"removed", removed},
        {"C", e.C}, {"scales", scales}, {"ratios", stats}, {"median", mu}, {"solves", e.solves}});
    return result.dump();
}
}
}
