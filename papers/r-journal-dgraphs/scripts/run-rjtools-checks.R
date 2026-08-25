#!/usr/bin/env Rscript

if (!requireNamespace("rjtools", quietly = TRUE)) stop("rjtools is required")
dir.create("build", showWarnings = FALSE, recursive = TRUE)
logfile <- file.path(normalizePath("build", mustWork = TRUE), "rjtools-checks.log")
if (file.exists(logfile)) file.remove(logfile)

stage <- tempfile("dgraphs-rjtools-check-")
dir.create(stage, recursive = TRUE)
on.exit(unlink(stage, recursive = TRUE, force = TRUE), add = TRUE)

top.level <- c(
    "dgraphs.Rmd", "dgraphs.tex", "dgraphs.R", "dgraphs.pdf",
    "RJreferences.bib", "RJournal.sty", "_Rpackages.txt"
)
if (!all(file.copy(top.level, stage, overwrite = TRUE))) {
    stop("Could not stage generated article files for rjtools checks")
}
dir.create(file.path(stage, "motivation-letter"))
letter <- c(
    "motivation-letter/motivation-letter.md",
    "motivation-letter/motivation-letter.pdf"
)
if (!all(file.copy(letter, file.path(stage, "motivation-letter"), overwrite = TRUE))) {
    stop("Could not stage the motivation letter")
}

connection <- file(logfile, open = "a", encoding = "UTF-8")
on.exit(close(connection), add = TRUE)
old <- options(
    check.log.file = connection,
    check.log.journal = new.env(parent = emptyenv())
)
on.exit(options(old), add = TRUE)

checks <- list(
    filenames = rjtools::check_filenames(stage),
    structure = rjtools::check_structure(stage),
    folders = rjtools::check_folder_structure(stage),
    unnecessary = rjtools::check_unnecessary_files(stage),
    cover_letter = rjtools::check_cover_letter(stage),
    title = rjtools::check_title(stage),
    sections = rjtools::check_section(stage),
    abstract = rjtools::check_abstract(stage),
    spelling = rjtools::check_spelling(
        stage,
        ignore = c(
            "dgraphs", "igraph", "dbscan", "knn", "cknn", "iknn",
            "geodesics", "lifecycle", "backend", "backends", "dataset",
            "datasets", "factor-specific", "tie-free", "vectorized",
            "embeddings", "inspectable", "kd", "th", "undirected",
            "selectk", "isometry", "extrema", "devel"
        )
    ),
    proposed_package = rjtools::check_proposed_pkg("dgraphs", ask = FALSE),
    package_labels = rjtools::check_pkg_label(stage),
    package_availability = rjtools::check_packages_available(stage),
    bibliography = rjtools::check_bib_doi(stage),
    csl = rjtools::check_csl(stage)
)

results <- getOption("check.log.journal")$results
capture.output(str(list(return_values = checks, results = results)),
               file = "build/rjtools-results.txt")
flat <- unlist(results, recursive = TRUE, use.names = TRUE)
if (any(grepl("ERROR|FAIL", as.character(flat), ignore.case = TRUE))) {
    stop("rjtools reported an error; see ", logfile,
         " and build/rjtools-results.txt")
}
message(
    "All durable rjtools checks completed without an error status. ",
    "Run make submission-date SUBMISSION_DATE=YYYY-MM-DD on the actual ",
    "submission date."
)
