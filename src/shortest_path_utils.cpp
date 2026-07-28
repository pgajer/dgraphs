#include <vector>             // For std::vector
#include <algorithm>          // For std::sort, std::reverse
#include <queue>              // For std::priority_queue
#include <utility>            // For std::pair
#include <numeric>            // For std::accumulate

#include "dgraphs/set_wgraph.hpp"     // For set_wgraph_t class definition
#include "dgraphs/error_utils.h"      // For REPORT_ERROR()
#include "dgraphs/kernels.h"
#include "dgraphs/progress_utils.hpp" // for elapsed.time
#include "dgraphs/vertex_info.hpp"

/**
 * @brief Finds all shortest paths within a specified radius that meet a minimum path size requirement
 *
 * This function extends find_graph_paths_within_radius() by adding a filter for path length.
 * It implements a modified version of Dijkstra's algorithm to find all shortest
 * paths from a start vertex to other vertices in the graph, limited by a maximum distance (radius),
 * and ensures all returned paths contain at least min_path_size vertices.
 *
 * The algorithm operates in three phases:
 * 1. A bounded Dijkstra's algorithm to find distances and predecessors
 * 2. Path reconstruction to generate actual paths from the collected information
 * 3. Filtering to retain only paths that meet the minimum size requirement
 *
 * Each vertex in the reachable set is mapped to its position within the shortest path that contains it,
 * allowing efficient lookup and subpath extraction for any reachable vertex.
 *
 * @note The algorithm terminates exploration once vertex distances exceed the radius,
 *       but ensures all possible shorter paths within radius are discovered first
 *
 * @param start The index of the starting vertex
 * @param radius The maximum allowed distance for paths from the start vertex
 * @param min_path_size The minimum number of vertices required in each path
 *
 * @return shortest_paths_t A structure containing:
 *         - paths: Vector of path_t objects, each containing at least min_path_size vertices:
 *           * vertices: Sequence of vertices in the path
 *           * total_weight: Total distance of the path
 *         - reachable_vertices: Set of all vertices reachable within the radius
 *         - vertex_to_path_map: Maps each vertex to its subpath information:
 *           * path_idx: Index of the path containing the vertex
 *           * vertex_idx: Position of the vertex within that path
 *
 * @note If no paths meet the size requirement, the function returns an empty paths vector
 *       but still populates the reachable_vertices set with all vertices within radius
 * @note Paths are returned in descending order of their total weights
 * @note The vertex_to_path_map enables O(1) lookup of any vertex's position within a path,
 *       allowing efficient extraction of subpaths between any reachable vertices
 * @note Each vertex is mapped to the shortest path that contains it when multiple paths are possible
 *
 * @pre The start vertex index must be valid (0 <= start < adjacency_list.size())
 * @pre The radius must be non-negative
 * @pre min_path_size must be at least 2 (to represent a valid path with start and end vertices)
 *
 * @complexity Time: O((V + E) * log V) where V is the number of vertices and E is the number of edges
 *            Space: O(V + E) for storing distances, predecessors, and the result paths
 *
 * @see find_graph_paths_within_radius() The base function without the path size filter
 * @see subpath_t Structure containing path index and vertex position information
 */
shortest_paths_t set_wgraph_t::find_graph_paths_within_radius_and_path_min_size(
    size_t start,
    double radius,
    size_t min_path_size
	) const
{
    // Start with standard path finding
    shortest_paths_t all_paths = find_graph_paths_within_radius(start, radius);

    // Filter for paths that meet minimum size
    shortest_paths_t filtered_paths;
    filtered_paths.reachable_vertices = all_paths.reachable_vertices;

    for (const auto& path : all_paths.paths) {
        if (path.vertices.size() >= min_path_size) {
            filtered_paths.paths.push_back(path);

            // Update vertex_to_path_map for vertices in this path
            for (size_t i = 0; i < path.vertices.size(); ++i) {
                size_t vertex = path.vertices[i];

                // Only add if not already mapped (keep shortest path mapping)
                if (filtered_paths.vertex_to_path_map.find(vertex) ==
                    filtered_paths.vertex_to_path_map.end()) {
                    subpath_t subpath;
                    subpath.path_idx = filtered_paths.paths.size() - 1;
                    subpath.vertex_idx = i;
                    filtered_paths.vertex_to_path_map[vertex] = subpath;
                }
            }
        }
    }

    return filtered_paths;
}

