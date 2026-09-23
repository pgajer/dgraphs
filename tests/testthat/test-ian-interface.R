test_that("IAN remains internal and validates arguments before backend loading", {
 expect_false("create.ian.graph" %in% getNamespaceExports("dgraphs"))
 f <- get("create.ian.graph", asNamespace("dgraphs"))
 x <- matrix(c(0,1,2,0,1,0),3,2)
 expect_error(f(x,graph=list()),"Supplied initial graphs")
 expect_error(f(x,max.solves=1.1),"max.solves")
 expect_error(f(x,specimen.ids=c("x","x","y")),"unique")
 expect_error(f(x,distances=matrix(1,3,3)),"zero diagonal")
 expect_error(f(x,backend=tempfile()),"unavailable")
 expect_error(f(x,distances=matrix(c(0,1,2,1,0,3,2,4,0),3)),"symmetric")
 expect_error(f(matrix(NA_real_,3,2)),"finite")
})

test_that("IAN policy and minimum-row guards apply before optional backend loading", {
 f <- get("create.ian.graph", asNamespace("dgraphs"))
 x <- matrix(c(0, 1, 2, 0, 1, 0), 3, 2)
 for (policy in list(NA_character_, character(), c("IAN evaluated-LP 1.0", "bad"), "unknown"))
  expect_error(f(x, numerical.policy=policy, backend=tempfile()), "Unsupported numerical.policy")
 for (policy in c("IAN evaluated-LP 1.0", "IAN evaluated-LP retry-power 0.1"))
  expect_error(f(x, numerical.policy=policy, backend=tempfile()), "unavailable")
 expect_error(f(matrix(0, 1, 1), backend=tempfile()), "at least 2")
 for (n in c(501L, 1000L))
  expect_error(f(matrix(seq_len(n), n, 1), backend=tempfile()), "unavailable")
})

test_that("connectivity option validates before optional backend loading", {
 f <- get("create.ian.graph", asNamespace("dgraphs"))
 x <- matrix(c(0, 1, 2, 0, 1, 0), 3, 2)
 for (value in list(NA, NULL, 1, "TRUE", c(TRUE, FALSE)))
  expect_error(f(x, preserve.connectivity = value, backend = tempfile()), "preserve.connectivity")
 for (value in c(TRUE, FALSE))
  expect_error(f(x, preserve.connectivity = value, backend = tempfile()), "unavailable")
 expect_identical(formals(f)$preserve.connectivity, FALSE)
})

test_that("IAN dimensions use representation bounds without allocating large arrays", {
 f <- get(".ian.check.dimensions", asNamespace("dgraphs"))
 for (n in c(500, 501, 1000, 5000, 10000)) expect_null(f(n, 5))
 expect_error(f(.Machine$integer.max %/% 2 + 1, 1), "vertex-index")
 expect_error(f(2, as.double(.Machine$integer.max) + 1), "representation")
 if (.Machine$sizeof.pointer >= 8L) {
  expect_null(f(2^26, 1))
  expect_error(f(2^26 + 1, 1), "representation")
 }
 for (n in list(NA_real_, Inf, -1, 2.5, numeric(), c(2, 3)))
  expect_error(f(n, 1), "nonnegative integers")
})
