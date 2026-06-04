#ifndef HARMONIC_SMOOTHER_H_
#define HARMONIC_SMOOTHER_H_

#include "basin.hpp"

#include <vector>
#include <unordered_map>
#include <cstddef>
using std::size_t;

/**
 * @brief Advanced harmonic smoothing with predictions landscape feature tracking
 *
 * @details This function extends the standard harmonic smoothing by tracking
 *          how local extrema and their basins evolve during the smoothing process.
 *          It aims to find the optimal "sweet spot" where noise is reduced but
 *          significant predictions landscape features are preserved.
 *
 * The algorithm proceeds through these key steps:
 * 1. Iteratively performs harmonic smoothing on the interior vertices
 * 2. Periodically captures the current function values and identifies local extrema/basins
 * 3. Monitors the stability of predictions landscape structure
 * 4. Identifies the iteration where predictions landscape structure stabilizes
 * 5. Returns both the smoothed values and the history of predictions landscape evolution
 *
 * @param[in,out] harmonic_predictions Vector of function values to be smoothed in place
 * @param[in] region_vertices Set of vertex indices that define the region to smooth
 * @param[in] max_iterations Maximum number of relaxation iterations to perform (default: 100)
 * @param[in] tolerance Convergence threshold for value changes (default: 1e-6)
 * @param[in] record_frequency Frequency at which to record states (default: 1, record every iteration)
 * @param[in] stability_window Number of consecutive iterations to check for stability (default: 3)
 * @param[in] stability_threshold Threshold for considering predictions landscape stable (default: 0.05)
 *
 * @return A harmonic_smoother_t structure containing:
 *         - i_harmonic_predictions: Vector of function values at recorded iterations
 *         - i_basins: Vector of extrema basin maps at recorded iterations
 *         - stable_iteration: The iteration where predictions landscape stabilized
 *         - basin_cx_differences: Differences between consecutive recorded iterations
 *
 * @pre The size of harmonic_predictions must match the number of vertices in the graph
 * @pre All vertices in region_vertices must have valid indices less than the graph size
 *
 * @see perform_harmonic_smoothing
 * @see compute_basins
 * @see find_local_extremum_bfs_basin
 */
struct harmonic_smoother_t {
    std::vector<std::vector<double>> i_harmonic_predictions;   ///< Function values at each recorded iteration
    std::vector<std::unordered_map<size_t, basin_t>> i_basins; ///< Basin maps at each recorded iteration
    size_t stable_iteration = 0;                               ///< Iteration at which topology stabilized
    std::vector<double> basin_cx_differences;                  ///< basin complex differences between consecutive iterations

    /**
     * @brief Determines if the basin complex structure has stabilized over recent iterations
     *
     * @param window_size Number of consecutive iterations to check
     * @param threshold Maximum allowed difference to consider stable
     * @return True if topology has stabilized, false otherwise
     */
    bool is_basin_cx_stable(size_t window_size = 3, double threshold = 0.05) const {
        if (basin_cx_differences.size() < window_size) {
            return false;
        }

        // Check if the last 'window_size' differences are all below threshold
        for (size_t i = basin_cx_differences.size() - window_size; i < basin_cx_differences.size(); ++i) {
            if (basin_cx_differences[i] > threshold) {
                return false;
            }
        }

        return true;
    }
};

/**
 * @brief Diagnostics for harmonic smoothing.
 *
 * Stores per-iteration diagnostics:
 * - max_change[k]   = max_{v in I} |f_{k}(v) - f_{k-1}(v)|
 * - max_residual[k] = max_{v in I} |f_k(v) - avg_w(f_k(N(v) ∩ R))|
 */
struct harmonic_smoothing_stats_t {
    int num_iterations = 0;
    bool converged = false;

    std::vector<double> max_change;   // length == num_iterations
    std::vector<double> max_residual; // length == num_iterations

    size_t num_region = 0;
    size_t num_boundary = 0;
    size_t num_interior = 0;
};

#endif // HARMONIC_SMOOTHER_H_
