#include "quadform_geodesics_methods.h"
#include "quadform_geodesics_continuous.h"
#include "quadform_geodesics_boundary.h"
#include "quadform_geodesics_reference.h"
#include "quadform_geodesics_exact.h"
#include <Rcpp.h>
#include <cmath>

namespace qgn {
Point point(Rcpp::NumericVector, const char*);
double scalar(Rcpp::List, const char*, double, double, bool);
Rcpp::NumericMatrix matrix(Path, bool);
bool flag(Rcpp::List, const char*);
}

//' @keywords internal
//' @noRd
// [[Rcpp::export(rng = false)]]
Rcpp::List rcpp_quadform_geodesics_method(Rcpp::NumericMatrix A,
    Rcpp::NumericVector from,Rcpp::NumericVector to,Rcpp::List domain,
    std::string method,Rcpp::List control){
  if(method=="polyhedral_mesh"||method=="delaunay_graph"||method=="radius_graph")
    return qgr::solve(A,from,to,domain,method,control);
  if(A.nrow()!=2||A.ncol()!=2||A(0,1)!=A(1,0))Rcpp::stop("A must be symmetric and 2 by 2");
  for(double x:A)if(!std::isfinite(x))Rcpp::stop("A must be finite");
  std::array<double,4> a{{A(0,0),A(0,1),A(1,0),A(1,1)}};
  auto u=qgn::point(from,"from"),v=qgn::point(to,"to");
  qgn::Domain d{};std::string kind=Rcpp::as<std::string>(domain["kind"]);
  if(kind=="ball"){
    d.disk=true;d.center=qgn::point(domain["center"],"center");
    d.radius=qgn::scalar(domain,"radius",std::numeric_limits<double>::min(),1e150,false);
  }else if(kind=="box"){
    d.lower=qgn::point(domain["lower"],"lower");d.upper=qgn::point(domain["upper"],"upper");
    for(int j=0;j<2;++j)if(!(d.lower[j]<d.upper[j])||!std::isfinite(d.upper[j]-d.lower[j]))Rcpp::stop("Invalid box bounds");
  }else Rcpp::stop("Unknown domain kind");
  if(!d.inside(u)||!d.inside(v))Rcpp::stop("Endpoints must be inside the domain");
  qgm::Options o;o.max_seconds=qgn::scalar(control,"max_seconds",0,std::numeric_limits<double>::infinity(),false);
  qgm::Result s;
  if(method=="grid_dijkstra"){
    Rcpp::NumericVector size=control["grid_size"];
    if(size.size()!=2)Rcpp::stop("grid_size must have two entries");
    for(double x:size)if(!std::isfinite(x)||x<3||x>257||x!=std::floor(x))Rcpp::stop("Invalid grid_size");
    o.nx=size[0];o.ny=size[1];o.directions=qgn::scalar(control,"direction_radius",1,8,true);
    o.attachments=qgn::scalar(control,"endpoint_neighbors",1,32,true);
    o.max_edges=qgn::scalar(control,"max_edges",0,2000000,true);
    o.direct=qgn::flag(control,"include_direct");o.keep_graph=qgn::flag(control,"keep_graph");
    s=qgm::grid(a,d,u,v,o);
  }else if(method=="paraboloid_clairaut"){
    o.iterations=qgn::scalar(control,"iterations",1,256,true);
    o.samples=qgn::scalar(control,"path_samples",3,4097,true);
    o.domain_depth=qgn::scalar(control,"domain_check_depth",0,20,true);
    o.angle_tolerance=qgn::scalar(control,"angle_tolerance",1e-15,1e-8,false);
    s=qgm::clairaut(a,d,u,v,o);
  }else if(method=="boundary_optimization"){
    qgb::Options b;b.max_seconds=o.max_seconds;
    b.initial_edges=qgn::scalar(control,"initial_edges",2,64,true);
    b.levels=qgn::scalar(control,"levels",1,3,true);
    b.evaluations_per_start=qgn::scalar(control,"evaluations_per_start",1,100000,true);
    b.max_evaluations=qgn::scalar(control,"max_evaluations",0,1000000,true);
    b.position_tolerance=qgn::scalar(control,"position_tolerance",1e-10,1e-2,false);
    b.initial_step=qgn::scalar(control,"initial_step",1e-6,.5,false);
    Rcpp::NumericVector bends=control["initial_bends"];
    if(bends.hasAttribute("dim")||bends.size()<1||bends.size()>9)Rcpp::stop("initial_bends must be a vector of 1 to 9 values");
    b.bends.clear();for(double x:bends){
      if(!std::isfinite(x)||std::abs(x)>4||std::find(b.bends.begin(),b.bends.end(),x)!=b.bends.end())
        Rcpp::stop("Invalid initial_bends");
      b.bends.push_back(x);
    }
    if(!Rf_isNull(control["initial_path"])){
      Rcpp::NumericMatrix path=control["initial_path"];
      if(path.ncol()!=2||path.nrow()<2||path.nrow()>65)Rcpp::stop("initial_path must have 2 to 65 rows and two columns");
      for(int i=0;i<path.nrow();++i){qgn::Point p{{path(i,0),path(i,1)}};
        if(!std::isfinite(p[0])||!std::isfinite(p[1])||!d.inside(p))Rcpp::stop("initial_path must be finite and inside the domain");b.initial_path.push_back(p);}
      if(b.initial_path.front()!=u||b.initial_path.back()!=v)Rcpp::stop("initial_path endpoints must match from and to");
    }
    s=qgb::solve(a,d,u,v,b);
  }else if(method=="geodesic_shooting"||method=="geodesic_collocation"){
    qgc::Options c;c.max_seconds=o.max_seconds;
    c.ode_tolerance=qgn::scalar(control,"ode_tolerance",1e-10,1e-2,false);
    c.endpoint_tolerance=qgn::scalar(control,"endpoint_tolerance",1e-12,1e-3,false);
    c.path_tolerance=qgn::scalar(control,"path_tolerance",1e-10,1e-2,false);
    if(method=="geodesic_shooting")c.integration_tolerance=qgn::scalar(control,"integration_tolerance",1e-13,1e-5,false);
    c.iterations=qgn::scalar(control,"iterations",1,100,true);
    c.continuation_steps=qgn::scalar(control,"continuation_steps",1,128,true);
    c.continuation_attempts=qgn::scalar(control,"continuation_attempts",1,1024,true);
    c.initial_nodes=qgn::scalar(control,"initial_nodes",3,257,true);
    c.max_nodes=qgn::scalar(control,"max_nodes",3,4097,true);
    if(c.max_nodes<c.initial_nodes)Rcpp::stop("max_nodes must be at least initial_nodes");
    c.max_path_vertices=qgn::scalar(control,"max_path_vertices",3,65537,true);
    c.max_evaluations=qgn::scalar(control,"max_evaluations",0,10000000,true);
    c.domain_depth=qgn::scalar(control,"domain_check_depth",0,24,true);
    Rcpp::NumericVector bends=control["initial_bends"];
    if(bends.hasAttribute("dim"))Rcpp::stop("initial_bends must be a vector");
    if(bends.size()<1||bends.size()>9)Rcpp::stop("initial_bends must contain 1 to 9 values");
    c.bends.clear();for(double b:bends){
      if(!std::isfinite(b)||std::abs(b)>4)Rcpp::stop("initial_bends must be finite and between -4 and 4");
      if(std::find(c.bends.begin(),c.bends.end(),b)!=c.bends.end())Rcpp::stop("initial_bends must be distinct");
      c.bends.push_back(b);
    }
    s=qgc::solve(a,d,u,v,c,method=="geodesic_collocation");
  }else Rcpp::stop("Unknown native geodesic method");
  Rcpp::NumericMatrix lifted(s.path.size(),3);
  for(size_t i=0;i<s.path.size();++i){
    lifted(i,0)=s.path[i][0];lifted(i,1)=s.path[i][1];lifted(i,2)=qgn::surface_height(a,s.path[i]);
    if(!std::isfinite(lifted(i,2)))Rcpp::stop("Surface height overflow at returned point");
  }
  Rcpp::List diagnostics;
  for(const auto& x:s.numbers)diagnostics[x.first]=x.second;
  for(const auto& x:s.labels)diagnostics[x.first]=x.second;
  Rcpp::IntegerMatrix edges(s.edges.size(),2);
  for(size_t i=0;i<s.edges.size();++i){edges(i,0)=s.edges[i][0]+1;edges(i,1)=s.edges[i][1]+1;}
  Rcpp::RObject graph=R_NilValue;
  if(o.keep_graph)graph=Rcpp::List::create(Rcpp::_["vertices"]=qgn::matrix(s.vertices,false),
    Rcpp::_["edges"]=edges,Rcpp::_["weights"]=s.weights);
  return Rcpp::List::create(Rcpp::_["status"]=s.status,Rcpp::_["termination"]=s.termination,
    Rcpp::_["implementation"]="self-contained-cpp-"+method+"-v1",
    Rcpp::_["length"]=std::isfinite(s.length)?s.length:NA_REAL,
    Rcpp::_["error_estimate"]=std::isfinite(s.error)?s.error:NA_REAL,
    Rcpp::_["path"]=qgn::matrix(s.path,false),Rcpp::_["surface_path"]=lifted,
    Rcpp::_["path_representation"]=s.representation,Rcpp::_["curve_parameters"]=s.curve,
    Rcpp::_["diagnostics"]=diagnostics,Rcpp::_["graph"]=graph,
    Rcpp::_["configuration"]=control,Rcpp::_["state_saving"]=false);
}
