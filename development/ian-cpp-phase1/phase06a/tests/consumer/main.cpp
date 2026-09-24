// External consumer: only the installed public core header and C++ standard library.
#include <ian/core.hpp>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>

void require(bool condition,const char* message) { if(!condition) throw std::runtime_error(message); }
template<class T> void json(std::ostream& out,const T& value) { out<<value; }
void json(std::ostream& out,const std::string& value) { out<<std::quoted(value); }
template<class T> void json(std::ostream& out,const std::vector<T>& values) {
    out<<'['; bool first=true; for(const auto& v:values) { if(!first)out<<','; first=false; json(out,v); } out<<']';
}
void json(std::ostream& out,const ian::Edges& values) {
    out<<'['; bool first=true; for(auto v:values) { if(!first)out<<','; first=false; out<<'['<<v[0]<<','<<v[1]<<']'; } out<<']';
}
void write(const ian::Result& r,const std::string& path,int total_solves,int failed_calls) {
    std::ofstream out(path); require(bool(out),"output_open"); out<<std::setprecision(17)<<"{";
    bool first=true;
    auto field=[&](const char* name,const auto& v) { if(!first)out<<','; first=false; out<<std::quoted(name)<<':';json(out,v); };
    field("complete",r.complete);field("schema_version",r.version);field("policy",r.policy);
    field("edges",r.graph.edges);field("edge_lengths",r.graph.edge_lengths);field("degrees",r.graph.degrees);
    field("components",r.graph.components);field("isolates",r.graph.isolates);field("upper",r.graph.internal_upper);
    field("representatives",r.mapping.representatives);field("member_to_profile",r.mapping.member_to_profile);
    field("specimen_ids",r.mapping.specimen_ids);field("profile_ids",r.mapping.profile_ids);field("participant_ids",r.mapping.participant_ids);
    field("scales",r.scales);field("internal_scales",r.internal_scales);field("affinity",r.affinity);
    field("distance_multiplier",r.graph.distance_multiplier);field("multiplier",r.multiplier);
    field("solves",r.solves);field("total_solves",total_solves);field("invalid_calls_checked",failed_calls);
    out<<"}\n";require(bool(out),"output_write");
}
struct ThrowEvent : ian::Observer { void on_event(const ian::Event&) override { throw std::runtime_error("event_sink_failed"); } };
struct ThrowStage : ian::Observer { void on_stage(ian::Stage,const ian::Result&) override { throw std::runtime_error("stage_sink_failed"); } };
int main(int argc,char** argv) {
    try {
        require(argc==4,"usage: consumer input.txt result.json check|single");
        std::ifstream f(argv[1]);size_t n,p;f>>n>>p;require(bool(f),"input_open");
        ian::Input input;input.features.assign(n,ian::Vector(p));input.distances.assign(n,ian::Vector(n));
        for(auto& row:input.features)for(auto& x:row)f>>x;
        for(auto& row:input.distances)for(auto& x:row)f>>x;
        for(size_t i=0;i<n;++i) { std::string id;f>>std::quoted(id);input.specimen_ids.push_back(id);input.participant_ids.push_back("participant-"+std::to_string(i/2)); }
        require(bool(f),"input_parse");
        auto original=input;
        const auto result=ian::run(input); // No observer or output path supplied to core.
        require(result.complete,"first_run_failed");
        int total=result.solves,failed=0;
        if(std::string(argv[3])=="check") {
            auto second=ian::run(input);total+=second.solves;
            require(second.complete && second.graph.edges==result.graph.edges && second.scales==result.scales && second.affinity==result.affinity,"repeat_changed");
            require(input.features==original.features && input.distances==original.distances && input.specimen_ids==original.specimen_ids,"mutated_input");
            auto duplicate=input;
            duplicate.features.push_back(input.features[0]);duplicate.distances.push_back(input.distances[0]);
            for(auto& row:duplicate.distances)row.push_back(row[0]);
            duplicate.specimen_ids.push_back("duplicate-first");duplicate.participant_ids.push_back("different-participant");
            auto dup=ian::run(duplicate);total+=dup.solves;
            require(dup.complete && dup.graph.edges==result.graph.edges && dup.scales==result.scales && dup.affinity==result.affinity,"duplicate_changed_geometry");
            require(dup.mapping.member_to_profile.back()==0 && dup.mapping.participant_ids.back()=="different-participant","duplicate_lost_identity");
            auto invalid=[&](ian::Input value,const char* code) { auto r=ian::run(value);total+=r.solves;
                require(!r.complete && r.error.code==code && r.solves==0 && !r.graph_valid,"invalid_input_accepted");++failed; };
            auto bad=input;bad.version=2;invalid(bad,"unsupported_schema");
            bad=input;bad.policy="different";invalid(bad,"unsupported_policy");
            bad=input;bad.participant_ids.pop_back();invalid(bad,"participant_shape_or_identity");
            bad=input;bad.participant_ids[0]="";invalid(bad,"participant_shape_or_identity");
            bad=input;bad.distances[0].pop_back();invalid(bad,"input_shape_or_identity");
            bad=input;bad.features[0][0]=std::numeric_limits<double>::quiet_NaN();invalid(bad,"invalid_distances_or_features");
            bad=input;bad.distances[0][1]=std::numeric_limits<double>::infinity();invalid(bad,"invalid_distances_or_features");
            bad=input;bad.specimen_ids[1]=bad.specimen_ids[0];invalid(bad,"input_shape_or_identity");
            ThrowEvent event;auto stopped=ian::run(input,&event);total+=stopped.solves;
            require(!stopped.complete && stopped.error.kind==ian::ErrorKind::observer && stopped.solves==0,"event_exception_unhandled");
            ThrowStage stage;stopped=ian::run(input,&stage);total+=stopped.solves;
            require(!stopped.complete && stopped.error.kind==ian::ErrorKind::observer && stopped.graph_valid && !stopped.scales_valid,"stage_exception_lost_partial_state");
            input.features.clear();input.distances.clear();
            require(result.mapping.specimen_ids==original.specimen_ids && !result.affinity.empty(),"result_borrows_input");
        }
        write(result,argv[2],total,failed);
        std::cout<<"Public API checks passed; optimization solves: "<<total<<'\n';
        return 0;
    } catch(const std::exception& e) { std::cerr<<e.what()<<'\n';return 1; }
}
