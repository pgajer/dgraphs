# Compatibility helper for development scripts; never compiles a second solver.
qgn.load <- function(home = NULL) {
  if (!requireNamespace("dgraphs", quietly = TRUE) ||
      !exists("quadform_geodesics_solver", envir = asNamespace("dgraphs"), inherits = FALSE))
    stop("Install the current dgraphs development package before running these checks")
  list(solve = getFromNamespace("quadform_geodesics_solver", "dgraphs"),
    test_uniforms = getFromNamespace("rcpp_quadform_geodesics_reference_uniforms", "dgraphs"))
}
