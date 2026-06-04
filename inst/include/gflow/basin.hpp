#ifndef BASIN_HPP
#define BASIN_HPP

#include "edge_weights.hpp"
#include "invalid_vertex.hpp"
#include "reachability_map.hpp"

#include <map>
#include <unordered_map>
#include <string>
#include <cmath>  // for INFINITY
#include <cstddef>
using std::size_t;

/**
 * @brief Represents the monotonic basin of a local extremum
 *
 * @details A basin captures all vertices reachable from a local extremum while
 *          maintaining strict monotonicity (decreasing for maxima, increasing for minima).
 *          It contains information about the extremum itself, all vertices in the basin,
 *          and all boundary vertices where the basin terminates.
 */
struct basin_t {
    size_t extremum_vertex;                         ///< local extremum vertex of the basin
    double value;                                   ///< Function value at the extremum vertex
    bool is_maximum;                                ///< True if the extremum is a maximum; false if a minimum
	size_t extremum_hop_index;                      ///< The maximum number of hops for which a vertex remains a strict local extremum
	reachability_map_t reachability_map;            ///< Reachability map encoding distances, predecessors, and sorted basin vertices

    /**
     * @brief Minimum monotonicity span - the smallest vertical distance from the extremum to any boundary vertex
     *
     * @details This measures the "importance" of the extremum by quantifying how far one can travel
     *          from it while maintaining monotonicity before reaching a boundary.
     *
     *          For maxima: The minimum vertical descent (y[extremum] - y[boundary_vertex]) to any boundary
     *          For minima: The minimum vertical ascent (y[boundary_vertex] - y[extremum]) to any boundary
     *
     *          Boundaries can be either:
     *          1. Points where monotonicity would be violated if we continued further
     *          2. Points at the 'end/boundary' of the graph where no further expansion is possible
     *
     *          The smaller this value, the less significant the extremum.
     */
    double min_monotonicity_span;
	double rel_min_monotonicity_span; ///<  min_monotonicity_span / (max(y) - min(y))
    /**
     * @brief The boundary vertex at which the minimum monotonicity span is realized
     *
     * @details This identifies the specific boundary vertex that determines the
     *          minimum monotonicity span. It represents the most "vulnerable" point
     *          of the basin, where the extremum's influence is weakest.
     */
    size_t min_span_vertex;

    double max_monotonicity_span;
	double rel_max_monotonicity_span;
    size_t max_span_vertex;

	double delta_rel_span; ///< = rel_max_monotonicity_span - rel_min_monotonicity_span

	size_t rel_size; ///< = (number of basin elements) / Rf_length(y)

    /**
     * @brief Map of boundary vertices sorted by increasing distance from the extremum
     *
     * @details This map contains all vertices where the basin terminates, including:
     *          1. Vertices where monotonicity is violated (technically their predecessors,
     *             which are the last valid points in the monotonic path)
     *          2. Vertices at the edge of the basin's reach in the graph (have neighbors
     *             outside the basin)
     *
     *          The key is the distance from the extremum, allowing traversal of boundaries
     *          in order of increasing distance.
     *
     *          These boundary vertices are used to calculate min_monotonicity_span
     *          when no monotonicity violations occur during basin construction.
     */
    std::map<double, size_t> boundary_vertices_map;

    /**
     * @brief Maps boundary vertices to their monotonicity spans
     *
     * This allows us to recalculate min_span_vertex and min_monotonicity_span
     * when connected basins are changed during basin complex construction
     */
    std::map<size_t, double> boundary_monotonicity_spans_map;

	// ------- Member functions -------
	/**
     * @brief Updates min_span_vertex and spans after connected basin changes
     *
     * Recalculates the minimum monotonicity span and associated vertex
     * based on current boundary vertex information
     */
    void update_min_span(double y_range) {
        min_monotonicity_span = INFINITY;
        min_span_vertex = INVALID_VERTEX;

        for (const auto& [vertex, span] : boundary_monotonicity_spans_map) {
            if (span < min_monotonicity_span) {
                min_monotonicity_span = span;
                min_span_vertex = vertex;
            }
        }

        // Update relative span
        rel_min_monotonicity_span = (y_range > 0.0) ? min_monotonicity_span / y_range : 0.0;
    }
};

struct set_wgraph_t;

// gradient flow basin complex
struct basin_cx_t {
	std::vector<double> harmonic_predictions;                           ///< harmonically repaired function used to construct the basins
	std::unordered_map<size_t, basin_t> lmin_basins_map;                ///< lmin_basins[lmin vertex] = its basin
	std::unordered_map<size_t, basin_t> lmax_basins_map;                ///< lmax_basins[lmax vertex] = its basin
	std::vector<std::pair<size_t, size_t>> cancellation_pairs;          ///< <lmin_i, lmax_j> pairs with the property that lmin_i.depth_vertex = lmax_j and lmax_j.depth_vertex = lmin_i
	std::unordered_map<std::pair<size_t, size_t>, size_t, size_t_pair_hash_t> repair_lextr; // maps each cancellation pair <lmin_i, lmax_j> with range_rel_depth below rel_min_monotonicity_span_thld to the closest local extremum with basin containg one of the components of the pair
	std::vector<double> init_rel_min_monotonicity_spans;

	void absorb_basin(
        basin_t& absorbing_basin,
        const basin_t& absorbed_basin,
        const std::vector<double>& y,
        const set_wgraph_t& graph
		);

	basin_t* process_cancellation_pair(
		basin_t& A_basin,
		basin_t& B_basin,
		const std::vector<double>& y,
		const set_wgraph_t& graph
		);

	basin_t* process_single_basin(
		basin_t& A_basin,
		const std::vector<double>& y,
		const set_wgraph_t& graph
		);

	void write_basins_map(
		const std::string& out_dir,
		const std::string& prefix = ""
		) const;

};

#endif // BASIN_HPP
