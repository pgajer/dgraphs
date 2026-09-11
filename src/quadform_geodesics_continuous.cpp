#include "quadform_geodesics_continuous.h"
#include <RcppEigen.h>
#include <boost/numeric/odeint.hpp>
#include <algorithm>
#include <chrono>
#include <cmath>

namespace qgm {
qgn::Measure path_measure(const std::array<double,4>&, const qgn::Path&);
Result direct_result(const std::array<double,4>&, qgn::Point, qgn::Point, const std::string&);
}
namespace qgc {
using Vec = Eigen::Vector4d;
using Mat = Eigen::Matrix4d;
using V2 = Eigen::Vector2d;
using M2 = Eigen::Matrix2d;
using Clock = std::chrono::steady_clock;
using State = std::array<double,12>;
struct Stop { std::string reason; };
struct Unresolved { std::string reason; };
struct Outside { qgn::Point point; };
struct Budget {
  const Options& o;
  Clock::time_point start = Clock::now();
  int evaluations=0, steps=0, newton=0, stages=0, domains=0;
  explicit Budget(const Options& options):o(options){}
  double elapsed() const {return std::chrono::duration<double>(Clock::now()-start).count();}
  void poll() const {Rcpp::checkUserInterrupt();if(elapsed()>=o.max_seconds)throw Stop{"time_limit"};}
  void rhs(){poll();if(evaluations>=o.max_evaluations)throw Stop{"evaluation_limit"};++evaluations;}
};
struct Geometry {
  M2 H;
  V2 offset, center;
  double scale;
  const qgn::Domain& domain;
  Geometry(const std::array<double,4>& A,const qgn::Domain& d,qgn::Point from,qgn::Point to):domain(d){
    M2 a; a<<A[0],A[1],A[2],A[3];
    center=V2(from[0],from[1]);scale=std::hypot(to[0]-from[0],to[1]-from[1]);
    H=2*scale*a;offset=2*a*center;
    if(!std::isfinite(scale)||scale<1e-100||scale>1e100||!H.allFinite()||!offset.allFinite()||
       H.cwiseAbs().maxCoeff()>2048||offset.cwiseAbs().maxCoeff()>1e6)throw Unresolved{"numeric_scope"};
  }
  V2 local(qgn::Point p)const{return (V2(p[0],p[1])-center)/scale;}
  qgn::Point world(const V2& u)const{return {{center[0]+scale*u[0],center[1]+scale*u[1]}};}
  Vec rhs(const Vec& y,double lambda,Mat* jac,Budget& budget)const {
    budget.rhs();
    if(!y.allFinite()||y.cwiseAbs().maxCoeff()>1e50)throw Unresolved{"numerical_range"};
    M2 h=lambda*H;V2 g=lambda*(offset+H*y.head<2>()),v=y.tail<2>();
    double den=1+g.squaredNorm(),c=v.dot(h*v);
    Vec f; f.head<2>()=v;f.tail<2>()=-g*(c/den);
    if(jac){jac->setZero();jac->topRightCorner<2,2>().setIdentity();
      jac->bottomLeftCorner<2,2>()=-h*(c/den)+2*c/(den*den)*g*(h*g).transpose();
      jac->bottomRightCorner<2,2>()=-2/den*g*(h*v).transpose();}
    if(!f.allFinite()||(jac&&!jac->allFinite()))throw Unresolved{"numerical_range"};
    return f;
  }
};
struct Curve {std::vector<double> t;std::vector<Vec> y;double endpoint=0,residual=0;};

Curve integrate(const Geometry& g,const V2& a,const V2& velocity,double lambda,
                Budget& budget,bool retain,V2* endpoint=nullptr,M2* sensitivity=nullptr,double max_step=1.0/32){
  State y{}; y[0]=a[0];y[1]=a[1];y[2]=velocity[0];y[3]=velocity[1];y[6]=1;y[11]=1;
  auto system=[&](const State& s,State& derivative,double){
    Vec value;for(int k=0;k<4;++k)value[k]=s[k];Mat jac;
    Vec f=g.rhs(value,lambda,&jac,budget);for(int k=0;k<4;++k)derivative[k]=f[k];
    for(int j=0;j<2;++j){Vec z;for(int k=0;k<4;++k)z[k]=s[4+4*j+k];
      Vec dz=jac*z;for(int k=0;k<4;++k)derivative[4+4*j+k]=dz[k];}
  };
  using Stepper=boost::numeric::odeint::runge_kutta_dopri5<State>;
  auto stepper=boost::numeric::odeint::make_controlled(budget.o.integration_tolerance/100,
    budget.o.integration_tolerance,Stepper());
  Curve out;
  auto record=[&](double t){if(retain){
    if(out.y.size()>=static_cast<size_t>(budget.o.max_nodes))throw Unresolved{"node_limit"};
    Vec v;for(int k=0;k<4;++k)v[k]=y[k];out.t.push_back(t);out.y.push_back(v);}};
  double t=0,dt=.02;record(t);
  while(t<1){budget.poll();dt=std::min({dt,1-t,max_step});
    if(!(dt>0)||t+dt==t)throw Unresolved{"integration_step_underflow"};
    auto status=stepper.try_step(system,y,t,dt);++budget.steps;
    for(double v:y)if(!std::isfinite(v))throw Unresolved{"integration_nonfinite"};
    if(status==boost::numeric::odeint::success)record(t);
  }
  if(endpoint)*endpoint=V2(y[0],y[1]);
  if(sensitivity){(*sensitivity)<<y[4],y[8],y[5],y[9];}
  return out;
}

bool shoot(const Geometry& g,const V2& a,const V2& b,double lambda,V2& v,Budget& budget){
  double tol=budget.o.endpoint_tolerance;
  for(int i=0;i<budget.o.iterations;++i){
    ++budget.newton;V2 endpoint;M2 jac;
    integrate(g,a,v,lambda,budget,false,&endpoint,&jac);
    V2 residual=endpoint-b;double error=residual.norm();if(error<=tol)return true;
    Eigen::FullPivLU<M2> lu(jac);if(!lu.isInvertible())return false;
    V2 step=lu.solve(residual);if(!step.allFinite())return false;
    bool accepted=false;
    for(int k=0;k<16;++k){V2 trial=v-std::ldexp(1.0,-k)*step,check;
      try{integrate(g,a,trial,lambda,budget,false,&check);
        if((check-b).norm()<error){v=trial;accepted=true;break;}}
      catch(const Unresolved&){}
    }
    if(!accepted)return false;
  }
  V2 end;integrate(g,a,v,lambda,budget,false,&end);return (end-b).norm()<=tol;
}

// Cubic Hermite interpolation of the four-dimensional collocation state.
Vec hermite(const Vec& a,const Vec& b,const Vec& fa,const Vec& fb,double h,double s,bool derivative=false){
  double s2=s*s,s3=s2*s;
  if(derivative)return ((6*s2-6*s)*a+(-6*s2+6*s)*b)/h+(3*s2-4*s+1)*fa+(3*s2-2*s)*fb;
  return (2*s3-3*s2+1)*a+(-2*s3+3*s2)*b+h*((s3-2*s2+s)*fa+(s3-s2)*fb);
}
struct Interval {Vec r,scale;Mat left,right;};
Interval interval(const Geometry& g,const Vec& a,const Vec& b,double h,double lambda,Budget& budget,bool jacobian){
  Mat ja,jb,jm;Vec fa=g.rhs(a,lambda,jacobian?&ja:nullptr,budget);
  Vec fb=g.rhs(b,lambda,jacobian?&jb:nullptr,budget);
  Vec middle=(a+b)/2+h*(fa-fb)/8;
  Vec fm=g.rhs(middle,lambda,jacobian?&jm:nullptr,budget);
  Interval z;z.r=(b-a)/h-(fa+4*fm+fb)/6;
  z.scale=Vec::Ones()+(fa.cwiseAbs()+4*fm.cwiseAbs()+fb.cwiseAbs())/6;
  if(jacobian){Mat id=Mat::Identity();
    z.left=-id/h-(ja+4*jm*(id/2+h*ja/8))/6;
    z.right=id/h-(jb+4*jm*(id/2-h*jb/8))/6;}
  return z;
}
Eigen::VectorXd equations(const Geometry& g,const Curve& c,const V2& a,const V2& b,
                          double lambda,Budget& budget,std::vector<Eigen::Triplet<double>>* entries,
                          Eigen::VectorXd* scales=nullptr){
  int n=static_cast<int>(c.y.size()),end=4*(n-1);Eigen::VectorXd r(4*n);
  if(scales)*scales=Eigen::VectorXd::Ones(4*n);
  for(int i=0;i<n-1;++i){
    auto z=interval(g,c.y[i],c.y[i+1],c.t[i+1]-c.t[i],lambda,budget,entries!=nullptr);
    r.segment<4>(4*i)=z.r;
    if(scales)scales->segment<4>(4*i)=z.scale;
    if(entries)for(int j=0;j<4;++j)for(int k=0;k<4;++k){
      entries->emplace_back(4*i+j,4*i+k,z.left(j,k));
      entries->emplace_back(4*i+j,4*(i+1)+k,z.right(j,k));}
  }
  r.segment<2>(end)=c.y.front().head<2>()-a;r.segment<2>(end+2)=c.y.back().head<2>()-b;
  if(entries)for(int j=0;j<2;++j){entries->emplace_back(end+j,j,1);entries->emplace_back(end+2+j,end+j,1);}
  return r;
}
bool collocate(const Geometry& g,Curve& curve,const V2& a,const V2& b,double lambda,Budget& budget){
  const double tol=std::min(budget.o.ode_tolerance*.01,budget.o.endpoint_tolerance*.1);
  for(int it=0;it<budget.o.iterations;++it){
    ++budget.newton;std::vector<Eigen::Triplet<double>> entries;
    Eigen::VectorXd scales;
    auto r=equations(g,curve,a,b,lambda,budget,&entries,&scales);
    if(r.cwiseQuotient(scales).lpNorm<Eigen::Infinity>()<=tol)return true;
    // Scale the stopping test, not the Newton merit function. Changing the
    // line-search weights can collapse distinct starting curves onto the
    // same stationary branch. Endpoint residuals retain scale one.
    double error=r.lpNorm<Eigen::Infinity>();
    Eigen::SparseMatrix<double> jac(r.size(),r.size());jac.setFromTriplets(entries.begin(),entries.end());
    Eigen::SparseLU<Eigen::SparseMatrix<double>> lu;
    budget.poll();lu.compute(jac);if(lu.info()!=Eigen::Success)return false;
    Eigen::VectorXd step=lu.solve(r);if(lu.info()!=Eigen::Success||!step.allFinite())return false;
    bool accepted=false;
    for(int k=0;k<16;++k){Curve trial=curve;
      for(size_t i=0;i<trial.y.size();++i)trial.y[i]-=std::ldexp(1.0,-k)*step.segment<4>(4*i);
      try{auto next=equations(g,trial,a,b,lambda,budget,nullptr);
        if(next.lpNorm<Eigen::Infinity>()<error){curve=std::move(trial);accepted=true;break;}}
      catch(const Unresolved&){}
    }
    if(!accepted)return false;
  }
  Eigen::VectorXd scales;
  auto r=equations(g,curve,a,b,lambda,budget,nullptr,&scales);
  return r.cwiseQuotient(scales).lpNorm<Eigen::Infinity>()<=tol;
}
double residual(const Geometry& g,const Curve& curve,double lambda,Budget& budget,
                std::vector<bool>* refine=nullptr){
  double result=0;
  if(refine)refine->clear();
  for(size_t i=1;i<curve.y.size();++i){
    const auto& a=curve.y[i-1];const auto& b=curve.y[i];double h=curve.t[i]-curve.t[i-1];
    Vec fa=g.rhs(a,lambda,nullptr,budget),fb=g.rhs(b,lambda,nullptr,budget);
    double local=0;
    for(double s:{.2113248654051871,.5,.7886751345948129}){
      Vec y=hermite(a,b,fa,fb,h,s),dy=hermite(a,b,fa,fb,h,s,true);
      Vec f=g.rhs(y,lambda,nullptr,budget);
      local=std::max(local,((dy-f).array().abs()/(1+f.array().abs())).maxCoeff());
    }
    result=std::max(result,local);
    if(refine)refine->push_back(local>budget.o.ode_tolerance);
  }
  return result;
}
void subdivide(const Geometry& g,Curve& c,double lambda,Budget& budget,
               const std::vector<bool>& refine,bool shooting=false){
  if(c.y.size()+std::count(refine.begin(),refine.end(),true)>
     static_cast<size_t>(budget.o.max_nodes))throw Unresolved{"node_limit"};
  Curve out;
  for(size_t i=1;i<c.y.size();++i){
    Vec a=c.y[i-1],b=c.y[i],fa=g.rhs(a,lambda,nullptr,budget),fb=g.rhs(b,lambda,nullptr,budget);
    out.t.push_back(c.t[i-1]);out.y.push_back(a);
    if(refine[i-1]){
      double middle=(c.t[i-1]+c.t[i])/2;
      if(middle==c.t[i-1]||middle==c.t[i])throw Unresolved{"integration_step_underflow"};
      Vec value=hermite(a,b,fa,fb,c.t[i]-c.t[i-1],.5);
      if(shooting){
        // Obtain new shooting nodes from the ODE, not from the interpolant
        // whose residual triggered refinement. Existing nodes stay fixed.
        using S=std::array<double,4>;
        S y;for(int k=0;k<4;++k)y[k]=a[k];
        auto system=[&](const S& s,S& dy,double){Vec v;
          for(int k=0;k<4;++k)v[k]=s[k];auto f=g.rhs(v,lambda,nullptr,budget);
          for(int k=0;k<4;++k)dy[k]=f[k];};
        using Stepper=boost::numeric::odeint::runge_kutta_dopri5<S>;
        auto stepper=boost::numeric::odeint::make_controlled(budget.o.integration_tolerance/100,
          budget.o.integration_tolerance,Stepper());
        double t=c.t[i-1],dt=(middle-t)/4;
        while(t<middle){budget.poll();dt=std::min(dt,middle-t);
          if(!(dt>0)||t+dt==t)throw Unresolved{"integration_step_underflow"};
          stepper.try_step(system,y,t,dt);++budget.steps;}
        for(int k=0;k<4;++k)value[k]=y[k];
      }
      out.t.push_back(middle);out.y.push_back(value);
    }
  }
  out.t.push_back(c.t.back());out.y.push_back(c.y.back());c=std::move(out);
}
Curve initial(const V2& a,const V2& b,int n,double bend){
  Curve c;V2 delta=b-a,normal(-delta[1],delta[0]);double pi=std::acos(-1.0);
  for(int i=0;i<n;++i){double t=double(i)/(n-1);Vec y;
    y.head<2>()=a+t*delta+bend*std::sin(pi*t)*normal;
    y.tail<2>()=delta+bend*pi*std::cos(pi*t)*normal;c.t.push_back(t);c.y.push_back(y);}
  c.y.front().head<2>()=a;c.y.back().head<2>()=b;return c;
}

bool collocate_refined(const Geometry& g,Curve& curve,const V2& a,const V2& b,
                       double lambda,Budget& budget){
  if(!collocate(g,curve,a,b,lambda,budget))return false;
  std::vector<bool> refine;
  while(true){curve.residual=residual(g,curve,lambda,budget,&refine);
    if(curve.residual<=budget.o.ode_tolerance)return true;
    subdivide(g,curve,lambda,budget,refine);
    if(!collocate(g,curve,a,b,lambda,budget))return false;}
}

// A cubic Bezier curve lies in the convex hull of its four controls. Splitting
// refines the containment check without mistaking sampled points for a proof.
using Bezier=std::array<qgn::Point,4>;
qgn::Point mean(qgn::Point a,qgn::Point b){return {{a[0]/2+b[0]/2,a[1]/2+b[1]/2}};}
std::pair<Bezier,Bezier> split(const Bezier& q){
  auto a=mean(q[0],q[1]),b=mean(q[1],q[2]),c=mean(q[2],q[3]);
  auto d=mean(a,b),e=mean(b,c),f=mean(d,e);return {{{q[0],a,d,f}},{{f,e,c,q[3]}}};
}
void polygon(const std::array<double,4>& A,const qgn::Domain& domain,const Bezier& q,
             double allowance,int depth,Budget& budget,qgn::Path& path,double& discrepancy){
  budget.poll();++budget.domains;
  bool contained=true;for(auto p:q)contained=contained&&domain.inside(p);
  auto halves=split(q);auto middle=halves.first[3];
  auto quarter=split(halves.first).first[3],third=split(halves.second).first[3];
  for(auto p:{q[0],quarter,middle,third,q[3]})if(!domain.inside(p))throw Outside{p};
  auto coarse=qgn::connector_length(A,q[0],q[3]),left=qgn::connector_length(A,q[0],middle),
       right=qgn::connector_length(A,middle,q[3]);
  if(!coarse.ok||!left.ok||!right.ok)throw Unresolved{"length_evaluation_failed"};
  // Quarter points avoid the midpoint alias of an S-shaped cubic.
  std::array<qgn::Point,5> points{{q[0],quarter,middle,third,q[3]}};
  double fine=0;
  for(size_t i=1;i<points.size();++i){
    auto edge=qgn::connector_length(A,points[i-1],points[i]);
    if(!edge.ok)throw Unresolved{"length_evaluation_failed"};fine+=edge.length;
  }
  double difference=std::abs(left.length+right.length-coarse.length)+
    std::abs(fine-left.length-right.length);
  if(contained&&difference<=allowance){
    if(path.size()+1>static_cast<size_t>(budget.o.max_path_vertices))throw Unresolved{"path_vertex_limit"};
    // The accepted coarse connector is the curve approximation being tested.
    // Quarter points diagnose its discrepancy; they need not all be emitted.
    path.push_back(q[3]);discrepancy+=difference;return;
  }
  if(depth==0)throw Unresolved{contained?"path_resolution_limit":"domain_unresolved"};
  polygon(A,domain,halves.first,allowance/2,depth-1,budget,path,discrepancy);
  polygon(A,domain,halves.second,allowance/2,depth-1,budget,path,discrepancy);
}
qgm::Result publish(const std::array<double,4>& A,const Geometry& g,Curve curve,
                    qgn::Point from,qgn::Point to,Budget& budget){
  qgm::Result out;out.representation="lifted_domain_polyline";
  out.numbers["endpoint_residual"]=curve.endpoint*g.scale;
  out.numbers["equation_residual_estimate"]=curve.residual;
  out.numbers["solution_nodes"]=curve.y.size();
  curve.y.front().head<2>()=g.local(from);curve.y.back().head<2>()=g.local(to);
  auto direct=qgn::connector_length(A,from,to);if(!direct.ok)throw Unresolved{"length_evaluation_failed"};
  double allowance=budget.o.path_tolerance*std::max(direct.length,g.scale*1e-12),discrepancy=0;
  out.path.push_back(from);
  for(size_t i=1;i<curve.y.size();++i){
    const Vec& a=curve.y[i-1];const Vec& b=curve.y[i];double h=curve.t[i]-curve.t[i-1];
    Bezier q{{g.world(a.head<2>()),g.world(a.head<2>()+h/3*a.tail<2>()),
               g.world(b.head<2>()-h/3*b.tail<2>()),g.world(b.head<2>())}};
    if(i==1)q[0]=from;if(i+1==curve.y.size())q[3]=to;
    polygon(A,g.domain,q,allowance*h,budget.o.domain_depth,budget,out.path,discrepancy);
  }
  auto m=qgm::path_measure(A,out.path);if(!m.ok)throw Unresolved{"length_evaluation_failed"};
  out.length=m.length;out.error=m.error;out.status="candidate";out.termination="stationary_path_converged";
  out.numbers["polyline_refinement_difference"]=discrepancy;
  out.numbers["direct_connector_length"]=direct.length;
  out.numbers["longer_than_direct"]=out.length-out.error>direct.length+direct.error;
  out.labels["domain_check"]="bezier_control_hulls_then_convex_polyline";
  out.labels["optimality"]="stationary_candidate_not_global_certificate";
  out.labels["length_error_scope"]="returned_polyline_only";
  out.numbers["initial_velocity_x"]=g.scale*curve.y.front()[2];
  out.numbers["initial_velocity_y"]=g.scale*curve.y.front()[3];
  return out;
}

qgm::Result solve(const std::array<double,4>& A,const qgn::Domain& domain,
                  qgn::Point from,qgn::Point to,const Options& o,bool collocation){
  Budget budget(o);qgm::Result best;best.representation="lifted_domain_polyline";
  bool reversed=to<from;if(reversed)std::swap(from,to);
  int attempted=0,converged=0,feasible=0;std::map<std::string,std::string> attempts;
  std::map<std::string,double> lengths;std::string last="no_converged_path";
  bool outside=false,unresolved=false;
  try{
    budget.poll();
    if(from==to||std::all_of(A.begin(),A.end(),[](double x){return x==0;})){
      best=qgm::direct_result(A,from,to,from==to?"identity":"flat");
    }else{
      Geometry g(A,domain,from,to);V2 a=g.local(from),b=g.local(to),delta=b-a;
      for(size_t attempt=0;attempt<o.bends.size();++attempt){
        budget.poll();++attempted;std::string key="start_"+std::to_string(attempt+1);
        try{
          Curve curve;V2 velocity=delta;bool ok=false;
          if(o.bends[attempt]==0){
            curve=initial(a,b,o.initial_nodes,0);double lambda=0,step=1.0/o.continuation_steps;
            for(int stage=0;stage<o.continuation_attempts&&lambda<1;++stage){
              ++budget.stages;double target=std::min(1.0,lambda+step);V2 v=velocity;Curve c=curve;
              // A coarse collocation root can belong to a discretization
              // branch that disappears upon refinement. Qualify each
              // continuation stage before using it to seed the next one.
              try{ok=collocation?collocate_refined(g,c,a,b,target,budget):shoot(g,a,b,target,v,budget);}
              catch(const Unresolved&){ok=false;}
              if(ok){lambda=target;velocity=v;curve=std::move(c);step=std::min(step*1.5,1.0-lambda);}
              else step/=2;
              if(step<1e-8&&lambda<1)break;
            }
            if(lambda<1)throw Unresolved{"continuation_failed"};
          }else if(collocation){
            curve=initial(a,b,o.initial_nodes,o.bends[attempt]);ok=collocate(g,curve,a,b,1,budget);
            if(!ok)throw Unresolved{"newton_failed"};
          }else{
            velocity+=o.bends[attempt]*V2(-delta[1],delta[0]);
            if(!shoot(g,a,b,1,velocity,budget))throw Unresolved{"newton_failed"};
          }
          std::vector<bool> refine;
          if(collocation){
            while(true){curve.residual=residual(g,curve,1,budget,&refine);
              if(curve.residual<=o.ode_tolerance)break;
              subdivide(g,curve,1,budget,refine);if(!collocate(g,curve,a,b,1,budget))throw Unresolved{"newton_failed"};}
            curve.endpoint=std::max((curve.y.front().head<2>()-a).norm(),(curve.y.back().head<2>()-b).norm());
          }else{
            V2 end;curve=integrate(g,a,velocity,1,budget,true,&end);
            curve.endpoint=(end-b).norm();
            while(true){curve.residual=residual(g,curve,1,budget,&refine);
              if(curve.residual<=o.ode_tolerance)break;
              subdivide(g,curve,1,budget,refine,true);}
            curve.endpoint=(end-b).norm();
          }
          if(curve.endpoint>o.endpoint_tolerance)throw Unresolved{"endpoint_residual"};
          ++converged;auto candidate=publish(A,g,curve,from,to,budget);++feasible;
          attempts[key]="candidate";lengths[key+"_length"]=candidate.length;
          if(best.status!="candidate"||candidate.length+candidate.error<best.length-best.error){
            best=std::move(candidate);best.numbers["selected_start"]=attempt+1;}
        }catch(const Outside& e){last="stationary_path_outside_domain";outside=true;attempts[key]=last;
          lengths[key+"_outside_x"]=e.point[0];lengths[key+"_outside_y"]=e.point[1];}
        catch(const Unresolved& e){last=e.reason;attempts[key]=last;unresolved=true;}
      }
      if(best.status!="candidate"){
        best.status=outside&&!unresolved?"unsupported":"failed";
        best.termination=outside&&!unresolved?"stationary_paths_outside_domain":
          outside?"no_feasible_path_some_starts_unresolved":last;
      }else if(unresolved){
        best.status="partial";best.termination="some_starts_unresolved";
      }
    }
  }catch(const Stop& e){best.termination=e.reason;best.status=best.path.empty()?"failed":"partial";}
  catch(const Unresolved& e){best.status="unsupported";best.termination=e.reason;}
  for(auto x:attempts)best.labels[x.first]=x.second;
  for(auto x:lengths)best.numbers[x.first]=x.second;
  best.numbers["starts_attempted"]=attempted;best.numbers["starts_requested"]=o.bends.size();
  best.numbers["converged_starts"]=converged;best.numbers["feasible_starts"]=feasible;
  best.numbers["rhs_evaluations"]=budget.evaluations;best.numbers["integration_steps"]=budget.steps;
  best.numbers["newton_iterations"]=budget.newton;best.numbers["continuation_attempts"]=budget.stages;
  best.numbers["domain_sections"]=budget.domains;best.numbers["elapsed_seconds"]=budget.elapsed();
  best.numbers["caller_reversed"]=reversed;
  if(reversed)std::reverse(best.path.begin(),best.path.end());
  return best;
}
}
