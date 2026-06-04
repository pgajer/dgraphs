#include <vector>        // For std::vector
#include <algorithm>     // For std::sort
#include <utility>       // For std::pair
#include <cmath>         // For mathematical operations
#include <limits>        // For std::numeric_limits
#include <queue>         // For std::priority_queue
#include <functional>    // For std::greater
#include <mutex>         // For std::mutex
#include <chrono>        // For timing-based progress updates

#include "edge_pruning_stats.hpp" // For edge_pruning_stats_t
#include "set_wgraph.hpp"     // For set_wgraph_t definition
#include "error_utils.h"      // For REPORT_ERROR

#include <R_ext/Print.h>      // For Rprintf, R_FlushConsole

/**
 * @brief Compute the length of the shortest path between two vertices while excluding the direct edge between them
 *
 * This function implements a bidirectional Dijkstra algorithm that finds the shortest path
 * between the vertices of an edge, while ignoring the edge connecting them.
 *
 * @param source The starting vertex index
 * @param target The destination vertex index
 * @return The length of the shortest path from source to target excluding the direct edge.
 *         Returns infinity if no alternative path exists.
 */
double set_wgraph_t::bidirectional_dijkstra_excluding_edge(
    size_t source,
    size_t target) const
{
    const size_t n = adjacency_list.size();

    // Initialize distance arrays for forward and backward search
    std::vector<double> dist_forward(n, std::numeric_limits<double>::infinity());
    std::vector<double> dist_backward(n, std::numeric_limits<double>::infinity());

    dist_forward[source] = 0.0;
    dist_backward[target] = 0.0;

    // Initialize priority queues for forward and backward search
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

            // Relax outgoing edges, excluding the direct edge to target
            for (const auto& edge : adjacency_list[vertex]) {
                size_t neighbor = edge.vertex;

                // Skip the direct edge between source and target
                if (vertex == source && neighbor == target) {
                    continue;
                }

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

            // Relax incoming edges (backward direction), excluding the direct edge from source
            for (const auto& edge : adjacency_list[vertex]) {
                size_t neighbor = edge.vertex;

                // Skip the direct edge between target and source
                if (vertex == target && neighbor == source) {
                    continue;
                }

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


/**
 * @brief Compute statistics for potential edge pruning based on geometric criteria
 *
 * This function analyzes edges longer than a specified threshold (default: median edge length)
 * to determine how pruning each edge would affect the graph's geometry. For each candidate edge,
 * it computes the ratio of the alternative geodesic path length to the original edge length.
 *
 * @param threshold_percentile Percentile threshold for edge Rf_length(0.0-1.0).
 *        Default 0.5 (median). Only edges with length greater than or equal to
 *        the value at this percentile are analyzed.
 * @return edge_pruning_stats_t structure containing statistics for each analyzed edge
 */
edge_pruning_stats_t set_wgraph_t::compute_edge_pruning_stats(double threshold_percentile) const {
    // Structure to represent an edge with source, target, and weight
    struct Edge {
        size_t source;
        size_t target;
        double weight;

        Edge(size_t s, size_t t, double w) : source(s), target(t), weight(w) {}

        bool operator<(const Edge& other) const {
            return weight < other.weight;  // Ascending order for finding median
        }
    };

    // 1. Identify all edges in the graph
    std::vector<Edge> all_edges;
    all_edges.reserve(adjacency_list.size() * 5);  // Rough estimate of edges

    for (size_t vertex = 0; vertex < adjacency_list.size(); ++vertex) {
        std::vector<Edge> local_edges;

        for (const auto& edge_info : adjacency_list[vertex]) {
            size_t target = edge_info.vertex;

            // Only add each edge once (when source < target)
            if (vertex < target) {
                local_edges.emplace_back(vertex, target, edge_info.weight);
            }
        }

        if (!local_edges.empty()) {
            all_edges.insert(all_edges.end(),
                             local_edges.begin(),
                             local_edges.end());
        }
    }

    // Return early if no edges
    if (all_edges.empty()) {
        edge_pruning_stats_t empty_stats;
        empty_stats.median_edge_length = 0.0;
        return empty_stats;
    }

    // 2. Sort edges by weight in ascending order for finding median
    std::sort(all_edges.begin(), all_edges.end());

    // 3. Compute the median edge weight (or other threshold)
    double threshold_weight;
    if (threshold_percentile <= 0.0) {
        threshold_weight = all_edges.front().weight - 1.0;  // Analyze all edges
    } else if (threshold_percentile >= 1.0) {
        threshold_weight = all_edges.back().weight + 1.0;  // Analyze no edges
    } else {
        size_t threshold_index = static_cast<size_t>(all_edges.size() * threshold_percentile);
        threshold_index = std::min(threshold_index, all_edges.size() - 1);
        threshold_weight = all_edges[threshold_index].weight;
    }

    // Initialize result structure
    edge_pruning_stats_t result;
    result.median_edge_length = threshold_weight;

    // 4. Analyze edges longer than or equal to the threshold
    for (const auto& edge : all_edges) {
        if (edge.weight >= threshold_weight) {
            // Find the length of alternative geodesic path (excluding this edge)
            double alt_path_length = bidirectional_dijkstra_excluding_edge(
                edge.source, edge.target);
            
            // Only include edges that have an alternative path
            if (alt_path_length != std::numeric_limits<double>::infinity()) {
                result.stats.emplace_back(
                    edge.source, edge.target, edge.weight, alt_path_length);
            }
        }
    }

    return result;
}

/**
 * @brief Prune edges geometrically based on alternative path ratio
 *
 * This function prunes edges whose alternative geodesic path length is within a specified ratio
 * of the original edge length. This approach preserves the graph's geometric structure while
 * removing redundant edges.
 *
 * @param max_ratio_threshold Maximum acceptable ratio of alternative path length to edge length
 *        (default: 1.2). Edges with ratio <= this value will be pruned.
 * @param threshold_percentile Percentile threshold for edge Rf_length(0.0-1.0).
 *        Default 0.5 (median). Only edges with length greater than or equal to
 *        the value at this percentile are considered for pruning.
 * @return A new set_wgraph_t with redundant edges removed
 */
set_wgraph_t set_wgraph_t::prune_edges_geometrically(
    double max_ratio_threshold,
    double threshold_percentile,
    bool verbose) const
{
    // Compute edge pruning statistics on the original graph.
    // NOTE: These statistics certify that each edge is individually redundant
    // w.r.t. the *original* graph (i.e., has an alternative path in G \ e).
    // However, removing all such edges in a batch can disconnect the graph if
    // alternative paths rely on edges that are also removed.
    //
    // To guarantee connectivity preservation, we prune sequentially and
    // re-check the alternative-path condition in the *current* graph.
    edge_pruning_stats_t stats = compute_edge_pruning_stats(threshold_percentile);

    // Work on a copy of the graph.
    set_wgraph_t pruned_graph(*this);

    // Collect candidate edges from stats (already filtered to long edges by
    // threshold_percentile and to those that have some alternative path in the
    // original graph). We store the original edge length to sort candidates.
    struct candidate_edge_t {
        size_t source;
        size_t target;
        double edge_length;
    };

    std::vector<candidate_edge_t> candidates;
    candidates.reserve(stats.stats.size());
    for (const auto& st : stats.stats) {
        if (st.length_ratio <= max_ratio_threshold) {
            candidates.push_back(candidate_edge_t{st.source, st.target, st.edge_length});
        }
    }

    // Prune longer edges first (tends to remove the most geometrically redundant
    // edges early while preserving short edges that often stabilize local structure).
    std::sort(candidates.begin(), candidates.end(),
              [](const candidate_edge_t& a, const candidate_edge_t& b) {
                  return a.edge_length > b.edge_length;
              });

    const size_t total_candidates = candidates.size();
    size_t removed_edges = 0;
    auto progress_start_time = std::chrono::steady_clock::now();
    auto last_progress_time = progress_start_time;
    const size_t progress_step = std::max<size_t>(1, total_candidates / 200); // ~0.5%

    if (verbose) {
        if (total_candidates == 0) {
            Rprintf("[geometric_prune] no candidate edges to evaluate after prefilter\n");
        } else {
            Rprintf("[geometric_prune] evaluating candidates: 0.0%% (0/%zu), removed 0, ETA --:--",
                    total_candidates);
            R_FlushConsole();
        }
    }

    auto report_progress = [&](size_t processed, bool force) {
        if (!verbose || total_candidates == 0) {
            return;
        }

        const bool step_boundary = (processed % progress_step == 0) || (processed == total_candidates);
        if (!step_boundary && !force) {
            return;
        }

        const auto now = std::chrono::steady_clock::now();
        const bool time_boundary =
            std::chrono::duration_cast<std::chrono::milliseconds>(now - last_progress_time).count() >= 500;
        if (!time_boundary && processed != total_candidates && !force) {
            return;
        }

        const double elapsed = std::chrono::duration<double>(now - progress_start_time).count();
        const double eta_seconds =
            (processed > 0 && elapsed > 0.0)
            ? (elapsed * static_cast<double>(total_candidates - processed) / static_cast<double>(processed))
            : 0.0;
        const int eta_minutes = static_cast<int>(eta_seconds) / 60;
        const int eta_rem_seconds = static_cast<int>(eta_seconds) % 60;
        const double pct = 100.0 * static_cast<double>(processed) / static_cast<double>(total_candidates);
        Rprintf("\r[geometric_prune] evaluating candidates: %.1f%% (%zu/%zu), removed %zu, ETA %02d:%02d",
                pct, processed, total_candidates, removed_edges, eta_minutes, eta_rem_seconds);
        R_FlushConsole();
        last_progress_time = now;
    };

    // Helper: check whether an undirected edge exists in the current graph and
    // retrieve its current weight.
    auto get_edge_weight = [](const set_wgraph_t& g, size_t u, size_t v, double& w_out) -> bool {
        if (u >= g.adjacency_list.size() || v >= g.adjacency_list.size()) return false;
        const auto& nbrs = g.adjacency_list[u];
        for (const auto& e : nbrs) {
            if (e.vertex == v) {
                w_out = e.weight;
                return true;
            }
        }
        return false;
    };

    // Sequential safe pruning: before removing an edge, ensure that an
    // alternative path still exists in the current graph (excluding that edge)
    // and satisfies the ratio threshold.
    for (size_t idx = 0; idx < total_candidates; ++idx) {
        const auto& ce = candidates[idx];
        const size_t processed = idx + 1;
        double w = 0.0;
        if (!get_edge_weight(pruned_graph, ce.source, ce.target, w)) {
            report_progress(processed, false);
            continue; // edge already removed by earlier steps or absent
        }
        if (!(w > 0.0)) {
            report_progress(processed, false);
            continue;
        }

        const double alt_path_length =
            pruned_graph.bidirectional_dijkstra_excluding_edge(ce.source, ce.target);

        if (alt_path_length == std::numeric_limits<double>::infinity()) {
            report_progress(processed, false);
            continue; // removing would disconnect endpoints
        }

        const double ratio = alt_path_length / w;
        if (ratio <= max_ratio_threshold) {
            pruned_graph.remove_edge(ce.source, ce.target);
            ++removed_edges;
        }
        report_progress(processed, false);
    }

    if (verbose && total_candidates > 0) {
        const double elapsed = std::chrono::duration<double>(
            std::chrono::steady_clock::now() - progress_start_time
        ).count();
        Rprintf("\r[geometric_prune] done: 100.0%% (%zu/%zu), removed %zu, elapsed %.1fs\n",
                total_candidates, total_candidates, removed_edges, elapsed);
        R_FlushConsole();
    }

    return pruned_graph;
}

/**
 * @brief Get the list of edges that can be pruned based on a length ratio threshold
 *
 * This method filters the edge statistics to find edges whose alternative path to edge length
 * ratio is below or equal to the specified threshold.
 *
 * @param max_ratio_threshold Maximum acceptable ratio of alternative path length to edge length
 * @return Vector of (source, target) pairs representing prunable edges
 */
std::vector<std::pair<size_t, size_t>> edge_pruning_stats_t::get_prunable_edges(
    double max_ratio_threshold
    ) const {

    std::vector<std::pair<size_t, size_t>> prunable_edges;
    for (const auto& stat : stats) {
        if (stat.length_ratio <= max_ratio_threshold) {
            prunable_edges.emplace_back(stat.source, stat.target);
        }
    }
    return prunable_edges;
}
