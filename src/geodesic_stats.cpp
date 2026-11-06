// #include <Rinternals.h>
// #include <R.h>

#include <vector>
#include <unordered_set>
#include <algorithm>
#include <numeric>

#include "dgraphs/exec_policy.hpp"
#include "dgraphs/geodesic_stats.hpp"
#include "dgraphs/uniform_grid_graph.hpp"
#include "dgraphs/error_utils.h"         // For REPORT_ERROR()

/**
 * @brief Calculates Dice-Sørensen similarity indices between composite geodesic paths
 *
 * For each pair of composite paths, this function computes the Dice-Sørensen index:
 * DSI = (2 * |A ∩ B|) / (|A| + |B|)
 *
 * The function handles the case of avoiding duplication of the grid vertex when
 * calculating the intersection of path vertices.
 *
 * @param composite_shortest_paths The composite_shortest_paths_t structure containing paths
 * @return std::vector<double> Vector of Dice-Sørensen indices for all pairs of composite paths
 */
std::vector<double> calculate_path_overlap(const composite_shortest_paths_t& composite_shortest_paths) {
    std::vector<double> overlap_indices;

    // If there are fewer than 2 composite paths, return empty result
    if (composite_shortest_paths.composite_paths.size() < 2) {
        return overlap_indices;
    }

    // Build vertex sets for each composite path
    std::vector<std::unordered_set<size_t>> composite_path_vertices;
    for (const auto& [i, j] : composite_shortest_paths.composite_paths) {
        // Skip invalid paths (e.g., single path cases)
        if (j == INVALID_VERTEX || i >= composite_shortest_paths.paths.size()) {
            continue;
        }

        // Make sure j is also a valid path index
        if (j >= composite_shortest_paths.paths.size()) {
            continue;
        }

        // Get vertices from both paths
        const auto& path_i = composite_shortest_paths.paths[i];
        const auto& path_j = composite_shortest_paths.paths[j];

        // Combine vertices, ensuring no duplicates
        std::unordered_set<size_t> combined_vertices;
        combined_vertices.insert(path_i.vertices.begin(), path_i.vertices.end());
        combined_vertices.insert(path_j.vertices.begin(), path_j.vertices.end());

        composite_path_vertices.push_back(std::move(combined_vertices));
    }

    // If we have fewer than 2 valid composite paths, return empty result
    if (composite_path_vertices.size() < 2) {
        return overlap_indices;
    }

    // Calculate Dice-Sørensen indices for all pairs of composite paths
    for (size_t i = 0; i < composite_path_vertices.size(); i++) {
        for (size_t j = i + 1; j < composite_path_vertices.size(); j++) {
            const auto& vertices_i = composite_path_vertices[i];
            const auto& vertices_j = composite_path_vertices[j];

            // Calculate intersection size
            size_t intersection_size = 0;
            for (const auto& vertex : vertices_i) {
                if (vertices_j.count(vertex) > 0) {
                    intersection_size++;
                }
            }

            // Calculate Dice-Sørensen index
            double dsi = (2.0 * intersection_size) / (vertices_i.size() + vertices_j.size());
            overlap_indices.push_back(dsi);
        }
    }

    return overlap_indices;
}

/**
 * @brief Calculate overlap statistics from a vector of Dice-Sørensen indices
 *
 * Computes statistical measures of overlap including min, percentiles, median, and max
 *
 * @param overlap_indices Vector of Dice-Sørensen indices
 * @return std::vector<double> Vector containing [min, p05, p25, median, p75, p95, max]
 */
