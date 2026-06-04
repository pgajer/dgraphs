#include <vector>        // For std::vector
#include <algorithm>     // For std::sort, std::for_each
#include <numeric>       // For std::iota
#include <mutex>         // For std::mutex, std::lock_guard
#include <queue>         // For std::queue
#include <unordered_set> // For std::unordered_set
#include <functional>    // For std::function
#include <utility>       // For std::pair
#include <cmath>         // For mathematical operations

#include "exec_policy.hpp"
#include "set_wgraph.hpp"     // For set_wgraph_t definition
#include "error_utils.h"      // For REPORT_ERROR

/**
 * @brief Creates a new graph with long edges pruned while preserving connectivity
 *
 * This function prunes the graph by removing edges with weights greater than threshold_percentile,
 * but only if their endpoints remain connected by alternate paths.
 *
 * The pruning algorithm:
 * 1. Identifies all edges in the graph
 * 2. Sorts edges by weight in descending order
 * 3. Iteratively attempts to remove each edge, starting with the longest
 * 4. For each candidate edge, checks if removing it would disconnect its endpoints
 * 5. Only removes the edge if connectivity is preserved
 * 6. Stops pruning when reaching edges with weights below the median
 *
 * @param threshold_percentile Percentile threshold for pruning (0.0-1.0).
 *        Default 0.5 (median). Lower values prune fewer edges, higher values prune more.
 * @return A new set_wgraph_t with unnecessary long edges removed
 */
