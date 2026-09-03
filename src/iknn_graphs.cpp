/*!
  Creating Intersetion Weighted kNN graph (IWkNN graph)

  Two points are connected by an edge in this graph if and only if they share at
  least one common point within their respective k-nearest neighbor sets. In
  other words, there's an intersection between their k-nearest neighborhoods.

  \textbf{Characteristics:}

  * \textbf{Reciprocity:} This connection is inherently reciprocal. If point A is within the k-nearest neighbors of point B, then point B will also be within the k-nearest neighbors of point A. This generally results in an undirected graph.
  * \textbf{Sensitivity to k:} The choice of the parameter k significantly influences the structure of this graph. Larger values of k tend to create denser graphs with more connections.
  * \textbf{Focus on Shared Neighbors:} This variant emphasizes points that are "locally similar," meaning they share commonalities within their local neighborhoods.

  \textbf{Potential Use Cases:}

  * \textbf{Clustering and Community Detection:} This type of graph could be valuable in identifying densely connected clusters of points that share neighbors, indicating groups exhibiting similar characteristics.
  * \textbf{Outlier Detection:}  Points with abnormally few connections in this graph might indicate potential outliers, as they don't consistently appear in the k-nearest neighborhoods of other points.
  * \textbf{Collaborative Filtering:} This construct might be applicable in recommendation systems where you want to emphasize items that have been "liked" by users with overlapping tastes.

  \textbf{Caveats:}

  * \textbf{Computational Cost:} Constructing this graph can be computationally more demanding than a standard k-NN graph because you need to compare k-nearest neighbor sets.
  * \textbf{Data Density:}  In very sparse datasets, this construct might lead to highly disconnected graphs.

  \textbf{Relationship with Other Graphs:}

  It's interesting to note that this graph would likely be denser than a Mutual k-Nearest Neighbor Graph (Mk-NN).  In an Mk-NN, two points need to be *each other's* k-nearest neighbors, while in this variant they just need to share at least one common neighbor in their sets.

*/

#include "dgraphs/omp_compat.h"
#include "dgraphs/iknn_graphs.hpp"
#include "dgraphs/set_wgraph.hpp"
#include "dgraphs/knn_search_result.hpp"
#include "dgraphs/linf_simplex_knn.hpp"
#include "dgraphs/kNN_r.h"            // for S_kNN()
#include "dgraphs/kNN.h"              // for struct iknn_vertex_tt
#include "dgraphs/progress_utils.hpp" // for elapsed_time
#include "dgraphs/SEXP_cpp_conversion_utils.hpp"
#include "dgraphs/edge_pruning_stats.hpp"

#include <vector>
#include <unordered_set>
#include <set>
#include <memory>
#include <utility>
#include <string>
#include <limits>
#include <unordered_map>
#include <cstdint>
#include <cstddef>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <queue>
#include <numeric>    // for std::iota
#include <algorithm>
#include <cmath>
#include <chrono>
#include <cstdio>
#include <cerrno>
#include <atomic>

#include <ANN/ANN.h>  // ANN library header

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

extern "C" {

    SEXP S_verify_pruning(SEXP s_X,
                          SEXP s_k,
                          SEXP s_max_alt_path_length);

    SEXP S_create_single_iknn_graph(
        SEXP s_X,
        SEXP s_k,
        SEXP s_max_path_edge_ratio_thld,
        SEXP s_path_edge_ratio_percentile,
        SEXP s_threshold_percentile,
        SEXP s_compute_full,
        SEXP s_with_isize_pruning,
        SEXP s_with_edge_pruning_stats,
        SEXP s_knn_cache_path,
        SEXP s_knn_cache_mode,
        SEXP s_knn_metric,
        SEXP s_linf_tol,
        SEXP s_verbose
        );

    SEXP S_create_iknn_graphs(
        SEXP s_X,
        SEXP s_kmin,
        SEXP s_kmax,
        // pruning parameters
        SEXP s_max_path_edge_ratio_thld,
        SEXP s_path_edge_ratio_percentile,
        SEXP s_threshold_percentile,
        // other
        SEXP s_compute_full,
        SEXP s_with_isize_pruning,
        SEXP s_with_edge_pruning_stats,
        SEXP s_n_cores,
        SEXP s_parallel_mode,
        SEXP s_hybrid_batch_size,
        SEXP s_knn_cache_path,
        SEXP s_knn_cache_mode,
        SEXP s_knn_metric,
        SEXP s_linf_tol,
        SEXP s_verbose
        );

    SEXP S_compare_iknn_graph_builders(SEXP s_X,
                                       SEXP s_k,
                                       SEXP s_n_cores,
                                       SEXP s_verbose);
}

iknn_graph_t create_iknn_graph(SEXP s_X, SEXP s_k);

enum class knn_cache_mode_t : int {
    none = 0,
    read = 1,
    write = 2,
    readwrite = 3
};

enum class knn_cache_load_status_t : int {
    loaded = 0,
    not_found = 1,
    invalid = 2,
    io_error = 3
};

struct knn_cache_header_t {
    char magic[8];
    std::uint32_t version;
    std::uint32_t endian_marker;
    std::uint64_t n_points;
    std::uint64_t n_features;
    std::uint64_t k;
    std::uint32_t metric_id;
    double metric_param;
};

knn_search_result_t compute_knn(SEXP RX, int k);
knn_search_result_t compute_knn_by_metric(SEXP RX, int k, int knn_metric_id, double linf_tol);
iknn_graph_t create_iknn_graph_inverted_index(const knn_search_result_t& knn_results,
                                              int k,
                                              bool use_bucket_parallel,
                                              int num_threads);
void print_stage_running(const char* stage_name, bool verbose);
void print_stage_done(const char* stage_name,
                      const std::chrono::steady_clock::time_point& stage_start,
                      bool verbose);
knn_cache_load_status_t read_knn_cache_file(
    const std::string& cache_path,
    int expected_n_points,
    int expected_n_features,
    int required_k,
    int expected_metric_id,
    double expected_metric_param,
    knn_search_result_t& out_knn_results,
    std::string& out_reason);
void write_knn_cache_file_atomic(
    const std::string& cache_path,
    const knn_search_result_t& knn_results,
    int n_features,
    int metric_id,
    double metric_param);
const char* knn_cache_mode_label(knn_cache_mode_t mode);

std::vector<int> union_find(const std::vector<std::vector<int>>& adj_vect);
std::unique_ptr<std::vector<std::vector<std::pair<int, int>>>> prune_long_edges(const std::unique_ptr<std::vector<std::vector<std::pair<int, int>>>>& wgraph, int version);
std::unique_ptr<std::vector<int>> cycle_sizes(const std::vector<std::vector<int>>& graph);
std::vector<std::vector<std::pair<int, int>>> prune_edges_with_alt_paths(const std::vector<std::vector<std::pair<int, int>>>& graph,
                                                                         std::vector<int>& long_edge_isize,
                                                                         std::vector<int>& alt_path_lengths,
                                                                         std::vector<int>& alt_path_total_isize,
                                                                         int max_alt_path_length);


/**
 * Transforms an Intersection-Weighted-Distance k-Nearest Neighbor graph to an Intersection-Weighted k-Nearest Neighbor graph.
 *
 * This function converts a graph representation where each edge contains a distance measurement alongside the intersection size
 * to a representation that only considers the intersection size, discarding the distance information.
 *
 * @param graph The original graph represented as a vector of vectors of iknn_vertex_t, where each iknn_vertex_t contains
 *              the nearest neighbor index, intersection size, and distance.
 * @return A unique pointer to a vector of vectors of pairs, where each pair consists of a nearest neighbor index and an intersection size.
 */
std::unique_ptr<std::vector<std::vector<std::pair<int, int>>>> IWD_to_IW_kNN_graph(const std::vector<std::vector<iknn_vertex_t>>& graph) {
    auto iw_graph = std::make_unique<std::vector<std::vector<std::pair<int, int>>>>(graph.size());

    for (size_t i = 0; i < graph.size(); ++i) {
        for (const auto& vertex : graph[i]) {
            (*iw_graph)[i].emplace_back(vertex.index, vertex.isize);
        }
    }

    return iw_graph;
}

// ------------------------------------------------------------------------------------------
//
// iknn_graph_t members
//
// ------------------------------------------------------------------------------------------

vect_wgraph_t iknn_graph_t::prune_graph(int max_alt_path_length) const {

    // Create result graph with same size as input
    vect_wgraph_t result;
    result.adjacency_list.resize(graph.size());

    // Collect all edges with their distances
    std::set<weighted_edge_t> edges;
    for (size_t i = 0; i < graph.size(); i++) {
        for (const auto& vertex : graph[i]) {
            if (i < vertex.index) {
                edges.insert(
                    {i,
                     vertex.index,
                     vertex.dist,
                     vertex.isize}
                    );
            }
        }
    }

    // Process each edge
    for (const auto& edge : edges) {
        auto alt_path_exists = find_alternative_path(edge.start,
                                                     edge.end,
                                                     edge.isize,
                                                     max_alt_path_length);

        // If no alternative path exists or it's too long, keep the edge
        if (!alt_path_exists) {
            result.adjacency_list[edge.start].push_back({edge.end, edge.dist});
            result.adjacency_list[edge.end].push_back({edge.start, edge.dist});
        }
    }

    return result;
}

bool iknn_graph_t::find_alternative_path(
    int start,
    int end,
    int edge_isize,
    int max_path_length) const {

    size_t n_vertices = graph.size();

    total_isize_cache.assign(n_vertices, -1); // Track total isize
    num_edges_cache.assign(n_vertices, 0);    // Track number of edges in path

    std::queue<int> q;

    // Initialize BFS from source
    q.push(start);  // Should be 'start'
    total_isize_cache[start] = 0;
    num_edges_cache[start] = 0;

    while (!q.empty()) {
        int current = q.front();
        q.pop();

        // Add after popping from queue:
        if (max_path_length > 0 && num_edges_cache[current] >= max_path_length) {
            continue;
        }

        // Check all neighbors of current vertex
        for (const auto& neighbor_vertex : graph[current]) {
            int neighbor = neighbor_vertex.index;
            int neighbor_isize = neighbor_vertex.isize;

            // Skip if intersection size requirement is not met
            if (neighbor_isize <= edge_isize) {
                continue;
            }

            // If we haven't visited this neighbor yet
            if (total_isize_cache[neighbor] == -1) {
                total_isize_cache[neighbor] = total_isize_cache[current] + neighbor_isize;
                num_edges_cache[neighbor] = num_edges_cache[current] + 1;
                q.push(neighbor);

                // If we've reached the target, check if path length is valid
                if (neighbor == end && num_edges_cache[neighbor] >= 2) {
                    return true;
                }
            }
        }
    }
    return false;
}


/**
 * @brief Prints the graph structure to the R console
 *
 * This function prints a detailed representation of the graph including:
 * - Total number of vertices
 * - Total number of edges
 * - Average vertex degree
 * - Complete edge list with intersection sizes and distances
 *
 * For each edge, it prints a tuple (neighbor_index, intersection_size, distance)
 * where:
 * - neighbor_index is the shifted index of the neighboring vertex
 * - intersection_size is the size of the intersection of kNN sets
 * - distance is the minimum indirect distance between vertices
 *
 * @param vertex_index_shift An integer value added to all vertex indices in the output.
 *        Useful for converting between 0-based and 1-based indexing systems.
 * @param name Optional name to label the output (defaults to empty string)
 *
 * @note The function uses Rprintf for output, making it suitable for R package integration
 * @note Edge counts are divided by 2 as each edge is stored twice in the undirected graph
 *
 * @see iknn_vertex_t
 */
void iknn_graph_t::print(size_t vertex_index_shift,
                         const std::string& name) const {
    if (graph.empty()) {
        Rprintf("\nEmpty graph\n");
        return;
    }

    // Count each undirected edge once.
    size_t total_edges = 0;
    for (const auto& vertex_neighbors : graph) {
        total_edges += vertex_neighbors.size();
    }
    total_edges /= 2;  // Each edge is counted twice

    if (!name.empty()) {
        Rprintf("\n\niknn_graph_t: '%s'\n", name.c_str());
    } else {
        Rprintf("\n");
    }

    // Print graph summary
    Rprintf("iknn graph structure:\n");
    Rprintf("Number of vertices: %zu\n", graph.size());
    Rprintf("Number of edges: %zu\n", total_edges);
    Rprintf("Average degree: %.2f\n", graph.empty() ? 0.0 : (2.0 * total_edges / graph.size()));

    // Print detailed edge list
    Rprintf("Edge List:\n");
    for (size_t vertex_id = 0; vertex_id < graph.size(); ++vertex_id) {
        Rprintf("Vertex %zu:\n", vertex_id + vertex_index_shift);
        for (const auto& neighbor : graph[vertex_id]) {
            Rprintf("\t(%zu, %zu, %.3f)\n",
                   neighbor.index + vertex_index_shift,
                   neighbor.isize,
                   neighbor.dist);
        }
    }
}

