#include "dgraphs/Eigen_utils.h"
#include "dgraphs/graph_spectrum_r.h"
#include "dgraphs/SEXP_cpp_conversion_utils.hpp"

#include <algorithm>
#include <stdexcept>
#include <vector>
#include <Eigen/Dense>
#include <Eigen/SparseCore>
#include <Spectra/SymEigsSolver.h>
#include <Spectra/MatOp/SparseSymMatProd.h>

namespace {

Eigen::SparseMatrix<double> graph_laplacian(const std::vector<std::vector<int>>& graph) {
    const int n = graph.size();
    std::vector<Eigen::Triplet<double>> entries;
    for (int i = 0; i < n; ++i) {
        entries.emplace_back(i, i, static_cast<double>(graph[i].size()));
        for (int j : graph[i]) {
            if (j < 0 || j >= n || j == i)
                throw std::invalid_argument("Invalid graph adjacency in spectrum computation.");
            entries.emplace_back(i, j, -1.0);
        }
    }
    Eigen::SparseMatrix<double> L(n, n);
    L.setFromTriplets(entries.begin(), entries.end());
    return L;
}

struct eigenpairs {
    Eigen::VectorXd values;
    Eigen::MatrixXd vectors;
};

// The R boundary requests positive modes plus all component zero modes.
// Return the requested smallest eigenpairs without silently changing the count.
eigenpairs smallest_eigenpairs(const Eigen::SparseMatrix<double>& L, int nev) {
    const int n = L.rows();
    if (nev < 0 || nev > n)
        throw std::invalid_argument("Eigenpair count must be between zero and graph order.");
    if (nev == 0) return {Eigen::VectorXd(0), Eigen::MatrixXd(n, 0)};
    if (nev == n) {
        // Lanczos requires nev < n. A complete spectrum needs a dense solve.
        Eigen::SelfAdjointEigenSolver<Eigen::MatrixXd> solver{Eigen::MatrixXd(L)};
        if (solver.info() != Eigen::Success)
            throw std::runtime_error("Dense graph eigendecomposition failed.");
        return {solver.eigenvalues(), solver.eigenvectors()};
    }
    Spectra::SparseSymMatProd<double> op(L);
    const int ncv = static_cast<int>(std::min<double>(n, std::max<double>(2.0 * nev + 10, 150)));
    Spectra::SymEigsSolver<Spectra::SparseSymMatProd<double>> solver(op, nev, ncv);
    solver.init();
    const int converged = solver.compute(Spectra::SortRule::SmallestAlge, 1000,
                                         1e-12, Spectra::SortRule::SmallestAlge);
    if (solver.info() != Spectra::CompInfo::Successful || converged != nev)
        throw std::runtime_error("Graph eigenpair computation did not converge; try use.R = TRUE on a smaller graph.");
    return {solver.eigenvalues(), solver.eigenvectors()};
}

SEXP spectrum_result(SEXP Rgraph, SEXP Rnev, bool include_laplacian, bool dense) {
    const auto graph = convert_adj_list_from_R(Rgraph);
    const auto L = graph_laplacian(graph);
    const auto pairs = smallest_eigenpairs(L, Rf_asInteger(Rnev));
    const int size = include_laplacian ? 3 : 2;
    SEXP result = PROTECT(Rf_allocVector(VECSXP, size));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, size));
    SET_VECTOR_ELT(result, 0, EigenVectorXd_to_SEXP(pairs.values));
    SET_VECTOR_ELT(result, 1, EigenMatrixXd_to_SEXP(pairs.vectors));
    SET_STRING_ELT(names, 0, Rf_mkChar("evalues"));
    SET_STRING_ELT(names, 1, Rf_mkChar("evectors"));
    if (include_laplacian) {
        if (dense) {
            SET_VECTOR_ELT(result, 2, EigenMatrixXd_to_SEXP(Eigen::MatrixXd(L)));
            SET_STRING_ELT(names, 2, Rf_mkChar("dense_laplacian"));
        } else {
            SET_VECTOR_ELT(result, 2, EigenSparseMatrix_to_SEXP(L));
            SET_STRING_ELT(names, 2, Rf_mkChar("laplacian"));
        }
    }
    Rf_setAttrib(result, R_NamesSymbol, names);
    UNPROTECT(2);
    return result;
}

} // namespace

SEXP S_graph_spectrum(SEXP Rgraph, SEXP Rnev) {
    return spectrum_result(Rgraph, Rnev, false, false);
}

SEXP S_graph_spectrum_plus(SEXP Rgraph, SEXP Rnev, SEXP Rreturn_dense) {
    return spectrum_result(Rgraph, Rnev, true, Rf_asLogical(Rreturn_dense) == TRUE);
}