set_wgraph_t set_wgraph_t::prune_long_edges(double threshold_percentile) const {
    // Structure to represent an edge with source, target, and weight
    struct Edge {
        size_t source;
        size_t target;
        double weight;

        // Constructor
        Edge(size_t s, size_t t, double w) : source(s), target(t), weight(w) {}

        // Comparison for sorting (descending order)
        bool operator<(const Edge& other) const {
            return weight > other.weight;  // Descending order
        }
    };

    // 1. Identify all edges in the graph
    std::vector<Edge> all_edges;
    all_edges.reserve(adjacency_list.size() * 5);  // Rough estimate of edges

    // Using for_each with parallel execution policy
    std::vector<size_t> vertices(adjacency_list.size());
    std::iota(vertices.begin(), vertices.end(), 0);

    std::mutex edges_mutex;  // Mutex for thread-safe access to all_edges

    gflow::for_each(GFLOW_EXEC_POLICY, vertices.begin(), vertices.end(),
        [this, &all_edges, &edges_mutex](size_t vertex) {
            std::vector<Edge> local_edges;

            for (const auto& edge_info : adjacency_list[vertex]) {
                size_t target = edge_info.vertex;

                // Only add each edge once (when source < target)
                if (vertex < target) {
                    local_edges.emplace_back(vertex, target, edge_info.weight);
                }
            }

            // Thread-safe merging of local edges into all_edges
            if (!local_edges.empty()) {
                std::lock_guard<std::mutex> lock(edges_mutex);
                all_edges.insert(all_edges.end(), local_edges.begin(), local_edges.end());
            }
        }
    );

    // 2. Sort edges by weight in descending order (longest first)
    std::sort(all_edges.begin(), all_edges.end());

    // 3. Compute the median edge weight (or other threshold)
    double threshold_weight;
    if (all_edges.empty()) {
        // Edge case: no edges in graph
        return *this;  // Return a copy of the current graph
    } else if (threshold_percentile <= 0.0) {
        threshold_weight = all_edges.back().weight - 1.0;  // Prune no edges
    } else if (threshold_percentile >= 1.0) {
        threshold_weight = all_edges.front().weight + 1.0;  // Try to prune all edges
    } else {
        size_t threshold_index = static_cast<size_t>(all_edges.size() * threshold_percentile);
        threshold_index = std::min(threshold_index, all_edges.size() - 1);
        threshold_weight = all_edges[threshold_index].weight;
    }

    // 4. Create a copy of the current graph to prune
    set_wgraph_t pruned_graph(*this);

    // 5. Bidirectional BFS function for efficient connectivity checking
    auto are_connected = [](const set_wgraph_t& graph, size_t source, size_t target) -> bool {
        if (source == target) return true;

        const size_t n_vertices = graph.adjacency_list.size();

        // Forward and backward visit tracking
        std::vector<bool> visited_forward(n_vertices, false);
        std::vector<bool> visited_backward(n_vertices, false);

        // Forward and backward BFS queues
        std::queue<size_t> queue_forward;
        std::queue<size_t> queue_backward;

        // Initialize BFS from both ends
        queue_forward.push(source);
        queue_backward.push(target);
        visited_forward[source] = true;
        visited_backward[target] = true;

        // Sets to track visited vertices from each direction
        std::unordered_set<size_t> visited_set_forward{source};
        std::unordered_set<size_t> visited_set_backward{target};

        // Continue until either queue is empty
        while (!queue_forward.empty() && !queue_backward.empty()) {
            // Expand forward search by one level
            size_t forward_size = queue_forward.size();
            for (size_t i = 0; i < forward_size; ++i) {
                size_t current = queue_forward.front();
                queue_forward.pop();

                // Check if we found a meeting point
                if (visited_backward[current]) return true;

                // Expand neighbors
                for (const auto& edge : graph.adjacency_list[current]) {
                    size_t next = edge.vertex;
                    if (!visited_forward[next]) {
                        visited_forward[next] = true;
                        visited_set_forward.insert(next);
                        queue_forward.push(next);

                        // Check if this vertex has been visited from the other direction
                        if (visited_backward[next]) return true;
                    }
                }
            }

            // Expand backward search by one level
            size_t backward_size = queue_backward.size();
            for (size_t i = 0; i < backward_size; ++i) {
                size_t current = queue_backward.front();
                queue_backward.pop();

                // Check if we found a meeting point
                if (visited_forward[current]) return true;

                // Expand neighbors
                for (const auto& edge : graph.adjacency_list[current]) {
                    size_t next = edge.vertex;
                    if (!visited_backward[next]) {
                        visited_backward[next] = true;
                        visited_set_backward.insert(next);
                        queue_backward.push(next);

                        // Check if this vertex has been visited from the other direction
                        if (visited_forward[next]) return true;
                    }
                }
            }

            // Optimization: Always expand the smaller frontier first
            if (queue_forward.size() > queue_backward.size()) {
                std::swap(queue_forward, queue_backward);
                std::swap(visited_forward, visited_backward);
                std::swap(visited_set_forward, visited_set_backward);
            }
        }

        // If we exhaust either direction without finding a connection
        return false;
    };

    // 6. Iteratively try to remove each long edge
    for (const auto& edge : all_edges) {
        // Stop pruning when we reach edges below the threshold
        if (edge.weight < threshold_weight) {
            break;
        }

        // Temporarily remove the edge
        pruned_graph.remove_edge(edge.source, edge.target);

        // Check if the vertices remain connected
        bool remains_connected = are_connected(pruned_graph, edge.source, edge.target);

        // If removing the edge disconnects the vertices, restore it
        if (!remains_connected) {
            // Restore the edge with its original weight
            pruned_graph.add_edge(edge.source, edge.target, edge.weight);
        }
    }

    return pruned_graph;
}

/**
 * @brief Adds an edge between two vertices with the specified weight
 *
 * @param v1 Source vertex
 * @param v2 Target vertex
 * @param weight Edge weight
 */
void set_wgraph_t::add_edge(size_t v1, size_t v2, double weight) {
    // Make sure both vertices are in range
    if (v1 >= adjacency_list.size() || v2 >= adjacency_list.size()) {
        REPORT_ERROR("Vertex index out of range in add_edge");
        return;
    }

    // Add edge in both directions (undirected graph)
    edge_info_t edge1{v2, weight};
    edge_info_t edge2{v1, weight};

    adjacency_list[v1].insert(edge1);
    adjacency_list[v2].insert(edge2);
}
