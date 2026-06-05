#include "dgraphs/Eigen_utils.h"

/**
 * @brief Prints the elements of an Eigen::VectorXd to the standard output.
 *
 * This function prints the elements of an Eigen::VectorXd to the standard output. If a name is provided,
 * it is printed before the elements. The number of elements to print can be controlled by the parameter `n`.
 *
 * @param vec The Eigen::VectorXd to be printed.
 * @param name (Optional) A string to be printed before the vector elements. Default is an empty string.
 * @param n (Optional) The number of elements to print. If `n` is 0, all elements of the vector are printed. Default is 0.
 *
 * @details
 * - If `n` is greater than the size of the vector, all elements of the vector are printed.
 * - If `name` is provided, it is printed before the vector elements followed by a colon and space.
 * - The function ensures that only valid elements are accessed and printed.
 *
 * Example usage:
 * @code
 * Eigen::VectorXd vec(5);
 * vec << 1.0, 2.0, 3.0, 4.0, 5.0;
 *
 * print_Eigen_VectorXd(vec, "MyVector");        // Print all elements
 * print_Eigen_VectorXd(vec, "MyVector", 3);     // Print first 3 elements
 * print_Eigen_VectorXd(vec, "", 2);             // Print first 2 elements without name
 * @endcode
 *
 * @note The parameter `n` is of type `Eigen::Index`, which is typically an alias for `int` in Eigen.
 */
void print_Eigen_VectorXd(const Eigen::VectorXd& vec,
                          const std::string& name = "",
                          Eigen::Index n = 0) {
    if (n == 0) n = vec.size();
    if (!name.empty()) Rprintf("%s: ", name.c_str());
    for (Eigen::Index i = 0; i < n && i < vec.size(); ++i) {
        Rprintf("%.6g%s", vec[i], (i + 1 < n && i + 1 < vec.size()) ? " " : "");
    }
    Rprintf("\n");
}

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
