#include <utility>        // For std::pair return type
#include <queue>
#include <vector>
#include <string>
#include <fstream>
#include <sstream>
#include <ctime>
#include <iomanip>
#include <cstdlib>  // For getenv
#include <R.h>      // For Rprintf

#include "cpp_utils.hpp"
#include "set_wgraph.hpp"
#include "uniform_grid_graph.hpp"
#include "error_utils.h"  // for REPORT_ERROR()
// #include "SEXP_cpp_conversion_utils.hpp"

/**
 * @brief Finds a vertex that is at least epsilon away from all vertices in the packing
 *
 * @param adj_list Adjacency list representation of the graph
 * @param weight_list Edge weights corresponding to the adjacency list
 * @param packing Current set of vertices in the packing
 * @param epsilon Minimum distance required between any two packing vertices
 * @param start_search_from Vertex to start the search from (optional)
 *
 * @return size_t Index of a suitable vertex, or SIZE_MAX if none found
 */
size_t find_distant_vertex(
	const std::vector<std::vector<int>>& adj_list,
	const std::vector<std::vector<double>>& weight_list,
	const std::unordered_set<size_t>& packing,
	double epsilon,
	size_t start_search_from = 0) {

	size_t n = adj_list.size();

	// Track minimum distance from any packing vertex to each vertex
	std::vector<double> min_dist_from_packing(n, std::numeric_limits<double>::infinity());

	// For each packing vertex, run a modified Dijkstra's algorithm
	for (size_t source : packing) {
		// Standard Dijkstra initialization
		std::vector<double> dist(n, std::numeric_limits<double>::infinity());
		std::vector<bool> visited(n, false);
		dist[source] = 0.0;

		// Priority queue for Dijkstra: pairs of (distance, vertex)
		std::priority_queue<std::pair<double, size_t>,
							std::vector<std::pair<double, size_t>>,
							std::greater<std::pair<double, size_t>>> pq;
		pq.push({0.0, source});

		while (!pq.empty()) {
			double curr_dist = pq.top().first;
			size_t curr = pq.top().second;
			pq.pop();

			// If we've already processed this vertex or we're beyond epsilon
			if (visited[curr] || curr_dist > epsilon) {
				continue;
			}

			visited[curr] = true;

			// Update the minimum distance from any packing vertex
			min_dist_from_packing[curr] = std::min(min_dist_from_packing[curr], curr_dist);

			// If this vertex's minimum distance is now below epsilon, we don't need
			// to explore its neighbors (it can't be part of the packing)
			if (min_dist_from_packing[curr] < epsilon) {
				continue;
			}

			// Explore neighbors
			for (size_t i = 0; i < adj_list[curr].size(); ++i) {
				int next = adj_list[curr][i];
				double weight = weight_list[curr][i];

				if (!visited[next] && curr_dist + weight < dist[next]) {
					dist[next] = curr_dist + weight;
					pq.push({dist[next], next});
				}
			}
		}
	}

	// Find a vertex that is at least epsilon away from all packing vertices
	// Start searching from start_search_from to avoid always picking the same vertices
	for (size_t i = 0; i < n; ++i) {
		size_t v = (i + start_search_from) % n;
		if (min_dist_from_packing[v] >= epsilon && packing.find(v) == packing.end()) {
			return v;
		}
	}

	// No suitable vertex found
	return SIZE_MAX;
}

/**
 * @brief Finds the vertex with smallest distance exceeding the specified radius from start
 *
 * @details This function implements a modified Dijkstra's algorithm to find vertices within
 * a given radius from the start vertex, while simultaneously identifying vertices that lie
 * just beyond this radius (boundary vertices). After completing the search within the radius,
 * it returns the boundary vertex with the smallest distance.
 *
 * For a path-connected graph with positive edge weights, this function will always find the
 * first vertex outside the radius if such a vertex exists. The function uses standard Dijkstra's
 * algorithm for vertices within the radius, but does not enqueue vertices whose distances exceed
 * the radius - instead, it tracks them separately as boundary vertices.
 *
 * @param start The index of the starting vertex
 * @param radius The maximum distance threshold from the start vertex
 *
 * @return A pair containing:
 * - First: The index of the vertex with the smallest distance exceeding the radius
 * - Second: The shortest path distance from start to this vertex
 * If no vertex exists outside the radius (e.g., in a finite graph where all vertices
 * are within radius), returns {INVALID_VERTEX, INFINITY}
 *
 * @pre The graph must have non-negative edge weights (required for Dijkstra's algorithm)
 * @pre start must be a valid vertex index (0 <= start < adjacency_list.size())
 *
 * @see find_grid_paths_within_radius() - For finding all vertices within a given radius
 * @see compute_reachability_map() - For general reachability analysis
 *
 * @note Time complexity: O((V+E)log V) where V is the number of vertices and E is the number of edges
 * @note Space complexity: O(V) for storing distances, predecessors, and boundary vertices
 */