/**
 * @brief Finds all shortest paths within a specified radius from a start vertex
 *
 * This function implements a modified version of Dijkstra's algorithm to find all shortest
 * paths from a start vertex to other vertices in the graph, limited by a maximum distance (radius).
 * The algorithm operates in two phases:
 * 1. A bounded Dijkstra's algorithm to find distances and predecessors
 * 2. Path reconstruction to generate actual paths from the collected information
 *
 * Each vertex in the reachable set is mapped to its position within the shortest path that contains it,
 * allowing efficient lookup and subpath extraction for any reachable vertex.
 *
 * @note The algorithm terminates exploration once vertex distances exceed the radius,
 *       but ensures all possible shorter paths within radius are discovered first
 *
 * @param start The index of the starting vertex
 * @param radius The maximum allowed distance for paths from the start vertex
 *
 * @return shortest_paths_t A structure containing:
 *         - paths: Vector of path_t objects, each containing:
 *           * vertices: Sequence of vertices in the path
 *           * total_weight: Total distance of the path
 *         - reachable_vertices: Set of all vertices reachable within the radius
 *         - vertex_to_path_map: Maps each vertex to its subpath information:
 *           * path_idx: Index of the path containing the vertex
 *           * vertex_idx: Position of the vertex within that path
 *
 * @note Paths are returned in descending order of their total weights
 * @note The vertex_to_path_map enables O(1) lookup of any vertex's position within a path,
 *       allowing efficient extraction of subpaths between any reachable vertices
 * @note Each vertex is mapped to the shortest path that contains it when multiple paths are possible
 *
 * @pre The start vertex index must be valid (0 <= start < adjacency_list.size())
 * @pre The radius must be non-negative
 *
 * @complexity Time: O((V + E) * log V) where V is the number of vertices and E is the number of edges
 *            Space: O(V + E) for storing distances, predecessors, and the result paths
 *
 * @see subpath_t Structure containing path index and vertex position information
 */
shortest_paths_t set_wgraph_t::find_graph_paths_within_radius(
	size_t start,
	double radius
	) const {

	// Run bounded Dijkstra search.
	std::unordered_map<size_t, std::pair<double, int>> dp_map; // dp_map[vertex] = <distance, prev>
    size_t n = adjacency_list.size();
    std::vector<double> dist(n, INFINITY);
    std::vector<int> prev(n, -1);
    dist[start] = 0;

    std::priority_queue<std::pair<double, int>> pq;
    pq.push({0, start});

    while (!pq.empty()) {
        auto top = pq.top();
        double d = -top.first;
        int u = top.second;
        pq.pop();

        if (d > radius) break;
        if (d > dist[u]) continue;

        dp_map.emplace(u, std::pair<double, int>(d, prev[u]));

        for (const auto& edge : adjacency_list[u]) {
            size_t v = edge.vertex;
            double w = edge.weight;

            if (dist[u] + w < dist[v]) {
                dist[v] = dist[u] + w;
                prev[v] = u;
                pq.push({-dist[v], v});
            }
        }
    }

	if (dp_map.empty() || dp_map.size() == 1) {  // Only contains start vertex
		// Handle case where no vertices are reachable within radius
		shortest_paths_t result;
		result.reachable_vertices.insert(start);
		REPORT_WARNING("No vertices are reachable from vertex %zu within radius %f\n",
					   start, radius);
		return result;
	}

	// Construct paths from the predecessor map.
    shortest_paths_t result;

	// Create and sort vertex info
    std::vector<vertex_info_t> vertex_info;
    vertex_info.reserve(dp_map.size());
    for (const auto& [vertex, info] : dp_map) {
        if (vertex != start) {  // exclude start vertex itself
            vertex_info.emplace_back(vertex, info.first);
        }
    }

	// Sort by distance in descending order
    std::sort(vertex_info.begin(), vertex_info.end(),
              [](const vertex_info_t& a, const vertex_info_t& b) {
                  return a.distance > b.distance;
              });

	// result.reachable_vertices will be used to keep track of used vertices to avoid Rf_duplicate paths
    result.reachable_vertices.insert(start);  // start vertex is always used

	// Process vertices in order of decreasing distance
    for (const auto& info : vertex_info) {
		// Skip if this vertex was already used in another path
        if (result.reachable_vertices.count(info.vertex) > 0) {
            continue;
        }

        path_t new_path;
        new_path.total_weight = info.distance;  // distance from start to target

		// Reconstruct the path from this vertex to target
        int curr = (int)info.vertex;
        std::vector<size_t> temp_vertices;
        std::vector<double> temp_distances;

        double curr_distance = info.distance;
        temp_distances.push_back(curr_distance);

        temp_vertices.push_back(curr);
        result.reachable_vertices.insert(curr);  // mark vertex as used

        while (true) {
            auto it = dp_map.find(curr);
            if (it == dp_map.end()) {
                REPORT_ERROR("Path reconstruction failed: vertex not found in path info");
            }

            curr = it->second.second;  // move to predecessor
            if (curr == -1) break;  // reached the start vertex

            double prev_distance = it->second.first;  // distance of predecessor from start
            curr_distance = prev_distance;
            temp_distances.push_back(curr_distance);

            temp_vertices.push_back(curr);
            result.reachable_vertices.insert(curr);  // mark vertex as used
        }

		// Reverse the path to get correct order (from start to end)
        std::reverse(temp_vertices.begin(), temp_vertices.end());
        std::reverse(temp_distances.begin(), temp_distances.end());

        new_path.vertices = std::move(temp_vertices);
        new_path.distances = std::move(temp_distances);

        result.paths.push_back(new_path);
    }

	// Sort paths in the descending order of their total weights
    std::sort(result.paths.begin(), result.paths.end());

	// Now populate the vertex_to_path_map with detailed subpath information
	// We'll process paths from shortest to longest (reverse of how they're sorted)
	// to ensure vertices are mapped to the shortest paths that contain them
    for (int path_idx = result.paths.size() - 1; path_idx >= 0; path_idx--) {
        const auto& path = result.paths[path_idx];

        for (size_t vertex_idx = 1; vertex_idx < path.vertices.size(); vertex_idx++) { // starting from 1 as we are not interested in paths with one vertex
            size_t vertex = path.vertices[vertex_idx];

			// Only add mapping if this vertex doesn't already have one
			// This ensures each vertex is mapped to the shortest path containing it
            if (result.vertex_to_path_map.find(vertex) == result.vertex_to_path_map.end()) {
                subpath_t subpath;
                subpath.path_idx = path_idx;
                subpath.vertex_idx = vertex_idx;

                result.vertex_to_path_map[vertex] = subpath;
            }
        }
    }

    return result;
}

