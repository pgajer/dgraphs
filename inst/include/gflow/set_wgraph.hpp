#ifndef GRAPH_HPP
#define GRAPH_HPP

#include "graph_spectral_filter.hpp"
#include "iknn_graphs.hpp"
#include "edge_info.hpp"
#include "edge_weights.hpp"
#include "vertex_info.hpp"
#include "vertex_path.hpp"
#include "reachability_map.hpp"
#include "explored_tracker.hpp"
#include "circular_param_result.hpp"
#include "weighted_correlation.hpp"
#include "gradient_flow.hpp"
#include "ulm.hpp"
#include "opt_bw.hpp"
#include "graph_spectral_lowess.hpp"     // For graph_spectral_lowess_t
#include "edge_pruning_stats.hpp"        // For edge_pruning_stats_t
#include "graph_deg0_lowess_cv.hpp"
#include "graph_deg0_lowess_cv_mat.hpp"
#include "graph_deg0_lowess_buffer_cv.hpp"
#include "graph_kernel_smoother.hpp"
#include "graph_bw_adaptive_spectral_smoother.hpp"
#include "klaps_low_pass_smoother.hpp"
#include "basin.hpp"
#include "invalid_vertex.hpp"
#include "harmonic_smoother.hpp"
#include "geodesic_stats.hpp"
#include "harmonic_extender.hpp"
#include "gflow_cx.hpp"
#include "gradient_basin.hpp"
#include "lcor.hpp"
#include "lslope.hpp"
#include "gfc.hpp"
#include "se_tree.hpp"
#include "harmonic_extension.hpp"
#include "gfc_flow.hpp"

#include <cstddef>
#include <vector>        // For std::vector used throughout the code
#include <unordered_map> // For std::unordered_map used for boundary_vertices
#include <map>
#include <unordered_set>
#include <set>
#include <optional>
#include <algorithm>
#include <limits>
#include <utility>            // For std::pair

#include <Eigen/Core>
#include <Eigen/Dense>  // For Eigen::MatrixXd
#include <Eigen/Sparse> // For Eigen::SparseMatrix, Triplet

using std::size_t;

struct path_t {
	std::vector<size_t> vertices;  ///< vertices of the path
	std::vector<double> distances; ///< distance of each vertex to the reference vertex
	size_t ref_vertex_index = 0;   ///< index of the reference vertex within vertices (and hence distances)
	double total_weight = 0.0;

	// For priority queue ordering; sort paths in the descending order of their total_length's
	bool operator<(const path_t& other) const {
		return total_weight > other.total_weight;
	}
};

// shortest_paths_t allows reconstruction of shortest path between the given ref
// vertex and any vertex reachable from the ref vertex
struct subpath_t {
   size_t path_idx;   ///< path index
   size_t vertex_idx; ///< index of the given vertex of reachable_vertices set within the path with index path_idx; for example if path = {4,20,31,22} and v = 31, then vertex_idx for v is 2 as path[2] = 31
};
struct shortest_paths_t {
	std::vector<path_t> paths;
	std::unordered_set<int> reachable_vertices;
	std::unordered_map<size_t, subpath_t> vertex_to_path_map; // Maps vertex to path index
};

struct tube_lens_corridor_result_t {
	std::vector<size_t> path_vertices;
	std::vector<double> path_arc_length;
	double path_length = std::numeric_limits<double>::infinity();
	double tube_radius = 0.0;
	double excess_tolerance = std::numeric_limits<double>::quiet_NaN();
	std::vector<size_t> tube_vertices;
	std::vector<double> tube_geodesic_distances;
	std::vector<size_t> corridor_vertices;
	std::vector<double> t_balance;
	std::vector<double> harmonic_t;
	std::vector<double> distance_to_path;
	std::vector<double> excess;
	std::vector<size_t> excess_vertices;
};

struct gray_xyw_t {
	std::vector<size_t> vertices;  ///< Indices of the original graph vertices forming the path
	std::vector<double> x_path;///< Cumulative distance along path from initial vertex
	std::vector<double> y_path;///< Y-values of vertices restricted to the path
	std::vector<double> w_path;///< Kernel-weighted distances from reference vertex

// Method to evaluate linearity
	double evaluate_linearity() const {
		double corr = calculate_weighted_correlation(x_path, y_path, w_path);
		return corr * corr;
	}
};

struct composite_shortest_paths_t : public shortest_paths_t {
	std::vector<std::pair<size_t, size_t>> composite_paths;

	explicit composite_shortest_paths_t(const shortest_paths_t& shortest_paths)
		: shortest_paths_t(shortest_paths)
		{}

	void add_composite_shortest_path(size_t i, size_t j) {
		composite_paths.emplace_back(i, j);
	}

	bool is_single_path(size_t index) const {
		return composite_paths[index].second == INVALID_VERTEX;
	}
};

// Structure containing vectors of absolute and relative deviations for all
// edges (i,k) of the given graph that have triangle decomposition
// (i,k) = (i,j) \circ (j,k).
// That is, (i,k) is triangle decomposable if there is a vertex j, such that (i,j) and (j,k) are edges of the graph
struct edge_weight_deviations_t {
	std::vector<double> absolute_deviations;
	std::vector<double> relative_deviations;
};

struct edge_weight_rel_deviation_t {
	double rel_deviation;
	size_t source;  // source node i
	size_t target;  // target node k
	size_t best_intermediate;   // best intermediate node j

	explicit edge_weight_rel_deviation_t(double rel_deviation,
										 size_t source,
										 size_t target,
										 size_t best_intermediate)
		: rel_deviation(rel_deviation),
		  source(source),
		  target(target),
		  best_intermediate(best_intermediate)
		{}
};

struct gradient_trajectory_t {
	std::vector<size_t> path;///< The vertices forming the trajectory
	bool ends_at_critical;   ///< Whether the trajectory ends at local maximum or minimum
	bool ends_at_lmax;   ///< Whether the trajectory ends at local maximum
	double quality_metric;   ///< Quality metric of the trajectory (monotonicity * adjusted rate)
	double total_change; ///< Total function value change along the trajectory
};

/**
 * @brief Structure to hold a prediction result with a flag indicating exclusion
 */
struct prediction_result_t {
	double value;   ///< Predicted value
	bool is_excluded;   ///< Flag indicating if prediction could not be made
};

struct set_wgraph_t {

	std::vector<std::set<edge_info_t>> adjacency_list; 	// Core graph structure
	double graph_diameter;
	double max_packing_radius;

