# Runtime policy qg-refine-calibration-v2; adapter search decisions live elsewhere.
qgs.clock <- local({
  symbol <- NULL
  function() {
    if (is.null(symbol)) {
      source <- file.path(qgs.home, "clock.c")
      cache <- file.path(Sys.getenv("TMPDIR", "/tmp"), paste0("qgs-clock-", R.version$platform, "-",
        R.version$major, "-", R.version$minor, "-", digest::digest(file = source, algo = "sha256")))
      dir.create(cache, showWarnings = FALSE)
      dll <- file.path(cache, paste0("qgsclock", .Platform$dynlib.ext))
      if (!file.exists(dll)) {
        build <- tempfile("build-", tmpdir = cache); dir.create(build)
        file.copy(source, file.path(build, "clock.c"))
        pending <- file.path(build, basename(dll)); log <- file.path(build, "build.log")
        status <- system2(file.path(R.home("bin"), "R"),
          c("CMD", "SHLIB", "-o", shQuote(pending), shQuote(file.path(build, "clock.c"))),
          stdout = log, stderr = log)
        qg.assert(status == 0L, paste("Monotonic clock build failed; see", log))
        qg.assert(file.rename(pending, dll), "Cannot publish monotonic clock library")
      }
      info <- dyn.load(dll)
      symbol <<- getNativeSymbolInfo("qgs_monotonic", info)$address
    }
    .Call(symbol)
  }
})

qgs.binary <- function(x, path) {
  tmp <- tempfile(".pending-", tmpdir = dirname(path))
  on.exit(unlink(tmp), add = TRUE)
  saveRDS(x, tmp, version = 3, compress = FALSE)
  qg.assert(file.rename(tmp, path), "Atomic binary write failed")
}

qgs.vertex.key <- function(u) {
  u <- as.double(u)
  qg.assert(length(u) > 0L && all(is.finite(u)), "Invalid key coordinates")
  bytes <- c(writeBin(as.integer(length(u)), raw(), size = 4, endian = "big"),
             writeBin(u, raw(), size = 8, endian = "big"))
  paste(sprintf("%02x", as.integer(bytes)), collapse = "")
}

qgs.edge.key <- function(a, b) {
  keys <- c(qgs.vertex.key(a), qgs.vertex.key(b))
  order <- order(keys, method = "radix")
  list(key = paste(keys[order], collapse = ":"),
       from = as.double(if (order[1] == 1L) a else b),
       to = as.double(if (order[1] == 1L) b else a))
}

qgs.sum <- function(x) {
  total <- correction <- 0
  for (value in x) {
    next.total <- total + value
    correction <- correction + if (abs(total) >= abs(value)) {
      (total - next.total) + value
    } else (value - next.total) + total
    total <- next.total
  }
  total + correction
}

qgs.budget <- function(reason) stop(structure(list(message = reason, call = NULL),
  class = c("qgs_budget", "error", "condition")))

qgs.kernel <- function(a, b, forms, scale, tighter, poll, count) {
  h <- b - a
  if (all(h == 0)) return(list(length = 0, error_estimate = 0))
  alpha <- vapply(forms, function(A) 2 * sum(a * (A %*% h)), numeric(1))
  beta <- vapply(forms, function(A) 2 * sum(h * (A %*% h)), numeric(1))
  factor <- if (tighter) 0.01 else 1
  value <- stats::integrate(function(t) {
    poll(); count(length(t))
    vapply(t, function(tt) qg.norm(c(h, alpha + beta * tt)), numeric(1))
  }, 0, 1, subdivisions = 1000L, rel.tol = 1e-10 * factor, abs.tol = 1e-12 * scale * factor)
  list(length = value$value, error_estimate = value$abs.error)
}