/**
 * @brief Prints the structure of an integer-indexed k-nearest neighbors graph
 *
 * @details This function prints a detailed representation of an undirected graph where each edge
 * is represented by a vertex index and an intersection size. The output includes:
 * - Graph name (if provided)
 * - Total number of vertices
 * - Total number of edges
 * - Average vertex degree
 * - Complete edge list with intersection sizes
 *
 * For each edge, it prints a tuple (neighbor_index, intersection_size) where:
 * - neighbor_index is the index of the neighboring vertex (adjusted by vertex_index_shift)
 * - intersection_size is the size of the intersection set between the vertex and its neighbor
 *
 * @param graph The graph structure represented as a vector of vectors of pairs,
 *        where each pair contains (vertex_index, intersection_size)
 * @param name Optional name identifier for the graph (defaults to empty string)
 * @param vertex_index_shift Integer value added to all vertex indices in the output
 *        (useful for converting between 0-based and 1-based indexing systems)
 *
 * @note The function uses Rprintf for output, making it suitable for R package integration
 * @note Edge counts are divided by 2 as each edge is stored twice in the undirected graph
 */
void print_iiknn_graph(
    const std::vector<std::vector<std::pair<int, int>>>& graph,
    const std::string& name = "",
    int vertex_index_shift = 0) {

    if (graph.empty()) {
        Rprintf("\nEmpty graph\n");
        return;
    }

    if (!name.empty()) {
        Rprintf("\n\n%s:\n", name.c_str());
    }

    // Calculate total edges
    size_t total_edges = 0;
    for (const auto& vertex_neighbors : graph) {
        total_edges += vertex_neighbors.size();
    }
    total_edges /= 2;  // Each edge is counted twice in undirected graph

    // Print graph summary
    Rprintf("iknn graph structure:\n");
    Rprintf("Number of vertices: %zu\n", graph.size());
    Rprintf("Number of edges: %zu\n", total_edges);
    Rprintf("Average degree: %.2f\n", graph.empty() ? 0.0 : (2.0 * total_edges / graph.size()));

    // Print edge list
    Rprintf("Edge List:\n");
    for (size_t vertex_id = 0; vertex_id < graph.size(); ++vertex_id) {
        Rprintf("Vertex %zu:\n", vertex_id + vertex_index_shift);
        for (const auto& [neighbor_index, isize] : graph[vertex_id]) {
            Rprintf("\t(%d, %d)\n", neighbor_index + vertex_index_shift, isize);
        }
    }
}


// ------------------------------------------------------------------------------------------
//
// print iknn graph
//
// ------------------------------------------------------------------------------------------

/**
 * @brief Prints the structure of an IkNN (Intersection k-Nearest Neighbors) graph with configurable detail levels
 *
 * @details This function displays the graph structure where each vertex maintains a list of its nearest neighbors
 * along with intersection information and distances. The output detail can be controlled via the level parameter.
 *
 * The function supports three levels of detail:
 * - Level 1: Prints only the neighbor indices (basic adjacency list)
 * - Level 2: Prints neighbor indices and distances
 * - Level 3: Prints complete information including neighbor indices, intersection indices, and distances
 *
 * @param graph A vector of vectors where each inner vector contains iknn_vertex_t structures representing
 *              the nearest neighbors of a vertex. Each iknn_vertex_t contains:
 *              - index: Index of the nearest neighbor
 *              - isize: Size of the intersection between N(x) and N(x_j)
 *              - dist: Minimum distance computed as min_k{d(x,x_k) + d(x_k,x_j)}
 * @param level Detail level for printing (default = 3):
 *              - 1: Print only index
 *              - 2: Print index and dist
 *              - 3: Print all components (index, isize, dist)
 *
 * @note Output is formatted using Rprintf for R package compatibility
 *
 * @example
 * auto g = std::make_unique<std::vector<std::vector<iknn_vertex_t>>>;
 * // Print full details
 * print_iknn_graph(*g);
 * // Print only adjacency list
 * print_iknn_graph(*g, 1);
 */
void print_iknn_graph(
    const std::vector<std::vector<iknn_vertex_t>>& graph,
    int level = 3
    ) {
    if (level < 1 || level > 3) {
        Rprintf("Error: level must be 1, 2, or 3\n");
        return;
    }

    if (graph.empty()) {
        Rprintf("Empty graph\n");
        return;
    }

    // Print header
    Rprintf("\nIkNN Graph Structure:\n");
    Rprintf("%s\n", std::string(80, '-').c_str());

    // For each vertex in the graph
    for (size_t vertex_idx = 0; vertex_idx < graph.size(); ++vertex_idx) {
        Rprintf("Vertex %zu neighbors:\n", vertex_idx);

        // If this vertex has no neighbors
        if (graph[vertex_idx].empty()) {
            Rprintf("  No neighbors\n");
            continue;
        }

        // Print column headers based on level
        if (level == 1) {
            Rprintf("%15s\n", "NN Index");
            Rprintf("%s\n", std::string(15, '-').c_str());
        } else if (level == 2) {
            Rprintf("%15s %15s\n", "NN Index", "Distance");
            Rprintf("%s\n", std::string(30, '-').c_str());
        } else { // level == 3
            Rprintf("%15s %15s %15s\n", "NN Index", "I Index", "Distance");
            Rprintf("%s\n", std::string(45, '-').c_str());
        }

        // Print each neighbor's information
        for (const auto& neighbor : graph[vertex_idx]) {
            if (level == 1) {
                Rprintf("%15zu\n", neighbor.index);
            } else if (level == 2) {
                std::ostringstream dist_stream;
                dist_stream << std::fixed << std::setprecision(6) << neighbor.dist;
                Rprintf("%15zu %15s\n",
                       neighbor.index,
                       dist_stream.str().c_str());
            } else { // level == 3
                std::ostringstream dist_stream;
                dist_stream << std::fixed << std::setprecision(6) << neighbor.dist;
                Rprintf("%15zu %15zu %15s\n",
                       neighbor.index,
                       neighbor.isize,
                       dist_stream.str().c_str());
            }
        }

        // Add spacing between vertices
        Rprintf("\n");
    }
}


// ------------------------------------------------------------------------------------------
//
//
//
// ------------------------------------------------------------------------------------------


/**
 * @brief Constructs an Intersection-Weighted-Distance k-Nearest Neighbors (kNN) graph.
 *
 * This function builds an Intersection-Weighted-Distance kNN graph from a given data matrix.
 * For each point, it finds its k nearest neighbors, then constructs edges between points
 * based on the number of common nearest neighbors and computes the distance as the
 * minimum sum of distances through common neighbors.
 *
 * @param RX A numeric matrix (SEXP) representing the data points (rows are points, columns are features).
 * @param Rk An integer (SEXP) representing the number of nearest neighbors to consider.
 * @return A unique pointer to a 2D vector of iknn_vertex_t structures representing the kNN graph.
 *
 * Each iknn_vertex_t structure contains:
 * - `index`: Index of the nearest neighbor.
 * - `isize`: Number of common elements in the kNN sets.
 * - `dist`: Distance metric computed as the minimum sum of distances through common neighbors.
 *
 * @note The function uses the ANN library for kNN computation and R's SEXP structures.
 * Ensure the ANN library is properly linked and included in your project.
 */
iknn_graph_t create_iknn_graph(SEXP RX, SEXP Rk) {

    SEXP s_dim = PROTECT(Rf_getAttrib(RX, R_DimSymbol));
    if (s_dim == R_NilValue || TYPEOF(s_dim) != INTSXP || Rf_length(s_dim) < 1) {
        UNPROTECT(1);
        Rf_error("X must be a matrix with a valid integer 'dim' attribute.");
    }
    const size_t n_points = Rf_asInteger(s_dim);
    UNPROTECT(1);

    size_t k = Rf_asInteger(Rk);

    // Finding kNN's for all points of X
    SEXP knn_res = PROTECT(S_kNN(RX, Rk));
    int *indices = INTEGER(VECTOR_ELT(knn_res, 0));
    double *distances = REAL(VECTOR_ELT(knn_res, 1));

    UNPROTECT(1);

    std::vector<int> nn_i(k);
    std::vector<int> nn_j(k);
    std::vector<int> sorted_nn_i(k);
    std::vector<int> sorted_nn_j(k);

    iknn_graph_t res(n_points);

    size_t n_points_minus_one = n_points - 1;
    std::vector<int> intersection;

    for (size_t pt_i = 0; pt_i < n_points_minus_one; pt_i++) {
        for (size_t j = 0; j < k; j++) {
            nn_i[j] = indices[pt_i + n_points * j];
            sorted_nn_i[j] = nn_i[j];
        }
        std::sort(sorted_nn_i.begin(), sorted_nn_i.end());

        for (size_t pt_j = pt_i + 1; pt_j < n_points; pt_j++) {
            for (size_t j = 0; j < k; j++) {
                nn_j[j] = indices[pt_j + n_points * j];
                sorted_nn_j[j] = nn_j[j];
            }
            std::sort(sorted_nn_j.begin(), sorted_nn_j.end());

            intersection.clear();
            std::set_intersection(sorted_nn_i.begin(), sorted_nn_i.end(),
                                sorted_nn_j.begin(), sorted_nn_j.end(),
                                std::back_inserter(intersection));

            size_t common_count = intersection.size();

            if (common_count > 0) {
                double min_dist = std::numeric_limits<double>::max();
                for (int x_k : intersection) {
                    size_t idx_i = std::find(nn_i.begin(), nn_i.end(), x_k) - nn_i.begin();
                    size_t idx_j = std::find(nn_j.begin(), nn_j.end(), x_k) - nn_j.begin();
                    double dist_i_k = distances[pt_i + n_points * idx_i];
                    double dist_j_k = distances[pt_j + n_points * idx_j];
                    min_dist = std::min(min_dist, dist_i_k + dist_j_k);
                }

                res.graph[pt_i].emplace_back(iknn_vertex_t{pt_j, common_count, min_dist});
                res.graph[pt_j].emplace_back(iknn_vertex_t{pt_i, common_count, min_dist});

            }
        }
    }

    return res;
}

/**
 * @brief Computes and prunes an intersection-weighted k-nearest neighbors graph,
 *        with optional computation of full graph components.
 *
 * @details
 * This function performs the following operations:
 * 1. Constructs an intersection-weighted k-nearest neighbors (IWD-kNN) graph
 * 2. Computes intersection sizes and distances for each edge
 * 3. Applies geometric pruning based on path-to-edge length ratios
 *    If requested, applies quantile-based edge length pruning
 * 4. If compute_full is TRUE:
 *    - Computes all graph components including original graph metrics
 * 5. Always computes:
 *    - Pruned graph adjacency and distance lists
 *    - Basic graph statistics including edge counts and reduction ratios
 *
 * The geometric pruning uses the path-to-edge ratio to determine which edges to remove:
 * - Edges are pruned when an alternative path exists with a better path-to-edge ratio
 * - The pruning threshold and percentile can be configured via parameters
 *
 * @param s_X SEXP object representing the input data matrix. Must be a numeric matrix
 *           (not a data frame) where:
 *           - Rows represent data points (vertices)
 *           - Columns represent features
 *           - Values must be numeric (coercible to REALSXP)
 *
 * @param s_k SEXP object representing k, the number of nearest neighbors to consider
 *           for each point. Must be a positive integer.
 *
 * @param s_max_path_edge_ratio_thld SEXP object (double) Maximum acceptable ratio of
 *        alternative path length to edge length for geometric pruning.
 *        Edges with ratio <= this value will be pruned. If <= 0, this pruning stage is skipped.
 *
 * @param s_path_edge_ratio_percentile SEXP object (double) Percentile threshold (0.0-1.0)
 *        for edge lengths to consider in geometric pruning. Only edges with length
 *        greater than this percentile are considered for pruning.
 *
 * @param s_threshold_percentile SEXP object (double) Percentile threshold for quantile-based
 *        edge length pruning. Valid range is [0.0, 0.5]. Value of 0.0 disables quantile pruning.
 *        When > 0, edges in the top (1 - threshold_percentile) quantile by length are
 *        removed if their removal preserves connectivity. For example, 0.9 removes top 10% of edges.
 *
 * @param s_compute_full SEXP object (logical) controlling computation of optional components:
 *        - TRUE: Compute all graph components and metrics
 *        - FALSE: Compute only pruned graph components and statistics
 *
 * @return SEXP object (a named list) containing:
 *   Always computed components:
 *   - pruned_adj_list: Adjacency lists after edge pruning (1-based indices)
 *   - pruned_weight_list: Distances for edges in pruned graph
 *   - n_edges: Total number of edges in the original graph
 *   - n_edges_in_pruned_graph: Number of edges after pruning
 *   - n_removed_edges: Number of edges removed during pruning
 *   - edge_reduction_ratio: Proportion of edges removed (n_removed_edges / n_edges)
 *
 *   Components computed only when compute_full is TRUE:
 *   - adj_list: List of integer vectors containing adjacency lists (1-based indices)
 *   - isize_list: List of integer vectors with intersection sizes for each edge
 *   - weight_list: List of numeric vectors with distances for each edge
 *   - conn_comps: Integer vector identifying connected components
 *   - connected_components: Integer vector identifying connected components
 *
 * @throws Rf_error If:
 *   - Input matrix cannot be coerced to numeric
 *   - create_iknn_graph returns null
 *   - Pruned graph size doesn't match input size
 *
 * @pre
 *   - s_X must be a valid R matrix object
 *   - s_k must be a valid R integer
 *   - s_compute_full must be a valid R logical value
 *   - Input data should not contain NA/NaN values
 *
 * @post
 *   - All returned indices are 1-based (R convention)
 *   - Graph connectivity is preserved after pruning
 *   - Memory is properly freed (PROTECT/UNPROTECT balanced)
 *   - When compute_full is FALSE, optional components are set to NULL
 *
 * @note
 *   - Time complexity:
 *     * O(V * k * log(V)) for initial graph construction and pruning
 *     * Additional O(V * k) for full component computation when compute_full is TRUE
 *   - Space complexity:
 *     * O(V * k) in all cases (storage for pruned graph)
 *   - All graph operations maintain symmetry of edges
 *
 * @Rf_warning
 *   - Large k values relative to dataset size may impact performance
 *   - The function assumes dense numeric data; sparse matrices require preprocessing
 *   - When compute_full is FALSE, accessing optional components will return NULL
 *
 * @see
 *   - create_iknn_graph for initial graph construction
 *   - iknn_graph_t::prune_graph for graph pruning implementation
 */
