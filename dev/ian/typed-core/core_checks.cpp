#include "engine.hpp"
#include "store.hpp"
#include "testing.hpp"
#include <iostream>
using namespace ian;
using namespace ian::io;
struct Capture : Observer {
    std::vector<Event> events;
    RestartState saved;
    bool cancel=false,fail=false;
    int attempts=0;
    std::unique_ptr<RestartFiles> files;
    std::ofstream* ledger=nullptr;
    void on_event(const Event& e) override {
        events.push_back(e);
        if(std::holds_alternative<SolveRecord>(e.payload)) {
            ++attempts; if(ledger){*ledger<<event_json(e).dump()<<'\n';ledger->flush();}
            if(attempts>=80)throw std::runtime_error("test_budget");
        }
        if(files)files->on_event(e);
        if(fail)throw std::runtime_error("observer_test");
    }
    void on_stage(Stage stage,const Result& r) override {if(files)files->on_stage(stage,r);}
    bool on_checkpoint(const RestartState& s) override {
        saved=s;if(files)return files->on_checkpoint(s);return !(cancel && s.boundary=="pruning");
    }
};
void check(bool x,const char* label){if(!x)throw std::runtime_error(label);}
int main(int argc,char** argv) {
 try {
    check(argc==5,"arguments");
    auto in=parse_input(Json::parse(read_text(argv[1])));
    fs::path out=argv[4];check(!fs::exists(out),"fresh_output");fs::create_directories(out);
    std::ofstream ledger(out/"attempts.jsonl");int calls=0,attempts=0;Json accounting=Json::array();
    auto invoke=[&](const char* name,Capture& sink,const RestartState* saved=nullptr){
        ++calls;atomic_json(out/"progress.json",{{"call",calls},{"name",name},{"state","started"}});
        sink.ledger=&ledger;
        auto r=saved?resume(in,*saved,&sink):run(in,&sink);
        attempts+=sink.attempts;
        accounting.push_back({{"name",name},{"complete",r.complete},{"attempts",sink.attempts},{"error",error_kind_name(r.error.kind)}});
        atomic_json(out/"ledger.json",{{"calls",accounting},{"total_attempts",attempts}});
        atomic_json(out/(std::string(name)+".json"),result_json(r));
        return r;
    };
    Capture full;auto expected=invoke("full",full);check(expected.complete,"full_complete");
    Capture stopped;stopped.cancel=true;fs::create_directories(out/"disk");
    stopped.files=std::make_unique<RestartFiles>(out/"disk",file_hash(argv[1]),1,0,"none",1);
    auto partial=invoke("cancelled",stopped);
    check(!partial.complete && partial.error.kind==ErrorKind::cancelled,"cancellation");
    auto envelope=load_envelope(discover(out/"disk/checkpoints"),file_hash(argv[1]));
    auto encoded=envelope.at("payload");auto decoded=parse_state(Json::parse(encoded.dump()));
    check(encoded==state_json(stopped.saved),"disk_checkpoint_payload");
    auto damaged=envelope;auto bytes=read_text(out/"disk/trace.jsonl");bytes[0]=bytes[0]=='x'?'y':'x';
    std::ofstream(out/"damaged-trace.jsonl")<<bytes;damaged["trace_file"]=fs::absolute(out/"damaged-trace.jsonl").string();
    atomic_json(out/"damaged-checkpoint.json",damaged);bool corruption_rejected=false;
    try{load_envelope(out/"damaged-checkpoint.json",file_hash(argv[1]));}catch(const std::exception&){corruption_rejected=true;}
    check(corruption_rejected,"trace_corruption_refused");
    atomic_json(out/"checkpoint.json",encoded);
    Capture continuation;auto resumed=invoke("resumed",continuation,&decoded);
    check(resumed.complete && result_json(resumed)==result_json(expected),"resume_exact_result");
    auto bad=decoded;bad.degrees[0]++;
    Capture invalid;auto refused=invoke("malformed",invalid,&bad);
    check(!refused.complete && refused.error.code=="invalid_restart" && invalid.attempts==0,"malformed_restart");
    Capture failed;failed.fail=true;auto failure=invoke("observer_failure",failed);
    check(!failure.complete && failure.error.kind==ErrorKind::observer && failed.attempts==0,"observer_failure");
    std::ofstream trace(out/"full-trace.jsonl");for(const auto& e:full.events)trace<<event_json(e).dump()<<'\n';trace.close();
    auto probes=Json::parse(testing::fixed_probe(read_text(argv[2]),nullptr));
    auto reference=Json::parse(read_text(argv[3])).at("cases");
    check(probes.size()==6,"six_decision_controls");
    for(size_t i=0;i<6;++i){const auto& a=probes[i];const auto& b=reference[i+4];
        check(a["decision"]==b["decision"] && a["selected"]==b["selected"] && a["removed"]==b["removed"] && a["edges"]==b["remaining_edges"],"fixed_decision_order");}
    atomic_json(out/"decision-controls.json",probes);
    atomic_json(out/"summary.json",{{"pass",true},{"calls",calls},{"attempts",attempts},{"decision_controls",6},{"typed_events",full.events.size()}});
    std::cout<<calls<<" calls "<<attempts<<" attempts; typed/checkpoint/decision checks pass\n";
 } catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}
}
