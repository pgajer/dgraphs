graph_explorer_test_env <- .graph_explorer_env()
load_benchmark_run <- read.graph.benchmark

make_dg_fixture <- function(root, missing_graph = FALSE, missing_layout = FALSE, layout_as_list = TRUE) {
  run <- file.path(root, "run")
  dir.create(run, recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(run, "assets", "datasets"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(run, "assets", "graphs", "paraboloid_n10_seed001", "g0001"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(run, "assets", "layouts", "paraboloid_n10_seed001", "g0001"), recursive = TRUE, showWarnings = FALSE)

  dataset_id <- "paraboloid_n10_seed001"
  setting_id <- "g0001"
  stage <- "raw.repaired"
  dataset_file <- file.path(run, "assets", "datasets", paste0(dataset_id, ".rds"))
  graph_file <- file.path(run, "assets", "graphs", dataset_id, setting_id, "raw_repaired.rds")
  layout_file <- file.path(run, "assets", "layouts", dataset_id, setting_id, "raw_repaired_weighted_grip_3d.rds")

  X <- cbind(seq_len(10), seq_len(10) / 10, (seq_len(10) / 10)^2)
  saveRDS(list(dataset_id = dataset_id, X_embed = X), dataset_file)

  adj <- list(2L, c(1L, 3L), c(2L, 4L), c(3L, 5L), c(4L, 6L), c(5L, 7L), c(6L, 8L), c(7L, 9L), c(8L, 10L), 9L)
  weight <- lapply(adj, function(nb) rep(1, length(nb)))
  saveRDS(
    list(dataset_id = dataset_id, setting_id = setting_id, stage = stage, adj_list = adj, weight_list = weight),
    graph_file
  )

  layout <- cbind(seq_len(10), cos(seq_len(10)), sin(seq_len(10)))
  saveRDS(if (isTRUE(layout_as_list)) list(coords = layout) else layout, layout_file)

  dataset_manifest <- data.frame(
    surface = "paraboloid",
    curvature_label = "(1, 1)",
    domain_shape = "disk",
    sampling_profile = "uniform",
    n = 10L,
    seed = 1L,
    dataset_id = dataset_id,
    stringsAsFactors = FALSE
  )
  utils::write.csv(dataset_manifest, file.path(run, "dataset_manifest.csv"), row.names = FALSE)
  utils::write.csv(data.frame(dataset_id = dataset_id, dataset_asset_file = dataset_file, stringsAsFactors = FALSE), file.path(run, "dataset_assets.csv"), row.names = FALSE)
  utils::write.csv(
    data.frame(
      dataset_id = dataset_id,
      setting_id = setting_id,
      stage = stage,
      graph_family = "sknn",
      graph_asset_file = graph_file,
      n_vertices = 10L,
      n_edges = 9L,
      n_components = 1L,
      stringsAsFactors = FALSE
    ),
    file.path(run, "graph_assets.csv"),
    row.names = FALSE
  )
  utils::write.csv(
    data.frame(
      dataset_id = dataset_id,
      setting_id = setting_id,
      stage = stage,
      method = "weighted_grip",
      layout_asset_file = layout_file,
      n_vertices = 10L,
      stringsAsFactors = FALSE
    ),
    file.path(run, "layout_assets.csv"),
    row.names = FALSE
  )
  metrics <- data.frame(
    dataset_id = dataset_id,
    setting_id = setting_id,
    target = c("surface", "sample_oracle"),
    surface = "paraboloid",
    curvature_label = "(1, 1)",
    domain_shape = "disk",
    sampling_profile = "uniform",
    n = 10L,
    seed = 1L,
    graph_family = "sknn",
    k = 3L,
    radius_rank = NA_integer_,
    k_scale = NA_integer_,
    radius_rule = NA_character_,
    radius_factor = NA_real_,
    delta = NA_real_,
    prune_method = "none",
    metric_stage = stage,
    status = "ok",
    rel_rms_error = c(0.1, 0.2),
    rel_abs_error_q95 = c(0.3, 0.4),
    pearson_cor = c(0.99, 0.97),
    stringsAsFactors = FALSE
  )
  utils::write.csv(metrics, file.path(run, "metrics.csv"), row.names = FALSE)
  utils::write.csv(
    data.frame(dataset_id = dataset_id, setting_id = setting_id, stage = stage, n_edges_raw_repaired = 9L, stringsAsFactors = FALSE),
    file.path(run, "graph_diagnostics.csv"),
    row.names = FALSE
  )
  graph_settings <- data.frame(
    dataset_id = dataset_id,
    setting_id = setting_id,
    surface = "paraboloid",
    curvature_label = "(1, 1)",
    domain_shape = "disk",
    sampling_profile = "uniform",
    n = 10L,
    seed = 1L,
    graph_family = "sknn",
    k = 3L,
    radius_rank = NA_integer_,
    k_scale = NA_integer_,
    radius_rule = NA_character_,
    radius_factor = NA_real_,
    delta = NA_real_,
    prune_method = "none",
    stage = stage,
    stringsAsFactors = FALSE
  )
  manifest <- list(
    version = "1",
    project = "dg_fixture",
    graph_settings = graph_settings
  )
  saveRDS(manifest, file.path(run, "quadform_benchmark_manifest.rds"))
  writeLines("{}", file.path(run, "quadform_benchmark_manifest.json"))

  if (isTRUE(missing_graph)) {
    unlink(graph_file, force = TRUE)
  }
  if (isTRUE(missing_layout)) {
    unlink(layout_file, force = TRUE)
  }

  list(
    run = run,
    dataset_id = dataset_id,
    setting_id = setting_id,
    stage = stage,
    key = graph_explorer_test_env$dg_stage_key(dataset_id, setting_id, stage),
    dataset_file = dataset_file,
    graph_file = graph_file,
    layout_file = layout_file
  )
}

with_dg_cache <- function(code) {
  cache_dir <- tempfile("dggraphui-cache-")
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  old <- getOption("dgraphs.graph_explorer_cache_dir", NULL)
  options(dgraphs.graph_explorer_cache_dir = cache_dir)
  on.exit({
    if (is.null(old)) {
      options(dgraphs.graph_explorer_cache_dir = NULL)
    } else {
      options(dgraphs.graph_explorer_cache_dir = old)
    }
    unlink(cache_dir, recursive = TRUE, force = TRUE)
  }, add = TRUE)
  force(code)
}

test_that("benchmark run loader creates a normalized index", {
  root <- tempfile("dg-load-")
  fx <- make_dg_fixture(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  run <- load_benchmark_run(fx$run)
  expect_equal(run$summary$graph_assets$n_rows, 1L)
  expect_true(all(c("surface", "curvature_label", "domain_shape", "sampling_profile", "k") %in% names(run$index)))
  expect_equal(run$index$stage_key[[1]], fx$key)
})

test_that("manual selector resolves exact graph and layout rows", {
  root <- tempfile("dg-manual-")
  fx <- make_dg_fixture(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  run <- load_benchmark_run(fx$run)

  sel <- graph_explorer_test_env$dg_selector_state(run, list(
    selection_mode = "manual",
    surface = "paraboloid",
    curvature_label = "(1, 1)",
    domain_shape = "disk",
    sampling_profile = "uniform",
    n = "10",
    seed = "1",
    graph_family = "sknn",
    k = "3",
    prune_method = "none",
    stage = "raw.repaired"
  ))
  expect_equal(sel$status, "ok")
  expect_equal(sel$key, fx$key)
  expect_equal(graph_explorer_test_env$dg_exact_graph_row(run, fx$key)$status, "ok")
  expect_equal(graph_explorer_test_env$dg_exact_layout_row(run, fx$key)$status, "ok")
})

test_that("optimal selector chooses the smallest metric error", {
  root <- tempfile("dg-optimal-")
  fx <- make_dg_fixture(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  setting2 <- "g0002"
  graph2 <- file.path(fx$run, "assets", "graphs", fx$dataset_id, setting2, "raw_repaired.rds")
  layout2 <- file.path(fx$run, "assets", "layouts", fx$dataset_id, setting2, "raw_repaired_weighted_grip_3d.rds")
  dir.create(dirname(graph2), recursive = TRUE, showWarnings = FALSE)
  dir.create(dirname(layout2), recursive = TRUE, showWarnings = FALSE)
  file.copy(fx$graph_file, graph2)
  file.copy(fx$layout_file, layout2)

  graph_assets <- utils::read.csv(file.path(fx$run, "graph_assets.csv"), stringsAsFactors = FALSE)
  graph_assets <- rbind(graph_assets, transform(graph_assets[1, ], setting_id = setting2, graph_asset_file = graph2))
  utils::write.csv(graph_assets, file.path(fx$run, "graph_assets.csv"), row.names = FALSE)
  layout_assets <- utils::read.csv(file.path(fx$run, "layout_assets.csv"), stringsAsFactors = FALSE)
  layout_assets <- rbind(layout_assets, transform(layout_assets[1, ], setting_id = setting2, layout_asset_file = layout2))
  utils::write.csv(layout_assets, file.path(fx$run, "layout_assets.csv"), row.names = FALSE)
  metrics <- utils::read.csv(file.path(fx$run, "metrics.csv"), stringsAsFactors = FALSE)
  best <- metrics[metrics$target == "surface", , drop = FALSE][1, , drop = FALSE]
  best$setting_id <- setting2
  best$k <- 5L
  best$rel_rms_error <- 0.01
  metrics <- rbind(metrics, best)
  utils::write.csv(metrics, file.path(fx$run, "metrics.csv"), row.names = FALSE)
  manifest <- readRDS(file.path(fx$run, "quadform_benchmark_manifest.rds"))
  gs2 <- manifest$graph_settings[1, , drop = FALSE]
  gs2$setting_id <- setting2
  gs2$k <- 5L
  manifest$graph_settings <- rbind(manifest$graph_settings, gs2)
  saveRDS(manifest, file.path(fx$run, "quadform_benchmark_manifest.rds"))

  run <- load_benchmark_run(fx$run)
  sel <- graph_explorer_test_env$dg_selector_state(run, list(
    selection_mode = "optimal",
    metric_target = "surface",
    surface = "paraboloid",
    curvature_label = "(1, 1)",
    domain_shape = "disk",
    sampling_profile = "uniform",
    n = "10"
  ))

  expect_equal(sel$status, "ok")
  expect_equal(sel$mode, "optimal")
  expect_equal(as.character(sel$row$setting_id[[1]]), setting2)
  expect_equal(as.character(sel$row$k[[1]]), "5")
  expect_match(graph_explorer_test_env$dg_selection_summary(sel), "rel_rms_error=0.01", fixed = TRUE)
})

test_that("asset parsers handle graph stages and matrix/list layouts", {
  root <- tempfile("dg-parsers-")
  fx <- make_dg_fixture(root, layout_as_list = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  graph <- graph_explorer_test_env$dg_parse_graph_asset(fx$graph_file)
  expect_equal(graph$status, "ok")
  expect_true(is.list(graph$adj_list))
  expect_true(is.list(graph$weight_list))

  layout_list <- graph_explorer_test_env$dg_parse_layout_asset(fx$layout_file)
  expect_equal(layout_list$status, "ok")
  expect_equal(dim(layout_list$coords), c(10L, 3L))

  matrix_file <- file.path(root, "layout_matrix.rds")
  saveRDS(matrix(seq_len(30), nrow = 10, ncol = 3), matrix_file)
  layout_matrix <- graph_explorer_test_env$dg_parse_layout_asset(matrix_file)
  expect_equal(layout_matrix$status, "ok")
})

test_that("missing graph and layout assets produce clear states", {
  root <- tempfile("dg-missing-")
  fx <- make_dg_fixture(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  run <- load_benchmark_run(fx$run)
  sel <- graph_explorer_test_env$dg_selector_state(run, list(selection_mode = "manual"))

  unlink(fx$layout_file, force = TRUE)
  st_layout <- graph_explorer_test_env$dg_view_state(run, sel)
  expect_equal(st_layout$status, "missing_layout")

  unlink(fx$graph_file, force = TRUE)
  st_graph <- graph_explorer_test_env$dg_view_state(run, sel)
  expect_equal(st_graph$status, "missing_graph")
  expect_false(file.exists(fx$graph_file))
})

test_that("generated layout cache takes priority over benchmark layout", {
  root <- tempfile("dg-cache-priority-")
  fx <- make_dg_fixture(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  with_dg_cache({
    run <- load_benchmark_run(fx$run)
    sel <- graph_explorer_test_env$dg_selector_state(run, list(selection_mode = "manual"))
    cache_path <- graph_explorer_test_env$dg_generated_layout_cache_path(graph_explorer_test_env$dg_run_id(run), fx$key)
    dir.create(dirname(cache_path), recursive = TRUE, showWarnings = FALSE)
    saveRDS(list(coords = matrix(42, nrow = 10, ncol = 3)), cache_path)

    st <- graph_explorer_test_env$dg_view_state(run, sel)
    expect_equal(st$status, "ok")
    expect_equal(st$layout_source, "dgraphs_cache")
    expect_equal(st$layout_coords[1, 1], 42)
  })
})

test_that("weighted layout generation uses weighted function and reports unavailable without it", {
  root <- tempfile("dg-generate-")
  fx <- make_dg_fixture(root, missing_layout = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  with_dg_cache({
    cache_path <- graph_explorer_test_env$dg_generated_layout_cache_path("run", fx$key)
    fake_weighted <- function(adj_list, weight_list, dim, rounds, final_rounds, seed) {
      cbind(seq_along(adj_list), 0, 1)
    }
    out <- graph_explorer_test_env$dg_generate_weighted_layout(fx$graph_file, cache_path, weighted_layout_fun = fake_weighted)
    expect_equal(out$status, "ok")
    expect_true(file.exists(cache_path))

    unavailable <- graph_explorer_test_env$dg_generate_weighted_layout(fx$graph_file, tempfile(), weighted_layout_fun = NULL)
    expect_equal(unavailable$status, "unavailable")
    expect_match(unavailable$message, "grip(metric", fixed = TRUE)
  })
})

test_that("Shiny app constructs and renders benchmark selector controls", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("plotly")
  root <- tempfile("dg-app-")
  fx <- make_dg_fixture(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  with_dg_cache({
    shiny::testServer(function(input, output, session) {
      graph_explorer_test_env$dg_app_server(input, output, session, default_run_dir = fx$run)
    }, {
      session$flushReact()
      html <- paste(as.character(output$selector_panel), collapse = "")
      expect_match(html, "Selection mode", fixed = TRUE)
      expect_match(html, "Optimal", fixed = TRUE)
      expect_match(html, "Graph family", fixed = TRUE)
      compare_html <- paste(as.character(output$compare_view), collapse = "")
      expect_match(compare_html, "edges displayed", fixed = TRUE)
    })
  })
})

test_that("projects reopen by name and relocated relative manifests without mutation", {
  root <- tempfile("dg-project-")
  fx <- make_dg_fixture(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  withr::local_options(dgraphs.projects_dir = file.path(root, "catalog"))
  for (item in list(c("dataset_assets.csv", "dataset_asset_file"),
                   c("graph_assets.csv", "graph_asset_file"),
                   c("layout_assets.csv", "layout_asset_file"))) {
    path <- file.path(fx$run, item[1])
    tab <- utils::read.csv(path)
    tab[[item[2]]] <- substring(tab[[item[2]]], nchar(fx$run) + 2L)
    utils::write.csv(tab, path, row.names = FALSE)
  }
  files <- list.files(fx$run, recursive = TRUE, full.names = TRUE)
  before <- tools::md5sum(files)
  register.graph.project(fx$run, "Saved study")
  by.name <- read.graph.benchmark("Saved study")
  by.manifest <- read.graph.benchmark(file.path(fx$run, "quadform_benchmark_manifest.json"))
  expect_equal(by.name, by.manifest)
  expect_identical(tools::md5sum(files), before)
  moved <- file.path(root, "moved-run")
  expect_true(file.rename(fx$run, moved))
  expect_error(read.graph.benchmark("Saved study"), "not found")
  expect_error(register.graph.project(moved, "Saved study"), "already exists")
  register.graph.project(moved, "Saved study", overwrite = TRUE)
  run <- read.graph.benchmark("Saved study")
  with_dg_cache({
    selection <- graph_explorer_test_env$dg_selector_state(run, list(selection_mode = "manual"))
    view <- graph_explorer_test_env$dg_view_state(run, selection)
    expect_equal(view$status, "ok")
    expect_equal(view$dataset$status, "ok")
    expect_true(startsWith(view$graph_asset_file, normalizePath(moved)))
  })
})

test_that("same-named runs have separate caches", {
  root <- tempfile("dg-cache-isolation-")
  first <- make_dg_fixture(file.path(root, "first"))
  second <- make_dg_fixture(file.path(root, "second"))
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  with_dg_cache({
    a <- read.graph.benchmark(first$run); b <- read.graph.benchmark(second$run)
    e <- graph_explorer_test_env
    expect_false(identical(e$dg_generated_layout_cache_path(e$dg_run_id(a), first$key),
                           e$dg_generated_layout_cache_path(e$dg_run_id(b), second$key)))
  })
})

test_that("launcher and saved-project selection work without starting a server", {
  for (pkg in c("shiny", "bslib", "plotly", "digest")) skip_if_not_installed(pkg)
  root <- tempfile("dg-launch-")
  fx <- make_dg_fixture(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  withr::local_options(dgraphs.projects_dir = file.path(root, "catalog"))
  register.graph.project(fx$run, "Fixture")
  expect_s3_class(explore.graphs(project = "Fixture", launch = FALSE), "shiny.appobj")
  expect_error(explore.graphs(run_dir = fx$run, launch = FALSE), "removed")
  expect_error(explore.graphs(project = fx$run, run_dir = fx$run, launch = FALSE), "removed")
  with_dg_cache({
    shiny::testServer(function(input, output, session) {
      graph_explorer_test_env$dg_app_server(input, output, session)
    }, {
      session$flushReact()
      session$setInputs(saved_project = fx$run)
      session$flushReact()
      expect_match(paste(output$compare_view, collapse = ""), "edges displayed", fixed = TRUE)
      session$setInputs(project_name = "Another name", remember_project = 1L)
      session$flushReact()
      expect_true("Another name" %in% .graph_project_catalog()$name)
    })
  })
})

test_that("current dotted GRIP formals generate layouts without changing saved schemas", {
  e <- graph_explorer_test_env
  root <- tempfile("dg-dotted-grip-")
  fx <- make_dg_fixture(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  before <- tools::md5sum(c(fx$graph_file, fx$layout_file))
  received <- NULL
  current <- function(adj.list, weight.list, dim, rounds, final.rounds, seed, metric) {
    received <<- list(adj.list = adj.list, weight.list = weight.list, dim = dim,
                     rounds = rounds, final.rounds = final.rounds, seed = seed, metric = metric)
    cbind(seq_along(adj.list), 0, 1)
  }
  adapter <- e$dg.weighted.layout.adapter(current)
  expect_true(is.function(adapter))
  target <- file.path(root, "new.rds")
  result <- e$dg_generate_weighted_layout(fx$graph_file, target,
      params = list(rounds = 2L, final_rounds = 3L, seed = 17L), weighted_layout_fun = adapter)
  expect_identical(result$status, "ok")
  expect_equal(dim(result$coords), c(10L, 3L))
  expect_equal(received$adj.list, readRDS(fx$graph_file)$adj_list)
  expect_equal(received$weight.list, readRDS(fx$graph_file)$weight_list)
  expect_identical(received[c("dim", "rounds", "final.rounds", "seed", "metric")],
      list(dim = 3L, rounds = 2L, final.rounds = 3L, seed = 17L, metric = "edge_length"))
  expect_identical(readRDS(target)$params,
      list(dim = 3L, rounds = 2L, final_rounds = 3L, seed = 17L))
  expect_identical(tools::md5sum(c(fx$graph_file, fx$layout_file)), before)
  expect_error(adapter(adj_list = list(2L), adj.list = list(2L)), "Ambiguous")
  expect_null(e$dg.weighted.layout.adapter(function(adj_list, weight_list) NULL))
})

test_that("previous public GRIP spelling uses explicit boundary compatibility", {
  e <- graph_explorer_test_env
  previous <- function(adj_list, weight_list, dim, rounds, final_rounds, seed, metric)
    list(adj_list = adj_list, weight_list = weight_list, final_rounds = final_rounds, metric = metric)
  result <- e$dg.weighted.layout.adapter(previous)(adj.list = list(2L), weight.list = list(1),
      dim = 3L, rounds = 1L, final.rounds = 2L, seed = 6L)
  expect_identical(result, list(adj_list = list(2L), weight_list = list(1),
                              final_rounds = 2L, metric = "edge_length"))
})

test_that("older public weighted GRIP retains its explicit metric-free contract", {
  e <- graph_explorer_test_env
  previous <- function(adj_list, weight_list, dim, rounds, final_rounds, seed)
    cbind(seq_along(adj_list), 0, 1)
  f <- e$dg.weighted.layout.adapter(previous, weighted.only = TRUE)
  expect_true(is.function(f))
  expect_equal(f(adj_list = list(2L, 1L), weight_list = list(1, 1),
      dim = 3L, rounds = 1L, final_rounds = 2L, seed = 6L), cbind(1:2, 0, 1))
})

test_that("current public GRIP can explicitly generate a missing weighted layout", {
  skip_if_not_installed("grip")
  f <- graph_explorer_test_env$dg_weighted_layout_fun()
  expect_true(is.function(f), info = "Installed public GRIP must expose a supported weighted interface")
  root <- tempfile("dg-weighted-")
  fx <- make_dg_fixture(root, missing_layout = TRUE)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  result <- graph_explorer_test_env$dg_generate_weighted_layout(
    fx$graph_file, file.path(root, "new-layout.rds"), params = list(rounds = 1L, final_rounds = 1L))
  expect_equal(result$status, "ok")
  expect_equal(dim(result$coords), c(10L, 3L))
  expect_true(all(is.finite(result$coords)))
  graph <- readRDS(fx$graph_file)
  expected <- grip::grip(adj.list = graph$adj_list, weight.list = graph$weight_list,
    metric = "edge_length", dim = 3L, rounds = 1L, final.rounds = 1L, seed = 6L)
  expect_equal(unname(result$coords), unname(expected))
  expect_false(file.exists(fx$layout_file))
})


test_that("display modes preserve proportions unless distortion is requested", {
  e <- graph_explorer_test_env
  X <- rbind(c(0,0,0), c(10,1,2), c(4,1,0))
  expect_equal(unname(e$dg_normalize_coord_matrix(X)), X)
  Y <- e$dg_normalize_coord_matrix(X, "isotropic")
  expect_equal(as.numeric(dist(Y)), as.numeric(dist(X))/10)
  expect_false(isTRUE(all.equal(as.numeric(dist(e$dg_normalize_coord_matrix(X,"per.axis"))), as.numeric(dist(Y)))))
  expect_null(e$dg_normalize_coord_matrix(rbind(c(NA,1,2),c(1,2,3))))
  set.seed(4101); before <- .Random.seed
  g <- create.graph("complete",100)
  expect_equal(nrow(e$dg_display_edges(graph.adjacency(g))),4000)
  expect_identical(.Random.seed,before)
})

test_that("installed demo opens both saved settings without changing assets or registry", {
  e <- graph_explorer_test_env
  demo <- system.file("extdata","graph-explorer-demo",package="dgraphs")
  files <- list.files(demo,recursive=TRUE,full.names=TRUE)
  before <- tools::md5sum(files)
  registry <- tempfile(); withr::local_options(dgraphs.projects_dir=registry)
  run <- read.graph.benchmark(demo)
  expect_equal(nrow(run$graph_assets),2L)
  for (k in c("2","4")) {
    sel <- e$dg_selector_state(run,list(selection_mode="manual",k=k))
    st <- e$dg_view_state(run,sel)
    expect_equal(st$status,"ok")
    expect_equal(nrow(st$layout_coords),12L)
  }
  expect_equal(run$metrics$rel_rms_error,c(0.0113840705346307,0.0412747672229985))
  expect_identical(tools::md5sum(files),before)
  expect_false(dir.exists(registry))
})
