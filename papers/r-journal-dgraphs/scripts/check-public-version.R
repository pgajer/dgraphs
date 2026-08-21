#!/usr/bin/env Rscript

minimum <- package_version("0.1.1")
available <- utils::available.packages(
    repos = c(CRAN = "https://cloud.r-project.org"),
    filters = list()
)
if (!"dgraphs" %in% rownames(available)) stop("dgraphs is not listed in the CRAN index")
public <- package_version(available["dgraphs", "Version"])
if (public < minimum) {
    stop("R Journal submission gate: CRAN has dgraphs ", public,
         "; publish version ", minimum, " or later before submitting the article")
}
message("Public-version gate passed: CRAN dgraphs ", public)
