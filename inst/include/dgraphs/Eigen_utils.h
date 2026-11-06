#ifndef DGRAPHS_EIGEN_UTILS_H_
#define DGRAPHS_EIGEN_UTILS_H_

#include "dgraphs/omp_compat.h"

#include <string>

#include <Eigen/Dense>
#include <Eigen/SparseCore>

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Print.h>   // Rprintf, REprintf

SEXP EigenVectorXd_to_SEXP(const Eigen::VectorXd& vec);
SEXP EigenMatrixXd_to_SEXP(const Eigen::MatrixXd& mat);
SEXP EigenSparseMatrix_to_SEXP(const Eigen::SparseMatrix<double>& mat);

#endif // DGRAPHS_EIGEN_UTILS_H_
