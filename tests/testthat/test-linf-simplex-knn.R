exact.knn.test <- function(X,k) {
    storage.mode(X) <- "double"
    z <- .Call("S_linf_simplex_knn", X, as.integer(k), 1e-8, PACKAGE="dgraphs")
    D <- linf.simplex.distances(X)
    for (i in seq_len(nrow(X))) {
        other <- setdiff(seq_len(nrow(X)),i)
        expected <- c(i,other[order(D[i,other],other)])[seq_len(k)]
        expect_identical(z$indices[i,]+1L,as.integer(expected))
        expect_equal(z$distances[i,],D[i,expected],tolerance=1e-12)
    }
    z
}
test_that("intermediate faces change nearest-neighbor identities", {
    X <- rbind(c(1,0,.99,0),c(0,1,.99,0),c(1,1,0,1))
    z <- exact.knn.test(X,2)
    expect_equal(z$indices[1,2]+1L,2L)
    expect_equal(z$distances[1,2],1.01*sqrt(2))
    expect_lt(z$distances[1,2],sqrt(2+.99^2))
    g <- create.single.iknn.graph(X,1,knn.metric="linf.simplex",pca.dim=NULL,
        prune.method="none",connect.components=FALSE,verbose=FALSE)
    expect_true(nrow(graph.edges(g))>0)
    sequence <- create.iknn.graphs(X,k.values=c(1,2),knn.metric="linf.simplex",pca.dim=NULL,
        compute.full=TRUE,max.path.edge.ratio.deviation.thld=0,threshold.percentile=0,verbose=FALSE)
    expect_equal(graph.edges(sequence$geom_pruned_graphs[["1"]])[c("from","to","length")],graph.edges(g)[c("from","to","length")])
})
test_that("all candidates, ties and sparse faces agree with exhaustive distances", {
    set.seed(612)
    for (d in c(1,2,5,12)) {
        X <- matrix(runif(35*d),35,d);X[X<.4] <- 0;X[,1]<-pmax(X[,1],.01)
        X <- X/apply(X,1,max);X[2,]<-X[1,];X[3,1]<-1
        exact.knn.test(X,1);exact.knn.test(X,7);exact.knn.test(X,nrow(X))
    }
})
test_that("obsolete simplex cache is rejected but Euclidean v3 remains valid", {
    X <- rbind(c(1,0,.99),c(0,1,.99),c(1,1,0),c(1,.3,.2))
    path <- tempfile();on.exit(unlink(path))
    args <- list(X=X,k=1,pca.dim=NULL,knn.metric="linf.simplex",knn.cache.path=path,
                 prune.method="none",connect.components=FALSE,verbose=FALSE)
    do.call(create.single.iknn.graph,c(args,list(knn.cache.mode="write")))
    do.call(create.single.iknn.graph,c(args,list(knn.cache.mode="read")))
    bytes <- readBin(path,"raw",n=file.info(path)$size)
    bytes[9:12] <- writeBin(3L,raw(),size=4,endian=.Platform$endian)
    writeBin(bytes,path)
    expect_error(do.call(create.single.iknn.graph,c(args,list(knn.cache.mode="read"))),"version")
    args$knn.metric <- "euclidean"
    do.call(create.single.iknn.graph,c(args,list(knn.cache.mode="write")))
    con<-file(path,"rb");seek(con,8);version<-readBin(con,"integer",1,size=4);close(con)
    expect_equal(version,3L)
    expect_s3_class(do.call(create.single.iknn.graph,c(args,list(knn.cache.mode="read"))),"dgraph")
})
test_that("near-normalized inputs follow the documented clamp and normalize rule", {
    X <- rbind(c(1 + 1e-10, -.0000000001, .99), c(0, 1 - 1e-10, .99))
    z <- .Call("S_linf_simplex_knn", X, 2L, 1e-8, PACKAGE="dgraphs")
    expected <- linf.simplex.distances(pmax(X,0))
    expect_equal(z$distances[1,2],expected[1,2],tolerance=1e-12)
    expect_error(.Call("S_linf_simplex_knn",X,2L,0,PACKAGE="dgraphs"),"positive")
    expect_error(.Call("S_linf_simplex_knn",X,3L,1e-8,PACKAGE="dgraphs"),"1 <= k")
})
