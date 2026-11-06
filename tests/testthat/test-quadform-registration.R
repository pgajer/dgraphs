test_that("quadform native entries have registered arities and remain internal", {
  calls <- getDLLRegisteredRoutines(getLoadedDLLs()[["dgraphs"]])$.Call
  expected <- c(`_dgraphs_rcpp_quadform_geodesics_solver`=5L,
    `_dgraphs_rcpp_quadform_geodesics_reference_uniforms`=2L,
    `_dgraphs_rcpp_quadform_geodesics_method`=6L)
  for(n in names(expected)) expect_identical(calls[[n]]$numParameters,expected[[n]])
  expect_false(getLoadedDLLs()[["dgraphs"]][["dynamicLookup"]])
  expect_false(any(c("quadform_geodesics","quadform_geodesics_solver",
    "quadform_geodesics_best_of_six") %in% getNamespaceExports("dgraphs")))
  native <- getFromNamespace("rcpp_quadform_geodesics_method","dgraphs")
  expect_error(native("invalid matrix",c(0,0),c(1,0),list(),"grid_dijkstra",list()))
  expect_error(getFromNamespace("rcpp_quadform_geodesics_reference_uniforms","dgraphs")(-1,2L))
  expect_length(getFromNamespace("rcpp_quadform_geodesics_reference_uniforms","dgraphs")(1,2L)$order,2L)
})
