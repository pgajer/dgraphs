#include "graph_core_endpoints_r.h"
#include "dgraphs/SEXP_cpp_conversion_utils.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <numeric>
#include <queue>
#include <vector>

#include <R.h>
#include <Rinternals.h>

namespace {

constexpr double kTol = 1e-10;

struct core_distance_result_t {
    std::vector<double> eccentricity;
    std::vector<double> distance_to_core;
    std::vector<int> core_vertices;
    std::vector<bool> is_core;
    std::vector<int> landmarks;
    bool used_approx = false;
    double core_threshold = NA_REAL;
};

inline double finite_max(const std::vector<double>& values) {
    double mx = 0.0;
    for (double v : values) {
        if (std::isfinite(v) && v > mx) mx = v;
    }
    return mx;
}

double quantile_finite(const std::vector<double>& x, double q) {
    std::vector<double> vals;
    vals.reserve(x.size());
    for (double v : x) {
        if (std::isfinite(v)) vals.push_back(v);
    }
    if (vals.empty()) return NA_REAL;

    std::sort(vals.begin(), vals.end());
    if (vals.size() == 1) return vals[0];
    if (q <= 0.0) return vals.front();
    if (q >= 1.0) return vals.back();

    const double pos = q * static_cast<double>(vals.size() - 1);
    const size_t lo = static_cast<size_t>(std::floor(pos));
    const size_t hi = static_cast<size_t>(std::ceil(pos));
    const double frac = pos - static_cast<double>(lo);
    if (hi <= lo) return vals[lo];
    return vals[lo] * (1.0 - frac) + vals[hi] * frac;
}

int clamp_seed(int seed, int n) {
    if (n <= 0) return 0;
    int m = seed % n;
    if (m < 0) m += n;
    return m;
}

void validate_graph_inputs(const std::vector<std::vector<int>>& adj_list,
                           const std::vector<std::vector<double>>& weight_list,
                           const char* fn_name) {
    const size_t n = adj_list.size();
    if (n < 1) {
        Rf_error("%s: graph has zero vertices.", fn_name);
    }
    if (weight_list.size() != n) {
        Rf_error("%s: weight_list size must match adj_list size.", fn_name);
    }

    for (size_t i = 0; i < n; ++i) {
        if (weight_list[i].size() != adj_list[i].size()) {
            Rf_error("%s: weight_list[[%zu]] length does not match adj_list[[%zu]] length.",
                     fn_name, i + 1, i + 1);
        }
        for (size_t j = 0; j < adj_list[i].size(); ++j) {
            const int v = adj_list[i][j];
            if (v < 0 || static_cast<size_t>(v) >= n) {
                Rf_error("%s: invalid neighbor index at vertex %zu.", fn_name, i + 1);
            }
            if (!std::isfinite(weight_list[i][j]) || weight_list[i][j] <= 0.0) {
                Rf_error("%s: all edge lengths must be finite and > 0.", fn_name);
            }
        }
    }
}

std::vector<double> dijkstra_single_source(const std::vector<std::vector<int>>& adj_list,
                                           const std::vector<std::vector<double>>& weight_list,
                                           int source) {
    const size_t n = adj_list.size();
    std::vector<double> dist(n, std::numeric_limits<double>::infinity());

    using qitem_t = std::pair<double, int>;
    auto cmp = [](const qitem_t& a, const qitem_t& b) {
        return a.first > b.first;
    };
    std::priority_queue<qitem_t, std::vector<qitem_t>, decltype(cmp)> pq(cmp);

    dist[static_cast<size_t>(source)] = 0.0;
    pq.push({0.0, source});

    while (!pq.empty()) {
        const auto [curr_dist, u] = pq.top();
        pq.pop();

        if (curr_dist > dist[static_cast<size_t>(u)] + kTol) continue;

        const auto& nbrs = adj_list[static_cast<size_t>(u)];
        const auto& wts = weight_list[static_cast<size_t>(u)];
        for (size_t i = 0; i < nbrs.size(); ++i) {
            const int v = nbrs[i];
            const double w = wts[i];
            if (v < 0 || static_cast<size_t>(v) >= n) continue;
            const double nd = curr_dist + w;
            if (nd + kTol < dist[static_cast<size_t>(v)]) {
                dist[static_cast<size_t>(v)] = nd;
                pq.push({nd, v});
            }
        }
    }

    return dist;
}

std::vector<double> dijkstra_multi_source(const std::vector<std::vector<int>>& adj_list,
                                          const std::vector<std::vector<double>>& weight_list,
                                          const std::vector<int>& sources) {
    const size_t n = adj_list.size();
    std::vector<double> dist(n, std::numeric_limits<double>::infinity());

    using qitem_t = std::pair<double, int>;
    auto cmp = [](const qitem_t& a, const qitem_t& b) {
        return a.first > b.first;
    };
    std::priority_queue<qitem_t, std::vector<qitem_t>, decltype(cmp)> pq(cmp);

    for (int s : sources) {
        if (s < 0 || static_cast<size_t>(s) >= n) continue;
        if (dist[static_cast<size_t>(s)] > 0.0) {
            dist[static_cast<size_t>(s)] = 0.0;
            pq.push({0.0, s});
        }
    }

    while (!pq.empty()) {
        const auto [curr_dist, u] = pq.top();
        pq.pop();

        if (curr_dist > dist[static_cast<size_t>(u)] + kTol) continue;

        const auto& nbrs = adj_list[static_cast<size_t>(u)];
        const auto& wts = weight_list[static_cast<size_t>(u)];
        for (size_t i = 0; i < nbrs.size(); ++i) {
            const int v = nbrs[i];
            const double w = wts[i];
            if (v < 0 || static_cast<size_t>(v) >= n) continue;
            const double nd = curr_dist + w;
            if (nd + kTol < dist[static_cast<size_t>(v)]) {
                dist[static_cast<size_t>(v)] = nd;
                pq.push({nd, v});
            }
        }
    }

    return dist;
}

core_distance_result_t compute_core_distance(const std::vector<std::vector<int>>& adj_list,
                                             const std::vector<std::vector<double>>& weight_list,
                                             double core_quantile,
                                             bool use_approx,
                                             int n_landmarks,
                                             int seed,
                                             bool verbose,
                                             const char* fn_name) {
    const size_t n = adj_list.size();

    core_distance_result_t out;
    out.eccentricity.assign(n, 0.0);
    out.is_core.assign(n, false);
    out.used_approx = use_approx && static_cast<size_t>(n_landmarks) < n;

    if (out.used_approx) {
        const int nL = std::min(static_cast<int>(n), std::max(1, n_landmarks));
        out.landmarks.reserve(static_cast<size_t>(nL));

        std::vector<std::vector<double>> dists;
        dists.reserve(static_cast<size_t>(nL));

        std::vector<double> min_dist(n, std::numeric_limits<double>::infinity());
        std::vector<bool> is_landmark(n, false);
        int current = clamp_seed(seed, static_cast<int>(n));

        for (int li = 0; li < nL; ++li) {
            if (is_landmark[static_cast<size_t>(current)]) {
                bool found = false;
                for (size_t v = 0; v < n; ++v) {
                    if (!is_landmark[v]) {
                        current = static_cast<int>(v);
                        found = true;
                        break;
                    }
                }
                if (!found) break;
            }

            is_landmark[static_cast<size_t>(current)] = true;
            out.landmarks.push_back(current);

            if (verbose && ((li + 1) % 10 == 0 || li == 0 || li + 1 == nL)) {
                Rprintf("%s: landmark %d / %d\n", fn_name, li + 1, nL);
            }

            std::vector<double> d = dijkstra_single_source(adj_list, weight_list, current);
            for (size_t v = 0; v < n; ++v) {
                if (std::isfinite(d[v]) && d[v] < min_dist[v]) min_dist[v] = d[v];
            }
            dists.push_back(std::move(d));

            if (li + 1 >= nL) break;

            double best_score = -1.0;
            int best_vertex = -1;
            for (size_t v = 0; v < n; ++v) {
                if (is_landmark[v]) continue;
                const double sc = min_dist[v];
                if (std::isfinite(sc) && sc > best_score) {
                    best_score = sc;
                    best_vertex = static_cast<int>(v);
                }
            }
            if (best_vertex < 0) {
                for (size_t v = 0; v < n; ++v) {
                    if (!is_landmark[v]) {
                        best_vertex = static_cast<int>(v);
                        break;
                    }
                }
            }
            if (best_vertex < 0) break;
            current = best_vertex;
        }

        for (size_t v = 0; v < n; ++v) {
            double mx = 0.0;
            for (const auto& d : dists) {
                const double dv = d[v];
                if (std::isfinite(dv) && dv > mx) mx = dv;
            }
            out.eccentricity[v] = mx;
        }
    } else {
        if (verbose) {
            Rprintf("%s: computing exact vertex eccentricities for %zu vertices\n", fn_name, n);
        }
        for (size_t v = 0; v < n; ++v) {
            if (verbose && ((v + 1) % 500 == 0 || v == 0 || v + 1 == n)) {
                Rprintf("%s: eccentricity %zu / %zu\n", fn_name, v + 1, n);
            }
            std::vector<double> d = dijkstra_single_source(adj_list, weight_list, static_cast<int>(v));
            out.eccentricity[v] = finite_max(d);
        }
    }

    out.core_threshold = quantile_finite(out.eccentricity, core_quantile);
    out.core_vertices.reserve(std::max<size_t>(1, n / 10));
    for (size_t v = 0; v < n; ++v) {
        if (std::isfinite(out.eccentricity[v]) && out.eccentricity[v] <= out.core_threshold + kTol) {
            out.is_core[v] = true;
            out.core_vertices.push_back(static_cast<int>(v));
        }
    }

    if (out.core_vertices.empty()) {
        int vmin = 0;
        double emin = std::numeric_limits<double>::infinity();
        for (size_t v = 0; v < n; ++v) {
            if (std::isfinite(out.eccentricity[v]) && out.eccentricity[v] < emin) {
                emin = out.eccentricity[v];
                vmin = static_cast<int>(v);
            }
        }
        out.is_core[static_cast<size_t>(vmin)] = true;
        out.core_vertices.push_back(vmin);
    }

    out.distance_to_core = dijkstra_multi_source(adj_list, weight_list, out.core_vertices);
    return out;
}

std::vector<bool> detect_local_maxima(const std::vector<std::vector<int>>& adj_list,
                                      const std::vector<double>& f) {
    const size_t n = adj_list.size();
    std::vector<bool> is_local_max(n, false);

    for (size_t v = 0; v < n; ++v) {
        const double fv = f[v];
        if (!std::isfinite(fv)) continue;

        bool has_higher = false;
        for (int nb : adj_list[v]) {
            if (nb < 0 || static_cast<size_t>(nb) >= n) continue;
            const double fn = f[static_cast<size_t>(nb)];
            if (!std::isfinite(fn)) continue;
            if (fn > fv + kTol) {
                has_higher = true;
                break;
            }
        }
        if (has_higher) continue;

        bool keep_plateau_rep = true;
        for (int nb : adj_list[v]) {
            if (nb < 0 || static_cast<size_t>(nb) >= n) continue;
            const double fn = f[static_cast<size_t>(nb)];
            if (!std::isfinite(fn)) continue;
            if (std::fabs(fn - fv) <= kTol && static_cast<size_t>(nb) < v) {
                keep_plateau_rep = false;
                break;
            }
        }
        if (keep_plateau_rep) is_local_max[v] = true;
    }

    return is_local_max;
}

std::vector<int> assign_vertices_to_peaks(const std::vector<std::vector<int>>& adj_list,
                                          const std::vector<double>& f) {
    const size_t n = adj_list.size();
    std::vector<int> assigned(n, -1);

    for (size_t s = 0; s < n; ++s) {
        if (!std::isfinite(f[s])) continue;

        int cur = static_cast<int>(s);
        int it = 0;
        const int max_it = static_cast<int>(n) + 5;

        while (it < max_it) {
            ++it;
            const double fc = f[static_cast<size_t>(cur)];
            int best_higher = -1;
            double best_higher_val = -std::numeric_limits<double>::infinity();
            int best_equal = -1;

            for (int nb : adj_list[static_cast<size_t>(cur)]) {
                if (nb < 0 || static_cast<size_t>(nb) >= n) continue;
                const double fn = f[static_cast<size_t>(nb)];
                if (!std::isfinite(fn)) continue;

                if (fn > fc + kTol) {
                    if (fn > best_higher_val + kTol ||
                        (std::fabs(fn - best_higher_val) <= kTol && nb < best_higher)) {
                        best_higher_val = fn;
                        best_higher = nb;
                    }
                } else if (std::fabs(fn - fc) <= kTol && nb < cur) {
                    if (best_equal < 0 || nb < best_equal) best_equal = nb;
                }
            }

            if (best_higher >= 0) {
                cur = best_higher;
                continue;
            }
            if (best_equal >= 0) {
                cur = best_equal;
                continue;
            }
            break;
        }

        assigned[s] = cur;
    }

    return assigned;
}

struct persistence_result_t {
    std::vector<double> peak_birth;
    std::vector<double> peak_death;
    std::vector<double> peak_persistence;
};

persistence_result_t compute_peak_persistence(const std::vector<std::vector<int>>& adj_list,
                                              const std::vector<double>& f) {
    const size_t n = adj_list.size();

    std::vector<int> order;
    order.reserve(n);
    for (size_t i = 0; i < n; ++i) {
        if (std::isfinite(f[i])) order.push_back(static_cast<int>(i));
    }
    std::sort(order.begin(), order.end(), [&](int a, int b) {
        const double fa = f[static_cast<size_t>(a)];
        const double fb = f[static_cast<size_t>(b)];
        if (std::fabs(fa - fb) > kTol) return fa > fb;
        return a < b;
    });

    std::vector<int> parent(n, -1);
    std::vector<int> rankv(n, 0);
    std::vector<double> comp_birth(n, NA_REAL);
    std::vector<int> comp_peak(n, -1);
    std::vector<bool> active(n, false);

    std::vector<double> peak_birth(n, NA_REAL);
    std::vector<double> peak_death(n, NA_REAL);

    auto find_root = [&](int x) {
        int r = x;
        while (parent[static_cast<size_t>(r)] != r) {
            r = parent[static_cast<size_t>(r)];
        }
        while (parent[static_cast<size_t>(x)] != x) {
            int p = parent[static_cast<size_t>(x)];
            parent[static_cast<size_t>(x)] = r;
            x = p;
        }
        return r;
    };

    auto is_first_winner = [&](int r1, int r2) {
        const double b1 = comp_birth[static_cast<size_t>(r1)];
        const double b2 = comp_birth[static_cast<size_t>(r2)];
        if (std::fabs(b1 - b2) > kTol) return b1 > b2;
        const int p1 = comp_peak[static_cast<size_t>(r1)];
        const int p2 = comp_peak[static_cast<size_t>(r2)];
        return p1 < p2;
    };

    for (int v : order) {
        const size_t vv = static_cast<size_t>(v);
        active[vv] = true;
        parent[vv] = v;
        rankv[vv] = 0;
        comp_birth[vv] = f[vv];
        comp_peak[vv] = v;
        peak_birth[vv] = f[vv];

        for (int nb : adj_list[vv]) {
            if (nb < 0 || static_cast<size_t>(nb) >= n) continue;
            if (!active[static_cast<size_t>(nb)]) continue;

            int rv = find_root(v);
            int rn = find_root(nb);
            if (rv == rn) continue;

            int winner = rv;
            int loser = rn;
            if (!is_first_winner(winner, loser)) {
                winner = rn;
                loser = rv;
            }

            const int losing_peak = comp_peak[static_cast<size_t>(loser)];
            if (losing_peak >= 0 && !std::isfinite(peak_death[static_cast<size_t>(losing_peak)])) {
                peak_death[static_cast<size_t>(losing_peak)] = f[vv];
            }

            parent[static_cast<size_t>(loser)] = winner;
            if (rankv[static_cast<size_t>(winner)] == rankv[static_cast<size_t>(loser)]) {
                rankv[static_cast<size_t>(winner)] += 1;
            }
        }
    }

    std::vector<double> peak_persistence(n, NA_REAL);
    for (size_t i = 0; i < n; ++i) {
        if (!std::isfinite(peak_birth[i])) continue;
        if (!std::isfinite(peak_death[i])) peak_death[i] = 0.0;
        peak_persistence[i] = peak_birth[i] - peak_death[i];
    }

    return {std::move(peak_birth), std::move(peak_death), std::move(peak_persistence)};
}

SEXP make_endpoint_summary_df(const std::vector<int>& vertex,
                              const std::vector<int>& degree,
                              const std::vector<double>& eccentricity,
                              const std::vector<double>& distance_to_core,
                              const std::vector<bool>& is_core,
                              const std::vector<bool>& is_endpoint,
                              const std::vector<bool>& is_local_max,
                              const std::vector<int>& endpoint_rank) {
    const R_xlen_t n = static_cast<R_xlen_t>(vertex.size());

    SEXP df = PROTECT(Rf_allocVector(VECSXP, 8));
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 8));

    SET_STRING_ELT(nm, 0, Rf_mkChar("vertex"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("degree"));
    SET_STRING_ELT(nm, 2, Rf_mkChar("eccentricity"));
    SET_STRING_ELT(nm, 3, Rf_mkChar("distance_to_core"));
    SET_STRING_ELT(nm, 4, Rf_mkChar("is_core"));
    SET_STRING_ELT(nm, 5, Rf_mkChar("is_endpoint"));
    SET_STRING_ELT(nm, 6, Rf_mkChar("is_local_max"));
    SET_STRING_ELT(nm, 7, Rf_mkChar("endpoint_rank"));

    SET_VECTOR_ELT(df, 0, convert_vector_int_to_R(vertex));
    SET_VECTOR_ELT(df, 1, convert_vector_int_to_R(degree));
    SET_VECTOR_ELT(df, 2, convert_vector_double_to_R(eccentricity));
    SET_VECTOR_ELT(df, 3, convert_vector_double_to_R(distance_to_core));
    SET_VECTOR_ELT(df, 4, convert_vector_bool_to_R(is_core));
    SET_VECTOR_ELT(df, 5, convert_vector_bool_to_R(is_endpoint));
    SET_VECTOR_ELT(df, 6, convert_vector_bool_to_R(is_local_max));
    SET_VECTOR_ELT(df, 7, convert_vector_int_to_R(endpoint_rank));

    Rf_setAttrib(df, R_NamesSymbol, nm);

    SEXP row_names = PROTECT(Rf_allocVector(INTSXP, 2));
    INTEGER(row_names)[0] = NA_INTEGER;
    INTEGER(row_names)[1] = -static_cast<int>(n);
    Rf_setAttrib(df, R_RowNamesSymbol, row_names);

    SEXP cls = PROTECT(Rf_mkString("data.frame"));
    Rf_setAttrib(df, R_ClassSymbol, cls);

    UNPROTECT(4);
    return df;
}

