#' Create a Standard Graph
#'
#' Construct a standard topology or a simple geometric graph. All types return
#' a [dgraph()] and use compact, 1-based adjacency indices. `type` is required;
#' type names and names in `...` must match exactly.
#'
#' @param type Graph type: `"empty"`, `"complete"`, `"chain"`, `"cycle"`,
#'   `"complete_bipartite"`, `"star"`, `"random"` or `"circle"`.
#' @param n Number of vertices. Required except when inferred from chain `x`,
#'   bipartite `sizes` or star `arms`. If supplied alongside those arguments,
#'   it must agree. Empty graphs permit zero vertices; chains require at least
#'   two, cycles and circles at least three, and other types at least one.
#' @param ... Named type-specific arguments, described below. Unknown,
#'   duplicated, unnamed and irrelevant arguments error.
#' @param labels Optional unique, nonmissing character or numeric vertex labels,
#'   one per vertex. Labels name adjacency lists and are stored in
#'   `metadata$labels`; they never change adjacency indices. For chains with
#'   `x`, supply labels in the original input order.
#'
#' @section Types and arguments:
#' \describe{
#'   \item{`empty`, `complete`, `cycle`}{Only `n` and `labels`. These return
#'     topology without stored lengths. A cycle closes a chain with one edge.}
#'   \item{`chain`}{`span = 1` connects up to `span` positions on each side,
#'     giving at most `2 * span` neighbors. It must be an integer from 1 to
#'     `n - 1`; it does not use the nearest-neighbor meaning of `k`.
#'     Optional finite numeric `x` orders vertices by coordinate (ties by input
#'     position) and supplies absolute coordinate differences as lengths.
#'     Without `x`, lengths are one. Optional vector `y` requires `x` and is
#'     reordered with it. Metadata contains `order` (sorted-to-input indices),
#'     `x.sorted` and `y.sorted`.}
#'   \item{`complete_bipartite`}{Required `sizes`, two positive integers.
#'     All pairs across the two parts are connected; there are no within-part
#'     edges or stored lengths. Vertices in the first part come first.}
#'   \item{`star`}{Required `arms`, at least two positive integer edge counts.
#'     Chains of those lengths share vertex 1 as their center. Thus
#'     `n = 1 + sum(arms)`; all-one arms give an ordinary star. Vertices are
#'     numbered along successive arms. No lengths are stored.}
#'   \item{`circle`}{`sampling = "uniform"` or `"random"` (default),
#'     `edge.length = "arc"` (default) or `"chord"`, and optional `seed`.
#'     Vertices are ordered by angle on the unit circle and consecutive
#'     vertices, including last-to-first, are connected. Arc lengths measure
#'     the shorter unit-circle arc between endpoints, even when the gap in
#'     the sampling order exceeds pi. Chords are Euclidean distances.
#'     Metadata contains `angles` (radians) and `coordinates` (x/y columns).}
#'   \item{`random`}{Required finite `mean.degree`, `connected = TRUE`, and
#'     optional `seed`. The edge count is `floor(n * mean.degree / 2)`;
#'     `0 <= mean.degree <= n - 1`. If connected, this count must be at least
#'     `n - 1`. A randomly ordered growing tree is built first, then a uniform
#'     subset of remaining pairs is added. This is not uniform sampling over
#'     connected graphs or spanning trees. If disconnected graphs are allowed,
#'     a uniform subset of all pairs is sampled. Each undirected edge receives
#'     one independent length uniform between 0.5 and 1.5. Candidate-pair storage is
#'     quadratic in `n`; this constructor is intended for small examples.
#'     Metadata records requested and realized mean degrees and connectivity.}
#' }
#'
#' @section Random numbers:
#' For `random` and `circle`, `seed = NULL` uses and advances the caller's
#' current random stream. An explicit nonnegative integer seed makes the call
#' reproducible under the current RNG kind and restores the caller's RNG state
#' afterwards, including an initially absent state. Uniform circle sampling
#' consumes no random numbers. The richer geometry sampling API has its own
#' seed/state continuation contract; see [sample.synthetic.geometry()].
#'
#' @return A `dgraph` with one `final` stage and construction information in
#'   `metadata`, including `type`. Inspect it with [graph.adjacency()],
#'   [graph.lengths()], [graph.edges()] and [graph.order()].
#' @examples
#' graph.order(create.graph("empty", n = 4))
#' graph.edges(create.graph("complete", n = 3))
#' chain <- create.graph("chain", x = c(3, 1, 2), span = 1,
#'                       labels = c("third", "first", "second"))
#' graph.adjacency(chain)
#' graph.lengths(chain)
#' graph.edges(create.graph("cycle", n = 4))
#' graph.order(create.graph("complete_bipartite", sizes = c(2, 3)))
#' graph.order(create.graph("star", arms = c(2, 3, 1)))
#' graph.edges(create.graph("random", n = 6, mean.degree = 2, seed = 10))
#' circle <- create.graph("circle", n = 8, sampling = "uniform",
#'                        edge.length = "chord")
#' circle$metadata$coordinates
#' @export
create.graph <- function(type, n = NULL, ..., labels = NULL) {
    choices <- c("empty", "complete", "chain", "cycle", "complete_bipartite",
                 "star", "random", "circle")
    type <- .graph.choice(type, choices, "type")
    args <- list(...)
    allowed <- switch(type, chain = c("span", "x", "y"),
        complete_bipartite = "sizes", star = "arms",
        random = c("mean.degree", "connected", "seed"),
        circle = c("sampling", "edge.length", "seed"), character())
    if (length(args) && (is.null(names(args)) || anyNA(names(args)) ||
        any(!nzchar(names(args))) || anyDuplicated(names(args))))
        stop("Type-specific arguments must have unique, nonempty names.", call. = FALSE)
    unknown <- setdiff(names(args), allowed)
    if (length(unknown)) stop("Unsupported argument(s) for type '", type, "': ",
                             paste(unknown, collapse = ", "), call. = FALSE)
    if (!is.null(n)) .graph.integer(n, "n", 0)
    inferred <- switch(type,
        chain = if (!is.null(args$x)) length(args$x),
        complete_bipartite = {
            .graph.sizes(args$sizes, "sizes", exactly.two = TRUE)
            sum(args$sizes)
        },
        star = {
            .graph.sizes(args$arms, "arms")
            1 + sum(args$arms)
        }, NULL)
    if (!is.null(inferred)) {
        if (!is.null(n) && n != inferred)
            stop("'n' conflicts with the size inferred from type-specific arguments.", call. = FALSE)
        n <- inferred
    }
    minimum <- switch(type, empty = 0, chain = 2, cycle = 3, circle = 3, 1)
    n <- .graph.integer(n, "n", minimum)
    if (!is.null(labels) && (!is.atomic(labels) || !is.null(dim(labels)) ||
        !(is.character(labels) || is.numeric(labels)) || length(labels) != n ||
        anyNA(labels) || any(!nzchar(as.character(labels))) ||
        anyDuplicated(as.character(labels)) ||
        (is.numeric(labels) && any(!is.finite(labels)))))
        stop("'labels' must contain one unique, nonmissing, nonempty label per vertex.", call. = FALSE)
    graph <- switch(type,
        empty = dgraph(rep(list(integer()), n)),
        complete = dgraph(lapply(seq_len(n), function(i) setdiff(seq_len(n), i))),
        cycle = dgraph(.graph.cycle.adjacency(n)),
        chain = do.call(.graph.chain, c(list(n = n), args)),
        complete_bipartite = {
            a <- seq_len(args$sizes[1L]); b <- seq.int(length(a) + 1L, n)
            dgraph(c(rep(list(b), length(a)), rep(list(a), length(b))))
        },
        star = .graph.star(args$arms),
        circle = do.call(.graph.circle, c(list(n = n), args)),
        random = do.call(.graph.random, c(list(n = n), args)))
    graph$metadata$type <- type
    if (type == "complete_bipartite") graph$metadata$sizes <- as.integer(args$sizes)
    if (type == "star") graph$metadata$arms <- as.integer(args$arms)
    if (!is.null(labels)) {
        if (type == "chain") labels <- labels[graph$metadata$order]
        names(graph$stages$final$adj.list) <- as.character(labels)
        if (!is.null(graph$stages$final$length.list))
            names(graph$stages$final$length.list) <- as.character(labels)
        graph$metadata$labels <- labels
    }
    graph
}