std::vector<double> calculate_overlap_statistics(const std::vector<double>& overlap_indices) {
    if (overlap_indices.empty()) {
        return {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0}; // Return zeros for empty input
    }

    // Create a copy that we can sort
    std::vector<double> sorted_indices = overlap_indices;
    std::sort(sorted_indices.begin(), sorted_indices.end());

    const size_t n = sorted_indices.size();

    // Calculate percentiles
    auto get_percentile = [&sorted_indices, n](double p) {
        double pos = p * (n - 1);
        size_t idx = static_cast<size_t>(pos);
        double frac = pos - idx;

        if (idx + 1 < n) {
            return sorted_indices[idx] * (1.0 - frac) + sorted_indices[idx + 1] * frac;
        } else {
            return sorted_indices[idx];
        }
    };

    // Calculate and return statistics
    return {
        sorted_indices.front(),      // min
        get_percentile(0.05),        // 5th percentile
        get_percentile(0.25),        // 25th percentile
        get_percentile(0.5),         // median
        get_percentile(0.75),        // 75th percentile
        get_percentile(0.95),        // 95th percentile
        sorted_indices.back()        // max
    };
}

geodesic_stats_t compute_geodesic_stats(
    const uniform_grid_graph_t& grid_graph,
    double min_radius,
    double max_radius,
    size_t n_steps,
    bool verbose
) {
    geodesic_stats_t stats;

    // Ensure graph diameter is available
    double graph_diameter = grid_graph.graph_diameter;
    if (graph_diameter <= 0) {
        // Find diameter if not already set
        auto [end1, diam] = grid_graph.get_vertex_eccentricity(0);  // Start from vertex 0
        auto [end2, diameter] = grid_graph.get_vertex_eccentricity(end1);
        graph_diameter = diameter;
    }

    // Calculate radius steps
    double radius_step = (max_radius - min_radius) / std::max(n_steps - 1, size_t(1));
    stats.radii.resize(n_steps);
    for (size_t i = 0; i < n_steps; ++i) {
        stats.radii[i] = (min_radius + i * radius_step) * graph_diameter;
    }

    // Initialize storage
    stats.geodesic_rays.resize(n_steps);
    stats.composite_geodesics.resize(n_steps);
    stats.paths_overlap.resize(n_steps);
    stats.radius_overlaps.resize(n_steps);

    // Convert grid_vertices to vector for parallelization
    std::vector<size_t> grid_verts(grid_graph.grid_vertices.begin(), grid_graph.grid_vertices.end());

    if (verbose) {
        Rprintf("Gather geodesic stats in graph of diameter %.3f\n", graph_diameter);
    }

    // Process each radius
    for (size_t r = 0; r < n_steps; ++r) {
        double radius = stats.radii[r];

        // Temporary container to collect all DSI values for this radius
        std::vector<double> all_overlaps;

        if (verbose) {
            Rprintf("Processing radius %.2f (%zu/%zu)...\n", radius, r+1, n_steps);
        }

        for (size_t idx = 0; idx < grid_verts.size(); ++idx) {
            size_t grid_vertex = grid_verts[idx];

            // Find shortest paths within radius
            shortest_paths_t shortest_paths =
                grid_graph.find_graph_paths_within_radius(grid_vertex, radius);
            composite_shortest_paths_t composite_shortest_paths(shortest_paths);

            // Record number of geodesic rays
            stats.geodesic_rays[r][grid_vertex] = shortest_paths.paths.size();

            // Calculate composite geodesics
            size_t composite_geodesic_count = 0;
            for (size_t i = 0; i < shortest_paths.paths.size(); ++i) {
                for (size_t j = i + 1; j < shortest_paths.paths.size(); ++j) {
                    if (grid_graph.is_composite_path_geodesic(i, j, shortest_paths)) {
                        composite_shortest_paths.add_composite_shortest_path(i, j);
                        ++composite_geodesic_count;
                    }
                }
            }
            stats.composite_geodesics[r][grid_vertex] = composite_geodesic_count;

            // Calculate path overlap statistics
            if (composite_geodesic_count >= 2) {
                auto overlap_indices = calculate_path_overlap(composite_shortest_paths);

                if (!overlap_indices.empty()) {
                    // In serial mode, no lock needed
                    all_overlaps.insert(all_overlaps.end(),
                                        overlap_indices.begin(),
                                        overlap_indices.end());

                    auto overlap_stats_vec = calculate_overlap_statistics(overlap_indices);
                    overlap_stats_t overlap_stats(overlap_stats_vec);
                    stats.paths_overlap[r][grid_vertex] = overlap_stats;
                } else {
                    stats.paths_overlap[r][grid_vertex] = overlap_stats_t();
                }
            } else {
                stats.paths_overlap[r][grid_vertex] = overlap_stats_t();
            }
        }

        // Store all collected overlap values for this radius
        stats.radius_overlaps[r] = std::move(all_overlaps);

        if (verbose) {
            // Compute some statistics for this radius
            size_t avg_paths = 0;
            size_t max_paths = 0;
            for (const auto& [vertex, count] : stats.geodesic_rays[r]) {
                avg_paths += count;
                max_paths = std::max(max_paths, count);
            }
            avg_paths = avg_paths / std::max(size_t(1), stats.geodesic_rays[r].size());

            Rprintf("  Radius %.2f: Avg rays per vertex: %zu, Max rays: %zu\n",
                    radius, avg_paths, max_paths);
        }
    }

    return stats;
}