SEXP make_major_arm_summary_df(const std::vector<int>& vertex,
                               const std::vector<int>& degree,
                               const std::vector<double>& eccentricity,
                               const std::vector<double>& distance_to_core,
                               const std::vector<bool>& is_core,
                               const std::vector<bool>& is_local_max,
                               const std::vector<int>& assigned_tip,
                               const std::vector<int>& basin_size_of_vertex,
                               const std::vector<double>& persistence_of_vertex,
                               const std::vector<double>& length_of_vertex,
                               const std::vector<double>& score_of_vertex,
                               const std::vector<bool>& is_major_arm_tip,
                               const std::vector<bool>& is_on_major_arm,
                               const std::vector<int>& arm_rank_of_tip) {
    const R_xlen_t n = static_cast<R_xlen_t>(vertex.size());

    SEXP df = PROTECT(Rf_allocVector(VECSXP, 14));
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 14));

    SET_STRING_ELT(nm, 0, Rf_mkChar("vertex"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("degree"));
    SET_STRING_ELT(nm, 2, Rf_mkChar("eccentricity"));
    SET_STRING_ELT(nm, 3, Rf_mkChar("distance_to_core"));
    SET_STRING_ELT(nm, 4, Rf_mkChar("is_core"));
    SET_STRING_ELT(nm, 5, Rf_mkChar("is_local_max"));
    SET_STRING_ELT(nm, 6, Rf_mkChar("assigned_tip"));
    SET_STRING_ELT(nm, 7, Rf_mkChar("tip_basin_size"));
    SET_STRING_ELT(nm, 8, Rf_mkChar("tip_persistence"));
    SET_STRING_ELT(nm, 9, Rf_mkChar("tip_length"));
    SET_STRING_ELT(nm, 10, Rf_mkChar("tip_score"));
    SET_STRING_ELT(nm, 11, Rf_mkChar("is_major_arm_tip"));
    SET_STRING_ELT(nm, 12, Rf_mkChar("is_on_major_arm"));
    SET_STRING_ELT(nm, 13, Rf_mkChar("arm_rank"));

    SET_VECTOR_ELT(df, 0, convert_vector_int_to_R(vertex));
    SET_VECTOR_ELT(df, 1, convert_vector_int_to_R(degree));
    SET_VECTOR_ELT(df, 2, convert_vector_double_to_R(eccentricity));
    SET_VECTOR_ELT(df, 3, convert_vector_double_to_R(distance_to_core));
    SET_VECTOR_ELT(df, 4, convert_vector_bool_to_R(is_core));
    SET_VECTOR_ELT(df, 5, convert_vector_bool_to_R(is_local_max));
    SET_VECTOR_ELT(df, 6, convert_vector_int_to_R(assigned_tip));
    SET_VECTOR_ELT(df, 7, convert_vector_int_to_R(basin_size_of_vertex));
    SET_VECTOR_ELT(df, 8, convert_vector_double_to_R(persistence_of_vertex));
    SET_VECTOR_ELT(df, 9, convert_vector_double_to_R(length_of_vertex));
    SET_VECTOR_ELT(df, 10, convert_vector_double_to_R(score_of_vertex));
    SET_VECTOR_ELT(df, 11, convert_vector_bool_to_R(is_major_arm_tip));
    SET_VECTOR_ELT(df, 12, convert_vector_bool_to_R(is_on_major_arm));
    SET_VECTOR_ELT(df, 13, convert_vector_int_to_R(arm_rank_of_tip));

    Rf_setAttrib(df, R_NamesSymbol, nm);

    SEXP row_names = PROTECT(Rf_allocVector(INTSXP, 2));
    INTEGER(row_names)[0] = NA_INTEGER;
    INTEGER(row_names)[1] = -static_cast<int>(n);
    Rf_setAttrib(df, R_RowNamesSymbol, row_names);

    SEXP cls = PROTECT(Rf_mkString("data.frame"));
    Rf_setAttrib(df, R_ClassSymbol, cls);

    UNPROTECT(4);
    return df;
}

} // namespace

