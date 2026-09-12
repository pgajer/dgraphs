qgs.registry <- function(home) {
  registry <- jsonlite::fromJSON(file.path(home, "registry.json"), simplifyVector = FALSE)
  qg.assert(identical(registry$interface_version, qgs.version), "Registry version mismatch")
  ids <- vapply(registry$methods, `[[`, "", "id")
  qg.assert(!anyDuplicated(ids), "Duplicate method IDs")
  registry$methods
}

qgs.load.adapter <- function(path, id) {
  adapter <- source(path, local = new.env(parent = globalenv()))$value
  qg.assert(is.list(adapter) && identical(adapter$id, id) &&
              identical(adapter$interface_version, qgs.version), "Adapter identity/version mismatch")
  adapter
}

qgs.sources <- function(home, method, fixture.helpers) {
  relative <- c("interface.R", "runtime.R", "clock.c", "runner.R", "supervisor.R", "reporting.R", "registry.json", method$file, unlist(method$sources))
  qg.assert(!any(grepl("(^/|(^|/)\\.\\.(/|$))", relative)), "Unsafe source path")
  paths <- unique(c(file.path(home, relative), fixture.helpers))
  lapply(paths, function(path) list(path = normalizePath(path, mustWork = TRUE),
    sha256 = digest::digest(file = path, algo = "sha256")))
}

qgs.verify.sources <- function(sources) {
  for (s in sources) qg.assert(identical(digest::digest(file = s$path, algo = "sha256"), s$sha256),
                              paste("Source changed during run:", s$path))
}

qgs.job <- function(home, fixture.helpers, adapter.path, method, request, directory,
                    sources, audit.seconds = 10) {
  qgs.job.v2(home, fixture.helpers, adapter.path, method, request, directory, sources, audit.seconds)
}

qgs.row <- function(collection, record, revision) {
  r <- record$request
  mini <- collection
  case <- collection$cases[[match(r$case_id, vapply(collection$cases, `[[`, "", "id"))]]
  case$pairs <- case$pairs[match(r$pair_id, vapply(case$pairs, `[[`, "", "id"))]
  case$triangles <- list(); mini$cases <- list(case); mini$relations <- list()
  rows <- qg.template(mini)
  index <- which(rows$case_id == r$case_id & rows$pair_id == r$pair_id & rows$direction == r$direction)
  row <- rows[index, , drop = FALSE]
  row$method <- r$method_id; row$solver_revision <- revision
  row$elapsed_seconds <- record$end_to_end_seconds
  row$status <- if (identical(record$search$status, "unsupported")) "unsupported" else "failed"
  row$diagnostic <- paste(record$search$termination, record$final_audit$status, sep = ": ")
  if (identical(record$search$status, "candidate") && identical(record$final_audit$status, "passed")) {
    # Assess this row alone first. Cross-query checks remain an explicit later gate.
    row$status <- "ok"; row$distance <- record$final_audit$length
    rows[index, ] <- row
    error <- tryCatch({ qg.check.results(mini, rows); NULL }, error = conditionMessage)
    if (!is.null(error)) {
      row$status <- "failed"; row$distance <- NA_real_; row$diagnostic <- error
    }
  }
  row
}