std::vector<std::tuple<double, size_t, size_t, overlap_stats_t>> compute_vertex_geodesic_stats(
    const uniform_grid_graph_t& grid_graph,
    size_t grid_vertex,
    double min_radius,
    double max_radius,
    size_t n_steps
) {
    std::vector<std::tuple<double, size_t, size_t, overlap_stats_t>> results;

    // Ensure grid_vertex is valid
    if (grid_graph.grid_vertices.find(grid_vertex) == grid_graph.grid_vertices.end()) {
        return results;
    }

    double graph_diameter = grid_graph.graph_diameter;
    if (graph_diameter <= 0) {
        // Find diameter if not already set
        auto [end1, diam] = grid_graph.get_vertex_eccentricity(0);  // Start from vertex 0
        auto [end2, diameter] = grid_graph.get_vertex_eccentricity(end1);
        graph_diameter = diameter;
    }

    // Calculate radius steps
    double radius_step = (max_radius - min_radius) / std::max(n_steps - 1, size_t(1));
    std::vector<double> radii(n_steps);
    for (size_t i = 0; i < n_steps; ++i) {
        radii[i] = (min_radius + i * radius_step) * graph_diameter;
    }

    // Process each radius
    for (double radius : radii) {
        // Find shortest paths within radius
        shortest_paths_t shortest_paths = grid_graph.find_graph_paths_within_radius(grid_vertex, radius);
        composite_shortest_paths_t composite_shortest_paths(shortest_paths);

        // Calculate number of geodesic rays
        size_t geodesic_rays_count = shortest_paths.paths.size();

        // Calculate number of composite geodesics
        size_t composite_geodesics_count = 0;
        for (size_t i = 0; i < shortest_paths.paths.size(); i++) {
            for (size_t j = i + 1; j < shortest_paths.paths.size(); j++) {
                if (grid_graph.is_composite_path_geodesic(i, j, shortest_paths)) {
                    composite_shortest_paths.add_composite_shortest_path(i, j);
                    composite_geodesics_count++;
                }
            }
        }

        // Calculate overlap statistics
        overlap_stats_t overlap_stats;
        if (composite_geodesics_count >= 2) {
            auto overlap_indices = calculate_path_overlap(composite_shortest_paths);
            if (!overlap_indices.empty()) {
                auto overlap_stats_vec = calculate_overlap_statistics(overlap_indices);
                overlap_stats = overlap_stats_t(overlap_stats_vec);
            }
        }

        // Store results: radius, geodesic_rays_count, composite_geodesics_count, overlap_stats
        results.emplace_back(radius, geodesic_rays_count, composite_geodesics_count, overlap_stats);
    }

    return results;
}
