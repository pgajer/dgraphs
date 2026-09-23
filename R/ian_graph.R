#' Experimental Internal IAN Adapter
#'
#' The unexported adapter requires the separately built optional backend. Its
#' unchanged default, `IAN evaluated-LP 1.0`, uses strict numerical acceptance
#' without retries. The explicit experimental option
#' `IAN evaluated-LP retry-power 0.1` uses shared-power constraint arithmetic and
#' at most one normalized retry after an eligible rejected return. The retry must
#' return strict solver success and pass the unchanged original-unit checks; the
#' original rejected result is never accepted directly. This candidate has not
#' been adopted as the default. It has independent bounded qualification on
#' macOS arm64 and is selected explicitly for internal qualification studies.
#' See `system.file("ian", "README.md", package = "dgraphs")` for build and
#' numerical limitations. Input rows are specimens; graph vertices are unique
#' feature profiles in first-occurrence order.
#'
#' @param X Finite numeric specimen-by-feature matrix, at least one column.
#' @param distances Optional unsquared distance matrix or `dist`. When absent,
#'   Euclidean distances are computed with `stats::dist(X)`. Supplied distances
#'   are used exactly; duplicate feature rows must have identical distance rows.
#'   Coordinates are always required to define duplicate profiles. Row/column
#'   order must match X; named distances must match specimen IDs.
#' @param specimen.ids Unique nonempty IDs; defaults to row names or row numbers.
#' @param participant.ids Optional specimen-level nonempty IDs, possibly repeated.
#' @param graph Reserved supplied-graph argument; currently must be `NULL`.
#'   The actual initial Gabriel graph is always constructed by IAN.
#' @param diagnostics `"summary"` or `"full"`; full includes dense LP payloads.
#' @param backend Optional path to the separately built `dgraphs_ian.so` module.
#' @param numerical.policy Exactly `"IAN evaluated-LP 1.0"` (strict default) or
#'   `"IAN evaluated-LP retry-power 0.1"` (explicit experimental candidate).
#' @param max.solves Positive integer safety limit; reaching it returns refusal.
#' @return A list with `complete`, structured `error`, initial Gabriel graph,
#'   `final_graph` only on full completion, `last_valid_graph` (possibly partial),
#'   profile mapping, local scales and an affinity matrix distinct from metric
#'   edge lengths. Graph indices and mappings are one-based. Full traces retain
#'   original zero-based core indices and declare this in diagnostics. Summary diagnostics
#'   include per-solve status, acceptance, settings, residuals and iteration counts.
#'   Refusal and interruption return incomplete structured results; invalid R
#'   arguments error before native execution. Interrupts are checked at engine
#'   events; they do not interrupt an active solver call.
#' @keywords internal
create.ian.graph <- function(X, distances = NULL, specimen.ids = NULL,
                             participant.ids = NULL, graph = NULL,
                             diagnostics = c("summary", "full"), backend = NULL,
                             max.solves = 10000L, numerical.policy = "IAN evaluated-LP 1.0") {
    .ian.adapter(X, distances, specimen.ids, participant.ids, graph,
                 match.arg(diagnostics), backend, max.solves, "none", numerical.policy)
}

.ian.backend <- local({
    cache <- new.env(parent = emptyenv())
    function(path) {
        if (is.null(path)) path <- system.file("ian", "native", "dgraphs_ian.so", package = "dgraphs")
        if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path) || !file.exists(path))
            stop("IAN optional backend is unavailable. Build it using the installed ian/build_backend.py helper; see ian/README.md.", call. = FALSE)
        path <- normalizePath(path, mustWork = TRUE)
        if (!exists(path, cache, inherits = FALSE)) {
            dll <- dyn.load(path, local = TRUE)
            assign(path, list(dll = dll, run = getNativeSymbolInfo("dgraphs_ian_run", dll)$address), cache)
        }
        get(path, cache, inherits = FALSE)$run
    }
})

.ian.graph <- function(raw, ids, stage, policy = "IAN evaluated-LP 1.0") {
    if (is.null(raw)) return(NULL)
    n <- length(ids)
    adj <- rep(list(integer()), n); lens <- rep(list(numeric()), n)
    for (k in seq_len(nrow(raw$edges))) {
        i <- raw$edges[k, 1L]; j <- raw$edges[k, 2L]
        adj[[i]] <- c(adj[[i]], j); adj[[j]] <- c(adj[[j]], i)
        lens[[i]] <- c(lens[[i]], raw$lengths[k]); lens[[j]] <- c(lens[[j]], raw$lengths[k])
    }
    out <- dgraph(adj, lens)
    out$metadata <- list(method = policy, ian_stage = stage,
                         profile_ids = ids, edge_length_units = "input distances")
    out
}

