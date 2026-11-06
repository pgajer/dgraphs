#ifndef GRAPH_MAXIMAL_PACKING_H_
#define GRAPH_MAXIMAL_PACKING_H_

#include "dgraphs/uniform_grid_graph.hpp"

#include <cstddef>
using std::size_t;

uniform_grid_graph_t create_maximal_packing(
	const std::vector<std::vector<int>>& adj_list,
	const std::vector<std::vector<double>>& weight_list,
	size_t grid_size,
	size_t max_iterations,
	double precision);

#endif // GRAPH_MAXIMAL_PACKING_H_
