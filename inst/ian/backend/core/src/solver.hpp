#pragma once
extern "C" {
#include <clarabel.h>
}
#include "numeric.hpp"
#include <chrono>
#include <memory>
#include "backend_settings.hpp"
namespace ian::detail {
struct LPResult {
    Vec x, z;
    Json record;
};
inline LPResult solve_lp(const Mat &D, const Edges &edges, const Vec &u, double C,
                         bool parameterized, bool inject = false) {
    auto start = std::chrono::steady_clock::now();
    size_t n = u.size(), m = 2 * edges.size() + 2 * n;
    Vec values, b;
    std::vector<uintptr_t> indices, indptr{0};
    auto row = [&](int i, int j, double v, double rhs) {
        values.push_back(v);
        indices.push_back(i);
        if (j >= 0) {
            values.push_back(-1);
            indices.push_back(j);
        }
        indptr.push_back(values.size());
        b.push_back(rhs);
    };
    for (auto e : edges) {
        int i = e[0], j = e[1];
        double d = D[i][j];
        require(u[i] > 0 && u[j] > 0, "edge_zero_upper");
        if (parameterized) {
            row(i, j, (-d / u[i]) * C, (-(d * d) / u[i]) * (C * C) + (-d) * C);
            row(i, j, (-u[j] / d) * (1 / C), (-u[j]) + (-d) * C);
        } else {
            double w = d * C, inv = 1 / u[i];
            row(i, j, inv * (-w), (-(w * w)) * inv + (-w));
            row(i, j, u[j] * (-1 / w), (-1.) * u[j] + (-w));
        }
    }
    for (size_t i = 0; i < n; i++)
        row(i, -1, 1, u[i]);
    for (size_t i = 0; i < n; i++)
        row(i, -1, -1, 0);
    std::vector<uintptr_t> colptr(n + 1, 0), rows(values.size()), pzero(n + 1, 0);
    Vec csc(values.size()), q(n, 1);
    for (auto j : indices)
        colptr[j + 1]++;
    for (size_t j = 0; j < n; j++)
        colptr[j + 1] += colptr[j];
    auto next = colptr;
    for (size_t r = 0; r < m; r++)
        for (size_t k = indptr[r]; k < indptr[r + 1]; k++) {
            auto at = next[indices[k]]++;
            rows[at] = r;
            csc[at] = values[k];
        }
    ClarabelCscMatrix A, P;
    clarabel_CscMatrix_init(&A, m, n, colptr.data(), rows.data(), csc.data());
    clarabel_CscMatrix_init(&P, n, n, pzero.data(), nullptr, nullptr);
    verify_backend_abi();
    auto settings = clarabel_DefaultSettings_default();
    settings.verbose = false;
    settings.max_iter = 300;
    settings.max_threads = 1;
    settings.direct_solve_method = QDLDL;
    settings.presolve_enable = false;
    settings.input_sparse_dropzeros = false;
    settings.tol_feas = settings.tol_gap_abs = settings.tol_gap_rel = 1e-9;
    auto cone = ClarabelNonnegativeConeT(m);
    std::unique_ptr<ClarabelDefaultSolver, decltype(&clarabel_DefaultSolver_free)> solver(
        clarabel_DefaultSolver_new(&P, q.data(), &A, b.data(), 1, &cone, &settings),
        clarabel_DefaultSolver_free);
    require(bool(solver), "solver_construction");
    clarabel_DefaultSolver_solve(solver.get());
    auto sol = clarabel_DefaultSolver_solution(solver.get());
    Vec x(sol.x, sol.x + sol.x_length), z(sol.z, sol.z + sol.z_length);
    if (inject)
        std::fill(x.begin(), x.end(), 0.);
    bool accepted = sol.status == ClarabelSolved && x.size() == n && z.size() == m &&
                    std::isfinite(sol.obj_val);
    Ids active(n);
    long double objective = 0, dualobj = 0;
    double maxnormal = 0, maxabsolute = 0, stationarity = 0, negative = 0;
    Vec station(n, 1);
    for (size_t i = 0; i < n; i++) {
        active[i] = u[i] > 0;
        accepted = accepted && std::isfinite(x[i]) && (!active[i] || x[i] > 0);
        objective += x[i];
    }
    for (size_t r = 0; r < m; r++) {
        double ax = 0, den = 0;
        for (size_t k = indptr[r]; k < indptr[r + 1]; k++) {
            ax += values[k] * x[indices[k]];
            den += std::abs(values[k]) * std::abs(x[indices[k]]);
            station[indices[k]] += values[k] * z[r];
        }
        double residual = std::max(0., ax - b[r]);
        maxabsolute = std::max(maxabsolute, residual);
        maxnormal = std::max(maxnormal, residual / std::max({1., std::abs(b[r]), den}));
        dualobj -= static_cast<long double>(b[r]) * z[r];
        negative = std::max(negative, -z[r]);
        accepted = accepted && std::isfinite(z[r]);
    }
    for (double v : station)
        stationarity = std::max(stationarity, std::abs(v));
    double obj = double(objective), dual = double(dualobj),
           error =
               std::abs(obj - sol.obj_val) / std::max({1., std::abs(obj), std::abs(sol.obj_val)}),
           gap = std::abs(obj - dual) / std::max({1., std::abs(obj), std::abs(dual)});
    accepted = accepted && maxnormal <= 1e-7 && error <= 1e-7 && stationarity <= 1e-7 &&
               negative <= 1e-7 && gap <= 1e-7;
    Json record = {
        {"event", "solve"},
        {"settings", captured_settings(settings)},
        {"site", parameterized ? "parameterized" : "recycled"},
        {"C", C},
        {"A_data", values},
        {"A_indices", indices},
        {"A_indptr", indptr},
        {"A_shape", {m, n}},
        {"b", b},
        {"c", q},
        {"upper", u},
        {"active", active},
        {"scales", x},
        {"dual", z},
        {"status", sol.status == ClarabelSolved ? "optimal" : "not_optimal"},
        {"objective", sol.obj_val},
        {"iterations", sol.iterations},
        {"accepted", accepted},
        {"validation",
         {{"max_normalized_violation", maxnormal},
          {"max_absolute_violation", maxabsolute},
          {"objective_relative_error", error}}},
        {"dual_check",
         {{"stationarity", stationarity}, {"negative", negative}, {"relative_gap", gap}}},
        {"canonical_shape", {m, n}},
        {"canonical_soc", Json::array()},
        {"seconds",
         std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count()}};
    return {x, z, record};
}

} // namespace ian::detail
