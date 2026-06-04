/**
 * @file gfc.hpp
 * @brief Gradient Flow Complex (GFC) computation with refinement pipeline
 *
 * This header defines data structures and functions for computing refined
 * gradient flow complexes from scalar functions on weighted graphs. The
 * refinement pipeline includes relative value filtering, overlap-based
 * clustering, geometric filtering, and basin expansion.
 *
 * The GFC computation serves as the foundation for association analysis
 * via gradient flow, enabling robust measurement of relationships between
 * functions defined on the same graph structure.
 */

#ifndef GFC_HPP
#define GFC_HPP

#include <vector>
#include <unordered_map>
#include <unordered_set>
#include <string>
#include <cstddef>
#include <limits>
#include <algorithm>
#include <queue>
#include <cmath>
#include <map>

#include <Eigen/Core>

#include "gradient_basin.hpp"   // For trajectory_set_t
#include "gflow_modulation.hpp" // For gflow_modulation_t

// Forward declaration
struct set_wgraph_t;

using std::size_t;

// ============================================================================
// Parameter Structures
// ============================================================================

/**
 * @brief Parameters controlling the GFC refinement pipeline
 *
 * This structure encapsulates all parameters that control the basin
 * refinement process, from initial computation through filtering,
 * clustering, and expansion stages.
 */
struct gfc_params_t {
    // Edge length threshold for basin construction (quantile)
    double edge_length_quantile_thld = 0.9;

    // Relative value filtering parameters
    bool apply_relvalue_filter = true;
    double min_rel_value_max = 1.1;   ///< Minimum relative value for maxima
    double max_rel_value_min = 0.9;   ///< Maximum relative value for minima

    // Clustering parameters
    bool apply_maxima_clustering = true;
    bool apply_minima_clustering = true;
    double max_overlap_threshold = 0.15;  ///< Overlap distance threshold for maxima
    double min_overlap_threshold = 0.15;  ///< Overlap distance threshold for minima

    // Geometric filtering parameters
    bool apply_geometric_filter = true;
    double p_mean_nbrs_dist_threshold = 0.9;  ///< Percentile threshold for mean neighbor distance (maxima only)
    double p_mean_hopk_dist_threshold = 0.9;  ///< Percentile threshold for hop-k distance
    double p_deg_threshold = 0.9;             ///< Percentile threshold for degree

    int min_basin_size = 10;                  ///< Minimum basin size to retain

    /// Minimum number of trajectories required to keep an extremum non-spurious
    /// 0 disables this criterion
    int min_n_trajectories = 0;

    // Basin expansion
    bool expand_basins = true;  ///< Whether to expand basins to cover all vertices

    // Auxiliary parameters
    int hop_k = 2;  ///< Hop distance for summary statistics
    bool with_trajectories = false;
    int max_chain_depth = 5;

    // Default constructor with sensible defaults
    gfc_params_t() = default;
};

// ============================================================================
// Basin Data Structures
// ============================================================================

/**
 * @brief Basin structure with boundary information
 *
 * Represents the basin of attraction of a local extremum, including
 * the boundary vertices needed for Dirichlet harmonic extension.
 */
struct bbasin_t {
    size_t extremum_vertex;           ///< Local extremum vertex (basin attractor)
    double value;                     ///< Function value at extremum
    bool is_maximum;                  ///< True for max basin, false for min basin
    std::vector<size_t> vertices;     ///< Interior vertices of the basin
    std::vector<size_t> boundary;     ///< Boundary vertices (neighbors outside basin)

    // Optional: for diagnostics
    size_t hop_idx;                   ///< Hop index of the extremum (if computed)
};

/**
 * @brief Parameters for modulated gradient flow basin computation
 */
struct gfc_basin_params_t {
    gflow_modulation_t modulation = gflow_modulation_t::NONE;

    // For DENSITY modulation: density at each vertex
    // If empty and DENSITY requested, compute from d1^{-1}
    std::vector<double> density;

    // For EDGELEN modulation: pre-computed edge length weights
    // If empty and EDGELEN requested, compute from edge length distribution
    // dl([v,u]) = kernel_density(length([v,u])) / max_density
    double edgelen_bandwidth = -1.0;  // KDE bandwidth; -1 = automatic (Silverman)
};

/**
 * @brief Compact representation of a single basin for output
 *
 * This structure provides a lightweight representation of a basin
 * suitable for returning to R, containing only the essential information
 * needed for downstream analysis.
 */