SEXP S_create_single_iknn_graph(SEXP s_X,
                                SEXP s_k,
                                // pruning parameters
                                SEXP s_max_path_edge_ratio_thld,
                                SEXP s_path_edge_ratio_percentile,
                                SEXP s_threshold_percentile,
                                // other
                                SEXP s_compute_full,
                                SEXP s_with_isize_pruning,
                                SEXP s_with_edge_pruning_stats,
                                SEXP s_knn_cache_path,
                                SEXP s_knn_cache_mode,
                                SEXP s_knn_metric,
                                SEXP s_linf_tol,
                                SEXP s_verbose) {

    const int max_alt_path_length = 2;
    auto total_start_time = std::chrono::steady_clock::now();

    // --- Validate and extract dimensions
    SEXP s_dim = PROTECT(Rf_getAttrib(s_X, R_DimSymbol));
    if (s_dim == R_NilValue || TYPEOF(s_dim) != INTSXP || Rf_length(s_dim) < 2) {
        UNPROTECT(1);
        Rf_error("X must be a numeric matrix with valid dimensions.");
    }
    const int n_vertices = INTEGER(s_dim)[0];
    const int n_features = INTEGER(s_dim)[1];
    UNPROTECT(1); // s_dim

    if (!Rf_isInteger(s_k)) {
        Rf_error("k must be integer.");
    }
    const int k = Rf_asInteger(s_k);
    if (k <= 0) {
        Rf_error("k must be > 0.");
    }

    // --- Validate and extract pruning parameters
    if (!Rf_isReal(s_max_path_edge_ratio_thld) || !Rf_isReal(s_path_edge_ratio_percentile)) {
        Rf_error("Threshold/percentile must be numeric.");
    }
    const double max_path_edge_ratio_thld   = Rf_asReal(s_max_path_edge_ratio_thld);
    const double path_edge_ratio_percentile = Rf_asReal(s_path_edge_ratio_percentile);

    // --- Validate and extract quantile pruning parameter
    if (!Rf_isReal(s_threshold_percentile)) {
        Rf_error("threshold_percentile must be numeric.");
    }
    const double threshold_percentile = Rf_asReal(s_threshold_percentile);
    if (threshold_percentile < 0.0 || threshold_percentile > 0.5) {
        Rf_error("threshold_percentile must be in [0.0, 0.5]. Got %.3f", threshold_percentile);
    }

    if (!Rf_isLogical(s_compute_full) ||
        !Rf_isLogical(s_with_isize_pruning) ||
        !Rf_isLogical(s_with_edge_pruning_stats) ||
        !Rf_isLogical(s_verbose)) {
        Rf_error("compute_full, with_isize_pruning, with_edge_pruning_stats, and verbose must be logical.");
    }
    const bool compute_full             = (Rf_asLogical(s_compute_full) == TRUE);
    const bool with_isize_pruning       = (Rf_asLogical(s_with_isize_pruning) == TRUE);
    const bool with_edge_pruning_stats  = (Rf_asLogical(s_with_edge_pruning_stats) == TRUE);
    const bool verbose                  = (Rf_asLogical(s_verbose) == TRUE);

    if (!Rf_isInteger(s_knn_metric) || Rf_length(s_knn_metric) < 1) {
        Rf_error("knn.metric must be a length-1 integer.");
    }
    const int knn_metric_id = INTEGER(s_knn_metric)[0];
    if (knn_metric_id == NA_INTEGER || knn_metric_id < 0 || knn_metric_id > 1) {
        Rf_error("knn.metric must be in {0,1}.");
    }
    if (!Rf_isReal(s_linf_tol) || Rf_length(s_linf_tol) < 1) {
        Rf_error("linf.tol must be a length-1 numeric value.");
    }
    const double linf_tol = REAL(s_linf_tol)[0];
    if (!std::isfinite(linf_tol) || linf_tol <= 0.0) {
        Rf_error("linf.tol must be a positive finite number.");
    }

    if (!Rf_isInteger(s_knn_cache_mode) || Rf_length(s_knn_cache_mode) < 1) {
        Rf_error("knn.cache.mode must be a length-1 integer.");
    }
    const int knn_cache_mode_raw = INTEGER(s_knn_cache_mode)[0];
    if (knn_cache_mode_raw == NA_INTEGER ||
        knn_cache_mode_raw < static_cast<int>(knn_cache_mode_t::none) ||
        knn_cache_mode_raw > static_cast<int>(knn_cache_mode_t::readwrite)) {
        Rf_error("knn.cache.mode must be in {0,1,2,3}.");
    }
    const knn_cache_mode_t knn_cache_mode = static_cast<knn_cache_mode_t>(knn_cache_mode_raw);

    std::string knn_cache_path;
    if (!Rf_isNull(s_knn_cache_path)) {
        if (TYPEOF(s_knn_cache_path) != STRSXP ||
            Rf_length(s_knn_cache_path) != 1 ||
            STRING_ELT(s_knn_cache_path, 0) == NA_STRING) {
            Rf_error("knn.cache.path must be NULL or a non-empty character scalar.");
        }
        const char* path_cstr = CHAR(STRING_ELT(s_knn_cache_path, 0));
        if (path_cstr == nullptr || path_cstr[0] == '\0') {
            Rf_error("knn.cache.path must be NULL or a non-empty character scalar.");
        }
        knn_cache_path.assign(path_cstr);
    }
    if (knn_cache_mode != knn_cache_mode_t::none && knn_cache_path.empty()) {
        Rf_error("knn.cache.path must be provided when knn.cache.mode is not 'none'.");
    }

    if (verbose) Rprintf("Running single-threaded.\n");

    auto stage_start = std::chrono::steady_clock::now();
    print_stage_running("compute_knn", verbose);
    knn_search_result_t knn_results(static_cast<size_t>(n_vertices), 0);
    bool knn_cache_hit = false;
    bool knn_cache_written = false;

    if (knn_cache_mode == knn_cache_mode_t::read || knn_cache_mode == knn_cache_mode_t::readwrite) {
        std::string cache_reason;
        const knn_cache_load_status_t cache_status = read_knn_cache_file(
            knn_cache_path,
            n_vertices,
            n_features,
            k,
            knn_metric_id,
            (knn_metric_id == 1 ? linf_tol : 0.0),
            knn_results,
            cache_reason
        );
        if (cache_status == knn_cache_load_status_t::loaded) {
            knn_cache_hit = true;
        } else if (cache_status == knn_cache_load_status_t::not_found &&
                   knn_cache_mode == knn_cache_mode_t::readwrite) {
            knn_cache_hit = false;
        } else {
            Rf_error("Failed to read kNN cache '%s': %s", knn_cache_path.c_str(), cache_reason.c_str());
        }
    }

    if (!knn_cache_hit) {
        knn_results = compute_knn_by_metric(s_X, k, knn_metric_id, linf_tol);
        if (knn_cache_mode == knn_cache_mode_t::write || knn_cache_mode == knn_cache_mode_t::readwrite) {
            write_knn_cache_file_atomic(knn_cache_path,
                                        knn_results,
                                        n_features,
                                        knn_metric_id,
                                        (knn_metric_id == 1 ? linf_tol : 0.0));
            knn_cache_written = true;
        }
    }
    print_stage_done("compute_knn", stage_start, verbose);
    if (verbose && knn_cache_mode != knn_cache_mode_t::none) {
        if (knn_cache_hit) {
            Rprintf("[compute_knn] cache hit (%s, cached_k=%zu)\n",
                    knn_cache_path.c_str(),
                    knn_results.k);
        } else if (knn_cache_written) {
            Rprintf("[compute_knn] cache saved (%s, k=%d)\n",
                    knn_cache_path.c_str(),
                    k);
        } else {
            Rprintf("[compute_knn] cache mode: %s\n", knn_cache_mode_label(knn_cache_mode));
        }
    }

    stage_start = std::chrono::steady_clock::now();
    print_stage_running("graph_build (inverted index)", verbose);
    auto iknn_graph = create_iknn_graph_inverted_index(knn_results,
                                                       k,
                                                       false,
                                                       1);
    print_stage_done("graph_build (inverted index)", stage_start, verbose);

    // ---- Count total edges (undirected stored twice)
    int n_edges = 0;
    for (const auto& vertex_edges : iknn_graph.graph) {
        if (vertex_edges.size() > static_cast<size_t>(INT_MAX)) {
            Rf_error("Edge list too large for int lengths.");
        }
        n_edges += static_cast<int>(vertex_edges.size());
    }
    n_edges /= 2;

    // ---- Build plain C++ adjacency/weight lists for original graph
    std::vector<std::vector<int>>    adj_vect(static_cast<size_t>(n_vertices));
    std::vector<std::vector<double>> dist_vect(static_cast<size_t>(n_vertices));
    for (size_t i = 0; i < iknn_graph.graph.size(); ++i) {
        const auto& nbrs = iknn_graph.graph[i];
        adj_vect[i].reserve(nbrs.size());
        dist_vect[i].reserve(nbrs.size());
        for (const auto& nn : nbrs) {
            adj_vect[i].push_back(static_cast<int>(nn.index));  // 0-based here
            dist_vect[i].push_back(nn.dist);
        }
    }

    // ---- Stage 1/2: geometric + optional quantile pruning
    const bool do_geometric_prune = (max_path_edge_ratio_thld > 1.0);
    if (do_geometric_prune) {
        stage_start = std::chrono::steady_clock::now();
        print_stage_running("geometric_prune", verbose);
    }
    size_t n_edges_after_geometric_sz = 0;
    set_wgraph_t temp_graph_for_pruning(iknn_graph);
    set_wgraph_t pruned_graph = temp_graph_for_pruning;

    if (do_geometric_prune) {
        pruned_graph = pruned_graph.prune_edges_geometrically(
            max_path_edge_ratio_thld,
            path_edge_ratio_percentile,
            verbose
        );
        print_stage_done("geometric_prune", stage_start, verbose);
    } else if (verbose) {
        Rprintf("[geometric_prune] skipped (max.path.edge.ratio.deviation.thld=0)\n");
    }

    for (const auto& nbrs : pruned_graph.adjacency_list) {
        n_edges_after_geometric_sz += nbrs.size();
    }
    n_edges_after_geometric_sz /= 2;

    size_t n_edges_in_pruned_graph_sz = n_edges_after_geometric_sz;
    if (threshold_percentile > 0.0) {
        pruned_graph = pruned_graph.prune_long_edges(threshold_percentile);
        n_edges_in_pruned_graph_sz = 0;
        for (const auto& nbrs : pruned_graph.adjacency_list) {
            n_edges_in_pruned_graph_sz += nbrs.size();
        }
        n_edges_in_pruned_graph_sz /= 2;
    }
    // ---- Stage 3: optional intersection-size pruning
    vect_wgraph_t isize_pruned_graph;
    size_t n_edges_isize_pruned_sz = 0;
    if (with_isize_pruning) {
        stage_start = std::chrono::steady_clock::now();
        print_stage_running("isize_prune", verbose);
        isize_pruned_graph = iknn_graph.prune_graph(max_alt_path_length);
        for (const auto& nbrs : isize_pruned_graph.adjacency_list) {
            n_edges_isize_pruned_sz += nbrs.size();
        }
        n_edges_isize_pruned_sz /= 2;
        print_stage_done("isize_prune", stage_start, verbose);
    } else if (verbose) {
        Rprintf("[isize_prune] skipped (with.isize.pruning=FALSE)\n");
    }

    edge_pruning_stats_t edge_pruning_stats;
    if (with_edge_pruning_stats) {
        stage_start = std::chrono::steady_clock::now();
        print_stage_running("edge_pruning_stats", verbose);
        edge_pruning_stats = pruned_graph.compute_edge_pruning_stats(path_edge_ratio_percentile);
        print_stage_done("edge_pruning_stats", stage_start, verbose);
    } else if (verbose) {
        Rprintf("[edge_pruning_stats] skipped (with.edge.pruning.stats=FALSE)\n");
    }

    const int n_edges_in_pruned_graph =
        (n_edges_in_pruned_graph_sz > static_cast<size_t>(INT_MAX))
        ? INT_MAX
        : static_cast<int>(n_edges_in_pruned_graph_sz);

    const int removed = n_edges - n_edges_in_pruned_graph;
    const double ratio = (n_edges > 0) ? (static_cast<double>(removed) / static_cast<double>(n_edges)) : 0.0;

    double n_edges_isize_d = NA_REAL;
    double double_removed_d = NA_REAL;
    double double_red_ratio = NA_REAL;
    if (with_isize_pruning) {
        n_edges_isize_d = static_cast<double>(n_edges_isize_pruned_sz);
        double_removed_d = static_cast<double>(n_edges_in_pruned_graph_sz - n_edges_isize_pruned_sz);
        double_red_ratio = (n_edges_in_pruned_graph_sz > 0)
            ? (double_removed_d / static_cast<double>(n_edges_in_pruned_graph_sz))
            : 0.0;
    }

    // -------- Result list
    SEXP r_result = PROTECT(Rf_allocVector(VECSXP, 16));
    {
        SEXP names = PROTECT(Rf_allocVector(STRSXP, 16));
        SET_STRING_ELT(names, 0,  Rf_mkChar("adj_list"));
        SET_STRING_ELT(names, 1,  Rf_mkChar("isize_list"));
        SET_STRING_ELT(names, 2,  Rf_mkChar("weight_list"));
        SET_STRING_ELT(names, 3,  Rf_mkChar("conn_comps"));
        SET_STRING_ELT(names, 4,  Rf_mkChar("pruned_adj_list"));
        SET_STRING_ELT(names, 5,  Rf_mkChar("pruned_weight_list"));
        SET_STRING_ELT(names, 6,  Rf_mkChar("n_edges"));
        SET_STRING_ELT(names, 7,  Rf_mkChar("n_edges_in_pruned_graph"));
        SET_STRING_ELT(names, 8,  Rf_mkChar("n_removed_edges"));
        SET_STRING_ELT(names, 9,  Rf_mkChar("edge_reduction_ratio"));
        SET_STRING_ELT(names, 10, Rf_mkChar("isize_pruned_adj_list"));
        SET_STRING_ELT(names, 11, Rf_mkChar("isize_pruned_weight_list"));
        SET_STRING_ELT(names, 12, Rf_mkChar("n_edges_in_isize_pruned_graph"));
        SET_STRING_ELT(names, 13, Rf_mkChar("n_removed_edges_in_double_pruning"));
        SET_STRING_ELT(names, 14, Rf_mkChar("double_edge_reduction_ratio"));
        SET_STRING_ELT(names, 15, Rf_mkChar("edge_pruning_stats"));
        Rf_setAttrib(r_result, R_NamesSymbol, names);
        UNPROTECT(1); // names
    }

    // ---- geometric pruned lists
    {
        SEXP pruned_adj_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));
        SEXP pruned_weight_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));

        for (int i = 0; i < n_vertices; ++i) {
            const auto& edges = pruned_graph.adjacency_list[static_cast<size_t>(i)];

            SEXP RA = PROTECT(Rf_allocVector(INTSXP, static_cast<R_len_t>(edges.size())));
            int* A = INTEGER(RA);
            for (const auto& e : edges) {
                *A++ = static_cast<int>(e.vertex) + 1;
            }
            SET_VECTOR_ELT(pruned_adj_list, i, RA);
            UNPROTECT(1); // RA

            SEXP RD = PROTECT(Rf_allocVector(REALSXP, static_cast<R_len_t>(edges.size())));
            double* D = REAL(RD);
            for (const auto& e : edges) {
                *D++ = e.weight;
            }
            SET_VECTOR_ELT(pruned_weight_list, i, RD);
            UNPROTECT(1); // RD
        }

        SET_VECTOR_ELT(r_result, 4, pruned_adj_list);
        SET_VECTOR_ELT(r_result, 5, pruned_weight_list);
        UNPROTECT(2); // pruned_adj_list, pruned_weight_list
    }

    // ---- scalar stats
    {
        SEXP s0 = PROTECT(Rf_ScalarReal(static_cast<double>(n_edges)));
        SET_VECTOR_ELT(r_result, 6, s0);
        UNPROTECT(1);

        SEXP s1 = PROTECT(Rf_ScalarReal(static_cast<double>(n_edges_in_pruned_graph)));
        SET_VECTOR_ELT(r_result, 7, s1);
        UNPROTECT(1);

        SEXP s2 = PROTECT(Rf_ScalarReal(static_cast<double>(removed)));
        SET_VECTOR_ELT(r_result, 8, s2);
        UNPROTECT(1);

        SEXP s3 = PROTECT(Rf_ScalarReal(ratio));
        SET_VECTOR_ELT(r_result, 9, s3);
        UNPROTECT(1);

        SEXP s4 = PROTECT(Rf_ScalarReal(n_edges_isize_d));
        SET_VECTOR_ELT(r_result, 12, s4);
        UNPROTECT(1);

        SEXP s5 = PROTECT(Rf_ScalarReal(double_removed_d));
        SET_VECTOR_ELT(r_result, 13, s5);
        UNPROTECT(1);

        SEXP s6 = PROTECT(Rf_ScalarReal(double_red_ratio));
        SET_VECTOR_ELT(r_result, 14, s6);
        UNPROTECT(1);
    }

    if (compute_full && with_isize_pruning) {
        SEXP isize_adj_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));
        SEXP isize_weight_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));

        for (int i = 0; i < n_vertices; ++i) {
            const auto& edges = isize_pruned_graph.adjacency_list[static_cast<size_t>(i)];

            SEXP RA = PROTECT(Rf_allocVector(INTSXP, static_cast<R_len_t>(edges.size())));
            int* A = INTEGER(RA);
            for (const auto& e : edges) {
                *A++ = static_cast<int>(e.vertex) + 1;
            }
            SET_VECTOR_ELT(isize_adj_list, i, RA);
            UNPROTECT(1);

            SEXP RD = PROTECT(Rf_allocVector(REALSXP, static_cast<R_len_t>(edges.size())));
            double* D = REAL(RD);
            for (const auto& e : edges) {
                *D++ = e.weight;
            }
            SET_VECTOR_ELT(isize_weight_list, i, RD);
            UNPROTECT(1);
        }

        SET_VECTOR_ELT(r_result, 10, isize_adj_list);
        SET_VECTOR_ELT(r_result, 11, isize_weight_list);
        UNPROTECT(2); // isize_adj_list, isize_weight_list
    } else {
        SET_VECTOR_ELT(r_result, 10, R_NilValue);
        SET_VECTOR_ELT(r_result, 11, R_NilValue);
    }

    if (with_edge_pruning_stats) {
        const size_t nrows_sz = edge_pruning_stats.stats.size();
        if (nrows_sz > static_cast<size_t>(INT_MAX)) {
            Rf_error("Too many rows in edge pruning stats.");
        }
        SEXP edge_stats_matrix = PROTECT(Rf_allocMatrix(REALSXP, static_cast<R_len_t>(nrows_sz), 2));
        double* data = REAL(edge_stats_matrix);
        for (size_t i = 0; i < nrows_sz; ++i) {
            data[i] = edge_pruning_stats.stats[i].edge_length;
            data[i + nrows_sz] = edge_pruning_stats.stats[i].length_ratio;
        }
        SEXP dimnames = PROTECT(Rf_allocVector(VECSXP, 2));
        SET_VECTOR_ELT(dimnames, 0, R_NilValue);
        SEXP colnames = PROTECT(Rf_allocVector(STRSXP, 2));
        SET_STRING_ELT(colnames, 0, Rf_mkChar("edge_length"));
        SET_STRING_ELT(colnames, 1, Rf_mkChar("length_ratio"));
        SET_VECTOR_ELT(dimnames, 1, colnames);
        Rf_setAttrib(edge_stats_matrix, R_DimNamesSymbol, dimnames);
        SET_VECTOR_ELT(r_result, 15, edge_stats_matrix);
        UNPROTECT(3); // edge_stats_matrix, dimnames, colnames
    } else {
        SET_VECTOR_ELT(r_result, 15, R_NilValue);
    }

    // ---- optional full graph payload
    if (compute_full) {
        SEXP adj_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));
        SEXP intersection_size_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));
        SEXP weight_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));

        for (int i = 0; i < n_vertices; ++i) {
            // adjacency
            {
                const auto m = static_cast<R_len_t>(adj_vect[static_cast<size_t>(i)].size());
                SEXP RA = PROTECT(Rf_allocVector(INTSXP, m));
                int* A = INTEGER(RA);
                for (int idx = 0; idx < m; ++idx) {
                    A[idx] = adj_vect[static_cast<size_t>(i)][static_cast<size_t>(idx)] + 1;
                }
                SET_VECTOR_ELT(adj_list, i, RA);
                UNPROTECT(1);
            }
            // intersection sizes
            {
                const auto m = static_cast<R_len_t>(iknn_graph.graph[static_cast<size_t>(i)].size());
                SEXP RW = PROTECT(Rf_allocVector(INTSXP, m));
                int* W = INTEGER(RW);
                for (int idx = 0; idx < m; ++idx) {
                    W[idx] = static_cast<int>(
                        iknn_graph.graph[static_cast<size_t>(i)][static_cast<size_t>(idx)].isize
                    );
                }
                SET_VECTOR_ELT(intersection_size_list, i, RW);
                UNPROTECT(1);
            }
            // distances
            {
                const auto m = static_cast<R_len_t>(dist_vect[static_cast<size_t>(i)].size());
                SEXP RD = PROTECT(Rf_allocVector(REALSXP, m));
                double* D = REAL(RD);
                for (int idx = 0; idx < m; ++idx) {
                    D[idx] = dist_vect[static_cast<size_t>(i)][static_cast<size_t>(idx)];
                }
                SET_VECTOR_ELT(weight_list, i, RD);
                UNPROTECT(1);
            }
        }

        std::vector<int> conn_comps = union_find(adj_vect);
        if (conn_comps.size() > static_cast<size_t>(INT_MAX)) {
            UNPROTECT(3); // adj_list, intersection_size_list, weight_list
            Rf_error("Connected component vector too large for int lengths.");
        }
        SEXP s_conn_comps = PROTECT(Rf_allocVector(INTSXP, static_cast<R_len_t>(conn_comps.size())));
        std::copy(conn_comps.begin(), conn_comps.end(), INTEGER(s_conn_comps));

        SET_VECTOR_ELT(r_result, 0, adj_list);
        SET_VECTOR_ELT(r_result, 1, intersection_size_list);
        SET_VECTOR_ELT(r_result, 2, weight_list);
        SET_VECTOR_ELT(r_result, 3, s_conn_comps);
        UNPROTECT(4); // adj_list, intersection_size_list, weight_list, s_conn_comps
    } else {
        SET_VECTOR_ELT(r_result, 0, R_NilValue);
        SET_VECTOR_ELT(r_result, 1, R_NilValue);
        SET_VECTOR_ELT(r_result, 2, R_NilValue);
        SET_VECTOR_ELT(r_result, 3, R_NilValue);
    }

    if (verbose) {
        elapsed_time(total_start_time, "Total elapsed time", true);
    }

    UNPROTECT(1); // r_result
    return r_result;
}

