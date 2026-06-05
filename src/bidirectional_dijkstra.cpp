#include <vector>             // For std::vector
#include <queue>              // For std::priority_queue
#include <utility>            // For std::pair
#include <functional>         // For std::greater
#include <limits>             // For std::numeric_limits
#include <cmath>              // For std::fabs

#include "dgraphs/set_wgraph.hpp"     // For set_wgraph_t class definition
#include "dgraphs/error_utils.h"      // For REPORT_ERROR()

/**
 * @brief Determines if a composite path formed by joining two paths is a geodesic
 *
 * This function checks whether the composite path formed by joining path[i] with the reverse
 * of path[j] is a geodesic (shortest path) between its endpoints. The function uses a
 * bidirectional Dijkstra algorithm to efficiently compute the shortest path length.
 *
 * The composite path γ ∘ (γ')^(-1) starts at the first vertex of path[i], follows path[i]
 * to its end, and then follows path[j] in reverse from its end to its start.
 *
 * @param i Index of the first path in shortest_paths.paths
 * @param j Index of the second path in shortest_paths.paths
 * @param shortest_paths The structure containing paths and related information
 *
 * @return true if the composite path is a geodesic (shortest path), false otherwise
 *
 * @note The function allows for small floating-point differences (< 1e-10) when comparing path lengths
 * @note The function returns false for invalid indices or empty paths
 *
 * @see find_graph_paths_within_radius Function that generates the shortest_paths structure
 *
 * @complexity Time: O((V + E) * log V) where V is the number of vertices and E is the number of edges
 */
bool set_wgraph_t::is_composite_path_geodesic(size_t i, size_t j, const shortest_paths_t& shortest_paths) const {
    // Validate input indices
    if (i >= shortest_paths.paths.size() || j >= shortest_paths.paths.size()) {
        return false;
    }

    const auto& path_i = shortest_paths.paths[i];
    const auto& path_j = shortest_paths.paths[j];

    // Check for empty paths
    if (path_i.vertices.empty() || path_j.vertices.empty()) {
        return false;
    }

    // Get endpoints of the composite path
    size_t source = path_i.vertices.front();
    size_t target = path_j.vertices.front();

    if (source == target) {
        return true;  // Trivial case: same endpoints
    }

    // Calculate length of the composite path
    double composite_length = path_i.total_weight + path_j.total_weight;

    // Find the shortest path length using bidirectional Dijkstra
    double shortest_length = bidirectional_dijkstra(source, target);

    // The composite path is a geodesic if its length equals the shortest path length
    return std::fabs(composite_length - shortest_length) < 1e-10;
}

/**
 * @brief Computes the shortest path length between two vertices using bidirectional Dijkstra's algorithm
 *
 * This function implements the bidirectional Dijkstra algorithm, which simultaneously runs two
 * Dijkstra searches: one forward from the source vertex and one backward from the target vertex.
 * The algorithm terminates when the searches meet, finding the shortest path between the vertices.
 *
 * The bidirectional approach typically explores a smaller portion of the graph compared to the
 * standard Dijkstra algorithm, making it more efficient for finding the shortest path between
 * a specific pair of vertices.
 *
 * @param source The starting vertex index
 * @param target The destination vertex index
 *
 * @return The Rf_length(total weight) of the shortest path from source to target.
 *         Returns infinity if no path exists between the vertices.
 *
 * @note This implementation optimizes for finding the shortest path length only.
 *       It does not reconstruct the actual path vertices.
 * @note The algorithm handles undirected graphs, using the same adjacency list
 *       for both forward and backward searches.
 *
 * @pre The source and target vertices must be valid indices in the graph
 *      (0 <= source, target < adjacency_list.size())
 * @pre Edge weights in the graph must be non-negative
 *
 * @see is_composite_path_geodesic Function that uses this algorithm to verify geodesic properties
 *
 * @complexity Time: O((V + E) * log V) where V is the number of vertices and E is the number of edges
 *            Space: O(V) for distance arrays and priority queues
 */
double set_wgraph_t::bidirectional_dijkstra(size_t source, size_t target) const {
    const size_t n = adjacency_list.size();

    // Initialize distance arrays for forward and backward search
    std::vector<double> dist_forward(n, std::numeric_limits<double>::infinity());
    std::vector<double> dist_backward(n, std::numeric_limits<double>::infinity());

    dist_forward[source] = 0.0;
    dist_backward[target] = 0.0;

    // Initialize priority queues for forward and backward search
    // Using min-heap (pair.first is distance, pair.second is vertex)
    std::priority_queue<
        std::pair<double, size_t>,
        std::vector<std::pair<double, size_t>>,
        std::greater<std::pair<double, size_t>>
    > pq_forward, pq_backward;

    pq_forward.push({0.0, source});
    pq_backward.push({0.0, target});

    // Track visited vertices in both directions
    std::vector<bool> visited_forward(n, false);
    std::vector<bool> visited_backward(n, false);

    // Best path length found so far
    double best_path_length = std::numeric_limits<double>::infinity();

    // Main bidirectional search loop
    while (!pq_forward.empty() && !pq_backward.empty()) {
        // Check termination condition
        if (best_path_length <= pq_forward.top().first + pq_backward.top().first) {
            break;  // No better path possible
        }

        // Process forward direction
        {
            auto [dist, vertex] = pq_forward.top();
            pq_forward.pop();

            if (visited_forward[vertex]) continue;
            visited_forward[vertex] = true;

            // Check if this vertex has been reached from both directions
            if (dist_backward[vertex] != std::numeric_limits<double>::infinity()) {
                double path_length = dist_forward[vertex] + dist_backward[vertex];
                if (path_length < best_path_length) {
                    best_path_length = path_length;
                }
            }

            // Relax outgoing edges
            for (const auto& edge : adjacency_list[vertex]) {
                size_t neighbor = edge.vertex;
                double weight = edge.weight;

                if (dist_forward[vertex] + weight < dist_forward[neighbor]) {
                    dist_forward[neighbor] = dist_forward[vertex] + weight;
                    pq_forward.push({dist_forward[neighbor], neighbor});
                }
            }
        }

        // Process backward direction
        {
            auto [dist, vertex] = pq_backward.top();
            pq_backward.pop();

            if (visited_backward[vertex]) continue;
            visited_backward[vertex] = true;

            // Check if this vertex has been reached from both directions
            if (dist_forward[vertex] != std::numeric_limits<double>::infinity()) {
                double path_length = dist_forward[vertex] + dist_backward[vertex];
                if (path_length < best_path_length) {
                    best_path_length = path_length;
                }
            }

            // Relax incoming edges (backward direction)
            for (const auto& edge : adjacency_list[vertex]) {
                size_t neighbor = edge.vertex;
                double weight = edge.weight;

                if (dist_backward[vertex] + weight < dist_backward[neighbor]) {
                    dist_backward[neighbor] = dist_backward[vertex] + weight;
                    pq_backward.push({dist_backward[neighbor], neighbor});
                }
            }
        }
    }

    return best_path_length;
}
