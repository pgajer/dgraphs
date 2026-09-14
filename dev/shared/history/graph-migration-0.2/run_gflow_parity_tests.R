.run.gflow.parity.tests <- function() {
    args <- commandArgs(FALSE)
    file.arg <- args[grepl("^--file=", args)]
    script.path <- if (length(file.arg) > 0L) {
        sub("^--file=", "", file.arg[[1L]])
    } else {
        "tests/migration/run_gflow_parity_tests.R"
    }
    script.path <- normalizePath(script.path, mustWork = TRUE)
    migration.dir <- dirname(script.path)
    repo.root <- normalizePath(
        file.path(migration.dir, "..", ".."),
        mustWork = TRUE
    )
    setwd(repo.root)

    if (!requireNamespace("pkgload", quietly = TRUE)) {
        stop(
            "Package 'pkgload' is required for migration parity tests.",
            call. = FALSE
        )
    }
    if (!requireNamespace("testthat", quietly = TRUE)) {
        stop(
            "Package 'testthat' is required for migration parity tests.",
            call. = FALSE
        )
    }

    explicit.source <- Sys.getenv("DGRAPHS_GFLOW_PARITY_SOURCE", "")
    oracle.commit <- Sys.getenv(
        "DGRAPHS_GFLOW_PARITY_COMMIT",
        "663bc8454132ee9324717c09aae4c1ee4327c145"
    )
    created.worktree <- FALSE

    if (nzchar(explicit.source)) {
        gflow.path <- normalizePath(explicit.source, mustWork = FALSE)
    } else {
        gflow.repo <- Sys.getenv(
            "DGRAPHS_GFLOW_REPO",
            file.path(dirname(repo.root), "gflow")
        )
        gflow.repo <- normalizePath(gflow.repo, mustWork = FALSE)
        if (!file.exists(file.path(gflow.repo, ".git"))) {
            stop(
                "The gflow git repository is unavailable at ", gflow.repo,
                ". Set DGRAPHS_GFLOW_REPO or DGRAPHS_GFLOW_PARITY_SOURCE.",
                call. = FALSE
            )
        }

        gflow.path <- tempfile("dgraphs-gflow-oracle-")
        worktree.output <- system2(
            "git",
            c(
                "-C", shQuote(gflow.repo),
                "worktree", "add", "--detach",
                shQuote(gflow.path),
                shQuote(oracle.commit)
            ),
            stdout = TRUE,
            stderr = TRUE
        )
        worktree.status <- attr(worktree.output, "status")
        if (is.null(worktree.status)) {
            worktree.status <- 0L
        }
        if (worktree.status != 0L) {
            stop(
                "Unable to create pinned gflow parity worktree:\n",
                paste(worktree.output, collapse = "\n"),
                call. = FALSE
            )
        }
        created.worktree <- TRUE
        on.exit(
            system2(
                "git",
                c(
                    "-C", shQuote(gflow.repo),
                    "worktree", "remove", "--force",
                    shQuote(gflow.path)
                ),
                stdout = FALSE,
                stderr = FALSE
            ),
            add = TRUE
        )
    }

    if (!file.exists(file.path(gflow.path, "DESCRIPTION"))) {
        stop(
            "gflow parity source is unavailable at ", gflow.path, ".",
            call. = FALSE
        )
    }

    message(
        "Using gflow parity oracle: ",
        if (created.worktree) oracle.commit else gflow.path
    )
    Sys.setenv(DGRAPHS_GFLOW_PARITY_SOURCE = gflow.path)

    pkgload::load_all(repo.root, quiet = TRUE)
    pkgload::load_all(gflow.path, quiet = TRUE)

    test.files <- sort(
        Sys.glob(file.path(migration.dir, "test-*-gflow-parity.R"))
    )
    if (length(test.files) == 0L) {
        stop(
            "No migration parity tests found in ", migration.dir, ".",
            call. = FALSE
        )
    }

    all.results <- lapply(test.files, function(test.file) {
        testthat::test_file(test.file, reporter = "summary")
    })

    expectations <- list()
    for (file.results in all.results) {
        for (test.result in file.results) {
            expectations <- c(expectations, test.result$results)
        }
    }

    count.class <- function(class.name) {
        sum(vapply(
            expectations,
            inherits,
            logical(1),
            what = class.name
        ))
    }
    n.failed <- count.class("expectation_failure")
    n.errors <- count.class("expectation_error")
    n.skipped <- count.class("expectation_skip")
    n.warnings <- count.class("expectation_warning")

    if (n.failed > 0L || n.errors > 0L ||
        n.skipped > 0L || n.warnings > 0L) {
        stop(
            "Migration parity tests did not fully pass: ",
            n.failed, " failed, ",
            n.errors, " errored, ",
            n.warnings, " warned, ",
            n.skipped, " skipped.",
            call. = FALSE
        )
    }

    message(
        "Migration parity tests passed: ",
        length(expectations), " expectations across ",
        length(test.files), " files."
    )
    invisible(all.results)
}

.run.gflow.parity.tests()
