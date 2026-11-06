# Rendering helpers only: no experiment source, sampling, distances or fitting.
fermat_surfaces_snapshot <- function(path) {
  if (!file.exists(path))
    stop('The bundled Fermat-surfaces snapshot is missing. Restore inst/extdata/fermat-surfaces/snapshot.rds; builds never regenerate results.', call.=FALSE)
  b <- readRDS(path)
  required <- c('schema_version','metrics','chords','checks','comparisons','overlay','provenance')
  if (!is.list(b) || !all(required %in% names(b)) ||
      !identical(b$schema_version,1L))
    stop('Unsupported or incomplete Fermat-surfaces snapshot.', call.=FALSE)
  m <- b$metrics
  stopifnot(nrow(m)==108L,all(m$seed==4101L),all(m$n==150L),
            !anyDuplicated(m[c('shape','p','k')]),
            setequal(m$shape,c('paraboloid','saddle','helix')),
            all(table(m$shape,m$p)==9L),
            setequal(m$k,c(0L,3:10)),
            sum(m$k==0L)==12L,all(m$reference_pairs[m$k==0L]==1000L),
            nrow(b$chords)==3L,nrow(b$checks)==3L,
            nrow(b$comparisons)==1000L,
            all(b$comparisons$seed==4101L),
            all(b$comparisons$shape=='paraboloid'),
            length(b$overlay$data)>0L)
  b
}

fermat_surfaces_saved_widget <- function(snapshot) {
  # as_widget supplies the current Plotly JS dependencies. Its usual pre-render
  # data-building hook is disabled: these traces and layout are already saved.
  widget <- plotly::as_widget(snapshot$overlay)
  widget$preRenderHook <- NULL
  widget$height <- 600
  widget
}

# Project the saved scene only; never resample points or refit the embedding.
fermat_surfaces_saved_plot <- function(snapshot) {
    traces <- snapshot$overlay$data
    numeric.values <- function(x) vapply(x, function(v)
        if (length(v)) as.numeric(v) else NA_real_, numeric(1))
    coordinates <- function(trace) cbind(numeric.values(trace$x),
        numeric.values(trace$y), numeric.values(trace$z))
    observed <- coordinates(traces[[3L]])
    embedded <- coordinates(traces[[4L]])
    paths <- coordinates(traces[[2L]])
    az <- -125 * pi / 180; el <- 25 * pi / 180
    rotation <- rbind(c(cos(az), -sin(az), 0),
        c(sin(az)*sin(el), cos(az)*sin(el), cos(el)))
    project <- function(x) x %*% t(rotation)
    surface <- traces[[1L]]
    z <- do.call(rbind, lapply(surface$z, numeric.values))
    grid <- as.matrix(expand.grid(x = unlist(surface$x), y = unlist(surface$y)))
    mesh <- cbind(grid, as.vector(t(z)))
    all <- rbind(observed, embedded, mesh[is.finite(mesh[, 3L]), ])
    origin <- apply(all, 2, min)
    span <- max(apply(all, 2, function(x) diff(range(x))))
    axes <- rbind(origin, sweep(diag(3) * span * .5, 2, origin, "+"))
    title <- strsplit(snapshot$overlay$layout$title$text, "<br>", fixed = TRUE)[[1L]]
    graphics::plot(project(rbind(all, axes)), type = "n", asp = 1,
        axes = FALSE, xlab = "", ylab = "", main = title[1L])
    for (j in seq_len(nrow(z))) {
        ids <- (j - 1L) * ncol(z) + seq_len(ncol(z))
        graphics::lines(project(mesh[ids, ]), col = "#BBBBBB70")
    }
    for (j in seq_len(ncol(z)))
        graphics::lines(project(mesh[seq(j, nrow(mesh), by = ncol(z)), ]), col = "#BBBBBB70")
    graphics::lines(project(paths), col = "#4169A080")
    graphics::points(project(observed), pch = 19, cex = .55, col = "#777777")
    values <- numeric.values(traces[[4L]]$marker$color)
    limits <- range(values)
    palette <- grDevices::hcl.colors(101L, "Viridis")
    index <- if (diff(limits) == 0) rep(51L, length(values)) else
        1L + floor(100 * (values - limits[1L]) / diff(limits))
    graphics::points(project(embedded), pch = 19, cex = .7, col = palette[index])
    xy <- project(axes)
    for (j in 1:3) {
        graphics::arrows(xy[1,1], xy[1,2], xy[j+1,1], xy[j+1,2], length = .06)
        graphics::text(xy[j+1,1], xy[j+1,2], c("x", "y", "z")[j], pos = 3)
    }
    graphics::legend("topleft", c("Observed samples", "Aligned MDS", traces[[2L]]$name),
        col = c("#777777", palette[60L], "#4169A0"), pch = c(19,19,NA),
        lty = c(NA,NA,1), bty = "n", cex = .75)
    if (length(title) > 1L) graphics::mtext(gsub("<[^>]+>", "", title[2L]),
        side = 3, line = .2, cex = .55)
    graphics::mtext("Orthographic view; equal coordinate units",
        side = 1, line = 0, cex = .65)
    invisible(list(observed = observed, embedded = embedded, paths = paths))
}
