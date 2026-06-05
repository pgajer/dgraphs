args <- commandArgs(FALSE)
file.arg <- args[grepl("^--file=", args)]
script.path <- if (length(file.arg) > 0L) {
    sub("^--file=", "", file.arg[[1L]])
} else {
    "tests/migration/run_gflow_parity_tests.R"
}
script.path <- normalizePath(script.path, mustWork = TRUE)
migration.dir <- dirname(script.path)
repo.root <- normalizePath(file.path(migration.dir, "..", ".."), mustWork = TRUE)
setwd(repo.root)

gflow.path <- Sys.getenv(
    "DGRAPHS_GFLOW_PARITY_SOURCE",
    "/Users/pgajer/current_projects/gflow"
)
gflow.path <- normalizePath(gflow.path, mustWork = FALSE)
if (!file.exists(file.path(gflow.path, "DESCRIPTION"))) {
    stop(
        "Local gflow parity source is unavailable at ", gflow.path,
        ". Set DGRAPHS_GFLOW_PARITY_SOURCE to a local gflow checkout.",
        call. = FALSE
    )
}

if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("Package 'pkgload' is required for migration parity tests.", call. = FALSE)
}
if (!requireNamespace("testthat", quietly = TRUE)) {
    stop("Package 'testthat' is required for migration parity tests.", call. = FALSE)
}

Sys.setenv(DGRAPHS_GFLOW_PARITY_SOURCE = gflow.path)

pkgload::load_all(repo.root, quiet = TRUE)
pkgload::load_all(gflow.path, quiet = TRUE)

test.files <- sort(Sys.glob(file.path(migration.dir, "test-*-gflow-parity.R")))
if (length(test.files) == 0L) {
    stop("No migration parity tests found in ", migration.dir, ".", call. = FALSE)
}

all.results <- lapply(test.files, function(test.file) {
    testthat::test_file(test.file, reporter = "summary")
})

n.failed <- sum(vapply(all.results, function(x) sum(x[["failed"]]), integer(1)))
n.errors <- sum(vapply(all.results, function(x) sum(x[["error"]]), integer(1)))
n.skipped <- sum(vapply(all.results, function(x) sum(x[["skipped"]]), integer(1)))

if (n.failed > 0L || n.errors > 0L || n.skipped > 0L) {
    message(
        "Migration parity tests did not fully pass: ",
        n.failed, " failed, ",
        n.errors, " errored, ",
        n.skipped, " skipped."
    )
    quit(status = 1L)
}
