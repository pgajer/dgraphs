# Source-only maintenance check; run from the package root with make audit-guides.
ns <- readLines("NAMESPACE", warn = FALSE)
exports <- sub("^export[(](.*)[)]$", "\\1", grep("^export[(]", ns, value = TRUE))
methods <- sub("^S3method[(]([^,]+),([^)]*)[)]$", "\\1.\\2",
               grep("^S3method[(]", ns, value = TRUE))
guide <- readLines("vignettes/function-guide.Rmd", warn = FALSE)
# Generic workflow rows are outside the explicitly delimited catalog.
a <- match("## Function catalog", guide)
b <- match("## Object workflows and method help", guide)
stopifnot(!is.na(a), !is.na(b), a < b)
rows <- grep("^\\| \\[", guide[seq.int(a, b - 1L)], value = TRUE)
catalog <- sub("^.*#help-([^)]*)[)].*$", "\\1", rows)
fail <- function(label, x) if (length(x)) stop(label, ": ", paste(x, collapse = ", "))
fail("Missing catalog exports", setdiff(exports, catalog))
fail("Nonexported catalog entries", setdiff(catalog, exports))
fail("Duplicate catalog rows", catalog[duplicated(catalog)])
stopifnot(all(grepl("\\| .+ \\|$", rows)))
aliases <- character()
for (p in list.files("man", "[.]Rd$", full.names = TRUE)) {
  rd <- tools::parse_Rd(p)
  for (x in rd) if (identical(attr(x, "Rd_tag"), "\\alias"))
    aliases <- c(aliases, paste(unlist(x), collapse = ""))
}
fail("Undocumented exports or methods", setdiff(c(exports, methods), aliases))
method.text <- paste(guide[seq.int(b, length(guide))], collapse = "\n")
links <- regmatches(method.text, gregexpr("#help-[^)]*", method.text))[[1L]]
linked.methods <- setdiff(sub("#help-", "", links), exports)
fail("Missing method help links", setdiff(methods, linked.methods))
fail("Invalid method help links", setdiff(linked.methods, methods))
fail("Duplicate method help links", linked.methods[duplicated(linked.methods)])
# Check that explicit exports have local R function definitions, without evaluation.
definitions <- character()
for (p in list.files("R", "[.]R$", full.names = TRUE)) for (e in parse(p)) {
  if (is.call(e) && length(e) == 3L && as.character(e[[1L]]) %in% c("<-", "=") &&
      is.symbol(e[[2L]]) && is.call(e[[3L]]) && identical(e[[3L]][[1L]], as.name("function")))
    definitions <- c(definitions, as.character(e[[2L]]))
}
fail("Missing local function definitions", setdiff(c(exports, methods), definitions))
stopifnot(any(grepl(sprintf("all %d explicit public exports", length(exports)), guide, fixed = TRUE)),
          any(grepl(sprintf("%d registered S3 methods", length(methods)), guide, fixed = TRUE)))
for (p in list.files("vignettes", "[.]Rmd$", full.names = TRUE)) {
  s <- readLines(p, warn = FALSE)
  stopifnot(!any(grepl("file://|/Users/|/private/|localhost:", s)))
  txt <- paste(s, collapse = "\n")
  refs <- regmatches(txt, gregexpr("\\]\\([a-z][a-z-]+[.]html\\)", txt))[[1L]]
  if (length(refs)) stopifnot(all(file.exists(file.path("vignettes",
    sub("[.]html$", ".Rmd", sub("^\\]\\(|\\)$", "", gsub("\\)$", "", refs)))))))
}
cat(sprintf("Verified %d/%d explicit exports, no duplicate catalog rows; %d/%d registered S3 methods with help links and local definitions.\n",
            length(catalog), length(exports), length(linked.methods), length(methods)))
