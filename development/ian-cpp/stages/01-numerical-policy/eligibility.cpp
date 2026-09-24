#include <ian/core.hpp>
#include "retry.hpp"
#include "json_adapter.hpp"
#include "events_json.hpp"
#include <fstream>
#include <filesystem>
#include <iostream>
#include <limits>
struct ThrowRejected final : ian::Observer {
    int solves=0;
    std::ofstream trace;
    explicit ThrowRejected(const std::string& out):trace(out) {}
    void on_event(const ian::Event& e) override {
        trace<<ian::io::event_json(e).dump()<<'\n';trace.flush();
        auto j=ian::io::event_json(e);
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
    if(argc==2) {
        std::ifstream in(argv[1]);Json cases;in>>cases;
        Json rows=Json::array();
        auto number=[](const Json &v)->double {if(v.is_number()) return v.get<double>();return v=="nan"?std::numeric_limits<double>::quiet_NaN():std::numeric_limits<double>::infinity();};
        for(auto c:cases) {
            auto vec=[&](const char *key){std::vector<double> r;for(auto v:c[key])r.push_back(number(v));return r;};
            auto x=vec("x"),z=vec("z"),u=vec("upper"),d=vec("metrics");
            bool usable=ian::detail::usable_return(x,z,u,number(c["objective"]),c["n"].get<size_t>(),c["m"].get<size_t>());
            auto result=ian::detail::classify_return(usable,c["status"]=="Solved",c["status"]=="AlmostSolved",d[0],d[1],d[2],d[3],d[4],d[5]);
            check(result.first==c["expected"][0].get<bool>() && result.second==c["expected"][1].get<bool>());
            rows.push_back(Json{{"name",c["name"]},{"accepted",result.first},{"retry_eligible",result.second}});
        }
        std::cout<<Json{{"passed",true},{"checks",checks},{"cases",rows}}<<'\n';return 0;
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
