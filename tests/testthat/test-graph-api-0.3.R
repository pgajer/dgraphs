metric.graph <- function(X) {
    d <- as.matrix(dist(X)); n <- nrow(X)
    a <- lapply(seq_len(n), function(i) setdiff(seq_len(n), i))
    dgraph(a, lapply(seq_len(n), function(i) d[i, a[[i]]]))
}
reference.cover.edges <- function(D, k) {
    n <- nrow(D)
    covers <- lapply(seq_len(n), function(i) {
        other <- setdiff(which(is.finite(D[i, ])), i)
        c(i, head(other[order(D[i, other], other)], k))
    })
    pairs <- t(combn(seq_len(n), 2))
    keep <- apply(pairs, 1, function(e) length(intersect(covers[[e[1]]], covers[[e[2]]])) > 0)
    data.frame(from = as.integer(pairs[keep, 1]), to = as.integer(pairs[keep, 2]))
}
test_that("common graphs validate and sort aligned values without losing isolates or zeros", {
    graph <- dgraph(list(c(3L, 2L), 1L, 1L, integer()),
        list(c(0, 2), 2, 0, numeric()),
        list(kind = list(c("zero", "positive"), "positive", "zero", character())))
    expect_identical(names(graph), c("n.vertices", "stages", "metadata"))
    expect_equal(graph.order(graph), 4)
    expect_equal(graph.adjacency(graph)[[1]], c(2L, 3L))
    expect_equal(graph.lengths(graph)[[1]], c(2, 0))
    expect_equal(graph.edges(graph), data.frame(from = c(1L, 1L), to = c(2L, 3L),
        length = c(2, 0), kind = c("positive", "zero")))
    expect_equal(graph.geodesic.distances(graph)[1, 3], 0)
    expect_equal(igraph::vcount(as_igraph(graph)), 4)
    empty <- dgraph(rep(list(integer()), 2), rep(list(numeric()), 2),
        list(kind = rep(list(character()), 2)))
    expect_identical(graph.edges(empty), data.frame(from=integer(), to=integer(), length=numeric(), kind=character()))
    expect_error(dgraph(list(c(2L, 2L), 1L)), "duplicate")
    expect_error(dgraph(list(2L, integer())), "reciprocal")
    expect_error(dgraph(list(1L)), "Self-loops")
    expect_error(dgraph(list(2L, 1L), list(1, 2)), "Reciprocal")
    expect_error(dgraph(list(integer()), list(1)), "length")
    expect_error(graph.adjacency(graph, "missing"), "no stored stage")
    expect_error(graph.edge.attribute(graph, "absent"), "No edge attribute")
    unweighted <- create.circular.graph(4)
    expect_null(graph.lengths(unweighted))
    expect_error(graph.geodesic.distances(unweighted), "length")
    expect_equal(graph.geodesic.distances(unweighted, distance="hop")[1,3], 2)
})
test_that("intersection covers use k other vertices and deterministic boundary ties", {
    for (X in list(matrix(c(0, 1, 3, 6), ncol=1),
                   rbind(c(0,0),c(0,0),c(1,0),c(-1,0),c(0,1),c(0,-1)))) {
        D <- as.matrix(dist(X)); original <- metric.graph(X)
        for (k in c(1L, nrow(X)-1L)) {
            expected <- reference.cover.edges(D, k)
            coordinate <- create.single.iknn.graph(X,k,prune.method="none",connect.components=FALSE,verbose=FALSE)
            geodesic <- create.geodesic.iknn.graph(original,k)
            expect_equal(graph.edges(coordinate)[c("from","to")], expected)
            expect_equal(graph.edges(geodesic)[c("from","to")], expected)
            expect_equal(coordinate$metadata$neighborhood$effective.k, rep(k,nrow(X)))
            expect_equal(geodesic$metadata$neighborhood$effective.k, rep(k,nrow(X)))
            expect_true(all(graph.edges(geodesic)$overlap >= 1))
        }
        sequence <- create.iknn.graphs(X,k.values=c(1L,nrow(X)-1L),compute.full=TRUE,
            max.path.edge.ratio.deviation.thld=0,threshold.percentile=0,verbose=FALSE)
        for(k in attr(sequence,"k.values")) {
            scalar <- create.single.iknn.graph(X,k,prune.method="none",connect.components=FALSE,verbose=FALSE)
            expect_equal(graph.edges(sequence$geom_pruned_graphs[[as.character(k)]])[c("from","to","length")],
                         graph.edges(scalar)[c("from","to","length")])
        }
    }
})
test_that("geodesic components require explicit truncation and iterations preserve k", {
    graph <- dgraph(list(2L,1L,integer()),list(0,0,numeric()))
    expect_error(create.geodesic.iknn.graph(graph,1), "Undersized component sizes: 1")
    truncated <- create.geodesic.iknn.graph(graph,2,small.component="truncate")
    expect_equal(truncated$metadata$neighborhood$effective.k,c(1L,1L,0L))
    expect_equal(graph.order(truncated),3)
    expect_equal(graph.edges(truncated)$length,0)
    expect_equal(graph.adjacency(truncated)[[3]],integer())
    X <- matrix(c(0,1,3,6),ncol=1)
    out <- create.iterated.iknn.graphs(X,k.values=c(1L,3L),n.iterations=2,verbose=FALSE)
    for(iteration in out$graphs) for(k in c(1L,3L)) {
        g <- iteration[[as.character(k)]]
        expect_equal(g$metadata$neighborhood$k,k)
        expect_equal(g$metadata$neighborhood$effective.k,rep(k,4))
    }
    expect_error(create.iknn.graphs(X,k.values=c(2,1)),"strictly increasing")
    expect_error(create.geodesic.iknn.graph(metric.graph(X),0),"1 <= k")
    expect_error(create.geodesic.iknn.graph(metric.graph(X),4),"1 <= k")
})
test_that("cache reuse is tied to coordinates, order, metric and format", {
    X <- rbind(c(0,0),c(0,0),c(1,0),c(-1,0),c(0,1))
    path <- tempfile(); on.exit(unlink(path))
    construct <- function(X,k=2,mode) create.single.iknn.graph(X,k,knn.cache.path=path,
        knn.cache.mode=mode,prune.method="none",connect.components=FALSE,verbose=FALSE)
    original <- construct(X,mode="write")
    expect_equal(graph.edges(construct(X,mode="read")),graph.edges(original))
    expect_equal(graph.edges(construct(X,k=1,mode="read")),graph.edges(create.single.iknn.graph(X,1,
        prune.method="none",connect.components=FALSE,verbose=FALSE)))
    expect_error(construct(X[c(3,2,1,4,5),],mode="read"),"[Cc]ache|source|hash")
    changed <- X; changed[3,1] <- 2
    expect_error(construct(changed,mode="read"),"[Cc]ache|source|hash")
    expect_error(construct(X,k=4,mode="read"),"[Cc]ache|k")
    bytes <- readBin(path,"raw",n=file.info(path)$size)
    # The format version is the uint32 directly after its eight-byte magic.
    bytes[9:12] <- as.raw(c(2,0,0,0)); writeBin(bytes,path)
    expect_error(construct(X,mode="read"),"[Vv]ersion|[Cc]ache")
})
test_that("all retained stages convert with their lengths and attributes", {
    X <- rbind(c(0,0),c(0.1,0),c(0,0.1),c(10,10),c(10.1,10),c(10,10.1))
    graphs <- list(create.mknn.graph(X,2,connect.components=TRUE),
       create.sknn.graph(X,2,connect.components=TRUE),
       create.single.iknn.graph(X,2,connect.components=TRUE,verbose=FALSE),
       create.rknn.graph(X,type="adaptive",k.scale=2,connect.components=TRUE),create.cmst.graph(X,verbose=FALSE))
    for(g in graphs) for(stage in graph.stages(g)) {
       ig <- as_igraph(g,stage)
       expect_equal(igraph::vcount(ig),graph.order(g))
       expect_equal(igraph::ecount(ig),nrow(graph.edges(g,stage)))
       expect_equal(igraph::edge_attr(ig,"length"),graph.edges(g,stage)$length)
    }
    joined <- join.graphs(create.chain.graph(2),create.chain.graph(3),2,1)
    expect_equal(graph.order(joined),4)
    expect_equal(graph.geodesic.distances(joined)[1,4],3)
    sub <- create.subgraph(joined,c(4,3))
    expect_equal(sub$metadata$original.vertices,c(4L,3L))
    expect_equal(graph.adjacency(sub),list(2L,1L))
    expect_false(any(c("get.edge.weights","extract.edge.lengths") %in% getNamespaceExports("dgraphs")))
    expect_error(as_igraph(list(2L,1L)),"dgraph")
    expect_error(create.iknn.graphs(X,kmin=1,kmax=2),"unused argument")
    expect_error(shortest.path(adj.list=list(2L,1L),weight.list=list(1,1),vertices=1:2),"unused argument")
})

