#ifndef GRADIENT_FLOW_H_
#define GRADIENT_FLOW_H_

#include <vector>
#include <map>
#include <set>
#include <unordered_map>
#include <string>
#include <utility> // For std::pair
#include <cstddef>
using std::size_t;

struct gradient_flow_t {

	enum trajectory_type_t {
		LMIN_LMAX,  // Standard: connects local minimum to local maximum
		LMIN_ONLY,  // Starts at local minimum, ends at non-critical or spurious maximum
		LMAX_ONLY,  // Starts at non-critical or spurious minimum, ends at local maximum
		LMIN_LMIN,
		LMAX_LMAX,
		UNKNOWN
	};

	struct trajectory_t {
		std::vector<size_t> vertices;
		trajectory_type_t trajectory_type;
		double quality_metric;       ///< Quality metric of the trajectory (monotonicity * adjusted rate)
		double total_change;         ///< Total function value change along the trajectory
	};

	std::map<size_t, std::set<size_t>> ascending_basin_map;  // maps local minima to their basins
	std::map<size_t, std::set<size_t>> descending_basin_map; // maps local maxima to their basins
	std::map<std::pair<size_t, size_t>, std::set<size_t>> cell_map; // maps (local minima, local maxima) pairs to their cells; cells always have dangling trajectories attached to them. That is, for
	// the cell consisting of trajectories starting at local_minimum and
	// ending at local_maximum, we also add to it all danging trajectories starting
	// at local_minimum and all dangling trajectories ending at local_maximum.

	std::vector<trajectory_t> trajectories;
	std::unordered_map<size_t, bool> local_extrema; // vertex_index -> is_maximum
	std::vector<double> scale;
	std::string messages;
};

/**
 * @brief Structure to hold local extremum information
 */
struct local_extremum_t {
	size_t vertex;         ///< The vertex that is a local extremum
	double value;          ///< Function value at the vertex
	double radius;         //< The neighborhood radius where extremum property holds
	size_t neighborhood_size;// Number of vertices in the neighborhood
	bool is_maximum; // True if maximum, false if minimum
	std::vector<size_t> vertices; // neighbor vertices of the reference vertex where the extremum condition is satisfied
};

struct monotonic_path_info_t {
	double total_change;// Total y change from reference vertex (y[v] - y[ref])
	double cum_abs_change;  // Cumulative absolute changes along the path
	double monotonicity_index;  // |total_change| / cum_abs_change
	size_t predecessor; // Predecessor vertex in the optimal path
	double distance;// Actual distance from reference vertex
};

struct monotonic_reachability_map_t {
	size_t ref_vertex;  // Reference vertex
	std::unordered_map<size_t, monotonic_path_info_t> info; // Maps vertex to its path info
	std::vector<vertex_info_t> sorted_vertices; // Vertices sorted by monotonicity index
};


#endif // GRADIENT_FLOW_H_
