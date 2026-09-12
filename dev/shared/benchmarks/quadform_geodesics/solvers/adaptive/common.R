# Adaptive search only: connector cache, numerical kernel, audit and budgets belong
# to the shared control. See README.md for the explicit tie resolution and gates.
qga.tie <- "path-key-8.7-attachment-numeric-8.1-v1"
qga.key <- function(u) {
  stopifnot(is.numeric(u), all(is.finite(u)))
  raw <- c(writeBin(as.integer(length(u)), raw(), size = 4, endian = "big"),
           writeBin(as.double(u), raw(), size = 8, endian = "big"))
  paste(sprintf("%02x", as.integer(raw)), collapse = "")
}
qga.keys <- function(U) vapply(seq_len(nrow(U)), function(i) qga.key(U[i, ]), "")
qga.less <- function(a, b) !identical(a, b) && order(c(a, b), method = "radix")[1L] == 1L
qga.edge.key <- function(a, b) paste(sort(c(qga.key(a), qga.key(b)), method = "radix"), collapse = ":")
qga.path.key <- function(U) paste(qga.keys(U), collapse = "/")
qga.sum <- function(x) {
  s <- correction <- 0
  for (v in x) {
    t <- s + v
    correction <- correction + if (abs(s) >= abs(v)) (s - t) + v else (v - t) + s
    s <- t
  }
  s + correction
}
qga.norm <- function(x) {
  m <- max(abs(x))
  if (m == 0) 0 else m * sqrt(sum((x / m)^2))
}
qga.config <- function() list(protocol = "qg-refine-calibration-v2", provisional = TRUE,
  tie_order = qga.tie, cache_policy = "lru65536-levels01-v1", grid_intervals = 16L,
  window_edges = c(2L, 4L, 8L), radius_factors = c(1, 2, 4), samples = 16L,
  global_samples = 4L, rejection_cap = 1000L, max_vertices = 257L,
  max_stage_sweeps = 8L, plateau_sweeps = 2L, plateau_relative = 1e-5,
  insertion_every = 2L, global_every = 4L, move_abs = 1e-12, move_rel = 1e-10)