std::pair<size_t, double> set_wgraph_t::find_first_vertex_outside_radius(
	size_t start,
	double radius) const {

	std::vector<double> dist(adjacency_list.size(), INFINITY);
	std::vector<size_t> prev(adjacency_list.size(), INVALID_VERTEX);
	dist[start] = 0;

	// To track vertices that are directly connected to vertices within radius
	// but themselves lie outside the radius
	std::unordered_map<size_t, double> boundary_vertices;

	// Standard Dijkstra's implementation to find all vertices within radius
	std::priority_queue<std::pair<double, size_t>> pq;
	pq.push({0, start});

	while (!pq.empty()) {
		auto top = pq.top();
		double d = -top.first;
		size_t u = top.second;
		pq.pop();

		// Skip outdated entries
		if (d > dist[u]) continue;

		// Explore neighbors of u
		for (const auto& edge : adjacency_list[u]) {
			size_t v = edge.vertex;
			double w = edge.weight;
			double new_dist = dist[u] + w;

			if (new_dist < dist[v]) {
				dist[v] = new_dist;
				prev[v] = u;

				if (new_dist < radius) {
					// This vertex is within radius, so process it normally
					pq.push({-new_dist, v});

					// If it was previously thought to be outside radius, remove it
					boundary_vertices.erase(v);
				} else {
					// This vertex is outside radius, mark it as a boundary vertex
					boundary_vertices[v] = new_dist;
				}
			}
		}
	}

	// Find the boundary vertex with the smallest distance
	size_t closest_outside = INVALID_VERTEX;
	double min_dist = INFINITY;

	for (const auto& [vertex, distance] : boundary_vertices) {
		if (distance < min_dist) {
			min_dist = distance;
			closest_outside = vertex;
		}
	}

	return {closest_outside, min_dist};
}



/**
 * @brief Finds the first unexplored vertex beyond a specified radius
 *
 * @details This function implements a modified Dijkstra's algorithm to find vertices
 * within a given radius from the start vertex, while also identifying vertices that
 * lie just beyond this radius. It specifically searches for vertices that:
 * 1. Are at a distance greater than the specified radius from the start vertex
 * 2. Have not yet been marked as "explored" in the provided tracker
 *
 * The function is a key component in constructing a maximal ε-packing, as it identifies
 * candidates for inclusion in the packing that satisfy the minimum distance constraint.
 *
 * @param start Starting vertex index for the search
 * @param radius Distance threshold (ε) to consider
 * @param explored_tracker Reference to a tracker of vertices already explored
 *
 * @return A pair containing:
 * - First: The index of the unexplored vertex with smallest distance exceeding radius
 * - Second: The shortest path distance from start to this vertex
 * If no suitable vertex exists, returns {INVALID_VERTEX, INFINITY}
 *
 * @pre The graph must have non-negative edge weights
 * @pre start must be a valid vertex index
 * @pre radius must be positive
 *
 * @note This function updates the explored_tracker by marking vertices within radius
 *   as explored, as well as marking the returned vertex (if any) as explored
 * @note Time complexity: O((V+E)log V) where V is the number of vertices and E is the number of edges
 * @note Space complexity: O(V) for the distance vector, predecessor vector, and boundary vertices map
 */
