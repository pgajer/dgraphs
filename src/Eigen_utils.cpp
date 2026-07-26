#include "dgraphs/Eigen_utils.h"

// Function to convert Eigen::VectorXd to SEXP
SEXP EigenVectorXd_to_SEXP(const Eigen::VectorXd& vec) {
    SEXP result = PROTECT(Rf_allocVector(REALSXP, vec.size()));
    for (int i = 0; i < vec.size(); ++i) {
        REAL(result)[i] = vec[i];
    }
    UNPROTECT(1);
    return result;
}

// Function to convert Eigen::MatrixXd to SEXP
SEXP EigenMatrixXd_to_SEXP(const Eigen::MatrixXd& mat) {
    SEXP result = PROTECT(Rf_allocMatrix(REALSXP, mat.rows(), mat.cols()));
    for (int i = 0; i < mat.size(); ++i) {
        REAL(result)[i] = mat(i);
    }
    UNPROTECT(1);
    return result;
}

// Function to convert Eigen::SparseMatrix to SEXP
SEXP EigenSparseMatrix_to_SEXP(const Eigen::SparseMatrix<double>& mat) {
    std::vector<Eigen::Triplet<double>> tripletList;
    for (int k = 0; k < mat.outerSize(); ++k) {
        for (Eigen::SparseMatrix<double>::InnerIterator it(mat, k); it; ++it) {
            tripletList.push_back(Eigen::Triplet<double>(it.row(), it.col(), it.value()));
        }
    }

    SEXP dims = PROTECT(Rf_allocVector(INTSXP, 2));
    INTEGER(dims)[0] = mat.rows();
    INTEGER(dims)[1] = mat.cols();

    SEXP i = PROTECT(Rf_allocVector(INTSXP, tripletList.size()));
    SEXP j = PROTECT(Rf_allocVector(INTSXP, tripletList.size()));
    SEXP v = PROTECT(Rf_allocVector(REALSXP, tripletList.size()));

    for (size_t k = 0; k < tripletList.size(); ++k) {
        INTEGER(i)[k] = tripletList[k].row();
        INTEGER(j)[k] = tripletList[k].col();
        REAL(v)[k] = tripletList[k].value();
    }

    SEXP result = PROTECT(Rf_allocVector(VECSXP, 4));
    SET_VECTOR_ELT(result, 0, dims);
    SET_VECTOR_ELT(result, 1, i);
    SET_VECTOR_ELT(result, 2, j);
    SET_VECTOR_ELT(result, 3, v);

    UNPROTECT(5);
    return result;
}
