#include "linf_simplex_knn.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <memory>
#include <utility>
#include <vector>

#include <ANN/ANN.h>
#include <R.h>
#include <R_ext/Utils.h>
#include <Rinternals.h>

namespace {

inline double matrix_value(const double* x, int nrow, int row, int col) {
    return x[row + nrow * col];
}

inline size_t face_coord_offset(int col, int face) {
    return static_cast<size_t>(col < face ? col : col - 1);
}

std::vector<std::vector<int>> compute_active_faces(const double* x,
                                                   int nrow,
                                                   int ncol,
                                                   double tol) {
    std::vector<std::vector<int>> active(static_cast<size_t>(nrow));

    for (int i = 0; i < nrow; ++i) {
        double row_max = -std::numeric_limits<double>::infinity();
        for (int j = 0; j < ncol; ++j) {
            const double value = matrix_value(x, nrow, i, j);
            if (!std::isfinite(value)) {
                Rf_error("X cannot contain NA, NaN, or Inf values.");
            }
            if (value < -tol) {
                Rf_error("X must be nonnegative for knn.metric = 'linf.simplex'.");
            }
            row_max = std::max(row_max, value);
        }

        if (std::fabs(row_max - 1.0) > tol) {
            Rf_error("Each row of X must be L-infinity normalized: max(row) must equal 1 within linf.tol.");
        }

        for (int j = 0; j < ncol; ++j) {
            if (std::fabs(matrix_value(x, nrow, i, j) - 1.0) <= tol) {
                active[static_cast<size_t>(i)].push_back(j);
            }
        }
        if (active[static_cast<size_t>(i)].empty()) {
            Rf_error("Failed to identify an active L-infinity simplex face for at least one row.");
        }
    }

    return active;
}

double linf_simplex_dist_sq(const double* x,
                            int nrow,
                            int ncol,
                            int i,
                            int j,
                            const std::vector<int>& active_i,
                            const std::vector<int>& active_j) {
    double best = std::numeric_limits<double>::infinity();

    for (const int face_i : active_i) {
        for (const int face_j : active_j) {
            double dist_sq = 0.0;

            if (face_i == face_j) {
                for (int col = 0; col < ncol; ++col) {
                    if (col == face_i) {
                        continue;
                    }
                    const double diff = matrix_value(x, nrow, i, col) -
                                        matrix_value(x, nrow, j, col);
                    dist_sq += diff * diff;
                }
            } else {
                const double crossing_diff =
                    2.0 - matrix_value(x, nrow, i, face_j) -
                    matrix_value(x, nrow, j, face_i);
                dist_sq += crossing_diff * crossing_diff;

                for (int col = 0; col < ncol; ++col) {
                    if (col == face_i || col == face_j) {
                        continue;
                    }
                    const double diff = matrix_value(x, nrow, i, col) -
                                        matrix_value(x, nrow, j, col);
                    dist_sq += diff * diff;
                }
            }

            if (dist_sq < best) {
                best = dist_sq;
            }
        }
    }

    return best;
}

void fill_face_point(const double* x,
                     int nrow,
                     int ncol,
                     int row,
                     int face,
                     ANNpoint out) {
    for (int col = 0; col < ncol; ++col) {
        if (col == face) {
            continue;
        }
        out[face_coord_offset(col, face)] = matrix_value(x, nrow, row, col);
    }
}

void fill_unfolded_query(const double* x,
                         int nrow,
                         int ncol,
                         int row,
                         int source_face,
                         int target_face,
                         ANNpoint out) {
    for (int col = 0; col < ncol; ++col) {
        if (col == target_face) {
            continue;
        }
        const size_t offset = face_coord_offset(col, target_face);
        if (source_face != target_face && col == source_face) {
            out[offset] = 2.0 - matrix_value(x, nrow, row, target_face);
        } else {
            out[offset] = matrix_value(x, nrow, row, col);
        }
    }
}

struct face_tree_t {
    int face;
    int dim;
    ANNpointArray points;
    ANNkd_tree* tree;
    std::vector<int> members;

    face_tree_t(int face_id,
                int dim_value,
                std::vector<int>&& member_indices)
        : face(face_id),
          dim(dim_value),
          points(nullptr),
          tree(nullptr),
          members(std::move(member_indices)) {}

    face_tree_t(const face_tree_t&) = delete;
    face_tree_t& operator=(const face_tree_t&) = delete;