std::pair<size_t, double> set_wgraph_t::find_first_vertex_outside_radius(
	size_t start,
	double radius,
	explored_tracker_t& explored_tracker
	) const {
	std::vector<double> dist(adjacency_list.size(), INFINITY);
	std::vector<size_t> prev(adjacency_list.size(), INVALID_VERTEX);
	dist[start] = 0;

	std::unordered_map<size_t, double> boundary_vertices;
	std::priority_queue<std::pair<double, size_t>> pq;
	pq.push({0, start});

	while (!pq.empty()) {
		auto top = pq.top();
		double d = -top.first;
		size_t u = top.second;
		pq.pop();

		if (d > dist[u]) continue;

		for (const auto& edge : adjacency_list[u]) {
			size_t v = edge.vertex;
			double w = edge.weight;
			double new_dist = dist[u] + w;

			if (new_dist < dist[v]) {
				dist[v] = new_dist;
				prev[v] = u;

				if (new_dist < radius) {
					if (!explored_tracker.is_explored(v)) {
						pq.push({-new_dist, v});
						boundary_vertices.erase(v);
						explored_tracker.explored[v] = true;
						explored_tracker.n_explored++;
					}
				} else if (!explored_tracker.is_explored(v)) {
					boundary_vertices[v] = new_dist;
				}
			}
		}
	}

	size_t closest_outside = INVALID_VERTEX;
	double min_dist = INFINITY;

	for (const auto& [vertex, distance] : boundary_vertices) {
		if (distance < min_dist && !explored_tracker.is_explored(vertex)) {
			min_dist = distance;
			closest_outside = vertex;
		}
	}

	if (closest_outside != INVALID_VERTEX) {
		explored_tracker.explored[closest_outside] = true;
		explored_tracker.n_explored++;
	}

	return {closest_outside, min_dist};
}


/**
 * @brief Identifies vertices that lie just outside a specified radius from a start vertex
 *
 * @details This function implements a modified Dijkstra's algorithm to find vertices that
 * are the first encountered beyond a specified radius from the start vertex. These "boundary
 * vertices" represent the frontier of unexplored territory in the graph.
 *
 * The algorithm works by:
 * 1. Running a Dijkstra's shortest path algorithm from the start vertex
 * 2. Categorizing vertices based on their distance from start:
 *- Vertices within radius: marked as explored and queued for further expansion
 *- Vertices beyond radius: collected as boundary vertices if not already explored
 * 3. Tracking the explored status of vertices using the provided tracker
 *
 * This function is particularly useful in graph-based region growing algorithms, partitioning,
 * and the ε-packing algorithm, where incremental exploration with clear boundaries is needed.
 *
 * @param start The index of the starting vertex from which distances are measured
 * @param radius The distance threshold that defines the boundary (in the same units as edge weights)
 * @param explored_tracker Reference to a tracker object that maintains the exploration status of vertices
 *
 * @return A vector of vertex indices that lie just outside the specified radius.
 * If no boundary vertices are found, returns a vector containing INVALID_VERTEX
 *
 * @note The function updates the explored_tracker in-place, marking both vertices within
 *   the radius and boundary vertices as "explored"
 *
 * @see explored_tracker_t
 *
 * @time_complexity O((V + E) log V) where V is the number of vertices and E is the number of edges
 * @space_complexity O(V) for the distance and predecessor vectors
 */
std::vector<size_t> set_wgraph_t::find_boundary_vertices_outside_radius(
	size_t start,
	double radius,
	explored_tracker_t& explored_tracker
	) const {

	// Initialize distance array and priority queue
	std::vector<double> dist(adjacency_list.size(), INFINITY);
	std::vector<size_t> prev(adjacency_list.size(), INVALID_VERTEX);
	dist[start] = 0;

	std::priority_queue<std::pair<double, size_t>,
						std::vector<std::pair<double, size_t>>,
						std::greater<>> pq;
	pq.push({0, start});

	// Track boundary vertices
	std::unordered_map<size_t, double> boundary_vertices_map;

	// Main Dijkstra loop with early termination
	while (!pq.empty()) {
		auto [current_dist, u] = pq.top();
		pq.pop();

		// Early termination: if the minimum distance in the queue exceeds radius,
		// we've found all vertices strictly inside the radius
		if (current_dist > radius) {
			break;   // All remaining vertices are beyond our radius
		}

		// Skip outdated entries
		if (current_dist > dist[u]) continue;

		// Mark this vertex as explored
		if (!explored_tracker.is_explored(u)) {
			explored_tracker.explored[u] = true;
			explored_tracker.n_explored++;
		}

		// Process neighbors
		for (const auto& edge : adjacency_list[u]) {
			size_t v = edge.vertex;
			double w = edge.weight;
			double new_dist = dist[u] + w;

			// Update distance if shorter path found
			if (new_dist < dist[v]) {
				dist[v] = new_dist;
				prev[v] = u;

				// If this vertex is within radius, add to priority queue for further exploration
				if (new_dist <= radius) {
					pq.push({new_dist, v});
				}
				// Otherwise, it's potentially a boundary vertex (just outside radius)
				else if (!explored_tracker.is_explored(v)) {
					// Since u is within radius (we know this because we're processing u)
					// and v is outside radius, v is a boundary vertex
					boundary_vertices_map[v] = new_dist;
				}
			}
		}
	}

	// Convert boundary map to vector
	std::vector<size_t> boundary_vertices;
	boundary_vertices.reserve(boundary_vertices_map.size());
	for (const auto& [vertex, distance] : boundary_vertices_map) {
		boundary_vertices.push_back(vertex);
	}

	return boundary_vertices;
}

