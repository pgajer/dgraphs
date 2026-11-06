# Reproducible teaching helpers, not exported package functions.
# Coordinate units: arm length = 1. No arm membership is assigned to background.
fermat.two.arms <- function(seed = 6101L, width = 0.005, background = 20L) {
    stopifnot(width >= 0, background %in% c(20L, 60L, 120L))
    set.seed(seed)
    radial <- runif(160)
    transverse <- abs(rnorm(160))
    diffuse <- matrix(runif(240), ncol = 2)
    X.arm <- rbind(cbind(radial[1:80], width*transverse[1:80]),
                   cbind(width*transverse[81:160], radial[81:160]))
    stopifnot(max(X.arm) <= 1) # all predeclared draws lie in the unit square
    X <- rbind(X.arm, diffuse[seq_len(background), , drop = FALSE])
    # Pair identities are fixed across widths and nested background levels.
    a <- which(radial[1:80] > 0.35)[1:10]
    b <- 80L + which(radial[81:160] > 0.35)[1:10]
    arm.pairs <- cbind(a, b)
    base <- diffuse[1:20, , drop = FALSE]
    eligible <- apply(base, 1, min) > 0.08 & apply(base, 1, max) < 0.9 &
        apply(base, 1, max) > 0.3
    h <- which(eligible & base[,1] > base[,2])
    v <- which(eligible & base[,2] > base[,1])
    bg.pairs <- as.matrix(expand.grid(h, v))
    if (nrow(bg.pairs)) {
        score <- rowSums(sweep(base[bg.pairs[,1],,drop=FALSE],2,c(.65,.18),"-")^2) +
            rowSums(sweep(base[bg.pairs[,2],,drop=FALSE],2,c(.18,.65),"-")^2)
        bg.pairs <- bg.pairs[head(order(score), 12),,drop=FALSE] + 160L
    }
    list(X = X, arm.pairs = arm.pairs, background.pairs = bg.pairs,
         width = width, background = background, seed = seed)
}

# Parameter interval where a segment a + t*(b-a), 0 <= t <= 1, is in a rectangle.
fermat.rectangle.interval <- function(a, b, upper) {
    lo <- 0; hi <- 1
    for (j in 1:2) {
        delta <- b[j]-a[j]
        if (delta == 0) {
            if (a[j] < 0 || a[j] > upper[j]) return(c(0,0))
        } else {
            bounds <- sort(c(-a[j]/delta, (upper[j]-a[j])/delta))
            lo <- max(lo,bounds[1]); hi <- min(hi,bounds[2])
        }
    }
    if (hi <= lo) c(0,0) else c(lo,hi)
}

fermat.arm.path.scores <- function(X, path, tube = 0.05, junction = 0.1) {
    a <- X[head(path,-1),,drop=FALSE]; b <- X[tail(path,-1),,drop=FALSE]
    length <- sqrt(rowSums((b-a)^2))
    inside <- numeric(nrow(a)); min.radius <- Inf
    for (i in seq_len(nrow(a))) {
        h <- fermat.rectangle.interval(a[i,],b[i,],c(1,tube))
        v <- fermat.rectangle.interval(a[i,],b[i,],c(tube,1))
        inside[i] <- diff(h)+diff(v)-max(0,min(h[2],v[2])-max(h[1],v[1]))
        d <- b[i,]-a[i,]
        t <- if (sum(d^2)==0) 0 else max(0,min(1,-sum(a[i,]*d)/sum(d^2)))
        min.radius <- min(min.radius,sqrt(sum((a[i,]+t*d)^2)))
    }
    c(junction = as.numeric(min.radius <= junction),
      arm.fraction = sum(length*inside)/sum(length),
      min.radius = min.radius, euclidean.length = sum(length))
}

fermat.arm.paths <- function(sample, p) {
    X <- sample$X
    g <- igraph::make_full_graph(nrow(X), directed=FALSE)
    e <- igraph::as_edgelist(g, names=FALSE)
    eu <- as.matrix(stats::dist(X)); weights <- eu[e]^p
    pairs <- rbind(sample$arm.pairs,sample$background.pairs)
    paths <- lapply(seq_len(nrow(pairs)),function(i) {
        as.integer(igraph::shortest_paths(g,from=pairs[i,1],to=pairs[i,2],
                                         weights=weights)$vpath[[1]])
    })
    scores <- as.data.frame(t(vapply(paths,function(path) fermat.arm.path.scores(X,path),numeric(4))))
    scores$type <- c(rep("Arm endpoints",nrow(sample$arm.pairs)),
                     rep("Background endpoints",nrow(sample$background.pairs)))
    scores$from <- pairs[,1]; scores$to <- pairs[,2]
    scores$cost <- vapply(paths,function(path) sum(eu[cbind(head(path,-1),tail(path,-1))]^p),0)
    scores$start.arm.distance <- apply(X[pairs[,1],,drop=FALSE],1,min)
    scores$end.arm.distance <- apply(X[pairs[,2],,drop=FALSE],1,min)
    list(paths=paths,scores=scores,pairs=pairs)
}

fermat.plot.arm.path <- function(sample, path, main = "") {
    X <- sample$X
    plot(X,type="n",asp=1,xlim=c(0,1),ylim=c(0,1),xlab="x",ylab="y",main=main)
    rect(0,0,1,.05,col="gray94",border=NA); rect(0,0,.05,1,col="gray94",border=NA)
    lines(.1*cos(seq(0,pi/2,length.out=80)),.1*sin(seq(0,pi/2,length.out=80)),lty=2)
    points(X[1:160,],pch=16,cex=.35,col="steelblue")
    points(X[-(1:160),,drop=FALSE],pch=4,cex=.55,col="gray45")
    lines(X[path,,drop=FALSE],col="firebrick",lwd=2)
    points(X[path[c(1,length(path))],,drop=FALSE],pch=21,bg="black",cex=.85)
}
