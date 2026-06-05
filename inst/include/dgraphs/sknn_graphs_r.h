#ifndef GFLOW_SKNN_GRAPHS_R_H
#define GFLOW_SKNN_GRAPHS_R_H

#include <Rinternals.h>

#ifdef __cplusplus
extern "C" {
#endif

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

#ifdef __cplusplus
}
#endif

#endif
