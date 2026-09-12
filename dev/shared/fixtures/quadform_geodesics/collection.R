# Shared fixture reader, geometry adapter and numerical checks. No path solver.

qg.assert <- function(ok, message) {
  if (!isTRUE(ok)) stop(message, call. = FALSE)
}

qg.matrix <- function(rows) {
  do.call(rbind, lapply(rows, function(x) as.double(unlist(x))))
}

qg.geometry <- function(case) {
  p <- case$geometry
  args <- list(intrinsic.dim = p$intrinsic_dim, ambient.dim = p$ambient_dim,
               forms = lapply(p$forms, qg.matrix), frame = p$frame,
               offset = unlist(p$offset))
  if (p$frame == "supplied") args$frame.matrix <- qg.matrix(p$frame_matrix)
  do.call(dgraphs::synthetic.quadform, args)
}

qg.norm <- function(x) {
  m <- max(abs(x))
  if (!is.finite(m)) return(Inf)
  if (m == 0) return(0)
  m * sqrt(sum((x / m)^2))
}

qg.inside <- function(x, domain, slack = 0) {
  if (!all(is.finite(x))) return(FALSE)
  if (domain$kind == "ball") {
    return(qg.norm(x - unlist(domain$center)) <= domain$radius + slack)
  }
  all(x >= unlist(domain$lower) - slack & x <= unlist(domain$upper) + slack)
}

qg.embed <- function(case, x) {
  forms <- lapply(case$geometry$forms, qg.matrix)
  z <- c(x, vapply(forms, function(A) sum(x * (A %*% x)), numeric(1)))
  Q <- if (case$geometry$frame == "canonical") diag(length(z)) else {
    qg.matrix(case$geometry$frame_matrix)
  }
  as.double(Q %*% z) + unlist(case$geometry$offset)
}

qg.bounds <- function(case, from, to) {
  h <- to - from
  forms <- lapply(case$geometry$forms, qg.matrix)
  if (all(h == 0)) return(list(chord_lower = 0, segment_upper = 0,
                          quadrature_abs_error = 0))
  a <- vapply(forms, function(A) 2 * sum(from * (A %*% h)), numeric(1))
  b <- vapply(forms, function(A) 2 * sum(h * (A %*% h)), numeric(1))
  val <- stats::integrate(function(t) {
    vapply(t, function(tt) sqrt(sum(h^2) + sum((a + tt * b)^2)), numeric(1))
  }, 0, 1, rel.tol = 1e-12, abs.tol = 0, subdivisions = 1000L)
  list(chord_lower = sqrt(sum((qg.embed(case, from) - qg.embed(case, to))^2)),
       segment_upper = val$value, quadrature_abs_error = val$abs.error)
}

qg.exact <- function(case, pair) {
  u <- unlist(pair$from); v <- unlist(pair$to)
  kind <- pair$exact$kind
  if (kind == "unknown") return(NULL)
  if (kind == "identity") {
    qg.assert(identical(u, v), "Identity control has different endpoints")
    return(0)
  }
  forms <- lapply(case$geometry$forms, qg.matrix)
  if (kind == "flat") {
    qg.assert(all(vapply(forms, function(A) all(A == 0), logical(1))),
              "Flat control has nonzero curvature")
    return(sqrt(sum((v - u)^2)))
  }
  if (kind == "straight_ruling") {
    h <- v - u
    qg.assert(all(vapply(forms, function(A) abs(sum(h * (A %*% h))) < 1e-14,
                        logical(1))), "Ruling is not a straight lifted segment")
    return(sqrt(sum((qg.embed(case, v) - qg.embed(case, u))^2)))
  }
  qg.assert(kind == "radial_from_apex", "Unknown exact-control kind")
  d <- length(u)
  qg.assert(length(forms) == 1L && all(u == 0), "Invalid radial control")
  c <- forms[[1]][1, 1]
  qg.assert(c > 0 && max(abs(forms[[1]] - diag(c, d))) < 1e-14,
            "Radial control requires an isotropic positive form")
  r <- sqrt(sum(v^2))
  0.5 * r * sqrt(1 + 4 * c^2 * r^2) + asinh(2 * c * r) / (4 * c)
}

