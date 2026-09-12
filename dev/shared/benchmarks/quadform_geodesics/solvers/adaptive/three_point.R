# Load after common.R in a private adapter namespace. Historical adapters are unchanged.
.qg3_config_base <- qga.config
.qg3_rng_base <- qga.pcg64
qga.config <- function() {
  cfg <- .qg3_config_base()
  cfg$protocol <- "qg-three-point-center-v1"
  cfg$initial_edges <- 16L; cfg$candidate_draws <- 32L
  cfg$max_epochs <- 8L; cfg$plateau_sweeps <- 2L
  cfg$arc_abs <- 1e-10; cfg$arc_rel <- 1e-8; cfg$arc_iterations <- 64L
  cfg$window_edges <- 2L; cfg$radius_factors <- 1
  cfg$global_samples <- 0L; cfg$insertion_every <- NA_integer_
  cfg$global_every <- NA_integer_; cfg$grid_intervals <- NA_integer_
  cfg$initializer <- "equal-surface-length-direct"
  cfg$visit_order <- "seeded-fisher-yates-u32-rejection"
  cfg$proposal_region <- "domain-clipped-anchor-disk"
  cfg
}
qga.pcg64 <- function(seed_hex) {
  derive <- function(label) substr(digest::digest(paste("qg-three-point-center-v1", label,
    seed_hex, sep = "|"), algo = "sha256", serialize = FALSE), 1L, 16L)
  seeds <- c(candidates = derive("candidates"), order = derive("order"))
  candidates <- .qg3_rng_base(seeds[["candidates"]])
  visits <- .qg3_rng_base(seeds[["order"]])
  list(uniform = candidates$uniform, order_uniform = visits$uniform,
    state = function() list(seeds = seeds, candidates = candidates$state(), order = visits$state()),
    versions = c(candidates$versions, list(stream_derivation = "sha256-labelled-seed-v1")))
}
qg3.edge <- function(s, a, b) {
  batch <- qga.batch(s, list(rbind(a, b)), TRUE)
  if (length(batch$failed)) stop("three_point_initialization: connector evaluation failed")
  batch$records[[1L]]
}
qg3.arc.vertex <- function(s, a, b, fraction, total) {
  target <- fraction * total$length
  tolerance <- s$config$arc_abs * s$request$length_scale +
    s$config$arc_rel * total$length / s$config$initial_edges
  lo <- 0; hi <- 1
  for (iteration in seq_len(s$config$arc_iterations)) {
    t <- lo + (hi - lo) / 2
    if (t == lo || t == hi) break
    p <- a + t * (b - a)
    if (any(!is.finite(p)) || !qg.inside(p, s$request$domain))
      stop("three_point_initialization: interpolation outside representable domain")
    z <- qg3.edge(s, a, p)
    allowance <- z$error_estimate + fraction * total$error_estimate +
      64 * .Machine$double.eps * max(s$request$length_scale, total$length)
    if (abs(z$length - target) + allowance <= tolerance) return(p)
    if (z$length < target) lo <- t else hi <- t
  }
  stop("three_point_initialization: equal-length target unresolved")
}
qga.initialize <- function(s) {
  ends <- rbind(s$request$from, s$request$to)
  total <- qg3.edge(s, ends[1L, ], ends[2L, ])
  qga.publish(s, ends, c(1L, 2L), qga.measure.records(list(total)),
    "direct_fallback", list(total))
  if (all(ends[1L, ] == ends[2L, ])) {
    qga.publish(s, ends, c(1L, 2L), qga.measure.records(list(total)), "initializer", list(total))
    return(invisible(NULL))
  }
  m <- s$config$initial_edges
  if (m < 2L || m %% 1L != 0L || m + 1L > s$config$max_vertices)
    stop("three_point_initialization: invalid initial edge count")
  # Canonical orientation makes the initial subdivision identical under reversal.
  reverse <- qga.less(qga.key(ends[2L, ]), qga.key(ends[1L, ]))
  canonical <- if (reverse) ends[2:1, , drop = FALSE] else ends
  inside <- lapply(seq_len(m - 1L), function(j)
    qg3.arc.vertex(s, canonical[1L, ], canonical[2L, ], j / m, total))
  U <- rbind(canonical[1L, ], do.call(rbind, inside), canonical[2L, ])
  if (reverse) U <- U[nrow(U):1L, , drop = FALSE]
  U[1L, ] <- ends[1L, ]; U[nrow(U), ] <- ends[2L, ]
  if (any(vapply(seq_len(m), function(i) all(U[i, ] == U[i + 1L, ]), logical(1))))
    stop("three_point_initialization: distinct vertices unrepresentable")
  batch <- qga.batch(s, qga.path.edges(U), TRUE)
  if (length(batch$failed)) stop("three_point_initialization: subdivision integration failed")
  segments <- qga.segment.records(U, batch); measure <- qga.measure.records(segments)
  tolerance <- s$config$arc_abs * s$request$length_scale + s$config$arc_rel * total$length / m
  roundoff <- 64 * .Machine$double.eps * max(s$request$length_scale, total$length)
  equal <- vapply(segments, function(z) abs(z$length - total$length / m) +
    z$error_estimate + total$error_estimate / m <= 2 * tolerance + roundoff, logical(1))
  additive <- abs(measure$length - total$length) <= measure$error_estimate +
    total$error_estimate + (m + 1L) * roundoff
  if (!all(equal) || !additive)
    stop("three_point_initialization: equal-length or additive check failed")
  qga.record(s, "equal_length_initializer", list(edges = m, target = total$length / m,
    maximum_deviation = max(abs(vapply(segments, `[[`, 0, "length") - total$length / m)),
    tolerance = 2 * tolerance + roundoff, direct_length = total$length))
  s$phase <- "initialization"
  qga.publish(s, U, seq_len(nrow(U)), measure, "initializer", segments,
    list(next_id = nrow(U) + 1L))
  qga.checkpoint(s)
}
qg3.radius <- function(s, old, anchor) {
  max(qga.norm(anchor - old[1L, ]), qga.norm(anchor - old[nrow(old), ]))
}
qg3.window.indices <- function(s, i) c(i - 1L, i + 1L)
qga.sample <- function(s, old, anchor, use_global) {
  if (use_global || nrow(old) != 3L || !all(anchor == old[2L, ]))
    stop("three_point_sampling: requires an immediate-neighbor window")
  radius <- qg3.radius(s, old, anchor)
  if (!is.finite(radius) || radius <= 0) {
    qga.record(s, "sample_shortfall", list(reason = "zero_or_nonfinite_radius"))
    return(NULL)
  }
  points <- vector("list", s$config$candidate_draws)
  attempts <- 0L
  for (j in seq_along(points)) {
    accepted <- FALSE
    for (attempt in seq_len(s$config$rejection_cap)) {
      s$control$poll(); attempts <- attempts + 1L
      p <- qga.disk.draw(s, anchor, radius)
      if (all(is.finite(p)) && qg.inside(p, s$request$domain)) {
        accepted <- TRUE; points[[j]] <- p; break
      }
    }
    if (!accepted) {
      qga.record(s, "sample_shortfall", list(sample = j, attempts = attempts))
      return(NULL)
    }
  }
  R <- do.call(rbind, points); R <- R[!duplicated(qga.keys(R)), , drop = FALSE]
  qga.record(s, "center_disk", list(center = anchor, radius = radius,
    accepted_draws = length(points), distinct_points = nrow(R), attempts = attempts))
  R[order(qga.keys(R), method = "radix"), , drop = FALSE]
}
qg3.shuffle <- function(s, ids) {
  if (length(ids) < 2L) return(ids)
  for (k in seq.int(length(ids), 2L)) {
    limit <- floor(2^32 / k) * k
    accepted <- FALSE
    for (attempt in seq_len(s$config$rejection_cap)) {
      s$control$poll(); u <- s$rng$order_uniform()
      if (!qgs.scalar(u) || u < 0 || u >= 1) stop("three_point_order: invalid uniform draw")
      integer <- floor(u * 2^32)
      if (integer < limit) { j <- as.integer(integer %% k) + 1L; accepted <- TRUE; break }
    }
    if (!accepted) stop("three_point_order: rejection limit reached")
    swap <- ids[k]; ids[k] <- ids[j]; ids[j] <- swap
  }
  ids
}
qga.sweep <- function(s, use_global = FALSE, planner = qga.vertex.plan) {
  if (use_global) stop("three_point_epoch: global proposals are disabled")
  s$sweep <- s$sweep + 1L; s$stage_sweeps <- s$stage_sweeps + 1L; s$phase <- "sweep"
  s$global_history <- c(s$global_history, FALSE)
  ids <- if (nrow(s$U) > 2L) s$ids[seq.int(2L, nrow(s$U) - 1L)] else integer()
  s$queue <- qg3.shuffle(s, ids); s$queue_position <- 0L
  qga.record(s, "epoch_order", list(eligible = ids, order = s$queue))
  qga.checkpoint(s); start <- s$measure$length
  for (j in seq_along(s$queue)) {
    s$queue_position <- j; qga.checkpoint(s)
    i <- match(s$queue[j], s$ids)
    if (is.na(i) || i == 1L || i == nrow(s$U)) next
    window <- qg3.window.indices(s, i)
    qga.window(s, window[1L], window[2L], s$U[i, ], FALSE, planner)
  }
  s$queue_position <- length(s$queue) + 1L
  relative <- (start - s$measure$length) / max(start, 1e-12 * s$request$length_scale)
  s$plateau <- if (relative < s$config$plateau_relative) s$plateau + 1L else 0L
  qga.record(s, "epoch_end", list(relative_decrease = relative))
  qga.checkpoint(s)
}
qga.solve <- function(s, planner = qga.vertex.plan) {
  qga.initialize(s)
  if (all(s$request$from == s$request$to)) return(list(status = "candidate", termination = "identity"))
  repeat {
    qga.sweep(s, FALSE, planner)
    if (s$sweep >= s$config$max_epochs || s$plateau >= s$config$plateau_sweeps) break
  }
  s$phase <- "terminal"; qga.checkpoint(s)
  list(status = "candidate", termination = "schedule_exhausted",
    diagnostics = list(configuration = s$config,
      stopping_reason = if (s$plateau >= s$config$plateau_sweeps) "local_stagnation" else "epoch_limit",
      protocol_compliance = "experimental_three_point_not_independently_audited"))
}
