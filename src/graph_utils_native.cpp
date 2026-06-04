#include "graph_utils_r.h"
#include "cpp_utils.hpp"
#include "SEXP_cpp_conversion_utils.hpp"
#include "stats_utils.h"

#include <vector>
#include <queue>
#include <memory>
#include <limits>
#include <algorithm>
#include <unordered_set>
#include <set>
#include <stack>
#include <numeric>
#include <unordered_map>
#include <random>
#include <chrono>

#include <R.h>
#include <Rinternals.h>

// ------------------------------------------------------------------------------------------
//
// Graph construction functions
//
// ------------------------------------------------------------------------------------------

/**
 * @brief Calculates the eccentricity (maximum shortest-path distance) of a start vertex in a weighted graph
 *
 * @details Implements Dijkstra's algorithm to find the shortest paths from the start vertex
 *          to all other reachable vertices, then returns the maximum such distance.
 *          This value represents the eccentricity of start_vertex, not the graph's diameter
 *          which would be the maximum eccentricity across all vertices.
 *
 * @param adj_list    Adjacency list representing the graph structure where adj_list[i] contains
 *                    the vertices adjacent to vertex i
 * @param weight_list Weight list corresponding to the adjacency list where weight_list[i][j] is
 *                    the weight of the edge from vertex i to its j-th neighbor in adj_list[i]
 * @param start_vertex The vertex whose eccentricity we want to compute
 *
 * @return The maximum shortest-path distance from start_vertex to any reachable vertex
 *
 * @pre adj_list and weight_list must have consistent sizes
 * @pre start_vertex must be a valid vertex index (0 <= start_vertex < adj_list.size())
 * @pre All edge weights must be non-negative
 *
 * @complexity Time: O(E log V) where V is the number of vertices and E is the number of edges
 *             Space: O(V) for the distance array, finalized array, and priority queue
 */
double get_vertex_eccentricity(
    const std::vector<std::vector<int>>& adj_list,
    const std::vector<std::vector<double>>& weight_list,
    int start_vertex) {

    // Track distances and whether vertices are finalized
    std::vector<double> distances(adj_list.size(), std::numeric_limits<double>::infinity());
    std::vector<bool> finalized(adj_list.size(), false);
    distances[start_vertex] = 0.0;

    // Priority queue stores pairs of (-distance, vertex)
    // Using negative distance because C++ priority_queue is max heap
    std::priority_queue<std::pair<double, int>> pq;
    pq.push({0.0, start_vertex});

    double max_distance = 0.0;

    while (!pq.empty()) {
        int current_vertex = pq.top().second;
        double current_distance = -pq.top().first;  // Note the negative
        pq.pop();

        if (finalized[current_vertex]) continue;

        finalized[current_vertex] = true;
        max_distance = std::max(max_distance, current_distance);

        // Explore neighbors
        for (size_t i = 0; i < adj_list[current_vertex].size(); ++i) {
            int neighbor = adj_list[current_vertex][i];
            double edge_length = weight_list[current_vertex][i];

            if (!finalized[neighbor]) {
                double new_distance = current_distance + edge_length;
                if (new_distance < distances[neighbor]) {
                    distances[neighbor] = new_distance;
                    pq.push({-new_distance, neighbor});  // Note the negative
                }
            }
        }
    }

    return max_distance;
}