qg.read <- function(directory) {
  directory <- normalizePath(directory, mustWork = TRUE)
  manifest.file <- file.path(directory, "manifest.json")
  seal <- readLines(file.path(directory, "SEAL.sha256"), warn = FALSE)
  qg.assert(length(seal) == 1L && identical(seal,
    paste(digest::digest(file = manifest.file, algo = "sha256"), " manifest.json")),
    "Manifest seal mismatch")
  manifest <- jsonlite::fromJSON(manifest.file, simplifyVector = FALSE)
  paths <- vapply(manifest$files, `[[`, character(1), "path")
  qg.assert(!anyDuplicated(paths) && !any(grepl("(^/|(^|/)\\.\\.(/|$))", paths)),
            "Invalid manifest paths")
  actual <- list.files(directory, recursive = TRUE, all.files = TRUE,
                       no.. = TRUE, include.dirs = FALSE)
  qg.assert(setequal(actual, c(paths, "manifest.json", "SEAL.sha256")),
            "Unexpected or missing files in frozen directory")
  for (entry in manifest$files) {
    f <- file.path(directory, entry$path)
    qg.assert(identical(digest::digest(file = f, algo = "sha256"), entry$sha256) &&
                file.info(f)$size == entry$bytes, paste("Checksum mismatch:", entry$path))
  }
  x <- jsonlite::fromJSON(file.path(directory, "collection.json"), simplifyVector = FALSE)
  attr(x, "directory") <- directory
  attr(x, "sha256") <- digest::digest(file = file.path(directory, "collection.json"),
                                    algo = "sha256")
  x
}

