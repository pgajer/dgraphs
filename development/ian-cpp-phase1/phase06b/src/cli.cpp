#include "store.hpp"
int main(int argc,char** argv) {
    using namespace ian::io;
    if(argc<3) { std::cerr << "ian_engine input.json new-output [--resume file-or-checkpoint-directory] [--interval N] [--cancel-after iteration]\n"; return 2; }
    fs::path out=argv[2], resume_path;
    int interval=1, cancel_after=-1, fault_at=2;
    std::string fault="none", old_fault="none";
    bool diagnostic_fail=false;
    std::unique_ptr<RestartFiles> files;
    try {
        for(int i=3;i<argc;++i) {
            std::string option=argv[i];
            auto arg=[&]() { require(i+1<argc,"option_value"); return std::string(argv[++i]); };
            auto number=[&]() { auto s=arg(); size_t pos; int n=std::stoi(s,&pos); require(pos==s.size(),"invalid_option_integer"); return n; };
            if(option=="--resume") resume_path=arg();
            else if(option=="--interval") interval=number();
            else if(option=="--cancel-after") cancel_after=number();
            else if(option=="--fault") fault=arg();
            else if(option=="--fault-at") fault_at=number();
            else if(option=="--diagnostic-fail") diagnostic_fail=true;
            else if(i==3 && argc==4) old_fault=option;
            else throw std::runtime_error("unknown_option");
        }
        require(interval>0 && fault_at>0 && cancel_after>=-1,"invalid_option_integer");
        if(!fs::create_directories(out)) { std::cerr << "output_exists\n"; return 2; }
        auto began=std::chrono::steady_clock::now();
        auto input_json=Json::parse(read_text(argv[1]));
        if(input_json.value("kind","")=="stages") {
            atomic_json(out/"stages.json",Json::parse(ian::testing::legacy_stages(input_json.dump()))); return 0;
        }
        auto input=parse_input(input_json); auto hash=file_hash(argv[1]);
        ian::RestartState saved;
        if(!resume_path.empty()) { resume_path=discover(resume_path); saved=parse_state(load_envelope(resume_path,hash).at("payload")); }
        double loading=std::chrono::duration<double>(std::chrono::steady_clock::now()-began).count();
        files=std::make_unique<RestartFiles>(out,hash,interval,cancel_after,fault,fault_at);
        if(!resume_path.empty()) { files->pending_resume=resume_path.string(); files->origin_checkpoint=resume_path.string(); }
        std::signal(SIGINT,request_cancel); std::signal(SIGTERM,request_cancel);
        files->progress("running");
        auto result=resume_path.empty() ?
            (old_fault=="none" ? ian::run(input,files.get()) : ian::testing::run_with_fault(input,files.get(),old_fault)) :
            ian::resume(input,saved,files.get());
        files->account("output");
        atomic_json(out/"result.json",result_json(result));
        files->status["complete"]=result.complete; files->status["solves"]=result.solves;
        files->status["error"]=result.complete ? Json(nullptr) : Json(result.error.code);
        files->status["error_kind"]=ian::error_kind_name(result.error.kind);
        files->status["seconds"]=std::chrono::duration<double>(std::chrono::steady_clock::now()-began).count();
        atomic_json(out/"status.json",files->status);
        files->progress(result.complete ? "complete" : (result.error.kind==ian::ErrorKind::cancelled ? "cancelled" : "failed"),result.error.message);
        auto resources=files->resources(); resources["input_and_checkpoint_load_seconds"]=loading;
        resources["load_time_is_separate_from_phase_wall"]=true;
        atomic_json(out/"resources.json",resources);
        if(result.complete && diagnostic_fail)
            atomic_json(out/"diagnostics.json",Json{{"complete",false},{"error","injected_optional_diagnostic_failure"}});
        return result.complete ? 0 : (result.error.kind==ian::ErrorKind::cancelled ? 3 : 1);
    } catch(const std::exception& e) {
        if(!fs::is_directory(out)) { std::cerr << e.what() << '\n'; return 1; }
        Json status=files ? files->status : Json{{"graph",false},{"scales",false},{"affinity",false},{"complete",false},{"solves",0}};
        status["error"]=e.what(); status["error_kind"]="adapter";
        try { atomic_json(out/"status.json",status); if(files) files->progress("failed",e.what()); }
        catch(...) { std::cerr << "status_write_failed\n"; }
        std::cerr << e.what() << '\n'; return 1;
    }
}
