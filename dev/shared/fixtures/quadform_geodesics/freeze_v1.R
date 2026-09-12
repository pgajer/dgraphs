#!/usr/bin/env Rscript
# Explicit release builder. Validation never regenerates frozen inputs.

args <- commandArgs(trailingOnly = TRUE)
home <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])))
source(file.path(home, "collection.R"))
arg <- function(name, default = NULL) {
  i <- match(name, args)
  if (is.na(i)) return(default)
  qg.assert(i < length(args), paste("Missing value:", name))
  args[[i + 1L]]
}
out <- arg("--output")
qg.assert(!is.null(out) && !dir.exists(out), "Provide --output pointing to a new directory")
inputs <- arg("--source-inputs", file.path(home, "v1", "source_inputs"))
files <- c("uv-4101.csv", "uv-4102.csv", "faces-4101.csv", "faces-4102.csv")
qg.assert(all(file.exists(file.path(inputs, files))), "Missing original study input CSVs")
rows <- function(A) lapply(seq_len(nrow(A)), function(i) as.double(A[i, ]))
ball <- function(d, radius = 1) list(kind = "ball", center = rep(0, d), radius = radius)
box <- function(lower, upper) list(kind = "box", lower = lower, upper = upper)
pair <- function(id, from, to, purpose, exact = "unknown") {
  list(id = id, from = as.double(from), to = as.double(to), purpose = purpose,
       exact = list(kind = exact, value = NULL))
}
standard.pairs <- function(d, scale = 1, exact = "unknown") {
  pad <- function(v) c(v, rep(0, d - length(v))) * scale
  a <- pad(c(-0.45, -0.2)); b <- pad(c(0.4, -0.1)); c <- pad(c(0.1, 0.6))
  list(pair("identity", pad(c(0.2, 0.1)), pad(c(0.2, 0.1)), "Coincident endpoints", "identity"),
       pair("near", pad(c(0.2, 0.1)), pad(c(0.20000001, 0.10000002)),
            "Very short separation; keep absolute and relative errors", exact),
       pair("ab", a, b, "Interior triangle edge AB", exact),
       pair("bc", b, c, "Interior triangle edge BC", exact),
       pair("ac", a, c, "Interior triangle edge AC", exact),
       pair("antipodal", pad(c(-1, 0)), pad(c(1, 0)), "Boundary antipodes", exact),
       pair("grid_direction", pad(c(0, 0)), pad(c(0.8, 0.4)),
            "Detect fixed-stencil directional bias", exact))
}
cases <- list()
add <- function(id, forms, domain, purpose, pairs = NULL, frame = NULL, offset = NULL) {
  d <- nrow(forms[[1]])
  if (is.null(pairs)) pairs <- standard.pairs(d)
  ambient <- if (is.null(frame)) d + length(forms) else nrow(frame)
  if (is.null(offset)) offset <- rep(0, ambient)
  geom <- list(intrinsic_dim = d, ambient_dim = ambient, forms = lapply(forms, rows),
               frame = if (is.null(frame)) "canonical" else "supplied", offset = offset)
  if (!is.null(frame)) geom$frame_matrix <- rows(frame)
  radius <- if (domain$kind == "ball") domain$radius else {
    sqrt(sum(pmax(abs(domain$lower), abs(domain$upper))^2))
  }
  span <- if (domain$kind == "ball") 2 * radius else sqrt(sum((domain$upper - domain$lower)^2))
  length.scale <- span * sqrt(1 + 4 * radius^2 * sum(vapply(forms, function(A) norm(A, "2")^2, numeric(1))))
  case <- list(id = id, purpose = purpose, geometry = geom, domain = domain,
               sampling = list(domain_source = "declared_population_support",
                 endpoint_policy = "fixed_coordinates_not_random_draws",
                 density_does_not_restrict_paths = TRUE),
               length_scale = length.scale, pairs = pairs, triangles = list())
  if (all(c("ab", "bc", "ac") %in% vapply(pairs, `[[`, character(1), "id"))) {
    case$triangles <- list(c("ab", "bc", "ac"))
  }
  for (i in seq_along(pairs)) {
    p <- pairs[[i]]
    p$bounds <- qg.bounds(case, p$from, p$to)
    p$exact$value <- qg.exact(case, p)
    case$pairs[[i]] <- p
  }
  cases[[length(cases) + 1L]] <<- case
  invisible(case)
}
unit.box <- function(d) box(rep(-1, d), rep(1, d))
for (d in 2:4) for (kind in c("ball", "box")) {
  add(paste0("flat", d, "_", kind), list(matrix(0, d, d)),
      if (kind == "ball") ball(d) else unit.box(d),
      "Exact Euclidean control in a convex declared domain", standard.pairs(d, exact = "flat"))
}
parab <- list(diag(1.2, 2)); saddle <- list(diag(c(1.2, -1.2)))
radial <- pair("radial", c(0, 0), c(0.6, 0.8), "Exact isotropic apex-to-boundary arc", "radial_from_apex")
pp <- c(standard.pairs(2), list(radial))
sp <- c(standard.pairs(2), list(pair("ruling", c(-0.6, -0.6), c(0.6, 0.6),
                                    "Straight ruling on a saddle", "straight_ruling")))