.graph.choice <- function(value, choices, name) {
    if (!is.character(value) || length(value) != 1L || is.na(value) || !value %in% choices)
        stop("'", name, "' must be one of: ", paste(choices, collapse = ", "), ".", call. = FALSE)
    value
}

.graph.integer <- function(value, name, minimum = 0) {
    if (!is.numeric(value) || !is.null(dim(value)) || length(value) != 1L || !is.finite(value) ||
        value != floor(value) || value < minimum || value > .Machine$integer.max)
        stop("'", name, "' must be an integer >= ", minimum, " and <= ",
             .Machine$integer.max, ".", call. = FALSE)
    as.integer(value)
}

.graph.sizes <- function(value, name, exactly.two = FALSE) {
    if (!is.numeric(value) || !is.null(dim(value)) || length(value) < 2L ||
        (exactly.two && length(value) != 2L) || any(!is.finite(value)) ||
        any(value != floor(value)) || any(value < 1) || sum(value) >= .Machine$integer.max)
        stop("'", name, "' must contain ", if (exactly.two) "exactly" else "at least",
             " two positive integers with a representable total size.", call. = FALSE)
}

.graph.cycle.adjacency <- function(n) {
    lapply(seq_len(n), function(i) as.integer(c(if (i == 1L) n else i - 1L,
                                               if (i == n) 1L else i + 1L)))
}