/**
 * @brief Computes the shortest‐path distance between two vertices in a weighted graph.
 *
 * Uses Dijkstra’s algorithm with a min‐heap and early exit once the target is reached.
 * Assumes all edge weights are nonnegative.
 *
 * @note Time complexity is O(E log V) where E is the number of edges and
 *   V is the number of vertices in the graph. This function uses a
 *   priority queue-based implementation of Dijkstra's algorithm for
 *   optimal performance.
 *
 * @param from  Index of the source vertex
 * @param to    Index of the target vertex
 * @return      The length of the shortest path, or +∞ if none exists
 */
double set_wgraph_t::compute_shortest_path_distance(
	size_t from,
	size_t to
	) const {
	// Initialize distances to +∞ and mark source distance = 0
	std::vector<double> dist(adjacency_list.size(),
							 std::numeric_limits<double>::infinity());
	dist[from] = 0.0;

	// Min‐heap of (tentative_distance, vertex_index)
	using Pair = std::pair<double, size_t>;
	std::priority_queue<Pair, std::vector<Pair>, std::greater<Pair>> pq;
	pq.push({0.0, from});

	while (!pq.empty()) {
		auto [d, u] = pq.top();
		pq.pop();

		// If we popped the target, its distance is finalized
		if (u == to)
			return d;

		// Skip any stale pair
		if (d > dist[u])
			continue;

		// Relax outgoing edges
		for (const auto& edge : adjacency_list[u]) {
			size_t v = edge.vertex;
			double w = edge.weight;
			double alt = d + w;
			if (alt < dist[v]) {
				dist[v] = alt;
				pq.push({alt, v});
			}
		}
	}

	// Unreachable
	return std::numeric_limits<double>::infinity();
}

/**
 * @brief Constructs a maximal ε-packing of the graph using a breadth-first exploration approach
 *
 * @details A maximal ε-packing P(ε) is a set of vertices such that:
 * 1. For any two vertices v,u in P(ε), the shortest path distance d(v,u) is at least ε
 * 2. No additional vertex can be added to P(ε) while maintaining property 1
 *
 * This function builds such a packing using a breadth-first exploration strategy:
 * 1. Starting with an initial vertex in the packing
 * 2. Identifying all "boundary vertices" that lie just outside radius ε from the current packing
 * 3. Maintaining these boundary vertices in a queue for systematic exploration
 * 4. Iteratively selecting vertices from this queue to add to the packing
 * 5. For each new packing vertex, discovering additional boundary vertices
 * 6. Continuing until the queue is empty or all vertices have been explored
 *
 * This approach ensures comprehensive exploration of the graph in all directions,
 * avoiding the limitation of linear path following that can occur in graphs with
 * multiple diverging branches (like star graphs).
 *
 * @param radius The minimum distance (ε) required between any two packing vertices
 * @param start_vertex The initial vertex to include in the packing
 *
 * @return A vector containing the indices of vertices in the maximal ε-packing
 *
 * @pre The graph must be path-connected
 * @pre The graph must have non-negative edge weights
 * @pre start_vertex must be a valid vertex index
 * @pre radius must be positive
 *
 * @note The resulting packing is maximal but not necessarily maximum (optimal)
 * @note Different starting vertices may yield different maximal packings
 * @note Time complexity: O(P·(V+E)log V) where P is the size of the resulting packing,
 *   V is the number of vertices, and E is the number of edges
 * @note Space complexity: O(V) for the explored tracker, queue, and packing vector
 *
 * @see find_boundary_vertices_outside_radius - The helper function that identifies boundary vertices
 * @see explored_tracker_t - The structure used to track explored vertices
 */
