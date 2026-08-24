#!/usr/bin/env Rscript

required <- c(dgraphs = "0.2.0", grip = "0.2.0")
available <- utils::available.packages(
    repos = c(CRAN = "https://cloud.r-project.org"),
    filters = list()
)
missing <- setdiff(names(required), rownames(available))
if (length(missing)) {
    stop("R Journal submission gate: not listed in the CRAN index: ",
         paste(missing, collapse = ", "))
}

public <- vapply(
    names(required),
    function(package) available[package, "Version"],
    character(1L)
)
outdated <- names(required)[
    vapply(
        names(required),
        function(package) {
            package_version(public[[package]]) < package_version(required[[package]])
        },
        logical(1L)
    )
]
if (length(outdated)) {
    details <- paste0(
        outdated,
        " ",
        public[outdated],
        " (requires >= ",
        required[outdated],
        ")"
    )
    stop(
        "Coordinated R Journal submission gate: publish both 0.2.0 releases ",
        "before submitting the companion articles; CRAN currently has ",
        paste(details, collapse = ", ")
    )
}
message(
    "Coordinated public-version gate passed: ",
    paste(paste0(names(public), " ", public), collapse = ", ")
)
