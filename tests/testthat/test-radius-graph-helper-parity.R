.legacy.graph.from.edge.table <- function(n, edges) {
    adj <- vector("list", n)
    weights <- vector("list", n)
    if (is.null(edges) || !nrow(edges)) {
        for (i in seq_len(n)) {
            adj[[i]] <- integer(0)
            weights[[i]] <- numeric(0)
        }
        return(list(adj_list = adj, weight_list = weights))
    }
    edges <- edges[order(edges$from, edges$to), , drop = FALSE]
    for (r in seq_len(nrow(edges))) {
        u <- as.integer(edges$from[[r]])
        v <- as.integer(edges$to[[r]])
        w <- as.numeric(edges$weight[[r]])
        adj[[u]] <- c(adj[[u]], v)
        weights[[u]] <- c(weights[[u]], w)
        adj[[v]] <- c(adj[[v]], u)
        weights[[v]] <- c(weights[[v]], w)
    }
    for (i in seq_len(n)) {
        if (length(adj[[i]]) > 1L) {
            ord <- order(adj[[i]])
            adj[[i]] <- as.integer(adj[[i]][ord])
            weights[[i]] <- as.numeric(weights[[i]][ord])
        } else {
            adj[[i]] <- as.integer(adj[[i]])
            weights[[i]] <- as.numeric(weights[[i]])
        }
    }
    list(adj_list = adj, weight_list = weights)
}

.legacy.graph.components <- function(adj.list) {
    n <- length(adj.list)
    comp <- rep.int(NA_integer_, n)
    comp.id <- 0L
    for (start in seq_len(n)) {
        if (!is.na(comp[[start]])) {
            next
        }
        comp.id <- comp.id + 1L
        comp[[start]] <- comp.id
        stack <- start
        while (length(stack)) {
            u <- stack[[length(stack)]]
            stack <- stack[-length(stack)]
            for (v in adj.list[[u]]) {
                if (is.na(comp[[v]])) {
                    comp[[v]] <- comp.id
                    stack <- c(stack, v)
                }
            }
        }
    }
    list(component_id = comp, n_components = comp.id)
}

test_that(".graph.from.edge.table preserves legacy adjacency ordering", {
    cases <- list(
        empty = list(
            n = 4L,
            edges = data.frame(from = integer(), to = integer(),
                               weight = numeric())
        ),
        unsorted.with.isolate = list(
            n = 6L,
            edges = data.frame(
                from = c(3L, 1L, 2L, 4L, 1L),
                to = c(5L, 3L, 4L, 5L, 2L),
                weight = c(3.5, 1.3, 2.4, 4.5, 1.2)
            )
        ),
        repeated.endpoint.order = list(
            n = 5L,
            edges = data.frame(
                from = c(1L, 1L, 2L, 3L, 2L),
                to = c(3L, 2L, 5L, 5L, 3L),
                weight = c(1.3, 1.2, 2.5, 3.5, 2.3)
            )
        )
    )

    for (case in cases) {
        expect_equal(
            dgraphs:::.graph.from.edge.table(case$n, case$edges),
            .legacy.graph.from.edge.table(case$n, case$edges)
        )
    }
})

test_that(".graph.components preserves legacy component labels", {
    adj.cases <- list(
        all.isolates = rep(list(integer(0)), 4L),
        chain.plus.isolate = list(
            as.integer(2L),
            as.integer(c(1L, 3L)),
            as.integer(2L),
            integer(0)
        ),
        multiple.components = list(
            as.integer(2L),
            as.integer(1L),
            as.integer(c(4L, 5L)),
            as.integer(3L),
            as.integer(3L),
            integer(0)
        )
    )

    for (adj.list in adj.cases) {
        expect_equal(
            dgraphs:::.graph.components(adj.list),
            .legacy.graph.components(adj.list)
        )
    }
})
