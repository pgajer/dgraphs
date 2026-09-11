#include "quadform_geodesics_methods.h"
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
