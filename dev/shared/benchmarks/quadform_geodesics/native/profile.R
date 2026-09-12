# Development-only profiling. All output must be outside the package checkout.
qgp.profiler <- function(clock) {
  p <- new.env(parent = emptyenv())
  p$clock <- clock; p$depth <- 0L; p$children <- numeric()
  p$counts <- p$total <- p$self <- numeric()
  p
}
qgp.wrap <- function(fun, label, p) {
  force(fun); force(label); force(p)
  if (!label %in% names(p$counts)) {
    p$counts[label] <- 0; p$total[label] <- 0; p$self[label] <- 0
  }
  function(...) {
    level <- p$depth + 1L; p$depth <- level; p$children[level] <- 0
    start <- p$clock()
    on.exit({
      elapsed <- p$clock() - start
      p$counts[label] <- p$counts[label] + 1
      p$total[label] <- p$total[label] + elapsed
      p$self[label] <- p$self[label] + elapsed - p$children[level]
      p$depth <- level - 1L
      if (level > 1L) p$children[level - 1L] <- p$children[level - 1L] + elapsed
    })
    fun(...)
  }
}
qgp.instrument <- function(e, native, runtime, p) {
  groups <- c(qgc_key = "native_coordinate_keys", qgc_keys = "native_coordinate_keys",
    qgc_edge_key = "native_coordinate_keys", qgc_edge_order = "native_edge_ordering",
    qgc_sum = "native_compensated_sums", qgc_speeds = "native_tangent_speeds",
    qgc_complete_edges = "native_graph_construction", qgc_dijkstra = "native_shortest_path")
  for (name in names(groups)) native[[name]] <- qgp.wrap(native[[name]], groups[[name]], p)
  qgc.install(e, native, runtime)
  runtime$qgs.kernel <- qgp.wrap(runtime$qgs.kernel, "integration_driver", p)
  for (name in c("qga.sample", "qga.snapshot"))
    e[[name]] <- qgp.wrap(e[[name]], if (name == "qga.sample") "candidate_sampling" else "adapter_snapshot", p)
  original_rng <- e$qga.pcg64
  startup <- qgp.wrap(original_rng, "random_stream_startup", p)
  e$qga.pcg64 <- function(seed_hex) {
    rng <- startup(seed_hex)
    rng$uniform <- qgp.wrap(rng$uniform, "random_draws", p)
    rng$order_uniform <- qgp.wrap(rng$order_uniform, "random_draws", p)
    rng$state <- qgp.wrap(rng$state, "random_state_export", p)
    rng
  }
  original_control <- runtime$qgs.control.v2
  runtime$qgs.control.v2 <- function(...) {
    control <- original_control(...)
    inside <- environment(control$checkpoint)
    inside$snapshot <- qgp.wrap(inside$snapshot, "cache_snapshot_construction", p)
    control$edge <- qgp.wrap(control$edge, "edge_cache_and_checks", p)
    control
  }
}
qgp.worker <- function(home, reference_path, directory, mode) {
  process_start <- proc.time()[["elapsed"]]
  source(file.path(home, "../../fixtures/quadform_geodesics/collection.R"))
  source(file.path(home, "interface.R")); source(file.path(home, "runner.R"))
  source(file.path(home, "native/load.R")); source(file.path(home, "native/profile.R"))
  reference <- readRDS(reference_path); request <- reference$request
  e <- new.env(parent = globalenv())
  for (name in c("common.R", "local_graph.R", "three_point.R", "sensitivity.R"))
    sys.source(file.path(home, "solvers/adaptive", name), e)
  clock <- qgs.clock; invisible(clock())
  t <- clock(); native <- qgc.load(home); library_seconds <- clock() - t
  p <- qgp.profiler(clock)
  if (mode == "profile") qgp.instrument(e, native, globalenv(), p)
  else qgc.install(e, native, globalenv())
  adapter <- e$qgx.adapter(request$method_id,
    if (request$method_id == "sensitivity_vertex") e$qga.vertex.plan else e$qga.local.graph.plan)
  prepare <- adapter$prepare
  adapter$prepare <- function(request, control) {
    state <- prepare(request, control); state$config$backend <- "cpp-core-v1"; state
  }
  state_writes <- state_bytes <- event_writes <- event_bytes <- 0
  persist_state <- function(state) {
    # Force the snapshot even in the no-disk diagnostic, so only writing changes.
    force(state)
    state_writes <<- state_writes + 1
    if (mode != "no_state_disk") {
      path <- file.path(directory, "algorithm-state.rds")
      qgs.binary(state, path); state_bytes <<- state_bytes + file.info(path)$size
    }
    invisible(NULL)
  }
  persist_event <- function(event) {
    path <- file.path(directory, sprintf("checkpoint-%06d.rds", event$counters$commits))
    qgs.binary(event, path)
    event_writes <<- event_writes + 1; event_bytes <<- event_bytes + file.info(path)$size
  }
  if (mode == "profile") {
    persist_state <- qgp.wrap(persist_state, "state_file_writes", p)
    persist_event <- qgp.wrap(persist_event, "published_path_writes", p)
    Rprof(file.path(directory, "Rprof.out"), interval = .005, memory.profiling = TRUE, gc.profiling = TRUE)
    on.exit(Rprof(NULL), add = TRUE)
  }
  t <- clock()
  result <- qgs.execute(adapter, request, persist = persist_event, persist.state = persist_state)
  search_seconds <- clock() - t
  if (mode == "profile") Rprof(NULL)
  stopifnot(p$depth == 0L)
  qgs.binary(result, file.path(directory, "search-complete.rds"))
  source(file.path(home, "native/parallel.R"))
  # qgs.audit uses the independent R integrator, not qgs.kernel or native overrides.
  t <- clock(); audit <- qgs.audit(result$incumbent$candidate, request); audit_seconds <- clock() - t
  tests <- qgc.same.run(reference, list(search = result, final_audit = audit))
  totals <- data.frame(component = names(p$counts), calls = unname(p$counts),
    inclusive_seconds = unname(p$total), exclusive_seconds = unname(p$self))
  write.csv(totals, file.path(directory, "components.csv"), row.names = FALSE)
  if (mode == "profile") {
    prof <- summaryRprof(file.path(directory, "Rprof.out"), memory = "both")
    write.csv(prof$by.total, file.path(directory, "cpu-by-total.csv"))
    write.csv(prof$by.self, file.path(directory, "cpu-by-self.csv"))
    qgs.write(list(sample_seconds = prof$sampling.time, interval = prof$sample.interval),
      file.path(directory, "cpu-profile.json"))
  }
  answer <- list(mode = mode, request = request, search_seconds = search_seconds,
    prepare_seconds = result$prepare_seconds, solve_seconds = result$solve_seconds,
    cached_native_load_seconds = library_seconds, audit_seconds = audit_seconds,
    worker_seconds = proc.time()[["elapsed"]] - process_start,
    state_writes = state_writes, state_bytes = state_bytes, event_writes = event_writes,
    event_bytes = event_bytes, counters = result$counters, agreement = tests,
    all_passed = all(tests), audit = audit$status, components = totals)
  qgs.write(answer, file.path(directory, "measurement.json"))
  answer
}
qgp.main <- function(args) {
  stopifnot(length(args) == 3L)
  home <- normalizePath(args[1]); study <- normalizePath(args[2]); output <- args[3]
  project <- normalizePath(file.path(home, "../../../.."))
  stopifnot(!file.exists(output), dir.exists(dirname(output)))
  output <- file.path(normalizePath(dirname(output)), basename(output))
  stopifnot(!startsWith(output, paste0(project, "/")), output != project)
  dir.create(output)
  source(file.path(home, "../../fixtures/quadform_geodesics/collection.R"))
  source(file.path(home, "interface.R")); source(file.path(home, "runner.R"))
  source(file.path(home, "native/load.R")); source(file.path(home, "experiments/sensitivity.R"))
  source(file.path(home, "native/parallel.R"))
  sources <- qgc.sources(home, file.path(home, "../../fixtures/quadform_geodesics/collection.R"))
  sources <- c(sources, list(list(path = file.path(home, "native/profile.R"),
    sha256 = digest::digest(file = file.path(home, "native/profile.R"), algo = "sha256"))))
  rows <- read.csv(file.path(study, "runs.csv"))
  selected <- subset(rows, direction == "forward" & repeat_label == 50001 &
    (cohort == "edges" | (cohort == "epochs" & neighborhood == "fixed_span")))
  stopifnot(nrow(selected) == 8L)
  plan <- merge(selected[c("job", "method", "neighborhood", "cohort")],
    data.frame(mode = c(rep("baseline", 3), "profile", "no_state_disk"), repetition = 1:5), by = NULL)
  set.seed(93210); plan <- plan[sample.int(nrow(plan)), ]; rownames(plan) <- NULL
  plan$id <- seq_len(nrow(plan)); write.csv(plan, file.path(output, "plan.csv"), row.names = FALSE)
  qgs.write(list(purpose = "Function-level profiling and exact fixed-work replay; not a new accuracy campaign",
    sources = sources, environment = qgc.environment(), plan = plan, workers = 1,
    constraints = c("Source algorithms and numeric limits unchanged", "No-state-disk is diagnostic only",
      "Stopwatch instrumentation adds overhead", "Cold Python per process; cached native library")),
    file.path(output, "manifest.json"))
  for (s in sources) {
    relative <- if (startsWith(s$path, paste0(home, "/"))) substring(s$path, nchar(home) + 2) else "collection.R"
    target <- file.path(output, "sources", relative); dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    stopifnot(file.copy(s$path, target), digest::digest(file = target, algo = "sha256") == s$sha256)
  }
  qgc.load(home)
  all <- list()
  for (i in seq_len(nrow(plan))) {
    qgs.verify.sources(sources); job <- plan[i, ]; directory <- file.path(output, sprintf("%03d", i))
    dir.create(directory)
    t <- proc.time()[["elapsed"]]
    process <- callr::r_bg(function(home, reference, directory, mode) {
      source(file.path(home, "native/profile.R")); qgp.worker(home, reference, directory, mode)
    }, args = list(home, file.path(study, sprintf("%05d", job$job), "record.rds"), directory, job$mode),
      stdout = file.path(directory, "stdout.log"), stderr = file.path(directory, "stderr.log"),
      supervise = TRUE, libpath = .libPaths())
    peak <- 0
    while (process$is_alive()) {
      handle <- tryCatch(ps::ps_handle(process$get_pid()), error = function(e) NULL)
      if (!is.null(handle)) {
        handles <- c(list(handle), tryCatch(ps::ps_children(handle, recursive = TRUE), error = function(e) list()))
        peak <- max(peak, sum(vapply(handles, function(h)
          tryCatch(unname(ps::ps_memory_info(h)[["rss"]]), error = function(e) 0), 0)))
      }
      if (proc.time()[["elapsed"]] - t > 240 || peak > 2048 * 1024^2) {
        process$kill_tree(); stop("Profiling worker exceeded diagnostic outer limit; evidence retained")
      }
      Sys.sleep(.05)
    }
    answer <- process$get_result(); answer$process_seconds <- proc.time()[["elapsed"]] - t
    answer$peak_mib <- peak / 1024^2; answer$id <- i; answer$reference_job <- job$job
    qgs.write(answer, file.path(directory, "measurement.json"))
    all[[i]] <- answer
    qgs.write(list(completed = i, planned = nrow(plan), all_passed = all(vapply(all, `[[`, TRUE, "all_passed"))),
      file.path(output, "progress.json"))
    cat(sprintf("%d/%d %s %s %s %s: %.2fs, agreement=%s\n", i, nrow(plan), job$method,
      job$neighborhood, job$cohort, job$mode, answer$search_seconds, answer$all_passed)); flush.console()
    if (!answer$all_passed) stop("Exact replay failed; investigate before continuing")
  }
  qgs.verify.sources(sources)
  qgs.binary(all, file.path(output, "measurements.rds"))
  qgs.write(list(status = "complete", runs = length(all), all_passed = TRUE), file.path(output, "completion.json"))
}
if (sys.nframe() == 0L) qgp.main(commandArgs(TRUE))
