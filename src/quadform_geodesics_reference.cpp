#include "quadform_geodesics_reference.h"
#include "quadform_geodesics_solver.h"
#include "quadform_geodesics_exact.h"
#include "vendor/geodesic/geodesic_runtime.h"
#include <boost/graph/adjacency_list.hpp>
#include <boost/graph/dijkstra_shortest_paths.hpp>
#include <chrono>
#include <set>
#include <numeric>

namespace qgn {
long double positive_mean(long double,long double,long double);
double scalar(Rcpp::List,const char*,double,double,bool);
bool flag(Rcpp::List,const char*);
}
namespace qgr {
using Point=std::vector<double>;
using Points=std::vector<Point>;
using Clock=std::chrono::steady_clock;
struct Limit { std::string reason; };
struct Reached {};
struct Budget {
  Clock::time_point start=Clock::now();double seconds;
  explicit Budget(double s):seconds(s){}
  void poll()const {Rcpp::checkUserInterrupt();if(elapsed()>=seconds)throw Limit{"time_limit"};}
  double elapsed()const{return std::chrono::duration<double>(Clock::now()-start).count();}
};
double norm(const Point& a,const Point& b){double out=0;for(size_t j=0;j<a.size();++j)out=std::hypot(out,a[j]-b[j]);return out;}
qgn::Measure edge(const Rcpp::NumericMatrix& A,const Point& a,const Point& b){
  int d=A.nrow();if(d==2)return qgn::connector_length({{A(0,0),A(0,1),A(1,0),A(1,1)}},{{a[0],a[1]}},{{b[0],b[1]}});
  if(a==b)return {0,0,true};
  using Real=long double;const Real eps=std::numeric_limits<Real>::epsilon();
  std::vector<Real> h(d),ah(d),eh(d),eah(d);Real c=0,ec=0;
  for(int j=0;j<d;++j){h[j]=Real(b[j])-a[j];eh[j]=eps*std::abs(h[j]);c=std::hypot(c,h[j]);ec+=eh[j];}
  ec+=8*d*eps*c;
  for(int i=0;i<d;++i)for(int j=0;j<d;++j){Real p=Real(A(i,j))*h[j];ah[i]+=p;eah[i]+=16*d*eps*std::abs(p)+std::abs(Real(A(i,j)))*eh[j];}
  auto slope=[&](const Point& p,Real& error){Real out=0;error=0;for(int i=0;i<d;++i){Real term=Real(p[i])*ah[i];out+=term;error+=32*d*eps*std::abs(term)+2*std::abs(Real(p[i]))*eah[i];}return 2*out;};
  Real e0,e1,v0=slope(a,e0),v1=slope(b,e1),scale=std::max({c,std::abs(v0),std::abs(v1)});
  if(!(scale>0)||!std::isfinite(scale))return {0,0,false};
  Real cn=c/scale,q=std::abs(v0)/scale,r=std::abs(v1)/scale,mean,omitted=0;
  bool crossing=(v0<0)!=(v1<0);
  if(cn<=eps){mean=crossing?(q*q+r*r)/(2*(q+r)):(q+r)/2;omitted=c;}
  else if(crossing){Real w=q/(q+r);mean=w*qgn::positive_mean(cn,0,q)+(1-w)*qgn::positive_mean(cn,0,r);}
  else mean=qgn::positive_mean(cn,std::min(q,r),std::max(q,r));
  double value=double(scale*mean),error=double(ec+(e0+e1)/2+omitted+128*d*eps*scale*mean);
  error=std::nextafter(error+4*std::numeric_limits<double>::epsilon()*value,std::numeric_limits<double>::infinity());
  return {value,error,std::isfinite(value)&&value>0&&std::isfinite(error)};
}
double height(const Rcpp::NumericMatrix& A,const Point& p){
  if(p.size()==2)return qgn::surface_height({{A(0,0),A(0,1),A(1,0),A(1,1)}},{{p[0],p[1]}});
  long double value=0;for(size_t i=0;i<p.size();++i)for(size_t j=0;j<p.size();++j)value+=static_cast<long double>(p[i])*A(i,j)*p[j];
  return double(value);
}
Rcpp::NumericMatrix matrix(const Points& p,int d){Rcpp::NumericMatrix out(p.size(),d);for(size_t i=0;i<p.size();++i)for(int j=0;j<d;++j)out(i,j)=p[i][j];return out;}
using Graph=boost::adjacency_list<boost::vecS,boost::vecS,boost::undirectedS,
  boost::no_property,boost::property<boost::edge_weight_t,double>>;
struct Visitor:boost::default_dijkstra_visitor {
  const Budget* budget;size_t target;int* settled;
  Visitor(const Budget* b,size_t t,int* s):budget(b),target(t),settled(s){}
  template<class V,class G>void examine_vertex(V v,const G&)const{budget->poll();++*settled;if(v==target)throw Reached{};}
};
Rcpp::List solve(Rcpp::NumericMatrix A,Rcpp::NumericVector from,Rcpp::NumericVector to,
                 Rcpp::List domain,std::string method,Rcpp::List control){
  int d=A.nrow();if(d<2||d>4||A.ncol()!=d||from.size()!=d||to.size()!=d)Rcpp::stop("Invalid reference geometry dimensions");
  for(int i=0;i<d;++i)for(int j=0;j<d;++j)if(!std::isfinite(A(i,j))||A(i,j)!=A(j,i))Rcpp::stop("A must be finite and symmetric");
  Point a(from.begin(),from.end()),b(to.begin(),to.end());bool reversed=b<a;if(reversed)std::swap(a,b);
  bool disk=Rcpp::as<std::string>(domain["kind"])=="ball";
  Rcpp::NumericVector lo,hi,center;double radius=0;
  if(disk){center=domain["center"];radius=qgn::scalar(domain,"radius",1e-100,1e100,false);if(center.size()!=d)Rcpp::stop("Invalid center");}
  else {if(Rcpp::as<std::string>(domain["kind"])!="box")Rcpp::stop("Invalid domain kind");lo=domain["lower"];hi=domain["upper"];if(lo.size()!=d||hi.size()!=d)Rcpp::stop("Invalid box dimensions");}
  for(int j=0;j<d;++j)if(disk?!std::isfinite(center[j]):(!std::isfinite(lo[j])||!std::isfinite(hi[j])||lo[j]>=hi[j]))Rcpp::stop("Invalid domain coordinates");
  auto inside=[&](const Point& p){double r=0;for(int j=0;j<d;++j){if(!std::isfinite(p[j]))return false;if(disk)r=std::hypot(r,(p[j]-center[j])/radius);else if(p[j]<lo[j]||p[j]>hi[j])return false;}return !disk||r<=1;};
  if(!inside(a)||!inside(b))Rcpp::stop("Endpoints must be finite and in the domain");
  bool mesh=method=="polyhedral_mesh";if(!mesh&&method!="radius_graph"&&method!="delaunay_graph")Rcpp::stop("Unknown reference method");
  double seconds=qgn::scalar(control,"max_seconds",0,std::numeric_limits<double>::infinity(),false);Budget budget(seconds);
  int max_vertices=qgn::scalar(control,"max_vertices",2,4096,true),max_edges=qgn::scalar(control,"max_edges",0,2000000,true);
  int max_checks=qgn::scalar(control,"max_pair_checks",0,10000000,true);
  Rcpp::NumericMatrix input=control["prepared_vertices"];if(input.ncol()!=d||input.nrow()>max_vertices)Rcpp::stop("Invalid prepared vertices");
  Points points;for(int i=0;i<input.nrow();++i){Point p(d);for(int j=0;j<d;++j)p[j]=input(i,j);if(!inside(p))Rcpp::stop("Reference vertex outside domain");points.push_back(p);}
  if(!std::is_sorted(points.begin(),points.end())||std::adjacent_find(points.begin(),points.end())!=points.end())Rcpp::stop("Prepared vertices must be sorted and distinct");
  auto sa=std::lower_bound(points.begin(),points.end(),a),sb=std::lower_bound(points.begin(),points.end(),b);
  if(sa==points.end()||*sa!=a||sb==points.end()||*sb!=b)Rcpp::stop("Endpoints missing from reference vertices");
  int source=sa-points.begin(),target=sb-points.begin();
  Rcpp::IntegerMatrix cells=control["prepared_cells"];if(cells.ncol()!=d+1)Rcpp::stop("Invalid simplex dimensions");
  for(int i:cells)if(i==NA_INTEGER||i<1||i>input.nrow())Rcpp::stop("Invalid simplex index");
  Points path,surface;double length=NA_REAL,error=NA_REAL;std::string status="failed",termination;
  Rcpp::List diagnostics;Rcpp::RObject graph=R_NilValue,mesh_data=R_NilValue;
  std::set<std::array<int,2>> edges;std::vector<double> weights;int checks=0,settled=0;
  try{
    budget.poll();
    if(a==b){path={a,b};length=0;error=0;status="candidate";termination="identity";}
    else if(mesh){
      if(d!=2)throw Limit{"mesh_requires_two_dimensional_domain"};
      int max_faces=qgn::scalar(control,"max_faces",1,4096,true);
      if(cells.nrow()>max_faces||points.size()>1024)throw Limit{"face_or_vertex_limit"};
      if(!cells.nrow())throw Limit{"empty_triangulation"};
      std::vector<double> xyz;double scale=0;Point origin=a;origin.push_back(height(A,a));
      for(auto p:points){p.push_back(height(A,p));if(!std::isfinite(p.back()))throw Limit{"height_overflow"};
        for(int j=0;j<3;++j){double v=p[j]-origin[j];xyz.push_back(v);scale=std::max(scale,std::abs(v));}}
      if(!(scale>=1e-100&&scale<=1e100))throw Limit{"mesh_numeric_scope"};
      for(auto& v:xyz)v/=scale;
      std::vector<unsigned> faces;std::map<std::array<int,2>,int> incidence;std::vector<bool> used(points.size(),false);
      for(int i=0;i<cells.nrow();++i){budget.poll();std::array<int,3> t{{cells(i,0)-1,cells(i,1)-1,cells(i,2)-1}};
        for(int j=0;j<3;++j){int p=t[j],q=t[(j+1)%3],r=t[(j+2)%3];if(p==q||p==r)Rcpp::stop("Repeated triangle vertex");
          std::array<int,2> e{{std::min(p,q),std::max(p,q)}};if(++incidence[e]>2)Rcpp::stop("Nonmanifold mesh edge");
          double dot=0,n1=0,n2=0;for(int k=0;k<3;++k){double u=xyz[3*q+k]-xyz[3*p+k],v=xyz[3*r+k]-xyz[3*p+k];dot+=u*v;n1+=u*u;n2+=v*v;}
          if(!(n1>1e-100&&n2>1e-100))throw Limit{"mesh_degenerate_triangle"};
          double angle=std::acos(std::max(-1.,std::min(1.,dot/std::sqrt(n1*n2))));
          if(!(angle>1e-5&&angle<std::acos(-1.)-1e-5))throw Limit{"mesh_degenerate_triangle"};
          used[p]=true;faces.push_back(p);}}
      if(std::find(used.begin(),used.end(),false)!=used.end())throw Limit{"mesh_unused_vertex"};
      auto solved=mesh_path(xyz,faces,source,target,
        qgn::scalar(control,"max_propagations",0,1000000,true),qgn::scalar(control,"max_intervals",1,1000000,true),[&](){budget.poll();});
      for(auto p:solved.path){Point v(3);for(int j=0;j<3;++j)v[j]=origin[j]+scale*p[j];surface.push_back(v);path.push_back({v[0],v[1]});}
      if(path.size()<2||norm(path.front(),a)>1e-8*scale||norm(path.back(),b)>1e-8*scale)throw Limit{"mesh_endpoint_mismatch"};
      path.front()=a;path.back()=b;surface.front()={a[0],a[1],height(A,a)};surface.back()={b[0],b[1],height(A,b)};
      for(auto p:path)if(!inside(p))throw Limit{"mesh_path_outside_domain"};
      qgn::ExactLength total,smooth,smooth_error;
      for(size_t i=1;i<path.size();++i){total.add(norm(surface[i-1],surface[i]));auto m=edge(A,path[i-1],path[i]);if(!m.ok)throw Limit{"edge_length_failed"};smooth.add(m.length);smooth_error.add(m.error);}
      length=total.rounded();double search_length=solved.distance*scale;
      if(!std::isfinite(length)||std::abs(length-search_length)>1e-5*std::max(length,scale))throw Limit{"mesh_trace_length_mismatch"};
      diagnostics["mesh_search_length"]=search_length;diagnostics["smooth_lifted_length"]=smooth.rounded();
      diagnostics["smooth_length_error_estimate"]=smooth_error.rounded();diagnostics["propagations"]=solved.propagations;
      diagnostics["peak_intervals"]=solved.peak_intervals;diagnostics["triangles"]=cells.nrow();
      diagnostics["mesh_domain"]="triangulated_convex_hull_subset_of_declared_domain";
      diagnostics["smallest_interval_ratio"]=1e-6;
      if(qgn::flag(control,"keep_mesh")){Points lifted;for(auto p:points){p.push_back(height(A,p));lifted.push_back(p);}mesh_data=Rcpp::List::create(Rcpp::_["vertices"]=matrix(lifted,3),Rcpp::_["triangles"]=cells);}
      status="candidate";termination="mesh_search_complete";
    }else{
      auto add=[&](int p,int q){if(p==q)Rcpp::stop("Repeated simplex vertex");std::array<int,2> e{{std::min(p,q),std::max(p,q)}};
        if(edges.find(e)==edges.end()){if(edges.size()>=static_cast<size_t>(max_edges))throw Limit{"edge_limit"};edges.insert(e);}};
      if(method=="radius_graph"){
        double r=qgn::scalar(control,"radius",std::numeric_limits<double>::min(),std::numeric_limits<double>::max(),false);
        for(size_t i=0;i<points.size();++i)for(size_t j=i+1;j<points.size();++j){budget.poll();if(checks>=max_checks)throw Limit{"pair_check_limit"};++checks;if(norm(points[i],points[j])<=r)add(i,j);}
      }else {if(cells.nrow()>200000)throw Limit{"simplex_limit"};for(int i=0;i<cells.nrow();++i){budget.poll();for(int j=0;j<d+1;++j)for(int k=j+1;k<d+1;++k)add(cells(i,j)-1,cells(i,k)-1);}}
      Graph g(points.size());
      for(auto e:edges){budget.poll();auto w=edge(A,points[e[0]],points[e[1]]);if(!w.ok||!(w.length>0))throw Limit{"edge_length_failed"};boost::add_edge(e[0],e[1],w.length,g);weights.push_back(w.length);}
      std::vector<double> distance(points.size());std::vector<size_t> parent(points.size());std::iota(parent.begin(),parent.end(),0);
      try{boost::dijkstra_shortest_paths(g,source,boost::predecessor_map(parent.data()).distance_map(distance.data()).visitor(Visitor(&budget,target,&settled)));}catch(const Reached&){}
      if(parent[target]==static_cast<size_t>(target))throw Limit{"disconnected_reference_graph"};
      for(size_t id=target,n=0;;id=parent[id]){if(++n>points.size())throw Limit{"predecessor_cycle"};path.push_back(points[id]);if(id==static_cast<size_t>(source))break;}
      std::reverse(path.begin(),path.end());qgn::ExactLength total,errors;
      for(size_t i=1;i<path.size();++i){auto m=edge(A,path[i-1],path[i]);if(!m.ok)throw Limit{"edge_length_failed"};total.add(m.length);errors.add(m.error);}
      length=total.rounded();error=errors.rounded();if(!std::isfinite(length)||!std::isfinite(error))throw Limit{"path_length_failed"};
      diagnostics["search_distance"]=distance[target];diagnostics["search_sum_difference"]=distance[target]-length;
      if(qgn::flag(control,"keep_graph")){Rcpp::IntegerMatrix e(edges.size(),2);size_t i=0;for(auto x:edges){e(i,0)=x[0]+1;e(i++,1)=x[1]+1;}
        graph=Rcpp::List::create(Rcpp::_["vertices"]=input,Rcpp::_["edges"]=e,Rcpp::_["weights"]=weights);}
      status="candidate";termination="graph_search_complete";
    }
  }catch(const Limit& e){status=e.reason=="mesh_requires_two_dimensional_domain"||e.reason=="mesh_degenerate_triangle"||e.reason=="mesh_numeric_scope"?"unsupported":"failed";termination=e.reason;path.clear();surface.clear();length=error=NA_REAL;}
  catch(const geodesic::ResourceLimit& e){termination=e.what();path.clear();surface.clear();length=error=NA_REAL;}
  catch(const geodesic::Invariant& e){termination="mesh_numerical_failure";diagnostics["message"]=e.what();path.clear();surface.clear();length=error=NA_REAL;}
  if(surface.empty())for(auto p:path){p.push_back(height(A,p));if(!std::isfinite(p.back()))Rcpp::stop("Surface height overflow");surface.push_back(p);}
  if(reversed){std::reverse(path.begin(),path.end());std::reverse(surface.begin(),surface.end());}
  diagnostics["vertices"]=points.size();diagnostics["edges"]=edges.size();diagnostics["pair_checks"]=checks;
  diagnostics["settled_vertices"]=settled;diagnostics["elapsed_seconds"]=budget.elapsed();
  diagnostics["source_index"]=source+1;diagnostics["target_index"]=target+1;
  return Rcpp::List::create(Rcpp::_["status"]=status,Rcpp::_["termination"]=termination,
    Rcpp::_["implementation"]="self-contained-cpp-"+method+"-v1",Rcpp::_["length"]=length,
    Rcpp::_["error_estimate"]=error,Rcpp::_["path"]=matrix(path,d),Rcpp::_["surface_path"]=matrix(surface,d+1),
    Rcpp::_["path_representation"]=mesh?"polyhedral_surface_polyline":"lifted_domain_polyline",
    Rcpp::_["curve_parameters"]=R_NilValue,Rcpp::_["diagnostics"]=diagnostics,Rcpp::_["graph"]=graph,
    Rcpp::_["mesh"]=mesh_data,Rcpp::_["configuration"]=control,Rcpp::_["state_saving"]=false);
}
}