	// Default constructor
	set_wgraph_t() : graph_diameter(-1.0), max_packing_radius(-1.0) {}

	explicit set_wgraph_t(
		const std::vector<std::vector<int>>& adj_list,
		const std::vector<std::vector<double>>& weight_list
		);

	explicit set_wgraph_t(
		const iknn_graph_t& iknn_graph
		);

	// Constructor that initializes an empty graph with n_vertices
	explicit set_wgraph_t(size_t n_vertices)
		: adjacency_list(n_vertices),
		  graph_diameter(-1.0),
		  max_packing_radius(-1.0)
		{}

	// Core graph operations
	void print(const std::string& name,
			   bool split,
			   size_t shift
		) const;

	size_t num_vertices() const {
		return adjacency_list.size();
	}

	double compute_median_edge_length() const;
	double compute_quantile_edge_length(double quantile) const;
	void compute_graph_diameter();

	// ----------------------------------------------------------------
	//
	// precompute edge weights members
	//
	// ----------------------------------------------------------------
	/**
	 * @brief Ensures edge weights are computed and available for use
	 */
	void ensure_edge_weights_computed() const {
		if (!edge_weights_computed) {
			precompute_edge_weights();
		}
	}

	/**
	 * @brief Precomputes all edge weights in the graph for efficient lookup
	 */
 	void precompute_edge_weights() const;

	/**
	 * @brief Invalidates cached edge weights
	 */
	void invalidate_edge_weights() {
		edge_weights_computed = false;
		edge_weights.clear();
	}

	// ------- other ----------

	/**
	 * @brief Creates a subgraph containing only the specified vertices
	 */
	set_wgraph_t create_subgraph(
		const std::vector<size_t>& vertices
		) const;

	/**
	 * @brief Counts the number of connected components in the graph
	 */
	size_t count_connected_components() const;

	/**
	 * @brief Get all connected components in the graph
	 */
	std::vector<std::vector<size_t>> get_connected_components() const;

	void add_edge(
		size_t v1,
		size_t v2,
		double weight
		);

	// ----------------------------------------------------------------
	//
	// geometric edge pruning functions
	//
	// ----------------------------------------------------------------
	/**
	 * @brief Compute the length of the shortest path between two vertices while excluding a specific edge
	 */
	double bidirectional_dijkstra_excluding_edge(
		size_t source,
		size_t target
		) const;

	/**
	 * pure bidirectional Dijkstra algorithm
	 */
	double bidirectional_dijkstra(
		size_t source,
		size_t target
		) const;


	/**
	 * @brief Compute statistics for potential edge pruning based on geometric criteria
	 */
	edge_pruning_stats_t compute_edge_pruning_stats(
		double threshold_percentile = 0.5
		) const;

	/**
	 * @brief Prune edges geometrically based on alternative path ratio
	 */
	set_wgraph_t prune_edges_geometrically(
		double max_ratio_threshold = 1.2,
		double threshold_percentile = 0.5,
		bool verbose = false
		) const;

	set_wgraph_t prune_long_edges(double threshold_percentile = 0.5) const;

	edge_weight_deviations_t compute_edge_weight_deviations() const;
	std::vector<edge_weight_rel_deviation_t> compute_edge_weight_rel_deviations() const;

	bool is_composite_path_geodesic(
		size_t i,
		size_t j,
		const shortest_paths_t& shortest_paths
		) const;

	// ----------------------------------------------------------------
	//
	// function aware graph construction
	//
	// ----------------------------------------------------------------
	set_wgraph_t construct_function_aware_graph(
		const std::vector<double>& function_values,
		int weight_type,
		double epsilon,
		double lambda,
		double alpha,
		double beta,
		double tau,
		double p,
		double q,
		double r,
		bool normalize,
		double weight_thld
		) const;

	std::vector<std::vector<double>> analyze_function_aware_weights(
		const std::vector<double>& function_values,
		const std::vector<int>& weight_types,
		double epsilon,
		double lambda,
		double alpha,
		double beta,
		double tau,
		double p,
		double q,
		double r
		) const;

	// ----------------------------------------------------------------
	// Gradient flow trajectory members
	// ----------------------------------------------------------------
	// the first three are for compute_gfc_flow
	std::vector<size_t> follow_gradient_trajectory(
		size_t start_vertex,
		const std::vector<double>& y,
		bool ascending,
		gflow_modulation_t modulation,
		const std::vector<double>& density,
		const edge_weight_map_t& edge_length_weights,
		double edge_length_thld,
		size_t max_length
		) const;

	gflow_trajectory_t join_trajectories_at_vertex(
		size_t vertex,
		const std::vector<double>& y,
		gflow_modulation_t modulation,
		const std::vector<double>& density,
		const edge_weight_map_t& edge_length_weights,
		double edge_length_thld,
		size_t max_length
		) const;

    int check_nbr_extremum_type(
        size_t vertex,
        const std::vector<double>& y
		) const;

	std::unordered_map<size_t, std::unordered_map<size_t, double>>
	compute_edge_length_weights(
		double bandwidth
		) const;

	std::vector<double> compute_vertex_density() const;

	std::pair<size_t, bool> find_modulated_gradient_neighbor(
		size_t v,
		const std::vector<double>& y,
		bool ascending,
		gflow_modulation_t modulation,
		const std::vector<double>& density,
		const std::unordered_map<size_t, std::unordered_map<size_t, double>>& edge_weights
		) const;

	bbasin_t compute_single_basin(
    size_t extremum_vertex,
    const std::vector<double>& y,
    bool is_maximum,
    gflow_modulation_t modulation,
    const std::vector<double>& density,
    const std::unordered_map<size_t, std::unordered_map<size_t, double>>& edge_weights
		) const;

	std::unordered_map<size_t, bbasin_t> compute_gfc_basins(
		const std::vector<double>& y,
		const gfc_basin_params_t& params,
		bool verbose
		) const;

	se_tree_t build_se_tree(
		size_t root_vertex,
		const std::unordered_map<size_t, bbasin_t>& basins,
		const std::unordered_set<size_t>& spurious_min,
		const std::unordered_set<size_t>& spurious_max,
		bool verbose
		) const;

	// ------------------------------------------------------------------------

	monotonic_reachability_map_t compute_monotonic_reachability_map(
		size_t ref_vertex,
		const std::vector<double>& y,
		double radius,
		bool ascending
		) const;

	path_t reconstruct_monotonic_path(
		const monotonic_reachability_map_t& map,
		size_t target_vertex
		) const;