struct basin_compact_t {
    size_t extremum_vertex;            ///< 0-based vertex index of extremum
    double extremum_value;             ///< Function value at extremum
    bool is_maximum;                   ///< true = maximum basin, false = minimum
    std::vector<size_t> vertices;      ///< Basin member vertices (0-based)
    std::vector<int> hop_distances;    ///< Hop distance from extremum for each vertex
    int max_hop_distance;              ///< Maximum hop distance in basin

    // Trajectory data (only populated when with_trajectories=true)
    std::vector<trajectory_set_t> trajectory_sets;
    std::vector<size_t> terminal_extrema;

    basin_compact_t()
        : extremum_vertex(0), extremum_value(0.0), is_maximum(true), max_hop_distance(0) {}
};

/**
 * @brief Summary statistics for a single extremum
 *
 * Contains computed statistics about each extremum and its basin,
 * used for filtering decisions and downstream reporting.
 */
struct extremum_summary_t {
    size_t vertex;              ///< 0-based vertex index
    double value;               ///< Function value at extremum
    double rel_value;           ///< Relative to median (value / median)
    bool is_maximum;            ///< Type of extremum
    int basin_size;             ///< Number of vertices in basin
    int hop_index;              ///< Maximum hop distance in basin (hop_idx)
    double p_mean_nbrs_dist;    ///< Percentile of mean distance to neighbors
    double p_mean_hopk_dist;    ///< Percentile of mean hop-k distance
    double deg_percentile;      ///< Degree percentile of extremum vertex
    int degree;                 ///< Degree of extremum vertex

    extremum_summary_t()
        : vertex(0), value(0.0), rel_value(1.0), is_maximum(true),
          basin_size(0), hop_index(0), p_mean_nbrs_dist(0.0),
          p_mean_hopk_dist(0.0), deg_percentile(0.0), degree(0) {}
};

/**
 * @brief Record of counts at each refinement stage
 */
struct stage_counts_t {
    std::string stage_name;
    int n_max_before;
    int n_max_after;
    int n_min_before;
    int n_min_after;

    stage_counts_t()
        : stage_name(""), n_max_before(0), n_max_after(0),
          n_min_before(0), n_min_after(0) {}

    stage_counts_t(const std::string& name, int max_b, int max_a, int min_b, int min_a)
        : stage_name(name), n_max_before(max_b), n_max_after(max_a),
          n_min_before(min_b), n_min_after(min_a) {}
};

/**
 * @brief A complete trajectory connecting a non-spurious minimum to a
 *        non-spurious maximum, potentially passing through spurious extrema.
 *
 * The path vector contains vertices from min_vertex to max_vertex, following
 * the gradient flow direction (ascending from minimum to maximum).
 */
struct joined_trajectory_t {
    size_t min_vertex;                          ///< Non-spurious local minimum (start)
    size_t max_vertex;                          ///< Non-spurious local maximum (end)
    std::vector<size_t> path;                   ///< Full vertex sequence from min to max
    std::vector<size_t> intermediate_extrema;   ///< Spurious extrema traversed (in order from min to max)
    double total_change;                        ///< y[max] - y[min]
    double path_length;                         ///< Sum of edge weights along path
};

/**
 * @brief Represents a chain from a spurious extremum to a non-spurious one.
 *
 * Used during the recursive extension process to find paths from spurious
 * minima back to non-spurious minima (or spurious maxima to non-spurious maxima).
 */
struct extension_chain_t {
    size_t target_vertex;                       ///< Non-spurious extremum reached
    std::vector<size_t> extension_path;         ///< Path from target to starting spurious extremum
    std::vector<size_t> intermediates;          ///< Spurious extrema traversed in chain
};

/**
 * @brief Complete GFC result for a single function
 *
 * Contains all output from the GFC computation including refined basins,
 * summary statistics, membership information, and stage history.
 */
struct gfc_result_t {
    // Refined basins
    std::vector<basin_compact_t> max_basins;  ///< Maximum basins after refinement
    std::vector<basin_compact_t> min_basins;  ///< Minimum basins after refinement

    // Summary statistics for each retained extremum
    std::vector<extremum_summary_t> max_summaries;
    std::vector<extremum_summary_t> min_summaries;

    // Vertex-to-basin membership (for multiplicity handling)
    // max_membership[v] = indices of max basins containing vertex v
    std::vector<std::vector<int>> max_membership;
    std::vector<std::vector<int>> min_membership;

    // Expanded basin assignments (if expand_basins = true)
    // expanded_max_assignment[v] = index of assigned max basin (-1 if none)
    std::vector<int> expanded_max_assignment;
    std::vector<int> expanded_min_assignment;

