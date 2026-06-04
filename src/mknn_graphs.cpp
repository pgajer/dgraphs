/*!
  Creating Mutual kNN graph (MkNN graph)

  Two points are connected if and only if they are within each other's k-nearest neighbor lists.

*/

#include "omp_compat.h"
#include "set_wgraph.hpp"
#include "knn_search_result.hpp"
#include "progress_utils.hpp" // For elapsed.time
#include "kNN_r.h"            // For S_kNN()

#include <ANN/ANN.h>  // ANN library header
#include <vector>
#include <unordered_set>
#include <unordered_map>
#include <utility>
#include <memory>
#include <chrono>
#include <numeric>            // For std::iota()

#include <R.h>
#include <Rinternals.h>

extern "C" {
    SEXP S_create_mknn_graph(SEXP RX, SEXP Rk);

    SEXP S_create_mknn_graphs(
        SEXP s_X,
        SEXP s_kmin,
        SEXP s_kmax,
        // pruning parameters
        SEXP s_max_path_edge_ratio_thld,
        SEXP s_path_edge_ratio_percentile,
        // other
        SEXP s_compute_full,
        SEXP s_verbose
        );
}

/**
 * @brief Creates a mutual k-nearest neighbors (MkNN) graph from a dataset
 *
 * @details
 * This function constructs a mutual k-nearest neighbors (MkNN) graph from the given data points.
 * In an MkNN graph, two points i and j are connected by an edge if and only if:
 * 1. j is among the k-nearest neighbors of i
 * 2. i is among the k-nearest neighbors of j
 *
 * The function uses the pre-computed kNN results to efficiently build the MkNN graph.
 * The weight of each edge is set to the Euclidean distance between the connected vertices.
 *
 * @param knn_results Pre-computed k-nearest neighbors results containing indices and distances
 * @param k Number of nearest neighbors to consider
 *
 * @return set_wgraph_t A weighted graph structure representing the MkNN graph,
 *         where each edge corresponds to a mutual kNN relationship with the weight
 *         equal to the distance between vertices
 *
 * @note
 * - The MkNN graph is undirected and typically much sparser than a standard kNN graph
 * - Only reciprocal nearest neighbor relationships are included in the graph
 * - The function expects knn_results to contain at least k nearest neighbors for each point
 */
set_wgraph_t create_mknn_graph(const knn_search_result_t& knn_results, int k) {
    size_t n_points = knn_results.n_points;

    // Initialize an empty graph with n_points vertices
    set_wgraph_t graph(n_points);

    // Create sets of k-nearest neighbors for each point for efficient lookup
    std::vector<std::unordered_set<int>> nn_sets(n_points);

    // Populate the sets with k-nearest neighbors
    for (size_t i = 0; i < n_points; ++i) {
        for (int j = 0; j < k; ++j) {
            nn_sets[i].insert(knn_results.indices[i][j]);
        }
    }

    // Create edges for mutual k-nearest neighbors
    for (size_t i = 0; i < n_points; ++i) {
        for (size_t j = i + 1; j < n_points; ++j) {
            // Check if i and j are mutual k-nearest neighbors
            if (nn_sets[i].count(j) > 0 && nn_sets[j].count(i) > 0) {
                // Find the distance between i and j
                double distance = 0.0;

                // Look up distance in knn_results
                for (int idx = 0; idx < k; ++idx) {
                    if (knn_results.indices[i][idx] == (int)j) {
                        distance = knn_results.distances[i][idx];
                        break;
                    }
                }

                // Add edge to the graph (both directions since the graph is undirected)
                graph.add_edge(i, j, distance);
            }
        }
    }

    return graph;
}

