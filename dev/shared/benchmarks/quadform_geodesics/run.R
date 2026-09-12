#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
home <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])))
fixture.home <- normalizePath(file.path(home, "../../fixtures/quadform_geodesics"))
source(file.path(fixture.home, "collection.R"))
source(file.path(home, "interface.R"))
source(file.path(home, "runner.R"))
if (identical(args, "--list")) {
  for (method in qgs.registry(home)) cat(sprintf("%-24s %-12s %s\n", method$id, method$status, method$scope))
  quit(status = 0)
}
if (!length(args) || identical(args, "--help")) {
  cat("Usage: Rscript run.R --list\n",
      "       Rscript run.R --method ID --output NEW_DIRECTORY [--case CASE_ID]\n",
      "                    [--repeat 4101] [--config CONFIG_JSON]\n",
      "CONFIG_JSON: object with parameters and/or limits (edge_calls, seconds, max_vertices, rss_mib).\n",
      "Each invocation is one method/configuration/repeat; both directions are always selected.\n",
      "Exit 0: complete consistent results; 2: incomplete; 1: validation failure.\n", sep = "")
  quit(status = 0)
}
qg.assert(length(args) %% 2 == 0, "Options require values")
options <- args[seq(1, length(args), 2)]
qg.assert(!anyDuplicated(options) && all(options %in% c("--method", "--output", "--case", "--repeat", "--config")),
          "Unknown or duplicated option")
values <- as.list(args[seq(2, length(args), 2)]); names(values) <- options
qg.assert(all(c("--method", "--output") %in% options), "Provide --method and --output")
config <- if (is.null(values[["--config"]])) list() else {
  jsonlite::fromJSON(values[["--config"]], simplifyVector = FALSE)
}
qg.assert(is.list(config) && all(names(config) %in% c("parameters", "limits")), "Unknown config fields")
parameters <- if (is.null(config$parameters)) list() else config$parameters
limits <- if (is.null(config$limits)) list() else config$limits
repeat.label <- if (is.null(values[["--repeat"]])) "4101" else values[["--repeat"]]
selection <- NULL
if (!is.null(values[["--case"]])) {
  x <- qg.read(file.path(fixture.home, "v1"))
  rows <- qg.template(x)
  selection <- rows[rows$case_id == values[["--case"]], c("case_id", "pair_id", "direction")]
}
result <- qgs.run(home, file.path(fixture.home, "v1"), values[["--method"]], values[["--output"]],
                  selection, repeat.label, parameters, limits)
cat("Output:", result$output, "\n")
cat("Fixture gate:", result$verdict$status, "; ok rows:", sum(result$rows$status == "ok"),
    "/", nrow(result$rows), "\n")
quit(status = if (result$verdict$status == "failed") 1L else if (isTRUE(result$verdict$complete)) 0L else 2L)
