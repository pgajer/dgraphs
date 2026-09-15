elapsed.time <- function(start.time,
                         message = "DONE",
                         with.brackets = TRUE) {
    elapsed <- as.numeric(proc.time() - start.time)[3]
    minutes <- floor(elapsed / 60)
    seconds <- floor(elapsed %% 60)

    time.str <- sprintf("%d:%02d", minutes, seconds)

    if (with.brackets) {
        output <- sprintf("%s (%s)", message, time.str)
    } else {
        output <- sprintf("%s %s", message, time.str)
    }

    cat(output, "\n")
}

#' Embed Graph in 2D or 3D Space
#'
#' @param graph A `dgraph` object.
#' @param edge.attribute Explicit edge quantity, such as `"length"` or
#'   `"conductance"`; `NULL` uses an unweighted layout.
#' @param transform Use selected values directly (`"identity"`) or their
#'   reciprocals (`"reciprocal"`). Selected values must be strictly positive.
#'   Fruchterman-Reingold treats larger values as stronger attraction, whereas
#'   Kamada-Kawai uses them as distances.
#' @param dim Embedding dimension, either `2` or `3`.
#' @param method Layout method, `"fr"` or `"kk"`.
#' @param verbose Logical; print timing messages.
#' @param stage Stored graph stage used for both topology and edge attributes.
#'
#' @return Numeric layout matrix with one row per embedded vertex.
#'
#' @examples
#' set.seed(1)
#' graph <- create.graph("cycle", 6)
#' graph.embedding(graph, dim = 2, method = "fr")
#'
#' @export
graph.embedding <- function(graph, edge.attribute = NULL,
                            transform = c("identity", "reciprocal"),
                            dim = 2, method = c("fr", "kk"), verbose = FALSE,
                            stage = "final") {
    method <- match.arg(method)
    transform <- match.arg(transform)
    if (length(dim) != 1L || !dim %in% c(2, 3)) stop("dim must be 2 or 3.")
    g <- as_igraph(graph, stage)
    if (!graph.order(graph)) return(matrix(numeric(), 0L, dim))
    weights <- NULL
    if (!is.null(edge.attribute)) {
        edges <- graph.edges(graph, stage)
        if (length(edge.attribute) != 1L || !edge.attribute %in% setdiff(names(edges), c("from", "to")))
            stop("Select a stored edge attribute, such as 'length' or 'conductance'.")
        weights <- edges[[edge.attribute]]
        if (!is.numeric(weights) || any(!is.finite(weights)) || any(weights <= 0))
            stop("Layout edge values must be strictly positive, including before reciprocal transformation.")
        if (transform == "reciprocal") weights <- 1 / weights
    } else if (transform != "identity") stop("Select edge.attribute before transforming edge values.")
    if (method == "fr") igraph::layout_with_fr(g, dim = dim, weights = weights) else
        igraph::layout_with_kk(g, dim = dim, weights = weights)
}