/**
 * @brief Finds the maximum eccentricity among a given set of vertices in a weighted graph
 *
 * @details Computes the eccentricity (maximum shortest-path distance to any other vertex)
 *          for each vertex in the start_vertices set and returns the maximum value found.
 *          This can be used to find the graph's diameter if start_vertices includes all
 *          vertices, or to find the diameter with respect to a subset of vertices
 *          (e.g., leaf vertices only).
 *
 * @param adj_list       Adjacency list representing the graph structure where adj_list[i] contains
 *                       the vertices adjacent to vertex i
 * @param weight_list    Weight list corresponding to the adjacency list where weight_list[i][j] is
 *                       the weight of the edge from vertex i to its j-th neighbor in adj_list[i]
 * @param start_vertices Vector of vertex indices for which to compute eccentricities
 *
 * @return The maximum eccentricity found among the specified start vertices
 *
 * @pre adj_list and weight_list must have consistent sizes
 * @pre All vertices in start_vertices must be valid indices (0 <= vertex < adj_list.size())
 * @pre All edge weights must be non-negative
 * @pre start_vertices must not be empty
 *
 * @note In some graphs the diameter is realized by the distance between special
 * degree one vertices. In this case the computation of the graph diameter is
 * much cheeper than in the case of a general graph.
 *
 * @complexity Time: O(|S| * E log V) where:
 *             - |S| is the size of start_vertices
 *             - V is the total number of vertices
 *             - E is the number of edges
 *             Space: O(V) for the internal data structures used by Dijkstra's algorithm
 */
double get_vertex_eccentricity(
    const std::vector<std::vector<int>>& adj_list,
    const std::vector<std::vector<double>>& weight_list,
    std::vector<int>& start_vertices) {

    // Handle empty input case
    if (start_vertices.empty()) {
        return 0.0;
    }

    double max_diameter = 0.0;

    // Compute eccentricity for each start vertex and keep track of maximum
    for (int vertex : start_vertices) {
        double current_diameter = get_vertex_eccentricity(adj_list, weight_list, vertex);
        max_diameter = std::max(max_diameter, current_diameter);
    }

    return max_diameter;
}

/**
 * Joins two graphs by identifying a vertex from each graph.
 *
 * This function takes two graphs represented as adjacency lists and merges them
 * by identifying vertex `i1` in `graph1` with vertex `i2` in `graph2`. The
 * resulting graph combines the vertices and edges from both input graphs, with
 * the specified vertices being treated as a single vertex in the joined graph.
 *
 * @param graph1 The adjacency list representation of the first graph.
 * @param graph2 The adjacency list representation of the second graph.
 * @param i1 The index of the vertex in `graph1` to be identified with vertex `i2` in `graph2`.
 * @param i2 The index of the vertex in `graph2` to be identified with vertex `i1` in `graph1`.
 * @return A unique pointer to the adjacency list representation of the joined graph.
 *
 * @note The function assumes that the vertex indices in `graph1` and `graph2` are 0-based
 *       and contiguous. If the graphs have different index ranges or non-contiguous indices,
 *       additional mapping or adjustment may be needed.
 *
 * Example usage:
 * @code
 * std::vector<std::vector<int>> graph1 = {{1, 2}, {0}, {0}};
 * std::vector<std::vector<int>> graph2 = {{1}, {0, 2}, {1}};
 * int i1 = 1;
 * int i2 = 0;
 * auto joined_graph = join_graphs(graph1, graph2, i1, i2);
 * @endcode
 *
 * The resulting `joined_graph` will represent the graph obtained by identifying
 * vertex 1 in `graph1` with vertex 0 in `graph2`.
 */
