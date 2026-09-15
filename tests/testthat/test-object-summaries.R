test_that("sample output is bounded, informative, invisible and RNG neutral", {
  for (n in c(1,5,10000)) {
    x <- sample.synthetic.geometry(synthetic.circle(),synthetic.sampling.uniform.interval(0,2*pi),n=n,seed=17)
    set.seed(41); before <- .Random.seed
    text <- capture.output(returned <- withVisible(print(x)))
    expect_lte(length(text),6L)
    expect_false(returned$visible); expect_identical(returned$value,x)
    expect_match(paste(text,collapse=" "),"isolated seed/state")
    s <- summary(x); expect_equal(s$n,n)
    expect_equal(unname(s$ranges),t(apply(x$predictors,2,range)))
    expect_identical(.Random.seed,before)
  }
  x <- sample.synthetic.geometry(synthetic.circle(),synthetic.sampling.uniform.interval(0,2*pi),n=1,rng.plan="current")
  expect_output(print(x),"current stream")
  x$region <- "point"; expect_equal(unname(summary(x)$regions),structure(1L,dim=1L))
})
test_that("path series reports stored graph and route counts", {
  x <- create.path.graph(create.graph("chain",6),h.values=1:12)
  s <- summary(x)
  expect_equal(s$h,1:12); expect_equal(s$vertices,rep(6,12))
  expect_equal(s$edges[1:2],c(5,9)); expect_equal(s$routes,s$edges)
  text <- capture.output(out <- withVisible(print(x)))
  expect_lte(length(text),14); expect_false(out$visible); expect_identical(out$value,x)
})