/**
 * @brief Computes and analyzes a series of mutual k-nearest neighbors graphs with geometric pruning
 *
 * @details
 * For a given range of k values [kmin, kmax], this function:
 * 1. Constructs and analyzes mutual k-nearest neighbors (MkNN) graphs
 * 2. Applies geometric pruning to each graph:
 *    - Removes edges where alternative paths exist with better geometric properties
 * 3. Computes comprehensive statistics for each graph before and after pruning
 * 4. Optionally returns the full pruned graph structures for further analysis
 *
 * The geometric pruning uses the path-to-edge ratio to determine which edges to remove:
 * - Edges are pruned when an alternative path exists with a better path-to-edge ratio
 * - The pruning threshold and percentile can be configured via parameters
 *
 * In MkNN graphs, two vertices i and j are connected if and only if j is among the k-nearest
 * neighbors of i AND i is among the k-nearest neighbors of j, making these graphs naturally
 * more sparse than standard kNN graphs.
 *
 * @param s_X SEXP object representing the input data matrix. Must be a numeric matrix
 *           where rows represent data points (vertices) and columns represent features
 *
 * @param s_kmin SEXP object (integer) representing the minimum k value to consider
 *              Must be positive
 *
 * @param s_kmax SEXP object (integer) representing the maximum k value to consider
 *              Must be greater than or equal to kmin
 *
 * @param s_max_path_edge_ratio_thld SEXP object (double) Maximum acceptable ratio of
 *        alternative path length to edge length for geometric pruning.
 *        Edges with ratio <= this value will be pruned. If <= 0, this pruning stage is skipped.
 *
 * @param s_path_edge_ratio_percentile SEXP object (double) Percentile threshold (0.0-1.0)
 *        for edge lengths to consider in geometric pruning. Only edges with length
 *        greater than this percentile are considered for pruning.
 *
 * @param s_compute_full SEXP object (logical) controlling computation of optional components:
 *                      - TRUE: Store complete pruned graph structures
 *                      - FALSE: Return only statistics without full graph structures
 *
 * @param s_verbose SEXP object (logical) controlling progress reporting during computation
 *
 * @return SEXP object (a named list) containing:
 * - k_statistics: Matrix with columns:
 *   - k: k value
 *   - n_edges: Total edges in original MkNN graph
 *   - n_edges_in_pruned_graph: Edges remaining after geometric pruning
 *   - n_removed_edges: Edges removed during geometric pruning
 *   - edge_reduction_ratio: Proportion of edges removed by geometric pruning
 *
 * - pruned_graphs: If compute_full is TRUE, list of geometrically pruned graphs for each k value,
 *                  each containing adj_list and weight_list components. NULL if compute_full is FALSE.
 *
 * - edge_pruning_stats: List of matrices, one for each k value, containing edge pruning statistics:
 *   - edge_length: Length of each analyzed edge
 *   - length_ratio: Ratio of alternative path length to edge length
 *
 * @note
 * - The function computes k-nearest neighbors only once with the maximum k value for efficiency
 * - Parallelization is implemented using OpenMP for processing multiple k values simultaneously
 * - MkNN graphs are naturally more sparse than standard kNN graphs, containing only reciprocal connections
 * - Geometric pruning preserves graph connectivity while reducing redundant connections
 * - All indices in returned R objects are 1-based (R convention)
 *
 * @see
 * - create_mknn_graph(): Creates a single mutual k-nearest neighbors graph
 * - set_wgraph_t::prune_edges_geometrically(): Geometric pruning implementation
 */