add("paraboloid2_disk", parab, ball(2), "Specialized smooth-solver baseline", pp)
add("paraboloid2_square", parab, unit.box(2), "Same geometry and pairs on a larger domain", pp)
add("saddle2_disk", saddle, ball(2), "Shooting baseline and exact ruling", sp)
add("saddle2_square", saddle, unit.box(2), "Same saddle and pairs on the sampling square", sp)
add("paraboloid2_rectangle", parab, box(c(-0.3, -1), c(0.3, 1)),
    "Narrow rectangle; unrestricted candidates require containment checks",
    list(pair("boundary_face", c(0.3, -0.8), c(0.3, 0.8), "Endpoints on the same narrow face"),
         pair("opposite_corners", c(-0.3, -1), c(0.3, 1), "Box corners")))
add("saddle2_rectangle", saddle, box(c(-1, -0.2), c(1, 0.2)),
    "Narrow saddle patch, not its enclosing disk",
    list(pair("boundary_face", c(-0.9, 0.2), c(0.9, 0.2), "Same-face endpoints"),
         pair("opposite_corners", c(-1, -0.2), c(1, 0.2), "Box corners")))
add("paraboloid2_high_curvature", list(diag(8, 2)), ball(2), "High curvature", pp)
add("saddle2_high_curvature", list(diag(c(8, -8))), ball(2), "High curvature with ruling", sp)
add("paraboloid2_radius64", list(diag(2)), ball(2, 64), "Large-radius continuation sentinel",
    c(standard.pairs(2, 64), list(pair("radial", c(0, 0), c(38.4, 51.2),
      "Large exact apex arc", "radial_from_apex"))))
add("saddle2_radius64", list(diag(c(1, -1))), ball(2, 64), "Large-radius shooting sentinel",
    standard.pairs(2, 64))
add("anisotropic2_disk", list(diag(c(0.35, 3))), ball(2), "Clairaut isotropic specialization is inapplicable")
add("cross_term2_square", list(matrix(c(1.1, 0.75, 0.75, 0.1), 2)), unit.box(2),
    "Non-diagonal indefinite symmetric form")
add("paraboloid3_ball", list(diag(1.2, 3)), ball(3), "3D positive form with radial control",
    c(standard.pairs(3), list(pair("radial", c(0, 0, 0), c(0.48, 0.64, 0.6),
      "Exact 3D radial arc", "radial_from_apex"))))
add("mixed3_cube", list(diag(c(1, -1, 2))), unit.box(3), "3D mixed-index cube",
    c(standard.pairs(3), list(pair("full_dimension", c(-0.7, 0.2, 0.5), c(0.4, -0.6, -0.8),
      "All latent coordinates vary"))))
for (kind in c("ball", "box")) add(paste0("mixed4_", kind), list(diag(c(1, 1, -2, -4))),
  if (kind == "ball") ball(4) else unit.box(4), "4D anisotropic mixed form",
  c(standard.pairs(4), list(pair("full_dimension", c(-0.4, 0.2, 0.3, -0.5), c(0.3, -0.4, 0.5, 0.2),
                                "All four latent coordinates vary"))))
