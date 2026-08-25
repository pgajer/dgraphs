#!/usr/bin/env Rscript

required <- c("rmarkdown", "rjtools", "dgraphs", "ggplot2", "knitr")
missing <- required[!vapply(required, requireNamespace, logical(1L), quietly = TRUE)]
if (length(missing)) stop("Missing build package(s): ", paste(missing, collapse = ", "))
if (utils::packageVersion("dgraphs") < "0.2.0") {
    stop("The draft requires dgraphs >= 0.2.0; found ",
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
# The web-oriented R Journal format builds a PDF in a clean subprocess and
# removes its supporting figures. Render the PDF source once more without
# cleanup so the submission archive contains a directly buildable TeX tree.
rmarkdown::render(
    input = "dgraphs.Rmd",
    output_format = rjtools::rjournal_pdf_article(),
    envir = new.env(parent = globalenv()),
    clean = FALSE,
    quiet = TRUE
)
letter.source <- "motivation-letter/motivation-letter.md"
if (file.exists(letter.source)) {
    rmarkdown::render(
        input = letter.source,
        output_file = "motivation-letter.pdf",
        output_dir = "motivation-letter",
        clean = TRUE,
        quiet = TRUE
    )
}

required.outputs <- c(
    "dgraphs.html", "dgraphs.pdf", "dgraphs.tex", "dgraphs.R",
    file.path(
        "dgraphs_files", "figure-latex",
        c(
            "workflow-figure-1.pdf",
            "pipeline-timing-1.pdf",
            "family-fidelity-1.pdf"
        )
    )
)
if (file.exists(letter.source)) {
    required.outputs <- c(
        required.outputs,
        "motivation-letter/motivation-letter.pdf"
    )
}
missing.outputs <- required.outputs[!file.exists(required.outputs)]
if (length(missing.outputs)) {
    stop("Article build did not create: ", paste(missing.outputs, collapse = ", "))
}

file.copy("dgraphs.pdf", "output/pdf/dgraphs-r-journal.pdf", overwrite = TRUE)
file.copy("dgraphs.html", "output/html/dgraphs-r-journal.html", overwrite = TRUE)

# dgraphs.tex is an article fragment whose TeX root is RJwrapper.tex. Some
# render paths leave a failed standalone fragment log; it is non-authoritative
# and must not be retained or used by release checks.
if (file.exists("dgraphs.log")) unlink("dgraphs.log")

elapsed <- proc.time()[["elapsed"]] - started
writeLines(c(
    paste("dgraphs version:", as.character(utils::packageVersion("dgraphs"))),
    paste("R version:", R.version.string),
    paste("rjtools version:", as.character(utils::packageVersion("rjtools"))),
    sprintf("render seconds: %.3f", elapsed)
), "build/render-info.txt")
message(sprintf("Article render completed in %.2f seconds.", elapsed))
