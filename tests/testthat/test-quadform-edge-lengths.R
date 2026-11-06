local({
  solve <- getFromNamespace("quadform_geodesics_solver", "dgraphs")
  direct <- function(A,a,b) {
    bound <- 2*pmax(1,abs(a),abs(b))
    solve(A,a,b,list(kind="box",lower=-bound,upper=bound),
      cache_edges=0L,max_edge_calls=1,max_epochs=0L,random_orientation=FALSE)
  }
  test_that("analytic lengths cover narrow minima, cancellation and extreme scales", {
    fixtures <- read.csv(test_path("fixtures","quadform-edge-lengths.csv"),colClasses="character")
    numeric <- setdiff(names(fixtures),c("case","reference_digits"))
    fixtures[numeric] <- lapply(fixtures[numeric],as.numeric)
    expect_equal(nrow(fixtures),47L)
    for(i in seq_len(nrow(fixtures))) {
      x <- fixtures[i,]
      A <- matrix(c(x$A11,x$A12,x$A12,x$A22),2)
      a <- c(x$a1,x$a2); b <- c(x$b1,x$b2)
      for(reverse in c(FALSE,TRUE)) {
        z <- if(reverse) direct(A,b,a) else direct(A,a,b)
        expect_true(is.finite(z$length),info=x$case)
        # The independent 300-digit reference is rounded when read into R.
        rounding <- .Machine$double.eps*abs(x$reference)+5e-324
        expect_lte(abs(z$length-x$reference),z$error_estimate+rounding,label=x$case)
        expect_equal(z$counters$integrand_evaluations,0)
        expect_equal(z$counters$cache_entries,0)
      }
    }
  })
  test_that("analytic direct lengths remain additive across a narrow minimum", {
    A <- diag(c(25000000,0)); a <- c(-.0004,0); b <- c(.9996,0)
    whole <- direct(A,a,b)
    expect_equal(whole$length,24980008.00000030,tolerance=1e-15)
    for(t in c(.0004,.002171418,.5,1-1e-12)) {
      p <- a+t*(b-a); left <- direct(A,a,p); right <- direct(A,p,b)
      allowance <- whole$error_estimate+left$error_estimate+right$error_estimate
      expect_lte(abs(whole$length-left$length-right$length),allowance)
    }
  })
  test_that("constant vertical tangents have their exact straight lifted length", {
    z <- direct(diag(c(1,-1)),c(1,0),c(2,1))
    expect_lte(abs(z$length-sqrt(6)),z$error_estimate)
    z <- direct(matrix(0,2,2),c(0,0),c(1e-300,1e-300))
    expect_equal(z$length/1e-300,sqrt(2),tolerance=1e-14)
  })
})
