#ifndef PRUNING_LONG_EDGES_R_H_
#define PRUNING_LONG_EDGES_R_H_

#include <Rinternals.h>

#ifdef __cplusplus
extern "C" {
#endif

SEXP S_find_shortest_alt_path(SEXP s_adj_list,
                              SEXP s_isize_list,
                              SEXP s_source,
                              SEXP s_target,
                              SEXP s_edge_isize);

SEXP S_shortest_alt_path_length(SEXP s_adj_list,
                                SEXP s_isize_list,
                                SEXP s_source,
                                SEXP s_target,
                                SEXP s_edge_isize);

SEXP S_wgraph_prune_long_edges(SEXP s_adj_list,
                               SEXP s_edge_length_list,
                               SEXP s_alt_path_len_ratio_thld,
                               SEXP s_use_total_length_constraint,
                               SEXP s_verbose);

#ifdef __cplusplus
}
#endif

#endif // PRUNING_LONG_EDGES_R_H_
