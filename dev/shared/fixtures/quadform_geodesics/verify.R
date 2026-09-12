#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
file.arg <- grep("^--file=", commandArgs(), value = TRUE)
home <- dirname(normalizePath(sub("^--file=", "", file.arg[[1]]), mustWork = TRUE))
source(file.path(home, "collection.R"))
option <- function(name, default = NULL) {
  i <- match(name, args)
  if (is.na(i)) return(default)
  if (i == length(args)) stop("Missing value for ", name)
  args[[i + 1L]]
}
repo <- normalizePath(file.path(home, "../../../.."), mustWork = TRUE)
if (!requireNamespace("dgraphs", quietly = TRUE) ||
    !"sample.synthetic.geometry" %in% getNamespaceExports("dgraphs"))
  stop("Load the migrated dgraphs installation before validating the collection.")
cat("Using dgraphs:", find.package("dgraphs"), "\n")
x <- qg.read(option("--collection", file.path(home, "v1")))
counts <- qg.validate(x)
cat(sprintf("Fixture checks passed: %d cases, %d pairs, %d analytic controls, %d directed queries.\n",
            counts$cases, counts$pairs, counts$analytic_pairs, counts$directed_queries))
template <- option("--template")
if (!is.null(template)) {
  qg.assert(!file.exists(template), "Refusing to overwrite a results file")
  write.csv(qg.template(x), template, row.names = FALSE, na = "")
  cat("Wrote unexecuted result template:", template, "\n")
}
if ("--self-test" %in% args) source(file.path(home, "test_collection.R"))
result.file <- option("--results")
if (!is.null(result.file)) {
  results <- read.csv(result.file, stringsAsFactors = FALSE, na.strings = "",
                      colClasses = c(distance = "numeric", elapsed_seconds = "numeric"))
  verdict <- qg.check.results(x, results)
  cat(sprintf("Consistent submitted answers: %d/%d. %s.\n", verdict$ok, verdict$total, verdict$meaning))
  if (!verdict$complete) quit(status = 2L)
} else cat("No geodesic solver was executed or certified.\n")
