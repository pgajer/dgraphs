test_that("one-point draws and embeddings retain every matrix dimension", {
  for (d in c(1L, 2L, 3L)) for (heights in 0:2) for (n in c(1L, 3L)) {
    forms <- lapply(seq_len(heights), function(j) diag(seq_len(d) / j, nrow = d, ncol = d))
    canonical <- d + heights
    for (policy in c("canonical", "supplied", "random.orthonormal")) {
      ambient <- canonical + as.integer(policy != "canonical")
      frame <- if (policy == "supplied") rbind(diag(canonical), rep(0, canonical)) else NULL
      g <- synthetic.quadform(d, ambient, forms, frame = policy, frame.matrix = frame)
      for (ordering in c("draw", "ascending.first.coordinate")) {
        s <- synthetic.sampling.uniform.box(-1, 1, order = ordering)
        a <- sample.synthetic.geometry(g, s, n, seed = 19)
        expect_identical(dim(a$latent), c(n, d))
        expect_identical(dim(a$predictors), c(n, ambient))
        q <- matrix(0, n, heights)
        for (i in seq_len(n)) for (j in seq_len(heights))
          q[i,j] <- sum(a$latent[i,] * (forms[[j]] %*% a$latent[i,]))
        z <- cbind(a$latent, q)
        f <- if (policy == "canonical") diag(canonical) else if (policy == "supplied") frame else a$frame.matrix
        expect_equal(unname(a$predictors), unname(z %*% t(f)), tolerance = 1e-14)
        if (ordering != "draw") expect_false(is.unsorted(a$latent[,1]))
      }
    }
  }
  g <- synthetic.quadform(2, 4, list(diag(2), diag(c(1,-1))))
  a <- sample.synthetic.geometry(g, synthetic.sampling.uniform.disk(), 1, seed=19)
  expect_identical(dim(a$predictors), c(1L,4L))
  u <- a$latent[1,]
  expect_equal(unname(a$predictors[1,]), c(u, sum(u^2), u[1]^2-u[2]^2))
})

test_that("current-stream mode preserves selected generators and hidden normal continuation", {
  kinds <- RNGkind(); withr::defer(do.call(RNGkind, as.list(kinds)))
  for (kind in c("Mersenne-Twister", "L'Ecuyer-CMRG", "Wichmann-Hill")) {
    for (normal in c("Inversion", "Box-Muller")) {
      RNGkind(kind,normal,"Rejection")
      selected.kinds <- RNGkind(); set.seed(93); invisible(rnorm(1))
      expected <- matrix(runif(4,-1,1),2,2); following <- rnorm(5); end <- .Random.seed
      set.seed(93); invisible(rnorm(1))
      a <- sample.synthetic.geometry(synthetic.quadform(2,2),
        synthetic.sampling.uniform.box(-1,1),2,rng.plan="current")
      expect_identical(a$latent,expected)
      expect_identical(rnorm(5),following)
      expect_identical(.Random.seed,end)
      expect_identical(RNGkind(),selected.kinds)
      expect_identical(a$rng$plan,"current")
    }
  }
  expect_error(sample.synthetic.geometry(synthetic.circle(),
    synthetic.sampling.uniform.interval(0,1),1,seed=2,rng.plan="current"),"exactly one")
})

test_that("deterministic current-stream sampling does not create a seed", {
  if (exists(".Random.seed", .GlobalEnv, inherits=FALSE)) rm(".Random.seed",envir=.GlobalEnv)
  a <- sample.synthetic.geometry(synthetic.circle(),
    synthetic.sampling.grid.interval(0,1),1,rng.plan="current")
  expect_false(exists(".Random.seed", .GlobalEnv, inherits=FALSE))
  expect_null(a$rng$final.state)
})

test_that("current-stream errors retain draws already consumed", {
  RNGkind("Mersenne-Twister","Inversion","Rejection")
  set.seed(39); invisible(runif(2,1,1.1)); expected <- .Random.seed
  set.seed(39)
  expect_error(sample.synthetic.geometry(synthetic.sphere.cap(2,.25),
    synthetic.sampling.uniform.box(1,1.1),1,rng.plan="current"),"footprint")
  expect_identical(.Random.seed,expected)
})


test_that("successful singleton single-height names retain their legacy behavior", {
  g <- synthetic.quadform(1,2,list(height=matrix(.5)))
  u <- matrix(2,nrow=1)
  x <- embed.synthetic.geometry(g,u)
  expect_identical(dim(x),c(1L,2L))
  expect_identical(rownames(x),"height")
  expect_identical(unname(x),matrix(c(2,2),nrow=1))
  rownames(u) <- "sample"
  expect_identical(rownames(embed.synthetic.geometry(g,u)),"sample")
})
