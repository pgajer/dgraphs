#!/usr/bin/env Rscript

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 1L || !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", arguments)) {
    stop("Usage: check-submission-date.R YYYY-MM-DD")
}
expected <- arguments[[1L]]
if (is.na(as.Date(expected))) stop("Invalid expected submission date: ", expected)

rmd <- readLines("dgraphs.Rmd", warn = FALSE)
date.line <- grep('^date: *"?[0-9]{4}-[0-9]{2}-[0-9]{2}"? *$', rmd, value = TRUE)
if (length(date.line) != 1L) stop("Could not identify one manuscript YAML date")
source.date <- sub('^date: *"?([0-9]{4}-[0-9]{2}-[0-9]{2})"? *$', '\\1', date.line)
if (!identical(source.date, expected)) {
    stop("Manuscript date is ", source.date, "; expected ", expected,
         ". Update dgraphs.Rmd immediately before final submission.")
}

html <- paste(readLines("dgraphs.html", warn = FALSE), collapse = "\n")
if (!grepl(paste0('itemprop="datePublished" content="', expected, '"'), html,
           fixed = TRUE)) {
    stop("Rendered HTML does not contain the expected submission date ", expected)
}
message("Explicit submission-date gate passed: ", expected)
