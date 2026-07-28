test_that("native MST construction handles duplicate coordinates", {
  x <- rbind(
    c(0, 0),
    c(0, 0),
    c(1, 0)
  )

  mst <- .Call("S_mstree", x, PACKAGE = "dgraphs")

  expect_equal(dim(mst), c(2L, 3L))
  expect_equal(sort(mst[, "length"]), c(0, 1))
})

test_that("native MST construction validates matrix contents", {
  expect_error(
    .Call(
      "S_mstree",
      matrix(numeric(), nrow = 0L, ncol = 2L),
      PACKAGE = "dgraphs"
    ),
    "at least one row and one column"
  )
  expect_error(
    .Call(
      "S_mstree",
      matrix(c(0, NA_real_), nrow = 1L),
      PACKAGE = "dgraphs"
    ),
    "only finite values"
  )
})