// -----------------------------------------------------------------------------------------------
//
//  Implementation of S_create_iknn_graphs() with edge birth/death time statistics
//
// -----------------------------------------------------------------------------------------------

// Helper function to convert pruned graph to R representation
SEXP create_R_graph_representation(
    const std::vector<std::vector<std::pair<int, int>>>& pruned_graph,
    const std::vector<std::vector<iknn_vertex_t>>& original_graph) {

    // Create return list
    SEXP result = PROTECT(Rf_allocVector(VECSXP, 3));

    // Set names
    {
        SEXP names = PROTECT(Rf_allocVector(STRSXP, 3));
        SET_STRING_ELT(names, 0, Rf_mkChar("pruned_adj_list"));
        SET_STRING_ELT(names, 1, Rf_mkChar("pruned_weight_list"));
        SET_STRING_ELT(names, 2, Rf_mkChar("pruned_isize_list"));
        Rf_setAttrib(result, R_NamesSymbol, names);
        UNPROTECT(1);
    }

    int n_vertices = pruned_graph.size();

    // Create lists for adjacency, distances, and intersection sizes
    SEXP pruned_adj_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));
    SEXP pruned_weight_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));
    SEXP pruned_isize_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));

    for (int i = 0; i < n_vertices; i++) {
        size_t n_neighbors = pruned_graph[i].size();

        // Create vectors for this vertex
        SEXP adj = PROTECT(Rf_allocVector(INTSXP, n_neighbors));
        SEXP dist = PROTECT(Rf_allocVector(REALSXP, n_neighbors));
        SEXP isize = PROTECT(Rf_allocVector(INTSXP, n_neighbors));

        // Fill vectors
        for (size_t j = 0; j < n_neighbors; j++) {
            INTEGER(adj)[j] = pruned_graph[i][j].first + 1;  // 1-based indexing
            INTEGER(isize)[j] = pruned_graph[i][j].second;

            // Find corresponding distance in original graph
            double distance = 0.0;
            for (const auto& vertex : original_graph[i]) {
                if (vertex.index == (size_t)pruned_graph[i][j].first) {
                    distance = vertex.dist;
                    break;
                }
            }
            REAL(dist)[j] = distance;
        }

        SET_VECTOR_ELT(pruned_adj_list, i, adj);
        SET_VECTOR_ELT(pruned_weight_list, i, dist);
        SET_VECTOR_ELT(pruned_isize_list, i, isize);

        UNPROTECT(3);
    }
    SET_VECTOR_ELT(result, 0, pruned_adj_list);
    SET_VECTOR_ELT(result, 1, pruned_weight_list);
    SET_VECTOR_ELT(result, 2, pruned_isize_list);

    UNPROTECT(4); // result, pruned_adj_list, pruned_weight_list, pruned_isize_list
    return result;
}

