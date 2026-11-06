#ifndef EDGE_PRUNING_STATS_HPP
#define EDGE_PRUNING_STATS_HPP

#include <vector>    // For std::vector
#include <utility>   // For std::pair
#include <cstddef>   // For size_t
using std::size_t;

/**
 * @struct edge_pruning_stats_t
 * @brief Statistics for edges that can be potentially pruned based on geometric criteria
 */
struct edge_pruning_stats_t {
    struct edge_stats {
        size_t source;               ///< Source vertex of the edge
        size_t target;               ///< Target vertex of the edge
        double edge_length;          ///< Length of the edge
        double alt_path_length;      ///< Length of the alternative geodesic path
        double length_ratio;         ///< Ratio of alternative path length to edge length

        edge_stats(size_t s, size_t t, double el, double apl)
            : source(s), target(t), edge_length(el), alt_path_length(apl),
              length_ratio(apl / el) {}
    };

    std::vector<edge_stats> stats;   ///< Statistics for each edge analyzed
    double median_edge_length;       ///< Median length of all edges in the graph

    /**
     * @brief Get the list of edges that can be pruned based on a length ratio threshold
     *
     * This method filters the edge statistics to find edges whose alternative path to edge length
     * ratio is below or equal to the specified threshold.
     *
     * @param max_ratio_threshold Maximum acceptable ratio of alternative path length to edge length
     * @return Vector of (source, target) pairs representing prunable edges
     */
    std::vector<std::pair<size_t, size_t>> get_prunable_edges(double max_ratio_threshold = 1.2) const;
};

#endif // EDGE_PRUNING_STATS_HPP
