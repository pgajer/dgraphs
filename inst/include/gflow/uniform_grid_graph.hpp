#ifndef UNIFORM_GRID_GRAPH_HPP
#define UNIFORM_GRID_GRAPH_HPP

#include "set_wgraph.hpp"
#include "edge_weights.hpp"
#include "reachability_map.hpp"

#include <cstddef>

#include <R.h>
#include <Rinternals.h>

using std::size_t;

/**
 * @brief A structure representing a path through a graph centered around a reference (grid) vertex
 *
 * This structure stores information about a path in a graph, including its
 * sequence of vertices and the distances from the reference/grid vertex to each
 * vertex.
 *
 * @details The path maintains several key pieces of information:
 *   - A sequence of vertices forming the path
 *   - The distance from each vertex to the target vertex
 */
struct ref_vertex_path_t {
    std::vector<size_t> vertices;        ///< Sequence of vertices forming the path
    std::vector<double> dist_to_ref_vertex;  ///< Distance from each vertex[i] to target_vertex, using edge weights

    #if 1
    size_t target_vertex;                ///< The vertex around which this path is centered
    double total_weight;                 ///< Total length of the path using edge weights
    double center_offset;                ///< How far target_vertex is from path center (0 = perfectly centered)

    ref_vertex_path_t() : target_vertex(INVALID_VERTEX), total_weight(0), center_offset(INFINITY) {}

    // For priority queue ordering
    bool operator<(const ref_vertex_path_t& other) const {
        if (std::abs(total_weight - other.total_weight) > 1e-10) {
            return total_weight < other.total_weight;  // prefer paths closer to target length
        }
        return center_offset > other.center_offset;    // prefer more centered paths
    }
    #endif
};

/**
 * A streamlined version of ref_vertex_path_t; with time I am going to get rid of ref_vertex_path_t and replace it with grid_vertex_path_t
 */
struct grid_vertex_path_t {
    std::vector<size_t> vertices;                 ///< Sequence of the original graph vertices forming the path
    std::vector<size_t> grid_vertices;            ///< Sequence of grid vertices forming the path
    std::vector<double> dist_to_ref_vertex;       ///< dist_to_ref_vertex[i] = distance from ref_vertex to vertex[i] along the path
    std::vector<double> grid_dist_to_ref_vertex;  ///< grid_dist_to_ref_vertex[i] = distance from ref_vertex to grid_vertex[i]
};

struct compose_path_t {
    std::vector<size_t> vertices;            ///< Sequence of the original graph vertices forming the path
    std::vector<double> dist_to_ref_vertex;  ///< Distance from each vertex[i] to ref_vertex, using edge weights
    std::vector<double> dist_to_from_start;  ///< Distance from the first vertex of vertices to each other vertex; that is dist_to_from_start[i] is the distance from vertices[0] to vertices[i]
    // grid vertices objects
    std::vector<size_t> grid_vertices;            ///< Sequence of grid vertices forming the path
    std::vector<double> grid_dist_to_ref_vertex;  ///< Distance from each grid_vertex[i] to ref_vertex, using edge weights
    std::vector<double> grid_dist_to_from_start;  ///< grid_dist_to_from_start[i] is the distance from vertices[0] to grid_vertices[i]
};

/**
 * @brief A structure containing path data for composite paths constructed from
 * the shortest paths starting at a __grid vertex__ of a graph
 *
 * If there is only one shortest path starting at the given grid vertex (of
 * length bound by the bandwidth parameter) the path itself will be a degenerate
 * composite path. If the set of shortest paths starting at the ref vertex has
 * more than one element, each pair of these paths is combined to form a
 * composite path. In most of the cases the reference vertex that is a graph
 * grid vertex will not be a part of the path as the path consist of only
 * original graph vertices over which the response variable is defined. Thus,
 * ref_vertex is a grid vertex index that may in rare cases be an original
 * vertex. The structure in a non-grid case had a parameter ref_vertex_index
 * that was removed from this structure as in most cases it will not make sense
 * (as the ref vertex is not part of the vertices vector).
 */
struct xyw_path_t {
    std::vector<size_t> vertices;              ///< Indices of the original graph vertices forming the path
    std::vector<size_t> grid_vertices;         ///< grid vertices contained within the edges of the path