// Helper function to convert graph to pruned form
std::vector<std::vector<std::pair<int, int>>> prune_graph(
    const std::vector<std::vector<iknn_vertex_t>>& graph,
    int max_alt_path_length,
    std::vector<int>& long_edge_isize,
    std::vector<int>& alt_path_lengths,
    std::vector<int>& alt_path_total_isize) {

    // Convert to IW_kNN_graph format
    auto IW_graph = std::make_unique<std::vector<std::vector<std::pair<int, int>>>>(graph.size());
    for (size_t i = 0; i < graph.size(); i++) {
        for (const auto& vertex : graph[i]) {
            (*IW_graph)[i].push_back({vertex.index, vertex.isize});
        }
    }

    // Prune the graph
    return prune_edges_with_alt_paths(*IW_graph,
                                      long_edge_isize,
                                      alt_path_lengths,
                                      alt_path_total_isize,
                                      max_alt_path_length);
}


knn_search_result_t compute_knn_by_metric(SEXP RX, int k, int knn_metric_id, double linf_tol) {
    if (knn_metric_id == 0) {
        return compute_knn(RX, k);
    }
    if (knn_metric_id == 1) {
        return compute_linf_simplex_knn(RX, k, linf_tol);
    }
    Rf_error("Unsupported kNN metric id: %d.", knn_metric_id);
}

struct bucket_member_t {
    int point;
    double dist_to_common_neighbor;
};

struct edge_accumulator_t {
    int isize;
    double min_dist;
};

using edge_accumulator_map_t = std::unordered_map<std::uint64_t, edge_accumulator_t>;

static inline std::uint64_t pack_edge_key(size_t u, size_t v) {
    return (static_cast<std::uint64_t>(u) << 32U) | static_cast<std::uint64_t>(v);
}

static inline std::pair<size_t, size_t> unpack_edge_key(std::uint64_t key) {
    return {
        static_cast<size_t>(key >> 32U),
        static_cast<size_t>(key & 0xFFFFFFFFULL)
    };
}

static inline void accumulate_edge(edge_accumulator_map_t& edge_map,
                                   size_t u,
                                   size_t v,
                                   double cand_dist) {
    const std::uint64_t key = pack_edge_key(u, v);
    auto it = edge_map.find(key);
    if (it == edge_map.end()) {
        edge_map.emplace(key, edge_accumulator_t{1, cand_dist});
    } else {
        it->second.isize += 1;
        if (cand_dist < it->second.min_dist) {
            it->second.min_dist = cand_dist;
        }
    }
}

static std::vector<std::vector<bucket_member_t>> build_inverted_knn_index(
    const knn_search_result_t& knn_results,
    int k,
    size_t* pair_work_out) {

    const size_t n_points = knn_results.n_points;
    std::vector<size_t> bucket_counts(n_points, 0);

    for (size_t i = 0; i < n_points; ++i) {
        for (int j = 0; j < k; ++j) {
            const int neighbor = knn_results.indices[i][static_cast<size_t>(j)];
            if (neighbor >= 0 && static_cast<size_t>(neighbor) < n_points) {
                bucket_counts[static_cast<size_t>(neighbor)] += 1;
            }
        }
    }

    std::vector<std::vector<bucket_member_t>> buckets(n_points);
    for (size_t i = 0; i < n_points; ++i) {
        buckets[i].reserve(bucket_counts[i]);
    }

    for (size_t i = 0; i < n_points; ++i) {
        for (int j = 0; j < k; ++j) {
            const int neighbor = knn_results.indices[i][static_cast<size_t>(j)];
            if (neighbor < 0 || static_cast<size_t>(neighbor) >= n_points) {
                continue;
            }
            buckets[static_cast<size_t>(neighbor)].push_back({
                static_cast<int>(i),
                knn_results.distances[i][static_cast<size_t>(j)]
            });
        }
    }

    if (pair_work_out != nullptr) {
        size_t pair_work = 0;
        for (const auto& bucket : buckets) {
            const size_t m = bucket.size();
            if (m > 1) {
                pair_work += (m * (m - 1)) / 2;
            }
        }
        *pair_work_out = pair_work;
    }

    return buckets;
}

static inline void process_bucket(const std::vector<bucket_member_t>& bucket,
                                  edge_accumulator_map_t& edge_map) {
    const size_t m = bucket.size();
    for (size_t a = 0; a < m; ++a) {
        const int pt_i = bucket[a].point;
        const double dist_i = bucket[a].dist_to_common_neighbor;

        for (size_t b = a + 1; b < m; ++b) {
            const int pt_j = bucket[b].point;
            if (pt_i == pt_j) {
                continue;
            }
            const size_t u = (pt_i < pt_j) ? static_cast<size_t>(pt_i) : static_cast<size_t>(pt_j);
            const size_t v = (pt_i < pt_j) ? static_cast<size_t>(pt_j) : static_cast<size_t>(pt_i);
            accumulate_edge(edge_map, u, v, dist_i + bucket[b].dist_to_common_neighbor);
        }
    }
}

iknn_graph_t create_iknn_graph_inverted_index(const knn_search_result_t& knn_results,
                                              int k,
                                              bool use_bucket_parallel,
    int num_threads) {
    const size_t n_points = knn_results.n_points;
    auto buckets = build_inverted_knn_index(knn_results, k, nullptr);

    edge_accumulator_map_t edge_map;

    (void)use_bucket_parallel;
    (void)num_threads;
    for (const auto& bucket : buckets) {
        process_bucket(bucket, edge_map);
    }

    iknn_graph_t res(n_points);
    std::vector<size_t> degree_counts(n_points, 0);
    for (const auto& kv : edge_map) {
        const auto [u, v] = unpack_edge_key(kv.first);
        degree_counts[u] += 1;
        degree_counts[v] += 1;
    }
    for (size_t i = 0; i < n_points; ++i) {
        res.graph[i].reserve(degree_counts[i]);
    }

    for (const auto& kv : edge_map) {
        const auto [u, v] = unpack_edge_key(kv.first);
        const edge_accumulator_t& acc = kv.second;
        res.graph[u].emplace_back(iknn_vertex_t{v, static_cast<size_t>(acc.isize), acc.min_dist});
        res.graph[v].emplace_back(iknn_vertex_t{u, static_cast<size_t>(acc.isize), acc.min_dist});
    }

    for (auto& neighbors : res.graph) {
        std::sort(neighbors.begin(), neighbors.end(),
                  [](const iknn_vertex_t& a, const iknn_vertex_t& b) {
                      return a.index < b.index;
                  });
    }

    return res;
}

iknn_graph_t create_iknn_graph_from_knn_result(const knn_result_t& knn_result,
                                               int k,
                                               bool use_bucket_parallel,
                                               int num_threads) {
    if (k <= 0) {
        Rf_error("create_iknn_graph_from_knn_result: k must be > 0.");
    }
    if (knn_result.n <= 0 || knn_result.k <= 0) {
        Rf_error("create_iknn_graph_from_knn_result: invalid knn_result dimensions.");
    }
    if (k > knn_result.k) {
        Rf_error("create_iknn_graph_from_knn_result: requested k=%d exceeds knn_result.k=%d.",
                 k,
                 knn_result.k);
    }

    const size_t n_points = static_cast<size_t>(knn_result.n);
    const size_t stride = static_cast<size_t>(knn_result.k);
    const size_t required = n_points * stride;
    if (knn_result.indices.size() < required || knn_result.distances.size() < required) {
        Rf_error("create_iknn_graph_from_knn_result: knn_result buffers are smaller than n*k.");
    }

    knn_search_result_t converted(n_points, static_cast<size_t>(k));
    const size_t k_used = static_cast<size_t>(k);

    for (size_t i = 0; i < n_points; ++i) {
        const size_t row_offset = i * stride;
        for (size_t j = 0; j < k_used; ++j) {
            const size_t offset = row_offset + j;
            converted.indices[i][j] = knn_result.indices[offset];
            converted.distances[i][j] = knn_result.distances[offset];
        }
    }

    return create_iknn_graph_inverted_index(
        converted,
        k,
        use_bucket_parallel,
        num_threads
    );
}

void print_stage_running(const char* stage_name, bool verbose) {
    if (!verbose) {
        return;
    }
    Rprintf("[%s] running...", stage_name);
    R_FlushConsole();
}

void print_stage_done(const char* stage_name,
                      const std::chrono::steady_clock::time_point& stage_start,
                      bool verbose) {
    if (!verbose) {
        return;
    }
    const double elapsed_seconds = std::chrono::duration<double>(
        std::chrono::steady_clock::now() - stage_start
    ).count();
    Rprintf("\r[%s] %.3fs\n", stage_name, elapsed_seconds);
    R_FlushConsole();
}

namespace {

constexpr char k_knn_cache_magic[8] = {'G', 'F', 'L', 'K', 'N', 'N', '0', '1'};
constexpr std::uint32_t k_knn_cache_version = 2U;
constexpr std::uint32_t k_knn_cache_endian_marker = 0x01020304U;
std::atomic<std::uint64_t> g_knn_cache_tmp_counter(0U);

template <typename T>
bool write_binary(std::ofstream& out, const T& value) {
    out.write(reinterpret_cast<const char*>(&value), sizeof(T));
    return static_cast<bool>(out);
}

std::string make_knn_cache_tmp_path(const std::string& cache_path) {
    const std::uint64_t ts = static_cast<std::uint64_t>(
        std::chrono::steady_clock::now().time_since_epoch().count()
    );
    const std::uint64_t counter = g_knn_cache_tmp_counter.fetch_add(1U, std::memory_order_relaxed);
    std::ostringstream oss;
    oss << cache_path << ".tmp." << ts << "." << counter;
    return oss.str();
}

} // namespace

const char* knn_cache_mode_label(knn_cache_mode_t mode) {
    switch (mode) {
        case knn_cache_mode_t::read:
            return "read";
        case knn_cache_mode_t::write:
            return "write";
        case knn_cache_mode_t::readwrite:
            return "readwrite";
        case knn_cache_mode_t::none:
        default:
            return "none";
    }
}

knn_cache_load_status_t read_knn_cache_file(
    const std::string& cache_path,
    int expected_n_points,
    int expected_n_features,
    int required_k,
    int expected_metric_id,
    double expected_metric_param,
    knn_search_result_t& out_knn_results,
    std::string& out_reason) {

    errno = 0;
    std::ifstream in(cache_path, std::ios::binary);
    if (!in.is_open()) {
        const int open_errno = errno;
        if (open_errno == ENOENT) {
            out_reason = "cache file does not exist";
            return knn_cache_load_status_t::not_found;
        }
        out_reason = std::string("cannot open cache file: ") + std::strerror(open_errno);
        return knn_cache_load_status_t::io_error;
    }

    knn_cache_header_t header{};
    if (!in.read(reinterpret_cast<char*>(&header), sizeof(knn_cache_header_t))) {
        out_reason = "cache file is truncated (header)";
        return knn_cache_load_status_t::invalid;
    }

    if (std::memcmp(header.magic, k_knn_cache_magic, sizeof(k_knn_cache_magic)) != 0) {
        out_reason = "cache magic mismatch";
        return knn_cache_load_status_t::invalid;
    }
    if (header.version != k_knn_cache_version) {
        out_reason = "cache version mismatch";
        return knn_cache_load_status_t::invalid;
    }
    if (header.endian_marker != k_knn_cache_endian_marker) {
        out_reason = "cache endianness mismatch";
        return knn_cache_load_status_t::invalid;
    }
    if (header.n_points != static_cast<std::uint64_t>(expected_n_points)) {
        out_reason = "cache nrow mismatch";
        return knn_cache_load_status_t::invalid;
    }
    if (header.n_features != static_cast<std::uint64_t>(expected_n_features)) {
        out_reason = "cache ncol mismatch";
        return knn_cache_load_status_t::invalid;
    }
    if (header.k < static_cast<std::uint64_t>(required_k)) {
        out_reason = "cache k is smaller than required k";
        return knn_cache_load_status_t::invalid;
    }
    if (header.k > static_cast<std::uint64_t>(INT_MAX)) {
        out_reason = "cache k exceeds INT_MAX";
        return knn_cache_load_status_t::invalid;
    }
    if (header.metric_id != static_cast<std::uint32_t>(expected_metric_id)) {
        out_reason = "cache kNN metric mismatch";
        return knn_cache_load_status_t::invalid;
    }
    const double metric_param_tol =
        std::max(1e-15, std::fabs(expected_metric_param) * 1e-12);
    if (!std::isfinite(header.metric_param) ||
        std::fabs(header.metric_param - expected_metric_param) > metric_param_tol) {
        out_reason = "cache kNN metric parameter mismatch";
        return knn_cache_load_status_t::invalid;
    }

    const int cached_k = static_cast<int>(header.k);
    knn_search_result_t loaded_knn(static_cast<size_t>(expected_n_points), static_cast<size_t>(cached_k));

    for (int i = 0; i < expected_n_points; ++i) {
        std::vector<int>& indices_row = loaded_knn.indices[static_cast<size_t>(i)];
        in.read(reinterpret_cast<char*>(indices_row.data()), static_cast<std::streamsize>(cached_k * sizeof(int)));
        if (!in) {
            out_reason = "cache file is truncated (indices)";
            return knn_cache_load_status_t::invalid;
        }
    }
    for (int i = 0; i < expected_n_points; ++i) {
        std::vector<double>& dist_row = loaded_knn.distances[static_cast<size_t>(i)];
        in.read(reinterpret_cast<char*>(dist_row.data()), static_cast<std::streamsize>(cached_k * sizeof(double)));
        if (!in) {
            out_reason = "cache file is truncated (distances)";
            return knn_cache_load_status_t::invalid;
        }
    }

    char trailing = '\0';
    if (in.read(&trailing, 1)) {
        out_reason = "cache file has unexpected trailing bytes";
        return knn_cache_load_status_t::invalid;
    }

    for (int i = 0; i < expected_n_points; ++i) {
        const auto& idx_row = loaded_knn.indices[static_cast<size_t>(i)];
        const auto& dist_row = loaded_knn.distances[static_cast<size_t>(i)];
        for (int j = 0; j < cached_k; ++j) {
            const int idx = idx_row[static_cast<size_t>(j)];
            if (idx < 0 || idx >= expected_n_points) {
                out_reason = "cache contains out-of-range neighbor index";
                return knn_cache_load_status_t::invalid;
            }
            const double d = dist_row[static_cast<size_t>(j)];
            if (!std::isfinite(d) || d < 0.0) {
                out_reason = "cache contains invalid distance";
                return knn_cache_load_status_t::invalid;
            }
        }
    }

    out_knn_results = std::move(loaded_knn);
    out_reason.clear();
    return knn_cache_load_status_t::loaded;
}

