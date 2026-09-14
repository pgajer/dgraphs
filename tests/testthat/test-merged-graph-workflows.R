test_that("geodesic construction uses explicit graph types and retains coincident points", {
    X <- matrix(c(0, 0, 1), ncol = 1, dimnames = list(c("a", "b", "c"), "x"))
    expected <- matrix(c(0, 0, 1, 0, 0, 1, 1, 1, 0), 3, 3,
                       dimnames = list(rownames(X), rownames(X)))
    expect_equal(graph.geodesic.distances(points = X, graph.type = "mst"), expected)
    expect_equal(graph.geodesic.distances(points = X, graph.type = "sknn", k = 1), expected)
    expect_equal(graph.geodesic.distances(points = matrix(4, 1, 1), graph.type = "mst"), matrix(0, 1, 1))
    X <- matrix(c(0, 1, 10, 11), ncol = 1)
    D <- graph.geodesic.distances(points = X, k = 1)
    expect_true(is.infinite(D[1, 4]))
    expect_equal(graph.geodesic.distances(points = X, graph.type = "mst")[1, 4], 11)
    explicit <- create.sknn.graph(X, k = 2, graph.detail = "minimal")
    expect_equal(graph.geodesic.distances(points = X, k = 2), graph.geodesic.distances(explicit))
    expect_equal(graph.geodesic.distances(points = X, k = 2, distance = "hop"),
                 graph.geodesic.distances(explicit, distance = "hop"))
    large <- matrix(c(0, 1e200, 2e200), ncol = 1)
    expect_equal(graph.geodesic.distances(points = large, graph.type = "mst")[1, 3], 2e200)
})

test_that("geodesic matrices select vertices and stages without losing intermediate vertices", {
    g <- create.graph("chain", n = 4, labels = letters[1:4])
    g$stages$raw <- dgraph(rep(list(integer()), 4), rep(list(numeric()), 4))$stages$final
    D <- graph.geodesic.distances(g, vertices = c(4L, 1L))
    expect_equal(unname(D), matrix(c(0, 3, 3, 0), 2, 2))
    expect_identical(rownames(D), c("d", "a"))
    expect_true(is.infinite(graph.geodesic.distances(g, stage = "raw")[1, 4]))
    expect_equal(dim(graph.geodesic.distances(g, vertices = integer())), c(0L, 0L))
    expect_equal(dim(graph.geodesic.distances(dgraph(list(), list()))), c(0L, 0L))
    expect_error(graph.geodesic.distances(), "exactly one")
    expect_error(graph.geodesic.distances(g, points = matrix(1:4)), "exactly one")
    expect_error(graph.geodesic.distances(g, k = 1), "Construction arguments")
    expect_error(graph.geodesic.distances(g, graph.type = "mst"), "Construction arguments")
    expect_error(graph.geodesic.distances(points = matrix(1:4)), "'k'")
    expect_error(graph.geodesic.distances(points = matrix(1:4), graph.type = "mst", k = 1), "not accepted")
    expect_error(graph.geodesic.distances(points = matrix(1:4), graph.type = "bad"), "graph.type")
    expect_error(graph.geodesic.distances(points = matrix(1:4), k = 4), "less than")
    expect_error(graph.geodesic.distances(points = matrix(1:4), k = 1, stage = "raw"), "only stage")
    expect_error(graph.geodesic.distances(points = matrix(NA_real_), graph.type = "mst"), "finite")
    expect_error(graph.geodesic.distances(g, vertices = c(1, 1)), "unique")
    expect_error(graph.geodesic.distances(g, vertices = 1.2), "integer")
    expect_error(graph.geodesic.distances(create.graph("cycle", 4)), "no lengths")
    expect_equal(graph.geodesic.distances(create.graph("cycle", 4), distance = "hop")[1, 3], 2)
})

