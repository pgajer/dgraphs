#!/usr/bin/env Rscript

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 1L || !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", arguments)) {
    stop("Usage: check-submission-date.R YYYY-MM-DD")
}
expected <- arguments[[1L]]
if (is.na(as.Date(expected))) stop("Invalid expected submission date: ", expected)

source.files <- c(
    article = "dgraphs.Rmd",
    `motivation letter` = "motivation-letter/motivation-letter.md"
)
source.files <- source.files[file.exists(source.files)]
for (label in names(source.files)) {
    source <- readLines(source.files[[label]], warn = FALSE)
    date.line <- grep(
        '^date: *"?[0-9]{4}-[0-9]{2}-[0-9]{2}"? *$',
        source,
        value = TRUE
    )
    if (length(date.line) != 1L) {
        stop("Could not identify one YAML date in ", source.files[[label]])
    }
    source.date <- sub(
        '^date: *"?([0-9]{4}-[0-9]{2}-[0-9]{2})"? *$',
        '\\1',
        date.line
    )
    if (!identical(source.date, expected)) {
        stop(
            label, " date is ", source.date, "; expected ", expected,
            ". Update the dated source immediately before final submission."
        )
    }
}

html <- paste(readLines("dgraphs.html", warn = FALSE), collapse = "\n")
if (!grepl(paste0('itemprop="datePublished" content="', expected, '"'), html,
           fixed = TRUE)) {
    stop("Rendered HTML does not contain the expected submission date ", expected)
}
message("Explicit submission-date gate passed: ", expected)
