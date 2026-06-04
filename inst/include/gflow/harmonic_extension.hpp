/**
 * @file harmonic_extension.hpp
 * @brief Harmonic extension of trajectory coordinates to tubular neighborhoods
 *
 * Provides functionality for extending a one-dimensional parameterization of a
 * geodesic trajectory to nearby vertices via the solution of the discrete Laplace
 * equation with Dirichlet boundary conditions.
 */

#ifndef HARMONIC_EXTENSION_HPP
#define HARMONIC_EXTENSION_HPP

#include <vector>
#include <unordered_set>
#include <unordered_map>
#include <cstddef>

/**
 * @brief Tubular neighborhood result (internal)
 */
struct tubular_neighborhood_t {
    std::vector<size_t> vertices;
    std::vector<int> hop_distances;
    std::vector<double> geodesic_distances;
    std::vector<size_t> nearest_traj_idx;
};

/**
 * @brief Type of tubular neighborhood radius
 */
enum class tube_radius_type_t {
    HOP,       ///< Combinatorial: count edge traversals
    GEODESIC   ///< Geometric: sum edge weights
};

/**
 * @brief Parameters for harmonic extension computation
 */
struct harmonic_extension_params_t {
    /// Radius of tubular neighborhood
    double tube_radius = 2.0;

    /// Type of radius measurement
    tube_radius_type_t tube_type = tube_radius_type_t::HOP;

    /// Use inverse edge length as Laplacian weights (true) or unit weights (false)
    bool use_edge_weights = true;

    /// Maximum iterations for Gauss-Seidel solver
    int max_iterations = 1000;

    /// Convergence tolerance
    double tolerance = 1e-8;

    /// Restrict tubular neighborhood to vertices within a basin (empty = no restriction)
    std::unordered_set<size_t> basin_restriction;
};

/**
 * @brief Result of harmonic extension computation
 */
struct harmonic_extension_result_t {
    /// Trajectory vertices in order from minimum to maximum
    std::vector<size_t> trajectory;

    /// Arc-length coordinates for trajectory vertices, in [0,1]
    std::vector<double> trajectory_coords;

    /// Total geodesic length of trajectory
    double trajectory_length;

    /// Vertices in the tubular neighborhood (includes trajectory)
    std::vector<size_t> tubular_vertices;

    /// Hop distance from trajectory for each tubular vertex
    std::vector<int> hop_distances;

    /// Geodesic distance from trajectory for each tubular vertex
    std::vector<double> geodesic_distances;

    /// Index into trajectory of nearest trajectory vertex for each tubular vertex
    std::vector<size_t> nearest_traj_idx;

    /// Extended coordinates for all tubular vertices, in [0,1]
    std::vector<double> extended_coords;

    /// Number of iterations for convergence
    int n_iterations;

    /// Final maximum change (convergence criterion)
    double final_max_change;

    /// Type of radius used
    tube_radius_type_t tube_type;

    /// Radius value used
    double tube_radius;

    /// Mapping from vertex index to position in tubular_vertices
    std::unordered_map<size_t, size_t> vertex_to_idx;
};

#endif // HARMONIC_EXTENSION_HPP