    // x/y/w values over the original graph path vertices
    std::vector<double> x_path;                ///< Cumulative distance along path from initial vertex
    std::vector<double> y_path;                ///< Y-values of vertices restricted to the path
    std::vector<double> w_path;                ///< Kernel-weighted distances from reference vertex

    std::vector<double> grid_x_path;           ///< Cumulative distances along path from the initial vertex of the path to each grid vertex of the path; needed to generate predictions from the local model trained on x/y/w_path data at the grid vertices
    std::vector<double> grid_w_path;           ///< Weights for grid vertices - needed for model averaging over grid vertices
};

/**
 * @struct uniform_grid_graph_t
 * @brief Main data structure representing a uniform grid graph
 *
 * Stores the graph's adjacency list (inherited from graph_t), grid vertices,
 * and maintains information about the original graph structure.
 */
struct uniform_grid_graph_t : public set_wgraph_t {

    /**
     * @brief Tracks which vertices represent actual grid points Used to
     * distinguish between original graph vertices and intermediate vertices
     * added during grid construction. Some original graph vertices will become
     * grid vertices.
     */
    std::unordered_set<size_t> grid_vertices;

    /**
     * @brief Number of vertices in the original graph before grid refinement
     * This helps maintain a reference to the original graph's size when
     * working with the expanded grid graph
     */
    size_t n_original_vertices;

    uniform_grid_graph_t()
        : set_wgraph_t(),  // This will call the base class constructor that sets graph_diameter to -1.0 and max_packing_radius to -1.0
          n_original_vertices(0)
        {}

    explicit uniform_grid_graph_t(const std::vector<std::vector<int>>& adj_list,
                                  const std::vector<std::vector<double>>& weight_list
        )
        : set_wgraph_t(adj_list, weight_list), // Call the parent constructor
          n_original_vertices(adj_list.size())
        {};

    explicit uniform_grid_graph_t(const std::vector<std::vector<int>>& adj_list,
                                  const std::vector<std::vector<double>>& weight_list,
                                  size_t start_vertex
        )
        : set_wgraph_t(adj_list, weight_list), // Call the parent constructor
          n_original_vertices(adj_list.size())
        {
            grid_vertices.insert(start_vertex);
        };

    explicit uniform_grid_graph_t(const std::vector<std::vector<int>>& adj_list,
                                  const std::vector<std::vector<double>>& weight_list,
                                  std::vector<size_t>& packing
        )
        : set_wgraph_t(adj_list, weight_list), // Call the parent constructor
          n_original_vertices(adj_list.size())
        {
            grid_vertices = std::unordered_set<size_t>(packing.begin(), packing.end());
        };

    explicit uniform_grid_graph_t(const set_wgraph_t& graph,
                                  std::vector<size_t> packing)
        : set_wgraph_t(graph), // Copy construct from the parent graph
          n_original_vertices(graph.adjacency_list.size())
        {
            // Populate grid_vertices from the packing vector
            grid_vertices = std::unordered_set<size_t>(packing.begin(), packing.end());
        }

    /**
     * @brief Finds original vertices within a specified radius of a reference vertex
     */
    std::pair<std::unordered_map<size_t, double>,
              std::unordered_map<size_t, double>>
    find_original_vertices_within_radius(
        size_t grid_vertex,
        double radius
        ) const;

    /**
     * @brief Finds the minimum radius required to include at least domain_min_size original vertices
     */
    double find_grid_minimum_radius_for_domain_min_size(
        size_t grid_vertex,
        double lower_bound,
        double upper_bound,
        size_t domain_min_size,
        double precision
        ) const;


    /**
     * @brief Constructs a uniform grid graph from an existing weighted graph and packing
     *
     * @details This constructor creates a uniform grid graph by taking an existing set_wgraph_t
     * and a set of vertices that form a maximal packing. It efficiently utilizes the existing
     * graph structure without making deep copies, improving performance when the graph and
     * packing are computed in the same scope.
     *
     * @param graph Reference to an existing set_wgraph_t containing the graph structure
     * @param packing Reference to a vector of vertex indices forming the maximal packing
     *
     * @note This constructor preserves the properties of the source graph including
     *       graph_diameter and max_packing_radius
     */
    explicit uniform_grid_graph_t(set_wgraph_t& graph,
                                  std::vector<size_t>& packing)
        : set_wgraph_t(graph),  // Copy construct from the parent graph
          n_original_vertices(graph.adjacency_list.size())
        {
            // Transfer diameter and packing radius information
            this->graph_diameter = graph.graph_diameter;
            this->max_packing_radius = graph.max_packing_radius;

            // Populate grid_vertices from the packing vector
            grid_vertices = std::unordered_set<size_t>(packing.begin(), packing.end());
        }

