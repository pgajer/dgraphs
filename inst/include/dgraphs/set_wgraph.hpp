#ifndef DGRAPHS_SET_WGRAPH_HPP
#define DGRAPHS_SET_WGRAPH_HPP

#include "dgraphs/edge_info.hpp"
#include "dgraphs/edge_pruning_stats.hpp"
#include "dgraphs/edge_weights.hpp"
#include "dgraphs/explored_tracker.hpp"
#include "dgraphs/iknn_graphs.hpp"
#include "dgraphs/invalid_vertex.hpp"

#include <cstddef>
#include <limits>
#include <map>
#include <set>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

using std::size_t;

struct path_t {
	std::vector<size_t> vertices;
	std::vector<double> distances;
	size_t ref_vertex_index = 0;
	double total_weight = 0.0;

	bool operator<(const path_t& other) const {
		return total_weight > other.total_weight;
	}
};

struct subpath_t {
	size_t path_idx;
	size_t vertex_idx;
};

struct shortest_paths_t {
	std::vector<path_t> paths;
	std::unordered_set<int> reachable_vertices;
	std::unordered_map<size_t, subpath_t> vertex_to_path_map;
};

struct gray_xyw_t {
	std::vector<size_t> vertices;
	std::vector<double> x_path;
	std::vector<double> y_path;
	std::vector<double> w_path;
};

struct composite_shortest_paths_t : public shortest_paths_t {
	std::vector<std::pair<size_t, size_t>> composite_paths;

	explicit composite_shortest_paths_t(const shortest_paths_t& shortest_paths)
		: shortest_paths_t(shortest_paths)
		{}

	void add_composite_shortest_path(size_t i, size_t j) {
		composite_paths.emplace_back(i, j);
	}

	bool is_single_path(size_t index) const {
		return composite_paths[index].second == INVALID_VERTEX;
	}
};

struct edge_weight_deviations_t {
	std::vector<double> absolute_deviations;
	std::vector<double> relative_deviations;
};

struct edge_weight_rel_deviation_t {
	double rel_deviation;
	size_t source;
	size_t target;
	size_t best_intermediate;

	explicit edge_weight_rel_deviation_t(double rel_deviation,
										 size_t source,
										 size_t target,
										 size_t best_intermediate)
		: rel_deviation(rel_deviation),
		  source(source),
		  target(target),
		  best_intermediate(best_intermediate)
		{}
};

struct set_wgraph_t {
	std::vector<std::set<edge_info_t>> adjacency_list;
	double graph_diameter;
	double max_packing_radius;

	set_wgraph_t() : graph_diameter(-1.0), max_packing_radius(-1.0) {}

	explicit set_wgraph_t(
		const std::vector<std::vector<int>>& adj_list,
		const std::vector<std::vector<double>>& weight_list
		);

	explicit set_wgraph_t(
		const iknn_graph_t& iknn_graph
		);

	explicit set_wgraph_t(size_t n_vertices)
		: adjacency_list(n_vertices),
		  graph_diameter(-1.0),
		  max_packing_radius(-1.0)
		{}

	void print(const std::string& name,
			   bool split,
			   size_t shift
		) const;

	size_t num_vertices() const {
		return adjacency_list.size();
	}

	void compute_graph_diameter();
	double compute_median_edge_length() const;
	double compute_quantile_edge_length(double quantile) const;
	std::vector<double> compute_weight_percentiles(const std::vector<double>& probs) const;
	std::vector<double> extract_edge_lengths(const path_t& path) const;

	void ensure_edge_weights_computed() const {
		if (!edge_weights_computed) {
			precompute_edge_weights();
		}
	}

	void precompute_edge_weights() const;

	void invalidate_edge_weights() {
		edge_weights_computed = false;
		edge_weights.clear();
	}

	set_wgraph_t create_subgraph(
		const std::vector<size_t>& vertices
		) const;

	size_t count_connected_components() const;
	std::vector<std::vector<size_t>> get_connected_components() const;

	void add_edge(size_t v1, size_t v2, double weight);
	void remove_edge(size_t v1, size_t v2);

	double bidirectional_dijkstra_excluding_edge(
		size_t source,
		size_t target
		) const;

	double bidirectional_dijkstra(
		size_t source,
		size_t target
		) const;

	edge_pruning_stats_t compute_edge_pruning_stats(
		double threshold_percentile = 0.5
		) const;

	set_wgraph_t prune_edges_geometrically(
		double max_ratio_threshold = 1.2,
		double threshold_percentile = 0.5,
		bool verbose = false
		) const;

	set_wgraph_t prune_long_edges(double threshold_percentile = 0.5) const;

	edge_weight_deviations_t compute_edge_weight_deviations() const;
	std::vector<edge_weight_rel_deviation_t> compute_edge_weight_rel_deviations() const;

	bool is_composite_path_geodesic(
		size_t i,
		size_t j,
		const shortest_paths_t& shortest_paths
		) const;

	std::pair<size_t, double> get_vertex_eccentricity(
		size_t start_vertex
		) const;

	std::vector<size_t> create_maximal_packing(
		double radius,
		size_t start_vertex
		) const;

	std::vector<size_t> create_maximal_packing(
		size_t grid_size,
		size_t max_iterations,
		double precision
		);

	std::vector<size_t> find_boundary_vertices_outside_radius(
		size_t start,
		double radius,
		explored_tracker_t& explored_tracker
		) const;

	std::pair<size_t, double> find_first_vertex_outside_radius(
		size_t start,
		double radius
		) const;

	std::pair<size_t, double> find_first_vertex_outside_radius(
		size_t start,
		double radius,
		explored_tracker_t& explored_tracker
		) const;

	double compute_shortest_path_distance(
		size_t from,
		size_t to
		) const;

	shortest_paths_t find_graph_paths_within_radius(
		size_t start,
		double radius
		) const;

	shortest_paths_t find_graph_paths_within_radius_and_path_min_size(
		size_t start,
		double radius,
		size_t min_path_size
		) const;

	gray_xyw_t get_xyw_along_path(
		const std::vector<double>& y,
		path_t& path,
		double dist_normalization_factor
		) const;

	double find_minimum_bandwidth(
		size_t grid_vertex,
		double lower_bound,
		double upper_bound,
		size_t min_path_size,
		double precision
		) const;

	bool has_sufficient_path_size(
		const shortest_paths_t& paths,
		size_t min_path_size
		) const;

private:
	mutable std::unordered_map<size_t, shortest_paths_t> paths_cache;
	mutable std::unordered_set<size_t> unprocessed_vertices;
	mutable edge_weights_t edge_weights;
	mutable bool edge_weights_computed = false;

	std::vector<std::vector<size_t>> find_connected_components(
		const std::vector<size_t>& procell_vertices
		) const;
};

#endif // DGRAPHS_SET_WGRAPH_HPP
