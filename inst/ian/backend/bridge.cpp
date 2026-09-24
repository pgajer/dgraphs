// Internal optional dgraphs adapter. Numerical core policy is unchanged.
#include <Rcpp.h>
#include <csignal>
#include <R_ext/Utils.h>
#include <R_ext/Rdynload.h>
#include <ian/core.hpp>
#include "core/src/event_fields.hpp"
#include <map>
#include "r_dimensions.hpp"
#include <set>
#include "core/src/testing.hpp"

namespace {
// Direct typed-to-R projection. Arrays intentionally retain the historical trace
// list shape; top-level graph/mapping/scales objects keep their R-specific types.
template<class T> Rcpp::RObject r_object(const T&);
template<class T> Rcpp::RObject r_object(const std::vector<T>&);
template<class T,std::size_t N> Rcpp::RObject r_object(const std::array<T,N>&);
struct RFields {
 std::map<std::string,Rcpp::RObject> values;
 bool summary=false;
 template<class T> void field(const char* name,const T& value) {
   static const std::set<std::string> dense{"A_data","A_indices","A_indptr","A_shape","b","c","upper","active","scales","dual","backend_rhs","backend_primal","backend_dual","backend_slack"};
   if(summary && dense.count(name))return;
   values.emplace(name,r_object(value));
 }
 Rcpp::List finish() const {
   Rcpp::List out(values.size()); Rcpp::CharacterVector names(values.size());int k=0;
   for(const auto& p:values){names[k]=p.first;out[k++]=p.second;}
   out.attr("names")=names;return out;
 }
};
template<class T> Rcpp::RObject r_object(const T& value) {
 if constexpr(std::is_same_v<T,bool> || std::is_same_v<T,std::string>)return Rcpp::wrap(value);
 else if constexpr(std::is_integral_v<T>) {
   if(ian_r::integer_as_double(value))return Rcpp::wrap(static_cast<double>(value));
   return Rcpp::wrap(static_cast<int>(value));
 }
 else if constexpr(std::is_floating_point_v<T>) {
   // JSON trace schema previously represented non-finite numbers as null.
   return std::isfinite(value)?Rcpp::RObject(Rcpp::wrap(value)):Rcpp::RObject(R_NilValue);
 } else {RFields out;ian::serialization::fields(out,value);return out.finish();}
}
template<class T> Rcpp::RObject r_object(const std::vector<T>& value) {
 if(value.size()>std::size_t(R_XLEN_T_MAX))Rcpp::stop("IAN vector exceeds the R representation range");
 Rcpp::List out(value.size());for(size_t k=0;k<value.size();++k)out[k]=r_object(value[k]);return out;
}
template<class T,std::size_t N> Rcpp::RObject r_object(const std::array<T,N>& value) {
 Rcpp::List out(N);for(size_t k=0;k<N;++k)out[k]=r_object(value[k]);return out;
}
Rcpp::IntegerMatrix edges(const ian::Edges& e) {ian_r::matrix_dimensions(e.size(),2,R_XLEN_T_MAX);Rcpp::IntegerMatrix out(e.size(),2);for(size_t i=0;i<e.size();i++)for(int j=0;j<2;j++)out(i,j)=e[i][j]+1;return out;}
Rcpp::NumericMatrix matrix(const ian::Matrix& a) {size_t n=a.size(),p=n?a[0].size():0;ian_r::matrix_dimensions(n,p,R_XLEN_T_MAX);Rcpp::NumericMatrix out(n,p);for(size_t i=0;i<n;i++)for(size_t j=0;j<p;j++)out(i,j)=a[i][j];return out;}
ian::Matrix matrix(SEXP value) {Rcpp::NumericMatrix x(value);ian_r::matrix_dimensions(x.nrow(),x.ncol(),R_XLEN_T_MAX);ian::Matrix a(x.nrow(),ian::Vector(x.ncol()));for(int i=0;i<x.nrow();i++)for(int j=0;j<x.ncol();j++)a[i][j]=x(i,j);return a;}
Rcpp::IntegerVector indices(const ian::Indices& x) {Rcpp::IntegerVector out=Rcpp::wrap(x);for(auto& v:out)++v;return out;}
void check_interrupt(void*) {R_CheckUserInterrupt();}
struct Sink : ian::Observer {
 bool detailed, interrupted=false, inject_interrupt=false; int max_solves, solves=0;
 Rcpp::List events, history;
 ian::Edges initial,last; bool has_initial=false,has_last=false;
 explicit Sink(bool detail,int budget):detailed(detail),max_solves(budget) {}
 void on_event(const ian::Event& e) override {
   if(const auto* p=std::get_if<ian::ProcessedEvent>(&e.payload)) {initial=p->initial_edges;last=initial;has_initial=has_last=true;}
   if(const auto* p=std::get_if<ian::PruningAttempt>(&e.payload)) if(p->action=="removed")last.erase(std::find(last.begin(),last.end(),p->edge));
   if(const auto* p=std::get_if<ian::PrunedEvent>(&e.payload)) {last=p->graph.edges;has_last=true;}
   if(std::holds_alternative<ian::SolveRecord>(e.payload)) {
     ++solves;
     RFields out;out.summary=true;ian::serialization::fields(out,e);
     history.push_back(out.finish());
   }
   if(detailed) events.push_back(r_object(e));
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
extern "C" SEXP dgraphs_ian_run_v3(SEXP features,SEXP distances,SEXP ids,SEXP participants,SEXP detailed,SEXP max_solves,SEXP fault,SEXP policy,SEXP preserve_connectivity) {
 BEGIN_RCPP
 Rcpp::NumericMatrix feature_view(features),distance_view(distances);
 ian_r::input_dimensions(feature_view.nrow(),feature_view.ncol(),R_XLEN_T_MAX);
 if(distance_view.nrow()!=feature_view.nrow() || distance_view.ncol()!=feature_view.nrow())
     Rcpp::stop("IAN distance dimensions must match the feature rows");
 ian::Input in;in.preserve_connectivity=Rcpp::as<bool>(preserve_connectivity);in.policy=Rcpp::as<std::string>(policy);in.features=matrix(features);in.distances=matrix(distances);in.specimen_ids=Rcpp::as<std::vector<std::string>>(ids);in.participant_ids=Rcpp::as<std::vector<std::string>>(participants);
 Sink sink(Rcpp::as<bool>(detailed),Rcpp::as<int>(max_solves));
 std::string injection=Rcpp::as<std::string>(fault);
 sink.inject_interrupt=injection=="interrupt_after_initial";
 auto r=(injection=="none" || sink.inject_interrupt)?ian::run(in,&sink):ian::testing::run_with_fault(in,&sink,injection);
 if(sink.interrupted)r.error={ian::ErrorKind::cancelled,"R_user_interrupt","Interrupted at an engine event boundary; no live solver was abandoned."};
 Rcpp::List output=Rcpp::List::create(
 Rcpp::Named("complete")=r.complete,
 Rcpp::Named("error")=Rcpp::List::create(Rcpp::Named("kind")=ian::error_kind_name(r.error.kind),Rcpp::Named("code")=r.error.code,Rcpp::Named("message")=r.error.message),
 Rcpp::Named("initial")=sink.has_initial?SEXP(graph(sink.initial,r,in)):R_NilValue,
 Rcpp::Named("last")=sink.has_last?SEXP(graph(sink.last,r,in)):R_NilValue,
 Rcpp::Named("converged")=r.graph_valid?SEXP(graph(r.graph.edges,r,in)):R_NilValue,
 Rcpp::Named("mapping")=Rcpp::List::create(Rcpp::Named("representatives")=indices(r.mapping.representatives),Rcpp::Named("member_to_profile")=indices(r.mapping.member_to_profile),Rcpp::Named("specimen_ids")=r.mapping.specimen_ids,Rcpp::Named("profile_ids")=r.mapping.profile_ids,Rcpp::Named("participant_ids")=r.mapping.participant_ids),
 Rcpp::Named("scales")=r.scales,Rcpp::Named("affinity")=matrix(r.affinity),
 Rcpp::Named("diagnostics")=Rcpp::List::create(Rcpp::Named("solves")=r.solves,Rcpp::Named("last_iteration")=r.last_iteration,Rcpp::Named("distance_multiplier")=r.graph.distance_multiplier,Rcpp::Named("multiplier")=r.multiplier,Rcpp::Named("stats")=r.stats,Rcpp::Named("weighted_stats")=r.weighted_stats,Rcpp::Named("scales_valid")=r.scales_valid,Rcpp::Named("affinity_valid")=r.affinity_valid,Rcpp::Named("graph_converged")=r.graph_valid,Rcpp::Named("solver_history")=sink.history,Rcpp::Named("trace")=sink.events),
 Rcpp::Named("backend")=Rcpp::List::create(Rcpp::Named("numerical_policy")=r.policy,Rcpp::Named("source_identity")=ian::source_identity(),Rcpp::Named("configuration_identity")=ian::configuration_identity(),Rcpp::Named("solver")="Clarabel 0.11.1 / QDLDL"));
 if(r.preserve_connectivity) {
   Rcpp::List diagnostics=output["diagnostics"];diagnostics["connectivity"]=r_object(r.pruning);output["diagnostics"]=diagnostics;
   Rcpp::List backend=output["backend"];backend["pruning_policy"]=ian::connected_pruning_policy;output["backend"]=backend;
 }
 return output;
 END_RCPP
}
extern "C" SEXP dgraphs_ian_run_v2(SEXP features,SEXP distances,SEXP ids,SEXP participants,SEXP detailed,SEXP max_solves,SEXP fault,SEXP policy,SEXP preserve_connectivity) {
 return dgraphs_ian_run_v3(features,distances,ids,participants,detailed,max_solves,fault,policy,preserve_connectivity);
}
extern "C" SEXP dgraphs_ian_run(SEXP features,SEXP distances,SEXP ids,SEXP participants,SEXP detailed,SEXP max_solves,SEXP fault,SEXP policy) {
 SEXP flag=PROTECT(Rf_ScalarLogical(0));
 SEXP result=dgraphs_ian_run_v2(features,distances,ids,participants,detailed,max_solves,fault,policy,flag);
 UNPROTECT(1);return result;
}
extern "C" void R_init_dgraphs_ian(DllInfo* dll) {
 static const R_CallMethodDef methods[]={{"dgraphs_ian_run_v3",(DL_FUNC)&dgraphs_ian_run_v3,9},{"dgraphs_ian_run_v2",(DL_FUNC)&dgraphs_ian_run_v2,9},{"dgraphs_ian_run",(DL_FUNC)&dgraphs_ian_run,8},{nullptr,nullptr,0}};
 R_registerRoutines(dll,nullptr,methods,nullptr,nullptr);R_useDynamicSymbols(dll,FALSE);R_forceSymbols(dll,TRUE);
}
