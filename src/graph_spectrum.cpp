#include "dgraphs/omp_compat.h"
#include "dgraphs/Eigen_utils.h"
#include "dgraphs/graph_spectrum_r.h"
#include "dgraphs/SEXP_cpp_conversion_utils.hpp"

#include <vector>
#include <queue>
#include <set>
#include <memory>
#include <cmath>
#include <limits>
#include <algorithm>
#include <unordered_set>
#include <set>
#include <map>
#include <numeric>

#include <Eigen/Core>
#include <Eigen/Dense>
#include <Eigen/SparseCore>
#include <Spectra/SymEigsSolver.h>
#include <Spectra/MatOp/SparseSymMatProd.h>
#include <Spectra/MatOp/DenseSymMatProd.h>

#include <R.h>
#include <Rinternals.h>

struct graph_spectrum_t {
    Eigen::VectorXd evalues;
    Eigen::MatrixXd evectors;
};

//
// Graph spectrum
//
// This function computes the first `nev` eigenvalues and eigenvectors of the
// Laplacian matrix of a given graph.
//
// Parameters:
// - graph: A vector of vectors representing the adjacency list of the graph.
// - nev: The number of eigenvalues and eigenvectors to compute.
//
// Returns:
// - A unique pointer to a `graph_spectrum_t` structure containing the computed
//   eigenvalues and eigenvectors.
//
std::unique_ptr<graph_spectrum_t> graph_spectrum(std::vector<std::vector<int>>& graph,
                                                 int nev) {

    int n_vertices = graph.size();

    // Adjacency matrix as a sparse matrix
    Eigen::SparseMatrix<double> A(n_vertices, n_vertices);
    std::vector<Eigen::Triplet<double>> tripletList;
    for (int vertex = 0; vertex < n_vertices; ++vertex) {
        for (int neighbor : graph[vertex]) {
            if (vertex < neighbor) {  // Ensure each edge is added only once
                tripletList.push_back(Eigen::Triplet<double>(vertex, neighbor, 1.0));
                tripletList.push_back(Eigen::Triplet<double>(neighbor, vertex, 1.0));
            }
        }
    }
    A.setFromTriplets(tripletList.begin(), tripletList.end());

    // Compute Laplacian matrix as a sparse matrix
    Eigen::SparseMatrix<double> D(n_vertices, n_vertices);
    for (int k = 0; k < A.outerSize(); ++k) {
        double sum = 0;
        for (Eigen::SparseMatrix<double>::InnerIterator it(A, k); it; ++it) {
            sum += it.value();
        }
        D.insert(k, k) = sum;
    }
    Eigen::SparseMatrix<double> L = D - A;

    // Eigenvalue decomposition
    Spectra::SparseSymMatProd<double> op(L);

    // Ensure ncv is within bounds: nev < ncv <= n
    nev = std::min(nev, n_vertices);
    int ncv = std::min(2 * nev, n_vertices); // Adjust ncv to be within bounds
    // Ensure nev < ncv
    if (nev >= ncv) {
        nev = ncv - 1;
    }

    if (nev < 1) {
        nev = 1;
    }

    // Construct eigen solver object to find eigenvalues closest to 0

    // ncv rule-of-thumb: 3*nev is often safer for hard problems
    int ncv_default = std::max(2 * nev + 10, 150);  // for nev=50 => at least 150
    ncv_default = std::min(ncv_default, (int)L.rows()); // cannot exceed n

    Spectra::SymEigsSolver<Spectra::SparseSymMatProd<double>> eigs(op, nev, ncv_default);
    eigs.init();
    eigs.compute(Spectra::SortRule::SmallestAlge);

    if (eigs.info() != Spectra::CompInfo::Successful)
        Rf_error("Eigenvalue estimation with Spectra failed.");

    Eigen::VectorXd evalues = eigs.eigenvalues();
    Eigen::MatrixXd evectors = eigs.eigenvectors();

    auto result = std::make_unique<graph_spectrum_t>();
    result->evalues = evalues;
    result->evectors = evectors;

    return result;
}

