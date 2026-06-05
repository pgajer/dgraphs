#ifndef VERTEX_INFO_H_
#define VERTEX_INFO_H_

#include <cstddef>
#include <vector>

using std::size_t;

/**
 * used for sorting shortest paths staring at a given vertex by the distance from that vertex
 */
struct vertex_info_t {
	size_t vertex;
	double distance;

	// Added constructor for C++17 compatibility
	vertex_info_t(size_t v, double d) : vertex(v), distance(d) {}
	vertex_info_t() = default;
};

/**
 * @brief Stores information about an endpoint vertex and its complete path from a reference vertex
 */
struct vertex_shortest_path_info_t {
	size_t vertex;            ///< The endpoint vertex
	double distance;          ///< Distance from reference vertex to this endpoint
	std::vector<size_t> path; ///< The complete shortest path from reference vertex to endpoint
};

#endif // VERTEX_INFO_H_
