#include "dgraphs/geodesic_stats.hpp"
#include "dgraphs/uniform_grid_graph.hpp"
#include "dgraphs/SEXP_cpp_conversion_utils.hpp"

#include <numeric> // for std::iota()

#include <R.h>
#include <Rinternals.h>

/**
 * R interface for compute_geodesic_stats C++ function
 */
extern "C" SEXP S_compute_geodesic_stats(
    SEXP adj_list_sexp,
    SEXP weight_list_sexp,
    SEXP min_radius_sexp,
    SEXP max_radius_sexp,
    SEXP n_steps_sexp,
    SEXP n_packing_vertices_sexp,
    SEXP max_packing_iterations_sexp,
    SEXP packing_precision_sexp,
    SEXP verbose_sexp
) {
    // Container-first conversions
    std::vector<std::vector<int>>    adj_list    = convert_adj_list_from_R(adj_list_sexp);
    std::vector<std::vector<double>> weight_list = convert_weight_list_from_R(weight_list_sexp);

    // Defensive scalar extraction
    const double min_radius  = Rf_asReal(min_radius_sexp);
    const double max_radius  = Rf_asReal(max_radius_sexp);
    const int    n_steps_i   = Rf_asInteger(n_steps_sexp);
    const int    n_pack_i    = Rf_asInteger(n_packing_vertices_sexp);
    const int    max_iter_i  = Rf_asInteger(max_packing_iterations_sexp);
    const double pack_eps    = Rf_asReal(packing_precision_sexp);
    const int    verbose_i   = Rf_asLogical(verbose_sexp);

    // NA / range checks
    if (ISNAN(min_radius) || ISNAN(max_radius)) {
        Rf_error("S_compute_geodesic_stats(): min_radius and max_radius cannot be NA.");
    }
    if (min_radius <= 0.0 || max_radius <= 0.0) {
        Rf_error("S_compute_geodesic_stats(): min_radius and max_radius must be > 0.");
    }
    if (max_radius < min_radius) {
        Rf_error("S_compute_geodesic_stats(): max_radius must be >= min_radius.");
    }
    if (n_steps_i == NA_INTEGER || n_steps_i <= 0) {
        Rf_error("S_compute_geodesic_stats(): n_steps must be a positive integer.");
    }
    if (n_pack_i == NA_INTEGER || n_pack_i < 0) {
        Rf_error("S_compute_geodesic_stats(): n_packing_vertices must be >= 0.");
    }
    if (max_iter_i == NA_INTEGER || max_iter_i < 0) {
        Rf_error("S_compute_geodesic_stats(): max_packing_iterations must be >= 0.");
    }
    if (ISNAN(pack_eps) || pack_eps <= 0.0) {
        Rf_error("S_compute_geodesic_stats(): packing_precision must be > 0.");
    }
    if (verbose_i == NA_LOGICAL) {
        Rf_error("S_compute_geodesic_stats(): verbose must be TRUE/FALSE.");
    }

    const size_t n_steps           = static_cast<size_t>(n_steps_i);
    const size_t n_packing_vertices= static_cast<size_t>(n_pack_i);
    const size_t max_packing_iters = static_cast<size_t>(max_iter_i);
    const bool   verbose           = (verbose_i == TRUE);

    // Build grid graph (packing or full)
    uniform_grid_graph_t grid_graph;
    const size_t n_vertices = adj_list.size();
    if (n_packing_vertices > 0 && n_packing_vertices < n_vertices) {
        grid_graph = create_maximal_packing(adj_list, weight_list,
                                            n_packing_vertices, max_packing_iters, pack_eps);
    } else {
        std::vector<size_t> packing(n_vertices);
        std::iota(packing.begin(), packing.end(), 0);
        grid_graph = uniform_grid_graph_t(adj_list, weight_list, packing);
        // Diameter (two sweeps)
        auto ecc0         = grid_graph.get_vertex_eccentricity(0);
        auto ecc_far      = grid_graph.get_vertex_eccentricity(ecc0.first);
        grid_graph.graph_diameter = ecc_far.second;
    }

    // Compute geodesic statistics
    geodesic_stats_t stats = compute_geodesic_stats(grid_graph, min_radius, max_radius, n_steps, verbose);

    // Prepare result container
    SEXP result = PROTECT(Rf_allocVector(VECSXP, 6));
    SEXP result_names = PROTECT(Rf_allocVector(STRSXP, 6));
    SET_STRING_ELT(result_names, 0, Rf_mkChar("radii"));
    SET_STRING_ELT(result_names, 1, Rf_mkChar("grid_vertices"));
    SET_STRING_ELT(result_names, 2, Rf_mkChar("geodesic_rays"));
    SET_STRING_ELT(result_names, 3, Rf_mkChar("composite_geodesics"));
    SET_STRING_ELT(result_names, 4, Rf_mkChar("path_overlap"));
    SET_STRING_ELT(result_names, 5, Rf_mkChar("radius_overlaps"));
    Rf_setAttrib(result, R_NamesSymbol, result_names);

    const R_xlen_t n_radii = (R_xlen_t)stats.radii.size();
    // grid vertices as vector
    std::vector<size_t> grid_vertices_vec(grid_graph.grid_vertices.begin(), grid_graph.grid_vertices.end());
    const R_xlen_t n_grid_vertices = (R_xlen_t)grid_vertices_vec.size();

    // 0: radii
    {
        SEXP radii_sexp = PROTECT(Rf_allocVector(REALSXP, n_radii));
        std::copy(stats.radii.begin(), stats.radii.end(), REAL(radii_sexp));
        SET_VECTOR_ELT(result, 0, radii_sexp);
        UNPROTECT(1);
    }

    // 1: grid_vertices (1-based)
    {
        SEXP gv = PROTECT(Rf_allocVector(INTSXP, n_grid_vertices));
        int* gvp = INTEGER(gv);
        for (R_xlen_t i = 0; i < n_grid_vertices; ++i) gvp[i] = (int)grid_vertices_vec[(size_t)i] + 1;
        SET_VECTOR_ELT(result, 1, gv);
        UNPROTECT(1);
    }

    // helper: attach dimnames to a matrix in a local scope
    auto set_dimnames = [](SEXP mat, R_xlen_t nrow, R_xlen_t ncol,
                           const std::vector<size_t>& row_ids) {
        SEXP rownames = PROTECT(Rf_allocVector(STRSXP, nrow));
        for (R_xlen_t i = 0; i < nrow; ++i) {
            char buf[32];
            std::snprintf(buf, sizeof(buf), "%lld", (long long)row_ids[(size_t)i] + 1);
            SET_STRING_ELT(rownames, i, Rf_mkChar(buf));
        }
        SEXP colnames = PROTECT(Rf_allocVector(STRSXP, ncol));
        for (R_xlen_t j = 0; j < ncol; ++j) {
            // Columns use one-based radius indices.
            char buf[32];
            std::snprintf(buf, sizeof(buf), "%lld", (long long)(j + 1));
            SET_STRING_ELT(colnames, j, Rf_mkChar(buf));
        }
        SEXP dimnames = PROTECT(Rf_allocVector(VECSXP, 2));
        SET_VECTOR_ELT(dimnames, 0, rownames);
        SET_VECTOR_ELT(dimnames, 1, colnames);
        Rf_setAttrib(mat, R_DimNamesSymbol, dimnames);
        UNPROTECT(3);
    };

    // 2: geodesic_rays (matrix n_grid_vertices x n_radii)
    {
        SEXP m = PROTECT(Rf_allocMatrix(INTSXP, n_grid_vertices, n_radii));
        int* mp = INTEGER(m);
        const R_xlen_t N = n_grid_vertices * n_radii;
        for (R_xlen_t idx = 0; idx < N; ++idx) mp[idx] = -1;

        for (R_xlen_t r = 0; r < n_radii; ++r) {
            const auto& rays_map = stats.geodesic_rays[(size_t)r];
            for (R_xlen_t i = 0; i < n_grid_vertices; ++i) {
                size_t v = grid_vertices_vec[(size_t)i];
                auto it = rays_map.find(v);
                if (it != rays_map.end()) {
                    mp[i + r * n_grid_vertices] = it->second;
                }
            }
        }
        set_dimnames(m, n_grid_vertices, n_radii, grid_vertices_vec);
        SET_VECTOR_ELT(result, 2, m);
        UNPROTECT(1);
    }

    // 3: composite_geodesics (matrix)
    {
        SEXP m = PROTECT(Rf_allocMatrix(INTSXP, n_grid_vertices, n_radii));
        int* mp = INTEGER(m);
        const R_xlen_t N = n_grid_vertices * n_radii;
        for (R_xlen_t idx = 0; idx < N; ++idx) mp[idx] = 0;

        for (R_xlen_t r = 0; r < n_radii; ++r) {
            const auto& comp_map = stats.composite_geodesics[(size_t)r];
            for (R_xlen_t i = 0; i < n_grid_vertices; ++i) {
                size_t v = grid_vertices_vec[(size_t)i];
                auto it = comp_map.find(v);
                if (it != comp_map.end()) {
                    mp[i + r * n_grid_vertices] = it->second;
                }
            }
        }
        set_dimnames(m, n_grid_vertices, n_radii, grid_vertices_vec);
        SET_VECTOR_ELT(result, 3, m);
        UNPROTECT(1);
    }

    // 4: path_overlap (list of 7 matrices)
    {
        SEXP overlap_list = PROTECT(Rf_allocVector(VECSXP, 7));

        // Build and insert each matrix; protect/unprotect inside scope of overlap_list
        {
            SEXP m = PROTECT(Rf_allocMatrix(REALSXP, n_grid_vertices, n_radii));
            double* mp = REAL(m);
            const R_xlen_t N = n_grid_vertices * n_radii;
            for (R_xlen_t idx = 0; idx < N; ++idx) mp[idx] = 0.0;
            for (R_xlen_t r = 0; r < n_radii; ++r) {
                const auto& omap = stats.paths_overlap[(size_t)r];
                for (R_xlen_t i = 0; i < n_grid_vertices; ++i) {
                    size_t v = grid_vertices_vec[(size_t)i];
                    auto it = omap.find(v);
                    if (it != omap.end()) mp[i + r * n_grid_vertices] = it->second.min;
                }
            }
            set_dimnames(m, n_grid_vertices, n_radii, grid_vertices_vec);
            SET_VECTOR_ELT(overlap_list, 0, m);
            UNPROTECT(1);
        }
        {
            SEXP m = PROTECT(Rf_allocMatrix(REALSXP, n_grid_vertices, n_radii));
            double* mp = REAL(m);
            const R_xlen_t N = n_grid_vertices * n_radii;
            for (R_xlen_t idx = 0; idx < N; ++idx) mp[idx] = 0.0;
            for (R_xlen_t r = 0; r < n_radii; ++r) {
                const auto& omap = stats.paths_overlap[(size_t)r];
                for (R_xlen_t i = 0; i < n_grid_vertices; ++i) {
                    size_t v = grid_vertices_vec[(size_t)i];
                    auto it = omap.find(v);
                    if (it != omap.end()) mp[i + r * n_grid_vertices] = it->second.p05;
                }
            }
            set_dimnames(m, n_grid_vertices, n_radii, grid_vertices_vec);
            SET_VECTOR_ELT(overlap_list, 1, m);
            UNPROTECT(1);
        }
        {
            SEXP m = PROTECT(Rf_allocMatrix(REALSXP, n_grid_vertices, n_radii));
            double* mp = REAL(m);
            const R_xlen_t N = n_grid_vertices * n_radii;
            for (R_xlen_t idx = 0; idx < N; ++idx) mp[idx] = 0.0;
            for (R_xlen_t r = 0; r < n_radii; ++r) {
                const auto& omap = stats.paths_overlap[(size_t)r];
                for (R_xlen_t i = 0; i < n_grid_vertices; ++i) {
                    size_t v = grid_vertices_vec[(size_t)i];
                    auto it = omap.find(v);
                    if (it != omap.end()) mp[i + r * n_grid_vertices] = it->second.p25;
                }
            }
            set_dimnames(m, n_grid_vertices, n_radii, grid_vertices_vec);
            SET_VECTOR_ELT(overlap_list, 2, m);
            UNPROTECT(1);
        }
        {
            SEXP m = PROTECT(Rf_allocMatrix(REALSXP, n_grid_vertices, n_radii));
            double* mp = REAL(m);
            const R_xlen_t N = n_grid_vertices * n_radii;
            for (R_xlen_t idx = 0; idx < N; ++idx) mp[idx] = 0.0;
            for (R_xlen_t r = 0; r < n_radii; ++r) {
                const auto& omap = stats.paths_overlap[(size_t)r];
                for (R_xlen_t i = 0; i < n_grid_vertices; ++i) {
                    size_t v = grid_vertices_vec[(size_t)i];
                    auto it = omap.find(v);
                    if (it != omap.end()) mp[i + r * n_grid_vertices] = it->second.median;
                }
            }
            set_dimnames(m, n_grid_vertices, n_radii, grid_vertices_vec);
            SET_VECTOR_ELT(overlap_list, 3, m);
            UNPROTECT(1);
        }
        {
            SEXP m = PROTECT(Rf_allocMatrix(REALSXP, n_grid_vertices, n_radii));
            double* mp = REAL(m);
            const R_xlen_t N = n_grid_vertices * n_radii;
            for (R_xlen_t idx = 0; idx < N; ++idx) mp[idx] = 0.0;
            for (R_xlen_t r = 0; r < n_radii; ++r) {
                const auto& omap = stats.paths_overlap[(size_t)r];
                for (R_xlen_t i = 0; i < n_grid_vertices; ++i) {
                    size_t v = grid_vertices_vec[(size_t)i];
                    auto it = omap.find(v);
                    if (it != omap.end()) mp[i + r * n_grid_vertices] = it->second.p75;
                }
            }
            set_dimnames(m, n_grid_vertices, n_radii, grid_vertices_vec);
            SET_VECTOR_ELT(overlap_list, 4, m);
            UNPROTECT(1);
        }
        {
            SEXP m = PROTECT(Rf_allocMatrix(REALSXP, n_grid_vertices, n_radii));
            double* mp = REAL(m);
            const R_xlen_t N = n_grid_vertices * n_radii;
            for (R_xlen_t idx = 0; idx < N; ++idx) mp[idx] = 0.0;
            for (R_xlen_t r = 0; r < n_radii; ++r) {
                const auto& omap = stats.paths_overlap[(size_t)r];
                for (R_xlen_t i = 0; i < n_grid_vertices; ++i) {
                    size_t v = grid_vertices_vec[(size_t)i];
                    auto it = omap.find(v);
                    if (it != omap.end()) mp[i + r * n_grid_vertices] = it->second.p95;
                }
            }
            set_dimnames(m, n_grid_vertices, n_radii, grid_vertices_vec);
            SET_VECTOR_ELT(overlap_list, 5, m);
            UNPROTECT(1);
        }
        {
            SEXP m = PROTECT(Rf_allocMatrix(REALSXP, n_grid_vertices, n_radii));
            double* mp = REAL(m);
            const R_xlen_t N = n_grid_vertices * n_radii;
            for (R_xlen_t idx = 0; idx < N; ++idx) mp[idx] = 0.0;
            for (R_xlen_t r = 0; r < n_radii; ++r) {
                const auto& omap = stats.paths_overlap[(size_t)r];
                for (R_xlen_t i = 0; i < n_grid_vertices; ++i) {
                    size_t v = grid_vertices_vec[(size_t)i];
                    auto it = omap.find(v);
                    if (it != omap.end()) mp[i + r * n_grid_vertices] = it->second.max;
                }
            }
            set_dimnames(m, n_grid_vertices, n_radii, grid_vertices_vec);
            SET_VECTOR_ELT(overlap_list, 6, m);
            UNPROTECT(1);
        }

        // set names for overlap_list
        {
            SEXP overlap_names = PROTECT(Rf_allocVector(STRSXP, 7));
            SET_STRING_ELT(overlap_names, 0, Rf_mkChar("min"));
            SET_STRING_ELT(overlap_names, 1, Rf_mkChar("p05"));
            SET_STRING_ELT(overlap_names, 2, Rf_mkChar("p25"));
            SET_STRING_ELT(overlap_names, 3, Rf_mkChar("median"));
            SET_STRING_ELT(overlap_names, 4, Rf_mkChar("p75"));
            SET_STRING_ELT(overlap_names, 5, Rf_mkChar("p95"));
            SET_STRING_ELT(overlap_names, 6, Rf_mkChar("max"));
            Rf_setAttrib(overlap_list, R_NamesSymbol, overlap_names);
            UNPROTECT(1);
        }

        SET_VECTOR_ELT(result, 4, overlap_list);
        UNPROTECT(1); // overlap_list
    }

    // 5: radius_overlaps (list of numeric vectors per radius)
    {
        SEXP radius_overlaps_list = PROTECT(Rf_allocVector(VECSXP, n_radii));
        for (R_xlen_t r = 0; r < n_radii; ++r) {
            const std::vector<double>& rv = stats.radius_overlaps[(size_t)r];
            SEXP v = PROTECT(Rf_allocVector(REALSXP, (R_xlen_t)rv.size()));
            std::copy(rv.begin(), rv.end(), REAL(v));
            SET_VECTOR_ELT(radius_overlaps_list, r, v);
            UNPROTECT(1);
        }
        SET_VECTOR_ELT(result, 5, radius_overlaps_list);
        UNPROTECT(1);
    }

    UNPROTECT(2); // result, result_names
    return result;
}

