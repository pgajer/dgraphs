# Development-only adapter contract. Source the frozen collection helpers first.
qgs.version <- "0.3.2"
qgs.home <- local({
  paths <- vapply(sys.frames(), function(frame) {
    p <- get0("ofile", envir = frame, inherits = FALSE)
    if (is.character(p) && length(p) == 1L) p else ""
  }, "")
  dirname(normalizePath(tail(paths[nzchar(paths)], 1), mustWork = TRUE))
})
qgs.scalar <- function(x) is.numeric(x) && length(x) == 1L && is.finite(x)
qgs.string <- function(x) is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
qgs.clock <- function() unname(proc.time()[["elapsed"]])

qgs.parameters <- function(x) {
  qg.assert(is.list(x) && (length(x) == 0L ||
              (length(names(x)) == length(x) && all(nzchar(names(x))) && !anyDuplicated(names(x)))),
            "Parameters must be a named list/JSON object")
  if (!length(x)) names(x) <- character(0)
  x
}

qgs.write <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(".pending-", tmpdir = dirname(path))
  on.exit(unlink(tmp), add = TRUE)
  jsonlite::write_json(x, tmp, auto_unbox = TRUE, pretty = TRUE, digits = NA,
                       null = "null", na = "null", matrix = "rowmajor")
  qg.assert(file.rename(tmp, path), paste("Atomic write failed:", path))
}

qgs.limits <- function(x = list()) {
  defaults <- list(edge_calls = 200000L, seconds = 120, max_vertices = 257L, rss_mib = 512)
  qg.assert(is.list(x) && all(names(x) %in% names(defaults)) &&
              !anyDuplicated(names(x)) && (length(x) == 0L || length(names(x)) == length(x)),
            "Unknown or unnamed limits")
  defaults[names(x)] <- x
  qg.assert(all(vapply(defaults, function(v) qgs.scalar(v) && v > 0, logical(1))) &&
              defaults$edge_calls %% 1 == 0 && defaults$max_vertices %% 1 == 0 &&
              defaults$max_vertices >= 2, "Invalid resource limits")
  defaults
}

qgs.request <- function(collection, case_id, pair_id, direction = "forward",
                        repeat_label = "4101", parameters = list(), limits = list()) {
  qg.assert(direction %in% c("forward", "reverse") && length(direction) == 1L,
            "Invalid direction")
  qg.assert(qgs.string(repeat_label) && grepl("^(0|[1-9][0-9]*)$", repeat_label), "Invalid repeat label")
  parameters <- qgs.parameters(parameters)
  case <- collection$cases[[match(case_id, vapply(collection$cases, `[[`, "", "id"))]]
  qg.assert(!is.null(case), "Unknown case")
  pair <- case$pairs[[match(pair_id, vapply(case$pairs, `[[`, "", "id"))]]
  qg.assert(!is.null(pair), "Unknown pair")
  u <- as.double(unlist(pair$from)); v <- as.double(unlist(pair$to))
  if (direction == "reverse") { swap <- u; u <- v; v <- swap }
  seed.text <- paste("qg-refine-v1", attr(collection, "sha256"), case_id, pair_id,
                     direction, repeat_label, sep = "|")
  seed <- digest::digest(seed.text, algo = "sha256", serialize = FALSE)
  # No analytic answers or reference bounds are passed to an adapter.
  list(interface_version = qgs.version, collection_sha256 = attr(collection, "sha256"),
       case_id = case_id, pair_id = pair_id, direction = direction,
       repeat_label = repeat_label, seed_digest = seed, seed_hex = substr(seed, 1, 16),
       geometry = case$geometry, domain = case$domain, length_scale = case$length_scale,
       from = u, to = v, parameters = parameters, limits = qgs.limits(limits))
}

qgs.adapter <- function(id, supports, prepare, solve, inspect = NULL) {
  qg.assert(qgs.string(id) && grepl("^[a-z][a-z0-9_]*$", id) &&
              all(vapply(list(supports, prepare, solve), is.function, logical(1))),
            "Invalid adapter")
  qg.assert(is.null(inspect) || is.function(inspect), "Invalid state inspector")
  list(interface_version = qgs.version, id = id, supports = supports,
       prepare = prepare, solve = solve, inspect = inspect)
}

