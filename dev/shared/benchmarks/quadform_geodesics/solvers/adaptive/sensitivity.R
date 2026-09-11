# Experimental overrides, loaded only by the sensitivity adapters.
.qgx_initialize <- qga.initialize
.qgx_sample <- qga.sample
.qgx_radius <- qg3.radius
.qgx_indices <- qg3.window.indices
.qgx_record <- qga.record

qgx.settings <- function(parameters) {
  if (!identical(sort(names(parameters)), c("cohort", "neighborhood")) ||
      length(parameters$neighborhood) != 1L || length(parameters$cohort) != 1L ||
      !parameters$neighborhood %in% c("neighbors", "fixed_disk", "fixed_span") ||
      !parameters$cohort %in% c("epochs", "edges", "seconds"))
    stop("Sensitivity tests require one known neighborhood and cohort")
  parameters
}
qga.initialize <- function(s) {
  .qgx_initialize(s)
  U <- s$U
  # Fixed before any refinement; identical for both methods and orientations.
  s$config$reference_radius <- max(vapply(qga.path.edges(U),
    function(edge) qga.norm(edge[2L, ] - edge[1L, ]), 0))
  qga.record(s, "reference_neighborhood", list(radius = s$config$reference_radius))
  qga.checkpoint(s)
}
qg3.radius <- function(s, old, anchor) {
  if (s$config$neighborhood == "neighbors") .qgx_radius(s, old, anchor)
  else s$config$reference_radius
}
qg3.window.indices <- function(s, i) {
  if (s$config$neighborhood != "fixed_span") return(.qgx_indices(s, i))
  radius <- s$config$reference_radius
  lo <- hi <- i; left <- right <- 0
  while (lo > 1L && left < radius) {
    left <- left + qga.norm(s$U[lo, ] - s$U[lo - 1L, ]); lo <- lo - 1L
  }
  while (hi < nrow(s$U) && right < radius) {
    right <- right + qga.norm(s$U[hi + 1L, ] - s$U[hi, ]); hi <- hi + 1L
  }
  c(lo, hi)
}
qga.sample <- function(s, old, anchor, use_global) {
  if (use_global || nrow(old) < 3L ||
      !any(apply(old[2L:(nrow(old) - 1L), , drop = FALSE], 1L,
        function(u) all(u == anchor)))) stop("Invalid experimental path section")
  span <- qga.sum(vapply(qga.path.edges(old),
    function(edge) qga.norm(edge[2L, ] - edge[1L, ]), 0))
  qga.record(s, "section", list(domain_length = span, points = nrow(old)))
  # Reuse the same area-uniform sampler, clipping, draw count and rejection rule.
  .qgx_sample(s, rbind(old[1L, ], anchor, old[nrow(old), ]), anchor, FALSE)
}
qga.record <- function(s, kind, details = list()) {
  if (kind == "epoch_end") {
    events <- Filter(function(d) d$sweep == s$sweep, s$diagnostics)
    radii <- vapply(Filter(function(d) d$kind == "center_disk", events), `[[`, 0, "radius")
    spans <- vapply(Filter(function(d) d$kind == "section", events), `[[`, 0, "domain_length")
    med <- function(x) if (length(x)) median(x) else NA_real_
    details <- c(details, list(length = s$measure$length, vertices = nrow(s$U),
      median_radius = med(radii), median_section_length = med(spans),
      visits = length(spans), accepted = s$accepted, counters = s$control$stats()))
  }
  .qgx_record(s, kind, details)
}
qgx.adapter <- function(id, planner) {
  base <- qga.adapter(id, planner)
  clean <- function(request) { request$parameters <- list(); request }
  qgs.adapter(id,
    supports = function(request) {
      qgx.settings(request$parameters)
      base$supports(clean(request))
    },
    prepare = function(request, control) {
      parameters <- qgx.settings(request$parameters)
      s <- base$prepare(clean(request), control)
      s$request <- request
      s$config$protocol <- "qg-three-point-sensitivity-v1"
      s$config$neighborhood <- parameters$neighborhood
      s$config$cohort <- parameters$cohort
      if (parameters$cohort != "epochs") {
        s$config$max_epochs <- 1000L
        s$config$plateau_sweeps <- 1001L
      }
      s
    }, solve = base$solve, inspect = base$inspect)
}
