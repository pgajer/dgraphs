// Standalone exact-path IAN prototype. See IAN-LICENSE.txt and NUMPY-LICENSE.txt.
#include "numeric.hpp"
#include "solver.hpp"
#include <CommonCrypto/CommonDigest.h>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iomanip>
#include <sstream>
#include <map>
#include <set>
#include <fcntl.h>
#include <unistd.h>
namespace fs=std::filesystem;
using Clock=std::chrono::steady_clock;
std::string file_hash(const fs::path& p){std::ifstream f(p,std::ios::binary);require(bool(f),"hash_read");CC_SHA256_CTX ctx;CC_SHA256_Init(&ctx);char buf[65536];while(f){f.read(buf,sizeof(buf));if(f.gcount())CC_SHA256_Update(&ctx,buf,CC_LONG(f.gcount()));}unsigned char result[CC_SHA256_DIGEST_LENGTH];CC_SHA256_Final(result,&ctx);std::ostringstream s;for(auto c:result)s<<std::hex<<std::setw(2)<<std::setfill('0')<<int(c);return s.str();}
void atomic_json(const fs::path& p,const Json& value){std::string text=value.dump()+"\n";fs::path tmp=p;tmp+=".tmp";int fd=::open(tmp.c_str(),O_WRONLY|O_CREAT|O_EXCL,0600);require(fd>=0,"checkpoint_open");size_t at=0;while(at<text.size()){ssize_t n=::write(fd,text.data()+at,text.size()-at);if(n<=0){::close(fd);throw std::runtime_error("checkpoint_write");}at+=n;}int flushed=::fsync(fd);int closed=::close(fd);require(flushed==0&&closed==0,"checkpoint_flush");fs::rename(tmp,p);int dir=::open(p.parent_path().c_str(),O_RDONLY);require(dir>=0,"checkpoint_directory");int sync=::fsync(dir);::close(dir);require(sync==0,"checkpoint_directory_flush");}
struct Input{Mat D;Json mapping;};
Input preprocess(const Json& in){
 Mat X=in.at("features").get<Mat>(),D=in.at("distances").get<Mat>();auto ids=in.at("ids").get<std::vector<std::string>>();size_t n=X.size();require(n>0&&D.size()==n&&ids.size()==n,"input_shape_or_identity");std::set<std::string> distinct(ids.begin(),ids.end());require(distinct.size()==n,"input_shape_or_identity");
 for(size_t i=0;i<n;i++){require(X[i].size()==X[0].size()&&D[i].size()==n,"input_shape_or_identity");for(double v:X[i])require(std::isfinite(v),"invalid_distances_or_features");for(double v:D[i])require(std::isfinite(v)&&v>=0,"invalid_distances_or_features");}
 for(size_t i=0;i<n;i++)for(size_t j=0;j<n;j++)require(D[i][j]==D[j][i]&&(i!=j||D[i][j]==0),"invalid_distances_or_features");
 std::map<Vec,int> lookup;Ids reps,mapping;for(size_t i=0;i<n;i++){auto it=lookup.find(X[i]);if(it==lookup.end()){int id=reps.size();lookup[X[i]]=id;reps.push_back(i);mapping.push_back(id);}else mapping.push_back(it->second);}
 Mat U(reps.size(),Vec(reps.size()));for(size_t i=0;i<reps.size();i++)for(size_t j=0;j<reps.size();j++)U[i][j]=D[reps[i]][reps[j]];
 for(size_t i=0;i<n;i++)for(size_t j=0;j<n;j++)require(D[i][j]==U[mapping[i]][mapping[j]],"duplicate_distance_inconsistency");require(reps.size()>=2,"fewer_than_two_unique_profiles");double minimum=std::numeric_limits<double>::infinity();for(size_t i=0;i<U.size();i++)for(size_t j=i+1;j<U.size();j++)minimum=std::min(minimum,U[i][j]);require(!close(minimum,0),"nearly_identical_distinct_profiles");
 std::vector<std::string> profileids;for(int i:reps)profileids.push_back(ids[i]);return {U,Json{{"representatives",reps},{"member_to_profile",mapping},{"specimen_ids",ids},{"profile_ids",profileids}}};
}
struct Engine{
 fs::path out;std::ofstream trace;Json metadata,status={{"graph",false},{"scales",false},{"affinity",false},{"complete",false},{"error",nullptr}};Mat D,D2;Edges edges;Ids deg;Vec upper;double scl=1,C=0;int iteration=0,solves=0;bool cache=false;std::string phase="initial",inject;
 Engine(fs::path folder,std::string injection):out(folder),trace(folder/"trace.jsonl"),inject(injection){}
 void emit(Json event){event["iteration"]=iteration;event["phase"]=phase;trace<<event.dump()<<'\n';trace.flush();require(bool(trace),"trace_write");}
 Json graph_data(){return Json{{"edges",edges},{"degrees",deg},{"upper",upper},{"components",components(D.size(),edges)},{"isolates",isolates(deg)}};}
 void checkpoint(const std::string& stage,Json data){for(auto it=metadata.begin();it!=metadata.end();++it)data[it.key()]=it.value();data["stage"]=stage;data["status"]="validated";auto path=out/(stage+".json");require(!fs::exists(path),"checkpoint_exists");atomic_json(path,data);status[stage]=true;status[stage+"_sha256"]=file_hash(path);atomic_json(out/"status.json",status);}
 Vec solve(bool parameterized){auto r=solve_lp(D,edges,upper,C,parameterized,inject=="invalid_solver"&&solves==0);r.record["number"]=solves++;emit(r.record);require(r.record["accepted"].get<bool>(),"invalid_solver_result");return r.x;}
 Mat kernel(const Vec& s){Mat K=affinity(D2,s,deg);emit(Json{{"event","kernel"},{"affinity",K},{"scales",s}});return K;}
 Vec volume(const Vec& s,const Mat* K){Vec v=volumes(D2,s,deg,K);emit(Json{{"event","volume"},{"ratios",v},{"scales",s},{"degrees",deg},{"multiscale",K!=nullptr}});return v;}
 struct Tune{Vec scales,ratios;double mu;Mat K;};
 Tune tune(bool weighted){
  if(weighted)phase="final_affinity_retuning";double lo=std::min(C,.5),hi=std::max(C,1.);Json begin=graph_data();begin.update(Json{{"event","tune_start"},{"C",C},{"minC",lo},{"maxC",hi},{"recycled",cache}});emit(begin);
  Tune result;int nits=0;
  auto evaluate=[&](bool parameterized,int index){result.scales=solve(parameterized);if(weighted)result.K=kernel(result.scales);result.ratios=volume(result.scales,weighted?&result.K:nullptr);Vec positive;for(double x:result.ratios)if(x>0)positive.push_back(x);result.mu=median(positive);emit(Json{{"event","retune_eval"},{"C",C},{"median",result.mu},{"minC",lo},{"maxC",hi},{"bisection_index",index},{"median_margin",std::abs(result.mu-1)-.1},{"lower_margin",std::abs(C-lo)-(1e-8+1e-5*std::abs(lo))},{"upper_margin",std::abs(C-hi)-(1e-8+1e-5*std::abs(hi))}});};
  auto centered=[&](){return std::abs(result.mu-1)<=.1;};auto boundary=[&](){return (result.mu-1>.1&&close(C,lo))||(result.mu-1<-.1&&close(C,hi));};
  auto advance=[&](){if(result.mu-1>0)hi=C;else lo=C;C=lo+.5*(hi-lo);};
  auto stop=[&](){emit(Json{{"event","retune_stop"},{"C",C},{"median",result.mu},{"minC",lo},{"maxC",hi},{"median_target_met",centered()},{"boundary_stop",boundary()},{"cap_reached",nits>=20},{"bisection_updates",nits}});require(nits<20,"retuning_cap");};
  if(cache){evaluate(false,-1);if(centered()||boundary()){stop();return result;}advance();}
  for(nits=0;nits<20;){evaluate(true,nits);if(centered()||boundary())break;advance();nits++;}cache=true;stop();return result;
 }
 void run(const Json& input,const fs::path& file){auto began=Clock::now();Input p=preprocess(input);metadata={{"input_sha256",file_hash(file)},{"source_sha256",SOURCE_HASH},{"configuration_sha256",CONFIG_HASH},{"mapping",p.mapping}};Json map=p.mapping;map["event"]="mapping";emit(map);D=p.D;D2=D;double minimum=std::numeric_limits<double>::infinity();for(size_t i=0;i<D.size();i++)for(size_t j=i+1;j<D.size();j++)minimum=std::min(minimum,D[i][j]);scl=1/minimum;double scl2=scl*scl;for(size_t i=0;i<D.size();i++)for(size_t j=0;j<D.size();j++){D2[i][j]=(D[i][j]*D[i][j])*scl2;D[i][j]*=scl;}edges=gabriel(D2);deg=degrees(D.size(),edges);upper=upper_bounds(D,edges);emit(Json{{"event","processed"},{"D1",D},{"D2",D2},{"scl",scl},{"initial_edges",edges}});require(isolates(deg).empty(),"unsupported_initial_isolate");
  auto nbr=neighbors(D,edges);Vec ratios(D.size());for(size_t i=0;i<D.size();i++){int k=deg[i];int mid=std::min(k-1,std::max(1,int(std::ceil(k/2.))-1));ratios[i]=D[i][nbr[i][k-mid-1]]/upper[i];}C=std::min(std::max(.55,median(ratios)),.95);bool converged=false;Vec last_stats;
  for(iteration=0;iteration<(inject=="pruning_cap"?1:2000);iteration++){phase=iteration==0?"initial":"post_prune";Json event=graph_data();event.update(Json{{"event","iteration"},{"scl",scl}});emit(event);auto t=tune(false);last_stats=t.ratios;auto dec=decision(t.ratios,t.mu);emit(dec);Ids candidates=dec["candidates"].get<Ids>();if(candidates.empty()){converged=true;break;}size_t limit=std::max(1,int(.1*candidates.size()));candidates.resize(std::min(limit,candidates.size()));auto removed=prune(edges,D,candidates);deg=degrees(D.size(),edges);upper=upper_bounds(D,edges);event=graph_data();event.update(Json{{"event","pruned"},{"selected",candidates},{"removed",removed}});emit(event);}
  if(!converged&&iteration>0)--iteration; // match adapter STATE.it: last visited iteration
  phase="final_affinity_retuning";Json stop=graph_data();stop.update(Json{{"event","graph_stop"},{"converged",converged},{"reason",converged?"no_pruning_candidates":"pruning_iteration_cap"}});emit(stop);require(converged,"pruning_iteration_cap");checkpoint("graph",graph_data());if(inject=="after_graph")throw std::runtime_error("injected_after_graph");
  auto final=tune(true);Vec original=final.scales;for(double& x:original)x/=scl;checkpoint("scales",Json{{"scales",original},{"internal_scales",final.scales},{"scl",scl},{"C",C}});if(inject=="after_scales")throw std::runtime_error("injected_after_scales");
  for(size_t i=0;i<D.size();i++)for(size_t j=0;j<D.size();j++)require(std::isfinite(final.K[i][j])&&final.K[i][j]>=0&&final.K[i][j]<=1&&final.K[i][j]==final.K[j][i]&&(i!=j||final.K[i][i]==(deg[i]?1:0)),"invalid_affinity");
  checkpoint("affinity",Json{{"affinity",final.K},{"scales",original},{"C",C}});if(inject=="after_affinity")throw std::runtime_error("injected_after_affinity");emit(Json{{"event","complete"},{"edges",edges},{"scales",original},{"affinity",final.K},{"stats",last_stats},{"wstats",final.ratios},{"isolates",isolates(deg)}});status["complete"]=true;status["solves"]=solves;status["seconds"]=std::chrono::duration<double>(Clock::now()-began).count();atomic_json(out/"status.json",status);
 }
};
Json stages(const Json& in){Json results;auto dup=preprocess(in["duplicate"]);results["duplicate"]=dup.mapping;results["gabriel"]=Json::array();for(auto f:in["gabriel"])results["gabriel"].push_back(Json{{"name",f["name"]},{"edges",gabriel(f["D2"].get<Mat>())}});results["decisions"]=Json::array();for(auto d:in["decisions"]){auto out=decision(d["stats"].get<Vec>(),d["median"].get<double>());out["name"]=d["name"];results["decisions"].push_back(out);}auto e=in["pruning"]["edges"].get<Edges>();auto removed=prune(e,in["pruning"]["distances"].get<Mat>(),in["pruning"]["candidates"].get<Ids>());results["pruning"]={{"removed",removed},{"edges",e}};
 auto c=in["disconnected"];Mat D=c["distances"].get<Mat>(),D2=D;for(auto& row:D2)for(auto& x:row)x=x*x;Edges edges=c["edges"].get<Edges>();Ids deg=degrees(D.size(),edges);Vec u=upper_bounds(D,edges);auto sol=solve_lp(D,edges,u,c["C"].get<double>(),true);require(sol.record["accepted"],"stage_solve_invalid");Mat K=affinity(D2,sol.x,deg);results["disconnected"]={{"solve",sol.record},{"components",components(D.size(),edges)},{"ratios",volumes(D2,sol.x,deg)},{"affinity",K},{"weighted_ratios",volumes(D2,sol.x,deg,&K)}};
 auto cut=in["affinity_cutoffs"];results["affinity_cutoffs"]=affinity(cut["D2"].get<Mat>(),cut["scales"].get<Vec>(),cut["degrees"].get<Ids>());return results;}
int main(int argc,char** argv){if(argc<3||argc>4){std::cerr<<"ian_engine input.json new-output [invalid_solver|after_graph|after_scales|after_affinity|pruning_cap]\n";return 2;}fs::path out=argv[2];if(!fs::create_directories(out)){std::cerr<<"output_exists\n";return 2;}std::unique_ptr<Engine> engine;try{std::ifstream file(argv[1]);Json in;file>>in;if(in.value("kind","")=="stages"){atomic_json(out/"stages.json",stages(in));return 0;}engine=std::make_unique<Engine>(out,argc==4?argv[3]:"none");engine->run(in,argv[1]);return 0;}catch(const std::exception& exc){Json status=engine?engine->status:Json{{"graph",false},{"scales",false},{"affinity",false},{"complete",false}};status["error"]=exc.what();try{atomic_json(out/"status.json",status);}catch(...){std::cerr<<"status_write_failed\n";}std::cerr<<exc.what()<<'\n';return 1;}}
