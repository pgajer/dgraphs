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
#' @param adj.list Adjacency list representation of a graph.
#' @param weights.list Optional edge-weight list aligned with `adj.list`.
#' @param invert.weights Logical; invert weights for Fruchterman-Reingold layout.
#' @param dim Embedding dimension, either `2` or `3`.
#' @param method Layout method, `"fr"` or `"kk"`.
#' @param verbose Logical; print timing messages.
#'
#' @return Numeric layout matrix with one row per embedded vertex.
#'
#' @export
graph.embedding <- function(adj.list,
                            weights.list = NULL,
                            invert.weights = TRUE,
                            dim = 2,
                            method = c("fr", "kk"),
                            verbose = FALSE) {

  if (!requireNamespace("igraph", quietly = TRUE)) {
    stop("Package 'igraph' is required. Please install it.")
  }

  if (!is.list(adj.list)) {
    stop("adj.list must be a list")
  }

  if (!is.numeric(dim) || length(dim) != 1 || dim %% 1 != 0 || !(dim %in% c(2, 3))) {
    stop("dim must be either 2 or 3")
  }

  method <- match.arg(method)

  if (!is.logical(invert.weights) || length(invert.weights) != 1) {
    stop("invert.weights must be a single logical value")
  }

  if (!is.logical(verbose) || length(verbose) != 1) {
    stop("verbose must be a single logical value")
  }

  if (!is.null(weights.list)) {
    if (!is.list(weights.list) || length(weights.list) != length(adj.list)) {
      stop("weights.list must be a list with the same length as adj.list")
    }
    if (!all(mapply(function(a, w) length(a) == length(w), adj.list, weights.list))) {
      stop("Each element of weights.list must have the same length as the corresponding element of adj.list")
    }
    weights.list <- lapply(weights.list, as.numeric)
  }

  n.vertices <- length(adj.list)

  if (n.vertices == 0) {
    return(matrix(0, nrow = 0, ncol = dim))
  }

  if (verbose) {
    routine.ptm <- proc.time()
    ptm <- proc.time()
    cat("Converting graph adjacency list to edge matrix ... ")
  }

  res <- convert.adjacency.to.edge.matrix(adj.list, weights.list)

  if (verbose) {
    elapsed.time(ptm)
  }

  if (nrow(res$edge.matrix) == 0) {
    if (verbose) {
      cat("Graph has no edges. Returning random positions.\n")
    }
    return(matrix(stats::runif(n.vertices * dim, -1, 1), nrow = n.vertices, ncol = dim))
  }

  if (verbose) {
    ptm <- proc.time()
    cat("Creating igraph object from edge matrix ... ")
  }

  g <- igraph::graph_from_edgelist(res$edge.matrix, directed = FALSE)

  if (verbose) {
    elapsed.time(ptm)
  }

  if (!is.null(weights.list)) {
    if (method == "fr" && invert.weights) {
      igraph::E(g)$weight <- 1 / res$weights
    } else {
      igraph::E(g)$weight <- res$weights
    }
  }

  if (verbose) {
    ptm <- proc.time()
    cat(sprintf("Computing %s layout in %dD space ... ",
                toupper(method), dim))
  }

  layout.coords <- switch(method,
                         fr = igraph::layout_with_fr(g, dim = dim),
                         kk = igraph::layout_with_kk(g, dim = dim))

  if (verbose) {
    elapsed.time(ptm)
    txt <- "Total elapsed time"
    elapsed.time(routine.ptm, txt, with.brackets = FALSE)
  }

  return(layout.coords)
}