test_that("raw symmetrization preserves vertex order and isolated vertices", {
    a <- list(first=3L, isolated=integer(), third=integer(), last=1L)
    undirected <- convert.to.undirected(a)
    expect_identical(undirected,list(first=c(3L,4L), isolated=integer(), third=1L, last=1L))
    expect_equal(graph.order(dgraph(undirected)),4)
    set.seed(1)
    graph <- create.random.graph(10,2)
    expect_equal(length(unique(graph.connected.components(graph))),1)
    expect_equal(nrow(graph.edges(graph)),10)
})

test_that("packing results contain a directly inspectable graph", {
    graph <- create.chain.graph(5)
    packing <- create.maximal.packing(graph.adjacency(graph), graph.lengths(graph),grid.size=2)
    expect_s3_class(packing$graph,"dgraph")
    expect_true(verify.maximal.packing(packing,verbose=FALSE))
    expect_false(any(c("adj_list","weight_list") %in% names(packing)))
})

test_that("simplex-face ties follow the same exact cover rule", {
    X <- cbind(1, c(0,0,0.25,0.5,0.75,1))
    expected <- reference.cover.edges(as.matrix(dist(X)),1)
    graph <- create.single.iknn.graph(X,1,knn.metric="linf.simplex",pca.dim=NULL,
        prune.method="none",connect.components=FALSE,verbose=FALSE)
    expect_equal(graph.edges(graph)[c("from","to")],expected)
    sequence <- create.iknn.graphs(X,k.values=c(1,3),knn.metric="linf.simplex",pca.dim=NULL,
        compute.full=TRUE,max.path.edge.ratio.deviation.thld=0,threshold.percentile=0,verbose=FALSE)
    expect_equal(graph.edges(sequence$geom_pruned_graphs[["1"]])[c("from","to")],expected)
})

