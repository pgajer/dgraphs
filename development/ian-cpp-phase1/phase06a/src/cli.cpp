#include <ian/core.hpp>
#include "json_adapter.hpp"
#include "checkpoint.hpp"
#include "testing.hpp"
#include <chrono>
#include <iostream>
#include <memory>

using namespace ian::io;
struct Files final : ian::Observer {
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
        trace << event.json << '\n'; trace.flush(); require(bool(trace),"trace_write");
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
int main(int argc, char** argv) {
    if (argc < 3 || argc > 4) { std::cerr << "ian_engine input.json new-output [diagnostic-fault]\n"; return 2; }
    fs::path out=argv[2];
    std::unique_ptr<Files> files;
    try {
        if (!fs::create_directories(out)) { std::cerr << "output_exists\n"; return 2; }
        std::ifstream f(argv[1]); require(bool(f),"input_read"); Json j; f>>j;
        if (j.value("kind","")=="stages") {
            atomic_json(out/"stages.json",Json::parse(ian::testing::legacy_stages(j.dump()))); return 0;
        }
        auto input=parse_input(j);
        files=std::make_unique<Files>(out,file_hash(argv[1]));
        auto start=std::chrono::steady_clock::now();
        auto result=argc==4 ? ian::testing::run_with_fault(input,files.get(),argv[3]) : ian::run(input,files.get());
        atomic_json(out/"result.json",result_json(result));
        files->status["complete"]=result.complete;
        files->status["solves"]=result.solves;
        files->status["seconds"]=std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count();
        if (!result.complete) files->status["error"]=result.error.code;
        files->status["error_kind"]=ian::error_kind_name(result.error.kind);
        atomic_json(out/"status.json",files->status);
        return result.complete ? 0 : 1;
    } catch (const std::exception& e) {
        Json status=files ? files->status : Json{{"graph",false},{"scales",false},{"affinity",false},{"complete",false}};
        status["error"]=e.what(); status["error_kind"]="adapter";
        try { atomic_json(out/"status.json",status); } catch (...) { std::cerr << "status_write_failed\n"; }
        std::cerr << e.what() << '\n'; return 1;
    }
}