.ian.adapter <- function(X, distances, specimen.ids, participant.ids, graph,
                         diagnostics, backend, max.solves, fault, numerical.policy = "IAN evaluated-LP 1.0") {
    if (!is.character(numerical.policy) || length(numerical.policy) != 1L || is.na(numerical.policy) || !numerical.policy %in% c("IAN evaluated-LP 1.0", "IAN evaluated-LP retry-power 0.1")) stop("Unsupported numerical.policy.", call. = FALSE)
    if (!is.null(graph)) stop("Supplied initial graphs are unsupported; IAN constructs its Gabriel graph from distances.", call. = FALSE)
    if (!is.matrix(X) || !is.numeric(X) || nrow(X) < 2L || nrow(X) > 500L || ncol(X) < 1L || any(!is.finite(X)))
        stop("X must be a finite numeric matrix with 2 to 500 specimen rows and at least one feature.", call. = FALSE)
    storage.mode(X) <- "double"
    n <- nrow(X)
    if (is.null(specimen.ids)) specimen.ids <- if (is.null(rownames(X))) as.character(seq_len(n)) else rownames(X)
    valid.ids <- function(x) is.character(x) && length(x) == n && !anyNA(x) && all(nzchar(x))
    if (!valid.ids(specimen.ids) || anyDuplicated(specimen.ids)) stop("specimen.ids must be unique nonempty strings, one per row.", call. = FALSE)
    if (is.null(participant.ids)) participant.ids <- character()
    if (length(participant.ids) && !valid.ids(participant.ids)) stop("participant.ids must be nonempty strings, one per specimen.", call. = FALSE)
    if (!is.numeric(max.solves) || length(max.solves) != 1L || !is.finite(max.solves) || max.solves < 1 || max.solves != trunc(max.solves) || max.solves > 10000)
        stop("max.solves must be an integer from 1 to 10000.", call. = FALSE)
    input.mode <- if (is.null(distances)) "Euclidean distances computed in R" else "supplied unsquared distances"
    if (is.null(distances)) distances <- as.matrix(stats::dist(X)) else if (inherits(distances, "dist")) distances <- as.matrix(distances)
    if (!is.matrix(distances) || !is.numeric(distances) || !identical(dim(distances), c(n, n)) || any(!is.finite(distances)) || any(distances < 0) || any(diag(distances) != 0) || !all(distances == t(distances)))
        stop("distances must be a finite, nonnegative, exactly symmetric n by n matrix with zero diagonal.", call. = FALSE)
    if (input.mode == "supplied unsquared distances") for (labels in dimnames(distances))
        if (!is.null(labels) && !identical(labels, specimen.ids)) stop("Named distances must match specimen.ids in order.", call. = FALSE)
    storage.mode(distances) <- "double"
    native_run <- .ian.backend(backend)
    raw <- .Call(native_run, X, distances, specimen.ids, participant.ids,
                 identical(diagnostics, "full"), as.integer(max.solves), fault, numerical.policy)
    ids <- raw$mapping$profile_ids
    initial <- .ian.graph(raw$initial, ids, "initial Gabriel", raw$backend$numerical_policy)
    last <- .ian.graph(raw$last, ids, "last valid, possibly partial", raw$backend$numerical_policy)
    final <- if (isTRUE(raw$complete)) .ian.graph(raw$converged, ids, "completed final", raw$backend$numerical_policy) else NULL
    if (isTRUE(raw$diagnostics$affinity_valid)) dimnames(raw$affinity) <- list(ids, ids)
    raw$diagnostics$trace_index_base <- 0L
    raw$diagnostics$trace_format <- "schema-1 core fields; zero-based indices"
    raw$diagnostics$input_mode <- input.mode
    raw$diagnostics$requested_max_solves <- as.integer(max.solves)
    list(complete = raw$complete, error = raw$error, initial_graph = initial,
         final_graph = final, last_valid_graph = last, mapping = raw$mapping,
         scales = stats::setNames(raw$scales, if (length(raw$scales)) ids else character()),
         affinity = if (isTRUE(raw$diagnostics$affinity_valid)) raw$affinity else NULL,
         diagnostics = raw$diagnostics, backend = raw$backend)
}
