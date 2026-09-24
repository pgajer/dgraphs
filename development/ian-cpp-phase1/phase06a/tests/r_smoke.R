# Standalone .Call feasibility; base R only, no package or shared-library install.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3L)
bridge <- normalizePath(args[[1L]])
input_dir <- normalizePath(args[[2L]])
output_dir <- args[[3L]]
stopifnot(!dir.exists(output_dir), dir.create(output_dir, recursive = TRUE))
dll <- dyn.load(bridge)
symbol <- getNativeSymbolInfo("ian_run", dll)
vec <- function(name) {
    path <- file.path(input_dir, paste0(name, ".bin"))
    readBin(path, "double", n = file.info(path)$size / 8, size = 8L, endian = "little")
}
mat <- function(name) {
    shape <- scan(file.path(input_dir, paste0(name, ".shape")), quiet = TRUE)
    matrix(vec(name), nrow = shape[[1L]], ncol = shape[[2L]], byrow = TRUE)
}
features <- mat("features"); storage.mode(features) <- "double"
distances <- mat("distances"); storage.mode(distances) <- "double"
ids <- readLines(file.path(input_dir, "ids.txt"))
participants <- paste0("participant-", (seq_along(ids)-1L) %/% 2L)
before <- list(features, distances, ids, participants)
result <- .Call(symbol, features, distances, ids, participants)
stopifnot(result$complete, result$graph_valid, result$scales_valid, result$affinity_valid)
stopifnot(identical(before, list(features, distances, ids, participants)))
stopifnot(result$schema_version == 1L, result$numerical_policy == "IAN evaluated-LP 1.0")
stopifnot(result$error_kind == "none", result$error_code == "")
# Exact equality is tested on this pinned clean build, in addition to CLI tolerances.
stopifnot(all(result$edges == mat("edges") + 1L))
for (name in c("edge_lengths", "degrees", "scales", "internal_scales"))
    stopifnot(identical(as.numeric(result[[name]]), vec(name)))
for (name in c("components", "isolates", "representatives", "member_to_profile"))
    stopifnot(identical(as.numeric(result[[name]]), vec(name) + 1))
stopifnot(identical(result$affinity, mat("affinity")))
stopifnot(identical(result$specimen_ids, ids), identical(result$profile_ids, ids))
stopifnot(identical(result$participant_ids, participants))
stopifnot(result$distance_multiplier == vec("distance_multiplier"), result$multiplier == vec("multiplier"))
saved <- result
features[,] <- 0; distances[,] <- 0
stopifnot(identical(saved, result))
stopifnot(inherits(try(.Call(symbol, 1, before[[2L]], ids, participants), silent=TRUE), "try-error"))
bad <- before[[2L]]; bad[1,2] <- NaN
refused <- .Call(symbol, before[[1L]], bad, ids, participants)
stopifnot(!refused$complete, refused$error_kind == "input", refused$solves == 0L)
refused <- .Call(symbol, before[[1L]], before[[2L]], ids, participants[-1L])
stopifnot(!refused$complete, refused$error_code == "participant_shape_or_identity", refused$solves == 0L)
saveRDS(result, file.path(output_dir, "result.rds"))
capture.output(sessionInfo(), file=file.path(output_dir, "session-info.txt"))
capture.output(getLoadedDLLs(), file=file.path(output_dir, "loaded-libraries.txt"))
writeLines(c("passed", paste("solves", result$solves), "indices one-based; degrees unchanged",
    "input and result values independently owned; explicit copies in both directions"), file.path(output_dir, "checks.txt"))
dyn.unload(bridge)
cat("Minimal R call and returned-data comparisons passed.\n")