add("multi_form2_square", list(diag(2), matrix(c(0, 0.5, 0.5, 0), 2)), unit.box(2),
    "Codimension two; no single-height specialization")
Q <- rbind(c(0, 0, -1), c(1, 0, 0), c(0, 1, 0), c(0, 0, 0))
add("paraboloid2_rigid_frame", parab, ball(2), "Ambient isometry and translation preserve distances",
    pp, frame = Q, offset = c(2, -3, 1, 4))
for (s in c(0.001, 1000)) {
  scaled <- lapply(pp, function(p) { p$from <- s * p$from; p$to <- s * p$to; p })
  add(if (s < 1) "paraboloid2_small_units" else "paraboloid2_large_units",
      lapply(parab, function(A) A / s), ball(2, s),
      "Scale latent coordinates and divide forms by scale: F_new = scale * F", scaled)
}
clouds <- lapply(c("4101", "4102"), function(seed) as.matrix(read.csv(file.path(inputs, paste0("uv-", seed, ".csv")))))
names(clouds) <- c("4101", "4102")
bad <- rbind(c(11, 155), c(57, 155), c(77, 155), c(115, 184), c(148, 155), c(155, 228))
regression <- lapply(seq_len(nrow(bad)), function(i) {
  ids <- bad[i, ]
  p <- pair(paste(ids, collapse = "_"), clouds[["4101"]][ids[1] + 1L, ],
            clouds[["4101"]][ids[2] + 1L, ], "Historical mesh-refinement outlier; new target is sampling square")
  p$source <- list(file = "source_inputs/uv-4101.csv", zero_based_rows = as.integer(ids))
  p
})
add("regression_paraboloid4101", parab, unit.box(2), "Six actual former refinement outliers", regression)
failed <- pair("2_3", clouds[["4102"]][3, ], clouds[["4102"]][4, ],
               "Actual zero-path-segment failure endpoints; failure is not an expected outcome")
failed$source <- list(file = "source_inputs/uv-4102.csv", zero_based_rows = c(2L, 3L))
add("regression_paraboloid4102", parab, unit.box(2), "Former optimizer-degeneracy endpoints", list(failed))
for (seed in names(clouds)) {
  U <- clouds[[seed]]
  distances <- as.matrix(dist(U)); diag(distances) <- Inf
  near <- which(distances == min(distances), arr.ind = TRUE)[1, ]
  far <- which(distances == max(distances[is.finite(distances)]), arr.ind = TRUE)[1, ]
  sentinel <- lapply(list(near, far), function(ids) {
    p <- pair(paste(ids - 1L, collapse = "_"), U[ids[1], ], U[ids[2], ],
              "Deterministic short/long source-cloud sentinel; not a localized historical failure")
    p$source <- list(file = paste0("source_inputs/uv-", seed, ".csv"), zero_based_rows = as.integer(ids - 1L))
    p
  })
  add(paste0("regression_saddle", seed), saddle, unit.box(2),
      "Cloud-level historical failure; offending pair was not retained", sentinel)
}
relation <- function(a, b, kind, factor = NULL, pairs = vapply(pp, `[[`, character(1), "id")) {
  list(from_case = a, to_case = b, kind = kind, factor = factor, pairs = pairs)
}
x <- list(schema_version = 1L, collection_id = "quadform_geodesics", collection_version = "1.0.0",
  frozen_date = "2026-09-09", equation = "F(u) = Q * (u, u^T A1 u, ..., u^T Am u) + offset; no implicit 1/2",
  domain_policy = "Closed declared population sampling domain, never inferred from sample extrema or convex hull",
  checks = list(absolute_factor = 1e-12, relative_factor = 1e-8,
    scope = "Analytic controls and necessary consistency checks, not accuracy certification for unknown distances",
    results_required = c("finite_nonnegative", "identity", "chord_lower", "segment_upper", "symmetry",
                         "exact_when_known", "triangle_when_available", "scale_isometry", "domain_inclusion"),
    future_path_checks = c("both_endpoints", "entire_path_domain_containment", "independent_length_integration")),
  cases = cases,
  relations = list(relation("paraboloid2_disk", "paraboloid2_rigid_frame", "distance_scale", 1),
    relation("paraboloid2_disk", "paraboloid2_small_units", "distance_scale", 0.001),
    relation("paraboloid2_disk", "paraboloid2_large_units", "distance_scale", 1000),
    relation("paraboloid2_square", "paraboloid2_disk", "domain_inclusion"),
    relation("saddle2_square", "saddle2_disk", "domain_inclusion", pairs = vapply(sp, `[[`, character(1), "id"))),
  robustness_inputs = list(list(id = "duplicate_interior_vertex", case_id = "regression_paraboloid4102",
    pair_id = "2_3", latent_path = rows(rbind(failed$from, (failed$from + failed$to) / 2,
      (failed$from + failed$to) / 2, failed$to)),
    check = "Handle redundant segment or reject this start with a structured diagnostic; attempt other declared starts")),
  cloud_workloads = do.call(c, lapply(c("paraboloid", "saddle"), function(surface) lapply(names(clouds), function(seed) {
    list(id = paste(surface, seed, sep = "_"), case_id = paste0("regression_", surface, seed),
      source_file = paste0("source_inputs/uv-", seed, ".csv"), n = 240L,
      pairs = "All i < j in zero-based rows 0..239", unordered_pair_count = 28680L,
      default_execution = FALSE, domain = unit.box(2))
  }))))
