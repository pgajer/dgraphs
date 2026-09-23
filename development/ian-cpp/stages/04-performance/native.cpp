#include "store.hpp"
using namespace ian::io;
using Clock=std::chrono::steady_clock;
double now(){return std::chrono::duration<double>(Clock::now().time_since_epoch()).count();}
struct History {int number,attempt,iterations;bool accepted;std::string status;double objective;};
struct Profile:ian::Observer {
 std::ofstream &account; std::ofstream trace;double start,processed=0,graph=0,solver=0;int count=0;ian::Edges initial;std::vector<History> history;
 Profile(std::ofstream& a,const fs::path& p,bool full):account(a){if(full)trace.open(p);}
 void on_event(const ian::Event& e)override{
  if(e.name=="processed"){processed=now();initial=std::get<ian::ProcessedEvent>(e.payload).initial_edges;}
  if(e.name=="graph_stop")graph=now();
  if(const auto* s=std::get_if<ian::SolveRecord>(&e.payload)){
   solver+=s->seconds;history.push_back({s->number,s->attempt,int(s->iterations),s->accepted,s->solver_status,s->objective});
   account<<Json{{"event","attempt"},{"number",s->number}}.dump()<<'\n';account.flush();if(++count>=250)throw std::runtime_error("profile_attempt_limit");
  }
  if(trace.is_open()){trace<<event_json(e).dump()<<'\n';trace.flush();}
 }
};
int main(int argc,char**argv){
 try{
  double began=now();auto schedule=Json::parse(read_text(argv[1]));fs::path out=argv[2];fs::create_directories(out);
  std::vector<ian::Input> inputs;for(auto& c:schedule["cases"])inputs.push_back(parse_input(Json::parse(read_text(c["path"]))));
  std::ofstream account(out/"account.jsonl");atomic_json(out/"setup.json",Json{{"seconds",now()-began},{"source",ian::source_identity()}});
  int entry=0;for(size_t k=0;k<inputs.size();k++)for(int rep=0;rep<schedule["repeats"].get<int>();rep++,entry++){
   auto folder=out/std::to_string(entry);fs::create_directory(folder);account<<Json{{"event","entry"},{"entry",entry},{"fixture",schedule["cases"][k]["name"]}}.dump()<<'\n';account.flush();
   Profile p(account,folder/"trace.jsonl",schedule["full"]);p.start=now();auto r=ian::run(inputs[k],&p);double end=now();
   Json h=Json::array();for(auto&s:p.history)h.push_back(Json{{"number",s.number},{"attempt",s.attempt},{"iterations",s.iterations},{"accepted",s.accepted},{"solver_status",s.status},{"objective",s.objective}});
   auto result=Json{{"complete",r.complete},{"initial_edges",p.initial},{"edges",r.graph.edges},{"scales",r.scales},{"affinity",r.affinity},{"history",h}};
   atomic_json(folder/"result.json",result);atomic_json(folder/"timing.json",Json{{"fixture",schedule["cases"][k]["name"]},{"rep",rep},{"total",end-p.start},{"initialization",p.processed-p.start},{"pruning",p.graph-p.processed},{"final",end-p.graph},{"solver_recorded",p.solver},{"solves",r.solves}});
   account<<Json{{"event","returned"},{"entry",entry},{"solves",r.solves},{"complete",r.complete}}.dump()<<'\n';account.flush();require(r.complete,"incomplete_engine");
  }
  return 0;
 }catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}
}
