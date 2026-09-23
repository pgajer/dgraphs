#include <ian/core.hpp>
#include "testing.hpp"
#include "checkpoint.hpp"
#include "events_json.hpp"
#include <iostream>
using namespace ian::io;
struct Trace final : ian::Observer {
    std::ofstream stream;
    explicit Trace(const fs::path& path):stream(path) { require(bool(stream),"trace_open"); }
    void on_event(const ian::Event& e) override { stream<<ian::io::event_json(e).dump()<<'\n'; stream.flush(); require(bool(stream),"trace_write"); }
};
int main(int argc,char** argv) {
    if(argc!=3) return 2;
    fs::path out=argv[2];
    try {
        require(fs::create_directories(out),"output_exists");
        std::ifstream f(argv[1]); Json input; f>>input;
        Trace sink(out/"trace.jsonl");
        Json result=Json::parse(ian::testing::fixed_probe(input.dump(),&sink));
        atomic_json(out/(input.contains("cases")?"stages.json":"result.json"),result);
        atomic_json(out/"status.json",Json{{"complete",true},{"diagnostic_only",true},{"solves",input.contains("cases")?0:result["solves"].get<int>()}});
        return 0;
    } catch(const std::exception& e) { std::cerr<<e.what()<<'\n'; return 1; }
}
