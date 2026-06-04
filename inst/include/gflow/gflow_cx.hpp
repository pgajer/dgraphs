#ifndef GFLOW_CX_HPP
#define GFLOW_CX_HPP

#include "basin.hpp"

#include <cstddef>
#include <unordered_set>
#include <unordered_map>

using std::size_t;

struct hop_nbhd_t {
	size_t vertex;                                   // index of the vertex of the given hop neighborhood
	size_t hop_idx;                                  // the maximal hop size of the neighborhood where local extremum condition holds
	std::unordered_map<size_t, size_t> hop_dist_map; // hop distance map: vertex_idx -> (hop distance); contains all vertices with hop distance <= hop_idx
	std::unordered_map<size_t, double> y_nbhd_bd_map;// maps vertices at (hop_idx + 1) hop distance from 'vertex' to the value of y at these vertices
};

enum class smoother_type_t {
	WMEAN,                      // weighted mean
	HARMONIC_IT,                // iterative estimation of harmonic extension
	HARMONIC_EIGEN,             // Eigen estimation of harmonic extension
	HYBRID_BIHARMONIC_HARMONIC, // Hybrid biharmonic-harmonic extension
	BOUNDARY_SMOOTHED_HARMONIC  // Boundary-smoothed harmonic extension
};

// This struct records smoothing history
struct smoothing_step_t {
	size_t vertex;                     // Vertex being smoothed
	bool is_minimum;                   // Whether it's a minimum or maximum
	size_t hop_idx;                    // Hop index
	smoother_type_t smoother;          // Smoother used
	std::vector<double> before;        // Values before smoothing
	std::vector<double> after;         // Values after smoothing
	std::unordered_set<size_t> region; // Region vertices
	std::unordered_map<size_t, double> boundary_values;
};

struct gflow_cx_t {
	std::unordered_map<size_t, hop_nbhd_t> lmin_hop_nbhd_map; // nbh local minimum to its hop_nbhd_t object map
	std::unordered_map<size_t, hop_nbhd_t> lmax_hop_nbhd_map; // nbh local maximum to its hop_nbhd_t object map
	std::vector<double> harmonic_predictions;                 // harmonically repaired function used to construct the basins
	std::unordered_map<size_t, basin_t> lmin_basins_map;      // lmin_basins[lmin vertex] = its basin
	std::unordered_map<size_t, basin_t> lmax_basins_map;      // lmax_basins[lmax vertex] = its basin
	std::vector<smoothing_step_t> smoothing_history;          // detailed recording of smoothing steps (if enabled)
};

#endif // GFLOW_CX_HPP