#' Compute the Positive Spectrum of an Unweighted Graph Laplacian
#'
#' @param graph A `dgraph`; the final-stage topology defines the combinatorial
#'   Laplacian `L = D - A`. Stored edge lengths and attributes are not used.
#' @param nev Number of smallest positive eigenpairs, in increasing eigenvalue
#'   order. `NULL` requests all `n - nullity` positive modes; zero requests none.
#'   Explicit counts must be integers in that range; they are never truncated.
#' @param use.R Logical; use base R's dense symmetric eigensolver instead of
#'   the native backend. Both return the same numerical contract.
#' @param return.Laplacian Logical; include the graph Laplacian in the result.
#' @param return.dense Logical; return a base matrix when `TRUE`, otherwise a
#'   sparse Matrix object. If Matrix is unavailable, warn and return dense.
#'   Ignored when `return.Laplacian = FALSE`.
#' @param tol Positive absolute eigenvalue tolerance. By default, use
#'   `100 * .Machine$double.eps * max(1, 2 * max.degree)`. Computed zero modes
#'   must have absolute eigenvalues at most `tol`; returned modes must exceed
#'   it. An unresolved separation from zero is an error, not silent truncation.
#'
#' @return A `graph_spectrum` list with `evalues` (the requested positive
#'   eigenvalues in increasing order), `evectors` (one row per original vertex,
#'   one orthonormal column per eigenvalue), `nullity` (the exact number of
#'   connected components), `components` (component IDs in vertex order), and
#'   the resolved `tolerance`. When requested, `laplacian` contains `L`.
#'   An empty or edgeless graph has no positive modes and an `n` by zero
#'   eigenvector matrix when `nev = NULL` or `nev = 0`.
#'
#' @details
#' Every component contributes one zero mode, including isolated vertices.
#' These modes are omitted from `evalues` and `evectors`; their number is
#' determined from topology and checked against the computed spectrum.
#' The native backend uses sparse Lanczos for partial spectra, requesting the
#' component zero modes as well, and a dense eigensolver for the full spectrum.
#' The R backend computes the full dense spectrum before selection. Thus a
#' small explicit `nev` is preferable for large graphs. Dense solves require
#' quadratic memory; requesting all positive modes is not a sparse operation.
#'
#' Eigenvector signs and bases within repeated-eigenvalue subspaces are not
#' unique. If `nev` or an embedding dimension cuts through a repeated
#' eigenvalue, the selected subspace and embedding distances can differ between
#' backends. Include the whole tied eigenspace for invariant comparisons.
#' @seealso [graph.spectral.embedding()], [graph.connected.components()]
#'
#' @examples
#' graph <- create.graph("chain", 8)
#' spectrum <- graph.spectrum(graph, nev = 3)
#' spectrum$evalues
#' spectrum$nullity # one omitted zero mode
#' graph.spectral.embedding(spectrum, dim = 2)
#'
#' @export
graph.spectrum <- function(graph, nev = NULL, use.R = FALSE,
                           return.Laplacian = FALSE, return.dense = FALSE,
                           tol = NULL) {
    adj.list <- graph.adjacency(graph)
    n <- length(adj.list)
    components <- graph.connected.components(graph)
    nullity <- length(unique(components))
    rank <- n - nullity
    for (name in c("use.R", "return.Laplacian", "return.dense")) {
        value <- get(name)
        if (!is.logical(value) || length(value) != 1L || is.na(value))
            stop(name, " must be TRUE or FALSE.", call. = FALSE)
    }
    if (is.null(nev)) nev <- rank
    if (!is.numeric(nev) || is.complex(nev) || length(nev) != 1L ||
        !is.null(dim(nev)) || !is.finite(nev) || nev != floor(nev) || nev < 0 || nev > rank)
        stop("nev must be an integer between 0 and n - nullity (", rank, ").", call. = FALSE)
    nev <- as.integer(nev)
    if (is.null(tol)) tol <- 100 * .Machine$double.eps * max(1, 2 * lengths(adj.list))
    if (!is.numeric(tol) || is.complex(tol) || length(tol) != 1L ||
        !is.null(dim(tol)) || !is.finite(tol) || tol <= 0)
        stop("tol must be a finite positive number.", call. = FALSE)
    if (return.Laplacian && !return.dense && !requireNamespace("Matrix", quietly = TRUE)) {
        warning("Matrix not installed: returning a dense Laplacian instead of sparse.")
        return.dense <- TRUE
    }
    count <- if (nev) nev + nullity else 0L
    if (use.R) {
        ans <- list(evalues = numeric(), evectors = matrix(numeric(), n, 0L))
        if (count || return.Laplacian) {
            # Assemble directly from adjacency; avoid a dense adjacency copy.
            i <- rep.int(seq_len(n), lengths(adj.list))
            j <- as.integer(unlist(adj.list, use.names = FALSE))
            if (requireNamespace("Matrix", quietly = TRUE)) {
                L <- Matrix::sparseMatrix(i = c(seq_len(n), i), j = c(seq_len(n), j),
                    x = c(lengths(adj.list), rep(-1, length(i))), dims = c(n, n))
            } else {
                L <- matrix(0, n, n)
                diag(L) <- lengths(adj.list)
                L[cbind(i, j)] <- -1
            }
            if (count) {
                ed <- eigen(as.matrix(L), symmetric = TRUE)
                selected <- order(ed$values)[seq_len(count)]
                ans$evalues <- ed$values[selected]
                ans$evectors <- ed$vectors[, selected, drop = FALSE]
            }
            if (return.Laplacian) ans$laplacian <- if (return.dense) as.matrix(L) else L
        }
    } else {
        graph.0 <- lapply(adj.list, function(x) as.integer(x - 1L))
        ans <- if (return.Laplacian) {
            result <- .Call("S_graph_spectrum_plus", graph.0, as.integer(count),
                            return.dense, PACKAGE = "dgraphs")
            result$laplacian <- if (return.dense) result$dense_laplacian else
                Matrix::sparseMatrix(i = result$laplacian[[2]] + 1L,
                    j = result$laplacian[[3]] + 1L, x = result$laplacian[[4]],
                    dims = result$laplacian[[1]])
            result
        } else .Call("S_graph_spectrum", graph.0, as.integer(count), PACKAGE = "dgraphs")
    }
    selected <- integer()
    if (count) {
        if (length(ans$evalues) != count || any(!is.finite(ans$evalues)) ||
            any(ans$evalues < -tol) || sum(abs(ans$evalues) <= tol) != nullity)
            stop("Computed zero modes do not match graph nullity at tol; adjust tol or try the other backend.",
                 call. = FALSE)
        selected <- which(ans$evalues > tol)
        selected <- selected[order(ans$evalues[selected])]
        if (length(selected) != nev)
            stop("Could not resolve the requested positive eigenpairs at tol.", call. = FALSE)
    }
    out <- list(evalues = ans$evalues[selected],
                evectors = ans$evectors[, selected, drop = FALSE],
                nullity = nullity, components = components, tolerance = tol)
    if (return.Laplacian) out$laplacian <- ans$laplacian
    structure(out, class = "graph_spectrum")
}