std::vector<size_t> set_wgraph_t::create_maximal_packing(
	double radius,
	size_t start_vertex) const {

	size_t n_vertices = adjacency_list.size();
	std::vector<size_t> packing;
	packing.reserve(n_vertices);
	packing.push_back(start_vertex);

	explored_tracker_t explored_tracker(n_vertices, start_vertex);
	std::queue<size_t> boundary_queue;

	// Initial boundary vertices from the starting point
	std::vector<size_t> boundary_vertices = find_boundary_vertices_outside_radius(start_vertex, radius, explored_tracker);

	// Add all initial boundary vertices to the queue
	for (size_t vertex : boundary_vertices) {
		boundary_queue.push(vertex);
	}

	// Main packing algorithm loop
	while (!boundary_queue.empty() && explored_tracker.n_explored < n_vertices) {
		// Get the next candidate vertex from the queue
		size_t current_vertex = boundary_queue.front();
		boundary_queue.pop();

		// Skip if this vertex has already been explored
		if (explored_tracker.is_explored(current_vertex)) {
			continue;
		}

		packing.push_back(current_vertex);
		explored_tracker.explored[current_vertex] = true;
		explored_tracker.n_explored++;

		// Find new boundary vertices from this new packing vertex
		boundary_vertices = find_boundary_vertices_outside_radius(current_vertex, radius, explored_tracker);

		// Add newly discovered boundary vertices to the queue
		for (size_t vertex : boundary_vertices) {
			// Only add if not already explored
			if (!explored_tracker.is_explored(vertex)) {
				boundary_queue.push(vertex);
			}
		}
	}

	return packing;
}

void set_wgraph_t::trace_exploration_path(
	size_t from_vertex,
	size_t to_vertex,
	double radius) const {

	// Rerun Dijkstra's algorithm with detailed logging
	std::vector<double> dist(adjacency_list.size(), INFINITY);
	std::vector<size_t> prev(adjacency_list.size(), INVALID_VERTEX);
	dist[from_vertex] = 0;

	std::priority_queue<std::pair<double, size_t>> pq;
	pq.push({0, from_vertex});

	Rprintf("TRACE: Starting path exploration from %zu to %zu\n", from_vertex + 1, to_vertex + 1);

	while (!pq.empty()) {
		auto top = pq.top();
		double d = -top.first;   // Note the negation here!
		size_t u = top.second;
		pq.pop();

		if (u == to_vertex) {
			Rprintf("TRACE: Reached target vertex %zu with distance %.4f\n", to_vertex + 1, d);
			break;
		}

		if (d > dist[u]) continue;

		for (const auto& edge : adjacency_list[u]) {
			size_t v = edge.vertex;
			double w = edge.weight;
			double new_dist = dist[u] + w;

			if (new_dist < dist[v]) {
				dist[v] = new_dist;
				prev[v] = u;
				pq.push({-new_dist, v});   // Note the negation!

				if (v == to_vertex || new_dist < radius) {
					Rprintf("TRACE: Updated vertex %zu distance to %.4f (via %zu)\n",
							v + 1, new_dist, u + 1);
				}

				// Key debugging for the issue
				if (new_dist < radius) {
					Rprintf("TRACE: Vertex %zu should be marked as explored (dist=%.4f < radius=%.4f)\n",
							v + 1, new_dist, radius);
				}
			}
		}
	}

	// Reconstruct and print the shortest path
	if (prev[to_vertex] != INVALID_VERTEX) {
		std::vector<size_t> path;
		for (size_t at = to_vertex; at != from_vertex; at = prev[at]) {
			path.push_back(at);
		}
		path.push_back(from_vertex);
		std::reverse(path.begin(), path.end());

		Rprintf("TRACE: Shortest path from %zu to %zu: ", from_vertex + 1, to_vertex + 1);
		for (size_t i = 0; i < path.size(); i++) {
			Rprintf("%zu", path[i] + 1);
			if (i < path.size() - 1) {
				Rprintf(" -> ");
			}
		}
		Rprintf(" (total distance: %.4f)\n", dist[to_vertex]);
	}
}