qgs.control.v2 <- function(request, persist = function(event) NULL, restore = NULL,
                           capacity = 65536L, kernel = qgs.kernel, clock = qgs.clock,
                           persist.state = NULL) {
  qg.assert(qgs.scalar(capacity) && capacity >= 1 && capacity %% 1 == 0, "Invalid cache capacity")
  fingerprint <- digest::digest(request, algo = "sha256")
  start <- clock(); elapsed.offset <- 0
  limits <- request$limits; forms <- lapply(request$geometry$forms, qg.matrix)
  cache <- new.env(parent = emptyenv()); oldest <- newest <- NULL; size <- 0L
  counts <- list(edge_requests = 0L, cache_hits = 0L, cache_misses = 0L,
    edge_calls = 0L, integrand_evaluations = 0L, failure_hits = 0L, evictions = 0L,
    upgrades = 0L, commits = 0L)
  latest <- initializer <- NULL
  history <- list()
  checkpoints <- list(); checkpoint.index <- 1L
  budget <- request$budget
  if (is.null(budget)) budget <- list(metric = "edges", values = numeric())
  values <- as.double(unlist(budget$values))
  qg.assert(budget$metric %in% c("edges", "seconds") && all(is.finite(values)) &&
              all(values > 0) && !anyDuplicated(values) && !is.unsorted(values), "Invalid checkpoint grid")
  elapsed <- function() elapsed.offset + clock() - start
  stats <- function() c(counts, list(algorithm_seconds = elapsed(), cache_entries = size,
                                    cache_policy = "lru65536-levels01-v1"))
  value.now <- function() if (budget$metric == "edges") counts$edge_calls else elapsed()
  checkpoints.due <- function(inclusive = TRUE) {
    now <- value.now()
    while (checkpoint.index <= length(values) &&
           if (inclusive) values[checkpoint.index] <= now else values[checkpoint.index] < now) {
      checkpoints[[checkpoint.index]] <<- list(metric = budget$metric, budget = values[checkpoint.index],
        status = if (is.null(initializer)) "initializer_incomplete" else "observed",
        event = latest, observed_counters = stats())
      checkpoint.index <<- checkpoint.index + 1L
    }
  }
  poll <- function() {
    checkpoints.due(inclusive = budget$metric == "seconds")
    if (elapsed() >= limits$seconds) qgs.budget("time_budget")
    invisible(NULL)
  }
  detach <- function(node) {
    if (is.null(node$prev)) oldest <<- node$after else node$prev$after <- node$after
    if (is.null(node$after)) newest <<- node$prev else node$after$prev <- node$prev
  }
  touch <- function(node) {
    if (identical(node, newest)) return(invisible(NULL))
    detach(node); node$prev <- newest; node$after <- NULL
    if (is.null(newest)) oldest <<- node else newest$after <- node
    newest <<- node
  }
  insert <- function(key, records) {
    if (size >= capacity) {
      removed <- oldest; detach(removed); rm(list = removed$key, envir = cache)
      size <<- size - 1L; counts$evictions <<- counts$evictions + 1L
    }
    node <- new.env(parent = emptyenv())
    node$key <- key; node$records <- records; node$prev <- newest; node$after <- NULL
    if (is.null(newest)) oldest <<- node else newest$after <- node
    newest <<- node; assign(key, node, cache); size <<- size + 1L
    node
  }
  unwrap <- function(record) {
    if (record$status == "failed") stop(structure(list(message = record$diagnostic, call = NULL,
      record = record), class = c("qgs_edge_error", "error", "condition")))
    record$value
  }
  edge <- function(from, to, tighter = FALSE) {
    poll()
    qg.assert(is.logical(tighter) && length(tighter) == 1L && !is.na(tighter), "Invalid fidelity")
    a <- as.double(from); b <- as.double(to)
    qg.assert(length(a) == request$geometry$intrinsic_dim && length(b) == length(a) &&
      all(is.finite(c(a, b))) && qg.inside(a, request$domain) && qg.inside(b, request$domain),
      "Invalid connector endpoints")
    ordered <- qgs.edge.key(a, b); key <- ordered$key
    counts$edge_requests <<- counts$edge_requests + 1L
    level <- if (tighter) "level1" else "level0"
    node <- if (exists(key, cache, inherits = FALSE)) get(key, cache) else NULL
    if (!is.null(node)) {
      touch(node)
      record <- node$records[[level]]
      if (!tighter && identical(node$records$level1$status, "success")) record <- node$records$level1
      if (!is.null(record)) {
        counts$cache_hits <<- counts$cache_hits + 1L
        if (record$status == "failed") counts$failure_hits <<- counts$failure_hits + 1L
        return(unwrap(record))
      }
    }
    counts$cache_misses <<- counts$cache_misses + 1L
    if (counts$edge_calls >= limits$edge_calls) qgs.budget("edge_budget")
    checkpoints.due()
    counts$edge_calls <<- counts$edge_calls + 1L
    record <- tryCatch({
      result <- withCallingHandlers(kernel(ordered$from, ordered$to, forms, request$length_scale,
        tighter, poll, function(n) counts$integrand_evaluations <<- counts$integrand_evaluations + n),
        warning = function(w) stop(conditionMessage(w), call. = FALSE))
      qg.assert(qgs.scalar(result$length) && result$length >= 0 && qgs.scalar(result$error_estimate) &&
                  result$error_estimate >= 0, "Invalid integration result")
      qg.assert(all(a == b) || result$length > 0, "Zero connector length for distinct endpoints")
      list(status = "success", value = result)
    }, error = function(e) {
      if (inherits(e, "qgs_budget")) stop(e)
      list(status = "failed", diagnostic = conditionMessage(e))
    })
    poll()
    if (is.null(node)) node <- insert(key, list())
    if (level == "level1" && !is.null(node$records$level0)) counts$upgrades <<- counts$upgrades + 1L
    node$records[[level]] <- record
    unwrap(record)
  }
  batch <- function(edges, tighter = FALSE) {
    keys <- vapply(edges, function(e) qgs.edge.key(e$from, e$to)$key, "")
    indices <- order(keys, method = "radix"); indices <- indices[!duplicated(keys[indices])]
    answers <- list()
    for (i in indices) answers[[keys[i]]] <- tryCatch(edge(edges[[i]]$from, edges[[i]]$to, tighter),
      qgs_edge_error = function(e) e$record)
    answers
  }
  publish <- function(candidate, phase = "search", diagnostics = list()) {
    # Exclude earlier thresholds before publishing; equality at an edge count is eligible.
    checkpoints.due(inclusive = FALSE)
    if (elapsed() >= limits$seconds) qgs.budget("time_budget")
    qgs.check.candidate(candidate)
    if (candidate$path$kind == "lifted_segments") qgs.vertices(candidate, request, limits$max_vertices)
    qg.assert(qgs.string(phase) && is.list(diagnostics), "Invalid checkpoint metadata")
    event <- list(candidate = candidate, phase = phase, diagnostics = diagnostics,
      counters = c(counts, list(algorithm_seconds = elapsed())))
    event$counters$commits <- counts$commits + 1L
    persist(event)
    # The runner separately records the completed publication time after persistence.
    checkpoints.due(inclusive = FALSE)
    if (elapsed() >= limits$seconds) qgs.budget("time_budget")
    counts$commits <<- counts$commits + 1L
    event$counters <- stats(); latest <<- event
    history[[length(history) + 1L]] <<- event[c("candidate", "phase", "counters")]
    history[[length(history)]]$adapter <- diagnostics$algorithm_state[
      c("stage", "sweep", "pass", "accepted", "inserted", "deleted")]
    if (phase == "initializer" && is.null(initializer)) initializer <<- event
    invisible(event)
  }
  finish <- function(reason) {
    checkpoints.due()
    carry <- reason %in% c("initializer_complete", "schedule_exhausted", "identity")
    while (checkpoint.index <= length(values)) {
      checkpoints[[checkpoint.index]] <<- list(metric = budget$metric, budget = values[checkpoint.index],
        status = if (carry) "carried" else "censored", event = if (carry) latest else NULL,
        observed_counters = stats())
      checkpoint.index <<- checkpoint.index + 1L
    }
    checkpoints
  }
  snapshot <- function(adapter_state = NULL) {
    entries <- list(); node <- oldest
    while (!is.null(node)) {
      entries[[length(entries) + 1L]] <- list(key = node$key, records = node$records)
      node <- node$after
    }
    list(version = qgs.version, fingerprint = fingerprint, capacity = capacity,
      cache = entries, counts = counts, elapsed = elapsed(), latest = latest, initializer = initializer,
      checkpoints = checkpoints, checkpoint_index = checkpoint.index, history = history, adapter_state = adapter_state)
  }
  checkpoint <- function(state) {
    qg.assert(is.function(persist.state), "Durable state checkpoint sink is unavailable")
    qg.assert(is.list(state), "Algorithm checkpoint state must be a list")
    poll()
    # One atomic record binds algorithm state to the acknowledged path and LRU.
    persist.state(snapshot(state))
    poll()
    invisible(NULL)
  }
  capabilities <- function() list(
    cache_policy = if (capacity == 65536L) "lru65536-levels01-v1" else "test-capacity-override",
    edge_key = "u32be-f64be-v1", edge_failures = "qgs_edge_error-v1",
    checkpoint = if (is.function(persist.state)) "adaptive-state-v1" else "unavailable",
    interrupted_solver_resume = FALSE)
  if (!is.null(restore)) {
    qg.assert(identical(restore$version, qgs.version) && identical(restore$fingerprint, fingerprint) &&
                restore$capacity == capacity, "Snapshot configuration mismatch")
    for (entry in restore$cache) insert(entry$key, entry$records)
    counts <- restore$counts; elapsed.offset <- restore$elapsed
    latest <- restore$latest; initializer <- restore$initializer
    history <- restore$history
    checkpoints <- restore$checkpoints; checkpoint.index <- restore$checkpoint_index
    start <- clock()
  }
  list(edge = edge, batch = batch, poll = poll, publish = publish, stats = stats,
    latest = function() latest, initializer = function() initializer,
    finish = finish, checkpoints = function() checkpoints, snapshot = snapshot,
    checkpoint = checkpoint, capabilities = capabilities, history = function() history)
}

