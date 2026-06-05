#include <Rcpp.h>

using Rcpp::List;
using Rcpp::LogicalMatrix;
using Rcpp::NumericMatrix;
using Rcpp::NumericVector;

Rcpp::List dgraphs_rcpp_compute_graph_endpoint_scores(
    const List& adj_list,
    const List& weight_list,
    const NumericMatrix& layout_3d,
    const NumericVector& scales,
    const std::string& neighborhood,
    double q,
    const std::string& neighbor_weighting,
    Rcpp::Nullable<double> gaussian_sigma,
    int min_neighborhood_size);

LogicalMatrix dgraphs_rcpp_graph_multi_source_support_by_scale(
    const List& adj_list,
    const List& weight_list,
    const LogicalMatrix& local_max_by_scale,
    double radius);

LogicalMatrix dgraphs_rcpp_graph_greedy_maxima_suppression_by_scale(
    const List& adj_list,
    const List& weight_list,
    const LogicalMatrix& local_max_by_scale,
    const NumericMatrix& score_by_scale,
    double radius);

extern "C" {

SEXP _dgraphs_rcpp_compute_graph_endpoint_scores(
    SEXP adj_list_sexp,
    SEXP weight_list_sexp,
    SEXP layout_3d_sexp,
    SEXP scales_sexp,
    SEXP neighborhood_sexp,
    SEXP q_sexp,
    SEXP neighbor_weighting_sexp,
    SEXP gaussian_sigma_sexp,
    SEXP min_neighborhood_size_sexp) {
  BEGIN_RCPP
  Rcpp::RObject result;
  Rcpp::RNGScope rng_scope;
  Rcpp::traits::input_parameter<const List&>::type adj_list(adj_list_sexp);
  Rcpp::traits::input_parameter<const List&>::type weight_list(weight_list_sexp);
  Rcpp::traits::input_parameter<const NumericMatrix&>::type layout_3d(layout_3d_sexp);
  Rcpp::traits::input_parameter<const NumericVector&>::type scales(scales_sexp);
  Rcpp::traits::input_parameter<const std::string&>::type neighborhood(neighborhood_sexp);
  Rcpp::traits::input_parameter<double>::type q(q_sexp);
  Rcpp::traits::input_parameter<const std::string&>::type neighbor_weighting(neighbor_weighting_sexp);
  Rcpp::traits::input_parameter<Rcpp::Nullable<double>>::type gaussian_sigma(gaussian_sigma_sexp);
  Rcpp::traits::input_parameter<int>::type min_neighborhood_size(min_neighborhood_size_sexp);
  result = Rcpp::wrap(dgraphs_rcpp_compute_graph_endpoint_scores(
      adj_list,
      weight_list,
      layout_3d,
      scales,
      neighborhood,
      q,
      neighbor_weighting,
      gaussian_sigma,
      min_neighborhood_size));
  return result;
  END_RCPP
}

SEXP _dgraphs_rcpp_graph_multi_source_support_by_scale(
    SEXP adj_list_sexp,
    SEXP weight_list_sexp,
    SEXP local_max_by_scale_sexp,
    SEXP radius_sexp) {
  BEGIN_RCPP
  Rcpp::RObject result;
  Rcpp::RNGScope rng_scope;
  Rcpp::traits::input_parameter<const List&>::type adj_list(adj_list_sexp);
  Rcpp::traits::input_parameter<const List&>::type weight_list(weight_list_sexp);
  Rcpp::traits::input_parameter<const LogicalMatrix&>::type local_max_by_scale(local_max_by_scale_sexp);
  Rcpp::traits::input_parameter<double>::type radius(radius_sexp);
  result = Rcpp::wrap(dgraphs_rcpp_graph_multi_source_support_by_scale(
      adj_list,
      weight_list,
      local_max_by_scale,
      radius));
  return result;
  END_RCPP
}

SEXP _dgraphs_rcpp_graph_greedy_maxima_suppression_by_scale(
    SEXP adj_list_sexp,
    SEXP weight_list_sexp,
    SEXP local_max_by_scale_sexp,
    SEXP score_by_scale_sexp,
    SEXP radius_sexp) {
  BEGIN_RCPP
  Rcpp::RObject result;
  Rcpp::RNGScope rng_scope;
  Rcpp::traits::input_parameter<const List&>::type adj_list(adj_list_sexp);
  Rcpp::traits::input_parameter<const List&>::type weight_list(weight_list_sexp);
  Rcpp::traits::input_parameter<const LogicalMatrix&>::type local_max_by_scale(local_max_by_scale_sexp);
  Rcpp::traits::input_parameter<const NumericMatrix&>::type score_by_scale(score_by_scale_sexp);
  Rcpp::traits::input_parameter<double>::type radius(radius_sexp);
  result = Rcpp::wrap(dgraphs_rcpp_graph_greedy_maxima_suppression_by_scale(
      adj_list,
      weight_list,
      local_max_by_scale,
      score_by_scale,
      radius));
  return result;
  END_RCPP
}

}  // extern "C"