	std::pair<size_t, double> find_best_gradient_vertex(
		const monotonic_reachability_map_t& map,
		double min_distance,
		size_t min_path_length,
		bool ascending
		) const;

	std::vector<size_t> compute_ascending_gradient_trajectory(
		const std::vector<double>& values,
		size_t start_vertex) const;

	double calculate_path_evenness(
		const std::vector<double>& edge_lengths
		) const;

	double calculate_monotonicity_index(
		double total_change,
		double cumulative_absolute_changes
		) const;

	std::vector<double> compute_weight_percentiles(
		const std::vector<double>& probs
		) const;

	std::vector<double> extract_edge_lengths(
		const path_t& path
		) const;

	std::vector<std::tuple<vertex_shortest_path_info_t, double, double>> evaluate_paths(
		const std::vector<vertex_shortest_path_info_t>& paths,
		size_t current_vertex,
		const std::vector<double>& y
		) const;


	std::vector<local_extremum_t> detect_local_minima(
		const std::vector<double>& y,
		double max_radius,
		size_t min_neighborhood_size
		) const;

	std::vector<local_extremum_t> detect_local_maxima(
		const std::vector<double>& y,
		double max_radius,
		size_t min_neighborhood_size
		) const;

	std::vector<local_extremum_t> detect_local_extrema(
		const std::vector<double>& y,
		double max_radius,
		size_t min_neighborhood_size,
		bool detect_maxima
		) const;

	basin_t find_local_extremum_geodesic_basin(
		size_t vertex,
		const std::vector<double>& y,
		bool detect_maxima,
		double edge_length_thld
		) const;

	std::vector<size_t> find_shortest_monotonic_path(
		size_t source,
		size_t target,
		const std::vector<double>& y,
		bool detect_maxima
		) const;

	std::vector<size_t> find_shortest_monotonic_within_basin_path(
		size_t source,
		size_t target,
		const std::vector<double>& y,
		bool detect_maxima,
		const std::unordered_set<size_t>& basin_vertices
		) const;

	gradient_basin_t compute_geodesic_basin(
		size_t vertex,
		const std::vector<double>& y,
		bool detect_maxima,
		double edge_length_thld,
		bool with_trajectories
		) const;


	basin_t find_local_extremum_bfs_basin(
		size_t vertex,
		const std::vector<double>& y,
		bool detect_maxima
		) const;

	basin_cx_t create_basin_cx(
		const std::vector<double>& y
		) const;

	gflow_cx_t create_gflow_cx(
		const std::vector<double>& y,
		size_t hop_idx_thld,
		smoother_type_t smoother_type,
		int max_outer_iterations,
		int max_inner_iterations,
		double smoothing_tolerance,
		double sigma,
		bool process_in_order,
		bool verbose,
		bool detailed_recording
		) const;

	std::unordered_map<size_t, basin_t> compute_basins(
		const std::vector<double>& y
		) const;

	harmonic_extender_t harmonic_extender(
		const std::unordered_map<size_t, double>& boundary_values,
		const std::unordered_set<size_t>& region_vertices,
		int max_iterations = 1000,
		double tolerance = 1e-6,
		int record_frequency = 10,
		bool verbose = false
		) const;

	std::vector<double> harmonic_extension_eigen(
		const std::unordered_map<size_t, double>& boundary_values,
		const std::unordered_set<size_t>& region_vertices,
		double regularization = 1e-10,
		bool verbose = false
		) const;

	std::vector<double> biharmonic_extension_eigen(
		const std::unordered_map<size_t, double>& boundary_values,
		const std::unordered_map<size_t, double>& boundary_neighbor_values,
		const std::unordered_set<size_t>& region_vertices,
		double regularization = 1e-10,
		bool verbose = false
		) const;

	std::vector<double> hybrid_biharmonic_harmonic_extension(
		const std::unordered_map<size_t, double>& boundary_values,
		const std::unordered_set<size_t>& region_vertices,
		int boundary_blend_distance = 2,
		bool verbose = false
		) const;

	std::vector<double> boundary_smoothed_harmonic_extension(
		const std::unordered_map<size_t, double>& boundary_values,
		const std::unordered_set<size_t>& region_vertices,
		int boundary_blend_distance = 2,
		bool verbose = false
		) const;

	harmonic_smoother_t harmonic_smoother(
		std::vector<double>& harmonic_predictions,
		std::unordered_set<size_t>& region_vertices,
		int max_iterations = 100,
		double tolerance = 1e-6,
		int record_frequency = 1,
		size_t stability_window = 3,
		double stability_threshold = 0.05
		) const;

	void perform_harmonic_repair(
		std::vector<double>& harmonic_predictions,
		const basin_t& absorbing_basin,
		const basin_t& absorbed_basin
		) const;

	harmonic_smoothing_stats_t perform_harmonic_smoothing(
		std::vector<double>& harmonic_predictions,
		const std::unordered_set<size_t>& region_vertices,
		int max_iterations,
		double tolerance,
		bool edge_weight_is_distance,
		bool verbose
		) const;

	double basin_cx_difference(
		const std::unordered_map<size_t, basin_t>& basins1,
		const std::unordered_map<size_t, basin_t>& basins2
		) const;

	basin_t find_gflow_basin(
		size_t vertex,
		const std::vector<double>& y,
		size_t min_basin_size,
		size_t min_path_size,
		double q_edge_thld,
		bool detect_maxima
		) const;

	std::pair<std::vector<basin_t>, std::vector<basin_t>>
	find_gflow_basins(
		const std::vector<double>& y,
		size_t min_basin_size,
		size_t min_path_size,
		double q_edge_thld
		) const;

	basin_t find_local_extremum(
		size_t vertex,
		const std::vector<double>& y,
		size_t min_basin_size,
		bool detect_maxima
		) const;

	// this incorrectly computes basins and should be deprecated
	size_t compute_extremum_hop_index(
		size_t vertex,
		const std::vector<double>& y,
		bool detect_maxima
		) const;

	// In set_wgraph.hpp or wherever the declaration is:
	gradient_basin_t compute_basin_of_attraction(
		size_t vertex,
		const std::vector<double>& y,
		bool detect_maxima,
		bool with_trajectories,
		size_t k_paths
		) const;

	hop_nbhd_t compute_extremum_hop_nbhd(
		size_t vertex,
		const std::vector<double>& y,
		bool detect_maxima
		) const;