qgs.path.key <- function(candidate, request) {
  if (!identical(candidate$path$kind, "lifted_segments")) return(digest::digest(candidate$path, algo = "sha256"))
  U <- qgs.vertices(candidate, request, request$limits$max_vertices)
  paste(digest::digest(list(request$geometry, request$domain, "lifted_segments"), algo = "sha256"),
        paste(apply(U, 1, qgs.vertex.key), collapse = "/"), sep = ":")
}

qgs.audit.integrate <- function(candidate, request, consume = function() NULL) {
  qgs.check.candidate(candidate)
  if (candidate$path$kind != "lifted_segments") return(list(status = "representation_not_audited"))
  U <- qgs.vertices(candidate, request, request$limits$max_vertices)
  forms <- lapply(request$geometry$forms, qg.matrix)
  lengths <- errors <- numeric(nrow(U) - 1L); evaluations <- 0L
  for (i in seq_along(lengths)) {
    consume()
    delta <- U[i + 1L, ] - U[i, ]
    if (all(delta == 0)) next
    fit <- stats::integrate(function(t) {
      evaluations <<- evaluations + length(t)
      vapply(t, function(tt) {
        u <- U[i, ] + tt * delta
        tangent <- c(delta, vapply(forms, function(A) 2 * sum((A %*% u) * delta), numeric(1)))
        qg.norm(tangent)
      }, numeric(1))
    }, 0, 1, subdivisions = 1000L, rel.tol = 1e-12, abs.tol = 1e-14 * request$length_scale)
    lengths[i] <- fit$value; errors[i] <- fit$abs.error
  }
  qg.assert(all(is.finite(c(lengths, errors))) && all(c(lengths, errors) >= 0), "Invalid audit integration")
  list(status = "integrated", length = qgs.sum(lengths), error_estimate = qgs.sum(errors),
    segments = length(lengths), feasibility = "entire_lifted_segments_in_convex_domain",
    edge_calls = length(lengths), integrand_evaluations = evaluations, rigorous = FALSE)
}