/**
 * @brief Calculates the eccentricity of a vertex in the weighted graph and the farthest vertex
 *
 * The eccentricity of a vertex is defined as the maximum shortest path distance
 * from that vertex to any other reachable vertex in the graph. This function
 * implements Dijkstra's algorithm to compute the shortest paths from the start
 * vertex to all other vertices in the graph.
 *
 * @param start_vertex The index of the vertex for which to calculate eccentricity
 * @return A pair (farthest_vertex, eccentricity) where:
 *   - farthest_vertex: The index of the vertex that is farthest from start_vertex
 *   - eccentricity: The eccentricity value (maximum shortest path distance)
 *
 * @note Time complexity is O((V+E)log(V)) where V is the number of vertices and
 *   E is the number of edges in the graph
 * @note If some vertices are not reachable from start_vertex, only the reachable
 *   vertices are considered in the eccentricity calculation
 * @note Unreachable vertices will have infinite distance values but do not
 *   contribute to the eccentricity calculation
 *
 * @see Dijkstra's algorithm
 */
std::pair<size_t, double> set_wgraph_t::get_vertex_eccentricity(size_t start_vertex) const {
	// Track distances and whether vertices are finalized
	std::vector<double> distances(adjacency_list.size(), std::numeric_limits<double>::infinity());
	std::vector<bool> finalized(adjacency_list.size(), false);
	distances[start_vertex] = 0.0;

	// Priority queue stores pairs of (-distance, vertex)
	// Using negative distance because C++ priority_queue is max heap
	std::priority_queue<std::pair<double, size_t>> pq;
	pq.push({-0.0, start_vertex}); // Using negative distance consistently

	while (!pq.empty()) {
		size_t current_vertex = pq.top().second;
		double current_distance = -pq.top().first;  // Note the negative
		pq.pop();

		if (finalized[current_vertex]) continue;
		finalized[current_vertex] = true;

		// Explore neighbors using the set-based adjacency list
		for (const auto& edge : adjacency_list[current_vertex]) {
			size_t neighbor = edge.vertex;
			double edge_length = edge.weight;

			if (!finalized[neighbor]) {
				double new_distance = current_distance + edge_length;
				if (new_distance < distances[neighbor]) {
					distances[neighbor] = new_distance;
					pq.push({-new_distance, neighbor});   // Note the negative
				}
			}
		}
	}

	// Find the vertex with maximum finite distance (farthest reachable vertex)
	double max_distance = 0.0;
	size_t farthest_vertex = start_vertex;

	for (size_t i = 0; i < distances.size(); ++i) {
		if (distances[i] != std::numeric_limits<double>::infinity() && distances[i] > max_distance) {
			max_distance = distances[i];
			farthest_vertex = i;
		}
	}

	return {farthest_vertex, max_distance};
}


/**
 * @brief Creates a maximal packing with a target size by finding the appropriate radius
 *
 * @details This function uses binary search to find a radius value that produces a maximal
 * ε-packing with approximately 'grid_size' vertices. It starts by determining the graph
 * diameter using the endpoints method, then refines the packing radius through iterations,
 * creating trial packings until it converges on a packing whose size is as close as possible
 * to the target grid_size.
 *
 * As a side effect, this function sets two class member variables:
 * - graph_diameter: The computed diameter of the graph
 * - max_packing_radius: The optimal radius used for the final packing
 *
 * @param grid_size The target number of vertices in the packing
 * @param max_iterations Maximum number of binary search iterations to perform
 * @param precision Relative precision threshold (as a fraction of diameter) for terminating the search
 *
 * @return A vector containing the indices of vertices in the maximal packing
 *
 * @note After calling this function, the graph_diameter and max_packing_radius members
 *   will contain the computed values for the graph and can be accessed directly.
 *
 * @pre The graph must be path-connected
 * @pre The graph must have non-negative edge weights
 * @pre grid_size must be positive
 */