//' Graph spectrum
//'
//' This function computes the first `nev` eigenvectors and eigenvalues of the
//' given graph's Laplacian.
//'
//' @param Rgraph List of integer vectors representing the adjacency list of the graph.
//' @param Rnev Integer specifying the number of eigenvalues and eigenvectors to compute.
//' @return A list containing the eigenvalues and eigenvectors.
//' @export
SEXP S_graph_spectrum(SEXP Rgraph, SEXP Rnev) {

    std::vector<std::vector<int>> graph = convert_adj_list_from_R(Rgraph);
    int nev = INTEGER(Rnev)[0];

    std::unique_ptr<graph_spectrum_t> result = graph_spectrum(graph, nev);

    // Creating return list
    SEXP ret = PROTECT(Rf_allocVector(VECSXP, 2));
    SET_VECTOR_ELT(ret, 0, EigenVectorXd_to_SEXP(result->evalues));
    SET_VECTOR_ELT(ret, 1, EigenMatrixXd_to_SEXP(result->evectors));

    SEXP names = PROTECT(Rf_allocVector(STRSXP, 2));
    SET_STRING_ELT(names, 0, Rf_mkChar("evalues"));
    SET_STRING_ELT(names, 1, Rf_mkChar("evectors"));
    Rf_setAttrib(ret, R_NamesSymbol, names);

    UNPROTECT(2);
    return ret;
}


// ------------------------------------------------------------------------------------
//
// Versions of graph_spectrum returning also graph Laplacian
//
// ------------------------------------------------------------------------------------

struct graph_spectrum_plus_t {
    Eigen::VectorXd evalues;
    Eigen::MatrixXd evectors;
    Eigen::SparseMatrix<double> L;
    Eigen::MatrixXd dense_L;
};

/**
 * Graph spectrum
 *
 * This function computes the first `nev` eigenvalues and eigenvectors of the
 * Laplacian matrix of a given graph. Optionally, it can return the Laplacian
 * matrix in either sparse or dense format.
 *
 * Parameters:
 * - graph: A vector of vectors representing the adjacency list of the graph.
 * - nev: The number of eigenvalues and eigenvectors to compute.
 * - return_dense: A boolean indicating whether to return the Laplacian matrix
 *   in dense format. If false, the Laplacian matrix is returned in sparse format.
 *
 * Returns:
 * - A unique pointer to a `graph_spectrum_t` structure containing the computed
 *   eigenvalues, eigenvectors, and the Laplacian matrix.
 *
 */
std::unique_ptr<graph_spectrum_plus_t> graph_spectrum_plus(std::vector<std::vector<int>>& graph,
                                                           int nev,
                                                           bool return_dense) {
    int n_vertices = graph.size();

    // Adjacency matrix as a sparse matrix
    Eigen::SparseMatrix<double> A(n_vertices, n_vertices);
    std::vector<Eigen::Triplet<double>> tripletList;
    for (int vertex = 0; vertex < n_vertices; ++vertex) {
        for (int neighbor : graph[vertex]) {
            if (vertex < neighbor) {  // Ensure each edge is added only once
                tripletList.push_back(Eigen::Triplet<double>(vertex, neighbor, 1.0));
                tripletList.push_back(Eigen::Triplet<double>(neighbor, vertex, 1.0));
            }
        }
    }
    A.setFromTriplets(tripletList.begin(), tripletList.end());

    // Compute Laplacian matrix as a sparse matrix
    Eigen::SparseMatrix<double> D(n_vertices, n_vertices);
    for (int k = 0; k < A.outerSize(); ++k) {
        double sum = 0;
        for (Eigen::SparseMatrix<double>::InnerIterator it(A, k); it; ++it) {
            sum += it.value();
        }
        D.insert(k, k) = sum;
    }
    Eigen::SparseMatrix<double> L = D - A;

    // Eigenvalue decomposition
    Spectra::SparseSymMatProd<double> op(L);

    // Ensure ncv is within bounds: nev < ncv <= n
    nev = std::min(nev, n_vertices);
    int ncv = std::min(2 * nev, n_vertices); // Adjust ncv to be within bounds
    // Ensure nev < ncv
    if (nev >= ncv) {
        nev = ncv - 1;
    }

    if (nev < 1) {
        nev = 1;
    }

    // Construct eigen solver object to find eigenvalues closest to 0

    // ncv rule-of-thumb: 3*nev is often safer for hard problems
    int ncv_default = std::max(2 * nev + 10, 150);  // for nev=50 => at least 150
    ncv_default = std::min(ncv_default, (int)L.rows()); // cannot exceed n

    Spectra::SymEigsSolver<Spectra::SparseSymMatProd<double>> eigs(op, nev, ncv_default);
    eigs.init();
    eigs.compute(Spectra::SortRule::SmallestAlge);

    if (eigs.info() != Spectra::CompInfo::Successful)
        Rf_error("Eigenvalue estimation with Spectra failed.");

    Eigen::VectorXd evalues = eigs.eigenvalues();
    Eigen::MatrixXd evectors = eigs.eigenvectors();

    // Convert to dense if required
    Eigen::MatrixXd dense_L;
    if (return_dense) {
        dense_L = Eigen::MatrixXd(L);
    }

    auto result = std::make_unique<graph_spectrum_plus_t>();
    result->evalues = evalues;
    result->evectors = evectors;
    result->L = L;
    result->dense_L = dense_L;

    return result;
}