std::unique_ptr<std::vector<std::vector<int>>> join_graphs(const std::vector<std::vector<int>>& graph1,
                                                           const std::vector<std::vector<int>>& graph2,
                                                           int i1, int i2) {
    int n1 = graph1.size();
    int n2 = graph2.size();

    // Input validation
    if (i1 < 0 || i1 >= n1 || i2 < 0 || i2 >= n2) {
        if (i1 < 0 || i1 >= n1) {
            Rf_error("i1 has to be between 0 and graph1.size() - 1.");
        } else {
            Rf_error("i2 has to be between 0 and graph2.size() - 1.");
        }
    }

    // Create a new graph with the combined size of graph1 and graph2
    auto joined_graph = std::make_unique<std::vector<std::vector<int>>>(n1 + n2 - 1);

    // Copy the adjacency lists from graph1 to the join graph
    int n1_minus_one = n1 - 1;
    std::map<int, int> graph2_new_index;
    for (int i = 0; i < n2; ++i) {
        if (i < i2) {
            graph2_new_index[i] = i + n1;
        } else {
            graph2_new_index[i] = i + n1_minus_one;
        }
    }

    for (int i = 0; i < n1; ++i) {
        if (i == i1) {
            // For vertex i1 in graph1, add the neighbors of vertex i2 in graph2
            (*joined_graph)[i] = graph1[i];
            for (int neighbor : graph2[i2]) {
                (*joined_graph)[i].push_back(graph2_new_index[neighbor]);
            }
        } else {
            // For other vertices in graph1, copy their neighbors
            (*joined_graph)[i] = graph1[i];
        }
    }

    // Copy the adjacency lists from graph2 to the join graph, excluding vertex i2
    for (int i = 0; i < n2; ++i) {
        if (i != i2) {
            // Adjust the vertex indices in graph2 to account for the join graph size
            for (int neighbor : graph2[i]) {
                if (neighbor == i2) {
                    // If the neighbor is vertex i2, replace it with vertex i1 from graph1
                    (*joined_graph)[graph2_new_index[i]].push_back(i1);
                } else {
                    // For other neighbors, adjust their indices
                    (*joined_graph)[graph2_new_index[i]].push_back(graph2_new_index[neighbor]);
                }
            }
        }
    }

    return joined_graph;
}

/**
 * An R interface to the join_graphs function.
 *
 * This function takes two R lists representing graph adjacency lists and two integers
 * representing vertex indices, and returns the joined graph as an R list.
 *
 * @param Rgraph1 An R list representing the adjacency list of the first graph.
 * @param Rgraph2 An R list representing the adjacency list of the second graph.
 * @param Ri1 An integer representing the index of the vertex in the first graph to be joined.
 * @param Ri2 An integer representing the index of the vertex in the second graph to be joined.
 * @return An R list representing the adjacency list of the joined graph.
 */
SEXP S_join_graphs(SEXP Rgraph1, SEXP Rgraph2, SEXP Ri1, SEXP Ri2) {

    // Basic type sanity checks (fast-fail, defensive)
    if (TYPEOF(Rgraph1) != VECSXP)
        Rf_error("S_join_graphs(): Rgraph1 must be a list (adjacency list).");
    if (TYPEOF(Rgraph2) != VECSXP)
        Rf_error("S_join_graphs(): Rgraph2 must be a list (adjacency list).");

    // Indices — use Rf_asInteger (no need to PROTECT, result is a plain int)
    int i1 = Rf_asInteger(Ri1);
    int i2 = Rf_asInteger(Ri2);
    if (i1 == NA_INTEGER || i2 == NA_INTEGER) {
        Rf_error("S_join_graphs(): i1 and i2 must be valid integers (not NA).");
    }
    if (i1 < 0 || i2 < 0) {
        Rf_error("S_join_graphs(): i1 and i2 must be non-negative.");
    }

    std::vector<std::vector<int>> graph1 = convert_adj_list_from_R(Rgraph1);
    std::vector<std::vector<int>> graph2 = convert_adj_list_from_R(Rgraph2);

    // Core operation
    std::unique_ptr<std::vector<std::vector<int>>> joined_graph = join_graphs(graph1, graph2, i1, i2);
    if (!joined_graph) {
        Rf_error("S_join_graphs(): join_graphs() returned null.");
    }

    SEXP result = PROTECT(convert_vector_vector_int_to_R(*joined_graph));

    UNPROTECT(1);
    return result;
}