std::vector<size_t> set_wgraph_t::create_maximal_packing(
	size_t grid_size,
	size_t max_iterations,
	double precision
	) {

	// Find diameter endpoints
	auto [end1, diam] = get_vertex_eccentricity(0);   // Start from vertex 0
	auto [end2, diameter] = get_vertex_eccentricity(end1);

	size_t start_vertex = end2;  // Use end2 as the starting vertex
	graph_diameter = diameter;

	// Set initial bounds for binary search
	double lower_radius = graph_diameter / (grid_size * 4.0);// Start with a smaller radius to ensure we can get more vertices
	double upper_radius = graph_diameter / 2;// Maximum possible radius

	// Initial packing with estimated radius
	double init_radius = graph_diameter / grid_size;
	std::vector<size_t> best_packing = create_maximal_packing(init_radius, start_vertex);
	size_t best_diff = std::abs(static_cast<int>(best_packing.size()) - static_cast<int>(grid_size));
	double best_radius = init_radius;

	// Binary search to find optimal radius - continue until a certain precision is reached
	// or we've completed a reasonable number of iterations
	const double EPSILON = precision * graph_diameter; // Small fraction of diameter as precision

	size_t iterations = 0;
	while (iterations < max_iterations && upper_radius - lower_radius > EPSILON) {
		// Try the middle radius
		double mid_radius = (lower_radius + upper_radius) / 2.0;
		std::vector<size_t> current_packing = create_maximal_packing(mid_radius, start_vertex);
		size_t current_size = current_packing.size();

		// Calculate how far this packing is from our target size
		size_t current_diff = std::abs(static_cast<int>(current_size) - static_cast<int>(grid_size));

		// If this is the best we've found so far, save it
		if (current_diff < best_diff) {
			best_diff = current_diff;
			best_packing = std::move(current_packing);
			best_radius = mid_radius;

			// If we've hit the exact target size, we can stop
			if (current_diff == 0) {
				break;
			}
		}

		// Adjust our search range based on the result
		if (current_size < grid_size) {
			// Too few vertices - need a smaller radius
			upper_radius = mid_radius;
		} else {
			// Too many vertices - need a larger radius
			lower_radius = mid_radius;
		}

		iterations++;
	}

	max_packing_radius = best_radius;  // <-- setting max_packing_radius set_wgraph_t member value

	// For logging/debugging purposes
	Rprintf("Found packing of size %zu with radius %.4f after %zu iterations\n",
			best_packing.size(), best_radius, iterations);

	return best_packing;
}

/**
 * @brief Creates a uniform grid graph with a maximal packing of vertices
 *
 * @details This function takes a graph representation (adjacency list and weight list),
 * constructs a set-based weighted graph, and computes a maximal packing of vertices
 * based on the specified grid size. A maximal packing is a subset of vertices where
 * no two vertices are closer than the grid size, and no additional vertex can be added
 * without violating this constraint.
 *
 * The algorithm first determines the diameter endpoints of the graph and then uses one
 * of these endpoints as the starting point for building the packing. It iteratively adds
 * vertices to the packing, ensuring they maintain proper spacing. The iteration process
 * continues until either convergence is reached (no more vertices can be added) or
 * the maximum number of iterations is exceeded.
 *
 * The returned uniform_grid_graph_t object inherits both the graph_diameter and
 * max_packing_radius values from the intermediate set_wgraph_t object, making these
 * calculated values available for further analysis.
 *
 * @param adj_list A vector of vectors representing the adjacency list of the graph,
 * where each inner vector contains the indices of neighbors for a vertex
 * @param weight_list A vector of vectors containing the edge weights corresponding to
 * the adjacency list, where weight_list[i][j] is the weight of the
 * edge from vertex i to adj_list[i][j]
 * @param grid_size The target spacing between vertices in the packing
 * @param max_iterations The maximum number of iterations for the packing algorithm
 * @param precision The convergence threshold for the algorithm
 *
 * @return A uniform_grid_graph_t object containing the original graph structure and the
 * computed maximal packing of vertices
 *
 * @note Both graph_diameter and max_packing_radius are copied to the returned object
 * through the uniform_grid_graph_t constructor, providing access to these computed values.
 *
 * @note The packing algorithm is implemented in the set_wgraph_t::create_maximal_packing
 *   method, which this function calls internally
 *
 * @see set_wgraph_t
 * @see uniform_grid_graph_t
 * @see set_wgraph_t::create_maximal_packing
 */
uniform_grid_graph_t create_maximal_packing(
	const std::vector<std::vector<int>>& adj_list,
	const std::vector<std::vector<double>>& weight_list,
	size_t grid_size,
	size_t max_iterations,
	double precision) {

	set_wgraph_t graph(adj_list, weight_list);

	std::vector<size_t> packing = graph.create_maximal_packing(
		grid_size,
		max_iterations,
		precision);

	uniform_grid_graph_t grid_graph(graph, packing);

	return grid_graph;
}

