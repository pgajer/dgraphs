#ifndef EDGE_WEIGHTS_H_
#define EDGE_WEIGHTS_H_

#include <functional>   // For std::hash
#include <utility>      // For std::pair
#include <unordered_map> // For std::unordered_map
#include <vector>       // For std::vector
#include <cstddef>      // For size_t (though often included by other headers)
using std::size_t;

/**
 * @struct edge_weights_t
 * @brief A memory-efficient data structure for storing and accessing edge weights in a graph
 *
 * This structure implements a sparse representation of edge weights using an unordered map,
 * optimizing memory usage for graphs where the number of edges is significantly smaller
 * than the maximum possible number of edges (E << V²).
 *
 * The implementation uses std::unordered_map with a custom hash function for vertex pairs,
 * providing constant-time average case access while dramatically reducing memory usage
 * compared to the dense matrix representation (std::vector<std::vector<double>>).
 *
 * Memory Usage Comparison (8 bytes per double):
 * For a graph with V vertices and 3V edges:
 *   Dense Matrix (vector<vector>):
 * - V = 10K:800 MB(10K × 10K × 8 bytes)
 * - V = 100K:   80 GB (100K × 100K × 8 bytes)
 * - V = 1M: 8 TB  (1M × 1M × 8 bytes)
 *
 *   Sparse Map (This implementation):
 * - V = 10K:1.4 MB(30K edges × 48 bytes per entry)
 * - V = 100K:   14.4 MB   (300K edges × 48 bytes per entry)
 * - V = 1M: 144 MB(3M edges × 48 bytes per entry)
 *
 * Performance Characteristics:
 *   - Access Time: O(1) average case, but 2-3x slower than vector implementation
 *   - Memory: O(E) instead of O(V²)
 *   - Benchmark Results:
 * - V = 10K: ~3x slower than vector access
 * - V = 100K: ~2x slower than vector access
 *   - Performance gap decreases with larger graphs due to cache effects
 *
 * @note The structure assumes undirected edges (weight(v1,v2) = weight(v2,v1)).
 *   Only one direction is stored to save space.
 *
 * Benchmark results in my M4 laptop:
 *
 * Number of vertices: 10000
 * Number of edges: 30000
 * Average vector time: 0.00 seconds
 * Average map time: 0.00 seconds
 * Map is 2.98x slower
 *
 * Number of vertices: 100000
 * Number of edges: 300000
 * Average vector time: 0.01 seconds
 * Average map time: 0.01 seconds
 * Map is 2.05x slower
 *
 *
 * Usage Example:
 * @code
 * edge_weights_t weights;
 * weights.n_vertices = graph_size;
 *
 *   // Adding an edge weight
 * int v1 = 0, v2 = 1;
 * weights.weights[{std::min(v1,v2), std::max(v1,v2)}] = 1.5;
 *
 *   // Accessing an edge weight
 * double w = weights.get(v1, v2);// Returns 1.5
 * @endcode
 *
 * @see int_pair_hash_t For the hash function implementation used by the unordered_map
 */

/**
 * @struct int_pair_hash_t
 * @brief Hash function object for std::pair<int,int>
 *
 * Provides a hash combining function for vertex pairs used in the edge_weights_t
 * unordered_map. Uses XOR with bit shifting to combine the two integer hashes.
 */

struct size_t_pair_hash_t {
	std::size_t operator()(const std::pair<size_t, size_t>& p) const {
		// Combine the hash of both integers in a way that preserves uniqueness
		return std::hash<size_t>{}(p.first) ^
								   (std::hash<size_t>{}(p.second) << 1);
	}
};

using edge_weights_t = std::unordered_map<std::pair<size_t,size_t>, double, size_t_pair_hash_t>;

edge_weights_t precompute_edge_weights(
	const std::vector<std::vector<int>>& adj_list,
	const std::vector<std::vector<double>>& weight_list
	);


#endif // EDGE_WEIGHTS_H_
