# Graph explorer component, migrated from dggraphui.
# Copyright Pawel Gajer. License: GPL (>= 3).
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) < 1L) y else x
}

dg_now <- function() {
  format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
}

dg_scalar_chr <- function(x, default = "") {
  if (is.null(x) || length(x) < 1L || is.na(x[[1]])) {
    return(default)
  }
  as.character(x[[1]])
}

dg_first_col <- function(df, candidates) {
  if (!is.data.frame(df) || length(candidates) < 1L) {
    return("")
  }
  nm <- names(df)
  low <- tolower(gsub("[._]+", "_", nm))
  for (cand in candidates) {
    idx <- match(tolower(gsub("[._]+", "_", cand)), low)
    if (!is.na(idx)) {
      return(nm[[idx]])
    }
  }
  ""
}

dg_read_csv <- function(path) {
  pp <- dg_scalar_chr(path)
  if (!nzchar(pp) || !file.exists(pp)) {
    return(data.frame())
  }
  out <- tryCatch(
    utils::read.csv(pp, stringsAsFactors = FALSE, check.names = FALSE),
    error = function(e) data.frame()
  )
  if (!is.data.frame(out)) {
    return(data.frame())
  }
  rownames(out) <- NULL
  out
}

dg_normalize_path <- function(path, root = "", must_work = FALSE) {
  pp <- dg_scalar_chr(path)
  if (!nzchar(pp)) {
    return("")
  }
  if (!grepl("^(/|~|[A-Za-z]:[/\\\\])", pp, perl = TRUE) && nzchar(root)) {
    pp <- file.path(root, pp)
  }
  normalizePath(path.expand(pp), mustWork = must_work)
}

dg_safe_token <- function(x, fallback = "asset") {
  out <- tolower(gsub("[^a-zA-Z0-9]+", "_", dg_scalar_chr(x)))
  out <- gsub("^_+|_+$", "", out)
  if (!nzchar(out)) {
    out <- fallback
  }
  out
}

dg_order_values <- function(values, field) {
  vals <- unique(as.character(values %||% character(0)))
  vals <- vals[!is.na(vals) & nzchar(vals) & vals != "NA"]
  if (length(vals) < 1L) {
    return(character(0))
  }
  num_fields <- c("n", "seed", "k", "radius_rank", "k_scale", "radius_factor", "delta")
  if (field %in% num_fields) {
    num <- suppressWarnings(as.numeric(vals))
    if (all(is.finite(num))) {
      vals <- vals[order(num)]
    } else {
      vals <- sort(vals)
    }
  } else if (identical(field, "stage")) {
    pref <- c("raw", "raw.repaired", "pruned", "pruned.repaired", "repaired.pruned", "final")
    vals <- c(pref[pref %in% vals], sort(setdiff(vals, pref)))
  } else if (identical(field, "graph_family")) {
    pref <- c("adaptive_radius", "cknn", "fixed_radius", "iknn", "mknn", "sknn")
    vals <- c(pref[pref %in% vals], sort(setdiff(vals, pref)))
  } else {
    vals <- sort(vals)
  }
  unique(vals)
}

dg_format_number <- function(x, digits = 4L) {
  xx <- suppressWarnings(as.numeric(x))
  if (!is.finite(xx)) {
    return("")
  }
  trimws(formatC(xx, digits = digits, format = "fg"))
}

dg_coord_matrix <- function(coords) {
  if (is.data.frame(coords)) {
    coords <- as.matrix(coords)
  } else {
    coords <- suppressWarnings(as.matrix(coords))
  }
  if (!is.matrix(coords) || nrow(coords) < 1L || ncol(coords) < 3L) {
    return(NULL)
  }
  num <- suppressWarnings(matrix(as.numeric(coords), nrow = nrow(coords), ncol = ncol(coords)))
  if (!is.matrix(num) || ncol(num) < 3L || !all(is.finite(num))) {
    return(NULL)
  }
  num <- num[, seq_len(3L), drop = FALSE]
  num
}

# Display transformations never modify saved coordinates or metric tables.
dg_normalize_coord_matrix <- function(coords, mode = c("original", "isotropic", "per.axis")) {
  mode <- match.arg(mode)
  coords <- dg_coord_matrix(coords)
  if (is.null(coords)) return(NULL)
  colnames(coords) <- c("x", "y", "z")
  if (mode == "original") return(coords)
  bounds <- apply(coords, 2, range)
  coords <- sweep(coords, 2, colMeans(bounds), "-")
  spans <- bounds[2, ] - bounds[1, ]
  if (mode == "isotropic") spans[] <- max(spans)
  spans[spans == 0] <- 1
  sweep(coords, 2, spans, "/")
}

dg_display_edges <- function(adj_list, limit = 4000L) {
  edges <- dg_adj_edges(adj_list)
  if (nrow(edges) > limit)
    edges <- edges[unique(round(seq(1, nrow(edges), length.out = limit))), , drop = FALSE]
  edges
}

dg_display_description <- function(mode) switch(mode,
  original = "Original coordinates; equal x/y/z units in each view.",
  isotropic = "Centered coordinates; one scale factor per view preserves proportions.",
  per.axis = "Per-axis normalization distorts proportions; axes show normalized units.")

dg_adj_edges <- function(adj_list) {
  if (!is.list(adj_list) || length(adj_list) < 1L) {
    return(matrix(integer(0), ncol = 2L))
  }
  edges <- vector("list", length(adj_list))
  for (ii in seq_along(adj_list)) {
    nb <- suppressWarnings(as.integer(adj_list[[ii]] %||% integer(0)))
    nb <- nb[is.finite(nb) & nb > ii]
    edges[[ii]] <- if (length(nb) > 0L) cbind(ii, nb) else NULL
  }
  out <- do.call(rbind, edges)
  if (is.null(out)) {
    return(matrix(integer(0), ncol = 2L))
  }
  matrix(as.integer(out), ncol = 2L)
}