/**
 * @brief Extracts x/y/w values along a geodesic ray path for use in weighted linear models
 *
 * @details For a given path in the graph, this function extracts the distance values,
 * corresponding response values, and calculates kernel weights based on distance from
 * the reference vertex. The weights are normalized so they sum to 1. This function is
 * designed to prepare data for fitting weighted linear models along geodesic rays.
 *
 * The function performs these key steps:
 * 1. Copies the vertices from the path
 * 2. Uses the pre-computed distances from the reference vertex
 * 3. Normalizes distances using the specified factor
 * 4. Applies the globally defined kernel function to calculate weights
 * 5. Normalizes weights to sum to 1
 * 6. Collects response (y) values for each vertex
 *
 * @param[in] y Vector of response values for all vertices in the original graph
 * @param[in] path The path object containing vertex indices, distances, and total weight
 * @param[in] dist_normalization_factor Factor to adjust the normalization of distances
 *
 * @return A gray_xyw_t object containing vertices, distances, response values and weights
 *
 * @note This function assumes that initialize_kernel() has been called to set up the
 * global kernel_fn pointer before this function is called
 *
 * @see initialize_kernel()
 * @see gray_xyw_t
 */
gray_xyw_t set_wgraph_t::get_xyw_along_path(
    const std::vector<double>& y,
    path_t& path,
    double dist_normalization_factor
	) const {
    gray_xyw_t result;

	// Get number of vertices in the path
    size_t n_vertices = path.vertices.size();
    if (n_vertices == 0) {
        return result; // Return empty result for empty path
    }


	// Check that distances and vertices match in length
	if (path.distances.size() != n_vertices) {
		// Handle inconsistent path data
		REPORT_ERROR("Path has inconsistent data: %zu vertices but %zu distances",
					 n_vertices, path.distances.size());
		return result;
	}

	// Use the pre-computed distances directly
    result.x_path = path.distances;

	// Weights centered at the midpoint of the path
	{
		size_t n_path_vertices = result.x_path.size();

		// finding the mid vertex
		size_t ref_index;
		if ((n_path_vertices - 1) % 2 == 0) {
			ref_index = (n_path_vertices - 1) / 2;
		} else {
			ref_index = n_path_vertices / 2;
		}

		// Computing distances from ref_index to all other vertices
		double ref_dist = result.x_path[ref_index];
		std::vector<double> ref_vertex_distances(n_path_vertices);
		for (size_t i = 0; i < n_path_vertices; i++) {
			ref_vertex_distances[i] = std::abs(result.x_path[i] - ref_dist);
		}

		// Normalize distances for kernel function
		double max_dist = std::max(ref_vertex_distances.front(), ref_vertex_distances.back());
		if (max_dist <= 0.0) max_dist = 1.0;          // Safety check

		max_dist *= dist_normalization_factor;        // Apply normalization factor

		for (size_t i = 0; i < n_path_vertices; ++i) {
			ref_vertex_distances[i] /= max_dist;
		}

		// Calculate kernel weights
		result.w_path.resize(n_vertices);
		kernel_fn(ref_vertex_distances.data(), n_path_vertices, result.w_path.data());
	}

	// Normalize weights to sum to 1
    double total_weight = std::accumulate(result.w_path.begin(), result.w_path.end(), 0.0);
    if (total_weight > 0.0) {
        for (size_t i = 0; i < n_vertices; ++i) {
            result.w_path[i] /= total_weight;
        }
    }

	// Extract response values for each vertex in the path
    result.y_path.resize(n_vertices);
    for (size_t i = 0; i < n_vertices; ++i) {
        result.y_path[i] = y[path.vertices[i]];
    }

	// move vertices
    result.vertices = std::move(path.vertices);

    return result;
}


