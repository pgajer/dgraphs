#ifndef GEODESIC_STATS_R_H_
#define GEODESIC_STATS_R_H_

#include <Rinternals.h>

// C interface declarations
#ifdef __cplusplus
extern "C" {
#endif

SEXP S_compute_geodesic_stats(
	SEXP adj_list_sexp,
	SEXP weight_list_sexp,
	SEXP min_radius_sexp,
	SEXP max_radius_sexp,
	SEXP n_steps_sexp,
	SEXP n_packing_vertices_sexp,
	SEXP max_packing_iterations_sexp,
	SEXP packing_precision_sexp,
	SEXP verbose_sexp
	);

	SEXP S_compute_vertex_geodesic_stats(
		SEXP adj_list_sexp,
		SEXP weight_list_sexp,
		SEXP grid_vertex_sexp,
		SEXP min_radius_sexp,
		SEXP max_radius_sexp,
		SEXP n_steps_sexp,
		SEXP n_packing_vertices_sexp,
		SEXP packing_precision_sexp
	);

#ifdef __cplusplus
}
#endif
#endif // GEODESIC_STATS_R_H_
