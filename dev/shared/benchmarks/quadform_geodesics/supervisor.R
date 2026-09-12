qgs.stop.children <- function(handles) {
  alive <- function(h) tryCatch(isTRUE(ps::ps_is_running(h)) && !identical(ps::ps_status(h), "zombie"),
                                error = function(e) FALSE)
  # ps handles retain process creation times, protecting against PID reuse.
  for (h in handles) if (alive(h)) tryCatch(ps::ps_kill(h), error = function(e) NULL)
  for (i in seq_len(100L)) {
    live <- vapply(handles, alive, logical(1))
    if (!any(live)) return(invisible(TRUE))
    Sys.sleep(0.01)
  }
  stop("descendant_cleanup_failed", call. = FALSE)
}

qgs.supervise <- function(func, args, seconds, rss_mib = 512, start.file = NULL,
                           stdout = "|", stderr = "|", memory.info = ps::ps_memory_info) {
  started <- qgs.clock()
  process <- callr::r_bg(function(func, args, cleanup) {
    # Reconcile descendants before normal return, while ancestry is still known.
    on.exit(cleanup(ps::ps_children(ps::ps_handle(), recursive = TRUE)), add = TRUE)
    do.call(func, args)
  }, args = list(func = func, args = args, cleanup = qgs.stop.children), stdout = stdout, stderr = stderr,
    supervise = TRUE, user_profile = FALSE,
    env = c(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1"))
  known <- list()
  on.exit({
    if (process$is_alive()) process$kill_tree()
    qgs.stop.children(known)
  }, add = TRUE)
  peak <- 0; samples <- 0L; missing <- 0L; reason <- NULL; algorithm.start <- NULL
  errors <- list(); error.count <- 0L; trace <- list(); next.trace <- 0; memory <- NA_real_
  sample.error <- function(e, scope, pid) {
    error.count <<- error.count + 1L
    if (length(errors) < 64L) errors[[length(errors) + 1L]] <<- list(
      elapsed_seconds = qgs.clock() - started, scope = scope, pid = pid,
      message = conditionMessage(e), class = class(e),
      worker_alive = tryCatch(process$is_alive(), error = function(e) NA),
      process_status = tryCatch(ps::ps_status(ps::ps_handle(pid)), error = function(e) conditionMessage(e)))
    invisible(NULL)
  }
  while (process$is_alive()) {
    now <- qgs.clock()
    if (!is.null(start.file) && is.null(algorithm.start) && file.exists(start.file)) {
      algorithm.start <- readRDS(start.file)
      qg.assert(qgs.scalar(algorithm.start) && algorithm.start >= started && algorithm.start <= now,
                "Invalid worker start clock")
    }
    deadline <- if (is.null(start.file)) started + seconds else {
      if (is.null(algorithm.start)) started + 5 else algorithm.start + seconds
    }
    memory <- tryCatch({
      handle <- ps::ps_handle(process$get_pid())
      parent <- unname(memory.info(handle)[["rss"]])
      children <- ps::ps_children(handle, recursive = TRUE)
      for (child in children) {
        key <- paste(ps::ps_pid(child), ps::ps_create_time(child), sep = ":")
        known[[key]] <- child
      }
      parent + sum(vapply(children, function(h) tryCatch(unname(memory.info(h)[["rss"]]),
        error = function(e) { sample.error(e, "child", ps::ps_pid(h)); 0 }), numeric(1)))
    }, error = function(e) { sample.error(e, "worker_tree", process$get_pid()); NA_real_ })
    if (is.finite(memory)) { peak <- max(peak, memory); samples <- samples + 1L; missing <- 0L }
    else missing <- missing + 1L
    if (missing >= 3L && process$is_alive()) reason <- "monitor_unavailable"
    if (is.finite(memory) && memory > rss_mib * 1024^2) reason <- "memory_budget"
    if (now >= deadline) reason <- if (!is.null(start.file) && is.null(algorithm.start)) {
      "startup_timeout"
    } else "time_budget"
    if (now - started >= next.trace || !is.null(reason)) {
      trace[[length(trace) + 1L]] <- list(elapsed_seconds = now - started,
        rss_bytes = memory, consecutive_missing = missing)
      next.trace <- now - started + 1
    }
    if (!is.null(reason)) {
      process$kill_tree(); process$wait(timeout = 1000)
      qg.assert(!process$is_alive(), "Worker did not terminate within grace period")
      break
    }
    process$poll_io(20)
  }
  value <- NULL
  if (is.null(reason)) value <- tryCatch(process$get_result(), error = function(e) {
    reason <<- "worker_failure"; list(diagnostic = conditionMessage(e))
  })
  qgs.stop.children(known)
  list(value = value, termination = reason, pid = process$get_pid(), peak_rss_bytes = peak, rss_samples = samples,
    rss_errors = errors, rss_error_count = error.count, rss_errors_truncated = error.count > length(errors),
    rss_trace = trace, last_rss_bytes = memory,
    elapsed_seconds = qgs.clock() - started, algorithm_start = algorithm.start,
    rss_semantics = "Sampled worker plus descendants RSS sum; shared pages may be counted more than once")
}

qgs.targets <- function(search) {
  targets <- list(initializer = search$initializer$candidate, terminal = search$incumbent$candidate)
  for (i in seq_along(search$checkpoints)) {
    targets[paste0("checkpoint_", i)] <- list(search$checkpoints[[i]]$event$candidate)
  }
  for (i in seq_along(search$history)) {
    targets[paste0("publication_", i)] <- list(search$history[[i]]$candidate)
  }
  routes <- Filter(function(d) identical(d$kind, "initializer_routes"), search$adapter_state$diagnostics)
  if (length(routes)) for (kind in c("grid", "direct")) {
    route <- routes[[1]][[kind]]
    if (!is.null(route$vertices)) targets[paste0("raw_", kind)] <- list(
      qgs.candidate(route$vertices, route$measure$length, route$measure$error_estimate))
  }
  targets
}

qgs.job.v2 <- function(home, fixture.helpers, adapter.path, method, request, directory,
                       sources, audit.seconds = 10) {
  started <- qgs.clock()
  search.process <- qgs.supervise(function(home, helpers, adapter.path, id, request, directory, sources) {
    source(helpers); source(file.path(home, "interface.R")); source(file.path(home, "runner.R"))
    qgs.verify.sources(sources)
    adapter <- qgs.load.adapter(adapter.path, id)
    clock <- qgs.clock()
    qgs.binary(clock, file.path(directory, "started.rds"))
    result <- qgs.execute(adapter, request, persist = function(event) {
      qgs.binary(event, file.path(directory, sprintf("checkpoint-%06d.rds", event$counters$commits)))
    }, persist.state = function(state) qgs.binary(state, file.path(directory, "algorithm-state.rds")))
    qgs.binary(result, file.path(directory, "search-complete.rds"))
    result
  }, args = list(home, fixture.helpers, adapter.path, method$id, request, directory, sources),
  seconds = request$limits$seconds, rss_mib = request$limits$rss_mib,
  start.file = file.path(directory, "started.rds"),
  stdout = file.path(directory, "stdout.log"), stderr = file.path(directory, "stderr.log"))
  search <- search.process$value
  if (!is.null(search.process$termination)) {
    search <- list(status = "failed", termination = search.process$termination,
                    diagnostic = if (is.null(search.process$value$diagnostic)) {
                      "Worker did not return a complete acknowledged result"
                    } else search.process$value$diagnostic)
  }
  targets <- qgs.targets(search)
  audits <- list(); audit.process <- NULL
  if (!is.null(search$incumbent)) {
    audit.file <- file.path(directory, "audit-progress.rds")
    audit.process <- qgs.supervise(function(home, helpers, request, targets, sources, seconds, file) {
      source(helpers); source(file.path(home, "interface.R")); source(file.path(home, "runner.R"))
      qgs.verify.sources(sources)
      qgs.audit.queue(targets, request, seconds = seconds, persist = function(answers) qgs.binary(answers, file))
    }, args = list(home, fixture.helpers, request, targets, sources, audit.seconds, audit.file),
    seconds = audit.seconds, rss_mib = request$limits$rss_mib)
    audits <- if (is.null(audit.process$termination)) audit.process$value else {
      if (file.exists(audit.file)) readRDS(audit.file) else list()
    }
    for (label in names(targets)) if (is.null(audits[[label]])) {
      audits[[label]] <- list(status = if (identical(audit.process$termination, "time_budget")) {
        "audit_unavailable_budget"
      } else "audit_unavailable_worker")
    }
  }
  final <- audits$terminal
  if (is.null(final)) final <- list(status = "unavailable")
  list(interface_version = qgs.version, request = request, search = search,
    audits = audits, final_audit = final, search_monitor = search.process[names(search.process) != "value"],
    audit_monitor = audit.process[names(audit.process) != "value"],
    search_process_seconds = search.process$elapsed_seconds,
    audit_process_seconds = if (is.null(audit.process)) 0 else audit.process$elapsed_seconds,
    end_to_end_seconds = qgs.clock() - started,
    timing_note = "Cold query, monitored process-tree RSS; audit separate; no claims of geodesic optimality")
}
