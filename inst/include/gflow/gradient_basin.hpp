#ifndef GRADIENT_BASIN_H_
#define GRADIENT_BASIN_H_

#include <unordered_map>
using std::size_t;

/**
 * @brief Structure to store all trajectories terminating at a specific terminal extremum.
 */
struct trajectory_set_t {
    size_t terminal_vertex;                          // terminal extremum vertex
    std::vector<std::vector<size_t>> trajectories;   // all paths from this terminal to origin
};

/**
 * @brief Structure representing a gradient basin of attraction with complete trajectory information.
 *
 * This structure extends the basic basin representation to store all valid predecessors
 * for each vertex, enabling complete reconstruction of all gradient flow trajectories
 * within the basin.
 */
struct gradient_basin_t {
    size_t vertex;                                   // extremum vertex (origin of basin)
    double value;                                    // y value at extremum
    bool is_maximum;                                 // true if descending basin, false if ascending
    size_t hop_idx;                                  // maximum hop distance in basin
    std::unordered_map<size_t, size_t> hop_dist_map; // vertex -> hop distance from origin

    // All valid predecessors for complete trajectory reconstruction
    std::unordered_map<size_t, std::vector<size_t>> all_predecessors; // vertex -> all valid predecessors
    // Complete trajectory enumeration (populated only if requested)
    std::vector<trajectory_set_t> trajectory_sets;   // trajectories organized by terminal

    std::unordered_map<size_t, double> y_nbhd_bd_map; // boundary vertices -> y value
    std::vector<size_t> terminal_extrema;            // indices of terminal extrema reachable from origin
};

#endif // GRADIENT_BASIN_H_
