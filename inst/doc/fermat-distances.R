## ----setup, include=FALSE-----------------------------------------------------
knitr::opts_chunk$set(collapse = TRUE, comment = "#>", fig.width = 7, fig.height = 5)
library(dgraphs)

## ----small-example------------------------------------------------------------
X <- matrix(c(0, 1, 2), ncol = 1)
fermat.distances(points = X, p = 2)

## ----restrictions-------------------------------------------------------------
fermat.distances(points = X, graph.type = "sknn", k = 1, p = 2)
graph <- create.sknn.graph(X, k = 1, neighbor.method = "exact",
                          prune.edges = FALSE, connect.components = FALSE)
fermat.distances(graph, p = 2)

## ----circle-data--------------------------------------------------------------
set.seed(4101)
n <- 100
angles <- list(
  Uniform = sort(runif(n, 0, 2*pi)),
  Concentrated = sort(c(runif(n/2, 0, 2*pi),
                        rnorm(n/2, 0, 0.4) %% (2*pi)))
)
radial.noise <- rnorm(n, 0, 0.04)
circles <- lapply(angles, function(theta) {
  cbind((1 + radial.noise)*cos(theta), (1 + radial.noise)*sin(theta))
})
powers <- c(1, 2, 3)
reference <- lapply(circles, function(X) {
  lapply(powers, function(p) fermat.distances(points = X, p = p))
})

## ----paths, fig.height=5.5, fig.cap="Complete-graph shortest paths at powers 1, 2 and 3. Rows show uniform and concentrated angular sampling; axes are the observed Cartesian coordinates.", fig.alt="Six circle panels compare complete-graph paths for three powers and two angular sampling distributions. Endpoints are black, observations gray, and minimizing paths red."----
old <- par(mfrow = c(2, 3), mar = c(3, 3, 2, 0.5))
for (s in seq_along(circles)) {
  X <- circles[[s]]
  ends <- c(which.min(rowSums(sweep(X, 2, c(1,0), "-")^2)),
            which.min(rowSums(sweep(X, 2, c(-1,0), "-")^2)))
  g <- igraph::make_full_graph(n, directed = FALSE)
  e <- igraph::as_edgelist(g, names = FALSE)
  eu <- as.matrix(dist(X))
  for (j in seq_along(powers)) {
    p <- powers[j]
    weights <- eu[e]^p
    path <- as.integer(igraph::shortest_paths(g, from = ends[1], to = ends[2],
                                             weights = weights)$vpath[[1]])
    cost <- sum(eu[cbind(head(path, -1), tail(path, -1))]^p)
    stopifnot(isTRUE(all.equal(cost, reference[[s]][[j]][ends[1],ends[2]])))
    plot(X, asp = 1, pch = 16, cex = 0.5, col = "gray60",
         xlab = "x", ylab = "y", main = paste(names(circles)[s], "p =", p))
    lines(X[path, , drop = FALSE], col = "firebrick", lwd = 2)
    points(X[ends, ], pch = 16, cex = 1.1)
  }
}
par(old)

## ----comparison---------------------------------------------------------------
rows <- list()
for (s in seq_along(circles)) for (j in seq_along(powers)) {
  full <- reference[[s]][[j]]
  use <- upper.tri(full)
  for (k in c(4, 8, 16)) {
    restricted <- fermat.distances(points = circles[[s]], p = powers[j],
                                   graph.type = "sknn", k = k)
    finite <- use & is.finite(restricted)
    stopifnot(all(restricted[use] >= full[use] - 1e-10))
    agree <- is.finite(restricted[use]) &
      abs(restricted[use] - full[use]) <= 1e-10*pmax(1, full[use])
    rows[[length(rows)+1L]] <- data.frame(
      Sampling = names(circles)[s], p = powers[j], k = k,
      Unreachable = sum(use & !is.finite(restricted)),
      Agreement_percent = 100*mean(agree),
      Max_relative_error = if (any(finite))
        max(abs(restricted[finite] - full[finite])/full[finite]) else NA_real_
    )
  }
}
knitr::kable(do.call(rbind, rows), digits = 4)

## ----arm-data-----------------------------------------------------------------
source(system.file("examples", "fermat-two-arms.R", package = "dgraphs"))
arm.examples <- lapply(c(20L, 120L), function(count) {
  fermat.two.arms(seed = 6101L, width = 0.005, background = count)
})
arm.routes <- lapply(arm.examples, function(sample) {
  lapply(1:3, function(p) fermat.arm.paths(sample, p))
})

## ----arm-endpoints------------------------------------------------------------
sample <- arm.examples[[1]]
ends <- sample$background.pairs[1, ]
knitr::kable(data.frame(Endpoint = c("Start", "End"),
                       x = sample$X[ends,1], y = sample$X[ends,2],
                       Distance_to_arm = apply(sample$X[ends,,drop=FALSE],1,min)),
             digits = 3)

## ----arm-paths, fig.height=5.5, fig.cap="Paths between arm observations. Rows contain 20 and 120 background points; columns show powers 1, 2 and 3. The arm sample and endpoints are fixed across panels.", fig.alt="Six two-arm panels show complete-graph paths between fixed arm endpoints, comparing two nested background levels and three powers."----
old <- par(mfrow = c(2,3), mar = c(3,3,2,0.5))
for (s in 1:2) for (p in 1:3) {
  fermat.plot.arm.path(arm.examples[[s]], arm.routes[[s]][[p]]$paths[[1]],
                      paste(arm.examples[[s]]$background, "background; p =", p))
}
par(old)

