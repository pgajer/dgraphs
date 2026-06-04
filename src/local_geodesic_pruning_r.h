#ifndef GFLOW_LOCAL_GEODESIC_PRUNING_R_H
#define GFLOW_LOCAL_GEODESIC_PRUNING_R_H

#include <Rinternals.h>

#ifdef __cplusplus
extern "C" {
#endif

SEXP S_prune_graph_local_geodesic(SEXP s_X,
                                  SEXP s_adj_list,
                                  SEXP s_weight_list,
                                  SEXP s_prune_tau,
                                  SEXP s_prune_local_k,
                                  SEXP s_with_pruned_edge_stats);

SEXP S_prune_graph_global_geodesic_ratio(SEXP s_adj_list,
                                         SEXP s_weight_list,
                                         SEXP s_max_ratio_threshold,
                                         SEXP s_path_edge_ratio_percentile,
                                         SEXP s_with_pruned_edge_stats);

#ifdef __cplusplus
}
#endif

#endif