    void print(
        const std::string& name = "",
        bool split = false,
        size_t shift = 0
        ) const;

    void print_grid_vertices(size_t shift = 0) const;

    std::unordered_map<size_t, std::pair<double, size_t>> find_grid_paths_within_radius(
        size_t start,
        double radius
        ) const;

    /**
     * @brief Discovers paths meeting minimum size requirements by adaptively adjusting search radius
     */
    std::vector<compose_path_t> find_min_size_composite_paths(
        size_t grid_vertex,
        size_t min_path_size,
        size_t min_num_grid_vertices,
        double current_max_bw,
        double graph_diameter,
        double* final_max_bw = nullptr
        ) const;

    /**
     * @brief Filters paths to include only those meeting minimum size requirements
     */
    std::vector<compose_path_t> filter_composite_paths(
        const std::vector<compose_path_t>& paths,
        size_t min_path_size,
        size_t min_num_grid_vertices
        ) const;

    /**
     * @brief Combines search and filtering operations to find qualified composite paths with adaptive radius adjustment
     */
    std::vector<compose_path_t> find_and_filter_composite_paths(
        size_t ref_vertex,
        double initial_radius,
        size_t min_path_size,
        size_t min_num_grid_vertices,
        double graph_diameter,
        double* final_radius = nullptr
        ) const;

     /**
     * @brief Computes a reachability map from a reference vertex within a specified radius
     * @param ref_vertex The starting vertex for path computation
     * @param radius Maximum distance to consider when computing paths
     * @return A reachability map containing paths and distances to reachable vertices
     */
    reachability_map_t compute_reachability_map(
        size_t ref_vertex,
        double radius
        ) const;

    /**
     * @brief Computes a reachability map from a reference vertex to all reachable vertices
     * @param ref_vertex The starting vertex for path computation
     * @return A reachability map containing paths and distances to all reachable vertices
     */
    reachability_map_t compute_reachability_map(size_t ref_vertex) const {
        return compute_reachability_map(ref_vertex, INFINITY);
    }

    std::vector<grid_vertex_path_t> reconstruct_paths(
        reachability_map_t& reachability_map
        ) const;

    std::vector<compose_path_t> create_composite_paths(
        std::vector<grid_vertex_path_t>& grid_vertex_paths
        ) const;

    bool has_min_size_path(
        const std::vector<compose_path_t>& composite_paths,
        size_t min_path_size,
        size_t min_num_grid_vertices = 2
        ) const;

    std::vector<compose_path_t> find_min_size_composite_paths(
        size_t grid_vertex,
        size_t min_path_size,
        double current_max_bw,
        double graph_diameter
        ) const;

    std::vector<compose_path_t> get_bw_composite_paths(
        double bw,
        const std::vector<compose_path_t>& composite_paths,
        size_t min_path_size,
        size_t min_num_grid_vertices
        ) const;


    xyw_path_t get_xyw_data(
        const std::vector<double>& y,
        compose_path_t& path,
        double dist_normalization_factor
        ) const;

    // -----

#if 0
    std::vector<xyw_path_t> reconstruct_xyw_paths(
        const reachability_map_t& reachability_map,
        const std::vector<double>& y,
        double radius,
        size_t kernel_type,
        double dist_normalization_factor,
        size_t min_path_size,
        size_t diff_threshold,
        const edge_weights_t& edge_weights
        ) const;
#endif

    void remove_edge(size_t v1, size_t v2);
    void add_edge(size_t v1, size_t v2, double weight);
    double find_grid_distance(size_t source, size_t target) const;
    double get_parent_graph_edge_weight(
        const edge_weights_t& weights,
        size_t v1, size_t v2
        ) const;

