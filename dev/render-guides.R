# Render from the maintained sources using the package installed by R CMD check.
root <- normalizePath(".")
lib <- file.path(root, "build", "dgraphs.Rcheck")
if (!dir.exists(file.path(lib, "dgraphs")))
  stop("Run make check first to install the candidate in build/dgraphs.Rcheck.")
.libPaths(c(lib, .libPaths()))
stopifnot(as.character(utils::packageVersion("dgraphs")) ==
          read.dcf("DESCRIPTION")[1L, "Version"])
out <- file.path(root, "build", "validation", "vignettes")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
for (name in c("function-guide", "synthetic-geometry", "data-derived-graph-workflow")) {
  tmp <- tempfile("dgraphs-vignette-")
  dir.create(tmp)
  rmarkdown::render(file.path(root, "vignettes", paste0(name, ".Rmd")),
                    output_dir = out, intermediates_dir = tmp,
                    envir = new.env(parent = globalenv()), quiet = TRUE)
  unlink(tmp, recursive = TRUE)
}
cat("HTML previews: ", out, "\n", sep = "")
