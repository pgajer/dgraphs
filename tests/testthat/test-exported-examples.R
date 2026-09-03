rd.tags <- function(rd) {
    vapply(
        rd,
        function(node) {
            tag <- attr(node, "Rd_tag", exact = TRUE)
            if (is.null(tag)) "" else tag
        },
        character(1)
    )
}

rd.node.text <- function(node) {
    paste(unlist(node, recursive = TRUE, use.names = FALSE), collapse = "")
}

test_that("every exported function and registered S3 method has an example", {
    source.root <- normalizePath(
        file.path(testthat::test_path(), "..", ".."),
        mustWork = FALSE
    )
    source.namespace <- file.path(source.root, "NAMESPACE")

    if (file.exists(source.namespace)) {
        namespace.lines <- trimws(readLines(source.namespace, warn = FALSE))
        exported.functions <- sub(
            "^export\\((.*)\\)$",
            "\\1",
            namespace.lines[grepl("^export\\(", namespace.lines)]
        )
        registered.methods <- sub(
            "^S3method\\(([^,]+),([^,]+)\\)$", "\\1.\\2",
            namespace.lines[grepl("^S3method\\(", namespace.lines)]
        )
        exported.functions <- c(exported.functions, registered.methods)
        rd.db <- lapply(
            list.files(
                file.path(source.root, "man"),
                pattern = "[.]Rd$",
                full.names = TRUE
            ),
            tools::parse_Rd
        )
    } else {
        exported.functions <- getNamespaceExports("dgraphs")
        exported.functions <- exported.functions[vapply(
            exported.functions,
            function(name) is.function(getExportedValue("dgraphs", name)),
            logical(1)
        )]
        methods <- getNamespaceInfo(asNamespace("dgraphs"), "S3methods")
        exported.functions <- c(exported.functions, paste(methods[, 1L],
                                                        methods[, 2L], sep = "."))
        rd.db <- tools::Rd_db("dgraphs")
    }

    aliases.with.examples <- unlist(lapply(rd.db, function(rd) {
        tags <- rd.tags(rd)
        aliases <- vapply(
            rd[tags == "\\alias"],
            rd.node.text,
            character(1)
        )
        examples <- rd[tags == "\\examples"]
        has.examples <- length(examples) > 0L && any(nzchar(trimws(vapply(
            examples,
            rd.node.text,
            character(1)
        ))))
        if (has.examples) aliases else character()
    }), use.names = FALSE)

    missing.examples <- setdiff(
        sort(unique(exported.functions)),
        sort(unique(aliases.with.examples))
    )
    expect_length(
        missing.examples,
        0L
    )
})
