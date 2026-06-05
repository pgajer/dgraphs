#ifndef DGRAPHS_GRAPH_CORE_ENDPOINTS_R_H_
#define DGRAPHS_GRAPH_CORE_ENDPOINTS_R_H_

#include <R.h>
#include <Rinternals.h>

#ifdef __cplusplus
extern "C" {
#endif

SEXP S_geodesic_core_endpoints(SEXP s_adj_list,
                               SEXP s_weight_list,
                               SEXP s_core_quantile,
                               SEXP s_endpoint_quantile,
                               SEXP s_use_approx_eccentricity,
                               SEXP s_n_landmarks,
                               SEXP s_max_endpoints,
                               SEXP s_seed,
                               SEXP s_verbose);

SEXP S_detect_major_arms(SEXP s_adj_list,
                         SEXP s_weight_list,
                         SEXP s_core_quantile,
                         SEXP s_use_approx_eccentricity,
                         SEXP s_n_landmarks,
                         SEXP s_min_arm_size,
                         SEXP s_min_persistence_quantile,
                         SEXP s_min_length_quantile,
                         SEXP s_max_arms,
                         SEXP s_seed,
                         SEXP s_verbose);

#ifdef __cplusplus
}
#endif

#endif // DGRAPHS_GRAPH_CORE_ENDPOINTS_R_H_
