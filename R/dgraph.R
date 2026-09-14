#' Construct and Inspect an Undirected Metric Graph
#'
#' A `dgraph` stores an undirected simple graph, including isolated vertices.
#' Adjacency, lengths and scalar edge attributes are validated together and
#' sorted together. Zero lengths are edges; absent lengths remain `NULL`.
#'
#' @param adj.list List of 1-based neighbor vectors, one per vertex.
#' @param length.list Optional aligned finite nonnegative numeric length lists.
#' @param edge.attributes Named list of aligned scalar edge-attribute lists.
#' @param graph A `dgraph` object.
#' @param stage Stored graph stage; defaults to `"final"`. Missing stages error.
#' @param name Name of a stored edge attribute, for example `"overlap"`.
#' @return `dgraph()` returns a graph. The accessors return adjacency lists,
#'   length lists (or `NULL`), an ordered edge data frame, the vertex count,
#'   stage names, or the requested attribute list, respectively. Edge tables
#'   contain integer `from < to`, optional numeric `length`, and attributes.
#' @examples
#' graph <- dgraph(list(c(3L, 2L), 1L, 1L, integer()),
#'                 list(c(0, 2), 2, 0, numeric()))
#' graph.order(graph)
#' graph.edges(graph)
#' graph.stages(graph)
#' graph.adjacency(graph)
#' graph.lengths(graph)
#' @export
dgraph <- function(adj.list, length.list = NULL, edge.attributes = list()) {
    stage <- .dgraph.stage(adj.list, length.list, edge.attributes)
    structure(list(n.vertices = length(stage$adj.list),
                   stages = list(final = stage), metadata = list()), class = "dgraph")
}

.dgraph.stage <- function(adj.list, length.list = NULL, edge.attributes = list()) {
    adj.list <- .dgraphs.validate.adj.list(adj.list, allow.empty = TRUE)
    n <- length(adj.list)
    if (!is.list(edge.attributes) || (length(edge.attributes) &&
        (is.null(names(edge.attributes)) || anyNA(names(edge.attributes)) ||
         any(!nzchar(names(edge.attributes))) || anyDuplicated(names(edge.attributes)) ||
         any(names(edge.attributes) %in% c("from", "to", "length")))))
        stop("edge.attributes must have unique names other than from, to and length.", call. = FALSE)
    if (!is.null(length.list))
        length.list <- .dgraphs.validate.length.list(adj.list, length.list)
    aligned <- c(if (!is.null(length.list)) list(length = length.list), edge.attributes)
    for (name in names(aligned)) {
        values <- aligned[[name]]
        if (!is.list(values) || length(values) != n ||
            !identical(unname(lengths(values)), unname(lengths(adj.list))))
            stop("Attribute '", name, "' must align with adj.list.", call. = FALSE)
        types <- unique(vapply(values[lengths(values) > 0L], typeof, ""))
        if (length(types) > 1L && !all(types %in% c("double", "integer")))
            stop("Attribute '", name, "' must have a consistent scalar type.", call. = FALSE)
        if (any(vapply(values, function(v) !is.atomic(v) || !is.null(dim(v)) ||
                       anyNA(v) || (is.numeric(v) && any(!is.finite(v))), logical(1))))
            stop("Edge attributes must contain finite, nonmissing scalar values.", call. = FALSE)
    }
    for (i in seq_len(n)) {
        if (i %in% adj.list[[i]]) stop("Self-loops are not supported.", call. = FALSE)
        for (j in seq_along(adj.list[[i]])) {
            v <- adj.list[[i]][j]
            back <- match(i, adj.list[[v]])
            if (is.na(back)) stop("adj.list must contain reciprocal edges.", call. = FALSE)
            for (name in names(aligned)) {
                if (!isTRUE(all.equal(unname(aligned[[name]][[i]][j]),
                                     unname(aligned[[name]][[v]][back]), tolerance = 1e-12)))
                    stop("Reciprocal values differ for '", name, "'.", call. = FALSE)
            }
        }
        order <- order(adj.list[[i]])
        adj.list[[i]] <- unname(adj.list[[i]][order])
        for (name in names(aligned)) aligned[[name]][[i]] <- unname(aligned[[name]][[i]][order])
    }
    list(adj.list = adj.list, length.list = aligned$length,
         edge.attributes = aligned[setdiff(names(aligned), "length")])
}

.dgraph.get.stage <- function(graph, stage) {
    if (!inherits(graph, "dgraph")) stop("graph must be a dgraph object.", call. = FALSE)
    if (!is.character(stage) || length(stage) != 1L || is.na(stage) ||
        !stage %in% names(graph$stages))
        stop("Graph has no stored stage '", paste(stage, collapse = ","), "'.", call. = FALSE)
    graph$stages[[stage]]
}

