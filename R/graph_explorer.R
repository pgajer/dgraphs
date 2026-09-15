.graph_explorer_env <- function() {
    root <- system.file("shiny/graph-explorer/R", package = "dgraphs",
                        mustWork = TRUE)
    env <- new.env(parent = asNamespace("dgraphs"))
    for (name in c("utils", "benchmark_run", "selectors", "view_model",
                   "app_ui", "app_server")) {
        sys.source(file.path(root, paste0(name, ".R")), envir = env)
    }
    env
}

.graph_project_catalog_file <- function() {
    root <- getOption("dgraphs.projects_dir", tools::R_user_dir("dgraphs", "data"))
    file.path(path.expand(root), "graph-projects.rds")
}

.graph_project_catalog <- function() {
    path <- .graph_project_catalog_file()
    empty <- data.frame(name = character(), path = character(),
                        stringsAsFactors = FALSE)
    if (!file.exists(path)) return(empty)
    out <- tryCatch(readRDS(path), error = function(e) {
        stop("Cannot read the graph project catalog: ", conditionMessage(e),
             call. = FALSE)
    })
    if (!is.data.frame(out) || !all(c("name", "path") %in% names(out)) ||
        anyNA(out[, c("name", "path")]) || anyDuplicated(out$name)) {
        stop("Invalid graph project catalog: ", path, call. = FALSE)
    }
    out
}

.graph_project_path <- function(project) {
    if (!is.character(project) || length(project) != 1L || is.na(project) ||
        !nzchar(trimws(project))) {
        stop("project must be a directory, benchmark manifest, or registered name.",
             call. = FALSE)
    }
    path <- path.expand(project)
    if (!file.exists(path)) {
        catalog <- .graph_project_catalog()
        hit <- match(project, catalog$name)
        if (!is.na(hit)) path <- catalog$path[[hit]]
    }
    if (file.exists(path) && !dir.exists(path)) {
        if (!basename(path) %in% c("quadform_benchmark_manifest.rds",
                                  "quadform_benchmark_manifest.json")) {
            stop("Expected a benchmark directory or quadform benchmark manifest.",
                 call. = FALSE)
        }
        path <- dirname(path)
    }
    if (!dir.exists(path)) {
        stop("Project directory not found: ", path,
             ". Supply its current path or update the registered location.",
             call. = FALSE)
    }
    normalizePath(path, mustWork = TRUE)
}

#' Open the Graph Reconstruction Explorer
#'
#' Explore saved data-geodesic graph reconstruction benchmarks using manual
#' graph selection, metric-based selection, saved layouts and parameter scans.
#' This is the maintained replacement for the dggraphui application.
#'
#' @param project Optional benchmark directory, benchmark manifest file, or
#'   name previously stored by [register.graph.project()]. When omitted, the
#'   app opens a project selector. No dataset is loaded or fitted automatically.
#' @param run_dir Compatibility argument for older dggraphui launch scripts.
#'   Supply either this or `project`, not both.
#' @param launch If `TRUE`, run the application; if `FALSE`, return its Shiny
#'   application object without starting a server.
#' @param host Interface on which to listen; defaults to the local computer.
#' @param port Optional port passed to [shiny::runApp()].
#' @param launch.browser Whether to open the browser when launching.
#' @param ... Further arguments to [shiny::runApp()].
#'
#' @details
#' The optional packages shiny, bslib, plotly and digest are required only for
#' the explorer. The optional grip package is needed only when explicitly
#' generating a missing weighted layout. Opening a project reads saved results;
#' it does not reconstruct graphs, fit layouts or overwrite benchmark assets.
#' Newly generated layouts are stored in a separate user cache. Legacy
#' dggraphui caches are used only when their graph provenance matches.
#'
#' Project registration stores locations in the user's dgraphs data directory,
#' outside the installed package. Set `options(dgraphs.projects_dir = ...)`
#' to choose another catalog directory. Set
#' `options(dgraphs.graph_explorer_cache_dir = ...)` to choose the layout cache.
#' The older `dggraphui.cache_dir` option is also accepted.
#'
#' The viewer retains dggraphui's per-axis display normalization. These display
#' coordinates are not the original metric coordinates; metric tables continue
#' to report the saved benchmark values.
#'
#' @return When `launch = FALSE`, a `shiny.appobj`; otherwise the result of
#'   [shiny::runApp()], invisibly.
#' @seealso [read.graph.benchmark()], [register.graph.project()]
#' @export
#' @examples
#' if (interactive() && all(vapply(c("shiny", "bslib", "plotly", "digest"),
#'                                requireNamespace, logical(1), quietly = TRUE))) {
#'     explore.graphs()
#' }
explore.graphs <- function(project = NULL, run_dir = NULL, launch = TRUE,
                           host = "127.0.0.1", port = getOption("shiny.port"),
                           launch.browser = interactive(), ...) {
    packages <- c("shiny", "bslib", "plotly", "digest")
    missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
    if (length(missing)) {
        stop("The graph explorer needs optional packages: ",
             paste(missing, collapse = ", "), ". Install them before launching.",
             call. = FALSE)
    }
    if (!is.null(project) && !is.null(run_dir)) {
        stop("Supply only one of project and run_dir.", call. = FALSE)
    }
    if (!is.logical(launch) || length(launch) != 1L || is.na(launch)) {
        stop("launch must be TRUE or FALSE.", call. = FALSE)
    }
    if (is.null(project)) project <- run_dir
    path <- if (is.null(project)) "" else .graph_project_path(project)
    env <- .graph_explorer_env()
    app <- shiny::shinyApp(
        ui = env$dg_app_ui(default_run_dir = path),
        server = function(input, output, session) {
            env$dg_app_server(input, output, session, default_run_dir = path)
        }
    )
    if (!launch) return(app)
    invisible(shiny::runApp(app, host = host, port = port,
                           launch.browser = launch.browser, ...))
}