    // Stage history for reporting
    std::vector<stage_counts_t> stage_history;

    // Metadata
    size_t n_vertices;
    double y_median;

    // Parameters used (for reproducibility)
    gfc_params_t params;

    // Joined trajectories (only populated when with_trajectories=true)
    std::vector<joined_trajectory_t> joined_trajectories;

    // Cell map: (min_vertex, max_vertex) -> indices into joined_trajectories
    std::map<std::pair<size_t, size_t>, std::vector<size_t>> cell_map;

    gfc_result_t() : n_vertices(0), y_median(0.0) {}
};

// ============================================================================
// Helper Function Declarations
// ============================================================================

/**
 * @brief Compute overlap distance matrix using Szymkiewicz-Simpson coefficient
 *
 * The overlap distance between basins A and B is defined as:
 *   d(A, B) = 1 - |A ∩ B| / min(|A|, |B|)
 *
 * This measure equals 0 when one basin is completely contained in the other,
 * making it ideal for detecting nested basin structures.
 *
 * @param basin_vertices Vector of vectors, each containing vertex indices for a basin
 * @return Symmetric matrix of pairwise overlap distances
 */
Eigen::MatrixXd compute_overlap_distance_matrix(
    const std::vector<std::vector<size_t>>& basin_vertices
);

/**
 * @brief Create adjacency list for threshold graph from distance matrix
 *
 * Creates a graph where basins are connected if their overlap distance
 * is strictly less than the threshold.
 *
 * @param dist_matrix Symmetric distance matrix
 * @param threshold Distance threshold (edges created where dist < threshold)
 * @return Adjacency list (0-based indices)
 */
std::vector<std::vector<int>> create_threshold_graph(
    const Eigen::MatrixXd& dist_matrix,
    double threshold
);

/**
 * @brief Find connected components of a graph
 *
 * @param adj_list Adjacency list (0-based indices)
 * @return Vector of component assignments (0-based component indices)
 */
std::vector<int> find_connected_components(
    const std::vector<std::vector<int>>& adj_list
);

/**
 * @brief Compute edge length threshold from quantile
 *
 * @param graph The weighted graph
 * @param quantile Quantile value in (0, 1]
 * @return Edge length threshold
 */
double compute_edge_length_threshold(
    const set_wgraph_t& graph,
    double quantile
);

/**
 * @brief Expand basins to cover all vertices using shortest-path assignment
 *
 * For each vertex not covered by any basin, assigns it to the nearest
 * basin based on weighted shortest path distance.
 *
 * @param graph The weighted graph
 * @param basin_vertices Vector of basin vertex sets
 * @param n_vertices Total number of vertices
 * @return Assignment vector: assignment[v] = basin index for vertex v
 */
std::vector<int> expand_basins_to_cover(
    const set_wgraph_t& graph,
    const std::vector<std::vector<size_t>>& basin_vertices,
    size_t n_vertices
);

// ============================================================================
// Main GFC Computation Functions
// ============================================================================

/**
 * @brief Compute refined gradient flow complex for a single function
 *
 * This is the main entry point for GFC computation. It performs:
 * 1. Initial basin computation using BFS from each local extremum
 * 2. Relative value filtering (optional)
 * 3. Overlap-based clustering and merging (optional)
 * 4. Geometric filtering by hop distance and degree (optional)
 * 5. Basin expansion to cover all vertices (optional)
 *
 * @param graph The weighted graph structure
 * @param y Function values at each vertex
 * @param params Refinement parameters
 * @param verbose Print progress messages
 * @return Complete GFC result
 */
gfc_result_t compute_gfc(
    const set_wgraph_t& graph,
    const std::vector<double>& y,
    const gfc_params_t& params,
    bool verbose = false
);

/**
 * @brief Compute GFC for multiple functions over the same graph
 *
 * Efficiently computes GFC for each column of a matrix, reusing
 * graph structure across all computations. Supports OpenMP
 * parallelization over columns.
 *
 * @param graph The weighted graph structure
 * @param Y Matrix of function values (n_vertices x n_functions)
 * @param params Refinement parameters (applied to all functions)
 * @param n_cores Number of OpenMP threads (1 = sequential)
 * @param verbose Print progress messages
 * @return Vector of GFC results, one per function
 */
std::vector<gfc_result_t> compute_gfc_matrix(
    const set_wgraph_t& graph,
    const Eigen::MatrixXd& Y,
    const gfc_params_t& params,
    int n_cores = 1,
    bool verbose = false
);