/**
 * Creates a star graph by joining chain graphs of specified sizes to a central vertex.
 *
 * This function takes a vector of positive integers representing the sizes of chain graphs
 * and constructs a star graph by joining each chain graph to a central vertex. The resulting
 * star graph consists of a central vertex connected to multiple chains of vertices.
 *
 * @param sizes A vector of positive integers specifying the sizes of the chain graphs to be
 *              joined to the central vertex. Each size represents the number of vertices in
 *              a chain graph.
 * @return A unique pointer to the adjacency list representation of the created star graph.
 *
 * Example usage:
 * @code
 * std::vector<int> sizes = {3, 4, 2};
 * auto star_graph = create_star_graph(sizes);
 * @endcode
 *
 * The resulting `star_graph` will represent a star graph with a central vertex connected to
 * three chain graphs of sizes 3, 4, and 2, respectively.
 *
 * The structure of the star graph will be as follows:
 * - The central vertex will have an index of 0.
 * - The vertices of the first chain graph will have indices 1, 2, and 3.
 * - The vertices of the second chain graph will have indices 4, 5, 6, and 7.
 * - The vertices of the third chain graph will have indices 8 and 9.
 *
 * The adjacency list representation of the star graph will be as follows:
 * - Vertex 0 (central vertex) will be connected to vertices 1, 4, and 8.
 * - Vertices 1, 2, and 3 will form the first chain graph.
 * - Vertices 4, 5, 6, and 7 will form the second chain graph.
 * - Vertices 8 and 9 will form the third chain graph.
 *
 * @note The function uses the `join_graphs` function internally to join the chain graphs
 *       to the central vertex. Make sure to include the necessary header file containing
 *       the `join_graphs` function.
 */
// create_star_graph is not implemented correctly
#if 0
std::unique_ptr<std::vector<std::vector<int>>> create_star_graph(const std::vector<int>& sizes) {
    int num_chains = sizes.size();
    int total_vertices = 0;
    for (int size : sizes) {
        total_vertices += size;
    }

    // Create the central vertex
    auto star_graph = std::make_unique<std::vector<std::vector<int>>>(total_vertices);

    for (int i = 0; i < num_chains; ++i) {
        int chain_size = sizes[i];

        // Create a chain graph
        std::vector<std::vector<int>> chain_graph(chain_size);
        for (int j = 0; j < chain_size - 1; ++j) {
            chain_graph[j].push_back(j + 1);
            chain_graph[j + 1].push_back(j);
        }

        // Join the chain graph to the central vertex
        star_graph = join_graphs(*star_graph, chain_graph, 0, 0);
    }

    return star_graph;
}
#endif

/**
 * An R interface to the create_star_graph function.
 *
 * This function takes an R vector of positive integers representing the sizes of chain graphs
 * and creates a star graph by joining each chain graph to a central vertex. The resulting
 * star graph consists of a central vertex connected to multiple chains of vertices.
 *
 * @param Rsizes An R vector of positive integers specifying the sizes of the chain graphs to be
 *               joined to the central vertex. Each size represents the number of vertices in
 *               a chain graph.
 * @return An R list representing the adjacency list of the created star graph.
 *
 * @note This function is a wrapper around the C++ create_star_graph function and handles
 *       the conversion of R inputs to C++ types and the conversion of the C++ output back
 *       to an R object.
 *
 * Example usage in R:
 * @code
 * sizes <- c(3, 4, 2)
 * star_graph <- .Call("S_create_star_graph", sizes)
 * print(star_graph)
 * @endcode
 *
 * The resulting `star_graph` will be an R list representing the adjacency list of the star
 * graph created by joining chain graphs of the specified sizes to a central vertex.
 *
 * The structure of the star graph will be as follows:
 * - The central vertex will have an index of 1.
 * - The vertices of the first chain graph will have indices 2, 3, and 4.
 * - The vertices of the second chain graph will have indices 5, 6, 7, and 8.
 * - The vertices of the third chain graph will have indices 9 and 10.
 *
 * The adjacency list representation of the star graph will be as follows:
 * - Vertex 1 (central vertex) will be connected to vertices 2, 5, and 9.
 * - Vertices 2, 3, and 4 will form the first chain graph.
 * - Vertices 5, 6, 7, and 8 will form the second chain graph.
 * - Vertices 9 and 10 will form the third chain graph.
 */