qg.validate <- function(x, package.check = TRUE) {
  qg.assert(x$schema_version == 1 && x$collection_version == "1.0.0",
            "Unsupported fixture version")
  ids <- vapply(x$cases, `[[`, character(1), "id")
  qg.assert(length(ids) > 0 && !anyDuplicated(ids), "Duplicate or missing case IDs")
  total <- exact <- 0L
  for (case in x$cases) {
    d <- case$geometry$intrinsic_dim; domain <- case$domain
    qg.assert(d %in% 2:4 && domain$kind %in% c("ball", "box"), "Invalid domain/dimension")
    if (domain$kind == "ball") {
      qg.assert(length(domain$center) == d && all(is.finite(unlist(domain$center))) &&
                  is.finite(domain$radius) && domain$radius > 0,
                "Invalid ball")
    } else {
      qg.assert(length(domain$lower) == d && length(domain$upper) == d &&
                  all(is.finite(unlist(c(domain$lower, domain$upper)))) &&
                  all(unlist(domain$lower) < unlist(domain$upper)), "Invalid box")
    }
    forms <- lapply(case$geometry$forms, qg.matrix)
    qg.assert(length(forms) > 0 && all(vapply(forms, function(A) {
      identical(dim(A), c(as.integer(d), as.integer(d))) && all(is.finite(A)) &&
        max(abs(A - t(A))) < 1e-14
    }, logical(1))), "Invalid quadratic forms")
    canonical <- d + length(forms)
    gspec <- case$geometry
    qg.assert(gspec$frame %in% c("canonical", "supplied") &&
                length(gspec$offset) == gspec$ambient_dim && all(is.finite(unlist(gspec$offset))),
              "Invalid ambient frame/offset")
    if (gspec$frame == "canonical") qg.assert(gspec$ambient_dim == canonical, "Invalid canonical dimension")
    else {
      Q <- qg.matrix(gspec$frame_matrix)
      qg.assert(identical(dim(Q), c(as.integer(gspec$ambient_dim), as.integer(canonical))) &&
                  all(is.finite(Q)) && max(abs(crossprod(Q) - diag(canonical))) < 1e-12,
                "Frame must be an ambient isometry")
    }
    qg.assert(is.finite(case$length_scale) && case$length_scale > 0, "Invalid scale")
    pair.ids <- vapply(case$pairs, `[[`, character(1), "id")
    qg.assert(length(pair.ids) > 0 && !anyDuplicated(pair.ids), "Duplicate/missing pair IDs")
    g <- if (package.check) qg.geometry(case) else NULL
    for (pair in case$pairs) {
      u <- unlist(pair$from); v <- unlist(pair$to)
      qg.assert(length(u) == d && length(v) == d && all(is.finite(c(u, v))),
                paste("Invalid endpoints:", case$id, pair$id))
      qg.assert(qg.inside(u, domain) && qg.inside(v, domain),
                paste("Endpoint outside declared domain:", case$id, pair$id))
      if (!is.null(pair$source) && !is.null(attr(x, "directory"))) {
        source <- as.matrix(read.csv(file.path(attr(x, "directory"), pair$source$file)))
        source.rows <- as.integer(unlist(pair$source$zero_based_rows)) + 1L
        qg.assert(length(source.rows) == 2L && all(source.rows >= 1L & source.rows <= nrow(source)) &&
                    max(abs(rbind(u, v) - source[source.rows, , drop = FALSE])) < 1e-15,
                  "Regression endpoints differ from frozen source rows")
      }
      bounds <- qg.bounds(case, u, v)
      tol <- 1e-11 * max(1, bounds$segment_upper)
      qg.assert(max(abs(unlist(bounds)[1:2] - unlist(pair$bounds)[1:2])) <= tol,
                "Frozen bounds do not match endpoints")
      truth <- qg.exact(case, pair)
      if (!is.null(truth)) {
        exact <- exact + 1L
        qg.assert(abs(truth - pair$exact$value) <= tol &&
                    truth >= bounds$chord_lower - tol && truth <= bounds$segment_upper + tol,
                  "Exact control disagrees with formula or bounds")
      } else qg.assert(is.null(pair$exact$value), "Unknown distance has invented truth")
      if (package.check) {
        U <- rbind(u, v)
        actual <- dgraphs::embed.synthetic.geometry(g, U)
        qg.assert(max(abs(actual - rbind(qg.embed(case, u), qg.embed(case, v)))) <= tol,
                  "Package embedding mismatch")
        upper <- dgraphs::edge.lengths.synthetic.geometry(g, matrix(u, nrow = 1),
                                                           matrix(v, nrow = 1), tolerance = 1e-11)
        qg.assert(abs(upper - bounds$segment_upper) <= 1e-9 * max(1, upper),
                  "Package segment-length mismatch")
      }
      total <- total + 1L
    }
    for (triangle in case$triangles) {
      p <- lapply(unlist(triangle), function(id) case$pairs[[match(id, pair.ids)]])
      qg.assert(length(p) == 3 && !any(vapply(p, is.null, logical(1))) &&
                  identical(p[[1]]$to, p[[2]]$from) && identical(p[[1]]$from, p[[3]]$from) &&
                  identical(p[[2]]$to, p[[3]]$to), "Invalid triangle relation")
    }
  }
  for (rel in x$relations) {
    a <- x$cases[[match(rel$from_case, ids)]]; b <- x$cases[[match(rel$to_case, ids)]]
    qg.assert(!is.null(a) && !is.null(b), "Unknown relation case")
    for (id in unlist(rel$pairs)) {
      pa <- a$pairs[[match(id, vapply(a$pairs, `[[`, character(1), "id"))]]
      pb <- b$pairs[[match(id, vapply(b$pairs, `[[`, character(1), "id"))]]
      qg.assert(!is.null(pa) && !is.null(pb), "Unknown relation pair")
      if (rel$kind == "distance_scale") {
        qg.assert(max(abs(unlist(pb$bounds)[1:2] - rel$factor * unlist(pa$bounds)[1:2])) <
                    1e-9 * max(1, pb$bounds$segment_upper), "Invalid scaling relation")
      } else {
        qg.assert(rel$kind == "domain_inclusion" && identical(pa$from, pb$from) &&
                    identical(pa$to, pb$to) && identical(a$geometry, b$geometry),
                  "Invalid domain-inclusion relation")
        qg.assert(a$domain$kind == "box" && b$domain$kind == "ball" &&
                    all(unlist(b$domain$center) - b$domain$radius >= unlist(a$domain$lower)) &&
                    all(unlist(b$domain$center) + b$domain$radius <= unlist(a$domain$upper)),
                  "Declared smaller domain is not contained in larger domain")
      }
    }
  }
  for (workload in x$cloud_workloads) {
    qg.assert(workload$case_id %in% ids && workload$unordered_pair_count == choose(workload$n, 2) &&
                identical(workload$default_execution, FALSE), "Invalid full-cloud workload")
    if (!is.null(attr(x, "directory"))) {
      U <- as.matrix(read.csv(file.path(attr(x, "directory"), workload$source_file)))
      qg.assert(nrow(U) == workload$n && ncol(U) == 2L && all(is.finite(U)) &&
                  all(apply(U, 1, qg.inside, domain = workload$domain)), "Invalid source cloud")
    }
  }
  for (input in x$robustness_inputs) {
    case <- x$cases[[match(input$case_id, ids)]]
    qg.assert(!is.null(case), "Unknown robustness case")
    pair <- case$pairs[[match(input$pair_id, vapply(case$pairs, `[[`, character(1), "id"))]]
    path <- qg.matrix(input$latent_path)
    qg.assert(!is.null(pair) && nrow(path) >= 2L &&
                ncol(path) == case$geometry$intrinsic_dim && all(is.finite(path)) &&
                all(path[1, ] == unlist(pair$from)) &&
                all(path[nrow(path), ] == unlist(pair$to)) &&
                all(apply(path, 1, qg.inside, domain = case$domain)),
              "Invalid robustness path")
  }
  list(cases = length(ids), pairs = total, analytic_pairs = exact,
       directed_queries = 2L * total)
}

