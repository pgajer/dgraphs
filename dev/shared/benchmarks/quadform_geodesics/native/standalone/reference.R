# Test/benchmark oracle only. Normal solver execution does not source this file.
qgn.reference <- function(home, api, A, from, to, domain, method, neighborhood,
                          seed = 1, length_scale = 1, max_epochs = 2L, candidates = 32L,
                          native_helpers = NULL) {
  e <- new.env(parent = globalenv())
  sys.source(file.path(home, "../../fixtures/quadform_geodesics/collection.R"), e)
  # source() supplies the filename context used by the existing interface loader.
  source(file.path(home, "interface.R"), local = e)
  source(file.path(home, "runtime.R"), local = e)
  for (file in c("common.R", "local_graph.R", "three_point.R", "sensitivity.R"))
    sys.source(file.path(home, "solvers/adaptive", file), e)
  if (!is.null(native_helpers)) {
    loader <- new.env(parent = globalenv())
    sys.source(file.path(home, "native/load.R"), loader)
    loader$qgc.install(e,native_helpers,e)
  }
  tape <- api$test_uniforms(seed, 100000L)
  index <- c(candidates = 0L, order = 0L)
  draw <- function(label) {
    index[label] <<- index[label] + 1L
    if (index[label] > length(tape[[label]])) stop("Reference random tape exhausted")
    tape[[label]][index[label]]
  }
  rng <- list(uniform = function() draw("candidates"), order_uniform = function() draw("order"),
    state = function() index, versions = list(generator = "matched C++ test stream"))
  published <- list(); calls <- 0L
  control <- list(edge = function(a,b,tighter = FALSE) {
    calls <<- calls + 1L
    e$qgs.kernel(a,b,list(A),length_scale,tighter,function() NULL,function(n) NULL)
  }, publish = function(candidate, phase, diagnostics) {
    published[[length(published)+1L]] <<- list(candidate = candidate, phase = phase)
  }, poll = function() NULL, stats = function() list(edge_calls = calls),
    checkpoint = function(state) invisible(NULL), latest = function() tail(published,1L))
  cfg <- e$qga.config(); cfg$max_epochs <- max_epochs; cfg$candidate_draws <- candidates
  cfg$neighborhood <- neighborhood
  request <- list(from = from, to = to, domain = domain, length_scale = length_scale)
  state <- e$qga.state(request,control,rng,config = cfg)
  elapsed <- system.time(result <- e$qga.solve(state,
    if (method == "single_point") e$qga.vertex.plan else e$qga.local.graph.plan))[["elapsed"]]
  list(path = state$U, length = state$measure$length, error_estimate = state$measure$error_estimate,
    initial_path = published[[2L]]$candidate$path$vertices,
    candidate_uniforms = unname(index["candidates"]), order_uniforms = unname(index["order"]),
    edge_calls = calls, accepted = state$accepted, diagnostics = state$diagnostics,
    published = published, termination = result$termination, elapsed_seconds = elapsed)
}