qga.pcg64 <- function(seed_hex) {
  if (!requireNamespace("reticulate", quietly = TRUE))
    stop("adaptive_rng_unavailable: install reticulate and select Python with NumPy; no R RNG fallback")
  if (!grepl("^[0-9a-f]{16}$", seed_hex)) stop("Invalid exact PCG64 seed")
  np <- reticulate::import("numpy", convert = FALSE)
  bi <- reticulate::import_builtins(convert = FALSE)
  js <- reticulate::import("json", convert = FALSE)
  sys <- reticulate::import("sys", convert = FALSE)
  g <- np$random$Generator(np$random$PCG64(bi$int(seed_hex, 16L)))
  list(uniform = function() as.double(reticulate::py_to_r(g$random(1L)))[1L],
       state = function() reticulate::py_to_r(js$dumps(g$bit_generator$state)),
       versions = list(generator = "NumPy PCG64", numpy = reticulate::py_to_r(np$`__version__`),
         python = reticulate::py_to_r(sys$version),
         reticulate = as.character(utils::packageVersion("reticulate"))))
}
qga.require.control <- function(control) {
  required <- list(cache_policy = "lru65536-levels01-v1", edge_key = "u32be-f64be-v1",
                   edge_failures = "qgs_edge_error-v1", checkpoint = "adaptive-state-v1")
  caps <- if (is.function(control$capabilities)) control$capabilities() else list()
  missing <- names(required)[!vapply(names(required), function(k) identical(caps[[k]], required[[k]]), logical(1))]
  methods <- c("edge", "publish", "poll", "stats", "latest", "checkpoint")
  missing <- c(missing, methods[!vapply(methods, function(k) is.function(control[[k]]), logical(1))])
  if (length(missing)) stop(paste("adaptive_runtime_unaligned:", paste(unique(missing), collapse = ", ")))
  invisible(TRUE)
}
qga.bounds <- function(domain) {
  if (domain$kind == "ball") {
    center <- as.double(unlist(domain$center)); radius <- domain$radius
    list(center = center, width = 2 * radius, diameter = 2 * radius,
         lower = center - radius, upper = center + radius)
  } else {
    lo <- as.double(unlist(domain$lower)); hi <- as.double(unlist(domain$upper))
    list(center = lo + (hi - lo) / 2, width = max(hi - lo),
         diameter = qga.norm(hi - lo), lower = lo, upper = hi)
  }
}
qga.state <- function(request, control, rng, method = "adaptive_vertex", config = qga.config()) {
  s <- new.env(parent = emptyenv())
  s$request <- request; s$control <- control; s$rng <- rng; s$method <- method; s$config <- config
  s$bounds <- qga.bounds(request$domain); s$h0 <- s$bounds$width / config$grid_intervals
  s$U <- rbind(request$from, request$to); s$ids <- c(1L, 2L); s$next_id <- 3L
  s$measure <- NULL; s$segments <- list(); s$stage <- 0L; s$sweep <- 0L; s$stage_sweeps <- 0L
  s$plateau <- 0L; s$global_history <- logical(); s$pass <- 0L
  s$pass_excluded <- character(); s$permanent_excluded <- character()
  s$queue <- integer(); s$queue_position <- 0L; s$phase <- "created"
  s$diagnostics <- list(); s$inserted <- s$deleted <- s$accepted <- 0L
  s
}
qga.snapshot <- function(s, U = s$U, ids = s$ids, measure = s$measure, segments = s$segments) {
  list(schema = "adaptive-state-v1", method = s$method, configuration = s$config,
       vertices = U, ids = ids, next_id = s$next_id, measure = measure, segments = segments,
       stage = s$stage, sweep = s$sweep, stage_sweeps = s$stage_sweeps,
       plateau = s$plateau, global_history = s$global_history, pass = s$pass,
       pass_excluded = s$pass_excluded, permanent_excluded = s$permanent_excluded,
       queue = s$queue, queue_position = s$queue_position, phase = s$phase,
       inserted = s$inserted, deleted = s$deleted, accepted = s$accepted,
       rng_state = if (is.null(s$rng)) NULL else s$rng$state(), diagnostics = s$diagnostics)
}
qga.checkpoint <- function(s) {
  s$control$poll()
  s$control$checkpoint(qga.snapshot(s))
}
qga.record <- function(s, kind, details = list()) {
  s$diagnostics[[length(s$diagnostics) + 1L]] <- c(list(kind = kind, stage = s$stage,
    sweep = s$sweep, pass = s$pass), details)
}
qga.publish <- function(s, U, ids, measure, phase, segments = list(), updates = list()) {
  candidate <- qgs.candidate(U, measure$length, measure$error_estimate)
  snapshot <- qga.snapshot(s, U, ids, measure, segments)
  snapshot[names(updates)] <- updates
  s$control$publish(candidate, phase, list(algorithm_state = snapshot,
    protocol_compliance = "unqualified_pending_shared_runtime_and_independent_audit",
    rng_versions = if (is.null(s$rng)) NULL else s$rng$versions))
  # Commit local state only after the shared control acknowledges publication.
  s$U <- U; s$ids <- ids; s$measure <- measure; s$segments <- segments
  for (name in names(updates)) s[[name]] <- updates[[name]]
}
qga.path.edges <- function(U) lapply(seq_len(nrow(U) - 1L), function(i) rbind(U[i, ], U[i + 1L, ]))
qga.edge.list <- function(edges) {
  if (!length(edges)) return(list())
  keys <- vapply(edges, function(e) qga.edge.key(e[1, ], e[2, ]), "")
  edges <- edges[!duplicated(keys)]; keys <- keys[!duplicated(keys)]
  edges <- edges[order(keys, method = "radix")]
  names(edges) <- sort(keys, method = "radix")
  lapply(edges, function(e) if (qga.less(qga.key(e[2, ]), qga.key(e[1, ]))) e[2:1, , drop = FALSE] else e)
}
qga.batch <- function(s, edges, tighter = FALSE) {
  edges <- qga.edge.list(edges); records <- vector("list", length(edges)); names(records) <- names(edges)
  failed <- character()
  for (k in names(edges)) {
    s$control$poll(); e <- edges[[k]]
    r <- tryCatch(s$control$edge(e[1, ], e[2, ], tighter = tighter),
                  qgs_edge_error = function(e) list(failure = conditionMessage(e)))
    if (!is.null(r$failure)) failed <- c(failed, k)
    else if (!qgs.scalar(r$length) || r$length < 0 || !qgs.scalar(r$error_estimate) || r$error_estimate < 0)
      stop("adaptive_edge_contract_error: invalid successful edge record")
    records[[k]] <- r
  }
  list(records = records, failed = failed, tighter = tighter)
}
qga.segment.records <- function(U, batch) {
  keys <- vapply(qga.path.edges(U), function(e) qga.edge.key(e[1, ], e[2, ]), "")
  r <- batch$records[keys]
  if (any(vapply(r, function(x) is.null(x) || !is.null(x$failure), logical(1))))
    stop("adaptive_incomplete_comparison: missing edge record")
  unname(r)
}
qga.measure.records <- function(r) list(length = qga.sum(vapply(r, `[[`, 0, "length")),
       error_estimate = qga.sum(vapply(r, `[[`, 0, "error_estimate")))
