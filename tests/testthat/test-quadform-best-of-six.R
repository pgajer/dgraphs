local({
  best <- getFromNamespace("quadform_geodesics_best_of_six", "dgraphs")
  single <- getFromNamespace("quadform_geodesics_solver", "dgraphs")
  input <- list(A = diag(c(8, 8)), from = c(-.45, -.2), to = c(.4, -.1),
    domain = list(kind = "ball", center = c(0, 0), radius = 1), seed = 13,
    length_scale = 32.0624390837628, initial_edges = 8L, candidates = 8L, max_epochs = 2L)
  run <- function(...) do.call(best, modifyList(input, list(...)))
  test_that("six results reproduce direct calls and minimum selection", {
    x <- run(); s <- x$ensemble$summary
    expect_identical(x$ensemble$status, "complete")
    expect_length(x$ensemble$results, 6L)
    expect_identical(x$ensemble$selected_index, which.min(s$length))
    expect_identical(x$length, min(s$length))
    expect_equal(x$ensemble$total_edge_calls, sum(s$edge_calls))
    for (i in seq_len(6L)) {
      z <- do.call(single, c(input, list(method = s$method[i], neighborhood = s$neighborhood[i],
        plateau_epochs = 3L, cache_edges = 0L, max_edge_calls = Inf)))
      actual <- x$ensemble$results[[i]]
      z$counters$elapsed_seconds <- actual$counters$elapsed_seconds <- NULL
      expect_identical(actual, z)
      expect_identical(actual$initial_path, x$ensemble$results[[1L]]$initial_path)
    }
  })
  test_that("default budgets are 64 rounds and numerical ties retain the minimum", {
    expect_identical(formals(best)$max_epochs, 64L)
    x <- run(A = matrix(0, 2, 2))
    expect_equal(x$length, sqrt(sum((input$to - input$from)^2)), tolerance = 1e-13)
    expect_identical(x$ensemble$tied_indices, 1:6)
    expect_identical(x$ensemble$selected_index, 1L)
    expect_true(all(x$ensemble$summary$rounds_completed))
  })
  test_that("safety limits expose incomplete and missing paths", {
    x <- run(max_edge_calls = 0)
    expect_identical(x$status, "no_path")
    expect_identical(x$ensemble$status, "no_path")
    expect_true(is.na(x$ensemble$selected_index))
    expect_length(x$ensemble$tied_indices, 0L)
    expect_equal(x$ensemble$total_edge_calls, 0)
    x <- run(max_edge_calls = 1)
    expect_identical(x$ensemble$status, "partial")
    expect_identical(x$status, "direct_fallback")
    expect_equal(x$ensemble$total_edge_calls, 6)
    expect_true(all(x$ensemble$summary$usable))
    expect_false(any(x$ensemble$summary$rounds_completed))
    x <- run(max_seconds = 0)
    expect_identical(x$ensemble$status, "no_path")
  })
  test_that("identity, invalid inputs and absent R RNG are handled", {
    x <- run(to = input$from)
    expect_equal(x$length, 0); expect_identical(x$ensemble$status, "complete")
    expect_error(run(max_epochs = NA_real_), "max_epochs")
    expect_error(run(max_epochs = .5), "max_epochs")
    expect_error(run(seed = -1), "seed")
    old <- get0(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    on.exit({
      if (is.null(old)) {
        if (exists(".Random.seed", .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
      } else assign(".Random.seed", old, envir = .GlobalEnv)
    }, add = TRUE)
    if (exists(".Random.seed", .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
    invisible(run(max_epochs = 0L))
    expect_false(exists(".Random.seed", .GlobalEnv, inherits = FALSE))
    expect_false("quadform_geodesics_best_of_six" %in% getNamespaceExports("dgraphs"))
  })
})