SEXP S_geodesic_core_endpoints(SEXP s_adj_list,
                               SEXP s_weight_list,
                               SEXP s_core_quantile,
                               SEXP s_endpoint_quantile,
                               SEXP s_use_approx_eccentricity,
                               SEXP s_n_landmarks,
                               SEXP s_max_endpoints,
                               SEXP s_seed,
                               SEXP s_verbose) {
    std::vector<std::vector<int>> adj_list = convert_adj_list_from_R(s_adj_list);
    std::vector<std::vector<double>> weight_list = convert_weight_list_from_R(s_weight_list);
    validate_graph_inputs(adj_list, weight_list, "S_geodesic_core_endpoints");

    const size_t n = adj_list.size();
    const double core_quantile = Rf_asReal(s_core_quantile);
    const double endpoint_quantile = Rf_asReal(s_endpoint_quantile);
    if (!std::isfinite(core_quantile) || core_quantile <= 0.0 || core_quantile >= 1.0) {
        Rf_error("S_geodesic_core_endpoints: core_quantile must be in (0, 1).");
    }
    if (!std::isfinite(endpoint_quantile) || endpoint_quantile < 0.0 || endpoint_quantile > 1.0) {
        Rf_error("S_geodesic_core_endpoints: endpoint_quantile must be in [0, 1].");
    }

    const bool use_approx = (Rf_asLogical(s_use_approx_eccentricity) == TRUE);
    const int n_landmarks_in = Rf_asInteger(s_n_landmarks);
    const int n_landmarks = (n_landmarks_in == NA_INTEGER) ? 64 : std::max(1, n_landmarks_in);
    const int max_endpoints_in = Rf_asInteger(s_max_endpoints);
    const int max_endpoints = (max_endpoints_in == NA_INTEGER || max_endpoints_in < 1) ? 0 : max_endpoints_in;
    const int seed = (Rf_asInteger(s_seed) == NA_INTEGER) ? 1 : Rf_asInteger(s_seed);
    const bool verbose = (Rf_asLogical(s_verbose) == TRUE);

    core_distance_result_t core = compute_core_distance(
        adj_list,
        weight_list,
        core_quantile,
        use_approx,
        n_landmarks,
        seed,
        verbose,
        "S_geodesic_core_endpoints"
    );

    std::vector<int> degree(n);
    for (size_t i = 0; i < n; ++i) degree[i] = static_cast<int>(adj_list[i].size());

    const double endpoint_threshold = quantile_finite(core.distance_to_core, endpoint_quantile);
    std::vector<bool> is_local_max = detect_local_maxima(adj_list, core.distance_to_core);
    std::vector<bool> is_endpoint(n, false);

    for (size_t v = 0; v < n; ++v) {
        if (!is_local_max[v]) continue;
        const double dv = core.distance_to_core[v];
        if (!std::isfinite(dv)) continue;
        if (std::isfinite(endpoint_threshold) && dv + kTol < endpoint_threshold) continue;

        bool has_lower = false;
        bool any_finite_neighbor = false;
        for (int nb : adj_list[v]) {
            const double dn = core.distance_to_core[static_cast<size_t>(nb)];
            if (!std::isfinite(dn)) continue;
            any_finite_neighbor = true;
            if (dn + kTol < dv) has_lower = true;
        }

        if (!any_finite_neighbor || has_lower || degree[v] <= 1 || !core.is_core[v]) {
            is_endpoint[v] = true;
        }
    }

    std::vector<int> endpoint_vertices;
    endpoint_vertices.reserve(n / 20 + 1);
    for (size_t v = 0; v < n; ++v) {
        if (is_endpoint[v]) endpoint_vertices.push_back(static_cast<int>(v));
    }

    std::sort(endpoint_vertices.begin(), endpoint_vertices.end(),
              [&](int a, int b) {
                  const double da = core.distance_to_core[static_cast<size_t>(a)];
                  const double db = core.distance_to_core[static_cast<size_t>(b)];
                  if (std::fabs(da - db) > kTol) return da > db;
                  const double ea = core.eccentricity[static_cast<size_t>(a)];
                  const double eb = core.eccentricity[static_cast<size_t>(b)];
                  if (std::fabs(ea - eb) > kTol) return ea > eb;
                  return a < b;
              });

    if (max_endpoints > 0 && static_cast<int>(endpoint_vertices.size()) > max_endpoints) {
        endpoint_vertices.resize(static_cast<size_t>(max_endpoints));
    }

    std::fill(is_endpoint.begin(), is_endpoint.end(), false);
    std::vector<int> endpoint_rank(n, NA_INTEGER);
    for (size_t i = 0; i < endpoint_vertices.size(); ++i) {
        const int v = endpoint_vertices[i];
        is_endpoint[static_cast<size_t>(v)] = true;
        endpoint_rank[static_cast<size_t>(v)] = static_cast<int>(i + 1);
    }

    std::vector<int> vertices(n);
    std::iota(vertices.begin(), vertices.end(), 0);

    SEXP summary_df = PROTECT(make_endpoint_summary_df(vertices,
                                                       degree,
                                                       core.eccentricity,
                                                       core.distance_to_core,
                                                       core.is_core,
                                                       is_endpoint,
                                                       is_local_max,
                                                       endpoint_rank));

    const int out_len = 15;
    SEXP out = PROTECT(Rf_allocVector(VECSXP, out_len));
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, out_len));

    SET_STRING_ELT(nm, 0, Rf_mkChar("endpoints"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("core_vertices"));
    SET_STRING_ELT(nm, 2, Rf_mkChar("eccentricity"));
    SET_STRING_ELT(nm, 3, Rf_mkChar("distance_to_core"));
    SET_STRING_ELT(nm, 4, Rf_mkChar("degree"));
    SET_STRING_ELT(nm, 5, Rf_mkChar("is_core"));
    SET_STRING_ELT(nm, 6, Rf_mkChar("is_endpoint"));
    SET_STRING_ELT(nm, 7, Rf_mkChar("is_local_max"));
    SET_STRING_ELT(nm, 8, Rf_mkChar("endpoint_rank"));
    SET_STRING_ELT(nm, 9, Rf_mkChar("summary"));
    SET_STRING_ELT(nm, 10, Rf_mkChar("core_threshold"));
    SET_STRING_ELT(nm, 11, Rf_mkChar("endpoint_threshold"));
    SET_STRING_ELT(nm, 12, Rf_mkChar("used_approx_eccentricity"));
    SET_STRING_ELT(nm, 13, Rf_mkChar("n_landmarks_used"));
    SET_STRING_ELT(nm, 14, Rf_mkChar("landmarks"));

    SEXP endpoints_r = PROTECT(convert_vector_int_to_R(endpoint_vertices));
    SEXP core_r = PROTECT(convert_vector_int_to_R(core.core_vertices));
    SEXP ecc_r = PROTECT(convert_vector_double_to_R(core.eccentricity));
    SEXP dist_r = PROTECT(convert_vector_double_to_R(core.distance_to_core));
    SEXP degree_r = PROTECT(convert_vector_int_to_R(degree));
    SEXP is_core_r = PROTECT(convert_vector_bool_to_R(core.is_core));
    SEXP is_endpoint_r = PROTECT(convert_vector_bool_to_R(is_endpoint));
    SEXP is_local_max_r = PROTECT(convert_vector_bool_to_R(is_local_max));
    SEXP endpoint_rank_r = PROTECT(convert_vector_int_to_R(endpoint_rank));
    SEXP core_thld_r = PROTECT(Rf_ScalarReal(core.core_threshold));
    SEXP endpoint_thld_r = PROTECT(Rf_ScalarReal(endpoint_threshold));
    SEXP used_approx_r = PROTECT(Rf_ScalarLogical(core.used_approx ? TRUE : FALSE));
    SEXP n_landmarks_used_r = PROTECT(Rf_ScalarInteger(static_cast<int>(core.landmarks.size())));
    SEXP landmarks_r = PROTECT(convert_vector_int_to_R(core.landmarks));

    SET_VECTOR_ELT(out, 0, endpoints_r);
    SET_VECTOR_ELT(out, 1, core_r);
    SET_VECTOR_ELT(out, 2, ecc_r);
    SET_VECTOR_ELT(out, 3, dist_r);
    SET_VECTOR_ELT(out, 4, degree_r);
    SET_VECTOR_ELT(out, 5, is_core_r);
    SET_VECTOR_ELT(out, 6, is_endpoint_r);
    SET_VECTOR_ELT(out, 7, is_local_max_r);
    SET_VECTOR_ELT(out, 8, endpoint_rank_r);
    SET_VECTOR_ELT(out, 9, summary_df);
    SET_VECTOR_ELT(out, 10, core_thld_r);
    SET_VECTOR_ELT(out, 11, endpoint_thld_r);
    SET_VECTOR_ELT(out, 12, used_approx_r);
    SET_VECTOR_ELT(out, 13, n_landmarks_used_r);
    SET_VECTOR_ELT(out, 14, landmarks_r);

    Rf_setAttrib(out, R_NamesSymbol, nm);
    UNPROTECT(17);
    return out;
}