test_that("hop-constrained routes retain feasible prefixes and matching lengths", {
    g <- dgraph(list(c(2L, 3L), c(1L, 3L, 4L), c(1L, 2L), 2L),
                list(c(5, 1), c(5, 1, 1), c(1, 1), 1))
    paths <- create.path.graph(g, h.values = c(2, 3, 9))
    expect_identical(names(paths), c("h_2", "h_3", "h_9"))
    expect_s3_class(paths, "path.graph.series")
    p2 <- get.shortest.path(paths$h_2, 1, 4)
    p3 <- get.shortest.path(paths$h_3, 1, 4)
    expect_equal(p2, list(path = c(1L, 2L, 4L), length = 6, hops = 2L))
    expect_equal(p3, list(path = c(1L, 3L, 2L, 4L), length = 3, hops = 3L))
    expect_identical(get.shortest.path(paths$h_3, 4, 1)$path, rev(p3$path))
    expect_equal(get.shortest.path(paths$h_9, 1, 4), p3)
    expect_equal(get.shortest.path(paths$h_2, 1, 1), list(path = 1L, length = 0, hops = 0L))
    expect_s3_class(create.path.graph(g, h.values = 2), "path.graph.series")
    expect_equal(create.path.graph(g, h.values = 2)[[1L]], paths$h_2)
    expect_error(get.shortest.path(paths$h_2, 1.5, 4), "integer")
    for (h in list(c(2, 1), c(1, 1), 1.5, NA_real_, Inf, 0, numeric()))
        expect_error(create.path.graph(g, h.values = h), "strictly increasing")
    expect_error(create.path.graph(create.graph("empty", 3), h.values = 1), "stored lengths")
    empty <- create.path.graph(dgraph(list(), list()), h.values = 1)[[1L]]
    expect_equal(graph.order(empty$graph), 0L)
    g$stages$raw <- dgraph(rep(list(integer()), 4), rep(list(numeric()), 4))$stages$final
    expect_null(get.shortest.path(create.path.graph(g, h.values = 3, stage = "raw")[[1L]], 1, 4))
    expect_equal(compare.paths(paths, 4, 1)$path_length, c(6, 3, 3))
})

# Independent exhaustive enumeration of simple paths, suitable only for tiny graphs.
.exhaustive.hop.path <- function(g, from, to, h) {
    adj <- graph.adjacency(g); lens <- graph.lengths(g)
    best <- Inf; best.hops <- Inf
    visit <- function(path, cost) {
        u <- tail(path, 1); steps <- length(path) - 1L
        if (u == to) {
            if (cost < best || (cost == best && steps < best.hops)) {
                best <<- cost; best.hops <<- steps
            }
        } else if (steps < h) for (j in seq_along(adj[[u]])) {
            v <- adj[[u]][j]
            if (!v %in% path) visit(c(path, v), cost + lens[[u]][j])
        }
    }
    visit(from, 0)
    c(length = best, hops = best.hops)
}

test_that("path lengths and hop counts agree with exhaustive constrained paths", {
    g <- dgraph(list(c(2L, 3L), c(1L, 3L, 4L), c(1L, 2L, 4L), c(2L, 3L), integer()),
                list(c(0, 2), c(0, 1, 3), c(2, 1, 1), c(3, 1), numeric()))
    paths <- create.path.graph(g, h.values = 1:4)
    for (h in 1:4) for (i in 1:5) for (j in 1:5) {
        ref <- .exhaustive.hop.path(g, i, j, h)
        got <- get.shortest.path(paths[[h]], i, j)
        if (is.infinite(ref[1L])) expect_null(got) else {
            expect_equal(got$length, unname(ref[1L]))
            expect_equal(got$hops, unname(ref[2L]))
            expect_equal(length(got$path) - 1L, got$hops)
            route.length <- 0
            if (got$hops) for (step in seq_len(got$hops)) {
                u <- got$path[step]; v <- got$path[step + 1L]
                route.length <- route.length + graph.lengths(g)[[u]][match(v, graph.adjacency(g)[[u]])]
            }
            expect_equal(route.length, got$length)
        }
    }
})

