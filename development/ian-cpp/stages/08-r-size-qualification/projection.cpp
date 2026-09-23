#include "bridge.cpp"
extern "C" SEXP ian_projection_probe(SEXP mode) {
 BEGIN_RCPP
 if(Rcpp::as<int>(mode)==1)return r_object((std::uint64_t(1)<<53)+1);
 return Rcpp::List::create(Rcpp::Named("minimum")=r_object(std::int64_t(std::numeric_limits<int>::min())),Rcpp::Named("above_maximum")=r_object(std::int64_t(std::numeric_limits<int>::max())+1),Rcpp::Named("exact_double_limit")=r_object(std::uint64_t(1)<<53));
 END_RCPP
}
