#ifndef GRAPH_MAXIMAL_PACKING_R_H_
#define GRAPH_MAXIMAL_PACKING_R_H_

#include <Rinternals.h>

// C interface declarations
#ifdef __cplusplus
extern "C" {
#endif

	SEXP S_create_maximal_packing(SEXP s_adj_list,
								  SEXP s_weight_list,
								  SEXP s_grid_size,
								  SEXP s_max_iterations,
								  SEXP s_precission);
#ifdef __cplusplus
}
#endif
#endif // GRAPH_MAXIMAL_PACKING_R_H_
