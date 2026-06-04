#ifndef REACHABILITY_MAP_H_
#define REACHABILITY_MAP_H_

#include "vertex_info.hpp"

#include <cstddef>
#include <vector>
#include <unordered_map>

using std::size_t;

/**
 * @brief Structure holding precomputed path information for a reference vertex
 */
struct reachability_map_t {
	std::vector<vertex_info_t> sorted_vertices;        ///< Vertices sorted in the descending order by distance from reference vertex
	std::unordered_map<size_t, double> distances;      ///< Map of vertex to distance from reference
	std::unordered_map<size_t, size_t> predecessors;   ///< Map of vertex to its predecessor in shortest path
	size_t ref_vertex;                                 ///< Reference vertex for these paths
};


#endif // REACHABILITY_MAP_H_