void write_knn_cache_file_atomic(
    const std::string& cache_path,
    const knn_search_result_t& knn_results,
    int n_features,
    int metric_id,
    double metric_param) {

    if (cache_path.empty()) {
        Rf_error("knn.cache.path cannot be empty.");
    }

    const std::string tmp_path = make_knn_cache_tmp_path(cache_path);
    knn_cache_header_t header{};
    std::memcpy(header.magic, k_knn_cache_magic, sizeof(k_knn_cache_magic));
    header.version = k_knn_cache_version;
    header.endian_marker = k_knn_cache_endian_marker;
    header.n_points = static_cast<std::uint64_t>(knn_results.n_points);
    header.n_features = static_cast<std::uint64_t>(n_features);
    header.k = static_cast<std::uint64_t>(knn_results.k);
    header.metric_id = static_cast<std::uint32_t>(metric_id);
    header.metric_param = metric_param;

    {
        std::ofstream out(tmp_path, std::ios::binary | std::ios::trunc);
        if (!out.is_open()) {
            Rf_error("Failed to create temp cache file '%s': %s",
                     tmp_path.c_str(), std::strerror(errno));
        }

        if (!write_binary(out, header)) {
            std::remove(tmp_path.c_str());
            Rf_error("Failed to write cache header to '%s'.", tmp_path.c_str());
        }

        for (size_t i = 0; i < knn_results.n_points; ++i) {
            const auto& idx_row = knn_results.indices[i];
            out.write(reinterpret_cast<const char*>(idx_row.data()),
                      static_cast<std::streamsize>(knn_results.k * sizeof(int)));
            if (!out) {
                std::remove(tmp_path.c_str());
                Rf_error("Failed to write cache indices to '%s'.", tmp_path.c_str());
            }
        }
        for (size_t i = 0; i < knn_results.n_points; ++i) {
            const auto& dist_row = knn_results.distances[i];
            out.write(reinterpret_cast<const char*>(dist_row.data()),
                      static_cast<std::streamsize>(knn_results.k * sizeof(double)));
            if (!out) {
                std::remove(tmp_path.c_str());
                Rf_error("Failed to write cache distances to '%s'.", tmp_path.c_str());
            }
        }

        out.flush();
        if (!out) {
            std::remove(tmp_path.c_str());
            Rf_error("Failed to flush temp cache file '%s'.", tmp_path.c_str());
        }
    }

    if (std::rename(tmp_path.c_str(), cache_path.c_str()) != 0) {
        const int rename_errno = errno;
#ifdef _WIN32
        std::remove(cache_path.c_str());
        if (std::rename(tmp_path.c_str(), cache_path.c_str()) == 0) {
            return;
        }
#endif
        std::remove(tmp_path.c_str());
        Rf_error("Failed to atomically move cache file '%s' to '%s': %s",
                 tmp_path.c_str(), cache_path.c_str(), std::strerror(rename_errno));
    }
}

enum class iknn_parallel_mode_t : int {
    auto_mode = 0,
    k = 1,
    bucket = 2,
    hybrid = 3
};

enum class iknn_execution_mode_t : int {
    serial = 0,
    k_parallel = 1,
    bucket = 2,
    hybrid = 3
};

const char* iknn_execution_mode_label(iknn_execution_mode_t mode) {
    switch (mode) {
        case iknn_execution_mode_t::k_parallel:
            return "over k values";
        case iknn_execution_mode_t::bucket:
            return "over inverted-index buckets";
        case iknn_execution_mode_t::hybrid:
            return "hybrid (bucket build + k pruning)";
        case iknn_execution_mode_t::serial:
        default:
            return "serial";
    }
}

const char* iknn_parallel_mode_label(iknn_parallel_mode_t mode) {
    switch (mode) {
        case iknn_parallel_mode_t::k:
            return "k";
        case iknn_parallel_mode_t::bucket:
            return "bucket";
        case iknn_parallel_mode_t::hybrid:
            return "hybrid";
        case iknn_parallel_mode_t::auto_mode:
        default:
            return "auto";
    }
}

size_t count_undirected_edges(const iknn_graph_t& graph) {
    size_t edge_count = 0;
    for (const auto& vertex_edges : graph.graph) {
        edge_count += vertex_edges.size();
    }
    return edge_count / 2;
}

size_t count_undirected_edges(const set_wgraph_t& graph) {
    size_t edge_count = 0;
    for (const auto& nbrs : graph.adjacency_list) {
        edge_count += nbrs.size();
    }
    return edge_count / 2;
}

size_t count_undirected_edges(const vect_wgraph_t& graph) {
    size_t edge_count = 0;
    for (const auto& nbrs : graph.adjacency_list) {
        edge_count += nbrs.size();
    }
    return edge_count / 2;
}

void prune_iknn_graph_and_collect_stats(
    const iknn_graph_t& iknn_graph,
    double max_path_edge_ratio_thld,
    double path_edge_ratio_percentile,
    double threshold_percentile,
    int max_alt_path_length,
    bool with_isize_pruning,
    bool with_edge_pruning_stats,
    bool verbose_geometric_prune,
    double na_real,
    set_wgraph_t& out_geom_pruned_graph,
    vect_wgraph_t* out_isize_pruned_graph,
    edge_pruning_stats_t* out_edge_pruning_stats,
    std::vector<double>& out_k_stats,
    double& out_geom_prune_seconds,
    double& out_isize_prune_seconds) {

    const bool do_geometric_prune = (max_path_edge_ratio_thld > 1.0);
    const size_t n_edges_sz = count_undirected_edges(iknn_graph);

    auto stage_start = std::chrono::steady_clock::now();
    set_wgraph_t pruned_graph(iknn_graph);
    if (do_geometric_prune) {
        pruned_graph = pruned_graph.prune_edges_geometrically(
            max_path_edge_ratio_thld, path_edge_ratio_percentile, verbose_geometric_prune);
    } else if (verbose_geometric_prune) {
        Rprintf("[geometric_prune] skipped (threshold <= 1.0)\n");
    }

    if (threshold_percentile > 0.0) {
        pruned_graph = pruned_graph.prune_long_edges(threshold_percentile);
    }

    const size_t n_edges_pruned_sz = count_undirected_edges(pruned_graph);
    out_geom_prune_seconds = std::chrono::duration<double>(
        std::chrono::steady_clock::now() - stage_start
    ).count();

    double n_edges_isize_d = na_real;
    double double_removed_d = na_real;
    double double_red_ratio = na_real;
    out_isize_prune_seconds = 0.0;

    if (with_isize_pruning) {
        stage_start = std::chrono::steady_clock::now();
        vect_wgraph_t isize_pruned_graph = iknn_graph.prune_graph(max_alt_path_length);
        const size_t n_edges_isize_pruned_sz = count_undirected_edges(isize_pruned_graph);
        out_isize_prune_seconds = std::chrono::duration<double>(
            std::chrono::steady_clock::now() - stage_start
        ).count();

        n_edges_isize_d = static_cast<double>(n_edges_isize_pruned_sz);
        double_removed_d = static_cast<double>(n_edges_pruned_sz - n_edges_isize_pruned_sz);
        double_red_ratio = (n_edges_pruned_sz > 0.0)
            ? (double_removed_d / static_cast<double>(n_edges_pruned_sz))
            : 0.0;

        if (out_isize_pruned_graph != nullptr) {
            *out_isize_pruned_graph = std::move(isize_pruned_graph);
        }
    }

    const double n_edges_d        = static_cast<double>(n_edges_sz);
    const double n_edges_pruned_d = static_cast<double>(n_edges_pruned_sz);
    const double removed_d        = static_cast<double>(n_edges_sz - n_edges_pruned_sz);
    const double red_ratio        = (n_edges_d > 0.0) ? (removed_d / n_edges_d) : 0.0;

    out_k_stats = {
        n_edges_d,
        n_edges_pruned_d,
        removed_d,
        red_ratio,
        n_edges_isize_d,
        double_removed_d,
        double_red_ratio
    };

    if (with_edge_pruning_stats && out_edge_pruning_stats != nullptr) {
        *out_edge_pruning_stats = pruned_graph.compute_edge_pruning_stats(path_edge_ratio_percentile);
    }

    out_geom_pruned_graph = std::move(pruned_graph);
}

/**
 * @brief Computes and analyzes a series of intersection-weighted k-nearest neighbors graphs with multiple pruning strategies
 *
 * @details
 * For a given range of k values [kmin, kmax], this function:
 * 1. Constructs and analyzes intersection-weighted k-nearest neighbors (IWD-kNN) graphs
 * 2. Applies geometric pruning based on path-to-edge ratios
 *    Optionally applies quantile-based edge length pruning
 * 3. Computes comprehensive statistics for each graph and pruning method
 * 4. Optionally returns the full pruned graph structures for further analysis
 *
 * The geometric pruning uses the path-to-edge ratio to determine which edges to remove:
 * - Edges are pruned when an alternative path exists with a better path-to-edge ratio
 * - The pruning threshold and percentile can be configured via parameters
 *
 * The intersection-size pruning evaluates alternative paths with at least 2 edges and prunes
 * edges when all edges in the alternative path have larger intersection sizes.
 *
 * @param s_X SEXP object representing the input data matrix. Must be a numeric matrix
 *           where rows represent data points (vertices) and columns represent features
 *
 * @param s_kmin SEXP object (integer) representing the minimum k value to consider
 *              Must be positive
 *
 * @param s_kmax SEXP object (integer) representing the maximum k value to consider
 *              Must be greater than or equal to kmin
 *
 * @param s_max_path_edge_ratio_thld SEXP object (double) Maximum acceptable ratio of
 *        alternative path length to edge length for geometric pruning.
 *        Edges with ratio <= this value will be pruned. If <= 0, this pruning stage is skipped.
 *
 * @param s_path_edge_ratio_percentile SEXP object (double) Percentile threshold (0.0-1.0)
 *        for edge lengths to consider in geometric pruning. Only edges with length
 *        greater than this percentile are considered for pruning.
 *
 * @param s_threshold_percentile SEXP object (double) Percentile threshold for quantile-based
 *        edge length pruning. Valid range is [0.0, 0.5]. Value of 0.0 disables quantile pruning.
 *        When > 0, edges in the top (1 - threshold_percentile) quantile by length are
 *        removed if their removal preserves connectivity. For example, 0.9 removes top 10% of edges.
 *
 * @param s_compute_full SEXP object (logical) controlling computation of optional components:
 *                      - TRUE: Store complete pruned graph structures for both pruning methods
 *                      - FALSE: Return only statistics without full graph structures
 * @param s_n_cores SEXP object(NULL or integer) controlling the number of cores to use with n_cores = NULL using maximal possible number of cores on OMP machines and n_cores = 1 forcing serial execution.
 * @param s_verbose SEXP object (logical) controlling progress reporting during computation
 *
 * @return SEXP object (a named list) containing:
 * - k_statistics: Matrix with columns:
 *   - k: k value
 *   - n_edges: Total edges in original graph
 *   - n_edges_in_pruned_graph: Edges remaining after geometric pruning
 *   - n_removed_edges: Edges removed during geometric pruning
 *   - edge_reduction_ratio: Proportion of edges removed by geometric pruning
 *   - n_edges_in_isize_pruned_graph: Edges remaining after intersection-size pruning
 *   - n_removed_edges_in_double_pruning: Additional edges removed by intersection-size pruning
 *   - double_edge_reduction_ratio: Proportion of edges removed by intersection-size pruning
 *
 * - geom_pruned_graphs: If compute_full is TRUE, list of geometrically pruned graphs for each k value,
 *                       each containing adj_list and weight_list components. NULL if compute_full is FALSE.
 *
 * - isize_pruned_graphs: If compute_full is TRUE, list of intersection-size pruned graphs for each k value,
 *                        each containing adj_list and weight_list components. NULL if compute_full is FALSE.
 *
 * - edge_pruning_stats: List of matrices, one for each k value, containing edge pruning statistics:
 *   - edge_length: Length of each analyzed edge
 *   - length_ratio: Ratio of alternative path length to edge length
 *
 * @note
 * - The function computes k-nearest neighbors only once with the maximum k value for efficiency
 * - Construction and pruning run serially on R\'s main thread
 * - The function uses intersection size and geometric distance for edge pruning decisions
 * - Edge pruning preserves graph connectivity while reducing redundant connections
 * - All indices in returned R objects are 1-based (R convention)
 *
 * @see
 * - create_iknn_graph(): Creates a single intersection-weighted k-nearest neighbors graph
 * - set_wgraph_t::prune_edges_geometrically(): Geometric pruning implementation
 * - iknn_graph_t::prune_graph(): Intersection-size pruning implementation
 */
