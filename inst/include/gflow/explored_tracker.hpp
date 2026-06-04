#ifndef EXPLORED_TRACKER_H_
#define EXPLORED_TRACKER_H_

#include <cstddef>
using std::size_t;

/**
 * @brief Helper structure to track vertices explored during the ε-packing algorithm
 *
 * @details This structure maintains a record of vertices that have been "explored"
 * during the construction of a maximal ε-packing. A vertex is considered "explored"
 * if it is within distance ε of any vertex in the current packing. This allows the
 * algorithm to efficiently track which vertices cannot be added to the packing due
 * to proximity constraints.
 *
 * The implementation uses a boolean vector to mark explored vertices and maintains
 * a counter of how many vertices have been explored so far, allowing for efficient
 * termination checks.
 */
struct explored_tracker_t {
	size_t n_explored;  ///< Number of vertices marked as explored
	std::vector<bool> explored;  ///< Boolean flags indicating whether each vertex is explored

	/**
	 * @brief Default constructor
	 * @details Initializes an empty tracker with no explored vertices
	 */
	explored_tracker_t() : n_explored(0) {}

	/**
	 * @brief Constructor with specified number of vertices
	 * @param n Total number of vertices in the graph
	 * @details Initializes a tracker for a graph with n vertices, all marked as unexplored
	 */
	explicit explored_tracker_t(size_t n) : n_explored(0) {
		explored.resize(n);
		for (size_t i = 0; i < explored.size(); ++i) {
			explored[i] = false;
		}
	}

	/**
	 * @brief Constructor with specified vertex count and initial explored vertex
	 * @param n Total number of vertices in the graph
	 * @param start_vertex Index of the initial vertex to mark as explored
	 * @details Initializes a tracker with all vertices unexplored except for start_vertex
	 */
	explored_tracker_t(size_t n, size_t start_vertex) : n_explored(1) {
		explored.resize(n, false);      // Initialize all to false
		explored[start_vertex] = true;  // Then mark start vertex as explored
	}

	/**
	 * @brief Check if a vertex has been explored
	 * @param v Index of the vertex to check
	 * @return true if the vertex has been explored, false otherwise
	 */
	bool is_explored(size_t v) const {
		return explored[v];
	}

	/**
	 * @brief Check if all vertices in the graph have been explored
	 * @param total_vertices Total number of vertices in the graph
	 * @return true if all vertices have been explored, false otherwise
	 */
	bool all_explored(size_t total_vertices) const {
		return n_explored == total_vertices;
	}
};

#endif // EXPLORED_TRACKER_H_