SEXP S_detect_major_arms(SEXP s_adj_list,
                         SEXP s_weight_list,
                         SEXP s_core_quantile,
                         SEXP s_use_approx_eccentricity,
                         SEXP s_n_landmarks,
                         SEXP s_min_arm_size,
                         SEXP s_min_persistence_quantile,
                         SEXP s_min_length_quantile,
                         SEXP s_max_arms,
                         SEXP s_seed,
                         SEXP s_verbose) {
    std::vector<std::vector<int>> adj_list = convert_adj_list_from_R(s_adj_list);
    std::vector<std::vector<double>> weight_list = convert_weight_list_from_R(s_weight_list);
    validate_graph_inputs(adj_list, weight_list, "S_detect_major_arms");

    const size_t n = adj_list.size();
    const double core_quantile = Rf_asReal(s_core_quantile);
    if (!std::isfinite(core_quantile) || core_quantile <= 0.0 || core_quantile >= 1.0) {
        Rf_error("S_detect_major_arms: core_quantile must be in (0, 1).");
    }

    const bool use_approx = (Rf_asLogical(s_use_approx_eccentricity) == TRUE);
    const int n_landmarks_in = Rf_asInteger(s_n_landmarks);
    const int n_landmarks = (n_landmarks_in == NA_INTEGER) ? 64 : std::max(1, n_landmarks_in);

    const int min_arm_size_in = Rf_asInteger(s_min_arm_size);
    const int min_arm_size = (min_arm_size_in == NA_INTEGER) ? 50 : std::max(1, min_arm_size_in);

    const double min_persistence_quantile = Rf_asReal(s_min_persistence_quantile);
    const double min_length_quantile = Rf_asReal(s_min_length_quantile);
    if (!std::isfinite(min_persistence_quantile) || min_persistence_quantile < 0.0 || min_persistence_quantile > 1.0) {
        Rf_error("S_detect_major_arms: min_persistence_quantile must be in [0, 1].");
    }
    if (!std::isfinite(min_length_quantile) || min_length_quantile < 0.0 || min_length_quantile > 1.0) {
        Rf_error("S_detect_major_arms: min_length_quantile must be in [0, 1].");
    }

    const int max_arms_in = Rf_asInteger(s_max_arms);
    const int max_arms = (max_arms_in == NA_INTEGER || max_arms_in < 1) ? 0 : max_arms_in;

    const int seed = (Rf_asInteger(s_seed) == NA_INTEGER) ? 1 : Rf_asInteger(s_seed);
    const bool verbose = (Rf_asLogical(s_verbose) == TRUE);

    core_distance_result_t core = compute_core_distance(
        adj_list,
        weight_list,
        core_quantile,
        use_approx,
        n_landmarks,
        seed,
        verbose,
        "S_detect_major_arms"
    );

    std::vector<int> degree(n);
    for (size_t i = 0; i < n; ++i) degree[i] = static_cast<int>(adj_list[i].size());

    std::vector<bool> is_local_max = detect_local_maxima(adj_list, core.distance_to_core);
    std::vector<int> assigned_tip = assign_vertices_to_peaks(adj_list, core.distance_to_core);

    std::vector<int> tip_basin_size(n, 0);
    for (size_t v = 0; v < n; ++v) {
        const int t = assigned_tip[v];
        if (t >= 0 && static_cast<size_t>(t) < n) {
            tip_basin_size[static_cast<size_t>(t)] += 1;
        }
    }

    persistence_result_t p = compute_peak_persistence(adj_list, core.distance_to_core);

    std::vector<double> tip_length(n, NA_REAL);
    std::vector<double> tip_persistence(n, NA_REAL);
    std::vector<double> tip_score(n, NA_REAL);

    std::vector<int> candidate_tips;
    candidate_tips.reserve(n / 10 + 1);
    for (size_t v = 0; v < n; ++v) {
        if (!is_local_max[v]) continue;
        const double len = core.distance_to_core[v];
        const double per = p.peak_persistence[v];
        if (!std::isfinite(len) || !std::isfinite(per)) continue;
        tip_length[v] = len;
        tip_persistence[v] = per;
        tip_score[v] = per * std::log1p(static_cast<double>(tip_basin_size[v]));
        candidate_tips.push_back(static_cast<int>(v));
    }

    std::vector<double> candidate_lengths;
    std::vector<double> candidate_pers;
    candidate_lengths.reserve(candidate_tips.size());
    candidate_pers.reserve(candidate_tips.size());
    for (int t : candidate_tips) {
        candidate_lengths.push_back(tip_length[static_cast<size_t>(t)]);
        candidate_pers.push_back(tip_persistence[static_cast<size_t>(t)]);
    }

    const double length_threshold = quantile_finite(candidate_lengths, min_length_quantile);
    const double persistence_threshold = quantile_finite(candidate_pers, min_persistence_quantile);

    std::vector<bool> is_major_arm_tip(n, false);
    for (int t : candidate_tips) {
        const size_t tt = static_cast<size_t>(t);
        if (tip_basin_size[tt] < min_arm_size) continue;
        if (std::isfinite(length_threshold) && tip_length[tt] + kTol < length_threshold) continue;
        if (std::isfinite(persistence_threshold) && tip_persistence[tt] + kTol < persistence_threshold) continue;
        is_major_arm_tip[tt] = true;
    }

    std::vector<int> major_arms;
    major_arms.reserve(candidate_tips.size());
    for (int t : candidate_tips) {
        if (is_major_arm_tip[static_cast<size_t>(t)]) major_arms.push_back(t);
    }

    auto tip_cmp = [&](int a, int b) {
        const double sa = tip_score[static_cast<size_t>(a)];
        const double sb = tip_score[static_cast<size_t>(b)];
        if (std::fabs(sa - sb) > kTol) return sa > sb;
        const int ba = tip_basin_size[static_cast<size_t>(a)];
        const int bb = tip_basin_size[static_cast<size_t>(b)];
        if (ba != bb) return ba > bb;
        const double la = tip_length[static_cast<size_t>(a)];
        const double lb = tip_length[static_cast<size_t>(b)];
        if (std::fabs(la - lb) > kTol) return la > lb;
        return a < b;
    };

    if (major_arms.empty() && !candidate_tips.empty()) {
        std::vector<int> fallback = candidate_tips;
        std::sort(fallback.begin(), fallback.end(), tip_cmp);
        major_arms.push_back(fallback.front());
        is_major_arm_tip[static_cast<size_t>(fallback.front())] = true;
    }

    std::sort(major_arms.begin(), major_arms.end(), tip_cmp);
    if (max_arms > 0 && static_cast<int>(major_arms.size()) > max_arms) {
        for (size_t i = static_cast<size_t>(max_arms); i < major_arms.size(); ++i) {
            is_major_arm_tip[static_cast<size_t>(major_arms[i])] = false;
        }
        major_arms.resize(static_cast<size_t>(max_arms));
    }

    std::vector<int> arm_rank_of_tip(n, NA_INTEGER);
    for (size_t i = 0; i < major_arms.size(); ++i) {
        arm_rank_of_tip[static_cast<size_t>(major_arms[i])] = static_cast<int>(i + 1);
    }

    std::vector<bool> is_on_major_arm(n, false);
    std::vector<int> basin_size_of_vertex(n, 0);
    std::vector<double> persistence_of_vertex(n, NA_REAL);
    std::vector<double> length_of_vertex(n, NA_REAL);
    std::vector<double> score_of_vertex(n, NA_REAL);

    for (size_t v = 0; v < n; ++v) {
        const int t = assigned_tip[v];
        if (t < 0 || static_cast<size_t>(t) >= n) continue;
        const size_t tt = static_cast<size_t>(t);
        basin_size_of_vertex[v] = tip_basin_size[tt];
        persistence_of_vertex[v] = tip_persistence[tt];
        length_of_vertex[v] = tip_length[tt];
        score_of_vertex[v] = tip_score[tt];
        if (is_major_arm_tip[tt]) is_on_major_arm[v] = true;
    }

    std::vector<int> local_maxima;
    local_maxima.reserve(candidate_tips.size());
    for (int t : candidate_tips) local_maxima.push_back(t);

    std::vector<int> vertices(n);
    std::iota(vertices.begin(), vertices.end(), 0);

    SEXP summary_df = PROTECT(make_major_arm_summary_df(vertices,
                                                        degree,
                                                        core.eccentricity,
                                                        core.distance_to_core,
                                                        core.is_core,
                                                        is_local_max,
                                                        assigned_tip,
                                                        basin_size_of_vertex,
                                                        persistence_of_vertex,
                                                        length_of_vertex,
                                                        score_of_vertex,
                                                        is_major_arm_tip,
                                                        is_on_major_arm,
                                                        arm_rank_of_tip));

    const int out_len = 24;
    SEXP out = PROTECT(Rf_allocVector(VECSXP, out_len));
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, out_len));

    SET_STRING_ELT(nm, 0, Rf_mkChar("major_arms"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("local_maxima"));
    SET_STRING_ELT(nm, 2, Rf_mkChar("assigned_tip"));
    SET_STRING_ELT(nm, 3, Rf_mkChar("tip_basin_size"));
    SET_STRING_ELT(nm, 4, Rf_mkChar("tip_persistence"));
    SET_STRING_ELT(nm, 5, Rf_mkChar("tip_length"));
    SET_STRING_ELT(nm, 6, Rf_mkChar("tip_score"));
    SET_STRING_ELT(nm, 7, Rf_mkChar("is_tip_selected"));
    SET_STRING_ELT(nm, 8, Rf_mkChar("arm_rank_of_tip"));
    SET_STRING_ELT(nm, 9, Rf_mkChar("is_on_major_arm"));
    SET_STRING_ELT(nm, 10, Rf_mkChar("basin_size_of_vertex"));
    SET_STRING_ELT(nm, 11, Rf_mkChar("persistence_of_vertex"));
    SET_STRING_ELT(nm, 12, Rf_mkChar("length_of_vertex"));
    SET_STRING_ELT(nm, 13, Rf_mkChar("score_of_vertex"));
    SET_STRING_ELT(nm, 14, Rf_mkChar("eccentricity"));
    SET_STRING_ELT(nm, 15, Rf_mkChar("distance_to_core"));
    SET_STRING_ELT(nm, 16, Rf_mkChar("degree"));
    SET_STRING_ELT(nm, 17, Rf_mkChar("is_core"));
    SET_STRING_ELT(nm, 18, Rf_mkChar("core_vertices"));
    SET_STRING_ELT(nm, 19, Rf_mkChar("summary"));
    SET_STRING_ELT(nm, 20, Rf_mkChar("core_threshold"));
    SET_STRING_ELT(nm, 21, Rf_mkChar("persistence_threshold"));
    SET_STRING_ELT(nm, 22, Rf_mkChar("length_threshold"));
    SET_STRING_ELT(nm, 23, Rf_mkChar("diagnostics"));

    SEXP major_arms_r = PROTECT(convert_vector_int_to_R(major_arms));
    SEXP local_max_r = PROTECT(convert_vector_int_to_R(local_maxima));
    SEXP assigned_tip_r = PROTECT(convert_vector_int_to_R(assigned_tip));
    SEXP tip_basin_size_r = PROTECT(convert_vector_int_to_R(tip_basin_size));
    SEXP tip_persistence_r = PROTECT(convert_vector_double_to_R(tip_persistence));
    SEXP tip_length_r = PROTECT(convert_vector_double_to_R(tip_length));
    SEXP tip_score_r = PROTECT(convert_vector_double_to_R(tip_score));
    SEXP is_tip_selected_r = PROTECT(convert_vector_bool_to_R(is_major_arm_tip));
    SEXP arm_rank_of_tip_r = PROTECT(convert_vector_int_to_R(arm_rank_of_tip));
    SEXP is_on_major_arm_r = PROTECT(convert_vector_bool_to_R(is_on_major_arm));
    SEXP basin_size_of_vertex_r = PROTECT(convert_vector_int_to_R(basin_size_of_vertex));
    SEXP persistence_of_vertex_r = PROTECT(convert_vector_double_to_R(persistence_of_vertex));
    SEXP length_of_vertex_r = PROTECT(convert_vector_double_to_R(length_of_vertex));
    SEXP score_of_vertex_r = PROTECT(convert_vector_double_to_R(score_of_vertex));
    SEXP ecc_r = PROTECT(convert_vector_double_to_R(core.eccentricity));
    SEXP dist_r = PROTECT(convert_vector_double_to_R(core.distance_to_core));
    SEXP degree_r = PROTECT(convert_vector_int_to_R(degree));
    SEXP is_core_r = PROTECT(convert_vector_bool_to_R(core.is_core));
    SEXP core_vertices_r = PROTECT(convert_vector_int_to_R(core.core_vertices));
    SEXP core_threshold_r = PROTECT(Rf_ScalarReal(core.core_threshold));
    SEXP persistence_threshold_r = PROTECT(Rf_ScalarReal(persistence_threshold));
    SEXP length_threshold_r = PROTECT(Rf_ScalarReal(length_threshold));

    SEXP diagnostics = PROTECT(Rf_allocVector(VECSXP, 5));
    SEXP diagnostics_nm = PROTECT(Rf_allocVector(STRSXP, 5));
    SET_STRING_ELT(diagnostics_nm, 0, Rf_mkChar("min_arm_size"));
    SET_STRING_ELT(diagnostics_nm, 1, Rf_mkChar("used_approx_eccentricity"));
    SET_STRING_ELT(diagnostics_nm, 2, Rf_mkChar("n_landmarks_used"));
    SET_STRING_ELT(diagnostics_nm, 3, Rf_mkChar("landmarks"));
    SET_STRING_ELT(diagnostics_nm, 4, Rf_mkChar("candidate_tips"));
    SET_VECTOR_ELT(diagnostics, 0, Rf_ScalarInteger(min_arm_size));
    SET_VECTOR_ELT(diagnostics, 1, Rf_ScalarLogical(core.used_approx ? TRUE : FALSE));
    SET_VECTOR_ELT(diagnostics, 2, Rf_ScalarInteger(static_cast<int>(core.landmarks.size())));
    SET_VECTOR_ELT(diagnostics, 3, convert_vector_int_to_R(core.landmarks));
    SET_VECTOR_ELT(diagnostics, 4, convert_vector_int_to_R(candidate_tips));
    Rf_setAttrib(diagnostics, R_NamesSymbol, diagnostics_nm);

    SET_VECTOR_ELT(out, 0, major_arms_r);
    SET_VECTOR_ELT(out, 1, local_max_r);
    SET_VECTOR_ELT(out, 2, assigned_tip_r);
    SET_VECTOR_ELT(out, 3, tip_basin_size_r);
    SET_VECTOR_ELT(out, 4, tip_persistence_r);
    SET_VECTOR_ELT(out, 5, tip_length_r);
    SET_VECTOR_ELT(out, 6, tip_score_r);
    SET_VECTOR_ELT(out, 7, is_tip_selected_r);
    SET_VECTOR_ELT(out, 8, arm_rank_of_tip_r);
    SET_VECTOR_ELT(out, 9, is_on_major_arm_r);
    SET_VECTOR_ELT(out, 10, basin_size_of_vertex_r);
    SET_VECTOR_ELT(out, 11, persistence_of_vertex_r);
    SET_VECTOR_ELT(out, 12, length_of_vertex_r);
    SET_VECTOR_ELT(out, 13, score_of_vertex_r);
    SET_VECTOR_ELT(out, 14, ecc_r);
    SET_VECTOR_ELT(out, 15, dist_r);
    SET_VECTOR_ELT(out, 16, degree_r);
    SET_VECTOR_ELT(out, 17, is_core_r);
    SET_VECTOR_ELT(out, 18, core_vertices_r);
    SET_VECTOR_ELT(out, 19, summary_df);
    SET_VECTOR_ELT(out, 20, core_threshold_r);
    SET_VECTOR_ELT(out, 21, persistence_threshold_r);
    SET_VECTOR_ELT(out, 22, length_threshold_r);
    SET_VECTOR_ELT(out, 23, diagnostics);

    Rf_setAttrib(out, R_NamesSymbol, nm);
    UNPROTECT(27);
    return out;
}