#' @rdname dgraph
#' @export
graph.adjacency <- function(graph, stage = "final") .dgraph.get.stage(graph, stage)$adj.list
#' @rdname dgraph
#' @export
graph.lengths <- function(graph, stage = "final") .dgraph.get.stage(graph, stage)$length.list
#' @rdname dgraph
#' @export
graph.order <- function(graph) {
    .dgraph.get.stage(graph, "final")
    graph$n.vertices
}
#' @rdname dgraph
#' @export
graph.stages <- function(graph) {
    .dgraph.get.stage(graph, "final")
    names(graph$stages)
}
#' @rdname dgraph
#' @export
graph.edge.attribute <- function(graph, name, stage = "final") {
    attrs <- .dgraph.get.stage(graph, stage)$edge.attributes
    if (!is.character(name) || length(name) != 1L || is.na(name) || !name %in% names(attrs))
        stop("No edge attribute named '", paste(name, collapse = ","), "'.", call. = FALSE)
    attrs[[name]]
}
#' @rdname dgraph
#' @export
graph.edges <- function(graph, stage = "final") {
    s <- .dgraph.get.stage(graph, stage)
    from <- rep.int(seq_along(s$adj.list), lengths(s$adj.list))
    to <- as.integer(unlist(s$adj.list, use.names = FALSE))
    keep <- from < to
    out <- data.frame(from = as.integer(from[keep]), to = to[keep])
    if (!is.null(s$length.list)) out$length <- as.numeric(unlist(s$length.list, use.names = FALSE))[keep]
    for (name in names(s$edge.attributes)) {
        values <- unlist(s$edge.attributes[[name]], use.names = FALSE)
        if (is.null(values)) {
            rows <- s$edge.attributes[[name]]
            values <- if (length(rows)) rows[[1L]][FALSE] else logical()
        }
        out[[name]] <- values[keep]
    }
    out
}

# Internal conversion at the native-result boundary; never accepts user graphs.
.dgraph.from.native <- function(result, graph.class = NULL) {
    prefixes <- c(final = "", raw = "raw_", pruned = "pruned_",
                  raw.repaired = "raw_repaired_", pruned.repaired = "pruned_repaired_",
                  repaired.pruned = "repaired_pruned_")
    stages <- list()
    raw.adj <- result$raw_adj_list
    raw.overlap <- result$raw_isize_list
    if (is.null(raw.adj)) raw.adj <- result$adj_list
    if (is.null(raw.overlap)) raw.overlap <- result$isize_list
    for (stage in names(prefixes)) {
        prefix <- prefixes[[stage]]
        adj <- result[[paste0(prefix, "adj_list")]]
        len <- result[[paste0(prefix, "weight_list")]]
        if (is.null(adj)) next
        attrs <- list()
        if (!is.null(raw.overlap) && identical(lengths(raw.overlap), lengths(raw.adj))) {
            attrs$overlap <- lapply(seq_along(adj), function(i) {
                idx <- match(adj[[i]], raw.adj[[i]])
                value <- as.integer(raw.overlap[[i]][idx])
                value[is.na(idx)] <- 0L
                value
            })
        }
        stages[[stage]] <- .dgraph.stage(adj, len, attrs)
    }
    if (!"final" %in% names(stages)) stop("Native graph is missing its final stage.")
    n <- length(stages$final$adj.list)
    if (any(vapply(stages, function(s) length(s$adj.list) != n, logical(1))))
        stop("Stored graph stages must share their vertex order.")
    removed <- grep("(^|_)(adj_list|weight_list|isize_list)$|^edge_matrix$|^edge_weight$|^n_vertices$|^n_edges$|^k_internal$", names(result), value = TRUE)
    out <- list(n.vertices = n, stages = stages, metadata = result[setdiff(names(result), removed)])
    attrs <- attributes(result)
    for (name in setdiff(names(attrs), c("names", "class", "k_internal"))) attr(out, name) <- attrs[[name]]
    if (is.null(graph.class)) graph.class <- setdiff(class(result), "list")
    class(out) <- unique(c(graph.class, "dgraph"))
    out
}

#' Print an Undirected Graph
#' @param x A `dgraph`.
#' @param ... Unused.
#' @return The unchanged graph, invisibly.
#' @examples
#' print(create.graph("empty", 3))
#' @export
print.dgraph <- function(x, ...) {
    cat("Undirected graph:", graph.order(x), "vertices,", nrow(graph.edges(x)), "edges\n")
    cat("Stored stages:", paste(graph.stages(x), collapse = ", "), "\n")
    invisible(x)
}

.validate.k.values <- function(k.values, n) {
    if (!is.numeric(k.values) || !length(k.values) || any(!is.finite(k.values)) ||
        any(k.values != floor(k.values)) || any(k.values < 1 | k.values >= n) ||
        any(diff(k.values) <= 0))
        stop("k.values must be strictly increasing integers with 1 <= k < n.", call. = FALSE)
    as.integer(k.values)
}

.neighborhood.metadata <- function(k, effective.k, metric) {
    list(k = as.integer(k), effective.k = as.integer(effective.k), metric = metric,
         self = "explicit", ties = "distance.then.vertex.index", convention.version = 3L)
}
