#ifndef GRAPH_SPECTRUM_R_H_
#define GRAPH_SPECTRUM_R_H_

#include <Rinternals.h>

#ifdef __cplusplus
extern "C" {
#endif

SEXP S_graph_spectrum(SEXP Rgraph, SEXP Rnev);
SEXP S_graph_spectrum_plus(SEXP Rgraph, SEXP Rnev, SEXP Rreturn_dense);

#ifdef __cplusplus
}
#endif

#endif // GRAPH_SPECTRUM_R_H_
