test_that("surface overlay meshes use Plotly row-y / column-x coordinates", {
  skip_if_not_installed("plotly")
  helper <- system.file("examples", "fermat-surfaces.R", package = "dgraphs")
  local <- test_path("..", "..", "inst", "examples", "fermat-surfaces.R")
  if (file.exists(local)) helper <- local
  env <- new.env(parent = globalenv())
  sys.source(helper, env)
  for (shape in c("paraboloid", "saddle")) {
    co <- if (shape == "saddle") c(1, 0, -1) else c(1, 0, 1)
    uv <- rbind(c(-.5, 0), c(0, .5), c(.2, -.3), c(.3, .1))
    X <- embed.quadform.surface(uv, co)
    graph <- dgraph(list(2L, c(1L,3L), c(2L,4L), 3L),
                  list(1, c(1,1), c(1,1), 1))
    result <- list(sample = list(shape = shape, predictors = X, latent = uv),
      layouts = list(p2_k0 = list(ids = 1:4, coords = X, graph = graph)))
    widget <- plotly::plotly_build(env$fermat.surface.overlay(result))
    mesh <- widget$x$data[[1]]
    expected <- outer(mesh$y, mesh$x, function(y, x) x^2 + co[3]*y^2)
    keep <- outer(mesh$y^2, mesh$x^2, "+") <= 1
    expect_equal(unname(mesh$z[keep]), unname(expected[keep]), tolerance = 1e-12)
    expect_true(all(is.na(mesh$z[!keep])))
  }
})
