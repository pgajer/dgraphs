#include <ian/core.hpp>
#include "retry.hpp"
#include "json_adapter.hpp"
#include <fstream>
#include <filesystem>
#include <iostream>
#include <limits>
struct ThrowRejected final : ian::Observer {
    int solves=0;
    std::ofstream trace;
    explicit ThrowRejected(const std::string& out):trace(out) {}
    void on_event(const ian::Event& e) override {
        trace<<e.json<<'\n';trace.flush();
        auto j=ian::io::Json::parse(e.json);
        if(j.at("event")=="solve") { ++solves; if(!j.at("accepted").get<bool>()) throw std::runtime_error("test_observer_rejection"); }
    }
};
int main(int argc,char** argv) {
    using ian::detail::retry_eligible;
    using ian::io::Json;
    int checks=0;
    auto check=[&](bool b){++checks;if(!b)throw std::runtime_error("check_failed_"+std::to_string(checks));};
    check(!retry_eligible(true,0,0,0,0,0,0));
    check(!retry_eligible(false,0,1e-6,1e-6,0,0,0));
    check(!retry_eligible(true,1e-6,1e-6,1e-6,0,0,0));
    check(!retry_eligible(true,0,1e-7,1e-7,1e-7,1e-7,1e-7));
    check(retry_eligible(true,0,1e-6,1e-6,0,0,0));
    check(retry_eligible(true,0,0,0,1e-6,0,0));
    check(retry_eligible(true,0,0,0,0,1e-6,0));
    check(retry_eligible(true,0,0,0,0,0,1e-6));
    for(int k=0;k<6;++k) for(double v:{std::numeric_limits<double>::infinity(),std::numeric_limits<double>::quiet_NaN()}) {
        double d[6]={0,1e-6,1e-6,0,0,0};d[k]=v;
        check(!retry_eligible(true,d[0],d[1],d[2],d[3],d[4],d[5]));
    }
    if(argc==3) {
        std::filesystem::create_directories(argv[2]);
        std::ifstream in(argv[1]);Json j;in>>j;
        ThrowRejected observer(std::string(argv[2])+"/trace.jsonl");
        auto result=ian::run(ian::io::parse_input(j),&observer);
        check(result.error.kind==ian::ErrorKind::observer);
        check(observer.solves==2 && result.solves==2);
        check(!result.complete && !result.graph_valid && !result.scales_valid && !result.affinity_valid);
        std::ofstream out(std::string(argv[2])+"/result.json");out<<ian::io::result_json(result)<<'\n';
    }
    std::cout<<Json{{"passed",true},{"checks",checks}}<<'\n';
}
