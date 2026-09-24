#pragma once
#include <ian/core.hpp>
#include <json.hpp>
#include <stdexcept>
namespace ian::io {
using Json = nlohmann::json;
inline Input parse_input(const Json& j) {
    Input in;
    // Validate the JSON representation before any conversion can truncate or narrow it.
    if (j.contains("schema_version")) {
        const auto& version = j.at("schema_version");
        if (!version.is_number_integer() || version != schema_version)
            throw std::invalid_argument("unsupported_schema");
    }
    in.version = schema_version;
    in.policy = j.value("numerical_policy", std::string(numerical_policy));
    in.features = j.at("features").get<Matrix>();
    in.distances = j.at("distances").get<Matrix>();
    in.specimen_ids = j.at("ids").get<std::vector<std::string>>();
    in.participant_ids = j.value("participant_ids", std::vector<std::string>{});
    return in;
}
inline Json mapping_json(const Mapping& m) {
    return Json{{"representatives", m.representatives}, {"member_to_profile", m.member_to_profile},
                {"specimen_ids", m.specimen_ids}, {"profile_ids", m.profile_ids}};
}
inline Json graph_json(const Graph& g) {
    return Json{{"edges",g.edges}, {"degrees",g.degrees}, {"upper",g.internal_upper},
                {"components",g.components}, {"isolates",g.isolates}, {"scl",g.distance_multiplier},
                {"upper_units","internal_distance = input_distance * scl"},
                {"upper_to_input_distance",1/g.distance_multiplier}};
}
inline Json result_json(const Result& r) {
    auto graph = graph_json(r.graph);
    graph["edge_lengths"] = r.graph.edge_lengths;
    graph["edge_length_units"] = "supplied input distance";
    auto mapping = mapping_json(r.mapping);
    mapping["participant_ids"] = r.mapping.participant_ids;
    return Json{{"schema_version",r.version}, {"numerical_policy",r.policy},
        {"mapping",mapping}, {"graph",graph}, {"scales",r.scales}, {"internal_scales",r.internal_scales},
        {"affinity",r.affinity}, {"stats",r.stats}, {"weighted_stats",r.weighted_stats},
        {"multiplier",r.multiplier}, {"solves",r.solves}, {"last_iteration",r.last_iteration},
        {"graph_valid",r.graph_valid}, {"scales_valid",r.scales_valid}, {"affinity_valid",r.affinity_valid},
        {"complete",r.complete}, {"error",Json{{"kind",error_kind_name(r.error.kind)},
        {"code",r.error.code}, {"message",r.error.message}}}};
}
}
