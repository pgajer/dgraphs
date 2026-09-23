#pragma once
#include <ian/core.hpp>
#include "json_adapter.hpp"
#include "events_json.hpp"
#include "checkpoint.hpp"
#include "testing.hpp"
#include <chrono>
#include <iostream>
#include <memory>

using namespace ian::io;
struct Files : ian::Observer {
    fs::path out;
    std::ofstream trace;
    Json metadata;
    Json status = {{"graph",false},{"scales",false},{"affinity",false},{"complete",false},{"error",nullptr}};
    Files(const fs::path& path, const std::string& input_hash) : out(path), trace(path/"trace.jsonl") {
        require(bool(trace),"trace_open");
        metadata = {{"input_sha256",input_hash},{"source_sha256",ian::source_identity()},
                    {"configuration_sha256",ian::configuration_identity()}};
    }
    void on_event(const ian::Event& event) override {
        trace << event_json(event).dump() << '\n'; trace.flush(); require(bool(trace),"trace_write");
    }
    void on_stage(ian::Stage s, const ian::Result& r) override {
        std::string stage;
        Json payload;
        if (s == ian::Stage::graph) { stage="graph"; payload=graph_json(r.graph); }
        else if (s == ian::Stage::scales) {
            stage="scales"; payload={{"scales",r.scales},{"internal_scales",r.internal_scales},
                {"scl",r.graph.distance_multiplier},{"C",r.multiplier}};
        } else { stage="affinity"; payload={{"affinity",r.affinity},{"scales",r.scales},{"C",r.multiplier}}; }
        payload.update(metadata);
        payload["mapping"]=mapping_json(r.mapping);
        payload["stage"]=stage; payload["status"]="validated";
        auto path=out/(stage+".json"); require(!fs::exists(path),"checkpoint_exists");
        atomic_json(path,payload);
        status[stage]=true; status[stage+"_sha256"]=file_hash(path);
        atomic_json(out/"status.json",status);
    }
};
