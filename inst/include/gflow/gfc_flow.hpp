/**
 * @file gfc_flow.hpp
 * @brief Trajectory-based Gradient Flow Complex (GFC) computation
 *
 * This header defines data structures and functions for computing gradient
 * flow complexes using a trajectory-first approach. Rather than growing
 * basins outward from extrema (as in compute_gfc), this approach traces
 * gradient flow trajectories and derives basins as byproducts.
 *
 * KEY DESIGN: All extrema and their basins are preserved, with clear
 * distinction between "retained" (significant) and "spurious" (filtered)
 * extrema. This enables:
 * - Complete trajectory analysis
 * - Harmonic repair of spurious regions
 * - Iterative refinement workflows
 *
 * Labeling convention:
 * - Retained minima: m1, m2, m3, ...
 * - Retained maxima: M1, M2, M3, ...
 * - Spurious minima: sm1, sm2, sm3, ...
 * - Spurious maxima: sM1, sM2, sM3, ...
 */

#ifndef GFC_FLOW_HPP
#define GFC_FLOW_HPP

#include "gfc.hpp" // For gfc_params_t, basin_compact_t, etc.

#include <vector>
#include <map>
#include <set>
#include <cstddef>
#include <utility>
#include <string>
#include <unordered_map>

// Forward declaration
struct set_wgraph_t;

using std::size_t;

// Type alias for edge length weights map
using edge_weight_map_t = std::unordered_map<size_t, std::unordered_map<size_t, double>>;

// ============================================================================
// Extended Data Structures
// ============================================================================

/**
 * @brief Filter stage at which an extremum was marked spurious
 */
enum class filter_stage_t {
    NONE = 0,            ///< Not filtered (retained)
    RELVALUE = 1,        ///< Filtered by relative value
    CLUSTER_MERGE = 2,   ///< Merged during clustering
    MIN_BASIN_SIZE = 3,  ///< Filtered by minimum basin size
    MIN_N_TRAJ = 4,      ///< Filtered by minimum number of trajectories
    GEOMETRIC = 5        ///< Filtered by geometric criteria
};

/**
 * @brief Convert filter_stage_t to string
 */
inline std::string filter_stage_to_string(filter_stage_t stage) {
    switch (stage) {
        case filter_stage_t::NONE: return "none";
        case filter_stage_t::RELVALUE: return "relvalue";
        case filter_stage_t::CLUSTER_MERGE: return "cluster_merge";
        case filter_stage_t::MIN_BASIN_SIZE: return "min_basin_size";
        case filter_stage_t::MIN_N_TRAJ: return "min_n_trajectories";
        case filter_stage_t::GEOMETRIC: return "geometric";
        default: return "unknown";
    }
}

/**
 * @brief Extended basin structure with spurious tracking
 */
struct basin_extended_t : public basin_compact_t {
    bool is_spurious = false;           ///< True if filtered out
    filter_stage_t filter_stage = filter_stage_t::NONE;  ///< Stage at which filtered
    int merged_into = -1;               ///< If merged, index of target basin (-1 if not merged)
    std::string label;                  ///< Label (m1, M1, sm1, sM1, etc.)
    
    basin_extended_t() = default;
    
    /// Construct from basin_compact_t
    explicit basin_extended_t(const basin_compact_t& base)
        : basin_compact_t(base), is_spurious(false),
          filter_stage(filter_stage_t::NONE), merged_into(-1) {}
};

/**
 * @brief Extended extremum summary with spurious tracking
 */
struct extremum_summary_extended_t : public extremum_summary_t {
    bool is_spurious = false;
    filter_stage_t filter_stage = filter_stage_t::NONE;
    int merged_into = -1;
    std::string label;
    
    extremum_summary_extended_t() = default;
    
    /// Construct from extremum_summary_t
    explicit extremum_summary_extended_t(const extremum_summary_t& base)
        : extremum_summary_t(base), is_spurious(false),
          filter_stage(filter_stage_t::NONE), merged_into(-1) {}
};

/**
 * @brief A single gradient flow trajectory with endpoint classification
 */
struct gflow_trajectory_t {
    std::vector<size_t> vertices;  ///< Ordered vertices along trajectory (0-based)
    size_t start_vertex;           ///< Starting vertex (local min for full trajectories)
    size_t end_vertex;             ///< Ending vertex (local max for full trajectories)
    bool starts_at_lmin;           ///< True if trajectory starts at local minimum
    bool ends_at_lmax;             ///< True if trajectory ends at local maximum
    double total_change;           ///< Total function change: y[end] - y[start]
    int trajectory_id;             ///< Unique identifier for this trajectory
    
    // Endpoint classification (set after filtering)
    bool start_is_spurious = false;  ///< True if start extremum is spurious
    bool end_is_spurious = false;    ///< True if end extremum is spurious
    int start_basin_idx = -1;        ///< Index into min_basins_all (-1 if not assigned)
    int end_basin_idx = -1;          ///< Index into max_basins_all (-1 if not assigned)