SEXP S_create_mknn_graphs(
    SEXP s_X,
    SEXP s_kmin,
    SEXP s_kmax,
    // pruning parameters
    SEXP s_max_path_edge_ratio_thld,
    SEXP s_path_edge_ratio_percentile,
    // other
    SEXP s_compute_full,
    SEXP s_verbose) {

    auto total_start_time = std::chrono::steady_clock::now();

    int kmin = INTEGER(s_kmin)[0];
    int kmax = INTEGER(s_kmax)[0];

    double max_path_edge_ratio_thld   = REAL(s_max_path_edge_ratio_thld)[0];
    double path_edge_ratio_percentile = REAL(s_path_edge_ratio_percentile)[0];

    int compute_full = (LOGICAL(s_compute_full)[0] == 1);
    int verbose = (LOGICAL(s_verbose)[0] == 1);

    SEXP s_dim = PROTECT(Rf_getAttrib(s_X, R_DimSymbol));
    if (s_dim == R_NilValue || TYPEOF(s_dim) != INTSXP || Rf_length(s_dim) < 1) {
        UNPROTECT(1);
        Rf_error("X must be a matrix with a valid integer 'dim' attribute.");
    }
    const int n_vertices = INTEGER(s_dim)[0];
    UNPROTECT(1); // s_dim

    if (verbose) {
        Rprintf("Processing k values from %d to %d for %d vertices\n", kmin, kmax, n_vertices);
    }

    // Create vector of k values
    std::vector<int> k_values(kmax - kmin + 1);
    std::iota(k_values.begin(), k_values.end(), kmin);

    // Parallel processing of graph creation and pruning
    if (verbose) Rprintf("Starting parallel graph processing\n");
    auto parallel_start_time = std::chrono::steady_clock::now();

    // Compute kNN once for maximum k
    auto knn_results = compute_knn(s_X, kmax);

    // Pre-allocate all data structures
    std::vector<set_wgraph_t> mknn_graphs(kmax - kmin + 1);
    std::vector<set_wgraph_t> pruned_graphs(kmax - kmin + 1);

    // Prepare vectors to store results
    std::vector<std::vector<double>> k_statistics(kmax - kmin + 1);
    std::vector<edge_pruning_stats_t> all_edge_pruning_stats(kmax - kmin + 1);

    // --- Thread setup (works with/without OpenMP) ---
    const int max_threads = gflow_get_max_threads();   // =1 when no OpenMP
    int num_threads = max_threads;                      // or clamp a user-supplied n_cores here
    gflow_set_num_threads(num_threads);                 // no-op when no OpenMP

    if (verbose) {
#if defined(_OPENMP)
        Rprintf("Using %d OpenMP thread%s\n", num_threads, (num_threads == 1 ? "" : "s"));
#else
        Rprintf("OpenMP not enabled; running single-threaded.\n");
#endif
    }

    // --- Parallel region (serial when no OpenMP) ---
    const int nK = (kmax - kmin + 1);

#if defined(_OPENMP)
#pragma omp parallel for schedule(dynamic)
#endif
    for (int k_idx = 0; k_idx < nK; ++k_idx) {
        const int k = kmin + k_idx;

        if (verbose) {
#if defined(_OPENMP)
#pragma omp critical
#endif
            {
                REprintf("\rProcessing k=%d (%d of %d) - %d%%",
                         k, k_idx + 1, nK, static_cast<int>((100.0 * (k_idx + 1)) / nK));
                R_FlushConsole();  // helpful on some R consoles
            }
        }

        // nice final newline after the carriage-return progress output
        if (verbose) REprintf("\n");

        // Create mutual kNN graph for current k value
        auto mknn_graph = create_mknn_graph(knn_results, k);

        // Count original edges
        size_t n_edges = 0;
        for (const auto& neighbors : mknn_graph.adjacency_list) {
            n_edges += neighbors.size();
        }
        n_edges /= 2; // Each edge is counted twice in undirected graph

        // Store the original graph
        mknn_graphs[k_idx] = std::move(mknn_graph);

        // Apply geometric pruning if threshold is positive
        set_wgraph_t pruned_graph;
        if (max_path_edge_ratio_thld > 0) {
            pruned_graph = mknn_graphs[k_idx].prune_edges_geometrically(
                max_path_edge_ratio_thld,
                path_edge_ratio_percentile
            );
        } else {
            // If pruning is disabled, just copy the original graph
            pruned_graph = mknn_graphs[k_idx];
        }

        // Count edges in pruned graph
        size_t n_edges_in_pruned_graph = 0;
        for (const auto& neighbors : pruned_graph.adjacency_list) {
            n_edges_in_pruned_graph += neighbors.size();
        }
        n_edges_in_pruned_graph /= 2;

        // Store results
        k_statistics[k_idx] = {
            (double)n_edges,
            (double)n_edges_in_pruned_graph,
            (double)(n_edges - n_edges_in_pruned_graph),
            (double)(n_edges - n_edges_in_pruned_graph) / n_edges
        };

        // Compute edge pruning stats
        all_edge_pruning_stats[k_idx] = pruned_graph.compute_edge_pruning_stats(path_edge_ratio_percentile);

        // Store the pruned graph
        pruned_graphs[k_idx] = std::move(pruned_graph);
    }

    if (verbose) {
        elapsed_time(parallel_start_time, "\rParallel processing completed", true);
    }

    // Set up a start time for creating return list objects
    auto serial_start_time = std::chrono::steady_clock::now();
    if (verbose) {
        Rprintf("Creating return list objects ... ");
    }

    //
    // Create return list
    //
    SEXP result = PROTECT(Rf_allocVector(VECSXP, 3));
    {
        SEXP names = PROTECT(Rf_allocVector(STRSXP, 3));
        SET_STRING_ELT(names, 0, Rf_mkChar("k_statistics"));
        SET_STRING_ELT(names, 1, Rf_mkChar("pruned_graphs"));
        SET_STRING_ELT(names, 2, Rf_mkChar("edge_pruning_stats"));
        Rf_setAttrib(result, R_NamesSymbol, names);
        UNPROTECT(1); // names
    }

    // 2:
    {
        // Create a list to hold all the edge pruning stats matrices
        SEXP edge_stats_list = PROTECT(Rf_allocVector(VECSXP, kmax - kmin + 1));

        // Fill the list with edge stats matrices for each k value
        for (int k_idx = 0; k_idx < kmax - kmin + 1; k_idx++) {
            const auto& edge_pruning_stats = all_edge_pruning_stats[k_idx];

            // Create matrix for this k value's stats
            SEXP edge_stats_matrix = PROTECT(Rf_allocMatrix(REALSXP, edge_pruning_stats.stats.size(), 2));
            double* stats_data = REAL(edge_stats_matrix);

            // Fill the matrix with data - edge_length and length_ratio
            for (size_t i = 0; i < edge_pruning_stats.stats.size(); i++) {
                const auto& stat = edge_pruning_stats.stats[i];
                stats_data[i] = stat.edge_length;
                stats_data[i + edge_pruning_stats.stats.size()] = stat.length_ratio;
            }

            // Set column names for the matrix
            {
                SEXP stats_dimnames = PROTECT(Rf_allocVector(VECSXP, 2));
                SET_VECTOR_ELT(stats_dimnames, 0, R_NilValue);  // No row names
                {
                SEXP stats_colnames = PROTECT(Rf_allocVector(STRSXP, 2));
                SET_STRING_ELT(stats_colnames, 0, Rf_mkChar("edge_length"));
                SET_STRING_ELT(stats_colnames, 1, Rf_mkChar("length_ratio"));
                SET_VECTOR_ELT(stats_dimnames, 1, stats_colnames);
                UNPROTECT(1); // stats_colnames
                }
                Rf_setAttrib(edge_stats_matrix, R_DimNamesSymbol, stats_dimnames);
                UNPROTECT(1); // stats_dimnames
            }

            // Add this matrix to the list
            SET_VECTOR_ELT(edge_stats_list, k_idx, edge_stats_matrix);
            UNPROTECT(1); // edge_stats_matrix
        }

        // Set names for the edge_stats_list (k values)
        {
            SEXP edge_stats_list_names = PROTECT(Rf_allocVector(STRSXP, kmax - kmin + 1));
            for (int k_idx = 0; k_idx < kmax - kmin + 1; k_idx++) {
                SET_STRING_ELT(edge_stats_list_names, k_idx, Rf_mkChar(std::to_string(kmin + k_idx).c_str()));
            }
            Rf_setAttrib(edge_stats_list, R_NamesSymbol, edge_stats_list_names);
            UNPROTECT(1); // edge_stats_list_names
        }

        SET_VECTOR_ELT(result, 2, edge_stats_list);
        UNPROTECT(1); // edge_stats_list
    }

    if (compute_full) {
        SEXP pruned_graphs_list = PROTECT(Rf_allocVector(VECSXP, kmax - kmin + 1));

        for (int k_idx = 0; k_idx < kmax - kmin + 1; k_idx++) {
            // Process pruned graph
            const auto& pruned_graph = pruned_graphs[k_idx];

            SEXP r_pruned_adj_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));
            SEXP r_pruned_weight_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));

            for (int i = 0; i < n_vertices; i++) {
                // Convert set of edge_info_t to vectors for R
                const auto& edges = pruned_graph.adjacency_list[i];

                {
                    SEXP RA = PROTECT(Rf_allocVector(INTSXP, edges.size()));
                    int* A = INTEGER(RA);
                    for (const auto& edge : edges) {
                        *A++ = edge.vertex + 1; // Convert to 1-based indexing for R
                    }
                    SET_VECTOR_ELT(r_pruned_adj_list, i, RA);
                    UNPROTECT(1);
                }

                {
                    SEXP RD = PROTECT(Rf_allocVector(REALSXP, edges.size()));
                    double* D = REAL(RD);
                    for (const auto& edge : edges) {
                        *D++ = edge.weight;
                    }
                    SET_VECTOR_ELT(r_pruned_weight_list, i, RD);
                    UNPROTECT(1);
                }
            }

            SEXP r_pruned_graph = PROTECT(Rf_allocVector(VECSXP, 2));
            SET_VECTOR_ELT(r_pruned_graph, 0, r_pruned_adj_list);
            SET_VECTOR_ELT(r_pruned_graph, 1, r_pruned_weight_list);

            SEXP r_pruned_graph_names = PROTECT(Rf_allocVector(STRSXP, 2));
            SET_STRING_ELT(r_pruned_graph_names, 0, Rf_mkChar("adj_list"));
            SET_STRING_ELT(r_pruned_graph_names, 1, Rf_mkChar("weight_list"));
            Rf_setAttrib(r_pruned_graph, R_NamesSymbol, r_pruned_graph_names);

            SET_VECTOR_ELT(pruned_graphs_list, k_idx, r_pruned_graph);
            UNPROTECT(4);
        }
        SET_VECTOR_ELT(result, 1, pruned_graphs_list);
        UNPROTECT(1); // pruned_graphs_list
    } else {
        SET_VECTOR_ELT(result, 1, R_NilValue);
    }

    // Create statistics matrix
    {
        SEXP k_stats_matrix = PROTECT(Rf_allocMatrix(REALSXP, k_statistics.size(), 5));
        double* data = REAL(k_stats_matrix);
        for (size_t i = 0; i < k_statistics.size(); i++) {
            data[i] = kmin + i;
            for (size_t j = 0; j < 4; j++) {
                data[i + (j + 1) * k_statistics.size()] = k_statistics[i][j];
            }
        }

        {
            // Set column names
            SEXP k_stats_dimnames = PROTECT(Rf_allocVector(VECSXP, 2));
            SET_VECTOR_ELT(k_stats_dimnames, 0, R_NilValue);

            SEXP k_stats_colnames = PROTECT(Rf_allocVector(STRSXP, 5));
            SET_STRING_ELT(k_stats_colnames, 0, Rf_mkChar("k"));
            SET_STRING_ELT(k_stats_colnames, 1, Rf_mkChar("n_edges"));
            SET_STRING_ELT(k_stats_colnames, 2, Rf_mkChar("n_edges_in_pruned_graph"));
            SET_STRING_ELT(k_stats_colnames, 3, Rf_mkChar("n_removed_edges"));
            SET_STRING_ELT(k_stats_colnames, 4, Rf_mkChar("edge_reduction_ratio"));

            SET_VECTOR_ELT(k_stats_dimnames, 1, k_stats_colnames);
            Rf_setAttrib(k_stats_matrix, R_DimNamesSymbol, k_stats_dimnames);
            UNPROTECT(2); // k_stats_dimnames, k_stats_colnames
        }
        SET_VECTOR_ELT(result, 0, k_stats_matrix);
        UNPROTECT(1); // k_stats_matrix
    }

    if (verbose) {
        elapsed_time(serial_start_time, "DONE", true);
        elapsed_time(total_start_time, "Total elapsed time", true);
    }

    UNPROTECT(1); // result
    return result;
}


