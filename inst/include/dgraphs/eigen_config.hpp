#ifndef EIGEN_CONFIG_HPP
#define EIGEN_CONFIG_HPP

/*
 * Suppress GCC's class-memaccess warning generated inside Eigen NEON packet
 * internals on newer GCC versions. We do this in source (not Makevars flags)
 * to keep CRAN portability checks clean.
 */
#if defined(__cplusplus) && defined(__GNUC__) && !defined(__clang__) && (__GNUC__ >= 8)
#  pragma GCC diagnostic ignored "-Wclass-memaccess"
#endif

/*
 * Current Eigen releases trigger this warning in SparseCore and SparseLU
 * headers under Apple Clang even when package code uses those headers
 * correctly.
 */
#if defined(__cplusplus) && defined(__clang__)
#  pragma clang diagnostic ignored "-Wunused-but-set-variable"
#endif

#endif // EIGEN_CONFIG_HPP