    gflow_trajectory_t()
        : start_vertex(0), end_vertex(0),
          starts_at_lmin(false), ends_at_lmax(false),
          total_change(0.0), trajectory_id(-1),
          start_is_spurious(false), end_is_spurious(false),
          start_basin_idx(-1), end_basin_idx(-1) {}
};

// ============================================================================
// Parameter Structure
// ============================================================================

/**
 * @brief Parameters for trajectory-based GFC computation
 */
struct gfc_flow_params_t : public gfc_params_t {
    /// Modulation strategy for gradient direction selection
    gflow_modulation_t modulation = gflow_modulation_t::NONE;

    /// Whether to store full trajectory information in result
    bool store_trajectories = true;

    /// Maximum trajectory length (vertices) before giving up
    size_t max_trajectory_length = 10000;

    /// If true, seed trajectories from both minima and maxima (symmetric)
    bool symmetric_seeding = true;

    gfc_flow_params_t() = default;

    /// Construct from base parameters
    explicit gfc_flow_params_t(const gfc_params_t& base)
        : gfc_params_t(base),
          modulation(gflow_modulation_t::NONE),
          store_trajectories(true),
          max_trajectory_length(10000),
          symmetric_seeding(true) {}
};

// ============================================================================
// Result Structure
// ============================================================================

/**
 * @brief Complete result from trajectory-based GFC computation
 *
 * This structure preserves ALL extrema and basins, clearly distinguishing
 * between retained (significant) and spurious (filtered) ones.
 *
 * Key design principles:
 * 1. ALL trajectories are stored, regardless of endpoint status
 * 2. ALL basins are stored in *_basins_all vectors
 * 3. Retained/spurious status is tracked via is_spurious flags
 * 4. Convenience vectors provide quick access to retained-only basins
 * 5. Multi-valued membership is computed for BOTH retained and spurious basins
 */
struct gfc_flow_result_t {
    // ========================================================================
    // ALL BASINS (retained + spurious)
    // ========================================================================
    
    /// All maximum basins with extended info (retained + spurious)
    std::vector<basin_extended_t> max_basins_all;
    
    /// All minimum basins with extended info (retained + spurious)
    std::vector<basin_extended_t> min_basins_all;
    
    /// All maximum summaries with extended info
    std::vector<extremum_summary_extended_t> max_summaries_all;
    
    /// All minimum summaries with extended info
    std::vector<extremum_summary_extended_t> min_summaries_all;

    // ========================================================================
    // CONVENIENCE: Indices of retained vs spurious basins
    // ========================================================================
    
    /// Indices into max_basins_all for retained maxima
    std::vector<int> retained_max_indices;
    
    /// Indices into min_basins_all for retained minima
    std::vector<int> retained_min_indices;
    
    /// Indices into max_basins_all for spurious maxima
    std::vector<int> spurious_max_indices;
    
    /// Indices into min_basins_all for spurious minima
    std::vector<int> spurious_min_indices;

    // ========================================================================
    // MULTI-VALUED MEMBERSHIP (for ALL basins)
    // ========================================================================
    
    /// max_membership_all[v] = indices into max_basins_all containing vertex v
    std::vector<std::vector<int>> max_membership_all;
    
    /// min_membership_all[v] = indices into min_basins_all containing vertex v
    std::vector<std::vector<int>> min_membership_all;

    // ========================================================================
    // CONVENIENCE: Membership for retained basins only
    // ========================================================================
    
    /// max_membership_retained[v] = indices into retained_max_indices
    std::vector<std::vector<int>> max_membership_retained;
    
    /// min_membership_retained[v] = indices into retained_min_indices
    std::vector<std::vector<int>> min_membership_retained;

    // ========================================================================
    // SINGLE-VALUED ASSIGNMENTS (backward compatibility)
    // ========================================================================
    
    /// max_assignment[v] = first retained max basin index for vertex v (-1 if none)
    std::vector<int> max_assignment;
    
    /// min_assignment[v] = first retained min basin index for vertex v (-1 if none)
    std::vector<int> min_assignment;

    // ========================================================================
    // ASCENT MAP (single-step pointers)
    // ========================================================================

    /// next_up[v] = next vertex on ascending trajectory from v (0-based), or -1 if none
    std::vector<int> next_up;

    // ========================================================================
    // TRAJECTORIES (ALL, with endpoint classification)
    // ========================================================================
    
    /// All computed trajectories with endpoint spurious flags
    std::vector<gflow_trajectory_t> trajectories;

    /// Number of trajectories started from local minima
    int n_lmin_trajectories;

    /// Number of trajectories started from local maxima (symmetric seeding)
    int n_lmax_trajectories;

    /// Number of trajectories started from non-extremal vertices (joins)
    int n_join_trajectories;

    // ========================================================================
    // OVERLAP DISTANCES
    // ========================================================================

    /// Pairwise overlap distances for ALL maxima basins
    Eigen::MatrixXd max_overlap_dist;