qg.template <- function(x) {
  rows <- list()
  for (case in x$cases) for (pair in case$pairs) for (direction in c("forward", "reverse")) {
    rows[[length(rows) + 1L]] <- data.frame(collection_sha256 = attr(x, "sha256"),
      case_id = case$id, pair_id = pair$id, direction = direction, method = "",
      solver_revision = "", status = "not_run", distance = NA_real_,
      elapsed_seconds = NA_real_, diagnostic = "", stringsAsFactors = FALSE)
  }
  do.call(rbind, rows)
}

qg.check.results <- function(x, results) {
  template <- qg.template(x)
  qg.assert(all(names(template) %in% names(results)), "Missing result columns")
  key <- function(z) paste(z$case_id, z$pair_id, z$direction, sep = "/")
  qg.assert(!anyDuplicated(key(results)) && setequal(key(results), key(template)),
            "Result keys must cover every query exactly once, including failures")
  results <- results[match(key(template), key(results)), , drop = FALSE]
  qg.assert(all(results$collection_sha256 == attr(x, "sha256")), "Wrong collection checksum")
  qg.assert(all(results$status %in% c("ok", "failed", "unsupported", "not_run")),
            "Unknown result status")
  qg.assert(is.numeric(results$distance) && is.numeric(results$elapsed_seconds),
            "Distance and elapsed_seconds must be numeric")
  run <- results$status != "not_run"
  qg.assert(all(!is.na(results$method[run]) & nzchar(results$method[run])) &&
              all(!is.na(results$solver_revision[run]) & nzchar(results$solver_revision[run])),
            "Executed results need method and solver revision")
  qg.assert(all(is.finite(results$elapsed_seconds[run]) & results$elapsed_seconds[run] >= 0),
            "Executed results need nonnegative finite runtime")
  qg.assert(all(is.na(results$distance[results$status != "ok"])),
            "Non-ok queries must not carry usable distances")
  rejected <- results$status %in% c("failed", "unsupported")
  qg.assert(all(!is.na(results$diagnostic[rejected]) & nzchar(results$diagnostic[rejected])),
            "Failed/unsupported queries need diagnostics")
  ok <- results$status == "ok"
  qg.assert(all(is.finite(results$distance[ok]) & results$distance[ok] >= 0),
            "Ok distances must be finite and nonnegative")
  lookup <- function(case, pair, direction = "forward") {
    r <- results[results$case_id == case & results$pair_id == pair &
                   results$direction == direction, , drop = FALSE]
    if (r$status == "ok") r$distance else NA_real_
  }
  tolerance <- function(scale, distance) x$checks$absolute_factor * scale +
    x$checks$relative_factor * abs(distance)
  for (case in x$cases) {
    for (pair in case$pairs) {
      values <- c(lookup(case$id, pair$id), lookup(case$id, pair$id, "reverse"))
      for (v in values[is.finite(values)]) {
        tol <- tolerance(case$length_scale, pair$bounds$segment_upper)
        qg.assert(v >= pair$bounds$chord_lower - tol && v <= pair$bounds$segment_upper + tol,
                  paste("Distance violates geometric bounds:", case$id, pair$id))
        if (pair$exact$kind == "identity") qg.assert(v == 0, "Identity distance must be zero")
        else qg.assert(v > 0, "Distinct endpoints need a positive distance")
        if (!is.null(pair$exact$value)) qg.assert(abs(v - pair$exact$value) <=
          tolerance(case$length_scale, pair$exact$value), paste("Exact-control failure:", case$id, pair$id))
      }
      if (all(is.finite(values))) qg.assert(abs(diff(values)) <=
        tolerance(case$length_scale, max(values)), paste("Symmetry failure:", case$id, pair$id))
    }
    for (triangle in case$triangles) {
      v <- vapply(unlist(triangle), function(id) lookup(case$id, id), numeric(1))
      if (all(is.finite(v))) qg.assert(max(v) <= sum(v) - max(v) +
        tolerance(case$length_scale, max(v)), paste("Triangle failure:", case$id))
    }
  }
  for (rel in x$relations) for (id in unlist(rel$pairs)) {
    a <- lookup(rel$from_case, id); b <- lookup(rel$to_case, id)
    if (all(is.finite(c(a, b)))) {
      case <- x$cases[[match(rel$to_case, vapply(x$cases, `[[`, character(1), "id"))]]
      tol <- tolerance(case$length_scale, b)
      if (rel$kind == "distance_scale") qg.assert(abs(b - rel$factor * a) <= tol,
                                                   "Scale/isometry failure")
      else qg.assert(a <= b + tol, "Larger domain cannot increase distance")
    }
  }
  list(ok = sum(ok), total = nrow(results), complete = all(ok),
       meaning = "Necessary consistency checks only; unknown curved distances are not certified")
}