qga.measure <- function(U, batch) qga.measure.records(qga.segment.records(U, batch))
qga.dijkstra <- function(U, edges, batch, from, to, control) {
  n <- nrow(U); keys <- qga.keys(U); dist <- rep(Inf, n); done <- rep(FALSE, n)
  paths <- vector("list", n); weights <- vector("list", n); pathkeys <- rep("", n); dist[from] <- 0
  paths[[from]] <- from; weights[[from]] <- numeric(); pathkeys[from] <- keys[from]
  adjacency <- vector("list", n)
  for (edge in edges) {
    ij <- match(qga.keys(edge), keys)
    w <- batch$records[[qga.edge.key(edge[1, ], edge[2, ])]]$length
    if (ij[1] == ij[2] || w == 0) next
    adjacency[[ij[1]]] <- c(adjacency[[ij[1]]], list(c(ij[2], w)))
    adjacency[[ij[2]]] <- c(adjacency[[ij[2]]], list(c(ij[1], w)))
  }
  repeat {
    control$poll(); live <- which(!done & is.finite(dist)); if (!length(live)) return(NULL)
    best <- live[dist[live] == min(dist[live])]
    u <- best[order(pathkeys[best], method = "radix")[1L]]
    if (u == to) return(U[paths[[u]], , drop = FALSE])
    done[u] <- TRUE
    for (a in adjacency[[u]]) {
      v <- as.integer(a[1]); if (done[v]) next
      pw <- c(weights[[u]], a[2]); d <- qga.sum(pw); p <- c(paths[[u]], v); pk <- paste(keys[p], collapse = "/")
      if (d < dist[v] || (d == dist[v] && qga.less(pk, pathkeys[v]))) {
        dist[v] <- d; paths[[v]] <- p; weights[[v]] <- pw; pathkeys[v] <- pk
      }
    }
  }
}
qga.initialize <- function(s) {
  s$phase <- "initialization"; U <- s$U
  direct <- qga.batch(s, qga.path.edges(U))
  if (length(direct$failed)) direct <- qga.batch(s, qga.path.edges(U), TRUE)
  if (length(direct$failed)) stop("adaptive_initializer_edge_failure")
  dm <- qga.measure(U, direct)
  if (all(U[1, ] == U[2, ])) {
    qga.publish(s, U, s$ids, dm, "initializer", qga.segment.records(U, direct)); return(invisible(TRUE))
  }
  qga.publish(s, U, s$ids, dm, "direct_fallback", qga.segment.records(U, direct))
  b <- s$bounds; h <- s$h0
  spans <- lapply(1:2, function(j) seq(ceiling((b$lower[j] - b$center[j]) / h),
                                            floor((b$upper[j] - b$center[j]) / h)))
  ij <- as.matrix(expand.grid(spans)); G <- sweep(ij * h, 2, b$center, "+")
  inside <- apply(G, 1, qg.inside, domain = s$request$domain)
  G <- G[inside, , drop = FALSE]; ij <- ij[inside, , drop = FALSE]
  edges <- list()
  if (nrow(G) > 1L) for (i in seq_len(nrow(G) - 1L)) {
    s$control$poll()
    for (j in seq.int(i + 1L, nrow(G))) if (max(abs(ij[i, ] - ij[j, ])) == 1)
      edges[[length(edges) + 1L]] <- rbind(G[i, ], G[j, ])
  }
  for (p in 1:2) {
    ds <- apply(G, 1, function(v) qga.norm(v - U[p, ]))
    take <- order(ds, G[, 1], G[, 2], method = "radix")
    take <- take[ds[take] > 0]; take <- head(take, 8L)
    for (i in take) edges[[length(edges) + 1L]] <- rbind(U[p, ], G[i, ])
  }
  edges <- qga.edge.list(edges)
  batch <- qga.batch(s, edges)
  if (length(batch$failed)) batch <- qga.batch(s, edges, TRUE)
  if (length(batch$failed)) stop("adaptive_grid_edge_failure")
  vertices <- rbind(U, G); vertices <- vertices[!duplicated(qga.keys(vertices)), , drop = FALSE]
  path <- qga.dijkstra(vertices, edges, batch, match(qga.key(U[1, ]), qga.keys(vertices)),
                       match(qga.key(U[2, ]), qga.keys(vertices)), s$control)
  gm <- if (is.null(path)) NULL else qga.measure(path, batch)
  qga.record(s, "initializer_routes", list(direct = list(vertices = U, measure = dm),
    grid = if (is.null(path)) list(status = "disconnected") else list(vertices = path, measure = gm)))
  segments <- qga.segment.records(U, direct)
  if (!is.null(gm) && gm$length < dm$length) { U <- path; dm <- gm; segments <- qga.segment.records(U, batch) }
  if (nrow(U) > s$config$max_vertices) stop("adaptive_initializer_vertex_cap")
  qga.publish(s, U, seq_len(nrow(U)), dm, "initializer", segments,
              list(next_id = nrow(U) + 1L))
  qga.checkpoint(s)
  invisible(TRUE)
}
qga.midpoint <- function(a, b, domain) {
  m <- a + (b - a) / 2
  bad <- !is.finite(m); if (any(bad)) m[bad] <- a[bad] / 2 + b[bad] / 2
  if (any(!is.finite(m)) || all(m == a) || all(m == b))
    return(list(ok = FALSE, reason = "midpoint_unrepresentable", midpoint = m))
  if (any(m < pmin(a, b) | m > pmax(a, b)) || !qg.inside(m, domain))
    return(list(ok = FALSE, reason = "midpoint_outside", midpoint = m))
  list(ok = TRUE, midpoint = m)
}
qga.subdivide <- function(s, target, force_interior = FALSE) {
  s$pass <- s$pass + 1L; s$pass_excluded <- character(); s$phase <- "subdivision"
  qga.checkpoint(s)
  repeat {
    s$control$poll()
    lens <- vapply(qga.path.edges(s$U), function(e) qga.norm(e[2, ] - e[1, ]), 0)
    keys <- vapply(qga.path.edges(s$U), function(e) qga.edge.key(e[1, ], e[2, ]), "")
    over <- lens > target | (force_interior && nrow(s$U) == 2L && lens > 0)
    eligible <- which(over & !(keys %in% c(s$pass_excluded, s$permanent_excluded)))
    if (!length(eligible) || nrow(s$U) >= s$config$max_vertices) {
      qga.record(s, "subdivision_end", list(unmet_spacing = sum(over), vertices = nrow(s$U)))
      qga.checkpoint(s); return(invisible(NULL))
    }
    i <- eligible[which.max(lens[eligible])]; key <- keys[i]
    a <- s$U[i, ]; b <- s$U[i + 1L, ]; mid <- qga.midpoint(a, b, s$request$domain)
    if (!mid$ok) {
      s$permanent_excluded <- unique(c(s$permanent_excluded, key))
      qga.record(s, mid$reason, list(edge = key, midpoint = mid$midpoint, exclusion = "run"))
      qga.checkpoint(s); next
    }
    c <- mid$midpoint; attempt <- list(rbind(a, b), rbind(a, c), rbind(c, b))
    check <- function(batch) {
      if (length(batch$failed)) return(list(ok = FALSE, residual = NA_real_, allowance = NA_real_))
      p <- qga.measure(rbind(a, b), batch); kids <- qga.measure(rbind(a, c, b), batch)
      residual <- abs(p$length - kids$length)
      allowance <- p$error_estimate + kids$error_estimate +
        64 * .Machine$double.eps * max(s$request$length_scale, p$length, kids$length)
      list(ok = residual <= allowance, residual = residual, allowance = allowance)
    }
    before <- s$control$stats(); batch <- qga.batch(s, attempt); result <- check(batch)
    if (!result$ok) { batch <- qga.batch(s, attempt, TRUE); result <- check(batch) }
    qga.record(s, "subdivision_attempt", list(edge = key, midpoint = c, result = result,
      tighter = batch$tighter, before = before, after = s$control$stats(),
      exclusion = if (result$ok) "none" else "pass", failures = batch$records[batch$failed]))
    if (!result$ok) { s$pass_excluded <- unique(c(s$pass_excluded, key)); qga.checkpoint(s); next }
    proposed <- rbind(s$U[seq_len(i), , drop = FALSE], c,
                      s$U[seq.int(i + 1L, nrow(s$U)), , drop = FALSE])
    # Immutable segment records belong to the current path, not an edge cache.
    # Reuse only unaffected published segments; every comparison still calls control.
    segments <- append(s$segments[-i], qga.segment.records(rbind(a, c, b), batch), after = i - 1L)
    ids <- append(s$ids, s$next_id, after = i)
    qga.publish(s, proposed, ids, qga.measure.records(segments), "subdivision", segments,
                list(next_id = s$next_id + 1L, inserted = s$inserted + 1L))
    qga.checkpoint(s)
  }
}
qga.uniform <- function(s) {
  x <- s$rng$uniform()
  if (!qgs.scalar(x) || x < 0 || x >= 1) stop("adaptive_rng_contract_error")
  x
}
qga.disk.draw <- function(s, center, radius) {
  angle <- 2 * pi * qga.uniform(s); radius <- radius * sqrt(qga.uniform(s))
  center + radius * c(cos(angle), sin(angle))
}
qga.sample <- function(s, old, anchor, use_global) {
  cfg <- s$config; h <- s$h0 / 2^s$stage
  endpoints <- old[c(1L, nrow(old)), , drop = FALSE]; samples <- list()
  for (side in 1:2) {
    radius <- min(s$bounds$diameter, cfg$radius_factors[s$stage + 1L] *
                    max(qga.norm(endpoints[side, ] - anchor), h))
    ng <- if (use_global) cfg$global_samples else 0L
    for (kind in c("local", "global")) {
      n <- if (kind == "local") cfg$samples - ng else ng
      if (n == 0L) next
      for (j in seq_len(n)) {
        accepted <- FALSE
        for (attempt in seq_len(cfg$rejection_cap)) {
          s$control$poll()
          p <- if (kind == "local") qga.disk.draw(s, endpoints[side, ], radius)
          else if (s$request$domain$kind == "ball") qga.disk.draw(s, s$bounds$center, s$request$domain$radius)
          else s$bounds$lower + vapply(1:2, function(j) qga.uniform(s), 0) * (s$bounds$upper - s$bounds$lower)
          if (all(is.finite(p)) && qg.inside(p, s$request$domain)) { accepted <- TRUE; break }
        }
        if (!accepted) {
          qga.record(s, "sample_shortfall", list(side = side, component = kind, sample = j))
          return(NULL)
        }
        samples[[length(samples) + 1L]] <- p
      }
    }
  }
  R <- do.call(rbind, samples); keys <- qga.keys(R)
  R <- R[!duplicated(keys), , drop = FALSE]
  R[order(qga.keys(R), method = "radix"), , drop = FALSE]
}
qga.vertex.plan <- function(old, R) {
  ends <- old[c(1, nrow(old)), , drop = FALSE]
  paths <- list(ends)
  for (i in seq_len(nrow(R))) if (!all(R[i, ] == ends[1, ]) && !all(R[i, ] == ends[2, ]))
    paths[[length(paths) + 1L]] <- rbind(ends[1, ], R[i, ], ends[2, ])
  list(edges = c(qga.path.edges(old), unlist(lapply(paths, qga.path.edges), recursive = FALSE)),
       choose = function(batch, control) {
         candidate <- old; measure <- qga.measure(old, batch); incumbent <- TRUE
         for (p in paths) {
           m <- qga.measure(p, batch)
           if (m$length < measure$length || (!incumbent && m$length == measure$length &&
                                                qga.less(qga.path.key(p), qga.path.key(candidate)))) {
             candidate <- p; measure <- m; incumbent <- FALSE
           }
         }
         list(vertices = candidate, measure = measure)
       })
}
qga.window <- function(s, lo, hi, anchor, use_global, planner = qga.vertex.plan) {
  old <- s$U[seq.int(lo, hi), , drop = FALSE]
  R <- qga.sample(s, old, anchor, use_global)
  if (is.null(R)) return(FALSE)
  plan <- planner(old, R)
  batch <- qga.batch(s, plan$edges)
  if (length(batch$failed)) batch <- qga.batch(s, plan$edges, TRUE)
  if (length(batch$failed)) { qga.record(s, "window_edge_failure", list(failures = batch$records[batch$failed])); return(FALSE) }
  decide <- function(batch) {
    om <- qga.measure(old, batch); best <- plan$choose(batch, s$control)
    margin <- s$config$move_abs * s$request$length_scale + s$config$move_rel * om$length
    delta <- om$length - best$measure$length
    list(best = best, old = om, delta = delta, margin = margin,
         accepted = delta > margin + om$error_estimate + best$measure$error_estimate,
         ambiguous = delta > margin && delta <= margin + om$error_estimate + best$measure$error_estimate)
  }
  d <- decide(batch)
  if (d$ambiguous && !batch$tighter) { batch <- qga.batch(s, plan$edges, TRUE)
    if (length(batch$failed)) { qga.record(s, "window_retry_failed", list(failures = batch$records[batch$failed])); return(FALSE) }
    d <- decide(batch)
  }
  qga.record(s, "window", list(lo = lo, hi = hi, global = use_global, samples = nrow(R),
    tighter = batch$tighter, decrease = d$delta, margin = d$margin, acceptance_test_passed = d$accepted))
  if (!d$accepted) return(FALSE)
  path <- d$best$vertices
  U <- rbind(if (lo > 1) s$U[seq_len(lo - 1L), , drop = FALSE], path,
             if (hi < nrow(s$U)) s$U[seq.int(hi + 1L, nrow(s$U)), , drop = FALSE])
  if (nrow(U) > s$config$max_vertices) { qga.record(s, "proposal_vertex_cap"); return(FALSE) }
  segments <- c(if (lo > 1L) s$segments[seq_len(lo - 1L)],
                qga.segment.records(path, batch),
                if (hi < nrow(s$U)) s$segments[seq.int(hi, nrow(s$U) - 1L)])
  # IDs identify path occurrences, not coordinates outside the replaced window.
  path_ids <- s$ids[seq.int(lo, hi)][match(qga.keys(path), qga.keys(old))]
  next_id <- s$next_id
  for (j in which(is.na(path_ids))) { path_ids[j] <- next_id; next_id <- next_id + 1L }
  ids <- c(if (lo > 1L) s$ids[seq_len(lo - 1L)], path_ids,
           if (hi < nrow(s$U)) s$ids[seq.int(hi + 1L, nrow(s$U))])
  changes <- list(next_id = next_id, inserted = s$inserted + sum(!ids %in% s$ids),
                  deleted = s$deleted + sum(!s$ids %in% ids), accepted = s$accepted + 1L)
  qga.publish(s, U, ids, qga.measure.records(segments), "refinement", segments, changes)
  TRUE
}
qga.sweep <- function(s, use_global, planner) {
  s$sweep <- s$sweep + 1L; s$stage_sweeps <- s$stage_sweeps + 1L; s$phase <- "sweep"
  s$global_history <- c(s$global_history, use_global)
  s$queue <- if (nrow(s$U) > 2L) s$ids[seq.int(2L, nrow(s$U) - 1L)] else integer()
  if (s$sweep %% 2L == 0L) s$queue <- rev(s$queue)
  start <- s$measure$length
  for (j in seq_along(s$queue)) {
    s$queue_position <- j; qga.checkpoint(s)
    i <- match(s$queue[j], s$ids); if (is.na(i) || i == 1L || i == nrow(s$U)) next
    half <- s$config$window_edges[s$stage + 1L] / 2
    qga.window(s, max(1L, i - half), min(nrow(s$U), i + half), s$U[i, ], use_global, planner)
  }
  s$queue_position <- length(s$queue) + 1L
  relative <- (start - s$measure$length) / max(start, 1e-12 * s$request$length_scale)
  s$plateau <- if (relative < s$config$plateau_relative) s$plateau + 1L else 0L
  if (s$sweep %% s$config$insertion_every == 0L)
    qga.subdivide(s, s$h0 / 2^s$stage)
  qga.record(s, "sweep_end", list(global = use_global, relative_decrease = relative))
  qga.checkpoint(s)
}
qga.solve <- function(s, planner = qga.vertex.plan) {
  qga.initialize(s)
  if (all(s$request$from == s$request$to)) return(list(status = "candidate", termination = "identity"))
  for (stage in 0:2) {
    s$stage <- stage; s$stage_sweeps <- 0L; s$plateau <- 0L
    qga.subdivide(s, s$h0 / 2^stage, force_interior = stage == 0L)
    repeat {
      qga.sweep(s, (s$sweep + 1L) %% s$config$global_every == 0L, planner)
      if (s$stage_sweeps >= s$config$max_stage_sweeps || s$plateau >= s$config$plateau_sweeps) break
    }
    if (!any(tail(s$global_history, 2L))) qga.sweep(s, TRUE, planner)
  }
  s$phase <- "terminal"; qga.checkpoint(s)
  list(status = "candidate", termination = "schedule_exhausted", diagnostics = list(
    configuration = s$config, protocol_compliance = "unqualified_pending_shared_runtime_and_independent_audit"))
}
qga.adapter <- function(id, planner = qga.vertex.plan, initializer.only = FALSE) {
  qgs.adapter(id,
    supports = function(request) {
      if (length(request$parameters)) stop("Adaptive provisional configuration accepts no parameter overrides")
      if (request$limits$max_vertices != 257L) stop("Adaptive protocol requires max_vertices = 257")
      g <- request$geometry
      ok <- g$intrinsic_dim == 2L && length(g$forms) == 1L && request$domain$kind %in% c("ball", "box")
      list(supported = ok, reason = if (ok) "2D single-height quadform; runtime alignment checked at preparation"
           else "adaptive_requires_2d_single_height_convex_domain")
    },
    prepare = function(request, control) {
      qga.require.control(control)
      rng <- if (initializer.only || all(request$from == request$to)) NULL else qga.pcg64(request$seed_hex)
      qga.state(request, control, rng, id)
    },
    solve = function(state, request, control) {
      if (!initializer.only) return(qga.solve(state, planner))
      qga.initialize(state)
      list(status = "candidate", termination = "initializer_complete")
    }, inspect = qga.snapshot)
}