    ~face_tree_t() {
        delete tree;
        if (points != nullptr) {
            annDeallocPts(points);
        }
    }
};

std::vector<std::unique_ptr<face_tree_t>> build_face_trees(
    const double* x,
    int nrow,
    int ncol,
    const std::vector<std::vector<int>>& active_faces) {

    std::vector<std::vector<int>> face_members(static_cast<size_t>(ncol));
    for (int i = 0; i < nrow; ++i) {
        for (const int face : active_faces[static_cast<size_t>(i)]) {
            face_members[static_cast<size_t>(face)].push_back(i);
        }
    }

    std::vector<std::unique_ptr<face_tree_t>> trees;
    trees.reserve(static_cast<size_t>(ncol));
    const int dim = ncol - 1;

    for (int face = 0; face < ncol; ++face) {
        auto& members = face_members[static_cast<size_t>(face)];
        if (members.empty()) {
            continue;
        }

        auto tree = std::make_unique<face_tree_t>(
            face,
            dim,
            std::move(members)
        );

        tree->points = annAllocPts(static_cast<int>(tree->members.size()), dim);
        for (size_t local = 0; local < tree->members.size(); ++local) {
            fill_face_point(x,
                            nrow,
                            ncol,
                            tree->members[local],
                            face,
                            tree->points[local]);
        }
        tree->tree = new ANNkd_tree(tree->points,
                                    static_cast<int>(tree->members.size()),
                                    dim);
        trees.push_back(std::move(tree));
    }

    return trees;
}

} // namespace

