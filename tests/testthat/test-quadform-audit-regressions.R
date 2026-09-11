local({
  solve <- getFromNamespace("quadform_geodesics_solver", "dgraphs")
  box <- list(kind="box",lower=c(-2e16,-2e16),upper=c(2e16,2e16))
  test_that("returned heights survive exact-input cancellation", {
    A <- matrix(c(1,1,1,1+2^-52),2)
    a <- c(1e16,-1e16)
    # (x+y)^2 + 2^-52*y^2, evaluated independently for these exact inputs.
    expected <- 22204460492503132
    for (method in c("single_point","local_network")) {
      identity <- solve(A,a,a,box,method=method,cache_edges=0)
      expect_identical(identity$surface_path[,3],rep(expected,2))
      z <- solve(A,a,a+c(1e12,0),box,method=method,initial_edges=4L,
        max_epochs=0L,random_orientation=FALSE,cache_edges=0)
      expect_identical(z$status,"candidate")
      expect_identical(z$surface_path[1,3],expected)
    }
    huge <- list(kind="box",lower=c(-2e200,-2e200),upper=c(2e200,2e200))
    z <- solve(matrix(1,2,2),c(1e200,-1e200),c(1e200,-1e200),huge)
    expect_identical(z$surface_path[,3],c(0,0))
    expect_error(solve(diag(c(.Machine$double.xmax,0)),c(2,0),c(2,0),box),
      "Surface height overflow")
  })
  test_that("close endpoints admit distinct equal-length initial subdivisions", {
    domain <- list(kind="box",lower=c(-200,-200),upper=c(200,200))
    for (distance in 10^seq(-14,2,by=2)) for (edges in c(2L,3L,4L,16L,256L)) {
      z <- solve(matrix(0,2,2),c(0,0),c(distance,0),domain,initial_edges=edges,
        max_epochs=0L,max_edge_calls=Inf,cache_edges=0,random_orientation=FALSE)
      expect_identical(z$status,"candidate")
      expect_equal(nrow(z$path),edges+1L)
      lengths <- diff(z$path[,1])
      expect_true(all(lengths > 0))
      expect_lt(max(abs(lengths/(distance/edges)-1)),3e-6)
    }
  })
  test_that("failed exploration is not labelled local stagnation", {
    domain <- list(kind="box",lower=c(-1,-1e-100),upper=c(1,1e-100))
    for (method in c("single_point","local_network")) {
      z <- solve(diag(2),c(-.9,0),c(.9,0),domain,method=method,
        initial_edges=4L,candidates=2L,rejection_cap=100L,max_epochs=3L,
        plateau_epochs=2L,random_orientation=FALSE,cache_edges=0)
      expect_identical(z$termination,"incomplete_exploration")
      expect_gt(z$counters$sampling_shortfalls,0)
      expect_identical(z$path,z$initial_path)
      expect_equal(z$counters$accepted_replacements,0)
    }
  })
})
