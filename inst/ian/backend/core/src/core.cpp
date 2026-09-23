#include <ian/core.hpp>
#include "engine.hpp"
#include "identity.hpp"
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
        engine.input_hash = io::input_identity(input);
        engine.run(input);
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
}
}
