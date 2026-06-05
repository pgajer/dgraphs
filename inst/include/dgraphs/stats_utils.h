#ifndef STATS_UTILS_H_
#define STATS_UTILS_H_

#include <R.h>
#include <Rinternals.h>

#ifdef __cplusplus
extern "C" {
#endif

/* External function declarations from c_random_sampling.c */
void C_runif_simplex(const int *rK, double *lambda);
void C_rsimplex(const double *w, const int *rn, double *lambda);

/* Structure for integer arrays */
typedef struct {
    int *x;    /* Array of integers */
    int size;  /* Size of the array */
} iarray_t;

double mean(const double *x, int n );
double wmean(const double *x, const double *w, int n);
double median(double *a, int n );
double* runif_hcube(int n, int dim, double* L, double w);
int dcmp( void const *e1, void const *e2 );

void C_matrix_wmeans(const double *TY,
                     const int    *nrTY,
                     const int    *ncTY,
                     const int    *Tnn_i,
                     const double *Tnn_w,
                     const int    *nrTnn,
                     const int    *ncTnn,
                     const int    *maxK,
                           double *EYg);

void C_columnwise_wmean(const double *nn_y,
                        const double *nn_w,
                        const int *maxK,
                        const int *rnr,
                        const int *rnc,
                        double *Ey);

void C_columnwise_wmean_BB(const double *nn_y,
                           const double *nn_w,
                           const int *maxK,
                           const int *rnr,
                           const int *rnc,
                           const int *rnBB,
                           double *Ey);

void C_columnwise_wmean_BB_qCrI(const int    *rybinary,
                               const double *nn_y,
                               const double *nn_w,
                               const int    *maxK,
                               const int    *rnr,
                               const int    *rnc,
                               const int    *rnBB,
                               const double *ralpha,
                               double *Eyg_CI);

void C_columnwise_wmean_BB_CrI_1(const double *Ey,
                                const double *nn_y,
                                const double *nn_w,
                                const int *maxK,
                                const int *rnr,
                                const int *rnc,
                                const int *rnBB,
                                double *madEy);

void C_columnwise_wmean_BB_CrI_2(const double *Ey,
                                const double *nn_y,
                                const double *nn_w,
                                const int *maxK,
                                const int *rnr,
                                const int *rnc,
                                const int *rnBB,
                                double *Ey_CI);

void C_quantiles(const double *x, const int *rn, const double *probs, const int *rnprobs, double *quants);

void C_modified_columnwise_wmean_BB(const double *nn_y,
                                    const double *nn_w,
                                    const int    *maxK,
                                    const int    *rnr,
                                    const int    *rnc,
                                    const int    *rnBB,
                                          double *Ey);

void C_columnwise_eval(const int    *nn_i,
                       const int    *rK,
                       const int    *rng,
                       const double *x,
                             double *nn_x);

void C_mat_columnwise_divide(      double *TX,
                             const int    *rnrTX,
                             const int    *rncTX,
                             const double *y);

void C_normalize_dist(const double *d,
                      const int    *rnr,
                      const int    *rnc,
                      const int    *rminK,
                      const double *rbw,
                            double *nd,
                            double *r);

void C_normalize_dist_with_minK_a(const double *x,
                                  const int    *rnr,
                                  const int    *rnc,
                                  const int    *minK,
                                  const double *rbw,
                                        double *y);

void C_samplewr(const int *rn, int *mult);

void C_permute(int *x, int n);

void C_dpermute(double *x, int n);

void C_vpermute(int *x, int *rn, int *y);

/* Internal helper functions */
iarray_t * get_folds(int n, int nfolds);
int cmp_double(const void *a, const void *b);

void C_v_get_folds(const int *rn,
                   const int *rnfolds,
                         int *folds);

void C_winsorize(const double *y, const int *rn, const double *rp, double *wy);

void C_pdistr(const double *x,
              const int    *rnx,
              const double *rz,
                    double *p);

void C_pearson_cor(const double *x, const double *y, const int *rn, double *rc);

void C_wcov(const double *x, const double *y, const double *w, const int *rn, double *rwc);

void C_pearson_wcor(const double *x, const double *y, const double *w, const int *rn, double *rwc);

void C_pearson_wcor_BB_qCrI(const double *nn_y1,
                            const double *nn_y2,
                            const int    *nn_i,
                            const double *nn_w,
                            const int    *rK,
                            const int    *rng,
                            const int    *rnx,
                            const int    *rnBB,
                            const double *ralpha,
                                  double *qCI);

void C_density_distance(const double *X,
                        const int    *rdim,
                        const int    *rnrX,
                        const double *density,
                        double       *dist);

void C_rmatrix(const double* X,
               const int *rnX,
               const int *rdim,
               double* Q,
               const int *rnQ);

/* SEXP functions */
SEXP S_pdistr(SEXP sx, SEXP sz);
SEXP S_lwcor(SEXP Snn_i, SEXP Snn_w, SEXP SY);
SEXP S_lwcor_yY(SEXP Snn_i, SEXP Snn_w, SEXP SY, SEXP Sy);

#ifdef __cplusplus
}
#endif

#endif // STATS_UTILS_H_