/*!
  Creates a mutual kNN graph with weights

  This function creates a mutual kNN graph that connects two points of X with an
  edge if and only if they are within each other's k-nearest neighbor lists. The
  weight of the edge is the distance between the vertices in X.

  \param X A matrix of points.
  \param k The number of nearest neighbors to use for the construction of the kNN graph.

  \return Returns a list with two components: 1) adjacency list, A, such that
  A[[i]] is a vector of vertices connected with the i-th vertex by an edge; 2)
  weights list, W, such that W[[i]] is a vector of distances between the i-th
  vertex and the neighbor vertices of that vertex.
*/
SEXP S_create_mknn_graph(SEXP RX, SEXP Rk) {

    SEXP s_dim = PROTECT(Rf_getAttrib(RX, R_DimSymbol));
    if (s_dim == R_NilValue || TYPEOF(s_dim) != INTSXP || Rf_length(s_dim) < 2) {
        UNPROTECT(1);
        Rf_error("X must be a matrix with a valid integer 'dim' attribute.");
    }
    const int nrX = INTEGER(s_dim)[0];
    const int ncX = INTEGER(s_dim)[1];
    UNPROTECT(1); // s_dim

    int k = Rf_asInteger(Rk);
    if (nrX <= 0 || ncX <= 0) {
        Rf_error("X must have positive dimensions.");
    }
    if (k <= 0 || k > nrX) {
        Rf_error("k must be positive and no greater than the number of rows in X.");
    }

    // Finding kNN's for all points of X
    SEXP knn_res = PROTECT(S_kNN(RX, Rk));
    int *indices = INTEGER(VECTOR_ELT(knn_res, 0));
    double *distances = REAL(VECTOR_ELT(knn_res, 1));

    if (indices == NULL) {
        UNPROTECT(1); // knn_res
        Rf_error("MW_kNN_graph: Error in S_kNN: kNN index extraction failed.");
    }

    if (distances == NULL) {
        UNPROTECT(1); // knn_res
        Rf_error("MW_kNN_graph: Error in S_kNN: kNN distances extraction failed.");
    }

    std::vector<std::unordered_set<int>> nn_sets(nrX);
    std::vector<std::unordered_map<int, double>> nn_distances(nrX);
    // Populate nn_sets with the k-nearest neighbors of each point
    for (int pt_i = 0; pt_i < nrX; ++pt_i) {
        for (int j = 0; j < k; ++j) {
            const int neighbor = indices[pt_i + nrX * j];
            if (neighbor < 0 || neighbor >= nrX) {
                UNPROTECT(1); // knn_res
                Rf_error("MW_kNN_graph: S_kNN returned an out-of-range neighbor index.");
            }
            nn_sets[pt_i].insert(neighbor);
            nn_distances[pt_i][neighbor] = distances[pt_i + nrX * j];
        }
    }

    auto adj_vect = std::make_unique<std::vector<std::vector<int>>>(nrX);       // Adjacency vector
    auto dists_vect = std::make_unique<std::vector<std::vector<double>>>(nrX);  // Distances vector

    // Find mutual k-nearest neighbors and add edges
    double d;
    for (int pt_i = 0; pt_i < nrX; ++pt_i) {
        for (int pt_j : nn_sets[pt_i]) {
            if (pt_i < pt_j && nn_sets[pt_j].count(pt_i) > 0) {
                (*adj_vect)[pt_i].push_back(pt_j);
                (*adj_vect)[pt_j].push_back(pt_i);
                d = nn_distances[pt_i][pt_j];
                (*dists_vect)[pt_i].push_back(d);
                (*dists_vect)[pt_j].push_back(d);
            }
        }
    }

    UNPROTECT(1); // knn_res

    // Prepare return list
    SEXP res = PROTECT(Rf_allocVector(VECSXP, 2)); // List with 2 elements

    // Add names to list elements
    {
        SEXP names = PROTECT(Rf_allocVector(STRSXP, 2));
        SET_STRING_ELT(names, 0, Rf_mkChar("adj_list"));
        SET_STRING_ELT(names, 1, Rf_mkChar("weight_list"));
        Rf_setAttrib(res, R_NamesSymbol, names);
        UNPROTECT(1); // names
    }

    // Creating adj_list associated with adj_vect
    SEXP adj_list = PROTECT(Rf_allocVector(VECSXP, nrX));  // List with nrX components; each component hold indices of points adjacent to the given point (index of the list)
    for (int i = 0; i < nrX; i++) {
        SEXP RA = PROTECT(Rf_allocVector(INTSXP, adj_vect->at(i).size())); // Adjacency list of the i-th vertex
        int* A = INTEGER(RA);

        for (auto neighbor : adj_vect->at(i))
            *A++ = neighbor + 1;

        SET_VECTOR_ELT(adj_list, i, RA);
        UNPROTECT(1);
    }

    // Creating dists_list associated with dists_vect
    SEXP dists_list = PROTECT(Rf_allocVector(VECSXP, nrX));  // List with nrX components; each component hold indices of points adjacent to the given point (index of the list)
    for (int i = 0; i < nrX; i++) {
        SEXP RW = PROTECT(Rf_allocVector(REALSXP, dists_vect->at(i).size())); // Dists list of the i-th vertex
        double* W = REAL(RW);

        for (auto dist : dists_vect->at(i))
            *W++ = dist;

        SET_VECTOR_ELT(dists_list, i, RW);
        UNPROTECT(1);
    }

    SET_VECTOR_ELT(res, 0, adj_list);
    SET_VECTOR_ELT(res, 1, dists_list);

    UNPROTECT(3); // res, adj_list, dists_list
    return res;
}