/**
 * S_graph_spectrum
 *
 * This function computes the first `nev` eigenvalues and eigenvectors of the
 * Laplacian matrix of a given graph. Optionally, it can return the Laplacian
 * matrix in either sparse or dense format.
 *
 * @param Rgraph A list of integer vectors representing the adjacency list of the graph.
 * @param Rnev An integer specifying the number of eigenvalues and eigenvectors to compute.
 * @param Rreturn_dense A boolean indicating whether to return the Laplacian matrix
 *        in dense format. If false, the Laplacian matrix is returned in sparse format.
 *
 * @return A list containing the following components:
 *         - evalues: A vector of the computed eigenvalues.
 *         - evectors: A matrix of the computed eigenvectors.
 *         - laplacian: The Laplacian matrix of the graph. This is returned in sparse format
 *           if `return_dense` is false, and in dense format if `return_dense` is true.
 */
SEXP S_graph_spectrum_plus(SEXP Rgraph, SEXP Rnev, SEXP Rreturn_dense) {

    // Convert inputs
    std::vector<std::vector<int>> graph = convert_adj_list_from_R(Rgraph);
    int nev = INTEGER(Rnev)[0];
    bool return_dense = (LOGICAL(Rreturn_dense)[0] == 1);

    // Compute spectrum
    std::unique_ptr<graph_spectrum_plus_t> result = graph_spectrum_plus(graph, nev, return_dense);

    // Create return list
    SEXP ret = PROTECT(Rf_allocVector(VECSXP, return_dense ? 4 : 3));
    SET_VECTOR_ELT(ret, 0, EigenVectorXd_to_SEXP(result->evalues));
    SET_VECTOR_ELT(ret, 1, EigenMatrixXd_to_SEXP(result->evectors));
    if (return_dense) {
        SET_VECTOR_ELT(ret, 2, EigenMatrixXd_to_SEXP(result->dense_L));
    } else {
        SET_VECTOR_ELT(ret, 2, EigenSparseMatrix_to_SEXP(result->L));
    }

    SEXP names = PROTECT(Rf_allocVector(STRSXP, return_dense ? 4 : 3));
    SET_STRING_ELT(names, 0, Rf_mkChar("evalues"));
    SET_STRING_ELT(names, 1, Rf_mkChar("evectors"));
    SET_STRING_ELT(names, 2, Rf_mkChar("laplacian"));
    if (return_dense) {
        SET_STRING_ELT(names, 2, Rf_mkChar("dense_laplacian"));
    }
    Rf_setAttrib(ret, R_NamesSymbol, names);

    UNPROTECT(2);
    return ret;
}
