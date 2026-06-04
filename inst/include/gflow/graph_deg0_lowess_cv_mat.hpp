#ifndef GRAPH_DEG0_LOWESS_CV_MAT_H_
#define GRAPH_DEG0_LOWESS_CV_MAT_H_

#include <vector>
#include <cstddef>
using std::size_t;

/**
 * @brief Return structure for matrix version of graph degree 0 LOWESS with cross-validation
 */
struct graph_deg0_lowess_cv_mat_t {
    std::vector<std::vector<double>> predictions;       ///< predictions[j][i] is an estimate of E(Y_j|G) at the i-th vertex
    std::vector<std::vector<std::vector<double>>> bw_predictions; ///< bw_predictions[j][bw_idx] are predictions for response j, bandwidth index 'bw_idx'
    std::vector<std::vector<double>> bw_errors;         ///< bw_errors[j][bw_idx] the prediction error for response j, bw with index bw_idx
    std::vector<double> bws;                           ///< bws[i] is the i-th radius/bandwidth
    std::vector<double> opt_bws;                       ///< optimal bandwidth value for each response variable
    std::vector<size_t> opt_bw_idxs;                   ///< the index of opt_bw in bws for each response variable
};

#endif // GRAPH_DEG0_LOWESS_CV_MAT_H_