// create_star_graph is not implemented correctly
#if 0
SEXP S_create_star_graph(SEXP Rsizes) {
    int n = LENGTH(Rsizes);
    std::vector<int> sizes(n);

    for (int i = 0; i < n; ++i) {
        sizes[i] = INTEGER(Rsizes)[i];
    }

    std::unique_ptr<std::vector<std::vector<int>>> star_graph = create_star_graph(sizes);

    SEXP result = convert_vector_vector_int_to_R(*star_graph);

    UNPROTECT(1);
    return result;
}
#endif


/**
 * @brief Converts an adjacency list representation of a graph to an edge matrix and weight vector
 *
 * This function takes an adjacency list and an optional weight list, and converts them to a list of edges
 * and corresponding weights.
 *
 * @param adj_vect The adjacency list representation of the graph
 * @param weight_list The optional weight list (can be empty)
 * @return A pair of unique pointers: first to a vector of integer pairs representing the edges,
 *         second to a vector of doubles representing the weights
 */
std::pair<std::vector<std::pair<int, int>>, std::vector<double>>
convert_adjacency_to_edge_matrix(const std::vector<std::vector<int>>& adj_vect,
                                 const std::vector<std::vector<double>>& weight_list) {
    std::vector<std::pair<int, int>> edges;
    std::vector<double> weights;
    bool has_weights = !weight_list.empty();
    for (size_t i = 0; i < adj_vect.size(); ++i) {
        for (size_t j = 0; j < adj_vect[i].size(); ++j) {
            int targetNode = adj_vect[i][j];
            if ((int)i <= targetNode) {
                edges.emplace_back(i, targetNode);
                if (has_weights) {
                    weights.push_back(weight_list[i][j]);
                }
            }
        }
    }
    return {std::move(edges), std::move(weights)};
}

SEXP S_convert_adjacency_to_edge_matrix(SEXP s_graph, SEXP s_weights) {
    // ---- Inputs (pure reads; no PROTECT needed) ----
    std::vector<std::vector<int>>    adj_vect    = convert_adj_list_from_R(s_graph);
    std::vector<std::vector<double>> weight_list;
    if (s_weights != R_NilValue) {
        weight_list = convert_weight_list_from_R(s_weights);
        if (!weight_list.empty() && weight_list.size() != adj_vect.size()) {
            Rf_error("weights length must be 0 or equal to adjacency length.");
        }
    }

    // ---- Core computation (no R allocations inside) ----
    // result.first  : vector<pair<int,int>> edges (0-based or 1-based per your core)
    // result.second : vector<double> weights (may be empty for unweighted)
    auto result = convert_adjacency_to_edge_matrix(adj_vect, weight_list);

    // ---- Build return (container-first; per-element protect) ----
    SEXP out = PROTECT(Rf_allocVector(VECSXP, 2));

    // names while `out` is protected
    {
        SEXP nm = PROTECT(Rf_allocVector(STRSXP, 2));
        SET_STRING_ELT(nm, 0, Rf_mkChar("edge.matrix"));
        SET_STRING_ELT(nm, 1, Rf_mkChar("weights"));
        Rf_setAttrib(out, R_NamesSymbol, nm);
        UNPROTECT(1); // nm
    }

    // 0: edge.matrix
    {
        SEXP edges = PROTECT(cpp_vector_of_pairs_to_R_matrix(result.first));
        SET_VECTOR_ELT(out, 0, edges);
        UNPROTECT(1); // edges
    }

    // 1: weights (or NULL)
    if (!result.second.empty()) {
        SEXP w = PROTECT(convert_vector_double_to_R(result.second));
        SET_VECTOR_ELT(out, 1, w);
        UNPROTECT(1); // w
    } else {
        SET_VECTOR_ELT(out, 1, R_NilValue);
    }

    UNPROTECT(1); // out
    return out;
}

