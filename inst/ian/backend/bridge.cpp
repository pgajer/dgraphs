// Internal optional dgraphs adapter. Numerical core policy is unchanged.
#include <Rcpp.h>
#include <csignal>
#include <R_ext/Utils.h>
#include <R_ext/Rdynload.h>
#include <ian/core.hpp>
#include "core/src/numeric.hpp"
#include "core/src/testing.hpp"
using Json = ian::detail::Json;
namespace {
Rcpp::RObject json_r(const Json& j) {
 if(j.is_null()) return R_NilValue;
 if(j.is_boolean()) return Rcpp::wrap(j.get<bool>());
 if(j.is_number_integer()) return Rcpp::wrap(j.get<int>());
 if(j.is_number()) return Rcpp::wrap(j.get<double>());
 if(j.is_string()) return Rcpp::wrap(j.get<std::string>());
 Rcpp::List out(j.size());
 if(j.is_object()) { Rcpp::CharacterVector names(j.size()); int k=0; for(auto it=j.begin();it!=j.end();++it) {names[k]=it.key();out[k++]=json_r(it.value());} out.attr("names")=names; }
 else {int k=0;for(auto& v:j)out[k++]=json_r(v);}
 return out;
}
Rcpp::IntegerMatrix edges(const ian::Edges& e) {Rcpp::IntegerMatrix out(e.size(),2);for(size_t i=0;i<e.size();i++)for(int j=0;j<2;j++)out(i,j)=e[i][j]+1;return out;}
Rcpp::NumericMatrix matrix(const ian::Matrix& a) {size_t n=a.size(),p=n?a[0].size():0;Rcpp::NumericMatrix out(n,p);for(size_t i=0;i<n;i++)for(size_t j=0;j<p;j++)out(i,j)=a[i][j];return out;}
ian::Matrix matrix(SEXP value) {Rcpp::NumericMatrix x(value);ian::Matrix a(x.nrow(),ian::Vector(x.ncol()));for(int i=0;i<x.nrow();i++)for(int j=0;j<x.ncol();j++)a[i][j]=x(i,j);return a;}
Rcpp::IntegerVector indices(const ian::Indices& x) {Rcpp::IntegerVector out=Rcpp::wrap(x);for(auto& v:out)++v;return out;}
void check_interrupt(void*) {R_CheckUserInterrupt();}
struct Sink : ian::Observer {
 bool detailed, interrupted=false, inject_interrupt=false; int max_solves, solves=0;
 Json events=Json::array(), history=Json::array();
 ian::Edges initial,last; bool has_initial=false,has_last=false;
 explicit Sink(bool detail,int budget):detailed(detail),max_solves(budget) {}
 void on_event(const ian::Event& e) override {
   auto j=Json::parse(e.json);
   if(e.name=="processed") {initial=j.at("initial_edges").get<ian::Edges>();last=initial;has_initial=has_last=true;}
   if(e.name=="pruned") {last=j.at("edges").get<ian::Edges>();has_last=true;}
   if(e.name=="solve") {
     ++solves;
     Json small=j;
     for(auto key:{"A_data","A_indices","A_indptr","A_shape","b","c","upper","active","scales","dual"})small.erase(key);
     history.push_back(small);
   }
   if(detailed) events.push_back(j);
   if(inject_interrupt && e.name=="processed") std::raise(SIGINT);
   if(!R_ToplevelExec(check_interrupt,nullptr)) {interrupted=true;throw std::runtime_error("R_user_interrupt");}
   // Guard before the next solver allocation; an already completed solve is retained.
   if(e.name=="solve" && solves>=max_solves)throw std::runtime_error("adapter_solve_budget");
 }
};
Rcpp::List graph(const ian::Edges& e,const ian::Result& result,const ian::Input& input) {
 Rcpp::NumericVector lengths(e.size());
 for(size_t i=0;i<e.size();++i) lengths[i]=input.distances[result.mapping.representatives[e[i][0]]][result.mapping.representatives[e[i][1]]];
 return Rcpp::List::create(Rcpp::Named("edges")=edges(e),Rcpp::Named("lengths")=lengths);
}
}
extern "C" SEXP dgraphs_ian_run(SEXP features,SEXP distances,SEXP ids,SEXP participants,SEXP detailed,SEXP max_solves,SEXP fault) {
 BEGIN_RCPP
 ian::Input in;in.features=matrix(features);in.distances=matrix(distances);in.specimen_ids=Rcpp::as<std::vector<std::string>>(ids);in.participant_ids=Rcpp::as<std::vector<std::string>>(participants);
 Sink sink(Rcpp::as<bool>(detailed),Rcpp::as<int>(max_solves));
 std::string injection=Rcpp::as<std::string>(fault);
 sink.inject_interrupt=injection=="interrupt_after_initial";
 auto r=(injection=="none" || sink.inject_interrupt)?ian::run(in,&sink):ian::testing::run_with_fault(in,&sink,injection);
 if(sink.interrupted)r.error={ian::ErrorKind::cancelled,"R_user_interrupt","Interrupted at an engine event boundary; no live solver was abandoned."};
 return Rcpp::List::create(
 Rcpp::Named("complete")=r.complete,
 Rcpp::Named("error")=Rcpp::List::create(Rcpp::Named("kind")=ian::error_kind_name(r.error.kind),Rcpp::Named("code")=r.error.code,Rcpp::Named("message")=r.error.message),
 Rcpp::Named("initial")=sink.has_initial?SEXP(graph(sink.initial,r,in)):R_NilValue,
 Rcpp::Named("last")=sink.has_last?SEXP(graph(sink.last,r,in)):R_NilValue,
 Rcpp::Named("converged")=r.graph_valid?SEXP(graph(r.graph.edges,r,in)):R_NilValue,
 Rcpp::Named("mapping")=Rcpp::List::create(Rcpp::Named("representatives")=indices(r.mapping.representatives),Rcpp::Named("member_to_profile")=indices(r.mapping.member_to_profile),Rcpp::Named("specimen_ids")=r.mapping.specimen_ids,Rcpp::Named("profile_ids")=r.mapping.profile_ids,Rcpp::Named("participant_ids")=r.mapping.participant_ids),
 Rcpp::Named("scales")=r.scales,Rcpp::Named("affinity")=matrix(r.affinity),
 Rcpp::Named("diagnostics")=Rcpp::List::create(Rcpp::Named("solves")=r.solves,Rcpp::Named("last_iteration")=r.last_iteration,Rcpp::Named("distance_multiplier")=r.graph.distance_multiplier,Rcpp::Named("multiplier")=r.multiplier,Rcpp::Named("stats")=r.stats,Rcpp::Named("weighted_stats")=r.weighted_stats,Rcpp::Named("scales_valid")=r.scales_valid,Rcpp::Named("affinity_valid")=r.affinity_valid,Rcpp::Named("graph_converged")=r.graph_valid,Rcpp::Named("solver_history")=json_r(sink.history),Rcpp::Named("trace")=json_r(sink.events)),
 Rcpp::Named("backend")=Rcpp::List::create(Rcpp::Named("numerical_policy")=r.policy,Rcpp::Named("source_identity")=ian::source_identity(),Rcpp::Named("configuration_identity")=ian::configuration_identity(),Rcpp::Named("solver")="Clarabel 0.11.1 / QDLDL"));
 END_RCPP
}
extern "C" void R_init_dgraphs_ian(DllInfo* dll) {
 static const R_CallMethodDef methods[]={{"dgraphs_ian_run",(DL_FUNC)&dgraphs_ian_run,7},{nullptr,nullptr,0}};
 R_registerRoutines(dll,nullptr,methods,nullptr,nullptr);R_useDynamicSymbols(dll,FALSE);R_forceSymbols(dll,TRUE);
}
