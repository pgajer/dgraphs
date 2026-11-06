# Make display copies; retain the original research figures and their hashes.
dgraphs_document_figure <- function(path, width = 1000L) {
    if (length(path) != 1L) return(vapply(path, dgraphs_document_figure,
        character(1), width = width, USE.NAMES = FALSE))
    path <- normalizePath(path, mustWork = TRUE)
    if (!identical(Sys.getenv("DGRAPHS_STATIC_VIGNETTES", "true"), "true"))
        return(path)
    image <- png::readPNG(path)
    if (dim(image)[2L] <= width) return(path)
    height <- as.integer(round(dim(image)[1L] * width / dim(image)[2L]))
    output <- tempfile("dgraphs-figure-", fileext = ".jpg")
    # Cairo honors JPEG quality consistently, including on macOS.
    type <- if (capabilities("cairo")) "cairo" else getOption("bitmapType", "Xlib")
    grDevices::jpeg(output, width = width, height = height, quality = 85,
        bg = "white", type = type)
    on.exit(grDevices::dev.off())
    graphics::par(mar = rep(0, 4), xaxs = "i", yaxs = "i")
    graphics::plot.new()
    graphics::plot.window(xlim = c(0, 1), ylim = c(0, 1))
    graphics::rasterImage(image, 0, 0, 1, 1, interpolate = TRUE)
    output
}
