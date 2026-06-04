#ifndef MS_COMPLEX_H_
#define MS_COMPLEX_H_

#include <vector>     // for std::vector
#include <set>        // for std::set
#include <map>        // for std::map
#include <utility>    // for std::pair
#include <cstddef>

using std::size_t;

struct hop_neighbor_info_t {
    int vertex;              ///< The neighboring vertex
    int hop_distance;        ///< Number of hops to the neighbor
    double diff_value;       ///< Difference in scalar values between vertices
    std::vector<int> path;   ///< Path to the neighbor
};

/**
 * @brief Represents a specific cell in the Morse-Smale complex
 */
struct cell_t {
    int lmax;           ///< Local maximum of the cell
    int lmin;           ///< Local minimum of the cell
    int cell_index;     ///< Index of this cell within the vector of cells for this (lmax,lmin) pair

    // Define ordering for use as map key
    bool operator<(const cell_t& other) const {
        if (lmax != other.lmax) return lmax < other.lmax;
        if (lmin != other.lmin) return lmin < other.lmin;
        return cell_index < other.cell_index;
    }

    bool operator==(const cell_t& other) const {
        return lmax == other.lmax && lmin == other.lmin && cell_index == other.cell_index;
    }
};

struct MS_complex_t {
    std::map<int, std::set<int>> lmax_to_lmin;    ///< Maps local maxima to their connected local minima
    std::map<int, std::set<int>> lmin_to_lmax;    ///< Maps local minima to their connected local maxima
    std::set<int> local_maxima;                   ///< Set of all local maxima vertices
    std::set<int> local_minima;                   ///< Set of all local minima vertices
    std::map<std::pair<int,int>, std::set<int>> procells;    ///< Maps (max,min) pairs to their proto-cells
    std::map<std::pair<int,int>, std::vector<std::set<int>>> cells;  ///< Maps (max,min) pairs to their decomposed cells
    std::vector<std::vector<int>> unique_trajectories;  ///< Vector of unique trajectories (max->min paths)
    std::map<cell_t, std::set<size_t>> cell_trajectories;  ///< Maps cells to indices of their trajectories
};

struct MS_complex_plus_t {
    std::map<int, std::set<int>> lmax_to_lmin;    ///< Maps local maxima to their connected local minima
    std::map<int, std::set<int>> lmin_to_lmax;    ///< Maps local minima to their connected local maxima
    std::set<int> local_maxima;                   ///< Set of all local maxima vertices
    std::set<int> local_minima;                   ///< Set of all local minima vertices
    std::map<std::pair<int,int>, std::set<int>> procells;    ///< Maps (max,min) pairs to their proto-cells
    std::map<std::pair<int,int>, std::vector<std::set<int>>> cells;  ///< Maps (max,min) pairs to their decomposed cells
    std::vector<std::vector<int>> unique_trajectories;  ///< Vector of unique trajectories (max->min paths)
    std::map<cell_t, std::set<size_t>> cell_trajectories;
    // path graph fields
    std::vector<std::vector<int>> path_graph_adj_list;
    std::vector<std::vector<double>> path_graph_weight_list;
    std::map<std::pair<int,int>, std::vector<int>> shortest_paths;
    // Ey field
    std::vector<double> Ey; ///< smoothed estimate of the conditional expectation of y; NULL if Ey was supplied
    //
    int h_value; // Store which h-value this MS complex corresponds to///< Maps cells to indices of their trajectories
};

#endif // MS_COMPLEX_H_
