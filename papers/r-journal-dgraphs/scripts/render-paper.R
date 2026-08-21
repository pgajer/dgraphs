#!/usr/bin/env Rscript

required <- c("rmarkdown", "rjtools", "dgraphs", "ggplot2", "knitr")
missing <- required[!vapply(required, requireNamespace, logical(1L), quietly = TRUE)]
if (length(missing)) stop("Missing build package(s): ", paste(missing, collapse = ", "))
if (utils::packageVersion("dgraphs") < "0.1.0.9000") {
    stop("The draft requires dgraphs >= 0.1.0.9000; found ",
         utils::packageVersion("dgraphs"))
}

dir.create("build", showWarnings = FALSE, recursive = TRUE)
dir.create("output/pdf", showWarnings = FALSE, recursive = TRUE)
dir.create("output/html", showWarnings = FALSE, recursive = TRUE)
started <- proc.time()[["elapsed"]]

rmarkdown::render(
    input = "dgraphs.Rmd",
    output_format = "rjtools::rjournal_article",
    envir = new.env(parent = globalenv()),
    clean = FALSE,
    quiet = FALSE
)
rmarkdown::render(
    input = "motivation-letter/motivation-letter.md",
    output_file = "motivation-letter.pdf",
    output_dir = "motivation-letter",
    clean = TRUE,
    quiet = TRUE
)

required.outputs <- c(
    "dgraphs.html", "dgraphs.pdf", "dgraphs.tex", "dgraphs.R",
    "motivation-letter/motivation-letter.pdf"
)
missing.outputs <- required.outputs[!file.exists(required.outputs)]
if (length(missing.outputs)) {
    stop("Article build did not create: ", paste(missing.outputs, collapse = ", "))
}

file.copy("dgraphs.pdf", "output/pdf/dgraphs-r-journal.pdf", overwrite = TRUE)
file.copy("dgraphs.html", "output/html/dgraphs-r-journal.html", overwrite = TRUE)

elapsed <- proc.time()[["elapsed"]] - started
writeLines(c(
    paste("dgraphs version:", as.character(utils::packageVersion("dgraphs"))),
    paste("R version:", R.version.string),
    paste("rjtools version:", as.character(utils::packageVersion("rjtools"))),
    sprintf("render seconds: %.3f", elapsed)
), "build/render-info.txt")
message(sprintf("Article render completed in %.2f seconds.", elapsed))