#' Read a Saved Graph Reconstruction Benchmark
#'
#' Read the existing dggraphui benchmark manifest and asset tables without
#' launching Shiny or changing any files. Asset paths relative to the run
#' directory are resolved against that directory; absolute paths are retained.
#'
#' @param project Benchmark directory, quadform benchmark manifest file, or
#'   registered project name.
#' @return A list containing the manifest, dataset and graph indexes, saved
#'   layout index, metrics, diagnostics, and table summaries. This validates
#'   required index files; it does not guarantee that every referenced asset
#'   exists or that the scientific results are correct. Assets are loaded on
#'   demand by the explorer, which reports missing files.
#' @seealso [explore.graphs()], [register.graph.project()]
#' @export
#' @examples
#' \dontrun{
#' run <- read.graph.benchmark("path/to/benchmark/run")
#' run$summary
#' head(run$metrics)
#' }
read.graph.benchmark <- function(project) {
    .graph_explorer_env()$load_benchmark_run(.graph_project_path(project))
}

#' Remember a Graph Explorer Project
#'
#' Register an existing benchmark directory for the explorer's project picker.
#' Only its name and location are saved. Scientific assets stay in place.
#'
#' @param project Benchmark directory or quadform benchmark manifest file.
#' @param name A nonempty, unique display name; it can also be passed as
#'   `project` to [explore.graphs()] or [read.graph.benchmark()].
#' @param overwrite Allow an existing name to point to a different directory.
#' @return The updated project catalog, invisibly, with `name` and `path`
#'   columns. Set `options(dgraphs.projects_dir = ...)` to change its location.
#' @seealso [explore.graphs()], [read.graph.benchmark()]
#' @export
#' @examples
#' \dontrun{
#' register.graph.project("path/to/benchmark/run", name = "My graph study")
#' explore.graphs(project = "My graph study")
#' }
register.graph.project <- function(project, name, overwrite = FALSE) {
    if (!is.character(name) || length(name) != 1L || is.na(name) ||
        !nzchar(trimws(name))) stop("name must be one nonempty string.", call. = FALSE)
    name <- trimws(name)
    path <- read.graph.benchmark(project)$run_dir
    catalog <- .graph_project_catalog()
    hit <- match(name, catalog$name)
    if (!is.na(hit) && catalog$path[[hit]] != path && !isTRUE(overwrite)) {
        stop("Project name already exists. Choose another name or use overwrite = TRUE.",
             call. = FALSE)
    }
    catalog <- catalog[catalog$name != name, , drop = FALSE]
    catalog <- rbind(catalog, data.frame(name = name, path = path))
    rownames(catalog) <- NULL
    file <- .graph_project_catalog_file()
    dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
    tmp <- tempfile("graph-projects-", tmpdir = dirname(file))
    on.exit(unlink(tmp), add = TRUE)
    saveRDS(catalog, tmp)
    if (!file.rename(tmp, file)) stop("Cannot save project catalog: ", file, call. = FALSE)
    invisible(catalog)
}