	std::pair<std::unordered_map<size_t, hop_nbhd_t>, std::unordered_map<size_t, hop_nbhd_t>>
	compute_extrema_hop_nbhds(
		const std::vector<double>& y
		) const;

	void perform_weighted_mean_hop_disk_extension(
		std::vector<double>& smoothed_values,
		const hop_nbhd_t& hop_nbhd,
		int max_iterations = 10,
		double tolerance = 1e-6,
		double sigma = 1.0,
		bool verbose = false
		) const;

	std::pair<std::vector<size_t>, std::vector<size_t>> find_nbr_extrema(
		const std::vector<double>& y
		) const;

	std::pair<std::vector<basin_t>, std::vector<basin_t>>
	find_local_extrema(
		const std::vector<double>& y,
		size_t min_basin_size
		) const;

	std::vector<int> watershed_edge_weighted(
		const std::vector<double>& y,
		size_t min_basin_size
		) const;

	gradient_flow_t compute_gradient_flow(
		std::vector<double>& y,
		std::vector<double>& scale,
		double quantile_scale_thld
		) const;

	void remove_edge(size_t v1, size_t v2);

	std::vector<vertex_shortest_path_info_t> get_vertex_shortest_paths(
		const reachability_map_t& reachability_map
		) const;

	std::vector<vertex_path_t> reconstruct_graph_paths(
		const reachability_map_t& reachability_map
		) const;

	reachability_map_t compute_graph_reachability_map(
		size_t ref_vertex,
		double radius
		) const;

	circular_param_result_t parameterize_circular_graph(
		bool use_edge_lengths = true
		) const;

	circular_param_result_t parameterize_circular_graph_with_reference(
		size_t reference_vertex,
		bool use_edge_lengths = true
		) const;

	// ========================================================================
    // Harmonic Extension Methods
    // ========================================================================

    /**
     * @brief Compute tubular neighborhood using hop distance (BFS)
     */
    tubular_neighborhood_t compute_tubular_neighborhood_hop(
        const std::vector<size_t>& trajectory,
        int hop_radius,
        const std::unordered_set<size_t>& basin_restriction = {}
    ) const;

    /**
     * @brief Compute tubular neighborhood using geodesic distance (Dijkstra)
     */
    tubular_neighborhood_t compute_tubular_neighborhood_geodesic(
        const std::vector<size_t>& trajectory,
        double geodesic_radius,
        const std::unordered_set<size_t>& basin_restriction = {}
    ) const;

    /**
     * @brief Compute tubular neighborhood (dispatcher)
     */
    tubular_neighborhood_t compute_tubular_neighborhood(
        const std::vector<size_t>& trajectory,
        double radius,
        tube_radius_type_t radius_type,
        const std::unordered_set<size_t>& basin_restriction = {}
    ) const;

    /**
     * @brief Compute arc-length coordinates for trajectory vertices
     */
    std::pair<std::vector<double>, double> compute_arc_length_coords(
        const std::vector<size_t>& trajectory
    ) const;

    /**
     * @brief Solve harmonic extension via Gauss-Seidel iteration
     */
    std::vector<double> solve_harmonic_extension(
        const std::vector<size_t>& tubular_vertices,
        const std::unordered_set<size_t>& trajectory_set,
        const std::unordered_map<size_t, double>& trajectory_coords,
        const std::vector<double>& initial_coords,
        bool use_edge_weights,
        int max_iterations,
        double tolerance,
        int& n_iterations,
        double& final_max_change
    ) const;

    /**
     * @brief Compute harmonic extension of trajectory coordinates
     */
    harmonic_extension_result_t compute_harmonic_extension(
        const std::vector<size_t>& trajectory,
        const harmonic_extension_params_t& params,
        bool verbose = false
		) const;
	
	// ----------------------------------------------------------------
	//
	// graph_spectral_lowess related functions
	//
	// ----------------------------------------------------------------
	/**
	 * @brief Original spectral LOWESS implementation (no model averaging)
	 */
	graph_spectral_lowess_t graph_spectral_lowess(
		const std::vector<double>& y,
		size_t n_evectors,
		// bw parameters
		size_t n_bws,
		bool log_grid,
		double min_bw_factor,
		double max_bw_factor,
		// kernel parameters
		double dist_normalization_factor,
		size_t kernel_type,
		// other
		double precision,
		size_t n_cleveland_iterations,
		bool verbose
		) const;

	std::vector<double> graph_deg0_lowess(
		const std::vector<double>& y,
		double bandwidth,
		size_t kernel_type,
		double dist_normalization_factor,
		bool verbose
		) const;

	graph_deg0_lowess_cv_t graph_deg0_lowess_cv(
		const std::vector<double>& y,
		double min_bw_factor,
		double max_bw_factor,
		size_t n_bws,
		bool log_grid,
		size_t kernel_type,
		double dist_normalization_factor,
		bool use_uniform_weights,
		size_t n_folds,
		bool with_bw_predictions,
		double precision,
		bool verbose
		);

	graph_deg0_lowess_cv_mat_t graph_deg0_lowess_cv_mat(
		const std::vector<std::vector<double>>& Y,
		double min_bw_factor,
		double max_bw_factor,
		size_t n_bws,
		bool log_grid,
		size_t kernel_type,
		double dist_normalization_factor,
		bool use_uniform_weights,
		size_t n_folds,
		bool with_bw_predictions,
		double precision,
		bool verbose
		);

	/**
	 * @brief Perform degree-0 LOWESS with buffer zone cross-validation for bandwidth selection
	 */
	graph_deg0_lowess_buffer_cv_t graph_deg0_lowess_buffer_cv(
		const std::vector<double>& y,
		double min_bw_factor,
		double max_bw_factor,
		size_t n_bws,
		bool log_grid,
		size_t kernel_type,
		double dist_normalization_factor,
		bool use_uniform_weights,
		size_t buffer_hops,
		bool auto_buffer_hops,
		size_t n_folds,
		bool with_bw_predictions,
		double precision,
		bool verbose
		);

	/**
	 * @brief Perform graph kernel smoothing with buffer zone cross-validation for bandwidth selection
	 */
	graph_kernel_smoother_t graph_kernel_smoother(
		const std::vector<double>& y,
		double min_bw_factor,
		double max_bw_factor,
		size_t n_bws,
		bool log_grid,
		size_t vertex_hbhd_min_size,
		size_t kernel_type,
		double dist_normalization_factor,
		bool use_uniform_weights,
		size_t buffer_hops,
		bool auto_buffer_hops,
		size_t n_folds,
		bool with_bw_predictions,
		double precision,
		bool verbose
		);