/**
 * @brief Find the minimum bandwidth that ensures at least one geodesic ray has the minimum required size
 *
 * This function performs a binary search to find the smallest bandwidth value for which
 * at least one geodesic ray starting from the specified grid vertex contains at least
 * min_path_size vertices. This is crucial for ensuring sufficient data points for model fitting.
 *
 * The function takes into account the graph's packing radius, ensuring the minimum bandwidth
 * is at least the maximum packing radius to guarantee coverage of all vertices.
 *
 * @param grid_vertex The starting vertex for geodesic rays
 * @param min_path_size Minimum number of vertices required in a geodesic ray
 * @param max_bw_factor Maximum bandwidth as a fraction of graph diameter
 * @param lower_bound_factor Lower bound factor for binary search (default: 0.001)
 * @param precision Precision threshold for terminating binary search (default: 0.001)
 *
 * @return The minimum bandwidth value that satisfies the path size requirement
 *
 * @note The function uses find_graph_paths_within_radius() to discover paths at each bandwidth
 */
double set_wgraph_t::find_minimum_bandwidth(
    size_t grid_vertex,
	double lower_bound,
    double upper_bound,
	size_t min_path_size,
	double precision) const {

	// Check if the lower bound already satisfies the condition
    shortest_paths_t paths = find_graph_paths_within_radius(grid_vertex, lower_bound);
    if (has_sufficient_path_size(paths, min_path_size)) {
        return lower_bound;
    }

	// Check if the upper bound fails to satisfy the condition
    paths = find_graph_paths_within_radius(grid_vertex, upper_bound);
    if (!has_sufficient_path_size(paths, min_path_size)) {
        REPORT_ERROR(
            "No geodesic ray from vertex %zu contains at least %zu vertices "
            "within upper bound %.6g.",
            grid_vertex + 1,
            min_path_size,
            upper_bound
        );
    }

	// Binary search for the minimum bandwidth
    while ((upper_bound - lower_bound) > precision * graph_diameter) {
        double mid = (lower_bound + upper_bound) / 2.0;
        paths = find_graph_paths_within_radius(grid_vertex, mid);

        if (has_sufficient_path_size(paths, min_path_size)) {
			// If condition is satisfied, try a smaller bandwidth
            upper_bound = mid;
        } else {
			// If condition is not satisfied, try a larger bandwidth
            lower_bound = mid;
        }
    }

	// Return the upper bound as the minimum bandwidth that satisfies the condition
    return upper_bound;
}

/**
 * @brief Check if any path in the shortest_paths structure has the minimum required size
 *
 * @param paths The shortest_paths_t structure containing paths
 * @param min_path_size The minimum required path size
 * @return true if at least one path has the minimum size, false otherwise
 */
bool set_wgraph_t::has_sufficient_path_size(
    const shortest_paths_t& paths,
    size_t min_path_size) const {

    for (const auto& path : paths.paths) {
        if (path.vertices.size() >= min_path_size) {
            return true;
        }
    }

    return false;
}