invisible(qg.validate(x, package.check = FALSE))
dir.create(file.path(out, "source_inputs"), recursive = TRUE)
qg.assert(all(file.copy(file.path(inputs, files), file.path(out, "source_inputs", files))), "Input copy failed")
write.json <- function(value, path) {
  jsonlite::write_json(value, path, auto_unbox = TRUE, pretty = TRUE, digits = NA, null = "null")
}
write.json(x, file.path(out, "collection.json"))
provenance <- list(source_project = "grip", source_directory = "papers/gmds_manuscript/evidence/study-embedding-methods/inputs",
  source_definition = "NumPy PCG64 seeds 4101 and 4102; 240 uniform points in [-1,1]^2; saved CSV bytes authoritative",
  face_indexing = "zero-based; original faces retained for lineage, not the new surface boundary",
  old_domain = "sample convex hull", new_domain = "declared sampling square [-1,1]^2",
  interpretation = "Preserves challenging inputs, not the old target or a claim to reproduce each failure unchanged",
  identified_pairs = list(paraboloid4101 = rows(bad), paraboloid4102 = list(c(2L, 3L))),
  missing_diagnostics = list(saddle4101 = "Asymmetry magnitude and offending pair not retained",
                            saddle4102 = "Timeout was cloud/mesh-level, no offending pair identified"))
write.json(provenance, file.path(out, "provenance.json"))
index <- c("# Quadform geodesic fixtures v1", "", "Frozen scientific inputs; no solver results are implied.", "",
           "| Case | Pairs | Purpose |", "|---|---:|---|",
           vapply(cases, function(c) sprintf("| `%s` | %d | %s |", c$id, length(c$pairs), c$purpose), character(1)))
writeLines(index, file.path(out, "INDEX.md"))
payloads <- sort(list.files(out, recursive = TRUE))
manifest <- list(collection_version = "1.0.0", hash_algorithm = "sha256",
  frozen_date = "2026-09-09", files = lapply(payloads, function(p) list(path = p,
    bytes = unname(file.info(file.path(out, p))$size), sha256 = digest::digest(file = file.path(out, p), algo = "sha256"))),
  builder = list(file = "freeze_v1.R", sha256 = digest::digest(file = file.path(home, "freeze_v1.R"), algo = "sha256")),
  helpers = list(file = "collection.R", sha256 = digest::digest(file = file.path(home, "collection.R"), algo = "sha256")))
write.json(manifest, file.path(out, "manifest.json"))
writeLines(paste(digest::digest(file = file.path(out, "manifest.json"), algo = "sha256"), " manifest.json"),
           file.path(out, "SEAL.sha256"))
counts <- qg.validate(qg.read(out), package.check = FALSE)
cat(sprintf("Frozen %d cases and %d pairs in %s\n", counts$cases, counts$pairs, out))