	/**
	 * @brief Spectral-based graph smoother with global bandwidth selection and optional diagnostics
	 */
	graph_bw_adaptive_spectral_smoother_t graph_bw_adaptive_spectral_smoother(
		const std::vector<double>& y,
		size_t n_evectors,
		double min_bw_factor,
		double max_bw_factor,
		size_t n_bws,
		bool log_grid,
		size_t kernel_type,
		double dist_normalization_factor,
		double precision,
		bool use_global_bw_grid,
		bool with_bw_predictions,
		bool with_vertex_bw_errors,
		bool verbose
	);

	klaps_low_pass_smoother_t klaps_low_pass_smoother(
		const std::vector<double>& y,
		size_t n_evectors_to_compute,
		size_t min_num_eigenvectors,
		size_t max_num_eigenvectors,
		double tau_factor,
		double radius_factor,
		size_t laplacian_power,
		size_t n_candidates,
		bool   log_grid,
		double energy_threshold,
		bool   with_k_predictions,
		bool   verbose
		) const;

	/**
	 * @brief Smooths a signal on a graph using spectral filtering.
	 *
	 * @details
	 * This function implements spectral filtering of graph signals using various types of
	 * graph Laplacians and filter functions. It can use different Laplacian constructions,
	 * including standard, normalized, and kernel-based approaches, and supports various
	 * spectral filter types like heat kernel, Gaussian, cubic spline, and others.
	 *
	 * @param y Vector of signal values defined on graph vertices
	 * @param laplacian_type Type of graph Laplacian to use
	 * @param filter_type Type of spectral filter to apply
	 * @param laplacian_power Power to which the Laplacian is raised (typically 1 or 2)
	 * @param kernel_params Parameters for kernel-based Laplacian construction
	 * @param n_evectors_to_compute Number of eigenvectors to compute for spectral decomposition
	 * @param n_candidates Number of diffusion times to evaluate
	 * @param log_grid Whether to use logarithmic spacing for diffusion times
	 * @param with_t_predictions Whether to store predictions for all diffusion times
	 * @param verbose Whether to print progress information
	 *
	 * @return graph_spectral_filter_t structure containing filtering results and parameters
	 */
	graph_spectral_filter_t
	graph_spectral_filter(
		const std::vector<double>& y,
		laplacian_type_t laplacian_type = laplacian_type_t::STANDARD,
		filter_type_t filter_type = filter_type_t::HEAT,
		size_t laplacian_power = 1,
		kernel_params_t kernel_params = {},
		size_t n_evectors_to_compute = 100,
		size_t n_candidates = 40,
		bool   log_grid = true,
		bool   with_t_predictions = false,
		bool   verbose = false
		) const;


	/**
	 * @brief Computes the spectrum of various types of graph Laplacians.
	 *
	 * @details
	 * This function provides a unified interface to compute the eigendecomposition of different
	 * types of graph Laplacians, including standard, normalized, kernel-based, and their squared
	 * or shifted variants. The function internally handles the appropriate construction and
	 * computation based on the laplacian_type parameter.
	 *
	 * @param n_evectors Number of eigenvectors to compute
	 * @param laplacian_type Type of Laplacian (see laplacian_type_t enum)
	 * @param kernel_params Parameters for kernel-based Laplacians:
	 *    - tau: Kernel bandwidth parameter
	 *    - radius_factor: Multiplier for search radius
	 *    - kernel_type: Type of kernel function to use
	 * @param power Power to raise the Laplacian to (typically 1 or 2)
	 * @param verbose Whether to print progress information
	 *
	 * @return A std::pair consisting of:
	 *   - first:  Eigen::VectorXd of eigenvalues sorted appropriately
	 *   - second: Eigen::MatrixXd whose columns are the corresponding eigenvectors
	 */
	std::pair<Eigen::VectorXd, Eigen::MatrixXd>
	compute_graph_laplacian_spectrum_generic(
		const std::vector<double>& y,
		size_t n_evectors,
		laplacian_type_t laplacian_type,
		const kernel_params_t& kernel_params = {},
		size_t power = 1,
		bool verbose = false
		) const;

	// Laplacian construction functions
	/**
	 * @brief Constructs the standard combinatorial Laplacian matrix L = D - A
	 *
	 * @return Eigen::SparseMatrix<double> The standard Laplacian matrix
	 */
	Eigen::SparseMatrix<double>
	construct_standard_laplacian(const kernel_params_t& params) const;

	/**
	 * @brief Constructs the normalized Laplacian matrix L_norm = D^(-1/2) L D^(-1/2)
	 *
	 * @return Eigen::SparseMatrix<double> The normalized Laplacian matrix
	 */
	Eigen::SparseMatrix<double>
	construct_normalized_laplacian(const kernel_params_t& params) const;

	/**
	 * @brief Constructs the random walk Laplacian matrix L_rw = D^(-1) L
	 *
	 * @return Eigen::SparseMatrix<double> The random walk Laplacian matrix
	 */
	Eigen::SparseMatrix<double>
	construct_random_walk_laplacian(const kernel_params_t& params) const;

	/**
	 * @brief Constructs a kernel-based Laplacian matrix using distance-based kernel weights
	 *
	 * @param params Parameters controlling kernel construction
	 * @return Eigen::SparseMatrix<double> The kernel Laplacian matrix
	 */
	Eigen::SparseMatrix<double>
	construct_kernel_laplacian(const kernel_params_t& params) const;

	/**
	 * @brief Constructs a normalized kernel Laplacian matrix
	 *
	 * @param params Parameters controlling kernel construction
	 * @return Eigen::SparseMatrix<double> The normalized kernel Laplacian matrix
	 */
	Eigen::SparseMatrix<double>
	construct_normalized_kernel_laplacian(const kernel_params_t& params) const;

	/**
	 * @brief Constructs an adaptive kernel Laplacian with locally varying bandwidths
	 *
	 * @param params Base parameters for kernel construction
	 * @return Eigen::SparseMatrix<double> The adaptive kernel Laplacian matrix
	 */
	Eigen::SparseMatrix<double>
	construct_adaptive_kernel_laplacian(const kernel_params_t& params) const;

	/**
	 * @brief Constructs a regularized Laplacian L + ε*I to ensure positive definiteness
	 *
	 * @param epsilon Regularization parameter (small positive value)
	 * @return Eigen::SparseMatrix<double> The regularized Laplacian matrix
	 */
	Eigen::SparseMatrix<double>
	construct_regularized_laplacian(const kernel_params_t& params, double epsilon) const;

