#include "dgraphs/graph_utils.hpp" // for get_grid_diameter()
#include "dgraphs/uniform_grid_graph.hpp"
#include "dgraphs/SEXP_cpp_conversion_utils.hpp"
#include "dgraphs/cpp_utils.hpp"
#include "dgraphs/error_utils.h"
#include "dgraphs/kernels.h"

#include <vector>
#include <queue>
#include <set>
#include <unordered_set>
#include <cmath>
#include <utility>
#include <tuple>
#include <numeric>

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

extern "C" {
    SEXP S_create_maximal_packing(SEXP s_adj_list,
                                  SEXP s_weight_list,
                                  SEXP s_grid_size,
                                  SEXP s_max_iterations,
                                  SEXP s_precision);
}

/**
 * @brief Creates a maximal packing of vertices and returns it as an R-compatible structure
 *
 * This function creates a maximal packing of vertices based on grid size parameters and
 * converts the resulting uniform grid graph back to R-compatible data structures. The packing
 * algorithm places vertices on the graph such that they are separated by approximately the
 * specified grid size. The function also calculates and returns the graph diameter and
 * the optimal packing radius used.
 *
 * @param s_adj_list An R list containing adjacency lists for each vertex (0-based in C++, 1-based in R)
 * @param s_weight_list An R list containing weight lists corresponding to each adjacency list
 * @param s_grid_size An R integer specifying the target grid size (distance between packed vertices)
 * @param s_max_iterations An R integer specifying the maximum number of iterations for the algorithm
 * @param s_precision An R double specifying the precision threshold for convergence
 *
 * @return An R list with five named components:
 *   - adj_list: A list of adjacency lists for each vertex in the resulting graph
 *   - weight_list: A list of weight lists corresponding to each adjacency entry
 *   - grid_vertices: An integer vector containing the indices of vertices in the maximal packing
 *   - graph_diameter: A double value representing the computed diameter of the graph
 *   - max_packing_radius: A double value representing the optimal radius used for the final packing
 *
 * @note All indices in the returned R structures are 1-based, while internal C++ processing uses 0-based indexing
 * @note The function handles R's garbage collection through PROTECT/UNPROTECT mechanism
 * @note The graph_diameter represents the maximum shortest path distance between any two vertices in the graph
 * @note The max_packing_radius represents the minimum distance between any two vertices in the packing
 *
 * @see uniform_grid_graph_t
 * @see create_maximal_packing
 */
SEXP S_create_maximal_packing(SEXP s_adj_list,
                              SEXP s_weight_list,
                              SEXP s_grid_size,
                              SEXP s_max_iterations,
                              SEXP s_precision) {

    // Convert R inputs to C++ types
    std::vector<std::vector<int>> adj_list       = convert_adj_list_from_R(s_adj_list);
    std::vector<std::vector<double>> weight_list = convert_weight_list_from_R(s_weight_list);
    int grid_size = INTEGER(s_grid_size)[0];
    int max_iterations = INTEGER(s_max_iterations)[0];
    double precision = REAL(s_precision)[0];

    // The returned uniform_grid_graph_t object inherits both the graph_diameter
    // and max_packing_radius values from the intermediate set_wgraph_t object,
    // making these calculated values available for further analysis.
    uniform_grid_graph_t grid_graph = create_maximal_packing(
        adj_list,
        weight_list,
        grid_size,
        max_iterations,
        precision);

    // Creating return list

    const int N_COMPONENTS = 5;  // Increased from 3 to 5
    SEXP r_result = PROTECT(Rf_allocVector(VECSXP, N_COMPONENTS));

    // Set names for return list
    {
        SEXP names = PROTECT(Rf_allocVector(STRSXP, N_COMPONENTS));
        SET_STRING_ELT(names, 0, Rf_mkChar("adj_list"));
        SET_STRING_ELT(names, 1, Rf_mkChar("weight_list"));
        SET_STRING_ELT(names, 2, Rf_mkChar("grid_vertices"));
        SET_STRING_ELT(names, 3, Rf_mkChar("graph_diameter"));       // Add name for graph diameter
        SET_STRING_ELT(names, 4, Rf_mkChar("max_packing_radius"));   // Add name for max packing radius
        Rf_setAttrib(r_result, R_NamesSymbol, names);
        UNPROTECT(1); // names
    }

    // Extract adjacency and weight lists from grid_graph
    int n_total_vertices = grid_graph.adjacency_list.size();

    // adj_list, weight_list
    {
        SEXP r_adj_list = PROTECT(Rf_allocVector(VECSXP, n_total_vertices));
        SEXP r_weight_list = PROTECT(Rf_allocVector(VECSXP, n_total_vertices));

        // Convert the set-based representation back to R lists
        for (int i = 0; i < n_total_vertices; ++i) {
            const auto& neighbors = grid_graph.adjacency_list[i];

            // Create vectors for this vertex's adjacency list and weights
            SEXP r_adj = PROTECT(Rf_allocVector(INTSXP, neighbors.size()));
            SEXP r_weights = PROTECT(Rf_allocVector(REALSXP, neighbors.size()));

            // Fill the vectors
            int idx = 0;
            for (const auto& [neighbor, weight] : neighbors) {
                // Convert to 1-based indices for R
                INTEGER(r_adj)[idx] = neighbor + 1;
                REAL(r_weights)[idx] = weight;
                ++idx;
            }

            SET_VECTOR_ELT(r_adj_list, i, r_adj);
            SET_VECTOR_ELT(r_weight_list, i, r_weights);
            UNPROTECT(2); // for r_adj and r_weights
        }

        SET_VECTOR_ELT(r_result, 0, r_adj_list);
        SET_VECTOR_ELT(r_result, 1, r_weight_list);
        UNPROTECT(2); // r_adj_list, r_weight_list
    }

    // Create grid vertices vector (1-based indices)
    {
        int n_grid_vertices = grid_graph.grid_vertices.size();
        SEXP r_grid_vertices = PROTECT(Rf_allocVector(INTSXP, n_grid_vertices));

        int counter = 0;
        for (const auto& i : grid_graph.grid_vertices) {
            // Convert to 1-based indices for R
            INTEGER(r_grid_vertices)[counter++] = i + 1;
        }

        SET_VECTOR_ELT(r_result, 2, r_grid_vertices);
        UNPROTECT(1); // r_grid_vertices
    }

    // Create graph diameter and max packing radius values
    {
        SEXP r_graph_diameter = PROTECT(Rf_allocVector(REALSXP, 1));
        REAL(r_graph_diameter)[0] = grid_graph.graph_diameter;

        SET_VECTOR_ELT(r_result, 3, r_graph_diameter);
        UNPROTECT(1); // r_graph_diameter
    }

    // max packing radius
    {
        SEXP r_max_packing_radius = PROTECT(Rf_allocVector(REALSXP, 1));
        REAL(r_max_packing_radius)[0] = grid_graph.max_packing_radius;

        SET_VECTOR_ELT(r_result, 4, r_max_packing_radius);
        UNPROTECT(1); // r_max_packing_radius
    }

    UNPROTECT(1); // r_result
    return r_result;
}
