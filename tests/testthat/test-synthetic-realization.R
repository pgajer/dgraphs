test_that("geometry realization preserves caller state and explicit continuation", {
  g <- synthetic.quadform(2, 4, list(diag(c(1, -1))), frame = "random.orthonormal")
  s <- synthetic.sampling.uniform.box(-1, 1)
  set.seed(29); old <- .Random.seed; kinds <- RNGkind()
  a <- sample.synthetic.geometry(g, s, 12, seed = 13)
  expect_identical(.Random.seed, old); expect_identical(RNGkind(), kinds)
  expect_identical(a, sample.synthetic.geometry(g, s, 12, rng.plan = a$rng$plan))
  expect_identical(dim(a$predictors), c(12L, 4L))
  expect_equal(crossprod(a$frame.matrix), diag(3), tolerance = 1e-12)
  expect_false(any(c("truth", "response", "dataset.id") %in% names(a)))
  plan <- a$rng$plan; plan$order <- "frame.sampling"
  b <- sample.synthetic.geometry(g, s, 12, rng.plan = plan)
  expect_identical(a$predictors, b$predictors)
  expect_identical(a$rng$final.state, a$rng$frame.after)
  expect_identical(b$rng$final.state, b$rng$sampling.after)
  expect_identical(.Random.seed, old)
})

test_that("legacy continuation matches direct seeded draws", {
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")
  set.seed(31); state <- .Random.seed
  expected <- matrix(runif(10, -2, 3), ncol = 1)
  continuation <- .Random.seed
  set.seed(99); before <- .Random.seed
  result <- sample.synthetic.geometry(synthetic.quadform(1, 1),
    synthetic.sampling.uniform.interval(-2, 3), 10,
    rng.plan = list(version=1L, order="frame.sampling", sampling=state, frame=NULL))
  expect_identical(result$latent, expected)
  expect_identical(result$rng$final.state, continuation)
  expect_identical(.Random.seed, before)
})

test_that("absence of caller seed is preserved on success and invalid plans", {
  if (exists(".Random.seed", .GlobalEnv, inherits=FALSE)) rm(".Random.seed", envir=.GlobalEnv)
  g <- synthetic.circle(); s <- synthetic.sampling.uniform.interval(0, 2*pi)
  a <- sample.synthetic.geometry(g, s, 5, seed=13)
  expect_false(exists(".Random.seed", .GlobalEnv, inherits=FALSE))
  bad <- a$rng$plan; bad$sampling[1] <- 1L
  expect_error(sample.synthetic.geometry(g,s,5,rng.plan=bad), "complete")
  expect_false(exists(".Random.seed", .GlobalEnv, inherits=FALSE))
  expect_error(sample.synthetic.geometry(g,s,5,seed=1,rng.plan=a$rng$plan), "exactly one")
  expect_false(exists(".Random.seed", .GlobalEnv, inherits=FALSE))
})

test_that("new interfaces work and reject retained legacy components explicitly", {
  expect_s3_class(sample.synthetic.geometry(synthetic.circle(),
    synthetic.sampling.grid.interval(0, 2*pi), 5, seed=2), "synthetic_geometry_sample")
  legacy <- structure(list(kind="sampling", family="stratified.g4", version=1L,
    parameters=list(fraction.a=.5)),class=c("synthetic_sampling","synthetic_component"))
  expect_error(validate.synthetic.sampling(legacy), "Legacy G4")
  expect_error(sample.synthetic.geometry(synthetic.circle(),legacy,5,seed=2), "Legacy G4")
  g <- structure(list(kind="geometry", family="g4.segment.rectangle", version=1L,
    parameters=list()),class=c("synthetic_geometry","synthetic_component"))
  expect_error(validate.synthetic.geometry(g), "Legacy G4")
  expect_false("synthetic.sampling.stratified" %in% getNamespaceExports("dgraphs"))
  expect_error(validate.synthetic.sampling(synthetic.sampling.uniform.disk(1),
    synthetic.circle()), "dimension")
})

test_that("simplex and clustered samples retain allocation metadata", {
  a <- sample.synthetic.geometry(synthetic.simplex(3),
    synthetic.sampling.dirichlet.zeros(rep(1,3),.25,1L), 20, seed=5)
  expect_equal(rowSums(a$predictors), rep(1,20))
  expect_identical(sum(a$region=="zero"), 5L)
  expect_identical(a$intrinsic.dim.by.region,c(interior=2L,zero=1L))
  expect_identical(a$codimension.by.region,c(interior=1L,zero=2L))
  expect_identical(a$declared.regions,c("interior","zero"))
  expect_identical(a$observed.regions,c("interior","zero"))
  no.zero <- sample.synthetic.geometry(synthetic.simplex(3),
    synthetic.sampling.dirichlet.zeros(rep(1,3),0,1L), 20, seed=5)
  expect_identical(no.zero$observed.regions,"interior")
  expect_identical(no.zero$declared.regions,c("interior","zero"))
  b <- sample.synthetic.geometry(synthetic.quadform(2,2),
    synthetic.sampling.clustered(3,4,within.sd=.1), seed=5)
  expect_identical(b$n, 12L)
  expect_identical(b$sample$parameters$cluster, rep(1:3,each=4))
  expect_error(sample.synthetic.geometry(synthetic.quadform(2,2),
    synthetic.sampling.clustered(3,4,within.sd=.1), n=13, seed=5), "fixed size")
})


test_that("Geometry Lab policy preserves disk draw order and continuation", {
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")
  set.seed(4101); state <- .Random.seed
  radius <- sqrt(runif(30)); theta <- runif(30,0,2*pi)
  uv <- cbind(radius*cos(theta),radius*sin(theta)); after <- .Random.seed
  a <- sample.synthetic.geometry(synthetic.quadform(2,3,list(diag(c(1,-1)))),
    synthetic.sampling.quadform.lab("disk"),30,
    rng.plan=list(version=1L,order="sampling.frame",sampling=state,frame=NULL))
  expect_identical(a$latent,uv)
  expect_identical(a$rng$final.state,after)
  expect_identical(a$predictors,cbind(uv,uv[,1]^2+2*0*uv[,1]*uv[,2]-uv[,2]^2))
  expect_error(validate.synthetic.sampling(synthetic.sampling.quadform.lab(),
    synthetic.circle()), "requires a canonical")
  expect_error(synthetic.sampling.quadform.lab(algorithm="v2"),"Unknown")
})