// ============================================================================
// Trajectory Joining Functions
// ============================================================================

/**
 * @brief Join paths by concatenating at a shared vertex
 *
 * @param path1 First path (ends at connection point)
 * @param path2 Second path (starts at connection point)
 * @return Joined path with connection point appearing once
 */
std::vector<size_t> join_paths(
    const std::vector<size_t>& path1,
    const std::vector<size_t>& path2
);

/**
 * @brief Reverse a path
 */
std::vector<size_t> reverse_path(const std::vector<size_t>& path);

/**
 * @brief Compute sum of edge weights along a path
 */
double compute_path_length(
    const set_wgraph_t& graph,
    const std::vector<size_t>& path
);

/**
 * @brief Build cell map from joined trajectories
 *
 * @param joined_trajectories Vector of all joined trajectories
 * @return Map from (min_vertex, max_vertex) pairs to trajectory indices
 */
std::map<std::pair<size_t, size_t>, std::vector<size_t>> build_cell_map(
    const std::vector<joined_trajectory_t>& joined_trajectories
);

/**
 * @brief Find extension chains from a spurious extremum to non-spurious targets
 *
 * Recursively explores basins of spurious extrema to find paths to non-spurious extrema.
 *
 * @param spurious_vertex Starting spurious extremum
 * @param is_min True if spurious_vertex is a minimum
 * @param all_max_basins Map of all maximum basins (including spurious)
 * @param all_min_basins Map of all minimum basins (including spurious)
 * @param non_spurious_targets Set of non-spurious extrema of the target type
 * @param depth_remaining Maximum recursion depth
 * @param visited Set of already-visited vertices (for cycle detection)
 * @return Vector of extension chains found
 */
std::vector<extension_chain_t> find_extension_chains(
    size_t spurious_vertex,
    bool is_min,
    const std::unordered_map<size_t, gradient_basin_t>& all_max_basins,
    const std::unordered_map<size_t, gradient_basin_t>& all_min_basins,
    const std::unordered_set<size_t>& non_spurious_targets,
    int depth_remaining,
    std::unordered_set<size_t> visited = {}
);

/**
 * @brief Compute all joined trajectories from basins
 *
 * For each trajectory in a non-spurious maximum's basin:
 * - If terminal is non-spurious minimum: use directly
 * - If terminal is spurious minimum: extend via chain finding
 *
 * @param graph The weighted graph
 * @param y Function values
 * @param all_max_basins_full Full gradient basins for all maxima
 * @param all_min_basins_full Full gradient basins for all minima
 * @param non_spurious_max Set of non-spurious maximum vertices
 * @param non_spurious_min Set of non-spurious minimum vertices
 * @param max_chain_depth Maximum depth for extension chain search
 * @param verbose Print progress information
 * @return Vector of joined trajectories
 */
std::vector<joined_trajectory_t> compute_joined_trajectories(
    const set_wgraph_t& graph,
    const std::vector<double>& y,
    const std::unordered_map<size_t, gradient_basin_t>& all_max_basins_full,
    const std::unordered_map<size_t, gradient_basin_t>& all_min_basins_full,
    const std::unordered_set<size_t>& non_spurious_max,
    const std::unordered_set<size_t>& non_spurious_min,
    int max_chain_depth,
    bool verbose
);


// ============================================================================
// Internal Pipeline Functions (exposed for testing)
// ============================================================================

namespace gfc_internal {

    void filter_by_relvalue(
        std::vector<extremum_summary_t>& summaries,
        std::vector<basin_compact_t>& basins,
        double min_rel_value_max,
        double max_rel_value_min,
        bool is_maximum
        );

    void cluster_and_merge_basins(
        std::vector<extremum_summary_t>& summaries,
        std::vector<basin_compact_t>& basins,
        double overlap_threshold,
        bool is_maximum
        );

    void filter_by_geometry(
        std::vector<extremum_summary_t>& summaries,
        std::vector<basin_compact_t>& basins,
        double p_mean_nbrs_dist_threshold,
        double p_mean_hopk_dist_threshold,
        double p_deg_threshold,
        int min_basin_size
        );

    std::vector<extremum_summary_t> compute_basin_summaries(
        const set_wgraph_t& graph,
        const std::vector<basin_compact_t>& basins,
        const std::vector<double>& y,
        double y_median,
        int hop_k
        );

    std::vector<std::vector<int>> build_membership_vectors(
        const std::vector<basin_compact_t>& basins,
        size_t n_vertices
        );

} // namespace gfc_internal

#endif // GFC_HPP
