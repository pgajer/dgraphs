#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

extern "C" {

SEXP S_adaptive_radius_edges_ann(SEXP s_X,
                                 SEXP s_k_scale,
                                 SEXP s_radius_factor,
                                 SEXP s_radius_rule);
SEXP S_compute_mstree_total_length(SEXP s_X);
SEXP S_create_geodesic_iknn_graph(SEXP s_adj_list,
                                  SEXP s_weight_list,
                                  SEXP s_k);
SEXP S_create_iknn_graphs(SEXP s_X,
                          SEXP s_kmin,
                          SEXP s_kmax,
                          SEXP s_max_path_edge_ratio_thld,
                          SEXP s_path_edge_ratio_percentile,
                          SEXP s_threshold_percentile,
                          SEXP s_compute_full,
                          SEXP s_with_isize_pruning,
                          SEXP s_with_edge_pruning_stats,
                          SEXP s_n_cores,
                          SEXP s_parallel_mode,
                          SEXP s_hybrid_batch_size,
                          SEXP s_knn_cache_path,
                          SEXP s_knn_cache_mode,
                          SEXP s_knn_metric,
                          SEXP s_linf_tol,
                          SEXP s_verbose);
SEXP S_create_mknn_graph(SEXP RX, SEXP Rk);
SEXP S_create_mknn_graphs(SEXP s_X,
                          SEXP s_kmin,
                          SEXP s_kmax,
                          SEXP s_max_path_edge_ratio_thld,
                          SEXP s_path_edge_ratio_percentile,
                          SEXP s_compute_full,
                          SEXP s_verbose);
SEXP S_create_mst_completion_graph(SEXP s_X,
                                   SEXP s_q_thld,
                                   SEXP s_verbose);
SEXP S_create_maximal_packing(SEXP s_adj_list,
                              SEXP s_weight_list,
                              SEXP s_grid_size,
                              SEXP s_max_iterations,
                              SEXP s_precision);
SEXP S_create_path_graph_plus(SEXP s_adj_list,
                              SEXP s_edge_length_list,
                              SEXP s_h);
SEXP S_create_path_graph_plm(SEXP s_adj_list,
                             SEXP s_edge_length_list,
                             SEXP s_h);
SEXP S_create_path_graph_series(SEXP s_adj_list,
                                SEXP s_weight_list,
                                SEXP s_h_values);
SEXP S_create_single_iknn_graph(SEXP s_X,
                                SEXP s_k,
                                SEXP s_max_path_edge_ratio_thld,
                                SEXP s_path_edge_ratio_percentile,
                                SEXP s_threshold_percentile,
                                SEXP s_compute_full,
                                SEXP s_with_isize_pruning,
                                SEXP s_with_edge_pruning_stats,
                                SEXP s_knn_cache_path,
                                SEXP s_knn_cache_mode,
                                SEXP s_knn_metric,
                                SEXP s_linf_tol,
                                SEXP s_verbose);
SEXP S_create_sknn_graph(SEXP s_X,
                         SEXP s_k,
                         SEXP s_connect_components,
                         SEXP s_connect_method,
                         SEXP s_neighbor_method,
                         SEXP s_ann_eps,
                         SEXP s_knn_index,
                         SEXP s_bridge_knn_index,
                         SEXP s_bridge_k,
                         SEXP s_bridge_k_max,
                         SEXP s_bridge_growth,
                         SEXP s_prune_edges,
                         SEXP s_prune_method,
                         SEXP s_prune_tau,
                         SEXP s_prune_local_k,
                         SEXP s_with_pruned_edge_stats);
SEXP S_create_uniform_grid_graph(SEXP s_adj_list,
                                 SEXP s_weight_list,
                                 SEXP s_grid_size,
                                 SEXP s_start_vertex,
                                 SEXP s_snap_tolerance);
SEXP S_graph_connected_components(SEXP R_graph);
SEXP S_graph_spectrum(SEXP Rgraph, SEXP Rnev);
SEXP S_graph_spectrum_plus(SEXP Rgraph, SEXP Rnev, SEXP Rreturn_dense);
SEXP S_compute_geodesic_stats(SEXP adj_list_sexp,
                              SEXP weight_list_sexp,
                              SEXP min_radius_sexp,
                              SEXP max_radius_sexp,
                              SEXP n_steps_sexp,
                              SEXP n_packing_vertices_sexp,
                              SEXP max_packing_iterations_sexp,
                              SEXP packing_precision_sexp,
                              SEXP verbose_sexp);
SEXP S_compute_vertex_geodesic_stats(SEXP adj_list_sexp,
                                     SEXP weight_list_sexp,
                                     SEXP grid_vertex_sexp,
                                     SEXP min_radius_sexp,
                                     SEXP max_radius_sexp,
                                     SEXP n_steps_sexp,
                                     SEXP n_packing_vertices_sexp,
                                     SEXP packing_precision_sexp);
SEXP S_geodesic_core_endpoints(SEXP s_adj_list,
                               SEXP s_weight_list,
                               SEXP s_core_quantile,
                               SEXP s_endpoint_quantile,
                               SEXP s_use_approx_eccentricity,
                               SEXP s_n_landmarks,
                               SEXP s_max_endpoints,
                               SEXP s_seed,
                               SEXP s_verbose);
SEXP _dgraphs_rcpp_compute_graph_endpoint_scores(SEXP adj_list_sexp,
                                                 SEXP weight_list_sexp,
                                                 SEXP layout_3d_sexp,
                                                 SEXP scales_sexp,
                                                 SEXP neighborhood_sexp,
                                                 SEXP q_sexp,
                                                 SEXP neighbor_weighting_sexp,
                                                 SEXP gaussian_sigma_sexp,
                                                 SEXP min_neighborhood_size_sexp);
SEXP _dgraphs_rcpp_graph_greedy_maxima_suppression_by_scale(SEXP adj_list_sexp,
                                                            SEXP weight_list_sexp,
                                                            SEXP local_max_by_scale_sexp,
                                                            SEXP score_by_scale_sexp,
                                                            SEXP radius_sexp);
SEXP _dgraphs_rcpp_graph_multi_source_support_by_scale(SEXP adj_list_sexp,
                                                       SEXP weight_list_sexp,
                                                       SEXP local_max_by_scale_sexp,
                                                       SEXP radius_sexp);
SEXP S_kNN(SEXP RX, SEXP Rk);
SEXP S_linf_simplex_knn(SEXP s_X, SEXP s_k, SEXP s_linf_tol);
SEXP S_mstree(SEXP X);
SEXP S_prune_graph_global_geodesic_ratio(SEXP s_adj_list,
                                         SEXP s_weight_list,
                                         SEXP s_max_ratio_threshold,
                                         SEXP s_path_edge_ratio_percentile,
                                         SEXP s_with_pruned_edge_stats);
SEXP S_prune_graph_local_geodesic(SEXP s_X,
                                  SEXP s_adj_list,
                                  SEXP s_weight_list,
                                  SEXP s_prune_tau,
                                  SEXP s_prune_local_k,
                                  SEXP s_with_pruned_edge_stats);
SEXP S_shortest_path(SEXP s_graph,
                     SEXP s_edge_lengths,
                     SEXP s_vertices);
SEXP S_wgraph_prune_long_edges(SEXP s_adj_list,
                               SEXP s_edge_length_list,
                               SEXP s_alt_path_len_ratio_thld,
                               SEXP s_use_total_length_constraint,
                               SEXP s_verbose);

static const R_CallMethodDef CallEntries[] = {
    {"S_adaptive_radius_edges_ann", (DL_FUNC) &S_adaptive_radius_edges_ann, 4},
    {"S_compute_mstree_total_length", (DL_FUNC) &S_compute_mstree_total_length, 1},
    {"S_create_geodesic_iknn_graph", (DL_FUNC) &S_create_geodesic_iknn_graph, 3},
    {"S_create_iknn_graphs", (DL_FUNC) &S_create_iknn_graphs, 17},
    {"S_create_mknn_graph", (DL_FUNC) &S_create_mknn_graph, 2},
    {"S_create_mknn_graphs", (DL_FUNC) &S_create_mknn_graphs, 7},
    {"S_create_mst_completion_graph", (DL_FUNC) &S_create_mst_completion_graph, 3},
    {"S_create_maximal_packing", (DL_FUNC) &S_create_maximal_packing, 5},
    {"S_create_path_graph_plus", (DL_FUNC) &S_create_path_graph_plus, 3},
    {"S_create_path_graph_plm", (DL_FUNC) &S_create_path_graph_plm, 3},
    {"S_create_path_graph_series", (DL_FUNC) &S_create_path_graph_series, 3},
    {"S_create_single_iknn_graph", (DL_FUNC) &S_create_single_iknn_graph, 13},
    {"S_create_sknn_graph", (DL_FUNC) &S_create_sknn_graph, 16},
    {"S_create_uniform_grid_graph", (DL_FUNC) &S_create_uniform_grid_graph, 5},
    {"S_graph_connected_components", (DL_FUNC) &S_graph_connected_components, 1},
    {"S_graph_spectrum", (DL_FUNC) &S_graph_spectrum, 2},
    {"S_graph_spectrum_plus", (DL_FUNC) &S_graph_spectrum_plus, 3},
    {"S_compute_geodesic_stats", (DL_FUNC) &S_compute_geodesic_stats, 9},
    {"S_compute_vertex_geodesic_stats", (DL_FUNC) &S_compute_vertex_geodesic_stats, 8},
    {"S_geodesic_core_endpoints", (DL_FUNC) &S_geodesic_core_endpoints, 9},
    {"_dgraphs_rcpp_compute_graph_endpoint_scores", (DL_FUNC) &_dgraphs_rcpp_compute_graph_endpoint_scores, 9},
    {"_dgraphs_rcpp_graph_greedy_maxima_suppression_by_scale", (DL_FUNC) &_dgraphs_rcpp_graph_greedy_maxima_suppression_by_scale, 5},
    {"_dgraphs_rcpp_graph_multi_source_support_by_scale", (DL_FUNC) &_dgraphs_rcpp_graph_multi_source_support_by_scale, 4},
    {"S_kNN", (DL_FUNC) &S_kNN, 2},
    {"S_linf_simplex_knn", (DL_FUNC) &S_linf_simplex_knn, 3},
    {"S_mstree", (DL_FUNC) &S_mstree, 1},
    {"S_prune_graph_global_geodesic_ratio", (DL_FUNC) &S_prune_graph_global_geodesic_ratio, 5},
    {"S_prune_graph_local_geodesic", (DL_FUNC) &S_prune_graph_local_geodesic, 6},
    {"S_shortest_path", (DL_FUNC) &S_shortest_path, 3},
    {"S_wgraph_prune_long_edges", (DL_FUNC) &S_wgraph_prune_long_edges, 5},
    {NULL, NULL, 0}
};

void R_init_dgraphs(DllInfo* dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}

} // extern "C"