qgs.check.candidate <- function(candidate) {
  qg.assert(is.list(candidate) && qgs.scalar(candidate$length) && candidate$length >= 0 &&
              qgs.scalar(candidate$error_estimate) && candidate$error_estimate >= 0,
            "Candidate needs a finite nonnegative length and error estimate")
  qg.assert(is.list(candidate$path) && qgs.string(candidate$path$kind) &&
              candidate$path$kind %in% c("lifted_segments", "native", "distance_only"),
            "Unknown path representation")
  if (candidate$path$kind == "native") qg.assert(qgs.string(candidate$path$format) &&
      !is.null(candidate$path$data), "Native path needs format and data")
  invisible(TRUE)
}

qgs.vertices <- function(candidate, request, max_vertices = Inf) {
  qgs.check.candidate(candidate)
  qg.assert(is.list(candidate$path) && identical(candidate$path$kind, "lifted_segments"),
            "Path representation is not lifted_segments")
  raw <- candidate$path$vertices
  U <- if (is.matrix(raw)) raw else qg.matrix(raw)
  qg.assert(is.numeric(U) && ncol(U) == request$geometry$intrinsic_dim &&
              nrow(U) >= 2L && nrow(U) <= max_vertices && all(is.finite(U)),
            "Invalid path dimensions or vertices")
  qg.assert(all(U[1, ] == unlist(request$from)) &&
              all(U[nrow(U), ] == unlist(request$to)), "Path endpoints differ from query")
  qg.assert(all(apply(U, 1, qg.inside, domain = request$domain)),
            "Path leaves declared domain")
  # Convex domains certify entire lifted segments, not arbitrary interpolants.
  U
}

qgs.candidate <- function(vertices, length, error_estimate = 0) {
  list(length = length, error_estimate = error_estimate,
       path = list(kind = "lifted_segments", vertices = vertices))
}

qgs.control <- function(request, persist = function(event) NULL, restore = NULL, persist.state = NULL) {
  qgs.control.v2(request, persist, restore, persist.state = persist.state)
}

qgs.execute <- function(adapter, request, persist = function(event) NULL, persist.state = NULL) {
  qg.assert(identical(adapter$interface_version, qgs.version) &&
              identical(request$interface_version, qgs.version), "Interface version mismatch")
  control <- qgs.control(request, persist, persist.state = persist.state)
  state <- NULL
  prepare.seconds <- solve.seconds <- 0
  phase <- "supports"
  result <- tryCatch({
    support <- adapter$supports(request)
    qg.assert(is.list(support) && is.logical(support$supported) &&
                length(support$supported) == 1 && !is.na(support$supported) &&
                qgs.string(support$reason), "Malformed applicability response")
    if (!support$supported) list(status = "unsupported", termination = support$reason)
    else {
      phase <- "prepare"; t <- qgs.clock()
      state <- tryCatch(adapter$prepare(request, control),
                        finally = { prepare.seconds <- qgs.clock() - t })
      phase <- "solve"; t <- qgs.clock()
      answer <- tryCatch(adapter$solve(state, request, control),
                         finally = { solve.seconds <- qgs.clock() - t })
      qg.assert(is.list(answer) && answer$status %in% c("candidate", "failed", "unsupported") &&
                  qgs.string(answer$termination), "Malformed solve response")
      if (answer$status == "candidate") {
        qg.assert(!is.null(control$latest()), "Candidate result has no published path")
      }
      answer
    }
  }, qgs_budget = function(e) list(status = if (is.null(control$latest())) "failed" else "candidate",
                                  termination = conditionMessage(e)),
     error = function(e) list(status = "failed", termination = paste0(phase, "_error"),
                              diagnostic = conditionMessage(e)))
  result$checkpoints <- control$finish(result$termination)
  result$initializer <- control$initializer()
  result$incumbent <- control$latest()
  result$history <- control$history()
  if (!is.null(state) && is.function(adapter$inspect)) {
    result$adapter_state <- tryCatch(adapter$inspect(state), error = function(e)
      list(inspection_error = conditionMessage(e)))
  }
  result$counters <- control$stats()
  result$prepare_seconds <- prepare.seconds
  result$solve_seconds <- solve.seconds
  result
}

qgs.audit <- function(candidate, request) qgs.audit.v2(candidate, request)

source(file.path(qgs.home, "runtime.R"), local = environment())
