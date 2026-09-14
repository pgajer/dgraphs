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

#' Compute Graph Spectrum
#'
#' @param graph A `dgraph`; only topology is used for its unweighted Laplacian.
#' @param nev Number of nontrivial eigenvalues/eigenvectors to compute.
#' @param use.R Logical; use R/igraph implementation instead of native backend.
#' @param return.Laplacian Logical; include the graph Laplacian in the result.
#' @param return.dense Logical; return a dense Laplacian when requested.
#'
#' @return A list with `evalues`, `evectors`, and optionally `laplacian`.
#'
#' @examples
#' graph <- create.graph("cycle", 8)
#' spectrum <- graph.spectrum(graph, nev = 3)
#' spectrum$evalues
#'
#' @export
graph.spectrum <- function(graph,
                           nev = NULL,
                           use.R = FALSE,
                           return.Laplacian = FALSE,
                           return.dense = FALSE) {
  adj.list <- graph.adjacency(graph)

  if (!is.list(adj.list)) stop("'adj.list' must be a list of integer vectors")
  n <- length(adj.list)
  if (n == 0L) stop("'adj.list' must contain at least one vertex")

  if (!is.null(nev)) {
    if (!is.numeric(nev) || length(nev) != 1L || nev < 1) stop("'nev' must be a positive integer")
    nev <- as.integer(nev)
    if (nev >= n) {
      warning("'nev' >= number of vertices; setting to n - 1")
      nev <- n - 1L
    }
  }

  stopifnot(is.logical(use.R), length(use.R) == 1L)
  stopifnot(is.logical(return.Laplacian), length(return.Laplacian) == 1L)
  stopifnot(is.logical(return.dense), length(return.dense) == 1L)

  if (use.R) {
    if (!requireNamespace("igraph", quietly = TRUE)) {
      stop("Package 'igraph' is required when use.R = TRUE. Install it with install.packages('igraph').", call. = FALSE)
    }
    g.m <- convert.adjacency.list.to.adjacency.matrix(adj.list)
    g <- igraph::graph_from_adjacency_matrix(g.m, mode = "undirected")
    L  <- igraph::laplacian_matrix(g, normalization = "unnormalized")
    ed <- eigen(L)
    res <- list(evalues = ed$values, evectors = ed$vectors)
    if (return.Laplacian) res$laplacian <- L
    return(res)
  }

  if (is.null(nev)) nev <- n - 1L

  want_sparse <- return.Laplacian && !return.dense
  has_Matrix  <- requireNamespace("Matrix", quietly = TRUE)
  if (want_sparse && !has_Matrix) {
    warning("Matrix not installed: returning a dense Laplacian instead of sparse.")
    return.dense <- TRUE
  }

  graph.0 <- lapply(adj.list, function(x) if (length(x)) as.integer(x - 1L) else integer(0))

  if (return.Laplacian) {
      ans <- .Call("S_graph_spectrum_plus",
                   graph.0,
                   as.integer(nev),
                   as.logical(return.dense),
                   PACKAGE = "dgraphs")
    if (isTRUE(return.dense)) {
      ans$laplacian <- ans$dense_laplacian
      ans$dense_laplacian <- NULL
    } else {
      ans$laplacian <- Matrix::sparseMatrix(
        i = ans$laplacian[[2]] + 1L,
        j = ans$laplacian[[3]] + 1L,
        x = ans$laplacian[[4]],
        dims = ans$laplacian[[1]],
        giveCsparse = TRUE
      )
    }
    return(list(evalues = ans$evalues, evectors = ans$evectors, laplacian = ans$laplacian))
  } else {
      ans <- .Call("S_graph_spectrum",
                   graph.0,
                   as.integer(nev),
                   PACKAGE = "dgraphs")
    return(list(evalues = ans$evalues, evectors = ans$evectors))
  }
}

#' Generate Spectral Embedding of a Graph
#'
#' @param evectors Numeric matrix of graph Laplacian eigenvectors.
#' @param dim Embedding dimension.
#' @param evalues Optional eigenvalues used for scaling.
#'
#' @return Numeric spectral embedding matrix.
#'
#' @examples
#' graph <- create.graph("cycle", 8)
#' spectrum <- graph.spectrum(graph, nev = 4)
#' graph.spectral.embedding(spectrum$evectors, dim = 2)
#'
#' @export
graph.spectral.embedding <- function(evectors, dim, evalues = NULL) {

    if (!is.matrix(evectors) && !is.numeric(evectors)) {
        stop("'evectors' must be a numeric matrix")
    }

    if (!is.matrix(evectors)) {
        evectors <- as.matrix(evectors)
    }

    if (!is.numeric(dim) || length(dim) != 1 || dim < 1) {
        stop("'dim' must be a positive integer")
    }
    dim <- as.integer(dim)

    if (dim >= ncol(evectors)) {
        stop("'dim' must be less than the number of eigenvectors")
    }

    if (!is.null(evalues)) {
        if (!is.numeric(evalues)) {
            stop("'evalues' must be a numeric vector")
        }

        if (length(evalues) != ncol(evectors)) {
            stop("The length of 'evalues' must match the number of columns in 'evectors'")
        }

        selected_indices <- (ncol(evectors) - dim):(ncol(evectors) - 1)
        selected_evalues <- evalues[selected_indices]

        if (any(selected_evalues <= 0)) {
            warning("Some selected eigenvalues are non-positive. ",
                   "This may lead to numerical issues.")
        }
    }

    embedding <- evectors[, (ncol(evectors) - dim):(ncol(evectors) - 1), drop = FALSE]

    if (!is.null(evalues)) {
        for (i in 1:dim) {
            eval_idx <- ncol(evectors) - dim - 1 + i
            if (evalues[eval_idx] > 0) {
                embedding[, i] <- embedding[, i] / sqrt(evalues[eval_idx])
            }
        }
    }

    colnames(embedding) <- paste0("Dim", 1:dim)

    return(embedding)
}
