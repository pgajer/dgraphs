#pragma once
#include "json_adapter.hpp"
#include "digest.hpp"
#include <climits>
namespace ian::io {
inline int integer(const Json& v, int minimum = 0, int maximum = INT_MAX) {
    if (!v.is_number_integer() || v < minimum || v > maximum)
        throw std::invalid_argument("invalid_checkpoint_integer");
    return v.get<int>();
}
inline void integers(const Json& v) {
    if (!v.is_array()) throw std::invalid_argument("invalid_checkpoint_array");
    for (const auto& x : v) integer(x);
}
inline Json state_json(const RestartState& s) {
    auto m = mapping_json(s.mapping); m["participant_ids"] = s.mapping.participant_ids;
    return Json{{"version",s.version},{"policy",s.policy},{"source",s.source},
        {"configuration",s.configuration},{"input_hash",s.input_hash},{"boundary",s.boundary},
        {"mapping",m},{"edges",s.edges},{"degrees",s.degrees},{"upper",s.upper},
        {"last_stats",s.last_stats},{"multiplier",s.multiplier},{"distance_multiplier",s.distance_multiplier},
        {"iteration",s.iteration},{"solves",s.solves},{"cache",s.cache}};
}
inline RestartState parse_state(const Json& j) {
    RestartState s;
    s.version = integer(j.at("version"),1,1);
    s.policy = j.at("policy").get<std::string>(); s.source = j.at("source").get<std::string>();
    s.configuration = j.at("configuration").get<std::string>(); s.input_hash = j.at("input_hash").get<std::string>();
    s.boundary = j.at("boundary").get<std::string>();
    const auto& m = j.at("mapping");
    integers(m.at("representatives")); integers(m.at("member_to_profile")); integers(j.at("degrees"));
    if (!j.at("edges").is_array()) throw std::invalid_argument("invalid_checkpoint_edges");
    for (const auto& e : j.at("edges")) {
        integers(e); if (e.size() != 2) throw std::invalid_argument("invalid_checkpoint_edges");
    }
    s.mapping.representatives = m.at("representatives").get<Indices>();
    s.mapping.member_to_profile = m.at("member_to_profile").get<Indices>();
    s.mapping.specimen_ids = m.at("specimen_ids").get<std::vector<std::string>>();
    s.mapping.profile_ids = m.at("profile_ids").get<std::vector<std::string>>();
    s.mapping.participant_ids = m.at("participant_ids").get<std::vector<std::string>>();
    s.edges = j.at("edges").get<Edges>(); s.degrees = j.at("degrees").get<Indices>();
    s.upper = j.at("upper").get<Vector>(); s.last_stats = j.at("last_stats").get<Vector>();
    s.multiplier = j.at("multiplier").get<double>(); s.distance_multiplier = j.at("distance_multiplier").get<double>();
    s.iteration = integer(j.at("iteration"),0,1999); s.solves = integer(j.at("solves"),1,42000);
    if (!j.at("cache").is_boolean()) throw std::invalid_argument("invalid_checkpoint_cache");
    s.cache = j.at("cache").get<bool>();
    return s;
}
}
