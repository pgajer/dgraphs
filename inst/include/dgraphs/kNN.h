#ifndef GFLOW_KNN_H_
#define GFLOW_KNN_H_

#include <string>
#include <vector>
#include <Eigen/Sparse>

// Leak-proof result: flat row-major buffers inside std::vector.
struct knn_result_t {
  int n = 0;                 // number of points
  int k = 0;                 // neighbors per point
  std::vector<int> indices;        // size n*k, neighbors of i at [i*k ... i*k+k-1]
  std::vector<double> distances;   // size n*k, same layout
};

// C++ helper: compute kNN over X as vector-of-rows
knn_result_t kNN(const std::vector<std::vector<double>>& X, int k);

// C++ helper: compute kNN directly from Eigen sparse matrix
knn_result_t compute_knn_from_eigen(
    const Eigen::SparseMatrix<double>& X,
    int k);

// C++ helper with optional on-disk cache:
// knn_cache_mode: 0=none, 1=read, 2=write, 3=readwrite
knn_result_t compute_knn_from_eigen(
    const Eigen::SparseMatrix<double>& X,
    int k,
    const std::string& knn_cache_path,
    int knn_cache_mode,
    bool* cache_hit = nullptr,
    bool* cache_written = nullptr);

#endif // GFLOW_KNN_H_