qgs.run <- function(home, collection.directory, method_id, output, selection = NULL,
                    repeat_label = "4101", parameters = list(), limits = list()) {
  home <- normalizePath(home, mustWork = TRUE)
  helpers <- normalizePath(file.path(collection.directory, "../collection.R"), mustWork = TRUE)
  collection <- qg.read(collection.directory)
  invisible(qg.validate(collection, package.check = FALSE))
  registry <- qgs.registry(home)
  index <- match(method_id, vapply(registry, `[[`, "", "id"))
  method <- if (is.na(index)) NULL else registry[[index]]
  qg.assert(!is.null(method), "Unknown method")
  qg.assert(identical(method$status, "implemented"), "Method is planned, not implemented; no fallback is allowed")
  sources <- qgs.sources(home, method, helpers)
  adapter.path <- normalizePath(file.path(home, method$file), mustWork = TRUE)
  qgs.load.adapter(adapter.path, method_id)
  parameters <- qgs.parameters(parameters)
  config <- list(interface_version = qgs.version, method_id = method_id,
                 parameters = parameters, limits = qgs.limits(limits), repeat_label = repeat_label)
  config.id <- digest::digest(jsonlite::toJSON(config, auto_unbox = TRUE, digits = NA),
                              algo = "sha256", serialize = FALSE)
  revision <- digest::digest(vapply(sources, `[[`, "", "sha256"), algo = "sha256")
  rows <- qg.template(collection)
  key <- function(z) paste(z$case_id, z$pair_id, z$direction, sep = "/")
  if (is.null(selection)) selected <- seq_len(nrow(rows))
  else {
    qg.assert(is.data.frame(selection) && all(c("case_id", "pair_id", "direction") %in% names(selection)) &&
                !anyDuplicated(key(selection)) && all(key(selection) %in% key(rows)), "Invalid selection")
    selected <- match(key(selection), key(rows))
  }
  qg.assert(length(selected) > 0, "Empty selection")
  requests <- lapply(selected, function(i) {
    r <- qgs.request(collection, rows$case_id[i], rows$pair_id[i], rows$direction[i],
                     repeat_label, parameters, limits)
    r$method_id <- method_id; r$config_id <- config.id
    r
  })
  qg.assert(!file.exists(output), "Output must be a new directory; no overwrite or implicit resume")
  qg.assert(dir.exists(dirname(output)), "Output parent must already exist")
  output <- file.path(normalizePath(dirname(output), mustWork = TRUE), basename(output))
  frozen <- normalizePath(collection.directory, mustWork = TRUE)
  qg.assert(!startsWith(output, paste0(frozen, "/")), "Cannot write inside frozen collection")
  qg.assert(dir.create(output), "Cannot create output directory")
  output <- normalizePath(output)
  plan <- rows
  plan$selected <- seq_len(nrow(rows)) %in% selected
  write.csv(plan, file.path(output, "plan.csv"), row.names = FALSE, na = "")
  manifest <- list(interface_version = qgs.version, collection_sha256 = attr(collection, "sha256"),
    configuration = config, config_id = config.id, solver_revision = revision, sources = sources,
    environment = list(R = R.version.string, platform = as.list(Sys.info()),
      libraries = lapply(c("jsonlite", "digest", "callr", "ps", "processx"), function(p)
        list(package = p, version = as.character(utils::packageVersion(p))))),
    selected_queries = length(selected), total_queries = nrow(rows),
    limitations = c("RSS is sampled, not an OS address-space limit", "No interrupted-solver resume or automatic retries",
      "Lifted-segment audit only; no general accuracy or optimality certification"))
  qgs.write(manifest, file.path(output, "manifest.json"))
  for (j in seq_along(selected)) {
    i <- selected[j]; request <- requests[[j]]
    directory <- file.path(output, "queries", sprintf("%04d", i))
    dir.create(directory, recursive = TRUE)
    qgs.binary(request, file.path(directory, "request.rds"))
    qgs.write(request, file.path(directory, "request.json"))
    record <- qgs.job(home, helpers, adapter.path, method, request, directory, sources)
    qgs.binary(record, file.path(directory, "record.rds"))
    qgs.write(record, file.path(directory, "record.json"))
    rows[i, ] <- qgs.row(collection, record, revision)
    # Keep a complete ledger, including all unselected/not-yet-run queries.
    csv <- file.path(output, "candidate-results.csv")
    pending <- tempfile(".csv-", tmpdir = output)
    write.csv(rows, pending, row.names = FALSE, na = "")
    qg.assert(file.rename(pending, csv), "Result ledger update failed")
  }
  qgs.verify.sources(sources)
  verdict <- tryCatch(c(list(status = "consistent"), qg.check.results(collection, rows)),
                      error = function(e) list(status = "failed", diagnostic = conditionMessage(e)))
  qgs.write(verdict, file.path(output, "gate.json"))
  if (verdict$status == "consistent") {
    qg.assert(file.copy(file.path(output, "candidate-results.csv"), file.path(output, "results.csv")),
              "Result export failed")
  }
  list(output = output, verdict = verdict, rows = rows)
}

source(file.path(qgs.home, "supervisor.R"), local = environment())
