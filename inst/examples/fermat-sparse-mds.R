# Teaching helper, not an exported API. Exact Fermat targets for local pairs
# and pivot interactions; never reinterpret those targets as graph lengths.
fermat.mds.constraints <- function(points, pivots, k = 4L, p = 2) {
    n <- nrow(points)
    D <- dgraphs::fermat.distances(points = points, p = p, backend = "implicit",
                                   sources = pivots)
    if (!length(pivots)) stop("At least one pivot is required")
    if (any(D < 0) || any(colSums(D == 0) > 1L) ||
        any(vapply(seq_along(pivots), function(j) sum(D[j,] == 0) != 1L, logical(1))))
        stop("Consolidate duplicate observations before inverse-squared MDS")
    owner <- max.col(-t(D), ties.method = "first")
    g <- dgraphs::create.sknn.graph(points, k = k, neighbor.method = "exact",
        prune.edges = FALSE, connect.components = FALSE, graph.detail = "minimal")
    adj <- dgraphs::graph.adjacency(g)
    rows <- list()
    # Local targets are shortest-path distances, not powered direct lengths.
    for (i in seq_len(n)) {
        js <- adj[[i]][adj[[i]] > i]
        if (!length(js)) next
        d <- dgraphs::fermat.distances(points = points, p = p, backend = "implicit",
                                       sources = i, targets = js)
        rows[[length(rows)+1L]] <- cbind(i, js, as.numeric(d), 1, 1)
    }
    for (j in seq_along(pivots)) {
        pivot <- pivots[j]
        ids <- setdiff(seq_len(n), c(pivot, adj[[pivot]]))
        region <- sort(D[j, owner == j])
        counts <- findInterval(D[j, ids]/2, region)
        a <- ifelse(ids < pivot, counts, 0)
        b <- ifelse(ids < pivot, 0, counts)
        rows[[length(rows)+1L]] <- cbind(pmin(ids,pivot), pmax(ids,pivot), D[j,ids], a, b)
    }
    rows <- do.call(rbind, rows)
    if (any(rows[,3] <= 0)) stop("Consolidate duplicate observations before inverse-squared MDS")
    # Merge opposite pivot directions with endpoint multiplicities retained.
    key <- paste(rows[,1], rows[,2], sep = ":")
    groups <- split(seq_len(nrow(rows)), key)
    merged <- t(vapply(groups, function(ix) c(rows[ix[1],1:2], min(rows[ix,3]),
                                             sum(rows[ix,4]), sum(rows[ix,5])), numeric(5)))
    merged <- merged[merged[,4]+merged[,5] > 0,,drop=FALSE]
    merged <- merged[order(merged[,1],merged[,2]),,drop=FALSE]
    list(pairs = unname(merged[,1:2,drop=FALSE]), targets = unname(merged[,3]),
         count_i = unname(merged[,4]), count_j = unname(merged[,5]))
}