    std::vector<double> compute_all_shortest_path_distances(size_t start_vertex) const;

    std::vector<vertex_info_t> find_path_endpoints(
        const reachability_map_t& reachability_map) const;


private:
    bool is_original_vertex(size_t vertex) const {
        return vertex < n_original_vertices;
    }

    // Helper method to reconstruct a single path
    ref_vertex_path_t reconstruct_single_path(
        size_t vertex,
        double distance,
        const reachability_map_t& reachability_map) const;


        // Helper method to check if paths can be combined
    bool can_combine_paths(
        const ref_vertex_path_t& path1,
        const ref_vertex_path_t& path2,
        size_t min_path_size,
        size_t diff_threshold) const;

#if 0
    // Convert a single reference vertex path to XYW format
    xyw_path_t convert_to_xyw_path(
        const ref_vertex_path_t& path,
        const std::vector<double>& y,
        size_t kernel_type,
        double dist_normalization_factor,
        const edge_weights_t& edge_weights) const;

    // Helper method to process paths into XYW format
    std::vector<xyw_path_t> process_xyw_paths(
        const std::vector<ref_vertex_path_t>& paths,
        const std::vector<double>& y,
        size_t min_path_size,
        size_t diff_threshold,
        size_t kernel_type,
        double dist_normalization_factor,
        const edge_weights_t& edge_weights) const;

    // Create a composite path by combining two paths
    xyw_path_t create_composite_xyw_path(
        const ref_vertex_path_t& path1,
        const ref_vertex_path_t& path2,
        const std::vector<double>& y,
        size_t kernel_type,
        double dist_normalization_factor,
        const edge_weights_t& edge_weights) const;

    // Helper method to compute kernel weights for a path
    void compute_kernel_weights(
        xyw_path_t& path,
        size_t kernel_type,
        double dist_normalization_factor) const;
#endif

    // Helper method to check if paths explore different directions
    bool paths_explore_different_directions(
        const ref_vertex_path_t& path1,
        const ref_vertex_path_t& path2,
        size_t diff_threshold) const;

};

uniform_grid_graph_t create_uniform_grid_graph(
    const std::vector<std::vector<int>>& input_adj_list,
    const std::vector<std::vector<double>>& input_weight_list,
    size_t grid_size,
    size_t start_vertex,
    double snap_tolerance);

uniform_grid_graph_t create_maximal_packing(
    const std::vector<std::vector<int>>& adj_list,
    const std::vector<std::vector<double>>& weight_list,
    size_t grid_size,
    size_t max_iterations,
    double precision);

/**
 * @brief Computes geodesic statistics for all grid vertices across a range of radii
 *
 * @param grid_graph The uniform grid graph to analyze
 * @param min_radius Minimum radius to test (as a fraction of graph diameter)
 * @param max_radius Maximum radius to test (as a fraction of graph diameter)
 * @param n_steps Number of radius steps to test
 * @param verbose Whether to print progress information
 *
 * @return geodesic_stats_t Structure containing geodesic statistics
 */
geodesic_stats_t compute_geodesic_stats(
    const uniform_grid_graph_t& grid_graph,
    double min_radius = 0.1,
    double max_radius = 0.5,
    size_t n_steps = 5,
    bool verbose = false
);

/**
 * @brief Computes geodesic statistics for a specific grid vertex across a range of radii
 *
 * @param grid_graph The uniform grid graph to analyze
 * @param grid_vertex The grid vertex to analyze
 * @param min_radius Minimum radius to test (as a fraction of graph diameter)
 * @param max_radius Maximum radius to test (as a fraction of graph diameter)
 * @param n_steps Number of radius steps to test
 *
 * @return std::vector<std::tuple<double, size_t, size_t, overlap_stats_t>>
 *         Vector of tuples containing (radius, geodesic_rays, composite_geodesics, overlap_stats)
 */
std::vector<std::tuple<double, size_t, size_t, overlap_stats_t>> compute_vertex_geodesic_stats(
    const uniform_grid_graph_t& grid_graph,
    size_t grid_vertex,
    double min_radius = 0.1,
    double max_radius = 0.5,
    size_t n_steps = 5
);


#endif // UNIFORM_GRID_GRAPH_HPP