knn_search_result_t compute_linf_simplex_knn(SEXP RX, int k, double tol) {
    if (TYPEOF(RX) != REALSXP || !Rf_isMatrix(RX)) {
        Rf_error("X must be a numeric matrix.");
    }
    if (k <= 0) {
        Rf_error("k must be positive.");
    }
    if (!std::isfinite(tol) || tol <= 0.0) {
        Rf_error("linf.tol must be a positive finite number.");
    }

    SEXP s_dim = PROTECT(Rf_getAttrib(RX, R_DimSymbol));
    if (s_dim == R_NilValue || TYPEOF(s_dim) != INTSXP || Rf_length(s_dim) < 2) {
        UNPROTECT(1);
        Rf_error("X must be a numeric matrix with valid dimensions.");
    }
    const int nrow = INTEGER(s_dim)[0];
    const int ncol = INTEGER(s_dim)[1];
    UNPROTECT(1);

    if (nrow <= 0 || ncol <= 0) {
        Rf_error("X must have positive row and column counts.");
    }
    if (k > nrow) {
        Rf_error("k cannot exceed nrow(X).");
    }

    const double* x = REAL(RX);
    const std::vector<std::vector<int>> active_faces =
        compute_active_faces(x, nrow, ncol, tol);

    knn_search_result_t result(static_cast<size_t>(nrow), static_cast<size_t>(k));

    if (ncol == 1) {
        for (int i = 0; i < nrow; ++i) {
            for (int j = 0; j < k; ++j) {
                result.indices[static_cast<size_t>(i)][static_cast<size_t>(j)] = j;
                result.distances[static_cast<size_t>(i)][static_cast<size_t>(j)] = 0.0;
            }
        }
        return result;
    }

    std::vector<std::unique_ptr<face_tree_t>> face_trees =
        build_face_trees(x, nrow, ncol, active_faces);

    std::vector<std::pair<double, int>> distances;
    distances.reserve(static_cast<size_t>(nrow));
    std::vector<double> best_dist_sq(static_cast<size_t>(nrow),
                                     std::numeric_limits<double>::infinity());
    std::vector<int> touched;
    touched.reserve(static_cast<size_t>(std::min(nrow, k * std::max(1, ncol))));
    std::vector<ANNcoord> query(static_cast<size_t>(ncol - 1));

    for (int i = 0; i < nrow; ++i) {
        if ((i & 127) == 0) {
            R_CheckUserInterrupt();
        }

        touched.clear();

        for (const int source_face : active_faces[static_cast<size_t>(i)]) {
            for (const auto& face_tree : face_trees) {
                const int query_k = std::min(
                    static_cast<int>(face_tree->members.size()),
                    std::max(k, 4 * k + 8)
                );
                std::vector<ANNidx> nn_idx(static_cast<size_t>(query_k));
                std::vector<ANNdist> nn_dist(static_cast<size_t>(query_k));

                fill_unfolded_query(x,
                                    nrow,
                                    ncol,
                                    i,
                                    source_face,
                                    face_tree->face,
                                    query.data());

                face_tree->tree->annkSearch(query.data(),
                                            query_k,
                                            nn_idx.data(),
                                            nn_dist.data(),
                                            0.0);

                for (int local_pos = 0; local_pos < query_k; ++local_pos) {
                    const int local_idx = nn_idx[static_cast<size_t>(local_pos)];
                    if (local_idx < 0 ||
                        static_cast<size_t>(local_idx) >= face_tree->members.size()) {
                        continue;
                    }
                    const int candidate = face_tree->members[static_cast<size_t>(local_idx)];
                    if (!std::isfinite(best_dist_sq[static_cast<size_t>(candidate)])) {
                        touched.push_back(candidate);
                    }

                    const double dist_sq = linf_simplex_dist_sq(
                        x,
                        nrow,
                        ncol,
                        i,
                        candidate,
                        active_faces[static_cast<size_t>(i)],
                        active_faces[static_cast<size_t>(candidate)]
                    );
                    if (dist_sq < best_dist_sq[static_cast<size_t>(candidate)]) {
                        best_dist_sq[static_cast<size_t>(candidate)] = dist_sq;
                    }
                }
            }
        }

        if (static_cast<int>(touched.size()) < k) {
            for (int candidate = 0; candidate < nrow; ++candidate) {
                if (std::isfinite(best_dist_sq[static_cast<size_t>(candidate)])) {
                    continue;
                }
                touched.push_back(candidate);
                best_dist_sq[static_cast<size_t>(candidate)] =
                    linf_simplex_dist_sq(
                        x,
                        nrow,
                        ncol,
                        i,
                        candidate,
                        active_faces[static_cast<size_t>(i)],
                        active_faces[static_cast<size_t>(candidate)]
                    );
            }
        }

        distances.clear();
        for (const int candidate : touched) {
            distances.emplace_back(
                best_dist_sq[static_cast<size_t>(candidate)],
                candidate
            );
        }

        std::partial_sort(
            distances.begin(),
            distances.begin() + k,
            distances.end(),
            [](const std::pair<double, int>& lhs, const std::pair<double, int>& rhs) {
                if (lhs.first < rhs.first) {
                    return true;
                }
                if (lhs.first > rhs.first) {
                    return false;
                }
                return lhs.second < rhs.second;
            }
        );

        for (int j = 0; j < k; ++j) {
            result.indices[static_cast<size_t>(i)][static_cast<size_t>(j)] =
                distances[static_cast<size_t>(j)].second;
            result.distances[static_cast<size_t>(i)][static_cast<size_t>(j)] =
                std::sqrt(std::max(0.0, distances[static_cast<size_t>(j)].first));
        }

        for (const int candidate : touched) {
            best_dist_sq[static_cast<size_t>(candidate)] =
                std::numeric_limits<double>::infinity();
        }
    }

    face_trees.clear();
    annClose();
    return result;
}

extern "C" SEXP S_linf_simplex_knn(SEXP s_X, SEXP s_k, SEXP s_linf_tol) {
    const int k = Rf_asInteger(s_k);
    const double tol = Rf_asReal(s_linf_tol);

    const knn_search_result_t knn = compute_linf_simplex_knn(s_X, k, tol);
    const int n = static_cast<int>(knn.n_points);

    SEXP out = PROTECT(Rf_allocVector(VECSXP, 2));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, 2));
    SET_STRING_ELT(names, 0, Rf_mkChar("indices"));
    SET_STRING_ELT(names, 1, Rf_mkChar("distances"));
    Rf_setAttrib(out, R_NamesSymbol, names);
    UNPROTECT(1);

    SEXP indices = PROTECT(Rf_allocMatrix(INTSXP, n, k));
    SEXP distances = PROTECT(Rf_allocMatrix(REALSXP, n, k));

    for (int i = 0; i < n; ++i) {
        for (int j = 0; j < k; ++j) {
            INTEGER(indices)[i + n * j] =
                knn.indices[static_cast<size_t>(i)][static_cast<size_t>(j)];
            REAL(distances)[i + n * j] =
                knn.distances[static_cast<size_t>(i)][static_cast<size_t>(j)];
        }
    }

    SET_VECTOR_ELT(out, 0, indices);
    SET_VECTOR_ELT(out, 1, distances);
    UNPROTECT(3);

    return out;
}
