#ifndef GRAPH_KERNEL_SMOOTHER_HPP
#define GRAPH_KERNEL_SMOOTHER_HPP

#include <vector>
#include <cstddef>
using std::size_t;

/**
 * @brief Return structure for graph kernel smoother
 */
struct graph_kernel_smoother_t {
    std::vector<double> predictions;                 ///< predictions[i] is an estimate of E(Y|G) at the i-th vertex at the optimal bw, so predictions = bw_predictions[opt_bw_idx]
    std::vector<std::vector<double>> bw_predictions; ///< bw_predictions[bw_idx] are predictions for the bandwidth index 'bw_idx'
    std::vector<double> bw_mean_abs_errors;          ///< bw_mean_abs_errors[bw_idx] is the mean prediction absolute error for the bw_idx-th bandwidth
    std::vector<double> vertex_min_bws;              ///< vertex_min_bws[i] is the the i-th vertex's minimum bandwidth
    size_t opt_bw_idx;                               ///< the index of opt_bw in bws - the index is the same for all vertices
    size_t buffer_hops_used;                         ///< the number of buffer hops actually used (when in the auto buffer hops mode)
};

#endif // GRAPH_KERNEL_SMOOTHER_HPP
