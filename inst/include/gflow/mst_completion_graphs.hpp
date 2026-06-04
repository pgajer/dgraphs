#ifndef MST_COMPLETION_GRAPHS_H_
#define MST_COMPLETION_GRAPHS_H_

#include "set_wgraph.hpp"

struct mst_completion_graph_t {
	set_wgraph_t mstree; ///< minimal spanning tree of the data
	set_wgraph_t completed_mstree;   ///< completed minimal spanning tree of the data
	std::vector<double> mstree_edge_weights; ///< vector of MST edge weights
	double q_thold;  ///< quantile threshold used for completion of the MST
};

mst_completion_graph_t create_mst_completion_graph(
	const std::vector<std::vector<double>>& X,
	double q_thold,
	bool verbose
	);

#endif // MST_COMPLETION_GRAPHS_H_