	/**
	 * @brief Constructs a regularized kernel Laplacian L_kernel + ε*I
	 *
	 * @param params Parameters for kernel construction
	 * @param epsilon Regularization parameter (small positive value)
	 * @return Eigen::SparseMatrix<double> The regularized kernel Laplacian matrix
	 */
	Eigen::SparseMatrix<double>
	construct_regularized_kernel_laplacian(
		const kernel_params_t& params,
		double epsilon) const;

	/**
	 * @brief Constructs a multi-scale Laplacian that combines kernel Laplacians at different scales
	 *
	 * @param params Base parameters for kernel construction
	 * @return Eigen::SparseMatrix<double> The multi-scale Laplacian matrix
	 */
	Eigen::SparseMatrix<double>
	construct_multi_scale_laplacian(const kernel_params_t& params) const;

	/**
	 *  @brief Constructs a path Laplacian
	 */
	Eigen::SparseMatrix<double>
	construct_path_laplacian(
		const std::vector<double>& y,
		const kernel_params_t& params,
		bool verbose
		) const;

	/**
	 * @brief Computes kernel weight based on distance and kernel type
	 *
	 * @param distance Distance between vertices
	 * @param tau Kernel bandwidth parameter
	 * @param kernel_type Type of kernel function to use
	 * @return double The computed kernel weight
	 */
	double
	compute_kernel_weight(
		double distance,
		double tau,
		kernel_type_t kernel_type) const;

	/**
	 * @brief Converts a Laplacian type enum to a string description
	 *
	 * @param type The Laplacian type enum value
	 * @return std::string A string description of the Laplacian type
	 */
	std::string
	laplacian_type_to_string(laplacian_type_t type) const;

	// Convenience wrappers for specific Laplacian types
	/**
	 * @brief Computes the spectrum of the normalized graph Laplacian
	 *
	 * @param n_evectors Number of eigenvectors to compute
	 * @param verbose Whether to print progress information
	 * @return A std::pair of eigenvalues and eigenvectors
	 */
	std::pair<Eigen::VectorXd, Eigen::MatrixXd>
	compute_graph_normalized_laplacian_spectrum(
		size_t n_evectors,
		bool verbose = false
		) const;

	/**
	 * @brief Computes the spectrum of a kernel-based graph Laplacian
	 *
	 * @param n_evectors Number of eigenvectors to compute
	 * @param tau Kernel bandwidth parameter
	 * @param radius_factor Search radius multiplier
	 * @param kernel_type Type of kernel function to use
	 * @param verbose Whether to print progress information
	 * @return A std::pair of eigenvalues and eigenvectors
	 */
	std::pair<Eigen::VectorXd, Eigen::MatrixXd>
	compute_graph_kernel_laplacian_spectrum(
		size_t n_evectors,
		double tau,
		double radius_factor,
		kernel_type_t kernel_type = kernel_type_t::S_GAUSSIAN,
		bool verbose = false
		) const;

	/**
	 * @brief Computes the spectrum of the squared graph Laplacian (L²)
	 *
	 * @param n_evectors Number of eigenvectors to compute
	 * @param laplacian_type Type of base Laplacian to square
	 * @param kernel_params Parameters for kernel-based Laplacians
	 * @param verbose Whether to print progress information
	 * @return A std::pair of eigenvalues and eigenvectors
	 */
	std::pair<Eigen::VectorXd, Eigen::MatrixXd>
	compute_graph_laplacian_squared_spectrum(
		size_t n_evectors,
		laplacian_type_t laplacian_type = laplacian_type_t::STANDARD,
		const kernel_params_t& kernel_params = {},
		bool verbose = false
		) const;


	/**
	 * @brief Computes the eigenvectors of the graph Laplacian.
	 */
	Eigen::MatrixXd compute_graph_laplacian_eigenvectors(
		size_t n_evectors,
		bool verbose
		) const;

	Eigen::MatrixXd compute_graph_shifted_kernel_laplacian_eigenvectors(
		size_t n_evectors,
		double tau,
		size_t k,
		bool verbose
		) const;

	std::pair<Eigen::VectorXd, Eigen::MatrixXd>
	compute_graph_shifted_kernel_laplacian_spectrum(
		size_t n_evectors,
		double tau,
		double radius_factor,
		size_t laplacian_power,
		bool verbose
		) const;

	/**
	 * @brief Returns both eigenvalues and eigenvectors
	 */
	std::pair<Eigen::VectorXd, Eigen::MatrixXd>
	compute_graph_laplacian_spectrum(
		size_t n_evectors,
		bool   verbose
		) const;

	/**
	 * @brief Compute total squared curvature using the random‑walk normalized Laplacian on an unweighted graph.
	 */
	double get_total_sq_curvature(
		const std::vector<double>& predictions
		) const;

	/**
	 * @brief Compute sum of squared normalized curvature (Laplacian) with additive regularization.
	 */
 	double get_total_sq_normalized_curvature(
		const std::vector<double>& predictions,
		double delta
		) const;



	/**
	 * @brief Create a buffer zone around test vertices up to a specified hop distance
	 */
	std::unordered_set<size_t> create_buffer_zone(
		const std::vector<size_t>& test_vertices,
		size_t buffer_hops
		);

	/**
	 * @brief Creates spatially stratified cross-validation folds for graph-based data
	 */
	std::vector<std::vector<size_t>> create_spatially_stratified_folds(
		size_t n_folds
		);

	/**
	 * @brief Predicts the value at a test vertex using training vertices outside a buffer zone
	 */
	double predict_test_vertex_with_buffer(
		size_t test_vertex,
		size_t buffer_hops,
		const std::vector<double>& y,
		const std::vector<size_t>& current_fold,
		double dist_normalization_factor,
		bool use_uniform_weights
		);

	/**
	 * @brief Predict values for test vertices while respecting buffer zones
	 */
	std::vector<prediction_result_t> predict_with_buffer_zone(
		double bandwidth,
		const std::vector<double>& weights,
		const std::vector<double>& y,
		const std::vector<size_t>& test_vertices,
		const std::unordered_set<size_t>& buffer_zone,
		double dist_normalization_factor,
		bool use_uniform_weights
		);