test_that("plotting draws undirected edges once, maps constants and restores graphics state", {
    file <- tempfile(fileext = ".pdf"); grDevices::pdf(file)
    on.exit({ grDevices::dev.off(); unlink(file) }, add = TRUE)
    g <- create.graph("cycle", 4)
    xy <- cbind(x = c(0, 1, 1, 0), y = c(0, 0, 1, 1))
    edges.drawn <- NULL; colors.drawn <- NULL
    oldpar <- graphics::par(c("mar", "xpd"))
    testthat::local_mocked_bindings(
        segments = function(x0, y0, x1, y1, ...) edges.drawn <<- cbind(x0, y0, x1, y1),
        points = function(x, y, bg, ...) colors.drawn <<- bg, .package = "graphics")
    out <- withVisible(plot(g, coordinates = xy, vertex.values = rep(7, 4),
                            color.palette = c("blue", "white", "red")))
    expect_false(out$visible)
    expect_identical(out$value, xy)
    expect_identical(colors.drawn, rep("white", 4))
    expect_equal(nrow(edges.drawn), 4L)
    expect_equal(graphics::par(c("mar", "xpd")), oldpar)
    plot(g, coordinates = xy, vertex.colors = c("red", "blue", "green", "black"))
    expect_identical(colors.drawn, c("red", "blue", "green", "black"))
    plot(g, coordinates = xy, vertex.values = c(-1e308, 0, 0, 1e308))
    expect_false(anyNA(colors.drawn))
    expect_error(plot(g, coordinates = xy, vertex.values = 1:4, vertex.colors = "red"), "only one")
    expect_error(plot(g, coordinates = xy, vertex.values = c(1, 2, NA, 4)), "finite")
    expect_error(plot(g, coordinates = xy, vertex.colors = "not-a-color"), "valid color")
    expect_error(plot(g, coordinates = xy, method = "kk"), "Layout arguments")
    expect_error(plot(g, coordinates = xy, color.palette = c("red", "blue")), "requires")
    expect_error(plot(g, coordinates = xy, edge.alpha = 2), "between")
    xyz <- cbind(xy, z = 4:1)
    expect_error(plot(g, coordinates = xyz), "explicit|projection|two distinct", fixed = FALSE)
    expect_equal(plot(g, coordinates = xyz, projection = c(1, 3)), xyz[, c(1, 3)])
    expect_error(plot(g, coordinates = xyz, projection = c(1, 1)), "two distinct")
    expect_error(plot(g, coordinates = xy, projection = c(1, 2)), "three-column")
})

test_that("automatic layouts and plotting use the selected stage", {
    file <- tempfile(fileext = ".pdf"); grDevices::pdf(file)
    on.exit({ grDevices::dev.off(); unlink(file) }, add = TRUE)
    g <- create.graph("chain", 4)
    g$stages$raw <- create.graph("complete", 4)$stages$final
    set.seed(30); expected <- graph.embedding(g, stage = "raw")
    set.seed(30); actual <- plot(g, stage = "raw", vertex.values = 1:4, add.legend = FALSE)
    expect_equal(actual, expected)
    expect_equal(dim(graph.embedding(g, dim = 3, stage = "raw")), c(4L, 3L))
    expect_error(graph.embedding(g, stage = "missing"), "stage")
    expect_equal(dim(plot(dgraph(list()))), c(0L, 2L))
    expect_equal(dim(plot(create.graph("empty", 1))), c(1L, 2L))
    expect_equal(dim(plot(create.graph("empty", 4))), c(4L, 2L))
})

test_that("retired distance, path-series and plotting names are absent", {
    retired <- c("shortest.path", "estimate.geodesic.distances", "create.path.graph.series", "plot2D.colored.graph")
    expect_false(any(retired %in% getNamespaceExports("dgraphs")))
    expect_false(any(vapply(retired, exists, logical(1), envir = asNamespace("dgraphs"), inherits = FALSE)))
    expect_true(is.function(getS3method("plot", "dgraph")))
})