test_that("mutual graph sequences preserve sparse requested sizes", {
    X <- matrix(c(0,1,3,6,10),ncol=1)
    sequence <- create.mknn.graphs(X,k.values=c(1,3,4),compute.full=TRUE,
        max.path.edge.ratio.thld=0,pca.dim=NULL,verbose=FALSE)
    for(k in c(1,3,4)) {
        single <- create.mknn.graph(X,k,prune.method="none",connect.components=FALSE)
        expect_equal(graph.edges(sequence$pruned_graphs[[as.character(k)]])[c("from","to","length")],
                     graph.edges(single)[c("from","to","length")])
    }
})

test_that("coordinate and geodesic intersection lengths retain distinct meanings", {
    X <- rbind(c(-1,0),c(1,0),c(0,1))
    coordinate <- create.single.iknn.graph(X,1,prune.method="none",connect.components=FALSE,verbose=FALSE)
    geodesic <- create.geodesic.iknn.graph(metric.graph(X),1)
    expect_equal(graph.edges(coordinate)$length[1],2*sqrt(2))
    expect_equal(graph.edges(geodesic)$length[1],2)
    expect_equal(graph.edges(coordinate)[c("from","to")],graph.edges(geodesic)[c("from","to")])
})

test_that("neighbor caches reject a changed metric or projected dimension", {
    X <- cbind(1, c(0,0.2,0.4,0.6,0.8,1))
    path <- tempfile(); on.exit(unlink(path))
    create.single.iknn.graph(X,1,pca.dim=NULL,knn.cache.path=path,knn.cache.mode="write",
        prune.method="none",connect.components=FALSE,verbose=FALSE)
    expect_error(create.single.iknn.graph(X,1,pca.dim=NULL,knn.metric="linf.simplex",
        knn.cache.path=path,knn.cache.mode="read",prune.method="none",connect.components=FALSE,verbose=FALSE),
        "metric")
    X <- cbind(1:6,c(3,1,4,2,6,5),c(2,4,1,6,3,5))
    create.single.iknn.graph(X,1,pca.dim=1,variance.explained=NULL,
        knn.cache.path=path,knn.cache.mode="write",prune.method="none",connect.components=FALSE,verbose=FALSE)
    expect_error(create.single.iknn.graph(X,1,pca.dim=2,variance.explained=NULL,
        knn.cache.path=path,knn.cache.mode="read",prune.method="none",connect.components=FALSE,verbose=FALSE),
        "cache|features|hash")
})
