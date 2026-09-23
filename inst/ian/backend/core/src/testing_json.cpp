#include "engine.hpp"
#include "stages.hpp"
#include "testing.hpp"
namespace ian::testing {
std::string legacy_stages(const std::string& input) {
    return detail::stages(io::Json::parse(input)).dump();
}
std::string fixed_probe(const std::string& text, Observer* observer) {
    using namespace detail;
    using io::Json;
    const Json input = Json::parse(text);
    if (input.contains("cases")) {
        Json results = Json::array();
        for (auto &c : input["cases"]) {
            auto d = decision(c["stats"].get<Vec>(), c["median"].get<double>());
            auto selected = d.candidates;
            selected.resize(std::min(selected.size(), size_t(std::max(1, int(.1 * selected.size())))));
            auto edges = c["edges"].get<Edges>();
            auto removed = prune(edges, c["D1"].get<Mat>(), selected);
            results.push_back(Json{{"name", c["name"]}, {"decision", io::payload_json(d)}, {"selected", selected},
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
    const auto& mapping=input["mapping"];
    e.emit(MappingEvent{Mapping{mapping["representatives"].get<Indices>(),mapping["member_to_profile"].get<Indices>(),mapping["specimen_ids"].get<std::vector<std::string>>(),mapping["profile_ids"].get<std::vector<std::string>>(),{}}});
    e.emit(ProcessedEvent{e.D,e.D2,e.scl,e.edges});
    e.emit(IterationEvent{e.graph_data(),e.scl});
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
        e.emit(PredicateEvent{e.C,mu,std::abs(mu-1)-.1,stop});
    }
    auto dec = decision(stats, mu);
    e.emit(dec);
    auto selected = dec.candidates;
    selected.resize(std::min(selected.size(), size_t(std::max(1, int(.1 * selected.size())))));
    auto removed = prune(e.edges, e.D, selected);
    e.deg = degrees(e.D.size(), e.edges);
    e.upper = upper_bounds(e.D, e.edges);
    e.emit(PrunedEvent{e.graph_data(),selected,removed});
    Json result = io::object_json(e.graph_data());
    result.update(Json{{"decision", io::payload_json(dec)}, {"selected", selected}, {"removed", removed},
        {"C", e.C}, {"scales", scales}, {"ratios", stats}, {"median", mu}, {"solves", e.solves}});
    return result.dump();
}
}