    /// Pairwise overlap distances for ALL minima basins
    Eigen::MatrixXd min_overlap_dist;

    // ========================================================================
    // PIPELINE HISTORY
    // ========================================================================
    
    /// Stage history for reporting
    std::vector<stage_counts_t> stage_history;

    // ========================================================================
    // METADATA
    // ========================================================================
    
    size_t n_vertices;
    double y_median;
    double edge_length_thld;
    gfc_flow_params_t params;

    // ========================================================================
    // COUNTS
    // ========================================================================
    
    int n_max_retained;
    int n_min_retained;
    int n_max_spurious;
    int n_min_spurious;

    gfc_flow_result_t()
        : n_lmin_trajectories(0), n_lmax_trajectories(0), n_join_trajectories(0),
          n_vertices(0), y_median(0.0),
          n_max_retained(0), n_min_retained(0),
          n_max_spurious(0), n_min_spurious(0) {}
};

// ============================================================================
// Main Computation Functions
// ============================================================================

/**
 * @brief Compute gradient flow complex using trajectory-first approach
 *
 * This function computes basins of attraction by tracing gradient flow
 * trajectories. ALL extrema and basins are preserved, with filtering
 * status tracked via is_spurious flags rather than deletion.
 *
 * The algorithm:
 * 1. Identify all local minima/maxima
 * 2. Trace trajectories from all minima to maxima
 * 3. Build basins from trajectory vertex assignments
 * 4. Apply filtering pipeline, marking (not deleting) spurious extrema
 * 5. Compute membership vectors for both retained and spurious basins
 * 6. Label all extrema (m1, M1, sm1, sM1, etc.)
 *
 * @param graph The weighted graph structure
 * @param y Function values at each vertex
 * @param params Flow computation and refinement parameters
 * @param density Optional vertex density weights for modulation
 * @param verbose Print progress messages
 * @return Complete GFC flow result with all basins preserved
 */
gfc_flow_result_t compute_gfc_flow(
    const set_wgraph_t& graph,
    const std::vector<double>& y,
    const gfc_flow_params_t& params,
    const std::vector<double>& density = {},
    bool verbose = false
);

/**
 * @brief Compute GFC flow for multiple functions
 */
std::vector<gfc_flow_result_t> compute_gfc_flow_matrix(
    const set_wgraph_t& graph,
    const Eigen::MatrixXd& Y,
    const gfc_flow_params_t& params,
    const std::vector<double>& density = {},
    int n_cores = 1,
    bool verbose = false
);

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * @brief Compute modulated gradient score for an edge
 */
inline double compute_modulated_score(
    double delta_y,
    double edge_length_weight,
    double target_density,
    gflow_modulation_t modulation
) {
    switch (modulation) {
        case gflow_modulation_t::NONE:
            return delta_y;
        case gflow_modulation_t::DENSITY:
            return target_density * delta_y;
        case gflow_modulation_t::EDGELEN:
            return edge_length_weight * delta_y;
        case gflow_modulation_t::DENSITY_EDGELEN:
            return target_density * edge_length_weight * delta_y;
        default:
            return delta_y;
    }
}

/**
 * @brief Get retained maximum basins as basin_compact_t vector
 *
 * Convenience function for backward compatibility
 */
inline std::vector<basin_compact_t> get_retained_max_basins(
    const gfc_flow_result_t& result
) {
    std::vector<basin_compact_t> basins;
    basins.reserve(result.retained_max_indices.size());
    for (int idx : result.retained_max_indices) {
        basins.push_back(static_cast<basin_compact_t>(result.max_basins_all[idx]));
    }
    return basins;
}

/**
 * @brief Get retained minimum basins as basin_compact_t vector
 */
inline std::vector<basin_compact_t> get_retained_min_basins(
    const gfc_flow_result_t& result
) {
    std::vector<basin_compact_t> basins;
    basins.reserve(result.retained_min_indices.size());
    for (int idx : result.retained_min_indices) {
        basins.push_back(static_cast<basin_compact_t>(result.min_basins_all[idx]));
    }
    return basins;
}

/**
 * @brief Get spurious maximum basins
 */
inline std::vector<basin_extended_t> get_spurious_max_basins(
    const gfc_flow_result_t& result
) {
    std::vector<basin_extended_t> basins;
    basins.reserve(result.spurious_max_indices.size());
    for (int idx : result.spurious_max_indices) {
        basins.push_back(result.max_basins_all[idx]);
    }
    return basins;
}

/**
 * @brief Get spurious minimum basins
 */
inline std::vector<basin_extended_t> get_spurious_min_basins(
    const gfc_flow_result_t& result
) {
    std::vector<basin_extended_t> basins;
    basins.reserve(result.spurious_min_indices.size());
    for (int idx : result.spurious_min_indices) {
        basins.push_back(result.min_basins_all[idx]);
    }
    return basins;
}

#endif // GFC_FLOW_HPP