## ----background-paths, fig.height=5.5, fig.cap="Paths between background observations near different arms, with the same samples and visual encodings. Endpoints are fixed and are not assigned generating-arm labels.", fig.alt="Six panels show paths between two fixed diffuse background observations near different arms, with 20 or 120 background points and powers 1, 2 and 3."----
old <- par(mfrow = c(2,3), mar = c(3,3,2,0.5))
for (s in 1:2) for (p in 1:3) {
  index <- nrow(arm.examples[[s]]$arm.pairs) + 1L
  fermat.plot.arm.path(arm.examples[[s]], arm.routes[[s]][[p]]$paths[[index]],
                      paste(arm.examples[[s]]$background, "background; p =", p))
}
par(old)

## ----arm-scores---------------------------------------------------------------
shown <- do.call(rbind, lapply(1:2, function(s) do.call(rbind,lapply(1:3,function(p) {
  scores <- arm.routes[[s]][[p]]$scores[c(1,11),]
  data.frame(Background=arm.examples[[s]]$background, Power=p,
             Endpoints=scores$type, Junction=ifelse(scores$junction==1,"Yes","No"),
             Arm_coverage_percent=100*scores$arm.fraction)
}))))
knitr::kable(shown, digits=1)

## ----arm-restriction-check----------------------------------------------------
arm.agreement <- list()
for (s in 1:2) for (p in 1:3) {
  result <- arm.routes[[s]][[p]]
  vertices <- sort(unique(as.vector(result$pairs)))
  index <- cbind(match(result$pairs[,1],vertices),match(result$pairs[,2],vertices))
  full <- fermat.distances(points=arm.examples[[s]]$X,p=p,vertices=vertices)[index]
  stopifnot(max(abs(full-result$scores$cost)) < 1e-10)
  restricted <- lapply(c(8,16),function(k) {
    fermat.distances(points=arm.examples[[s]]$X,p=p,vertices=vertices,
                     graph.type="sknn",k=k)[index]
  })
  agree <- vapply(restricted,function(d) {
    stopifnot(all(d >= full-1e-10))
    100*mean(is.finite(d) & abs(d-full)<=1e-10*pmax(1,full))
  },0)
  arm.agreement[[length(arm.agreement)+1L]] <- data.frame(
    Background=arm.examples[[s]]$background, Power=p, Pairs=length(full),
    Agreement_k8_percent=agree[1], Agreement_k16_percent=agree[2],
    Unreachable=sum(!is.finite(unlist(restricted))))
}
knitr::kable(do.call(rbind,arm.agreement),digits=1)

## ----arm-seed-summary---------------------------------------------------------
seed.scores <- list()
for (seed in 6101:6112) for (width in c(0.005,0.05)) for (count in c(20L,120L)) {
  sample <- fermat.two.arms(seed, width, count)
  scores <- fermat.arm.paths(sample, p=2)$scores
  means <- aggregate(scores[c("junction","arm.fraction")],list(Endpoints=scores$type),mean)
  means$Seed <- seed; means$Width <- width; means$Background <- count
  seed.scores[[length(seed.scores)+1L]] <- means
}
seed.scores <- do.call(rbind,seed.scores)
set.seed(8201)
mean.interval <- function(x) {
  boot <- replicate(2000,mean(sample(x,replace=TRUE)))
  sprintf("%.1f (%.1f–%.1f)",100*mean(x),
          100*quantile(boot,.025),100*quantile(boot,.975))
}
seed.summary <- do.call(rbind,lapply(split(seed.scores,
  interaction(seed.scores[c("Width","Background","Endpoints")],drop=TRUE)),function(d) {
    data.frame(d[1,c("Width","Background","Endpoints")],
               Junction_percent=mean.interval(d$junction),
               Arm_coverage_percent=mean.interval(d$arm.fraction))
}))
rownames(seed.summary) <- NULL
knitr::kable(seed.summary)

## ----implicit-pivots----------------------------------------------------------
X <- circles[[1]]
pivots <- c(1L, 14L, 27L, 40L, 53L, 66L, 79L, 92L)
pivot.distances <- fermat.distances(points = X, p = 2,
    backend = "implicit", sources = pivots)
stopifnot(isTRUE(all.equal(pivot.distances,
                          reference[[1]][[2]][pivots, , drop = FALSE])))
dim(pivot.distances)
# Rectangular queries preserve the supplied row and column order.
fermat.distances(points = X, backend = "implicit", sources = pivots[1:2],
                targets = c(25L, 50L, 75L))

## ----fermat-constraints-------------------------------------------------------
source(system.file("examples", "fermat-sparse-mds.R", package = "dgraphs"))
constraints <- fermat.mds.constraints(X, pivots, k = 4, p = 2)
stopifnot(max(abs(constraints$targets -
                 reference[[1]][[2]][constraints$pairs])) < 1e-10)
c(retained = nrow(constraints$pairs), all.pairs = choose(nrow(X), 2))

## ----sparse-fermat-fit, eval=FALSE--------------------------------------------
# fit <- grip::metric.mds(n = nrow(X), approximation = "sparse",
#                        constraints = constraints, seed = 1, max.iter = 100)
# plot(fit$coords, asp = 1, pch = 16)

## ----exact-fermat-neighbors---------------------------------------------------
set.seed(193)
neighbor.points <- matrix(runif(120), 60, 2)
neighbors <- fermat.knn(neighbor.points, k = 6, p = 2)
neighbor.graph <- create.fermat.sknn.graph(neighbor.points, k = 6, p = 2)
reference <- fermat.distances(points = neighbor.points, p = 2)
selected <- cbind(rep(seq_len(nrow(neighbor.points)), 6),
                  as.vector(neighbors$index))
stopifnot(max(abs(as.vector(neighbors$distance) - reference[selected])) < 1e-10)

