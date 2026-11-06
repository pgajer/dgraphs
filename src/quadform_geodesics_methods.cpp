#include "quadform_geodesics_methods.h"
#include "quadform_geodesics_exact.h"
#include <Rcpp.h>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <numeric>
#include <queue>
#include <set>

namespace qgn { long double positive_mean(long double, long double, long double); }
namespace qgm {
using Real = long double;
using qgn::Point;
using Clock = std::chrono::steady_clock;
const double inf = std::numeric_limits<double>::infinity();
const Real pi = std::acos(Real(-1));
struct Limit { std::string reason; };
struct Budget {
  Clock::time_point start = Clock::now();
  double seconds;
  explicit Budget(double s) : seconds(s) {}
  double elapsed() const { return std::chrono::duration<double>(Clock::now()-start).count(); }
  void check() const {
    Rcpp::checkUserInterrupt();
    if (elapsed() >= seconds) throw Limit{"time_limit"};
  }
};
Real radius(const Point& p) { return std::hypot(Real(p[0]),Real(p[1])); }
qgn::Measure path_measure(const std::array<double,4>& A, const qgn::Path& path) {
  qgn::ExactLength total, error;
  for (size_t i=1; i<path.size(); ++i) {
    auto e=qgn::connector_length(A,path[i-1],path[i]);
    if (!e.ok) return {0,0,false};
    total.add(e.length);error.add(e.error);
  }
  return {total.rounded(),std::nextafter(error.rounded(),inf),true};
}
Result direct_result(const std::array<double,4>& A, Point from, Point to, const std::string& reason) {
  Result out;out.path={from,to};auto m=path_measure(A,out.path);
  if (!m.ok) { out.path.clear();out.termination="length_evaluation_failed";return out; }
  out.status="candidate";out.termination=reason;out.length=m.length;out.error=m.error;
  out.representation="lifted_domain_polyline";
  out.labels["domain_check"]="convex_domain_segment";return out;
}

Result grid(const std::array<double,4>& A, const qgn::Domain& domain,
            Point from, Point to, const Options& o) {
  Budget budget(o.max_seconds);Result out;out.representation="lifted_domain_polyline";
  bool reversed=to<from;if(reversed)std::swap(from,to);
  try {
    budget.check();
    if(from==to) return direct_result(A,from,to,"identity");
    Point lo=domain.disk ? Point{{domain.center[0]-domain.radius,domain.center[1]-domain.radius}} : domain.lower;
    Point hi=domain.disk ? Point{{domain.center[0]+domain.radius,domain.center[1]+domain.radius}} : domain.upper;
    std::vector<int> indices(static_cast<size_t>(o.nx)*o.ny,-1);
    qgn::Path vertices;
    for(int i=0;i<o.nx;++i)for(int j=0;j<o.ny;++j){
      if((i*o.ny+j)%1024==0)budget.check();
      Point p{{double(Real(lo[0])+(Real(hi[0])-lo[0])*i/(o.nx-1)),
               double(Real(lo[1])+(Real(hi[1])-lo[1])*j/(o.ny-1))}};
      if(domain.inside(p)){indices[i*o.ny+j]=static_cast<int>(vertices.size());vertices.push_back(p);}
    }
    const int lattice=static_cast<int>(vertices.size());
    if(!lattice)throw Limit{"empty_lattice"};
    std::vector<std::array<int,2>> edges;
    auto add=[&](int a,int b){
      if(a==b)return;
      if(edges.size()>=o.max_edges)throw Limit{"edge_limit"};
      edges.push_back({{std::min(a,b),std::max(a,b)}});
    };
    auto gcd=[](int a,int b){a=std::abs(a);b=std::abs(b);while(b){int r=a%b;a=b;b=r;}return a;};
    std::vector<std::array<int,2>> offsets;
    for(int x=0;x<=o.directions;++x)for(int y=-o.directions;y<=o.directions;++y)
      if((x>0||y>0)&&gcd(x,y)==1)offsets.push_back({{x,y}});
    for(int i=0;i<o.nx;++i)for(int j=0;j<o.ny;++j){
      if((i*o.ny+j)%1024==0)budget.check();
      int a=indices[i*o.ny+j];if(a<0)continue;
      for(const auto& d:offsets){int x=i+d[0],y=j+d[1];
        if(x>=0&&x<o.nx&&y>=0&&y<o.ny&&indices[x*o.ny+y]>=0)add(a,indices[x*o.ny+y]);}
    }
    auto attach=[&](Point p){
      auto it=std::find(vertices.begin(),vertices.begin()+lattice,p);
      if(it!=vertices.begin()+lattice)return static_cast<int>(it-vertices.begin());
      int id=static_cast<int>(vertices.size());vertices.push_back(p);
      std::vector<std::pair<Real,int>> near;near.reserve(lattice);
      for(int j=0;j<lattice;++j)near.push_back({std::hypot(Real(p[0])-vertices[j][0],Real(p[1])-vertices[j][1]),j});
      std::sort(near.begin(),near.end());
      for(int j=0;j<std::min(o.attachments,lattice);++j)add(id,near[j].second);
      return id;
    };
    int source=attach(from),target=attach(to);
    if(o.direct)add(source,target);
    std::sort(edges.begin(),edges.end());edges.erase(std::unique(edges.begin(),edges.end()),edges.end());
    std::vector<qgn::Measure> measures;measures.reserve(edges.size());
    std::vector<std::vector<std::pair<int,int>>> adj(vertices.size());
    for(size_t i=0;i<edges.size();++i){
      if(i%256==0)budget.check();
      auto e=edges[i];auto m=qgn::connector_length(A,vertices[e[0]],vertices[e[1]]);
      if(!m.ok||!(m.length>0))throw Limit{"edge_length_failed"};
      measures.push_back(m);adj[e[0]].push_back({e[1],static_cast<int>(i)});adj[e[1]].push_back({e[0],static_cast<int>(i)});
    }
    std::vector<double> distance(vertices.size(),inf);
    std::vector<int> parent(vertices.size(),-1);
    using Entry=std::pair<double,int>;
    std::priority_queue<Entry,std::vector<Entry>,std::greater<Entry>> queue;
    distance[source]=0;queue.push({0,source});int settled=0;
    while(!queue.empty()){
      if(settled%256==0)budget.check();
      Entry top=queue.top();queue.pop();int a=top.second;
      if(top.first!=distance[a])continue;
      ++settled;if(a==target)break;
      for(const auto& edge:adj[a]){
        double trial=distance[a]+measures[edge.second].length;
        if(trial<distance[edge.first]){distance[edge.first]=trial;parent[edge.first]=a;queue.push({trial,edge.first});}
      }
    }
    if(!std::isfinite(distance[target]))throw Limit{"disconnected_reference_graph"};
    for(int id=target;id>=0;id=parent[id]){out.path.push_back(vertices[id]);if(id==source)break;}
    std::reverse(out.path.begin(),out.path.end());
    if(out.path.front()!=from)throw Limit{"predecessor_failure"};
    auto m=path_measure(A,out.path);if(!m.ok)throw Limit{"path_length_failed"};
    out.status="candidate";out.termination="graph_search_complete";out.length=m.length;out.error=m.error;
    out.numbers={{"grid_vertices",double(lattice)},{"graph_vertices",double(vertices.size())},
      {"graph_edges",double(edges.size())},{"settled_vertices",double(settled)},
      {"search_distance",distance[target]},{"search_sum_difference",distance[target]-m.length},
      {"selected_direct_edge",o.direct && out.path.size()==2?1.:0.},{"source_index",double(source+1)},{"target_index",double(target+1)}};
    out.labels["domain_check"]="convex_domain_segments";
    out.labels["search_order"]="strict_binary64_distance_then_vertex_id";
    if(o.keep_graph){out.vertices=vertices;out.edges=edges;for(auto m:measures)out.weights.push_back(m.length);}
    if(reversed)std::reverse(out.path.begin(),out.path.end());
  }catch(const Limit& e){out.path.clear();out.status="failed";out.termination=e.reason;}
  out.numbers["elapsed_seconds"]=budget.elapsed();return out;
}

// Stable angle and length primitives for a rotational paraboloid.
Real angle(Real k,Real c,Real t){
  Real b=std::hypot(Real(1),k*c),h=std::hypot(b,k*t);
  return k*c*std::asinh(k*t/b)+std::atan2(t,c*h);
}
Real angle_difference(Real k,Real c,Real ta,Real tb,Real dt){
  if(dt==0)return 0;
  Real b=std::hypot(Real(1),k*c),ha=std::hypot(b,k*ta),hb=std::hypot(b,k*tb);
  Real dv=std::log1p(k*dt*(1+k*(ta+tb)/(ha+hb))/(k*ta+ha));
  Real numerator=dt*b*b*(ta+tb)/(tb*ha+ta*hb);
  return k*c*dv+std::atan2(c*numerator,c*c*ha*hb+ta*tb);
}
Real length_interval(Real k,Real c,Real lo,Real hi,Real dt){
  if(dt==0)return 0;
  Real b=std::hypot(Real(1),k*c),scale=std::max(b,k*hi);
  return dt*scale*qgn::positive_mean(b/scale,k*lo/scale,k*hi/scale);
}
struct Curve {
  Real k,c,ta,tb,theta,sign;
  bool turning;
  Real start() const {return turning?-ta:ta;}
  Real theta_at(Real t) const {return theta+sign*(t<0?-angle(k,c,-t):angle(k,c,t));}
  Point at(Real t) const {Real r=std::hypot(c,t),a=theta_at(t);return {{double(r*std::cos(a)),double(r*std::sin(a))}};}
};
std::array<Real,2> trig_bounds(Real lo,Real hi,bool sine){
  if(lo>hi)std::swap(lo,hi);
  auto f=[&](Real x){return sine?std::sin(x):std::cos(x);};
  Real a=std::min(f(lo),f(hi)),b=std::max(f(lo),f(hi));
  for(int j=-8;j<=8;++j){Real x=j*pi/2;if(x>=lo&&x<=hi){a=std::min(a,f(x));b=std::max(b,f(x));}}
  return {{a,b}};
}
bool enclosing_box_inside(const Curve& c,Real a,Real b,const qgn::Domain& d){
  Real rlo=std::hypot(c.c,(a<=0&&b>=0)?Real(0):std::min(std::abs(a),std::abs(b)));
  Real rhi=std::hypot(c.c,std::max(std::abs(a),std::abs(b)));
  std::array<Real,2> lower,upper;
  for(int j=0;j<2;++j){auto t=trig_bounds(c.theta_at(a),c.theta_at(b),j==1);
    std::array<Real,4> v{{rlo*t[0],rlo*t[1],rhi*t[0],rhi*t[1]}};
    Real pad=32*std::numeric_limits<Real>::epsilon()*rhi;
    lower[j]=*std::min_element(v.begin(),v.end())-pad;upper[j]=*std::max_element(v.begin(),v.end())+pad;
  }
  if(!d.disk)return lower[0]>=d.lower[0]&&upper[0]<=d.upper[0]&&lower[1]>=d.lower[1]&&upper[1]<=d.upper[1];
  Real x=std::max(std::abs(lower[0]-d.center[0]),std::abs(upper[0]-d.center[0]));
  Real y=std::max(std::abs(lower[1]-d.center[1]),std::abs(upper[1]-d.center[1]));
  return std::hypot(x,y)<=d.radius;
}
std::string validate_curve(const Curve& c,const qgn::Domain& d,int depth,Budget& budget,int& visited){
  Real rmax=std::hypot(c.c,std::max(c.ta,c.tb));
  if(d.disk&&d.center==Point{{0,0}}&&rmax<=Real(d.radius)*(1+8*std::numeric_limits<Real>::epsilon()))return "radial_envelope";
  struct Section{Real a,b;int depth;};std::vector<Section> pending{{c.start(),c.tb,0}};
  while(!pending.empty()){
    if(visited%256==0)budget.check();
    Section s=pending.back();pending.pop_back();++visited;
    Real mid=(s.a+s.b)/2;
    if(!d.inside(c.at(mid)))return "path_leaves_domain";
    if(enclosing_box_inside(c,s.a,s.b,d))continue;
    if(s.depth>=depth||visited>=131071)return "domain_containment_unresolved";
    pending.push_back({s.a,mid,s.depth+1});pending.push_back({mid,s.b,s.depth+1});
  }
  return "radial_angular_enclosures";
}

Result clairaut(const std::array<double,4>& A,const qgn::Domain& domain,
                Point from,Point to,const Options& o){
  Result out;Budget budget(o.max_seconds);out.representation="analytic_clairaut_curve";
  if(A[1]!=0||A[2]!=0||A[0]!=A[3]){out.status="unsupported";out.termination="requires_isotropic_form";return out;}
  try{
    budget.check();
    if(A[0]==0||from==to)return direct_result(A,from,to,from==to?"identity":"flat_geodesic");
    Real dx=Real(to[0])-from[0],dy=Real(to[1])-from[1];
    Real sx=Real(to[0])+from[0],sy=Real(to[1])+from[1],yp=dy*sy;
    Real radial_square=std::fma(dx,sx,yp)+std::fma(dy,sy,-yp);
    Real a=radius(from),b=radius(to);
    bool reversed=radial_square<0||(radial_square==0&&to<from);
    if(reversed){std::swap(a,b);std::swap(from,to);}
    if(a==0){out=direct_result(A,from,to,"apex_meridian");if(reversed)std::reverse(out.path.begin(),out.path.end());return out;}
    Real k=2*std::abs(Real(A[0]));
    // Restrict numerical range before squaring normalized polar quantities.
    if(!std::isfinite(k*b)||k*b>1e6L||b>1e100L||a<1e-100L){out.status="unsupported";out.termination="polar_numerical_range";return out;}
    Real ux=Real(from[0])/a,uy=Real(from[1])/a,vx=Real(to[0])/b,vy=Real(to[1])/b;
    // Coordinate differences retain short separations lost by subtracting radii
    // or nearly equal products of unit vectors (long double can be binary64).
    dx=Real(to[0])-from[0];dy=Real(to[1])-from[1];
    radial_square=std::abs(radial_square);
    Real cross_product=Real(from[1])*dx;
    Real cross=(std::fma(Real(from[0]),dy,-cross_product)+
      std::fma(-Real(from[1]),dx,cross_product))/a/b,dot=ux*vx+uy*vy;
    Real gap=std::atan2(std::abs(cross),dot),sign=cross<0?-1:1;
    if(gap==0){out=direct_result(A,from,to,"same_meridian");if(reversed)std::reverse(out.path.begin(),out.path.end());return out;}
    Real threshold=angle(k,a,std::sqrt(radial_square));
    bool turning=gap>threshold;
    if(gap==pi&&turning){
      Real derivative=k*(std::asinh(k*a)+std::asinh(k*b))-std::hypot(Real(1),k*a)/a-std::hypot(Real(1),k*b)/b;
      if(derivative<=0){out=direct_result(A,from,to,"antipodal_meridian");if(reversed)std::reverse(out.path.begin(),out.path.end());return out;}
    }
    Real lo=0,hi=pi/2,phi=0,c=0,ta=0,tb=0,predicted=0,residual=0;int iterations=0;
    auto evaluate=[&](Real p){phi=p;c=a*std::sin(phi);ta=a*std::cos(phi);tb=std::sqrt(radial_square+ta*ta);
      if(turning){
        predicted=angle(k,c,ta)+angle(k,c,tb);
        Real base=std::hypot(Real(1),k*c);
        // Avoid subtracting pi when selecting the nonzero antipodal root.
        residual=gap>pi/2 ? k*c*(std::asinh(k*ta/base)+std::asinh(k*tb/base))-
          std::atan2(c*std::hypot(base,k*ta),ta)-std::atan2(c*std::hypot(base,k*tb),tb)+(pi-gap) : predicted-gap;
      }else{Real dt=radial_square/(tb+ta);predicted=angle_difference(k,c,ta,tb,dt);residual=predicted-gap;}
    };
    for(int i=0;i<o.iterations;++i){budget.check();Real mid=(lo+hi)/2;if(mid==lo||mid==hi)break;evaluate(mid);++iterations;
      if(turning ? residual>0 : residual<0)lo=mid;else hi=mid;
    }
    evaluate((lo+hi)/2);
    if(!std::isfinite(residual)||std::abs(residual)>o.angle_tolerance)throw Limit{"angular_residual_exceeded"};
    Real span=turning?ta+tb:radial_square/(tb+ta);
    Real length=turning ? length_interval(k,c,0,ta,ta)+length_interval(k,c,0,tb,tb) : length_interval(k,c,ta,tb,span);
    if(!std::isfinite(length)||length<=0||!std::isfinite(double(length)))throw Limit{"length_evaluation_failed"};
    Real ha=angle(k,c,ta),theta0=std::atan2(Real(from[1]),Real(from[0]));
    Curve curve{k,c,ta,tb,theta0+(turning?sign*ha:-sign*ha),sign,turning};
    int visited=0;std::string contained=validate_curve(curve,domain,o.domain_depth,budget,visited);
    out.labels["domain_check"]=contained;out.numbers["domain_sections_checked"]=visited;
    if(contained=="path_leaves_domain"||contained=="domain_containment_unresolved"){
      out.status="unsupported";out.termination=contained;return out;
    }
    Real mismatch=std::hypot(Real(curve.at(tb)[0])-to[0],Real(curve.at(tb)[1])-to[1]);
    if(mismatch>8*o.angle_tolerance*b)throw Limit{"endpoint_residual_exceeded"};
    for(int i=0;i<o.samples;++i){Real t=curve.start()+span*i/(o.samples-1);out.path.push_back(curve.at(t));}
    out.path.front()=from;out.path.back()=to;
    for(auto p:out.path)if(!domain.inside(p))throw Limit{"sampled_path_domain_failure"};
    auto upper=qgn::connector_length(A,from,to);
    Real allowance=512*std::numeric_limits<double>::epsilon()*length+b*std::abs(residual);
    Real chord=std::hypot(std::hypot(dx,dy),Real(A[0])*radial_square);
    if(!upper.ok||length>upper.length+upper.error+allowance||length+allowance<chord)throw Limit{"distance_bound_failure"};
    out.length=double(length);out.error=std::nextafter(double(allowance),inf);
    out.status="candidate";out.termination="clairaut_solved";
    out.labels["branch"]=turning?"turning":"radial_monotone";
    out.numbers["angular_residual"]=double(residual);out.numbers["endpoint_mismatch"]=double(mismatch);out.numbers["iterations"]=iterations;
    out.curve={{"k",double(k)},{"c",double(c)},{"t_from",double(curve.start())},{"t_to",double(tb)},
      {"t_span",double(span)},
      {"theta_turn",double(curve.theta)},{"angular_sign",double(sign)},{"caller_reversed",reversed?1.:0.}};
    if(reversed)std::reverse(out.path.begin(),out.path.end());
  }catch(const Limit& e){out.status="failed";out.termination=e.reason;out.path.clear();}
  out.numbers["elapsed_seconds"]=budget.elapsed();return out;
}
} // namespace qgm