#' Embed a Connected Graph Using its Positive Laplacian Spectrum
#'
#' @param spectrum A `graph_spectrum` object returned by [graph.spectrum()].
#' @param dim Positive integer number of coordinates, no greater than the
#'   number of positive eigenpairs in `spectrum`.
#' @param scale Coordinate scaling: `"none"` uses the orthonormal eigenvectors;
#'   `"inverse.sqrt"` divides each column by the square root of its eigenvalue.
#'
#' @return Numeric matrix with one row per vertex and columns `Dim1`, `Dim2`,
#'   and so on. Columns use the smallest `dim` positive eigenvalues.
#'
#' @details
#' The spectrum object carries the eigenvalue ordering, zero-mode tolerance
#' and component information, so embedding never discards a column by position
#' in an arbitrary eigenvector matrix. Disconnected graphs are rejected:
#' embed each component separately with [create.subgraph()] and
#' [graph.spectrum()]. There is no implied distance between separate components.
#' Singleton and empty graphs have no positive-dimensional spectral embedding.
#'
#' Unscaled coordinates are a spectral representation, not original physical
#' coordinates. On a connected graph, inverse-square-root scaling using all
#' positive modes makes squared Euclidean distances equal to effective
#' resistance; using fewer modes gives a truncated representation. Neither
#' choice generally reproduces shortest-path or manifold geodesic distances.
#' Signs and bases within tied eigenvalues can vary; choose whole tied
#' eigenspaces when comparing embedding distances across backends.
#' @seealso [graph.spectrum()], [graph.embedding()]
#'
#' @examples
#' graph <- create.graph("chain", 8)
#' spectrum <- graph.spectrum(graph, nev = 3)
#' graph.spectral.embedding(spectrum, dim = 2)
#' graph.spectral.embedding(spectrum, dim = 3, scale = "inverse.sqrt")
#'
#' @export
graph.spectral.embedding <- function(spectrum, dim = 2,
                                     scale = c("none", "inverse.sqrt")) {
    scale <- match.arg(scale)
    if (!inherits(spectrum, "graph_spectrum") || !is.list(spectrum))
        stop("spectrum must be a graph_spectrum object from graph.spectrum().", call. = FALSE)
    values <- spectrum$evalues
    vectors <- spectrum$evectors
    tol <- spectrum$tolerance
    nullity <- spectrum$nullity
    components <- spectrum$components
    if (!is.numeric(tol) || is.complex(tol) || length(tol) != 1L ||
        !is.finite(tol) || tol <= 0 || !is.numeric(values) || is.complex(values) ||
        !is.null(dim(values)) || any(!is.finite(values)) || any(values <= tol) ||
        any(diff(values) < 0) || !is.matrix(vectors) || !is.numeric(vectors) ||
        is.complex(vectors) || ncol(vectors) != length(values) || any(!is.finite(vectors)) ||
        !is.numeric(nullity) || is.complex(nullity) || length(nullity) != 1L ||
        !is.finite(nullity) || nullity != floor(nullity) || nullity < 0 || nullity > nrow(vectors) ||
        !is.numeric(components) || is.complex(components) || !is.null(base::dim(components)) ||
        length(components) != nrow(vectors) || any(!is.finite(components)) ||
        any(components != floor(components)) || any(components < 1 | components > nrow(vectors)) ||
        length(unique(components)) != nullity || length(values) > nrow(vectors) - nullity)
        stop("Invalid spectrum: expected ordered positive eigenpairs and component metadata.", call. = FALSE)
    if (nullity > 1L)
        stop("Disconnected graphs must be embedded component by component: use create.subgraph() and graph.spectrum().",
             call. = FALSE)
    if (!is.numeric(dim) || is.complex(dim) || length(dim) != 1L ||
        !is.null(base::dim(dim)) || !is.finite(dim) || dim != floor(dim) ||
        dim < 1 || dim > length(values))
        stop("dim must be a positive integer no greater than the number of positive eigenpairs.", call. = FALSE)
    embedding <- vectors[, seq_len(dim), drop = FALSE]
    if (scale == "inverse.sqrt")
        embedding <- sweep(embedding, 2, sqrt(values[seq_len(dim)]), "/")
    colnames(embedding) <- paste0("Dim", seq_len(dim))
    embedding
}
