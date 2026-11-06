#ifndef GRAPH_UTILS_H_
#define GRAPH_UTILS_H_

#include <vector>       // for std::vector

double get_graph_diameter(
	const std::vector<std::vector<int>>& adj_list,
	const std::vector<std::vector<double>>& weight_list,
	int start_vertex);

double get_vertex_eccentricity(
	const std::vector<std::vector<int>>& adj_list,
	const std::vector<std::vector<double>>& weight_list,
	int start_vertex);

double get_vertex_eccentricity(
	const std::vector<std::vector<int>>& adj_list,
	const std::vector<std::vector<double>>& weight_list,
	std::vector<int>& start_vertices);

std::pair<std::vector<std::vector<int>>, std::vector<std::vector<double>>>
create_chain_graph(
	const std::vector<double>& x
	);

#endif // GRAPH_UTILS_H_
