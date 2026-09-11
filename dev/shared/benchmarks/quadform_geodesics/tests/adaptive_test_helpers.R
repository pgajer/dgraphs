# No cache or auditor in these test controls: each requested edge is evaluated.
# Their deliberately synthetic behavior is not evidence of runtime compliance.
source(file.path(adaptive_home, "../../fixtures/quadform_geodesics/collection.R"))
source(file.path(adaptive_home, "solvers/adaptive/common.R"))
library(testthat)
fixture <- qg.read(file.path(adaptive_home, "../../fixtures/quadform_geodesics/v1"))
req <- function(case = "flat2_box", pair = "grid_direction", ...) qgs.request(fixture, case, pair, ...)
rng_test <- function(value = .37) list(uniform = function() value, state = function() "test-stream",
                                      versions = list(generator = "TEST DOUBLE"))
edge_failure <- function() stop(structure(list(message = "injected numerical failure", call = NULL),
                                        class = c("qgs_edge_error", "error", "condition")))
budget_failure <- function() stop(structure(list(message = "edge_budget", call = NULL),
                                           class = c("qgs_budget", "error", "condition")))
control_test <- function(kernel = function(a,b,tighter) list(length = qga.norm(b-a), error_estimate = 0),
                         budget = Inf, checkpoint_hook = NULL) {
  e <- new.env(); e$edges <- list(); e$events <- list(); e$states <- list()
  e$polls <- 0L
  list(edge = function(a,b,tighter = FALSE) {
    if (length(e$edges) >= budget) budget_failure()
    e$edges[[length(e$edges)+1L]] <- list(from=a,to=b,tighter=tighter,key=qga.edge.key(a,b))
    kernel(a,b,tighter)
  }, publish = function(candidate, phase="search", diagnostics=list()) {
    e$events[[length(e$events)+1L]] <- list(candidate=candidate,phase=phase,diagnostics=diagnostics)
  }, poll = function() {e$polls <- e$polls+1L; invisible(NULL)},
  stats = function() list(edge_calls=length(e$edges)),
  latest = function() if(length(e$events)) tail(e$events,1)[[1]] else NULL,
  checkpoint = function(state) {e$states[[length(e$states)+1L]] <- state
    if (!is.null(checkpoint_hook)) checkpoint_hook(state)},
  log=e)
}
seed_path <- function(s, U) {
  b <- qga.batch(s,qga.path.edges(U)); s$next_id <- nrow(U)+1L
  qga.publish(s,U,seq_len(nrow(U)),qga.measure(U,b),"initializer",qga.segment.records(U,b))
}