SEXP S_create_iknn_graphs(
    SEXP s_X,
    SEXP s_kmin,
    SEXP s_kmax,
    // pruning parameters
    SEXP s_max_path_edge_ratio_thld,
    SEXP s_path_edge_ratio_percentile,
    SEXP s_threshold_percentile,
    // other
    SEXP s_compute_full,
    SEXP s_with_isize_pruning,
    SEXP s_with_edge_pruning_stats,
    SEXP s_n_cores,
    SEXP s_parallel_mode,
    SEXP s_hybrid_batch_size,
    SEXP s_knn_cache_path,
    SEXP s_knn_cache_mode,
    SEXP s_knn_metric,
    SEXP s_linf_tol,
    SEXP s_verbose) {

    const int  max_alt_path_length = 2; // for intersection pruning

    // --- Dimensions (protect while reading)
    SEXP s_dim = PROTECT(Rf_getAttrib(s_X, R_DimSymbol));
    if (s_dim == R_NilValue || TYPEOF(s_dim) != INTSXP || Rf_length(s_dim) < 2) {
        UNPROTECT(1);
        Rf_error("X must be a matrix with a valid integer 'dim' attribute.");
    }
    const int n_vertices = INTEGER(s_dim)[0];
    const int n_features = INTEGER(s_dim)[1];
    UNPROTECT(1); // s_dim

    // --- Scalars / args
    if (!Rf_isInteger(s_kmin) || !Rf_isInteger(s_kmax))
        Rf_error("kmin and kmax must be integer.");
    const int kmin = Rf_asInteger(s_kmin);
    const int kmax = Rf_asInteger(s_kmax);
    if (kmin <= 0 || kmax < kmin) Rf_error("Require 0 < kmin <= kmax.");

    if (!Rf_isReal(s_max_path_edge_ratio_thld) || !Rf_isReal(s_path_edge_ratio_percentile))
        Rf_error("Threshold/percentile must be numeric.");
    const double max_path_edge_ratio_thld   = Rf_asReal(s_max_path_edge_ratio_thld);
    const double path_edge_ratio_percentile = Rf_asReal(s_path_edge_ratio_percentile);

    // --- Validate and extract quantile pruning parameter
    if (!Rf_isReal(s_threshold_percentile))
        Rf_error("threshold_percentile must be numeric.");
    const double threshold_percentile = Rf_asReal(s_threshold_percentile);

    if (threshold_percentile < 0.0 || threshold_percentile > 0.5) {
        Rf_error("threshold_percentile must be in [0.0, 0.5]. Got %.3f", threshold_percentile);
    }

    if (!Rf_isLogical(s_compute_full) ||
        !Rf_isLogical(s_with_isize_pruning) ||
        !Rf_isLogical(s_with_edge_pruning_stats) ||
        !Rf_isLogical(s_verbose)) {
        Rf_error("compute_full, with_isize_pruning, with_edge_pruning_stats, and verbose must be logical.");
    }
    const bool compute_full = (Rf_asLogical(s_compute_full) == TRUE);
    const bool with_isize_pruning = (Rf_asLogical(s_with_isize_pruning) == TRUE);
    const bool with_edge_pruning_stats = (Rf_asLogical(s_with_edge_pruning_stats) == TRUE);
    const bool verbose = (Rf_asLogical(s_verbose) == TRUE);

    if (!Rf_isInteger(s_knn_metric) || Rf_length(s_knn_metric) < 1) {
        Rf_error("knn.metric must be a length-1 integer.");
    }
    const int knn_metric_id = INTEGER(s_knn_metric)[0];
    if (knn_metric_id == NA_INTEGER || knn_metric_id < 0 || knn_metric_id > 1) {
        Rf_error("knn.metric must be in {0,1}.");
    }
    if (!Rf_isReal(s_linf_tol) || Rf_length(s_linf_tol) < 1) {
        Rf_error("linf.tol must be a length-1 numeric value.");
    }
    const double linf_tol = REAL(s_linf_tol)[0];
    if (!std::isfinite(linf_tol) || linf_tol <= 0.0) {
        Rf_error("linf.tol must be a positive finite number.");
    }

    if (!Rf_isInteger(s_parallel_mode) || Rf_length(s_parallel_mode) < 1) {
        Rf_error("parallel_mode must be a length-1 integer.");
    }
    const int parallel_mode_raw = INTEGER(s_parallel_mode)[0];
    if (parallel_mode_raw == NA_INTEGER ||
        parallel_mode_raw < static_cast<int>(iknn_parallel_mode_t::auto_mode) ||
        parallel_mode_raw > static_cast<int>(iknn_parallel_mode_t::hybrid)) {
        Rf_error("parallel_mode must be in {0,1,2,3}.");
    }
    const iknn_parallel_mode_t requested_parallel_mode =
        static_cast<iknn_parallel_mode_t>(parallel_mode_raw);

    if (!Rf_isInteger(s_hybrid_batch_size) || Rf_length(s_hybrid_batch_size) < 1) {
        Rf_error("hybrid_batch_size must be a length-1 integer.");
    }
    const int hybrid_batch_size = INTEGER(s_hybrid_batch_size)[0];
    if (hybrid_batch_size == NA_INTEGER || hybrid_batch_size < 1) {
        Rf_error("hybrid_batch_size must be a positive integer.");
    }

    if (!Rf_isInteger(s_knn_cache_mode) || Rf_length(s_knn_cache_mode) < 1) {
        Rf_error("knn.cache.mode must be a length-1 integer.");
    }
    const int knn_cache_mode_raw = INTEGER(s_knn_cache_mode)[0];
    if (knn_cache_mode_raw == NA_INTEGER ||
        knn_cache_mode_raw < static_cast<int>(knn_cache_mode_t::none) ||
        knn_cache_mode_raw > static_cast<int>(knn_cache_mode_t::readwrite)) {
        Rf_error("knn.cache.mode must be in {0,1,2,3}.");
    }
    const knn_cache_mode_t knn_cache_mode = static_cast<knn_cache_mode_t>(knn_cache_mode_raw);

    std::string knn_cache_path;
    if (!Rf_isNull(s_knn_cache_path)) {
        if (TYPEOF(s_knn_cache_path) != STRSXP ||
            Rf_length(s_knn_cache_path) != 1 ||
            STRING_ELT(s_knn_cache_path, 0) == NA_STRING) {
            Rf_error("knn.cache.path must be NULL or a non-empty character scalar.");
        }
        const char* path_cstr = CHAR(STRING_ELT(s_knn_cache_path, 0));
        if (path_cstr == nullptr || path_cstr[0] == '\0') {
            Rf_error("knn.cache.path must be NULL or a non-empty character scalar.");
        }
        knn_cache_path.assign(path_cstr);
    }
    if (knn_cache_mode != knn_cache_mode_t::none && knn_cache_path.empty()) {
        Rf_error("knn.cache.path must be provided when knn.cache.mode is not 'none'.");
    }

    // Compatibility parameters are validated but native construction is serial.
    if (!Rf_isNull(s_n_cores) &&
        (!Rf_isInteger(s_n_cores) || Rf_length(s_n_cores) != 1 ||
         INTEGER(s_n_cores)[0] == NA_INTEGER)) {
        Rf_error("n_cores must be NULL or a non-missing integer scalar.");
    }
    (void)hybrid_batch_size;

    // --- Precompute / allocate (pure C++; no R API here)
    std::vector<int> k_values(kmax - kmin + 1);
    std::iota(k_values.begin(), k_values.end(), kmin);
    const int n_k_values = static_cast<int>(k_values.size());
    const iknn_execution_mode_t execution_mode = iknn_execution_mode_t::serial;
    const bool do_geometric_prune = (max_path_edge_ratio_thld > 1.0);

    // Messaging
    if (verbose) {
        Rprintf("\tRunning single-threaded.\n");
        Rprintf("Processing k values from %d to %d for %d vertices\n", kmin - 1, kmax - 1, n_vertices);
        if (knn_cache_mode != knn_cache_mode_t::none) {
            Rprintf("kNN cache mode: %s (%s)\n",
                    knn_cache_mode_label(knn_cache_mode),
                    knn_cache_path.c_str());
        }
        if (threshold_percentile > 0.0) {
            Rprintf("Quantile pruning enabled: removing top %.1f%% of edges by length\n",
                    100.0 * (1.0 - threshold_percentile));
        }
        Rprintf("Requested parallel.mode: %s\n", iknn_parallel_mode_label(requested_parallel_mode));
        Rprintf("Parallel mode: %s\n", iknn_execution_mode_label(execution_mode));
        Rprintf("Starting graph processing\n");
    }

    auto total_start_time    = std::chrono::steady_clock::now();
    auto parallel_start_time = std::chrono::steady_clock::now();

    // Compute kNN once for maximum k (pure C++; must not touch R API)
    auto knn_start_time = std::chrono::steady_clock::now();
    print_stage_running("compute_knn", verbose);
    knn_search_result_t knn_results(static_cast<size_t>(n_vertices), 0);
    bool knn_cache_hit = false;
    bool knn_cache_written = false;

    if (knn_cache_mode == knn_cache_mode_t::read || knn_cache_mode == knn_cache_mode_t::readwrite) {
        std::string cache_reason;
        const knn_cache_load_status_t cache_status = read_knn_cache_file(
            knn_cache_path,
            n_vertices,
            n_features,
            kmax,
            knn_metric_id,
            (knn_metric_id == 1 ? linf_tol : 0.0),
            knn_results,
            cache_reason
        );
        if (cache_status == knn_cache_load_status_t::loaded) {
            knn_cache_hit = true;
        } else if (cache_status == knn_cache_load_status_t::not_found &&
                   knn_cache_mode == knn_cache_mode_t::readwrite) {
            knn_cache_hit = false;
        } else {
            Rf_error("Failed to read kNN cache '%s': %s", knn_cache_path.c_str(), cache_reason.c_str());
        }
    }

    if (!knn_cache_hit) {
        knn_results = compute_knn_by_metric(s_X, kmax, knn_metric_id, linf_tol);
        if (knn_cache_mode == knn_cache_mode_t::write || knn_cache_mode == knn_cache_mode_t::readwrite) {
            write_knn_cache_file_atomic(knn_cache_path,
                                        knn_results,
                                        n_features,
                                        knn_metric_id,
                                        (knn_metric_id == 1 ? linf_tol : 0.0));
            knn_cache_written = true;
        }
    }

    const double compute_knn_seconds = std::chrono::duration<double>(
        std::chrono::steady_clock::now() - knn_start_time
    ).count();
    print_stage_done("compute_knn", knn_start_time, verbose);
    if (verbose && knn_cache_mode != knn_cache_mode_t::none) {
        if (knn_cache_hit) {
            Rprintf("[compute_knn] cache hit (%s, cached_k=%zu)\n",
                    knn_cache_path.c_str(),
                    knn_results.k);
        } else if (knn_cache_written) {
            Rprintf("[compute_knn] cache saved (%s, k=%d)\n",
                    knn_cache_path.c_str(),
                    kmax);
        } else {
            Rprintf("[compute_knn] cache mode: %s\n", knn_cache_mode_label(knn_cache_mode));
        }
    }

    const double na_real = std::numeric_limits<double>::quiet_NaN();

    std::vector<set_wgraph_t>          geom_pruned_graphs(kmax - kmin + 1);
    std::vector<vect_wgraph_t>         isize_pruned_graphs;
    if (with_isize_pruning) {
        isize_pruned_graphs.resize(kmax - kmin + 1);
    }
    std::vector<std::vector<double>>   k_statistics(kmax - kmin + 1, std::vector<double>(7, na_real));
    std::vector<edge_pruning_stats_t>  all_edge_pruning_stats;
    if (with_edge_pruning_stats) {
        all_edge_pruning_stats.resize(kmax - kmin + 1);
    }

    double graph_build_seconds = 0.0;
    double geom_prune_seconds = 0.0;
    double isize_prune_seconds = 0.0;
    auto graph_processing_stage_start = std::chrono::steady_clock::now();
    print_stage_running("graph_build/geometric_prune/isize_prune", verbose);

    {
        for (int k_idx = 0; k_idx < static_cast<int>(k_values.size()); ++k_idx) {
            const int k = k_values[static_cast<size_t>(k_idx)];

            auto stage_start = std::chrono::steady_clock::now();
            iknn_graph_t iknn_graph = create_iknn_graph_inverted_index(knn_results, k, false, 1);
            graph_build_seconds += std::chrono::duration<double>(
                std::chrono::steady_clock::now() - stage_start
            ).count();

            double local_geom_prune_seconds = 0.0;
            double local_isize_prune_seconds = 0.0;
            prune_iknn_graph_and_collect_stats(
                iknn_graph,
                max_path_edge_ratio_thld,
                path_edge_ratio_percentile,
                threshold_percentile,
                max_alt_path_length,
                with_isize_pruning,
                with_edge_pruning_stats,
                verbose && n_k_values == 1,
                na_real,
                geom_pruned_graphs[static_cast<size_t>(k_idx)],
                with_isize_pruning ? &isize_pruned_graphs[static_cast<size_t>(k_idx)] : nullptr,
                with_edge_pruning_stats ? &all_edge_pruning_stats[static_cast<size_t>(k_idx)] : nullptr,
                k_statistics[static_cast<size_t>(k_idx)],
                local_geom_prune_seconds,
                local_isize_prune_seconds
            );
            geom_prune_seconds += local_geom_prune_seconds;
            isize_prune_seconds += local_isize_prune_seconds;
        }
    }

    print_stage_done("graph_build/geometric_prune/isize_prune",
                     graph_processing_stage_start,
                     verbose);

    if (verbose) {
        elapsed_time(parallel_start_time, "Graph processing completed", true);
        Rprintf("[compute_knn] %.3fs\n", compute_knn_seconds);
        Rprintf("[graph_build] %.3fs\n", graph_build_seconds);
        if (do_geometric_prune) {
            Rprintf("[geometric_prune] %.3fs\n", geom_prune_seconds);
        } else {
            Rprintf("[geometric_prune] skipped (max.path.edge.ratio.deviation.thld=0)\n");
        }
        if (with_isize_pruning) {
            Rprintf("[isize_prune] %.3fs\n", isize_prune_seconds);
        } else {
            Rprintf("[isize_prune] skipped (with.isize.pruning=FALSE)\n");
        }
    }

    auto serial_start_time = std::chrono::steady_clock::now();
    if (verbose) Rprintf("Creating return list objects ... ");

    // --- Return list (same structure as before)
    SEXP r_result = PROTECT(Rf_allocVector(VECSXP, 4));

    // names
    {
        SEXP names = PROTECT(Rf_allocVector(STRSXP, 4));
        SET_STRING_ELT(names, 0, Rf_mkChar("k_statistics"));
        SET_STRING_ELT(names, 1, Rf_mkChar("geom_pruned_graphs"));
        SET_STRING_ELT(names, 2, Rf_mkChar("isize_pruned_graphs"));
        SET_STRING_ELT(names, 3, Rf_mkChar("edge_pruning_stats"));
        Rf_setAttrib(r_result, R_NamesSymbol, names);
        UNPROTECT(1);
    }

    // 3: edge_pruning_stats (list of matrices, optional)
    if (with_edge_pruning_stats) {
        const int nK = kmax - kmin + 1;
        SEXP edge_stats_list = PROTECT(Rf_allocVector(VECSXP, (R_len_t)nK));

        for (int k_idx = 0; k_idx < nK; ++k_idx) {
            const auto& eps = all_edge_pruning_stats[static_cast<size_t>(k_idx)];
            const size_t nrows_sz = eps.stats.size();
            if (nrows_sz > static_cast<size_t>(INT_MAX)) {
                Rf_error("Too many rows in edge stats.");
            }

            SEXP edge_stats_matrix = PROTECT(Rf_allocMatrix(REALSXP, (R_len_t)nrows_sz, 2));
            double* stats_data = REAL(edge_stats_matrix);

            for (size_t i = 0; i < nrows_sz; ++i) {
                stats_data[i]            = eps.stats[i].edge_length;
                stats_data[i + nrows_sz] = eps.stats[i].length_ratio;
            }

            SEXP stats_dimnames = PROTECT(Rf_allocVector(VECSXP, 2));
            SET_VECTOR_ELT(stats_dimnames, 0, R_NilValue);
            SEXP stats_colnames = PROTECT(Rf_allocVector(STRSXP, 2));
            SET_STRING_ELT(stats_colnames, 0, Rf_mkChar("edge_length"));
            SET_STRING_ELT(stats_colnames, 1, Rf_mkChar("length_ratio"));
            SET_VECTOR_ELT(stats_dimnames, 1, stats_colnames);
            Rf_setAttrib(edge_stats_matrix, R_DimNamesSymbol, stats_dimnames);

            SET_VECTOR_ELT(edge_stats_list, k_idx, edge_stats_matrix);
            UNPROTECT(3); // edge_stats_matrix, stats_dimnames, stats_colnames
        }

        {
            const int nK2 = kmax - kmin + 1;
            SEXP edge_stats_list_names = PROTECT(Rf_allocVector(STRSXP, (R_len_t)nK2));
            for (int k_idx = 0; k_idx < nK2; ++k_idx) {
                SET_STRING_ELT(edge_stats_list_names, k_idx,
                               Rf_mkChar(std::to_string(kmin + k_idx).c_str()));
            }
            Rf_setAttrib(edge_stats_list, R_NamesSymbol, edge_stats_list_names);
            UNPROTECT(1);
        }

        SET_VECTOR_ELT(r_result, 3, edge_stats_list);
        UNPROTECT(1); // edge_stats_list
    } else {
        SET_VECTOR_ELT(r_result, 3, R_NilValue);
    }

    // 1 & 2: full graphs (optional)
    if (compute_full) {
        const int nK = kmax - kmin + 1;
        SEXP geom_pruned_graphs_list  = PROTECT(Rf_allocVector(VECSXP, (R_len_t)nK));
        SEXP isize_pruned_graphs_list = R_NilValue;
        if (with_isize_pruning) {
            isize_pruned_graphs_list = PROTECT(Rf_allocVector(VECSXP, (R_len_t)nK));
        }

        for (int k_idx = 0; k_idx < nK; ++k_idx) {
            // --- geometric pruned
            {
                const auto& pg = geom_pruned_graphs[static_cast<size_t>(k_idx)];

                SEXP r_adj  = PROTECT(Rf_allocVector(VECSXP, (R_len_t)n_vertices));
                SEXP r_wght = PROTECT(Rf_allocVector(VECSXP, (R_len_t)n_vertices));

                for (int i = 0; i < n_vertices; ++i) {
                    const auto& edges = pg.adjacency_list[(size_t)i];
                    const size_t m_sz = edges.size();
                    if (m_sz > static_cast<size_t>(INT_MAX))
                        Rf_error("Too many edges for R vectors.");

                    // adj
                    {
                        SEXP RA = PROTECT(Rf_allocVector(INTSXP, (R_len_t)m_sz));
                        int* A = INTEGER(RA);
                        for (const auto& e : edges) *A++ = (int)e.vertex + 1;
                        SET_VECTOR_ELT(r_adj, i, RA);
                        UNPROTECT(1);
                    }
                    // weight
                    {
                        SEXP RD = PROTECT(Rf_allocVector(REALSXP, (R_len_t)m_sz));
                        double* D = REAL(RD);
                        for (const auto& e : edges) *D++ = e.weight;
                        SET_VECTOR_ELT(r_wght, i, RD);
                        UNPROTECT(1);
                    }
                }

                SEXP r_pg = PROTECT(Rf_allocVector(VECSXP, 2));
                {
                    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 2));
                    SET_STRING_ELT(nm, 0, Rf_mkChar("adj_list"));
                    SET_STRING_ELT(nm, 1, Rf_mkChar("weight_list"));
                    Rf_setAttrib(r_pg, R_NamesSymbol, nm);
                    UNPROTECT(1);
                }
                SET_VECTOR_ELT(r_pg, 0, r_adj);
                SET_VECTOR_ELT(r_pg, 1, r_wght);
                UNPROTECT(2); // r_adj, r_wght

                SET_VECTOR_ELT(geom_pruned_graphs_list, k_idx, r_pg);
                UNPROTECT(1); // r_pg
            }

            if (with_isize_pruning) {
                // --- isize pruned
                const auto& ig = isize_pruned_graphs[static_cast<size_t>(k_idx)];

                SEXP r_adj  = PROTECT(Rf_allocVector(VECSXP, (R_len_t)n_vertices));
                SEXP r_wght = PROTECT(Rf_allocVector(VECSXP, (R_len_t)n_vertices));

                for (int i = 0; i < n_vertices; ++i) {
                    const auto& edges = ig.adjacency_list[(size_t)i];
                    const size_t m_sz = edges.size();
                    if (m_sz > static_cast<size_t>(INT_MAX))
                        Rf_error("Too many edges for R vectors.");

                    {
                        SEXP RA = PROTECT(Rf_allocVector(INTSXP, (R_len_t)m_sz));
                        int* A = INTEGER(RA);
                        for (const auto& e : edges) *A++ = (int)e.vertex + 1;
                        SET_VECTOR_ELT(r_adj, i, RA);
                        UNPROTECT(1);
                    }
                    {
                        SEXP RD = PROTECT(Rf_allocVector(REALSXP, (R_len_t)m_sz));
                        double* D = REAL(RD);
                        for (const auto& e : edges) *D++ = e.weight;
                        SET_VECTOR_ELT(r_wght, i, RD);
                        UNPROTECT(1);
                    }
                }

                SEXP r_ig = PROTECT(Rf_allocVector(VECSXP, 2));
                {
                    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 2));
                    SET_STRING_ELT(nm, 0, Rf_mkChar("adj_list"));
                    SET_STRING_ELT(nm, 1, Rf_mkChar("weight_list"));
                    Rf_setAttrib(r_ig, R_NamesSymbol, nm);
                    UNPROTECT(1);
                }
                SET_VECTOR_ELT(r_ig, 0, r_adj);
                SET_VECTOR_ELT(r_ig, 1, r_wght);
                UNPROTECT(2); // r_adj, r_wght

                SET_VECTOR_ELT(isize_pruned_graphs_list, k_idx, r_ig);
                UNPROTECT(1); // r_ig
            }
        }

        SET_VECTOR_ELT(r_result, 1, geom_pruned_graphs_list);
        if (with_isize_pruning) {
            SET_VECTOR_ELT(r_result, 2, isize_pruned_graphs_list);
            UNPROTECT(2); // geom_pruned_graphs_list, isize_pruned_graphs_list
        } else {
            SET_VECTOR_ELT(r_result, 2, R_NilValue);
            UNPROTECT(1); // geom_pruned_graphs_list
        }
    } else {
        SET_VECTOR_ELT(r_result, 1, R_NilValue);
        SET_VECTOR_ELT(r_result, 2, R_NilValue);
    }

    // 0: k_statistics matrix
    {
        const size_t nK_sz = k_statistics.size();
        if (nK_sz > static_cast<size_t>(INT_MAX)) Rf_error("Too many k rows.");
        SEXP k_stats_matrix = PROTECT(Rf_allocMatrix(REALSXP, (R_len_t)nK_sz, 8));
        double* data = REAL(k_stats_matrix);

        for (size_t i = 0; i < nK_sz; ++i) {
            // columns: k, n_edges, n_edges_in_pruned_graph, n_removed_edges,
            //          edge_reduction_ratio, n_edges_in_isize_pruned_graph,
            //          n_removed_edges_in_double_pruning, double_edge_reduction_ratio
            data[i + 0 * nK_sz] = (double)(kmin + (int)i);
            for (size_t j = 0; j < 7; ++j) {
                data[i + (j + 1) * nK_sz] = k_statistics[i][j];
            }
        }

        SEXP k_stats_dimnames = PROTECT(Rf_allocVector(VECSXP, 2));
        SEXP k_stats_colnames = PROTECT(Rf_allocVector(STRSXP, 8));
        SET_STRING_ELT(k_stats_colnames, 0, Rf_mkChar("k"));
        SET_STRING_ELT(k_stats_colnames, 1, Rf_mkChar("n_edges"));
        SET_STRING_ELT(k_stats_colnames, 2, Rf_mkChar("n_edges_in_pruned_graph"));
        SET_STRING_ELT(k_stats_colnames, 3, Rf_mkChar("n_removed_edges"));
        SET_STRING_ELT(k_stats_colnames, 4, Rf_mkChar("edge_reduction_ratio"));
        SET_STRING_ELT(k_stats_colnames, 5, Rf_mkChar("n_edges_in_isize_pruned_graph"));
        SET_STRING_ELT(k_stats_colnames, 6, Rf_mkChar("n_removed_edges_in_double_pruning"));
        SET_STRING_ELT(k_stats_colnames, 7, Rf_mkChar("double_edge_reduction_ratio"));
        SET_VECTOR_ELT(k_stats_dimnames, 1, k_stats_colnames);
        SET_VECTOR_ELT(k_stats_dimnames, 0, R_NilValue);
        Rf_setAttrib(k_stats_matrix, R_DimNamesSymbol, k_stats_dimnames);
        UNPROTECT(2); // k_stats_dimnames, k_stats_colnames

        SET_VECTOR_ELT(r_result, 0, k_stats_matrix);
        UNPROTECT(1); // k_stats_matrix
    }

    if (verbose) {
        elapsed_time(serial_start_time, "DONE", true);
        elapsed_time(total_start_time, "Total elapsed time", true);
    }

    UNPROTECT(1); // r_result
    return r_result;
}