/**
 * R interface for compute_vertex_geodesic_stats C++ function
 */
extern "C" SEXP S_compute_vertex_geodesic_stats(
    SEXP adj_list_sexp,
    SEXP weight_list_sexp,
    SEXP grid_vertex_sexp,
    SEXP min_radius_sexp,
    SEXP max_radius_sexp,
    SEXP n_steps_sexp,
    SEXP n_packing_vertices_sexp,
    SEXP packing_precision_sexp
) {
    //R_CheckUserInterrupt();

    // Graph inputs (container-first)
    std::vector<std::vector<int>>    adj_list    = convert_adj_list_from_R(adj_list_sexp);
    std::vector<std::vector<double>> weight_list = convert_weight_list_from_R(weight_list_sexp);
    const size_t n_vertices = adj_list.size();

    // Defensive scalars
    const int    grid_vertex_i       = Rf_asInteger(grid_vertex_sexp);
    const double min_radius          = Rf_asReal(min_radius_sexp);
    const double max_radius          = Rf_asReal(max_radius_sexp);
    const int    n_steps_i           = Rf_asInteger(n_steps_sexp);
    const int    n_pack_i            = Rf_asInteger(n_packing_vertices_sexp);
    const double packing_precision   = Rf_asReal(packing_precision_sexp);

    // NA / range checks
    if (grid_vertex_i == NA_INTEGER) {
        Rf_error("S_compute_vertex_geodesic_stats(): 'grid_vertex' cannot be NA.");
    }
    if (n_steps_i == NA_INTEGER || n_steps_i <= 0) {
        Rf_error("S_compute_vertex_geodesic_stats(): 'n_steps' must be a positive integer.");
    }
    if (ISNAN(min_radius) || ISNAN(max_radius)) {
        Rf_error("S_compute_vertex_geodesic_stats(): 'min_radius' and 'max_radius' cannot be NA.");
    }
    if (min_radius < 0.0) {
        Rf_error("S_compute_vertex_geodesic_stats(): 'min_radius' must be >= 0.");
    }
    if (max_radius <= 0.0) {
        Rf_error("S_compute_vertex_geodesic_stats(): 'max_radius' must be > 0.");
    }
    if (max_radius < min_radius) {
        Rf_error("S_compute_vertex_geodesic_stats(): 'max_radius' must be >= 'min_radius'.");
    }
    if (n_pack_i == NA_INTEGER || n_pack_i < 0) {
        Rf_error("S_compute_vertex_geodesic_stats(): 'n_packing_vertices' must be >= 0.");
    }
    if (ISNAN(packing_precision) || packing_precision <= 0.0) {
        Rf_error("S_compute_vertex_geodesic_stats(): 'packing_precision' must be > 0.");
    }

    // 1-based (R) → 0-based (C++) with bounds check
    const size_t grid_vertex = static_cast<size_t>(grid_vertex_i - 1);
    if (grid_vertex_i <= 0 || grid_vertex >= n_vertices) {
        Rf_error("S_compute_vertex_geodesic_stats(): 'grid_vertex' out of bounds (1..%zu).", n_vertices);
    }

    // Build uniform grid graph (packing or full)
    uniform_grid_graph_t grid_graph;
    const size_t n_packing_vertices = static_cast<size_t>(n_pack_i);

    if (n_packing_vertices > 0 && n_packing_vertices < n_vertices) {
        const size_t max_packing_iterations = 20;
        grid_graph = create_maximal_packing(adj_list, weight_list,
                                            n_packing_vertices,
                                            max_packing_iterations,
                                            packing_precision);
    } else {
        // Use all vertices as packing
        std::vector<size_t> packing(n_vertices);
        std::iota(packing.begin(), packing.end(), static_cast<size_t>(0));
        grid_graph = uniform_grid_graph_t(adj_list, weight_list, packing);

        // Initialize diameter info (two-sweep)
        auto ecc0         = grid_graph.get_vertex_eccentricity(static_cast<size_t>(0));
        auto ecc_far      = grid_graph.get_vertex_eccentricity(ecc0.first);
        grid_graph.graph_diameter = ecc_far.second;
    }

    // Compute vertex-specific geodesic statistics
    auto stats = compute_vertex_geodesic_stats(
        grid_graph,
        grid_vertex,
        min_radius,
        max_radius,
        n_steps_i
    );

    const R_xlen_t n_radii = static_cast<R_xlen_t>(stats.size());

    // Result list (2 elements): data matrix [n_radii x 10], vertex (1-based)
    SEXP result = PROTECT(Rf_allocVector(VECSXP, 2));

    // 0: data matrix
    {
        SEXP mat = PROTECT(Rf_allocMatrix(REALSXP, n_radii, 10));
        double* ptr = REAL(mat);

        for (R_xlen_t i = 0; i < n_radii; ++i) {
            auto [radius, geodesic_rays, composite_geodesics, overlap_stats] = stats[static_cast<size_t>(i)];

            // Column-major fill
            ptr[i + 0 * n_radii] = radius;
            ptr[i + 1 * n_radii] = static_cast<double>(geodesic_rays);
            ptr[i + 2 * n_radii] = static_cast<double>(composite_geodesics);

            ptr[i + 3 * n_radii] = overlap_stats.min;
            ptr[i + 4 * n_radii] = overlap_stats.p05;
            ptr[i + 5 * n_radii] = overlap_stats.p25;
            ptr[i + 6 * n_radii] = overlap_stats.median;
            ptr[i + 7 * n_radii] = overlap_stats.p75;
            ptr[i + 8 * n_radii] = overlap_stats.p95;
            ptr[i + 9 * n_radii] = overlap_stats.max;
        }

        // Column names
        SEXP colnames = PROTECT(Rf_allocVector(STRSXP, 10));
        SET_STRING_ELT(colnames, 0, Rf_mkChar("radius"));
        SET_STRING_ELT(colnames, 1, Rf_mkChar("rays"));
        SET_STRING_ELT(colnames, 2, Rf_mkChar("composite_geodesics"));
        SET_STRING_ELT(colnames, 3, Rf_mkChar("overlap_min"));
        SET_STRING_ELT(colnames, 4, Rf_mkChar("overlap_p05"));
        SET_STRING_ELT(colnames, 5, Rf_mkChar("overlap_p25"));
        SET_STRING_ELT(colnames, 6, Rf_mkChar("overlap_median"));
        SET_STRING_ELT(colnames, 7, Rf_mkChar("overlap_p75"));
        SET_STRING_ELT(colnames, 8, Rf_mkChar("overlap_p95"));
        SET_STRING_ELT(colnames, 9, Rf_mkChar("overlap_max"));

        // dimnames: list(NULL, colnames)
        SEXP dimnames = PROTECT(Rf_allocVector(VECSXP, 2));
        SET_VECTOR_ELT(dimnames, 0, R_NilValue);
        SET_VECTOR_ELT(dimnames, 1, colnames);
        Rf_setAttrib(mat, R_DimNamesSymbol, dimnames);
        UNPROTECT(2); // colnames, dimnames

        SET_VECTOR_ELT(result, 0, mat);
        UNPROTECT(1); // mat
    }

    // 1: vertex (1-based echo)
    {
        SEXP v = PROTECT(Rf_ScalarInteger(static_cast<int>(grid_vertex + 1)));
        SET_VECTOR_ELT(result, 1, v);
        UNPROTECT(1);
    }

    // names
    SEXP names = PROTECT(Rf_allocVector(STRSXP, 2));
    SET_STRING_ELT(names, 0, Rf_mkChar("data"));
    SET_STRING_ELT(names, 1, Rf_mkChar("vertex"));
    Rf_setAttrib(result, R_NamesSymbol, names);

    UNPROTECT(2); // result, names
    return result;
}