/**
 * @brief Converts an adjacency list to an edge matrix using a set for deduplication
 *
 * This function converts an adjacency list to a list of edges, using a set
 * to automatically remove Rf_duplicate edges.
 *
 * @param adj_vect The adjacency list representation of the graph
 * @return A unique pointer to a vector of integer pairs representing the edges
 */
std::unique_ptr<std::vector<std::pair<int, int>>> convert_adjacency_to_edge_matrix_set(
    const std::vector<std::vector<int>>& adj_vect) {

    std::set<std::pair<int, int>> edgeSet;

    for (size_t i = 0; i < adj_vect.size(); ++i) {
        for (int targetNode : adj_vect[i]) {
            edgeSet.emplace(std::min((int)i, targetNode), std::max((int)i, targetNode));
        }
    }

    auto edges = std::make_unique<std::vector<std::pair<int, int>>>(edgeSet.begin(), edgeSet.end());
    return edges;
}

SEXP S_convert_adjacency_to_edge_matrix_set(SEXP s_graph) {
    std::vector<std::vector<int>> adj_vect = convert_adj_list_from_R(s_graph);
    auto result = convert_adjacency_to_edge_matrix_set(adj_vect);
    return uptr_vector_of_pairs_to_R_matrix(result);
}


/**
 * @brief Converts an adjacency list to an edge matrix using an unordered set
 *
 * This function converts an adjacency list to a list of edges, using an
 * unordered set for potentially faster deduplication.
 *
 * @param adj_vect The adjacency list representation of the graph
 * @return A unique pointer to a vector of integer pairs representing the edges
 */
struct PairHash {
    template <class T1, class T2>
    std::size_t operator () (const std::pair<T1, T2>& p) const {
        auto h1 = std::hash<T1>{}(p.first);
        auto h2 = std::hash<T2>{}(p.second);
        return h1 ^ (h2 << 1);
    }
};

std::unique_ptr<std::vector<std::pair<int, int>>> convert_adjacency_to_edge_matrix_unordered_set(
    const std::vector<std::vector<int>>& adj_vect)  {

    std::unordered_set<std::pair<int, int>, PairHash> edgeSet;

    for (size_t i = 0; i < adj_vect.size(); ++i) {
        for (int targetNode : adj_vect[i]) {
            edgeSet.emplace(std::min((int)i, targetNode), std::max((int)i, targetNode));
        }
    }

    auto edges = std::make_unique<std::vector<std::pair<int, int>>>(edgeSet.begin(), edgeSet.end());
    return edges;
}

SEXP S_convert_adjacency_to_edge_matrix_unordered_set(SEXP s_graph) {
    std::vector<std::vector<int>> adj_vect = convert_adj_list_from_R(s_graph);
    auto result = convert_adjacency_to_edge_matrix_unordered_set(adj_vect);
    return uptr_vector_of_pairs_to_R_matrix(result);
}


/**
 * @brief Converts a graph from separate adjacency and int-weight lists to a combined weighted adjacency list format
 *
 * @param adj_vect Input adjacency list where adj_vect[i] contains the indices of vertices adjacent to vertex i
 * @param isize_vect Input weight list where isize_vect[i][j] contains the weight of the edge from vertex i to its j-th neighbor
 * @return std::vector<std::vector<std::pair<int, int>>> Output graph as adjacency list where each edge is represented
 *         as a pair (vertex_index, weight)
 *
 * @details The function combines two separate representations (adjacency and weights) into a single adjacency list
 *          where each edge is represented by a pair of (destination vertex, edge weight). The input vectors must have
 *          compatible dimensions, i.e., adj_vect[i].size() == isize_vect[i].size() for all valid i.
 *
 * @note Input vectors are passed by reference for efficiency but are not modified
 *
 * @Rf_warning No bounds checking is performed on the input vectors. Caller must ensure that adj_vect and isize_vect
 *          have compatible dimensions
 *
 * Example:
 * @code
 * std::vector<std::vector<int>> adj = {{1, 2}, {0}, {0, 1}};  // Adjacency lists
 * std::vector<std::vector<int>> weights = {{5, 3}, {2}, {4, 1}};  // Corresponding weights
 * auto weighted_graph = convert_to_int_weighted_adj_list(adj, weights);
 * // weighted_graph[0] contains pairs: {(1,5), (2,3)}
 * @endcode
 */