#' Plot a Graph with Colored Vertices
#'
#' @param embedding Numeric `n x 2` matrix of vertex coordinates.
#' @param adj.list Graph adjacency list.
#' @param vertex.colors Numeric color value for each vertex.
#' @param vertex.size Base graphics point size.
#' @param edge.alpha Edge alpha in `[0, 1]`.
#' @param color.palette Optional vector of colors.
#' @param main Plot title.
#' @param add.legend Logical; add color scale legend.
#'
#' @return Invisibly returns `NULL`; produces a plot as a side effect.
#'
#' @export
plot2D.colored.graph <- function(embedding, adj.list, vertex.colors,
                               vertex.size = 1,
                               edge.alpha = 0.2,
                               color.palette = NULL,
                               main = "",
                               add.legend = TRUE) {

    if (is.null(color.palette)) {
        cols <- grDevices::colorRampPalette(c("blue", "white", "red"))(100)
        color.indices <- round((vertex.colors - min(vertex.colors)) /
                             (max(vertex.colors) - min(vertex.colors)) * 99 + 1)
        point.colors <- cols[color.indices]
    } else {
        cols <- color.palette
        color.indices <- round((vertex.colors - min(vertex.colors)) /
                             (max(vertex.colors) - min(vertex.colors)) * (length(cols) - 1) + 1)
        point.colors <- cols[color.indices]
    }

    oldpar <- par(no.readonly = TRUE)
    on.exit(par(oldpar), add = TRUE)

    mar.right <- if(add.legend) 4 else 1
    par(mar = c(1, 1, 2, mar.right))

    plot(embedding[,1], embedding[,2],
         type = "n",
         xlab = "", ylab = "",
         xaxt = "n", yaxt = "n",
         main = main,
         asp = 1)

    edge.col <- grDevices::rgb(0, 0, 0, edge.alpha)

    for(i in seq_along(adj.list)) {
        if(length(adj.list[[i]]) > 0) {
            segments(embedding[i,1], embedding[i,2],
                    embedding[adj.list[[i]],1], embedding[adj.list[[i]],2],
                    col = edge.col)
        }
    }

    points(embedding[,1], embedding[,2],
           pch = 19,
           cex = vertex.size,
           col = point.colors)

    if(add.legend) {
        legend.vals <- round(seq(min(vertex.colors), max(vertex.colors), length.out = 5), 2)
        legend.cols <- cols[round(seq(1, length(cols), length.out = 5))]

        par(xpd = TRUE)
        legend.x <- par("usr")[2] * 1.02
        legend.y <- mean(par("usr")[3:4])

        gradient.bars <- length(cols)
        bar.height <- (par("usr")[4] - par("usr")[3]) / gradient.bars

        for(i in 1:gradient.bars) {
            rect(legend.x,
                 par("usr")[3] + (i-1) * bar.height,
                 legend.x + graphics::strwidth("M"),
                 par("usr")[3] + i * bar.height,
                 col = cols[i],
                 border = NA)
        }

        graphics::text(legend.x + graphics::strwidth("M") * 1.5,
             seq(par("usr")[3], par("usr")[4], length.out = 5),
             labels = legend.vals,
             adj = 0,
             cex = 0.8)
    }

    invisible(NULL)
}

#' Compute Graph Spectrum
#'
#' @param graph Graph adjacency list.
#' @param nev Number of nontrivial eigenvalues/eigenvectors to compute.
#' @param use.R Logical; use R/igraph implementation instead of native backend.
#' @param return.Laplacian Logical; include the graph Laplacian in the result.
#' @param return.dense Logical; return a dense Laplacian when requested.
#'
#' @return A list with `evalues`, `evectors`, and optionally `laplacian`.
#'
#' @export
graph.spectrum <- function(graph,
                           nev = NULL,
                           use.R = FALSE,
                           return.Laplacian = FALSE,
                           return.dense = FALSE) {
  if (!is.list(graph)) stop("'graph' must be a list of integer vectors")
  n <- length(graph)
  if (n == 0L) stop("'graph' must contain at least one vertex")

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
    g.m <- convert.adjacency.list.to.adjacency.matrix(graph)
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

  graph.0 <- lapply(graph, function(x) if (length(x)) as.integer(x - 1L) else integer(0))

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
