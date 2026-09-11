#ifndef DGRAPHS_QUADFORM_GEODESICS_REFERENCE_H
#define DGRAPHS_QUADFORM_GEODESICS_REFERENCE_H
#include <Rcpp.h>
#include <array>
#include <functional>
#include <vector>
namespace qgr {
struct MeshResult {
  std::vector<std::array<double,3>> path;
  double distance=0,propagations=0,peak_intervals=0;
};
MeshResult mesh_path(const std::vector<double>&,const std::vector<unsigned>&,
  unsigned,unsigned,size_t,size_t,const std::function<void()>&);
Rcpp::List solve(Rcpp::NumericMatrix,Rcpp::NumericVector,Rcpp::NumericVector,
  Rcpp::List,std::string,Rcpp::List);
}
#endif
