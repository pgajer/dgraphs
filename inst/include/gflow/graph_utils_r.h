#ifndef GRAPH_UTILS_R_H_
#define GRAPH_UTILS_R_H_

#include <Rinternals.h>

#ifdef __cplusplus
extern "C" {
#endif

SEXP S_join_graphs(SEXP Rgraph1, SEXP Rgraph2, SEXP Ri1, SEXP Ri2);
SEXP S_convert_adjacency_to_edge_matrix(SEXP s_graph, SEXP s_weights);
SEXP S_convert_adjacency_to_edge_matrix_set(SEXP s_graph);
SEXP S_convert_adjacency_to_edge_matrix_unordered_set(SEXP s_graph);

#ifdef __cplusplus
}
#endif

#endif // GRAPH_UTILS_R_H_
