#pragma once
#include "files.hpp"
#include "state_json.hpp"
#include "events_json.hpp"
#include <csignal>
#include <regex>
#include <sys/resource.h>
inline volatile std::sig_atomic_t cancel_requested = 0;
inline void request_cancel(int) { cancel_requested = 1; }
namespace ian::io {
inline std::string read_text(const fs::path& path) {
    std::ifstream f(path, std::ios::binary); require(bool(f),"checkpoint_read");
    std::ostringstream s; s << f.rdbuf(); require(!f.bad(),"checkpoint_read"); return s.str();
}
inline fs::path discover(fs::path path) {
    if (fs::is_directory(path)) {
        std::vector<fs::path> files;
        for (const auto& e : fs::directory_iterator(path))
            if (e.is_regular_file() && std::regex_match(e.path().filename().string(),std::regex("checkpoint-[0-9]{6}\\.json")))
                files.push_back(e.path());
        require(!files.empty(),"no_committed_checkpoint");
        std::sort(files.begin(),files.end()); path = files.back();
    }
    return fs::absolute(path);
}
inline Json load_envelope(const fs::path& path, const std::string& input_hash) {
    auto j = Json::parse(read_text(path));
    integer(j.at("checkpoint_schema"),1,1);
    require(j.at("input_file_sha256") == input_hash,"checkpoint_input_mismatch");
    require(j.at("payload_sha256") == ian::digest(j.at("payload").dump()),"checkpoint_digest_mismatch");
    int bytes = integer(j.at("trace_prefix_bytes")), count = integer(j.at("trace_prefix_events"));
    std::ifstream trace(j.at("trace_file").get<std::string>(),std::ios::binary);
    require(bool(trace),"checkpoint_trace_read");
    require(fs::file_size(j.at("trace_file").get<std::string>()) >= size_t(bytes),"checkpoint_trace_short");
    CC_SHA256_CTX context; CC_SHA256_Init(&context);
    int remaining=bytes, lines=0; char buffer[65536];
    while(remaining>0) {
        int wanted=std::min(remaining,int(sizeof(buffer))); trace.read(buffer,wanted);
        require(trace.gcount()==wanted,"checkpoint_trace_short");
        CC_SHA256_Update(&context,buffer,CC_LONG(wanted));
        lines+=std::count(buffer,buffer+wanted,'\n'); remaining-=wanted;
    }
    require(ian::finish_digest(context)==j.at("trace_prefix_sha256"),"checkpoint_trace_mismatch");
    require(lines==count,"checkpoint_trace_count");
    auto parent = j.at("parent_checkpoint").get<std::string>();
    if (!parent.empty()) require(fs::absolute(parent) != fs::absolute(path) &&
        file_hash(parent) == j.at("parent_checkpoint_sha256"),"checkpoint_parent_mismatch");
    else require(j.at("parent_checkpoint_sha256") == "","checkpoint_parent_mismatch");
    return j;
}
struct RestartFiles : Files {
    int interval, cancel_after, fault_at, commits=0, events=0;
    std::string fault, confirmed, pending_resume, origin_checkpoint, input_hash, current_phase="initialization";
    Json times=Json::object();
    bool commit_uncertain=false;
    CC_SHA256_CTX trace_digest; size_t trace_bytes=0;
    using Clock=std::chrono::steady_clock;
    Clock::time_point start=Clock::now(), tick=start;
    RestartFiles(const fs::path& path,const std::string& hash,int every,int stop,std::string injected,int at)
        : Files(path,hash),interval(every),cancel_after(stop),fault_at(at),fault(std::move(injected)),input_hash(hash) {
        fs::create_directory(out/"checkpoints");
        CC_SHA256_Init(&trace_digest);
    }
    void account(const std::string& phase) {
        auto now=Clock::now(); double elapsed=std::chrono::duration<double>(now-tick).count();
        times[current_phase]=times.value(current_phase,0.)+elapsed; tick=now; current_phase=phase;
    }
    Json resources() {
        account(current_phase);
        struct rusage use{}; require(getrusage(RUSAGE_SELF,&use)==0,"resource_read");
        return Json{{"elapsed_seconds",std::chrono::duration<double>(Clock::now()-start).count()},
            {"phase_wall_seconds",times},{"peak_process_rss_bytes",use.ru_maxrss},
            {"rss_convention","Darwin cumulative process peak; not per-phase peaks"}};
    }
    void progress(const std::string& state, const std::string& error="") {
        atomic_json(out/"progress.json",Json{{"state",state},{"error",error},
            {"last_confirmed_checkpoint",confirmed},{"resumable",!confirmed.empty()},
            {"checkpoint_commit_uncertain",commit_uncertain},{"resources",resources()}});
    }
    void on_event(const ian::Event& e) override {
        const auto encoded=event_json(e).dump();
        account(e.phase=="final_affinity_retuning" ? "final_retuning" :
            (e.name=="mapping" || e.name=="processed" ? "initialization" : "pruning"));
        if (!pending_resume.empty()) { confirmed=pending_resume; pending_resume.clear(); }
        Files::on_event(e); ++events;
        size_t offset=0;
        while(offset<encoded.size()) {
            size_t count=std::min(size_t(65536),encoded.size()-offset);
            CC_SHA256_Update(&trace_digest,encoded.data()+offset,CC_LONG(count)); offset+=count;
        }
        CC_SHA256_Update(&trace_digest,"\n",1); trace_bytes+=encoded.size()+1;
    }
    void on_stage(ian::Stage stage,const ian::Result& result) override {
        if (!pending_resume.empty()) { confirmed=pending_resume; pending_resume.clear(); }
        Files::on_stage(stage,result);
    }
    void hook(const std::string& at) {
        if (commits != fault_at) return;
        if (fault == "kill_"+at || fault == "signal_"+at) {
            atomic_json(out/"ready.json",Json{{"point",at},{"commit",commits},{"pid",getpid()}});
            ::raise(SIGSTOP); // Test controller sends SIGKILL or SIGINT then SIGCONT.
        }
        if (fault == at) throw std::runtime_error("injected_storage_"+at);
    }
    void commit(const Json& envelope) {
        ++commits;
        std::ostringstream name; name << "checkpoint-" << std::setw(6) << std::setfill('0') << commits << ".json";
        auto path=out/"checkpoints"/name.str(); auto tmp=path; tmp += ".tmp";
        int fd=-1;
        try {
            hook("open"); fd=::open(tmp.c_str(),O_WRONLY|O_CREAT|O_EXCL,0600); require(fd>=0,"checkpoint_open");
            std::string text=envelope.dump()+"\n";
            size_t split=std::max(size_t(1),text.size()/2), pos=0;
            while(pos<split) { auto n=::write(fd,text.data()+pos,split-pos); require(n>0,"checkpoint_write"); pos+=n; }
            hook("partial_write");
            while(pos<text.size()) { auto n=::write(fd,text.data()+pos,text.size()-pos); require(n>0,"checkpoint_write"); pos+=n; }
            hook("file_sync"); require(::fsync(fd)==0,"checkpoint_flush");
            require(::close(fd)==0,"checkpoint_close"); fd=-1; hook("after_file_sync");
            hook("rename"); require(!fs::exists(path),"checkpoint_exists"); fs::rename(tmp,path);
            commit_uncertain=true; hook("after_rename"); hook("directory_sync");
            fd=::open(path.parent_path().c_str(),O_RDONLY); require(fd>=0,"checkpoint_directory");
            require(::fsync(fd)==0,"checkpoint_directory_flush"); require(::close(fd)==0,"checkpoint_close"); fd=-1;
            confirmed=fs::absolute(path).string(); commit_uncertain=false; hook("after_directory_sync");
        } catch (...) { if(fd>=0) ::close(fd); throw; }
    }
    bool on_checkpoint(const ian::RestartState& s) override {
        bool stop=cancel_requested || (cancel_after>=0 && s.iteration>=cancel_after);
        if (!stop && s.boundary!="graph" && (s.iteration+1)%interval!=0) return true;
        std::string previous=current_phase; account("checkpoint_io");
        try {
            trace.flush(); require(bool(trace),"trace_write");
            int fd=::open((out/"trace.jsonl").c_str(),O_RDONLY); require(fd>=0,"trace_open");
            int synced=::fsync(fd); int closed=::close(fd); require(synced==0 && closed==0,"trace_flush");
            require(fs::file_size(out/"trace.jsonl")==trace_bytes,"trace_byte_count");
            auto payload=state_json(s);
            commit(Json{{"checkpoint_schema",1},{"input_file_sha256",input_hash},
                {"payload",payload},{"payload_sha256",ian::digest(payload.dump())},
                {"parent_checkpoint",origin_checkpoint},
                {"parent_checkpoint_sha256",origin_checkpoint.empty()?"":file_hash(origin_checkpoint)},
                {"trace_file",fs::absolute(out/"trace.jsonl").string()},
                {"trace_prefix_bytes",trace_bytes},{"trace_prefix_events",events},
                {"trace_prefix_sha256",ian::finish_digest(trace_digest)}});
            stop = stop || cancel_requested;
            progress(stop?"cancelled":"running");
        } catch (...) { account(previous); throw; }
        account(previous); return !stop;
    }
};
}
