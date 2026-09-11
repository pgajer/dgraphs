#!/usr/bin/env Rscript
script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L]))
home <- dirname(script)
helpers <- normalizePath(file.path(home, "../../fixtures/quadform_geodesics/collection.R"))
source(helpers); source(file.path(home, "interface.R")); source(file.path(home, "runner.R"))
source(file.path(home, "experiments/sensitivity.R"))
args <- commandArgs(trailingOnly = TRUE)
options <- list(repeats = "100", cases = qgx.cases[1L], cohorts = paste(qgx.cohorts, collapse = ","))
flags <- c("--plan-only", "--resume"); seen <- character()
while (length(args)) {
  key <- args[1L]; args <- args[-1L]
  stopifnot(!key %in% seen); seen <- c(seen, key)
  if (key %in% flags) { options[[substring(key, 3L)]] <- TRUE; next }
  stopifnot(key %in% c("--output", "--repeats", "--cases", "--cohorts"), length(args) > 0L)
  options[[substring(key, 3L)]] <- args[1L]; args <- args[-1L]
}
stopifnot(qgs.string(options$output))
plan <- qgx.plan(as.numeric(options$repeats), strsplit(options$cases, ",", fixed = TRUE)[[1L]],
  strsplit(options$cohorts, ",", fixed = TRUE)[[1L]])
output <- options$output
stopifnot(dir.exists(dirname(output)))
output <- file.path(normalizePath(dirname(output)), basename(output))
project <- normalizePath(file.path(home, "../../../.."))
if (output == project || startsWith(output, paste0(project, "/")))
  stop("Study output must be outside the package checkout")
if (file.exists(output)) {
  if (!isTRUE(options$resume) || !dir.exists(output)) stop("Use a new output directory or explicit --resume")
  output <- normalizePath(output)
  if (output == project || startsWith(output, paste0(project, "/"))) stop("Output resolves inside checkout")
} else { stopifnot(!isTRUE(options$resume)); stopifnot(dir.create(output)) }
collection <- qg.read(file.path(dirname(helpers), "v1"))
sources <- unlist(lapply(qgx.methods, function(id) qgs.sources(home, qgx.method(id), helpers)), recursive = FALSE)
sources <- sources[!duplicated(vapply(sources, `[[`, "", "path"))]
manifest <- list(protocol = "qg-three-point-sensitivity-v1", plan = plan, sources = sources,
  collection_sha256 = attr(collection, "sha256"), limits = lapply(qgx.cohorts, qgx.limits),
  process_return_grace_seconds = 5, audit_seconds = 10,
  R = R.version.string, python = Sys.getenv("RETICULATE_PYTHON"),
  packages = vapply(c("jsonlite", "digest", "callr", "ps", "reticulate"),
    function(p) as.character(utils::packageVersion(p)), ""))
if (isTRUE(options$resume)) {
  if (!identical(readRDS(file.path(output, "manifest.rds")), manifest))
    stop("Plan, source, fixture, or environment changed; use a new study directory")
} else {
  qgs.binary(manifest, file.path(output, "manifest.rds")); qgs.write(manifest, file.path(output, "manifest.json"))
  write.csv(plan, file.path(output, "plan.csv"), row.names = FALSE)
  archive <- file.path(output, "sources"); dir.create(archive)
  for (s in sources) {
    relative <- if (startsWith(s$path, paste0(home, "/"))) substring(s$path, nchar(home) + 2L) else "collection.R"
    destination <- file.path(archive, relative); dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
    stopifnot(file.copy(s$path, destination), identical(digest::digest(file = destination, algo = "sha256"), s$sha256))
  }
}
rows <- lapply(seq_len(nrow(plan)), function(i) qgx.row(plan[i, ])); trajectories <- vector("list", nrow(plan))
job_runner <- qgx.supervisor(home)
for (i in seq_len(nrow(plan))) {
  job <- plan[i, ]; directory <- file.path(output, sprintf("%05d", job$job))
  file <- file.path(directory, "record.rds")
  if (file.exists(file)) {
    record <- readRDS(file)
    stopifnot(identical(record$request, qgx.request(collection, job)))
  } else {
    if (isTRUE(options[["plan-only"]])) next
    if (dir.exists(directory)) stop("Interrupted attempt retained at ", directory,
      "; no silent retry. Review it and start a separate study if necessary.")
    qgs.verify.sources(sources); stopifnot(dir.create(directory))
    request <- qgx.request(collection, job); method <- qgx.method(job$method)
    qgs.binary(request, file.path(directory, "request.rds"))
    cat("START", i, "of", nrow(plan), job$case, job$method, job$neighborhood,
      job$cohort, job$direction, job$repeat_label, "\n"); flush.console()
    record <- job_runner(home, helpers, file.path(home, method$file), method, request, directory, sources)
    qgs.binary(record, file)
    cat("END", i, record$search$status, record$search$termination, record$final_audit$status, "\n"); flush.console()
  }
  rows[[i]] <- qgx.row(job, record, collection)
  trajectories[[i]] <- qgx.trajectory(job, record)
  write.csv(do.call(rbind, rows), file.path(output, "runs.csv"), row.names = FALSE)
}
qgs.verify.sources(sources)
invisible(qg.read(file.path(dirname(helpers), "v1")))
qgx.write.summaries(do.call(rbind, rows), do.call(rbind, trajectories), output)
cat(if (isTRUE(options[["plan-only"]])) "Plan saved:" else "Study records saved:", output, "\n")