std::vector<std::vector<std::pair<int, int>>> convert_to_int_weighted_adj_list(
    const std::vector<std::vector<int>>& adj_vect,
    const std::vector<std::vector<int>>& isize_vect) {
    int n_vertices = adj_vect.size();
    auto iigraph = std::vector<std::vector<std::pair<int, int>>>(n_vertices);
    for (int vertex = 0; vertex < n_vertices; ++vertex) {
        int n_neighbors = adj_vect[vertex].size();
        for (int neighbor = 0; neighbor < n_neighbors; ++neighbor) {
            iigraph[vertex].emplace_back(adj_vect[vertex][neighbor], isize_vect[vertex][neighbor]);
        }
    }
    return iigraph;
}


/**
 * @brief Creates a chain graph with edge lengths from a sequence of points
 *
 * @param x Vector of points that will form vertices in the chain
 * @return std::pair<std::vector<std::vector<int>>, std::vector<std::vector<double>>>
 *         First element: adjacency list where each vertex is connected to its neighbors
 *         Second element: corresponding edge lengths based on absolute differences between points
 */
std::pair<std::vector<std::vector<int>>, std::vector<std::vector<double>>>
create_chain_graph(const std::vector<double>& x) {
    int n_vertices = static_cast<int>(x.size());

    // Create chain graph adjacency list
    std::vector<std::vector<int>> adj_list(n_vertices);
    std::vector<std::vector<double>> edge_lengths(n_vertices);

    // Special cases for empty or single-vertex graphs
    if (n_vertices <= 1) {
        return {adj_list, edge_lengths};
    }

    // Set first vertex
    adj_list[0] = {1};
    edge_lengths[0] = {std::abs(x[0] - x[1])};

    // Set middle vertices
    for (int i = 1; i < n_vertices - 1; ++i) {
        adj_list[i] = {i - 1, i + 1};
        edge_lengths[i] = {std::abs(x[i] - x[i-1]),
                          std::abs(x[i] - x[i+1])};
    }

    // Set last vertex
    adj_list[n_vertices - 1] = {n_vertices - 2};
    edge_lengths[n_vertices - 1] = {std::abs(x[n_vertices-1] - x[n_vertices-2])};

    return {adj_list, edge_lengths};
}

// Helper function to compute all-pairs shortest paths
std::vector<std::vector<double>> compute_all_pairs_shortest_paths(
    const std::vector<std::vector<int>>& adj_list,
    const std::vector<std::vector<double>>& weight_list) {

    size_t n = adj_list.size();
    std::vector<std::vector<double>> dist(n, std::vector<double>(n, std::numeric_limits<double>::infinity()));

    // Initialize distances
    for (size_t i = 0; i < n; ++i) {
        dist[i][i] = 0.0;  // Distance to self is 0
        for (size_t j = 0; j < adj_list[i].size(); ++j) {
            int neighbor = adj_list[i][j];
            dist[i][neighbor] = weight_list[i][j];
        }
    }

    // Floyd-Warshall algorithm
    for (size_t k = 0; k < n; ++k) {
        for (size_t i = 0; i < n; ++i) {
            for (size_t j = 0; j < n; ++j) {
                if (dist[i][k] != std::numeric_limits<double>::infinity() &&
                    dist[k][j] != std::numeric_limits<double>::infinity()) {
                    dist[i][j] = std::min(dist[i][j], dist[i][k] + dist[k][j]);
                }
            }
        }
    }

    return dist;
}
