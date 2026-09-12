# Isolated operation timings; not a replacement for complete-search profiling.
qgp.micro <- function(home, output) {
  stopifnot(!file.exists(output), dir.exists(dirname(output)))
  project <- normalizePath(file.path(home, "../../../.."))
  output <- file.path(normalizePath(dirname(output)), basename(output))
  stopifnot(output != project, !startsWith(output, paste0(project, "/")))
  dir.create(output)
  source(file.path(home, "../../fixtures/quadform_geodesics/collection.R"))
  source(file.path(home, "interface.R")); source(file.path(home, "runner.R"))
  source(file.path(home, "native/load.R"))
  r <- new.env(parent = globalenv()); e <- new.env(parent = globalenv())
  for (env in list(r, e)) for (name in c("common.R", "local_graph.R", "three_point.R", "sensitivity.R"))
    sys.source(file.path(home, "solvers/adaptive", name), env)
  clock <- qgs.clock; invisible(clock())
  t <- clock(); native <- qgc.load(home); load_time <- clock() - t
  runtime <- new.env(parent = globalenv()); qgc.install(e, native, runtime)
  set.seed(1910)
  U <- matrix(runif(70, -.45, .45), ncol = 2); old <- U[1:3, ]; candidates <- U[4:35, ]
  endpoints <- lapply(1:500, function(i) matrix(runif(4, -.45, .45), ncol = 2))
  forms <- list(diag(8, 2)); nothing <- function(...) NULL
  kernels <- list(R = qgs.kernel, CPP = runtime$qgs.kernel)
  integrated <- lapply(kernels, function(kernel) lapply(endpoints, function(V)
    kernel(V[1, ], V[2, ], forms, 32.0624390837628, FALSE, nothing, nothing)))
  stopifnot(identical(integrated$R, integrated$CPP))
  edges <- e$qga.edge.list(native$qgc_complete_edges(U))
  batch <- list(records = lapply(edges, function(V)
    kernels$R(V[1, ], V[2, ], forms, 32.0624390837628, FALSE, nothing, nothing)))
  control <- list(poll = nothing)
  stopifnot(identical(r$qga.dijkstra(U, edges, batch, 1L, 35L, control),
    e$qga.dijkstra(U, edges, batch, 1L, 35L, control)),
    identical(r$qga.local.graph.plan(old, candidates)$edges, e$qga.local.graph.plan(old, candidates)$edges),
    identical(r$qga.keys(U), native$qgc_keys(U)))
  tgrid <- seq(0, 1, length.out = 21); h <- c(.4, -.1); alpha <- 3; beta <- 5
  speeds_R <- function() vapply(tgrid, function(t) qg.norm(c(h, alpha + beta * t)), 0)
  speeds_CPP <- function() native$qgc_speeds(tgrid, h, alpha, beta)
  stopifnot(identical(speeds_R(), speeds_CPP()))
  operations <- list(
    integration_500_edges = list(R = function() lapply(endpoints, function(V)
      kernels$R(V[1, ], V[2, ], forms, 32.0624390837628, FALSE, nothing, nothing)),
      CPP = function() lapply(endpoints, function(V)
        kernels$CPP(V[1, ], V[2, ], forms, 32.0624390837628, FALSE, nothing, nothing))),
    tangent_5000_batches = list(R = function() for(i in 1:5000) speeds_R(),
      CPP = function() for(i in 1:5000) speeds_CPP()),
    keys_500_batches = list(R = function() for(i in 1:500) r$qga.keys(U),
      CPP = function() for(i in 1:500) native$qgc_keys(U)),
    graph_100_plans = list(R = function() for(i in 1:100) r$qga.local.graph.plan(old, candidates),
      CPP = function() for(i in 1:100) e$qga.local.graph.plan(old, candidates)),
    shortest_path_10_searches = list(R = function() for(i in 1:10) r$qga.dijkstra(U, edges, batch, 1L, 35L, control),
      CPP = function() for(i in 1:10) e$qga.dijkstra(U, edges, batch, 1L, 35L, control)))
  measurements <- list()
  for (operation in names(operations)) for (repeat_id in 1:5) {
    for (backend in if (repeat_id %% 2) c("R", "CPP") else c("CPP", "R")) {
      gc(); start <- clock(); operations[[operation]][[backend]](); elapsed <- clock() - start
      measurements[[length(measurements) + 1L]] <- data.frame(operation, repeat_id, backend, seconds = elapsed)
    }
  }
  write.csv(do.call(rbind, measurements), file.path(output, "native-operations.csv"), row.names = FALSE)
  # First call initializes Python/NumPy; later calls create fresh seeded streams
  # in the already initialized interpreter. Timings are not interleaved searches.
  starts <- list()
  for (i in 1:6) {
    t <- clock(); rng <- r$qga.pcg64("ee183217dc1e023cb"); elapsed <- clock() - t
    starts[[i]] <- data.frame(attempt = i, state = if(i == 1) "cold_interpreter" else "warm_interpreter", seconds = elapsed)
  }
  write.csv(do.call(rbind, starts), file.path(output, "random-startup.csv"), row.names = FALSE)
  np <- reticulate::import("numpy", convert = FALSE)
  bi <- reticulate::import_builtins(convert = FALSE); js <- reticulate::import("json", convert = FALSE)
  random_times <- list(); expected <- NULL; expected_state <- NULL
  for (repeat_id in 1:5) for (mode in c("lookup_each_draw", "cached_draw_method", "one_vector_draw")) {
    g <- np$random$Generator(np$random$PCG64(bi$int("ee183217dc1e023cb", 16L)))
    draw <- g$random
    gc(); t <- clock()
    values <- switch(mode,
      lookup_each_draw = vapply(1:10000, function(i) as.double(reticulate::py_to_r(g$random(1L)))[1L], 0),
      cached_draw_method = vapply(1:10000, function(i) as.double(reticulate::py_to_r(draw(1L)))[1L], 0),
      one_vector_draw = as.double(reticulate::py_to_r(draw(10000L))))
    elapsed <- clock() - t; state <- reticulate::py_to_r(js$dumps(g$bit_generator$state))
    if (is.null(expected)) { expected <- values; expected_state <- state }
    stopifnot(identical(values, expected), identical(state, expected_state))
    random_times[[length(random_times) + 1L]] <- data.frame(repeat_id, mode, draws = 10000, seconds = elapsed)
  }
  write.csv(do.call(rbind, random_times), file.path(output, "random-draws.csv"), row.names = FALSE)
  qgs.write(list(status = "complete", exact_kernel_pairs = length(endpoints),
    graph_and_key_checks = "passed", random_value_and_terminal_state_checks = "passed",
    cached_native_load_seconds = load_time,
    sources = lapply(c(file.path(home, "native/profile_micro.R"), file.path(home, "native/core.cpp")),
      function(path) list(path = path, sha256 = digest::digest(file = path, algo = "sha256"))),
    limitation = "Warm isolated operations, not end-to-end speedups; vector draw omits partial-buffer checkpoint semantics"),
    file.path(output, "completion.json"))
}
if (sys.nframe() == 0L) {
  args <- commandArgs(TRUE); stopifnot(length(args) == 2L)
  qgp.micro(normalizePath(args[1]), args[2])
}
