# Validator regression tests; x is the verified collection loaded by verify.R.
local({
  checks <- 0L
  check <- function(ok) {
    stopifnot(isTRUE(ok))
    checks <<- checks + 1L
  }
  rejects <- function(expr, pattern) {
    message <- tryCatch({ force(expr); NULL }, error = conditionMessage)
    check(!is.null(message) && grepl(pattern, message, fixed = TRUE))
  }
  tmp <- tempfile("quadform-validator-tests-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  original.seal <- readLines(file.path(attr(x, "directory"), "SEAL.sha256"))
  counts <- qg.validate(x, package.check = FALSE)
  check(identical(unlist(counts), c(cases = 30L, pairs = 197L,
                                  analytic_pairs = 71L, directed_queries = 394L)))
  broken <- x; broken$cases[[2]]$id <- broken$cases[[1]]$id
  rejects(qg.validate(broken, FALSE), "Duplicate or missing case IDs")
  broken <- x; broken$cases[[1]]$domain$kind <- "hull"
  rejects(qg.validate(broken, FALSE), "Invalid domain/dimension")
  broken <- x; broken$cases[[1]]$pairs[[1]]$from <- list(2, 0)
  rejects(qg.validate(broken, FALSE), "Endpoint outside declared domain")
  broken <- x; broken$cases[[1]]$pairs[[2]]$exact$value <- 1
  rejects(qg.validate(broken, FALSE), "Exact control disagrees")
  curved <- which(vapply(x$cases, `[[`, character(1), "id") == "paraboloid2_disk")
  broken <- x; broken$cases[[curved]]$pairs[[2]]$exact$value <- 1
  rejects(qg.validate(broken, FALSE), "Unknown distance has invented truth")
  regression <- which(vapply(x$cases, `[[`, character(1), "id") == "regression_paraboloid4102")
  broken <- x; broken$cases[[regression]]$pairs[[1]]$source$zero_based_rows <- list(0L, 1L)
  rejects(qg.validate(broken, FALSE), "Regression endpoints differ")
  broken <- x; broken$robustness_inputs[[1]]$latent_path[[2]] <- list(4, 4)
  rejects(qg.validate(broken, FALSE), "Invalid robustness path")
  broken <- x; broken$relations[[1]]$factor <- 2
  rejects(qg.validate(broken, FALSE), "Invalid scaling relation")

  copy <- file.path(tmp, "copy")
  dir.create(copy)
  originals <- list.files(attr(x, "directory"), full.names = TRUE)
  check(all(file.copy(originals, copy, recursive = TRUE)))
  check(identical(attr(qg.read(copy), "sha256"), attr(x, "sha256")))
  writeLines("tampered", file.path(copy, "INDEX.md"))
  rejects(qg.read(copy), "Checksum mismatch")
  file.copy(file.path(attr(x, "directory"), "INDEX.md"), copy, overwrite = TRUE)
  writeLines("stray", file.path(copy, "unexpected.txt"))
  rejects(qg.read(copy), "Unexpected or missing files")
  unlink(file.path(copy, "unexpected.txt"))
  writeLines("tampered", file.path(copy, "manifest.json"))
  rejects(qg.read(copy), "Manifest seal mismatch")

  template <- qg.template(x)
  verdict <- qg.check.results(x, template)
  check(!verdict$complete && verdict$ok == 0L && verdict$total == 394L)
  csv <- file.path(tmp, "template.csv")
  write.csv(template, csv, row.names = FALSE, na = "")
  reread <- read.csv(csv, na.strings = "", stringsAsFactors = FALSE,
                     colClasses = c(distance = "numeric", elapsed_seconds = "numeric"))
  check(!qg.check.results(x, reread)$complete)
  rejects(qg.check.results(x, template[-1, ]), "cover every query")
  broken <- template; broken$collection_sha256[1] <- "wrong"
  rejects(qg.check.results(x, broken), "Wrong collection checksum")
  broken <- template; broken$status[1] <- "failed"
  broken$method[1] <- "mock"; broken$solver_revision[1] <- "test-only"
  broken$elapsed_seconds[1] <- 0
  rejects(qg.check.results(x, broken), "need diagnostics")
  broken$diagnostic[1] <- "Intentional regression-test failure"
  check(!qg.check.results(x, broken)$complete)
  broken$distance[1] <- 0
  rejects(qg.check.results(x, broken), "Non-ok queries")

  flat <- x
  flat$cases <- x$cases[1:6]
  flat$relations <- flat$cloud_workloads <- flat$robustness_inputs <- list()
  result <- qg.template(flat)
  result$method <- "analytic-fixture-self-test"
  result$solver_revision <- "test-only"
  result$status <- "ok"; result$elapsed_seconds <- 0
  result$distance <- rep(unlist(lapply(flat$cases, function(case) {
    vapply(case$pairs, function(pair) pair$exact$value, numeric(1))
  })), each = 2L)
  check(qg.check.results(flat, result)$complete)
  check(qg.check.results(flat, result[nrow(result):1L, ])$complete)
  broken <- result; broken$distance[1] <- NaN
  rejects(qg.check.results(flat, broken), "finite and nonnegative")
  broken <- result; broken$distance[1] <- -1
  rejects(qg.check.results(flat, broken), "finite and nonnegative")
  broken <- result; broken$distance[1] <- 1e-15
  rejects(qg.check.results(flat, broken), "Identity distance must be zero")
  broken <- result; broken$solver_revision[1] <- ""
  rejects(qg.check.results(flat, broken), "method and solver revision")
  broken <- result; broken$elapsed_seconds[1] <- Inf
  rejects(qg.check.results(flat, broken), "nonnegative finite runtime")
  # An eight-neighbor flat-grid answer is longer than the Euclidean geodesic.
  broken <- result
  broken$distance[result$pair_id == "grid_direction"] <- 0.4 * (1 + sqrt(2))
  rejects(qg.check.results(flat, broken), "violates geometric bounds")
  check(identical(original.seal, readLines(file.path(attr(x, "directory"), "SEAL.sha256"))))
  check(identical(attr(qg.read(attr(x, "directory")), "sha256"), attr(x, "sha256")))
  cat(sprintf("Validator self-tests passed: %d checks. Mock answers are not solver evidence.\n", checks))
})