.graph.chain <- function(n, span = 1, x = NULL, y = NULL) {
    span <- .graph.integer(span, "span", 1)
    if (span >= n) stop("'span' must be less than n.", call. = FALSE)
    if (!is.null(x) && (!is.numeric(x) || !is.null(dim(x)) || any(!is.finite(x))))
        stop("'x' must be a finite numeric vector.", call. = FALSE)
    if (!is.null(y) && (is.null(x) || !is.atomic(y) || !is.null(dim(y)) || length(y) != n))
        stop("'y' requires 'x' and must be a vector of the same length.", call. = FALSE)
    order <- if (is.null(x)) seq_len(n) else order(x, seq_len(n))
    x <- if (!is.null(x)) x[order]
    adj <- lapply(seq_len(n), function(i) setdiff(seq.int(max(1, i - span), min(n, i + span)), i))
    lens <- lapply(seq_len(n), function(i) if (is.null(x)) rep(1, length(adj[[i]])) else abs(x[i] - x[adj[[i]]]))
    out <- dgraph(adj, lens)
    out$metadata <- list(span = span, order = order, x.sorted = x,
                         y.sorted = if (!is.null(y)) y[order])
    out
}

.graph.star <- function(arms) {
    n <- 1L + sum(arms)
    adj <- rep(list(integer()), n)
    last <- 1L
    for (size in arms) {
        vertices <- c(1L, seq.int(last + 1L, last + size))
        for (i in seq_len(size)) {
            a <- vertices[i]; b <- vertices[i + 1L]
            adj[[a]] <- c(adj[[a]], b); adj[[b]] <- c(adj[[b]], a)
        }
        last <- last + size
    }
    dgraph(adj)
}

.graph.with.seed <- function(seed, code) {
    if (!is.null(seed)) {
        seed <- .graph.integer(seed, "seed")
        had.seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
        if (had.seed) saved <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
        on.exit({
            if (had.seed) assign(".Random.seed", saved, envir = .GlobalEnv)
            else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
                rm(".Random.seed", envir = .GlobalEnv)
        }, add = TRUE)
        set.seed(seed)
    }
    force(code)
}

.graph.circle <- function(n, sampling = "random", edge.length = "arc", seed = NULL) {
    sampling <- .graph.choice(sampling, c("uniform", "random"), "sampling")
    edge.length <- .graph.choice(edge.length, c("arc", "chord"), "edge.length")
    angles <- .graph.with.seed(seed, if (sampling == "uniform")
        2 * pi * (seq_len(n) - 1) / n else sort(stats::runif(n, 0, 2 * pi)))
    adj <- .graph.cycle.adjacency(n)
    lens <- lapply(seq_len(n), function(i) {
        gap <- abs(angles[i] - angles[adj[[i]]])
        arc <- pmin(gap, 2 * pi - gap)
        if (edge.length == "arc") arc else 2 * sin(arc / 2)
    })
    out <- dgraph(adj, lens)
    out$metadata <- list(sampling = sampling, edge.length = edge.length,
        angles = angles, coordinates = cbind(x = cos(angles), y = sin(angles)))
    out
}

.graph.random <- function(n, mean.degree, connected = TRUE, seed = NULL) {
    if (!is.numeric(mean.degree) || length(mean.degree) != 1L || !is.finite(mean.degree) ||
        mean.degree < 0 || mean.degree > n - 1L)
        stop("'mean.degree' must be finite and between 0 and n - 1.", call. = FALSE)
    if (!is.logical(connected) || length(connected) != 1L || is.na(connected))
        stop("'connected' must be TRUE or FALSE.", call. = FALSE)
    m <- floor(n * mean.degree / 2)
    if (connected && m < n - 1L)
        stop("Requested mean.degree gives fewer than n - 1 edges; connectivity is impossible.", call. = FALSE)
    .graph.with.seed(seed, {
        edges <- matrix(integer(), ncol = 2)
        if (connected && n > 1L) {
            vertices <- sample.int(n)
            for (i in seq.int(2L, n)) {
                pair <- sort(c(vertices[i], vertices[sample.int(i - 1L, 1L)]))
                edges <- rbind(edges, pair)
            }
        }
        if (m > nrow(edges)) {
            pairs <- t(utils::combn(seq_len(n), 2L))
            key <- function(e) paste(e[, 1L], e[, 2L], sep = ":")
            pairs <- pairs[!key(pairs) %in% key(edges), , drop = FALSE]
            edges <- rbind(edges, pairs[sample.int(nrow(pairs), m - nrow(edges)), , drop = FALSE])
        }
        adj <- rep(list(integer()), n); lens <- rep(list(numeric()), n)
        values <- stats::runif(nrow(edges), 0.5, 1.5)
        for (i in seq_len(nrow(edges))) {
            a <- edges[i, 1L]; b <- edges[i, 2L]
            adj[[a]] <- c(adj[[a]], b); lens[[a]] <- c(lens[[a]], values[i])
            adj[[b]] <- c(adj[[b]], a); lens[[b]] <- c(lens[[b]], values[i])
        }
        out <- dgraph(adj, lens)
        out$metadata <- list(mean.degree = mean.degree, realized.mean.degree = 2 * m / n,
                             connected = connected)
        out
    })
}