	/**
	 * @brief Generate predictions for all vertices using the optimal bandwidth
	 */
	std::vector<double> predict_all_with_optimal_bandwidth(
		double bandwidth,
		const std::vector<double>& y,
		double dist_normalization_factor,
		bool use_uniform_weights,
		double lower_bound,
		double upper_bound,
		size_t domain_min_size
		);

	/**
	 * @brief Determine the optimal buffer hop distance based on spatial autocorrelation
	 */
	size_t determine_optimal_buffer_hops(
		const std::vector<double>& y,
		bool verbose
		);

	/**
	 * @brief Calculate Moran's I spatial autocorrelation statistic
	 */
	double calculate_morans_i(
		const std::vector<double>& y,
		size_t hop_distance
		);

	/**
	 * @brief Model-averaged spectral LOWESS implementation
	 */
	graph_spectral_lowess_t graph_spectral_ma_lowess(
		const std::vector<double>& y,
		size_t n_evectors,
		// bw parameters
		size_t n_bws,
		bool log_grid,
		double min_bw_factor,
		double max_bw_factor,
		// kernel parameters
		double dist_normalization_factor,
		size_t kernel_type,
		// model parameters
		double model_blending_coef,
		// other
		double precision,
		bool verbose
		) const;

	/**
	 * @brief Find vertices within a specified radius of a reference vertex
	 */
	std::unordered_map<size_t, double> find_vertices_within_radius(
		size_t vertex,
		double radius
		) const;

	/**
	 * @brief Find minimum radius that includes a specified number of vertices
	 */
	double find_minimum_radius_for_domain_min_size(
		size_t vertex,
		double lower_bound,
		double upper_bound,
		size_t domain_min_size,
		double precision
		) const;

	double find_min_radius_for_neighbor_count(
		std::unordered_map<size_t, double>& ngbr_dist_map,
		size_t vertex_hbhd_min_size
		) const;

	std::pair<std::vector<std::pair<size_t, double>>, double>
	get_sorted_vertices_and_min_radius(
		const std::unordered_map<size_t, double>& ngbr_dist_map,
		size_t vertex_hbhd_min_size
		) const;

	std::pair<std::vector<std::pair<size_t, double>>, double>
	get_sorted_vertices_and_min_radius(
		const std::unordered_map<size_t, double>& ngbr_dist_map,
		size_t vertex_hbhd_min_size,
		std::unordered_set<size_t>& training_set
		) const;

	size_t get_lextr_count(
		std::vector<double>& y
		) const;

	// ----------------------------------------------------------------

	std::pair<size_t, double> get_vertex_eccentricity(
		size_t start_vertex
		) const;

	std::vector<size_t> create_maximal_packing(
		double radius,
		size_t start_vertex
		) const;

	std::vector<size_t> create_maximal_packing(
		size_t grid_size,
		size_t max_iterations,
		double precision
		);

	std::vector<size_t> find_boundary_vertices_outside_radius(
		size_t start,
		double radius,
		explored_tracker_t& explored_tracker
		) const;

	std::pair<size_t, double> find_first_vertex_outside_radius(
		size_t start,
		double radius
		) const;

	std::pair<size_t, double> find_first_vertex_outside_radius(
		size_t start,
		double radius,
		explored_tracker_t& explored_tracker
		) const;

	double compute_shortest_path_distance(
		size_t from,
		size_t to
		) const;

	std::unordered_map<size_t,double>
	compute_shortest_path_distances(
		size_t from,
		const std::unordered_set<size_t>& to_set
		) const;

	tube_lens_corridor_result_t compute_tube_lens_corridor(
		size_t source,
		size_t target,
		double path_relative_radius,
		double excess_tolerance,
		bool compute_excess
		) const;

	void trace_exploration_path(
		size_t from_vertex,
		size_t to_vertex,
		double radius
		) const;

	//
	// AGEMALO helper functions
	//
	shortest_paths_t find_graph_paths_within_radius(
		size_t start,
		double radius
		) const;

	shortest_paths_t find_graph_paths_within_radius_and_path_min_size(
		size_t start,
		double radius,
		size_t min_path_size
		) const;

	void handle_single_ray_geodesic(
		shortest_paths_t& shortest_paths,
		composite_shortest_paths_t& composite_paths
		) const;

	std::vector<double> compute_mirror_quadratic_weights(
		const std::vector<size_t>& path,
		size_t center_vertex,
		const std::vector<double>& y,
		const kernel_params_t& params
		) const;

	gray_xyw_t get_xyw_along_path(
		const std::vector<double>& y,
		path_t& path,
		double dist_normalization_factor
		) const;

	/**
	 * @brief Find the minimum bandwidth that ensures at least one geodesic ray has the minimum required size
	 */
	double find_minimum_bandwidth(
		size_t grid_vertex,
		double lower_bound,
		double upper_bound,
		size_t min_path_size,
		double precision
		) const;

	/**
	 * @brief Check if any path in the shortest_paths structure has the minimum required size
	 */
	bool has_sufficient_path_size(
		const shortest_paths_t& paths,
		size_t min_path_size
		) const;


	/**
	 * @brief Cluster similar geodesic rays and select representatives
	 */
	std::vector<path_t> cluster_and_select_rays(
		size_t grid_vertex,
		const shortest_paths_t& shortest_paths,
		const std::vector<double>& y,
		double directional_threshold,
		double jaccard_thld,
		size_t min_path_size,
		double dist_normalization_factor
		) const;

	/**
	 * @brief Determine if two paths explore similar directions from a reference vertex
	 */
	bool paths_share_direction(
		const path_t& path_i,
		const path_t& path_j,
		size_t ref_vertex,
		double directional_threshold,
		double jaccard_thld
		) const;

	/**
	 * @brief Select the best path from a cluster based on weighted correlation R-squared
	 */
	size_t select_best_path(
		const std::vector<size_t>& cluster,
		const shortest_paths_t& shortest_paths,
		const std::vector<double>& y,
		size_t min_path_size,
		double dist_normalization_factor
		) const;

	/**
	 * @brief Find the optimal bandwidth that minimizes mean prediction error using binary search
	 */
	std::pair<double, std::vector<ext_ulm_t>> find_optimal_bandwidth(
		size_t grid_vertex,
		const std::vector<double>& y,
		size_t min_path_size,
		double min_bw,
		double max_bw,
		double dist_normalization_factor,
		bool y_binary,
		double tolerance,
		double precision = 0.001,
		bool verbose = false,
		const std::optional<std::vector<double>>& weights = std::nullopt
		) const;

