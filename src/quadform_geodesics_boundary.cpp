#include "quadform_geodesics_boundary.h"
#include <Rcpp.h>
#include <nloptrAPI.h>
#include <algorithm>
#include <chrono>
#include <exception>
#include <memory>

namespace qgm {
qgn::Measure path_measure(const std::array<double,4>&,const qgn::Path&);
Result direct_result(const std::array<double,4>&,qgn::Point,qgn::Point,const std::string&);
}
namespace qgb {
using Clock=std::chrono::steady_clock;
struct Limit { std::string reason; };
struct Search {
  const std::array<double,4>& A;
  const qgn::Domain& domain;
  const Options& options;
  Clock::time_point start=Clock::now();
  qgn::Point origin,from,to;
  double scale;
  qgm::Result best;
  nlopt_opt active=nullptr;
  std::exception_ptr exception;
  int evaluations=0,feasible=0,improvements=0;
  double elapsed()const{return std::chrono::duration<double>(Clock::now()-start).count();}
  void poll(){Rcpp::checkUserInterrupt();if(elapsed()>=options.max_seconds)throw Limit{"time_limit"};}
  qgn::Point world(double x,double y)const{return {{origin[0]+scale*x,origin[1]+scale*y}};}
  qgn::Path decode(unsigned n,const double* x)const{
    qgn::Path p{from};for(unsigned j=0;j<n;j+=2)p.push_back(world(x[j],x[j+1]));p.push_back(to);return p;
  }
  void retain(const qgn::Path& p,const qgn::Measure& m){
    if(m.ok&&(best.path.empty()||m.length+m.error<best.length-best.error)){
      best.path=p;best.length=m.length;best.error=m.error;++improvements;
    }
  }
};
// NLopt is a C library: save exceptions inside callbacks and rethrow only after
// the optimizer has returned and its allocations have been released.
double objective(unsigned n,const double* x,double*,void* data){
  auto& s=*static_cast<Search*>(data);
  if(s.exception)return 1e100;
  try{
    s.poll();if(s.evaluations>=s.options.max_evaluations)throw Limit{"evaluation_limit"};
    ++s.evaluations;auto p=s.decode(n,x);auto m=qgm::path_measure(s.A,p);
    if(!m.ok||!std::isfinite(m.length/s.scale))throw Limit{"length_evaluation_failed"};
    bool inside=true;for(auto u:p)inside=inside&&s.domain.inside(u);
    if(inside){++s.feasible;s.retain(p,m);}
    return m.length/s.scale;
  }catch(...){s.exception=std::current_exception();nlopt_force_stop(s.active);return 1e100;}
}
void constraints(unsigned m,double* result,unsigned,const double* x,double*,void*){
  // Normalized disk constraint, one per interior path vertex.
  for(unsigned i=0;i<m;++i)result[i]=x[2*i]*x[2*i]+x[2*i+1]*x[2*i+1]-1;
}
qgn::Point project(const qgn::Domain& d,qgn::Point p){
  if(!d.disk){for(int j=0;j<2;++j)p[j]=std::max(d.lower[j],std::min(d.upper[j],p[j]));return p;}
  double x=p[0]-d.center[0],y=p[1]-d.center[1],r=std::hypot(x,y);
  if(r>d.radius){double ratio=std::nextafter(d.radius/r,0.0);p={{d.center[0]+ratio*x,d.center[1]+ratio*y}};}
  return p;
}
void check(nlopt_result r){if(r<0)Rcpp::stop("NLopt configuration failed (%d)",int(r));}
qgm::Result solve(const std::array<double,4>& A,const qgn::Domain& domain,
                 qgn::Point from,qgn::Point to,const Options& o){
  bool reversed=to<from;if(reversed)std::swap(from,to);
  qgn::Point origin=domain.disk?domain.center:qgn::Point{{domain.lower[0]/2+domain.upper[0]/2,domain.lower[1]/2+domain.upper[1]/2}};
  double scale=domain.disk?domain.radius:std::max(domain.upper[0]-domain.lower[0],domain.upper[1]-domain.lower[1]);
  Search s{A,domain,o,Clock::now(),origin,from,to,scale};
  std::map<std::string,double> codes,lengths;bool incomplete=false;int starts=0,levels=0;
  try{
    s.poll();s.best=qgm::direct_result(A,from,to,"initial_connector");
    if(s.best.path.empty())throw Limit{"length_evaluation_failed"};
    if(from==to||std::all_of(A.begin(),A.end(),[](double x){return x==0;})){
      s.best.termination=from==to?"identity":"flat";
    }else{
      if(!(scale>=1e-100&&scale<=1e100))throw Limit{"numeric_scope"};
      qgn::Path warm=o.initial_path;if(reversed)std::reverse(warm.begin(),warm.end());
      if(!warm.empty())s.retain(warm,qgm::path_measure(A,warm));
      for(int level=0;level<o.levels;++level){
        s.poll();qgn::Path base;
        if(level==0){
          if(!warm.empty())base=warm;
          else for(int i=0;i<=o.initial_edges;++i){double t=double(i)/o.initial_edges;
            base.push_back({{(1-t)*from[0]+t*to[0],(1-t)*from[1]+t*to[1]}});}
        }else{
          const auto& p=s.best.path;for(size_t i=1;i<p.size();++i){base.push_back(p[i-1]);
            base.push_back({{p[i-1][0]/2+p[i][0]/2,p[i-1][1]/2+p[i][1]/2}});}base.push_back(to);
        }
        base.front()=from;base.back()=to;
        // A retained direct connector still needs interior optimization variables.
        if(base.size()==2)base.insert(base.begin()+1,{{from[0]/2+to[0]/2,from[1]/2+to[1]/2}});
        if(base.size()>257)throw Limit{"vertex_limit"};
        for(double bend:o.bends){
          s.poll();if(s.evaluations>=o.max_evaluations)throw Limit{"evaluation_limit"};
          int n=2*(static_cast<int>(base.size())-2);std::vector<double> x(n),lo(n),hi(n);
          double dx=(to[0]-from[0])/scale,dy=(to[1]-from[1])/scale;
          for(size_t i=1;i+1<base.size();++i){double t=double(i)/(base.size()-1),v=bend*std::sin(std::acos(-1.)*t);
            auto p=project(domain,{{base[i][0]-scale*v*dy,base[i][1]+scale*v*dx}});
            for(int j=0;j<2;++j){int k=2*(i-1)+j;x[k]=(p[j]-origin[j])/scale;
              lo[k]=domain.disk?-1:(domain.lower[j]-origin[j])/scale;
              hi[k]=domain.disk?1:(domain.upper[j]-origin[j])/scale;}}
          nlopt_opt raw=nlopt_create(NLOPT_LN_COBYLA,n);if(!raw)throw std::bad_alloc();
          std::unique_ptr<nlopt_opt_s,void(*)(nlopt_opt)> opt(raw,nlopt_destroy);s.active=raw;
          check(nlopt_set_lower_bounds(raw,lo.data()));check(nlopt_set_upper_bounds(raw,hi.data()));
          check(nlopt_set_min_objective(raw,objective,&s));
          if(domain.disk){std::vector<double> tol(n/2,0);check(nlopt_add_inequality_mconstraint(raw,n/2,constraints,&s,tol.data()));}
          check(nlopt_set_xtol_abs1(raw,o.position_tolerance));check(nlopt_set_initial_step1(raw,o.initial_step));
          check(nlopt_set_maxeval(raw,std::min(o.evaluations_per_start,o.max_evaluations-s.evaluations)));
          if(std::isfinite(o.max_seconds))check(nlopt_set_maxtime(raw,std::max(1e-12,o.max_seconds-s.elapsed())));
          double value=0;int result=nlopt_optimize(raw,x.data(),&value);++starts;
          opt.reset();s.active=nullptr;if(s.exception)std::rethrow_exception(s.exception);
          std::string key="start_"+std::to_string(starts);codes[key+"_optimizer_code"]=result;
          lengths[key+"_best_length"]=s.best.length;
          if(result<=0||result==NLOPT_MAXEVAL_REACHED||result==NLOPT_MAXTIME_REACHED)incomplete=true;
        }
        ++levels;
      }
      s.best.status=incomplete?"partial":"candidate";
      s.best.termination=incomplete?"some_starts_incomplete":"position_tolerance_reached";
    }
  }catch(const Limit& e){s.best.status=s.best.path.empty()?"failed":"partial";s.best.termination=e.reason;}
  for(auto e:codes)s.best.numbers[e.first]=e.second;for(auto e:lengths)s.best.numbers[e.first]=e.second;
  s.best.representation="lifted_domain_polyline";
  s.best.numbers["objective_evaluations"]=s.evaluations;s.best.numbers["feasible_evaluations"]=s.feasible;
  s.best.numbers["accepted_improvements"]=s.improvements;s.best.numbers["completed_starts"]=starts;
  s.best.numbers["completed_levels"]=levels;s.best.numbers["elapsed_seconds"]=s.elapsed();
  s.best.labels["optimizer"]="NLopt_COBYLA";s.best.labels["domain_check"]="all_vertices_then_convex_segments";
  s.best.labels["optimality"]="local_candidate_not_global_certificate";
  if(reversed)std::reverse(s.best.path.begin(),s.best.path.end());return s.best;
}
}