qgs.audit.compare <- function(integrated, candidate, request) {
  if (!identical(integrated$status, "integrated")) return(integrated)
  qgs.check.candidate(candidate)
  allowance <- 64 * .Machine$double.eps * (integrated$segments + 1) *
    max(request$length_scale, integrated$length, candidate$length)
  margin <- candidate$error_estimate + integrated$error_estimate + allowance
  identity <- all(unlist(request$from) == unlist(request$to))
  integrated$status <- if (abs(integrated$length - candidate$length) <= margin &&
    (if (identity) integrated$length == 0 && candidate$length == 0 else
      integrated$length > 0 && candidate$length > 0)) "passed" else "length_mismatch"
  c(integrated, list(reported_length = candidate$length, discrepancy = integrated$length - candidate$length,
                    rounding_allowance = allowance, agreement_margin = margin))
}

qgs.audit.v2 <- function(candidate, request) {
  start <- qgs.clock()
  result <- qgs.audit.compare(qgs.audit.integrate(candidate, request), candidate, request)
  result$elapsed_seconds <- qgs.clock() - start
  result
}

qgs.audit.queue <- function(targets, request, seconds = 10, calls = 4096L,
                            persist = function(answers) NULL) {
  start <- qgs.clock(); used <- 0L; answers <- list(); seen <- new.env(parent = emptyenv())
  consume <- function() {
    if (used >= calls || qgs.clock() - start >= seconds) qgs.budget("audit_unavailable_budget")
    used <<- used + 1L
  }
  for (label in names(targets)) {
    candidate <- targets[[label]]
    if (is.null(candidate)) { answers[[label]] <- list(status = "missing_target"); next }
    feasibility <- NULL
    result <- tryCatch({
      if (qgs.clock() - start >= seconds) qgs.budget("audit_unavailable_budget")
      key <- qgs.path.key(candidate, request)
      if (candidate$path$kind == "lifted_segments") feasibility <- "entire_lifted_segments_in_convex_domain"
      if (exists(key, seen, inherits = FALSE)) integral <- get(key, seen)
      else {
        integral <- qgs.audit.integrate(candidate, request, consume)
        if (qgs.clock() - start >= seconds) qgs.budget("audit_unavailable_budget")
        assign(key, integral, seen)
      }
      qgs.audit.compare(integral, candidate, request)
    }, error = function(e) {
      list(status = if (inherits(e, "qgs_budget")) "audit_unavailable_budget" else
        if (is.null(feasibility)) "invalid_path" else "integration_failure",
        feasibility = feasibility, diagnostic = conditionMessage(e))
    })
    result$audit_calls_so_far <- used
    answers[[label]] <- result
    persist(answers)
  }
  answers
}