	/**
	 * @brief Find the optimal bandwidth that minimizes mean prediction error using candidate bw grid
	 */
	opt_bw_t find_optimal_bandwidth_over_grid(
		size_t grid_vertex,
		const std::vector<double>& y,
		size_t min_path_size,
		double min_bw,
		double max_bw,
		size_t n_bws,
		bool log_grid,
		double dist_normalization_factor,
		bool y_binary,
		double tolerance,
		double precision = 1e-6,
		bool verbose = false,
		const std::optional<std::vector<double>>& weights = std::nullopt
		) const;

	/**
	 * @brief Evaluate the prediction error for models at a specific bandwidth
	 */
	std::pair<double, std::vector<ext_ulm_t>> evaluate_bandwidth(
		size_t grid_vertex,
		const std::vector<double>& y,
		size_t min_path_size,
		double bw,
		double min_bw,
		double dist_normalization_factor,
		bool y_binary,
		double tolerance,
		const std::optional<std::vector<double>>& weights = std::nullopt
		) const;

	// ----------------------------------------------------------------
	// Local slope (asymmetric association) methods
	// ----------------------------------------------------------------

	std::pair<size_t, double> find_gradient_edge(
		size_t v,
		const std::vector<double>& y,
		edge_diff_type_t y_diff_type,
		double epsilon_y,
		bool ascending
		) const;

	lslope_result_t lslope_gradient(
		const std::vector<double>& y,
		const std::vector<double>& z,
		lslope_type_t slope_type,
		edge_diff_type_t y_diff_type,
		edge_diff_type_t z_diff_type,
		double epsilon,
		double sigmoid_alpha,
		sigmoid_type_t sigmoid_type,
		bool ascending
		) const;

	lslope_nbhd_result_t lslope_neighborhood(
		const std::vector<double>& y,
		const std::vector<double>& z,
		lcor_type_t weight_type,
		edge_diff_type_t y_diff_type,
		edge_diff_type_t z_diff_type,
		double epsilon,
		double winsorize_quantile
		) const;

	std::vector<double> lslope(
		const std::vector<double>& y,
		const std::vector<double>& z,
		lslope_type_t slope_type,
		lcor_type_t weight_type,
		edge_diff_type_t y_diff_type,
		edge_diff_type_t z_diff_type,
		double epsilon,
		double sigmoid_alpha,
		bool ascending
		) const;

	lslope_vector_matrix_result_t lslope_vector_matrix(
		const std::vector<double>& y,
		const Eigen::MatrixXd& Z,
		lslope_type_t slope_type,
		edge_diff_type_t y_diff_type,
		edge_diff_type_t z_diff_type,
		double epsilon,
		double sigmoid_alpha,
		bool ascending,
		int n_threads = 0
		) const;

	// ----------------------------------------------------------------
	// Local correlation methods
	// ----------------------------------------------------------------

	// instrumented
	lcor_result_t lcor_instrumented(
        const std::vector<double>& y,
        const std::vector<double>& z,
        lcor_type_t weight_type,
        edge_diff_type_t y_diff_type,
        edge_diff_type_t z_diff_type,
        double epsilon,
        double winsorize_quantile
		) const;

	lcor_result_t lcor_one_pass_instrumented(
		const std::vector<double>& y,
		const std::vector<double>& z,
		lcor_type_t weight_type,
		edge_diff_type_t y_diff_type,
		edge_diff_type_t z_diff_type,
		double epsilon_y,
		double epsilon_z
		) const;

	lcor_result_t lcor_two_pass_instrumented(
		const std::vector<double>& y,
		const std::vector<double>& z,
		lcor_type_t weight_type,
		edge_diff_type_t y_diff_type,
		edge_diff_type_t z_diff_type,
		double epsilon_y,
		double epsilon_z,
		double winsorize_quantile
		) const;

	// Production versions (return only coefficients)
	std::vector<double> lcor(
        const std::vector<double>& y,
        const std::vector<double>& z,
        lcor_type_t weight_type,
        edge_diff_type_t y_diff_type,
        edge_diff_type_t z_diff_type,
        double epsilon,
        double winsorize_quantile
		) const;

	std::vector<double> lcor_one_pass(
		const std::vector<double>& y,
		const std::vector<double>& z,
		lcor_type_t weight_type,
		edge_diff_type_t y_diff_type,
		edge_diff_type_t z_diff_type,
		double epsilon_y,
		double epsilon_z
		) const;

	std::vector<double> lcor_two_pass(
		const std::vector<double>& y,
		const std::vector<double>& z,
		lcor_type_t weight_type,
		edge_diff_type_t y_diff_type,
		edge_diff_type_t z_diff_type,
		double epsilon_y,
		double epsilon_z,
		double winsorize_quantile
		) const;

	/**
     * @brief Compute local correlation between a vector y and each column of matrix Z
     */
    lcor_vector_matrix_result_t lcor_vector_matrix(
        const std::vector<double>& y,
        const Eigen::MatrixXd& Z,
        lcor_type_t weight_type,
        edge_diff_type_t y_diff_type,
        edge_diff_type_t z_diff_type,
        double epsilon,
        double winsorize_quantile
		) const;

	double get_edge_weight(size_t u, size_t v) const;

private:
	// Cache for computation - updated to use shortest_paths_t
	mutable std::unordered_map<size_t, shortest_paths_t> paths_cache;
	mutable std::unordered_set<size_t> unprocessed_vertices;
	mutable edge_weights_t edge_weights; // using edge_weights_t = std::unordered_map<std::pair<size_t,size_t>, double, size_t_pair_hash_t>;
	mutable bool edge_weights_computed = false;

	// Helper functions for path Laplacian
	std::vector<double> compute_quadratic_weights(
		const std::vector<size_t>& path,
		size_t center_vertex,
		const kernel_params_t& params
		) const;

	// Helper methods for gradient flow computation
	std::optional<std::pair<size_t, bool>> check_local_extremum(
		size_t vertex,
		const shortest_paths_t& paths_result,
		const std::vector<double>& y
		) const;

	gradient_trajectory_t construct_trajectory(
		size_t start,
		bool ascending_init,
		const std::vector<double>& scale,
		const std::vector<double>& y,
		const std::unordered_map<size_t, bool>& extrema_map,
		double long_edge_lower_thld,
		double long_edge_upper_thld
		) const;

	// Helper method to find connected components in a pro-cell
	std::vector<std::vector<size_t>> find_connected_components(
		const std::vector<size_t>& procell_vertices
		) const;
};

#endif   // GRAPH_HPP__
