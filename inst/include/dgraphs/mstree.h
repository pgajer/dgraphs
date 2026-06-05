#ifndef GFLOW_MSTREE_H_
#define GFLOW_MSTREE_H_

#ifdef __cplusplus
extern "C" {
#endif

void C_mstree(const int    *riinit,
              const int    *nn_i,
              const double *nn_d,
              const double *rldist,
              const int    *rn_points,
                    int    *edges,
                    double *edge_lens);

#ifdef __cplusplus
}
#endif

#endif // GFLOW_MSTREE_H_
