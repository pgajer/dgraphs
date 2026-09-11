test_that("quadform embedding supports independent intrinsic and ambient dims", {
  frame <- rbind(diag(3), matrix(0, nrow = 2, ncol = 3))
  geometry <- synthetic.quadform(
    intrinsic.dim = 2, ambient.dim = 5,
    forms = list(diag(c(0.5, -0.25))),
    frame = "supplied", frame.matrix = frame,
    offset = c(1, -1, 0, 2, -2))
  latent <- rbind(c(0, 0), c(1, 2))
  observed <- embed.synthetic.geometry(geometry, latent)
  canonical <- cbind(latent, 0.5 * latent[, 1]^2 -
                               0.25 * latent[, 2]^2)
  expect_equal(
    observed,
    sweep(canonical %*% t(frame), 2, geometry$parameters$offset, "+"),
    tolerance = 1e-14)
  expect_identical(dim(observed), c(2L, 5L))
})

test_that("quadform gradient and metric agree with finite differences", {
  form <- matrix(c(0.8, 0.2, 0.2, -0.4), 2)
  geometry <- synthetic.quadform(
    2, 3, forms = list(form), frame = "canonical")
  point <- matrix(c(0.4, -0.7), nrow = 1)
  gradient <- quadform.gradient(geometry, point)
  expect_equal(gradient, matrix(2 * form %*% point[1, ], nrow = 1),
               tolerance = 1e-14)
  expected.metric <- diag(2) + tcrossprod(as.numeric(gradient))
  expect_equal(quadform.metric(geometry, point), expected.metric,
               tolerance = 1e-14)

  eps <- 1e-6
  jacobian <- vapply(seq_len(2), function(j) {
    plus <- point
    minus <- point
    plus[1, j] <- plus[1, j] + eps
    minus[1, j] <- minus[1, j] - eps
    as.numeric(
      (embed.synthetic.geometry(geometry, plus) -
         embed.synthetic.geometry(geometry, minus)) / (2 * eps))
  }, numeric(3))
  expect_equal(crossprod(jacobian), expected.metric, tolerance = 1e-8)
})

test_that("quadform segment lengths include the flat and curved contracts", {
  flat <- synthetic.quadform(2, 2, frame = "canonical")
  from <- rbind(c(0, 0), c(1, -1))
  to <- rbind(c(3, 4), c(1, -1))
  expect_equal(
    edge.lengths.synthetic.geometry(flat, from, to),
    c(5, 0), tolerance = 1e-14)

  curved <- synthetic.quadform(
    2, 3, forms = list(diag(c(1, -1))), frame = "canonical")
  length <- edge.lengths.synthetic.geometry(
    curved, matrix(c(0, 0), 1), matrix(c(1, 0), 1))
  numerical <- stats::integrate(
    function(t) sqrt(1 + 4 * t^2), 0, 1)$value
  expect_equal(length, numerical, tolerance = 1e-10)
})

test_that("geometry domain and frame contracts fail early", {
  expect_error(
    synthetic.quadform(2, 4, forms = list(diag(2)), frame = "canonical"),
    "canonical frame")
  sphere <- synthetic.sphere.cap(radius = 2, footprint.radius = 1)
  expect_error(
    embed.synthetic.geometry(sphere, matrix(c(1.1, 0), 1)),
    "outside")
  random <- synthetic.quadform(
    2, 3, forms = list(diag(2)), frame = "random.orthonormal")
  expect_error(
    embed.synthetic.geometry(random, matrix(c(0, 0), 1)),
    "requires a realized frame")
})

test_that("strata compose without conflating point-line and G4 geometries", {
  point <- synthetic.stratum.point("origin", c(0, 0, 0))
  line <- synthetic.stratum.segment(
    "axis", c(0, 1), c(0, 0, 0), c(1, 0, 0))
  rectangle <- synthetic.stratum.rectangle(
    "face", rbind(c(0, 1), c(-1, 1)), c(0, 0, 0),
    cbind(c(1, 0, 0), c(0, 1, 0)))
  geometry <- synthetic.stratified(list(point, line, rectangle))
  expect_identical(
    geometry$parameters$intrinsic.dim.by.region,
    c(origin = 0L, axis = 1L, face = 2L))

  junction <- synthetic.point.line.junction(
    c(0, 0), c(0, 0), c(1, 0), c(0, 1))
  expect_identical(junction$parameters$declared.regions,
                   c("point", "line"))
  expect_error(
    synthetic.stratum.segment(
      "bad", c(0, 1), c(0, 0), c(2, 0)),
    "unit length")
})
