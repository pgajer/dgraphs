#ifndef VECT_WGRAPH_H_
#define VECT_WGRAPH_H_

#include "edge_info.hpp"

#include <vector>
#include <string>
#include <cstddef>
using std::size_t;

struct vect_wgraph_t {
	// Core graph structure
	std::vector<std::vector<edge_info_t>> adjacency_list;

	// Default constructor
	vect_wgraph_t() = default;

	void print(const std::string& name = "",
			   size_t vertex_index_shift = 0) const;
};

#endif // VECT_WGRAPH_H_
