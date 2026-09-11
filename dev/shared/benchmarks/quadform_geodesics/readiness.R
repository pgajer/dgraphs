# Bounded integration pilot; explicit bindings do not activate the registry.
qgs.readiness.methods <- function() {
  ids <- c(I = "adaptive_initializer", A = "adaptive_vertex", B = "adaptive_local_graph")
  lapply(ids, function(id) list(id = id, file = paste0("solvers/", id, ".R"),
    sources = c("solvers/adaptive/common.R",
      if (id == "adaptive_local_graph") "solvers/adaptive/local_graph.R")))
}

qgs.readiness.plan <- function(collection) {
  plan <- qgs.campaign.plan(collection,
    pairs = data.frame(case_id = c("flat2_box", "paraboloid2_high_curvature"),
      pair_id = c("grid_direction", "ab")), repeats = 4103,
    seconds = 1800, protocol = "qg-readiness-pilot-v1")
  plan$qualification <- "Readiness pilot only; provisional conventions; no method ranking or calibration acceptance"
  plan
}

qgs.readiness.create <- function(home, collection.directory, output) {
  collection <- qg.read(collection.directory)
  plan <- qgs.readiness.plan(collection)
  # Complete the pilot-specific source manifest before it can be executed.
  qgs.campaign.create(home, collection.directory, output, plan)
  manifest <- jsonlite::fromJSON(file.path(output, "manifest.json"), simplifyVector = FALSE)
  methods <- qgs.readiness.methods()
  sources <- c(manifest$sources, qgs.sources(home, list(file = "readiness.R"),
    file.path(collection.directory, "../collection.R")))
  for (method in methods) sources <- c(sources, qgs.sources(home, method,
    file.path(collection.directory, "../collection.R")))
  manifest$sources <- sources[!duplicated(vapply(sources, `[[`, "", "path"))]
  git <- function(args) system2("git", c("-C", shQuote(home), args), stdout = TRUE)
  manifest$git <- list(head = git(c("rev-parse", "HEAD")), branch = git(c("branch", "--show-current")),
    status = git(c("status", "--porcelain")))
  manifest$purpose <- plan$qualification
  manifest$environment$python <- list(interpreter = Sys.getenv("RETICULATE_PYTHON"),
    R_LIBS_USER = Sys.getenv("R_LIBS_USER"))
  manifest$environment$session <- capture.output(sessionInfo())
  qgs.write(manifest, file.path(output, "manifest.json"))
  state <- readRDS(file.path(output, "state.rds"))
  state$manifest_sha256 <- digest::digest(file = file.path(output, "manifest.json"), algo = "sha256")
  qgs.binary(state, file.path(output, "state.rds"))
  qgs.campaign.export(output, plan, state, collection)
  invisible(output)
}

qgs.readiness.local <- function(home, output) {
  data <- qgs.campaign.read(output); plan <- data$plan; state <- data$state
  qg.assert(identical(plan, qgs.readiness.plan(data$collection)), "Unexpected readiness plan")
  qg.assert(all(state$status == "not_run") && is.null(state$active_job), "Pilot cannot retry or resume")
  methods <- qgs.readiness.methods(); started <- qgs.clock()
  for (i in seq_along(plan$jobs)) {
    job <- plan$jobs[[i]]; r <- job$request; method <- methods[[job$role]]
    if (qgs.clock() - started + r$limits$seconds + 22 > plan$seconds) break
    directory <- file.path(output, "jobs", job$id)
    qg.assert(!file.exists(directory), "Existing attempt cannot be overwritten")
    dir.create(directory, recursive = TRUE)
    state$status[i] <- "running"; state$active_job <- i
    qgs.binary(state, file.path(output, "state.rds"))
    qgs.binary(r, file.path(directory, "request.rds"))
    qgs.write(data$manifest$sources, file.path(directory, "sources.json"))
    cat("START", job$id, job$role, job$cohort, r$case_id, r$direction, "\n"); flush.console()
    record <- qgs.job(home, file.path(data$manifest$collection_directory, "../collection.R"),
      file.path(home, method$file), method, r, directory, data$manifest$sources)
    qgs.binary(record, file.path(directory, "record.rds"))
    qgs.write(record, file.path(directory, "record.json"))
    state$status[i] <- if (identical(record$search$status, "failed")) "failed" else "complete"
    state$active_job <- NULL; state$charged_seconds <- qgs.clock() - started
    qgs.binary(state, file.path(output, "state.rds"))
    cat("END", job$id, state$status[i], record$search$termination,
      "peak_MiB", record$search_monitor$peak_rss_bytes / 1024^2, "\n"); flush.console()
  }
  qgs.verify.sources(data$manifest$sources)
  invisible(NULL)
}

qgs.readiness.run <- function(home, output) {
  data <- qgs.campaign.read(output)
  qg.assert(identical(data$plan, qgs.readiness.plan(data$collection)), "Unexpected readiness plan")
  qg.assert(all(data$state$status == "not_run"), "Pilot cannot retry or resume")
  head <- system2("git", c("-C", shQuote(home), "rev-parse", "HEAD"), stdout = TRUE)
  status <- system2("git", c("-C", shQuote(home), "status", "--porcelain"), stdout = TRUE)
  qg.assert(identical(head, unlist(data$manifest$git$head)) && !length(status) &&
    !length(data$manifest$git$status), "Pilot requires a clean, unchanged committed source tree")
  lock <- file.path(output, "run.lock")
  qg.assert(dir.create(lock, showWarnings = FALSE), "Pilot lock exists")
  on.exit(unlink(lock, recursive = TRUE), add = TRUE)
  qgs.write(list(pid = Sys.getpid(), host = Sys.info()[["nodename"]]), file.path(lock, "owner.json"))
  result <- qgs.supervise(function(home, output, helpers) {
    source(helpers); source(file.path(home, "interface.R")); source(file.path(home, "runner.R"))
    source(file.path(home, "campaign.R")); source(file.path(home, "readiness.R"))
    qgs.readiness.local(home, output)
  }, list(home, output, file.path(data$manifest$collection_directory, "../collection.R")),
  seconds = data$plan$seconds, rss_mib = Inf,
  stdout = file.path(output, "pilot-stdout.log"), stderr = file.path(output, "pilot-stderr.log"))
  qgs.binary(result, file.path(output, "pilot-monitor.rds"))
  state <- readRDS(file.path(output, "state.rds"))
  if (!is.null(state$active_job)) {
    state$status[state$active_job] <- "interrupted"; state$active_job <- NULL
  }
  state$charged_seconds <- result$elapsed_seconds
  qgs.binary(state, file.path(output, "state.rds"))
  qgs.verify.sources(data$manifest$sources)
  qgs.campaign.export(output, data$plan, state, data$collection)
  list(termination = result$termination, status = table(state$status), seconds = state$charged_seconds,
    qualification = data$plan$qualification)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  stopifnot(length(args) == 2L, args[1] %in% c("plan", "run"))
  home <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])))
  fixture <- normalizePath(file.path(home, "../../fixtures/quadform_geodesics"))
  source(file.path(fixture, "collection.R")); source(file.path(home, "interface.R"))
  source(file.path(home, "runner.R")); source(file.path(home, "campaign.R"))
  if (args[1] == "plan") qgs.readiness.create(home, file.path(fixture, "v1"), args[2])
  else print(qgs.readiness.run(home, args[2]))
}
