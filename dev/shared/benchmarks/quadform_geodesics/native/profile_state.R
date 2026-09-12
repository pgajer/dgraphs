args <- commandArgs(TRUE)
stopifnot(length(args) >= 3)
home <- normalizePath(args[1]); output <- args[2]; inputs <- normalizePath(args[-c(1, 2)])
project <- normalizePath(file.path(home, "../../../.."))
stopifnot(!file.exists(output), dir.exists(dirname(output)))
output <- file.path(normalizePath(dirname(output)), basename(output))
stopifnot(output != project, !startsWith(output, paste0(project, "/")))
dir.create(output)
source(file.path(home, "../../fixtures/quadform_geodesics/collection.R"))
source(file.path(home, "interface.R"))
clock <- qgs.clock; invisible(clock())
rows <- list()
for (path in inputs) {
  state <- readRDS(path); raw <- serialize(state, NULL, version = 3)
  stopifnot(identical(unserialize(raw), state))
  label <- paste(basename(dirname(path)), basename(path), sep = "/")
  for (repeat_id in 1:5) for (mode in c("serialize_to_memory", "serialize_and_write", "write_prepared_bytes")) {
    target <- file.path(output, "scratch.rds")
    gc(); t <- clock()
    if (mode == "serialize_to_memory") result <- serialize(state, NULL, version = 3)
    if (mode == "serialize_and_write") qgs.binary(state, target)
    if (mode == "write_prepared_bytes") {
      temporary <- tempfile(".pending-", tmpdir = output)
      writeBin(raw, temporary); stopifnot(file.rename(temporary, target))
    }
    elapsed <- clock() - t
    if (mode != "serialize_to_memory") stopifnot(identical(readRDS(target), state))
    rows[[length(rows) + 1L]] <- data.frame(input = label, repeat_id, mode,
      seconds = elapsed, serialized_bytes = length(raw), cache_entries = length(state$cache))
  }
}
write.csv(do.call(rbind, rows), file.path(output, "state-costs.csv"), row.names = FALSE)
qgs.write(list(status = "complete", sources = lapply(c(inputs, file.path(home, "native/profile_state.R")),
  function(path) list(path = path, sha256 = digest::digest(file = path, algo = "sha256"))),
  caveat = "Warm local files; OS-buffered writes, not physical-disk throughput or fsync timing"),
  file.path(output, "completion.json"))
unlink(file.path(output, "scratch.rds"))
