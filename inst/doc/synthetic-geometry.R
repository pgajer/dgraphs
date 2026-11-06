## ----setup, include=FALSE-----------------------------------------------------
knitr::opts_chunk$set(collapse = TRUE, comment = "#>", fig.width = 6, fig.height = 4)

## ----circle-------------------------------------------------------------------
library(dgraphs)
circle <- synthetic.circle(radius = 1, ambient.dim = 2)
grid <- synthetic.sampling.grid.interval(
  0, 2 * pi, endpoints = "exclude.lower"
)
cloud <- sample.synthetic.geometry(circle, grid, n = 32, seed = 2026)
c(latent.columns = ncol(cloud$latent),
  ambient.columns = ncol(cloud$predictors))
stopifnot(isTRUE(all.equal(
  embed.synthetic.geometry(circle, cloud$latent), cloud$predictors
)))
graph <- create.sknn.graph(cloud$predictors, k = 2,
                           connect.components = TRUE)
edges <- convert.adjacency.to.edge.matrix(graph.adjacency(graph))$edge.matrix

## ----circle-plot, fig.cap="Circle sample with edges between nearby observations. Each coordinate row is a graph vertex.", fig.alt="Thirty-two points around a circle connected by short chord edges."----
X <- cloud$predictors
plot(X, asp = 1, pch = 19, col = "#245A81", xlab = "x", ylab = "y")
segments(X[edges[, 1], 1], X[edges[, 1], 2],
         X[edges[, 2], 1], X[edges[, 2], 2], col = "grey50")

## ----circle-distances---------------------------------------------------------
D <- graph.geodesic.distances(graph)
angle <- abs(cloud$latent[1, 1] - cloud$latent[9, 1])
c(chord = sqrt(sum((X[1, ] - X[9, ])^2)),
  graph.path = D[1, 9],
  circle.arc = min(angle, 2 * pi - angle))

## ----saddle-------------------------------------------------------------------
saddle <- synthetic.quadform(
  intrinsic.dim = 2, ambient.dim = 3, forms = list(diag(c(1, -1)))
)
sampling <- synthetic.sampling.uniform.disk(radius = 1)
validate.synthetic.sampling(sampling, saddle)
surface <- sample.synthetic.geometry(saddle, sampling, n = 48, seed = 17)
head(cbind(surface$latent, height = surface$predictors[, 3]), 3)
surface.graph <- create.sknn.graph(surface$predictors, k = 5,
                                   connect.components = TRUE)
length(unique(graph.connected.components(surface.graph)))

## ----segment-length-----------------------------------------------------------
a <- matrix(c(-0.8, 0), nrow = 1)
b <- matrix(c(0.8, 0), nrow = 1)
A <- embed.synthetic.geometry(saddle, a)
B <- embed.synthetic.geometry(saddle, b)
c(ambient.chord = sqrt(sum((B - A)^2)),
  lifted.segment = edge.lengths.synthetic.geometry(saddle, a, b))
quadform.metric(saddle, a)

## ----frame-and-single-point---------------------------------------------------
rotated <- synthetic.quadform(
  intrinsic.dim = 2, ambient.dim = 5,
  forms = list(diag(c(1, -1)), diag(c(0.5, 0.25))),
  frame = "random.orthonormal"
)
one <- sample.synthetic.geometry(
  rotated, synthetic.sampling.uniform.box(-1, 1), n = 1, seed = 91
)
dim(one$latent)
dim(one$predictors)
stopifnot(identical(dim(one$latent), c(1L, 2L)),
          identical(dim(one$predictors), c(1L, 5L)),
          isTRUE(all.equal(one$predictors,
            embed.synthetic.geometry(rotated, one$latent, one$frame.matrix))))

## ----quad-gallery-tools, include=FALSE----------------------------------------
have.ivue <- !identical(Sys.getenv("DGRAPHS_STATIC_VIGNETTES", "true"), "true") &&
  requireNamespace("ivue", quietly = TRUE) &&
  requireNamespace("rgl", quietly = TRUE) &&
  requireNamespace("htmlwidgets", quietly = TRUE) &&
  requireNamespace("htmltools", quietly = TRUE)

# These are vignette display helpers, not exported dgraphs functions.
source(system.file("doc-tools", "perspective.R", package = "dgraphs"), local = TRUE)
quad.view <- function(X, description, triangles = NULL, edges = NULL, values = X[, 3], color.title = "Displayed z",
    labels = c("x", "y", "z")) {
    stopifnot(is.matrix(X), ncol(X) == 3L, all(is.finite(X)), length(values) == nrow(X), all(is.finite(values)))
    list(X = X, description = description, triangles = triangles, edges = edges, values = values,
        color.title = color.title, labels = labels)
}
quad.gallery <- function(views, id) {
    if (!have.ivue) {
        old <- par(mfrow = c(ceiling(length(views)/3), 3), mar = c(3, 1, 3, 1))
        on.exit(par(old), add = TRUE)
        bounds <- do.call(rbind, lapply(views, function(v) v$X))
        for (j in seq_along(views)) {
            v <- views[[j]]
            dgraphs_perspective(v$X, names(views)[j], v$labels, v$values,
                                v$triangles, v$edges, limits = bounds)
            mtext(paste0(v$color.title, ": ", paste(signif(range(v$values), 2), collapse = " to ")),
                  side = 1, line = 1, cex = 0.55)
        }
        return(invisible(NULL))
    }
    widgets <- lapply(views, function(v) {
        layers <- list(ivue::layer3D.axes(labels = v$labels, col = c("#B33F40", "#287854",
            "#3259A8"), width = 1.5, cex = 1))
        if (!is.null(v$triangles))
            layers <- c(list(ivue::layer3D.mesh(v$triangles, col = "#B7CBD6", alpha = 0.3,
                edge.alpha = 0.18)), layers)
        if (!is.null(v$edges))
            layers <- c(layers, list(ivue::layer3D.edges(v$edges, col = "#273D4A", width = 2)))
        limits <- range(v$values)
        if (diff(limits) == 0)
            limits <- limits + c(-0.5, 0.5)
        scale <- ivue::color.scale.cont(v$values, limits = limits, palette = c("#244B94", "#F1DF9D",
            "#B64036"))
        ivue::plot3D.plain(v$X, col = ivue::map.colors(v$values, scale)$colors, point.size = 4,
            axes = FALSE, aspect = "equal", layers = layers, camera = ivue::camera.zup(elevation = 25,
                turn = -125, zoom = 0.53), height = 450, background.color = "#FAFCFD", controls = FALSE)
    })
    widget <- widgets[[1]]
    widget$elementId <- paste0(id, "-view")
    captions <- vapply(views, function(v) {
        color.range <- if (diff(range(v$values)) == 0)
            paste0("constant ", signif(v$values[1], 3), " (cream)")
        else paste0("blue ", signif(min(v$values), 3), " to red ", signif(max(v$values), 3))
        paste0(v$description, " Color: ", v$color.title, "; ", color.range, ".")
    }, character(1))
    widget <- htmlwidgets::onRender(widget, "\n    function(el, x, data) {\n      var box = document.getElementById(data.id);\n      var choice = box.querySelector(\"select\");\n      var caption = box.querySelector(\".quad-caption\");\n      function show() {\n        var j = Number(choice.value);\n        var scene = JSON.parse(JSON.stringify(data.scenes[j]));\n        HTMLWidgets.find(\"#\" + el.id).renderValue(scene);\n        caption.textContent = data.captions[j];\n        el.setAttribute(\"aria-label\", data.titles[j] + \". \" + data.captions[j]);\n      }\n      choice.addEventListener(\"change\", show);\n      box.querySelector(\"button\").addEventListener(\"click\", show);\n      el.setAttribute(\"aria-label\", data.titles[0] + \". \" + data.captions[0]);\n    }",
        data = list(id = id, scenes = unname(lapply(widgets, function(w) w$x)), captions = unname(captions),
            titles = names(views)))
    htmltools::tags$div(id = id, class = "quad-gallery", htmltools::tags$div(class = "quad-controls",
        htmltools::tags$label(`for` = paste0(id, "-choice"), "Example: "), htmltools::tags$select(id = paste0(id,
            "-choice"), lapply(seq_along(views), function(j) htmltools::tags$option(value = j -
            1L, names(views)[j]))), htmltools::tags$button(type = "button", "Reset view")),
        htmltools::tags$p(class = "quad-caption", `aria-live` = "polite", captions[1]), widget)
}

## ----quad-render-mode, echo=FALSE, results='asis', fig.alt="Quadratic geometry in perspective with labeled axes; examples and color meanings are described in the surrounding text."----
if (!have.ivue) cat("The panels below show orthographic perspective views with labeled x/y/z axes and equal coordinate-unit scales. To rebuild interactive 3D views, install ivue, rgl, htmlwidgets and htmltools and set DGRAPHS_STATIC_VIGNETTES=false.\n\n")

## ----quad-single-ivue, eval=FALSE---------------------------------------------
# ivue::plot3D.cont(
#   surface$predictors, values = surface$predictors[, 3],
#   legend.title = "Height", aspect = "equal",
#   layers = list(ivue::layer3D.axes(labels = c("x", "y", "z"))),
#   camera = ivue::camera.zup(elevation = 25, turn = -125, zoom = 0.53), controls = FALSE
# )

## ----quad-shapes, fig.alt="Seven quadratic surfaces in perspective: saddle, flat plane, bowl, dome, cylinder, unequal curvature and mixed term. Axes retain equal data units."----
u <- seq(-1, 1, length.out = 15)
uv <- as.matrix(expand.grid(u = u, v = u))
cells <- expand.grid(i = seq_len(length(u) - 1L),
                     j = seq_len(length(u) - 1L))
a <- cells$i + (cells$j - 1L) * length(u)
faces <- rbind(cbind(a, a + 1L, a + length(u)),
               cbind(a + 1L, a + length(u) + 1L, a + length(u)))
forms <- list(
  Bowl = diag(c(1, 1)), Dome = diag(c(-1, -1)),
  Cylinder = diag(c(1, 0)), Saddle = diag(c(1, -1)),
  `Unequal curvature` = diag(c(0.25, 1.5)),
  `Mixed term` = matrix(c(0.4, 0.8, 0.8, -0.2), 2)
)
shape.views <- list()
flat <- synthetic.quadform(2, 2)
flat.X <- embed.synthetic.geometry(flat, uv)
shape.views$Flat <- quad.view(cbind(flat.X, 0),
  "No forms: two ambient coordinates, padded with z = 0 only for display.", faces)
for (name in names(forms)) {
    geometry <- synthetic.quadform(2, 3, forms = list(forms[[name]]))
    X <- embed.synthetic.geometry(geometry, uv)
    shape.views[[name]] <- quad.view(X, paste(name, "with x = u, y = v, z = the quadratic height."),
        faces)
}
shape.views <- shape.views[c("Saddle", setdiff(names(shape.views), "Saddle"))]
# The specialized arithmetic agrees numerically with the general embedding.
co <- c(0.4, 0.8, -0.2)
stopifnot(isTRUE(all.equal(shape.views[["Mixed term"]]$X,
                          embed.quadform.surface(uv, co), check.attributes = FALSE)))

## ----quad-shapes-view, echo=FALSE, fig.height=7, fig.alt="Quadratic geometry in perspective with labeled axes; examples and color meanings are described in the surrounding text."----
quad.gallery(shape.views, "quad-shapes")

## ----quad-sampling-gallery, fig.alt="Perspective comparisons of quadratic-surface sampling modes and their point distributions."----
modes <- c("uniform", "area", "grid", "center", "gap")
sampling.views <- list()
for (domain in c("square", "disk")) for (mode in modes) {
    spec <- synthetic.sampling.quadform.lab(domain = domain, extent = 1, mode = mode, gap = 0.3)
    draw <- sample.synthetic.geometry(saddle, spec, n = 180, seed = 4101)
    stopifnot(nrow(draw$predictors) == 180L)
    if (mode == "gap")
        stopifnot(all(abs(draw$latent[, 1]) > 0.3))
    sampling.views[[paste(domain, mode, sep = " / ")]] <- quad.view(draw$predictors, paste("180 saddle points:",
        domain, "domain,", mode, "sampling."))
}
# General samplers support other domains, ordering and clustered designs.
general.samplers <- list(
  `Coordinate-wise box` = synthetic.sampling.uniform.box(
    lower = c(-1, -0.5), upper = c(1, 0.5), order = "ascending.first.coordinate"),
  Rectangle = synthetic.sampling.uniform.rectangle(c(-1, -0.5), c(1, 0.5)),
  `Uniform disk` = synthetic.sampling.uniform.disk(0.8),
  `Clustered points` = synthetic.sampling.clustered(6, 30, within.sd = 0.08)
)
for (name in names(general.samplers)) {
    draw <- sample.synthetic.geometry(saddle, general.samplers[[name]], n = 180, seed = 19)
    sampling.views[[name]] <- quad.view(draw$predictors, paste(name, "on the same quadratic saddle; no triangulation across gaps."))
}

## ----quad-sampling-view, echo=FALSE, fig.height=12, fig.alt="Quadratic geometry in perspective with labeled axes; examples and color meanings are described in the surrounding text."----
quad.gallery(sampling.views, "quad-sampling")

## ----quad-frames, fig.alt="The same saddle translated and rotated; coordinate-unit scales are equal."----
angle <- pi / 4
rotation <- matrix(c(1, 0, 0, 0, cos(angle), sin(angle),
                      0, -sin(angle), cos(angle)), 3)
placed <- synthetic.quadform(2, 3, list(diag(c(1, -1))),
  frame = "supplied", frame.matrix = rotation, offset = c(0.6, -0.3, 0.4))
placed.X <- embed.synthetic.geometry(placed, uv)
stopifnot(isTRUE(all.equal(as.matrix(dist(placed.X)),
                          as.matrix(dist(shape.views$Saddle$X)), tolerance = 1e-12)))
frame.views <- list(
  Canonical = shape.views$Saddle,
  `Supplied frame and translation` = quad.view(placed.X,
    "The same saddle rotated 45 degrees about x, then translated by (0.6, -0.3, 0.4). Axes remain ambient x/y/z.", faces)
)
for (algorithm in c("base.qr.gaussian.v1", "legacy.base.qr.gaussian.v1")) {
    geometry <- synthetic.quadform(2, 3, list(diag(c(1, -1))), frame = "random.orthonormal",
        frame.algorithm = algorithm)
    realization <- sample.synthetic.geometry(geometry, synthetic.sampling.uniform.box(-1, 1),
        n = 1, seed = 91)
    X <- embed.synthetic.geometry(geometry, uv, realization$frame.matrix)
    frame.views[[algorithm]] <- quad.view(X, paste("Random orthonormal orientation from seed 91 using",
        algorithm, "; frame.matrix is reused for every grid point."), faces)
}

## ----quad-frames-view, echo=FALSE, fig.height=6, fig.alt="Quadratic geometry in perspective with labeled axes; examples and color meanings are described in the surrounding text."----
quad.gallery(frame.views, "quad-frames")

## ----quad-dimensions, fig.alt="Projected examples across intrinsic dimensions and ambient dimensions, with displayed axes labeled."----
# One latent coordinate and two heights: all three ambient coordinates visible.
curve <- synthetic.quadform(1, 3, list(matrix(1), matrix(-0.4)))
curve.data <- sample.synthetic.geometry(curve,
  synthetic.sampling.grid.interval(-1, 1, endpoints = "include.both"),
  n = 61, seed = 2)
curve.edges <- cbind(1:60, 2:61)
dimension.views <- list(`Quadratic curve` = quad.view(curve.data$predictors,
  "One latent coordinate t, displayed as (t, t^2, -0.4 t^2). Both height coordinates are functions of t^2, so this curve lies in a plane.", edges = curve.edges))

# Two latent coordinates and two independent quadratic heights in four dimensions.
multi <- synthetic.quadform(2, 4,
  list(diag(c(1, -1)), matrix(c(0, 0.5, 0.5, 0), 2)))
X4 <- embed.synthetic.geometry(multi, uv)
stopifnot(identical(dim(quadform.gradient(multi, uv)), c(225L, 2L, 2L)))
dimension.views[["First of two heights"]] <- quad.view(X4[, c(1, 2, 3)],
  "Projection (u, v, h1) from four ambient coordinates; h2 = u*v is omitted.", faces,
  labels = c("x = u", "y = v", "z = h1"))
dimension.views[["Second of two heights"]] <- quad.view(X4[, c(1, 2, 4)],
  "Projection (u, v, h2) of the same rows; h1 = u^2-v^2 is omitted.", faces,
  labels = c("x = u", "y = v", "z = h2"))

# More ambient coordinates: an isometric supplied frame in five dimensions.
frame5 <- qr.Q(qr(rbind(diag(4), c(1, 1, 0, 0))))
wide <- synthetic.quadform(2, 5, multi$parameters$forms,
  frame = "supplied", frame.matrix = frame5, offset = c(0, 0, 0, 0, 0.5))
X5 <- embed.synthetic.geometry(wide, uv)
stopifnot(isTRUE(all.equal(as.matrix(dist(X4)), as.matrix(dist(X5)), tolerance = 1e-12)))
dimension.views[["Five-dimensional embedding"]] <- quad.view(X5[, c(1, 3, 5)],
  "Projection of ambient coordinates 1, 3 and 5. The full five-dimensional embedding preserves distances; this projection generally does not.", faces,
  labels = c("x = X1", "y = X3", "z = X5"))

# Three latent coordinates, one height: display two slices of a 4D geometry.
volume <- synthetic.quadform(3, 4,
  list(matrix(c(1, 0, 0.5, 0, -1, 0, 0.5, 0, 0.5), 3)))
volume.data <- sample.synthetic.geometry(volume,
  synthetic.sampling.uniform.box(-1, 1), n = 40, seed = 8)
stopifnot(identical(dim(volume.data$predictors), c(40L, 4L)))
for (w in c(-0.5, 0.5)) {
    slice <- embed.synthetic.geometry(volume, cbind(uv, w))
    dimension.views[[paste("Latent slice w =", w)]] <- quad.view(slice[, c(1, 2, 4)], paste("A two-dimensional slice at latent w =",
        w, "of a three-dimensional latent geometry; shown as (u, v, height)."), faces, labels = c("x = u",
        "y = v", "z = height"))
}
# The earlier one-point, two-height, random-frame sample is still a matrix.
dimension.views[["One point, five ambient coordinates"]] <- quad.view(
  one$predictors[, 1:3, drop = FALSE],
  "One row from a two-height geometry in five dimensions, projected to coordinates 1:3. A point alone does not identify the surrounding surface.")

## ----quad-dimensions-view, echo=FALSE, fig.height=9, fig.alt="Quadratic geometry in perspective with labeled axes; examples and color meanings are described in the surrounding text."----
quad.gallery(dimension.views, "quad-dimensions")

## ----quad-local-geometry, fig.alt="Quadratic geometry in perspective with labeled axes; examples and color meanings are described in the surrounding text."----
gradient <- quadform.gradient(saddle, uv)
metric <- quadform.metric(saddle, uv)
slope <- sqrt(rowSums(gradient^2))
area.factor <- vapply(seq_len(nrow(uv)), function(i) sqrt(det(metric[i, , ])), numeric(1))
stopifnot(max(abs(area.factor - sqrt(1 + slope^2))) < 1e-12,
          identical(dim(quadform.gradient(flat, uv)), c(225L, 0L, 2L)),
          isTRUE(all.equal(quadform.metric(flat, matrix(c(0, 0), 1)), diag(2))))
differential.views <- list(
  `Gradient magnitude` = quad.view(shape.views$Saddle$X,
    "Slope increases away from the stationary point at the origin.", faces,
    values = slope, color.title = "Gradient magnitude"),
  `Surface-area factor` = quad.view(shape.views$Saddle$X,
    "This area factor is the density adjustment used by area sampling on the canonical saddle.", faces,
    values = area.factor, color.title = "Area per unit latent area")
)

## ----quad-local-view, echo=FALSE, fig.height=4, fig.alt="Quadratic geometry in perspective with labeled axes; examples and color meanings are described in the surrounding text."----
quad.gallery(differential.views, "quad-differential")

## ----quad-path-views, fig.alt="Quadratic geometry in perspective with labeled axes; examples and color meanings are described in the surrounding text."----
graph.edges <- convert.adjacency.to.edge.matrix(graph.adjacency(surface.graph))$edge.matrix
line.uv <- cbind(seq(-0.8, 0.8, length.out = 61), 0)
line.X <- embed.synthetic.geometry(saddle, line.uv)
line.edges <- rbind(cbind(1:60, 2:61), c(1, 61))
path.views <- list(
  `Graph on sampled points` = quad.view(surface$predictors,
    "Symmetric kNN graph with k = 5 and explicit connectivity repair; edges carry ambient Euclidean chord lengths.", edges = graph.edges),
  `Chord and lifted segment` = quad.view(line.X,
    "The straight chord joins the endpoints; the curved polyline follows the lifted latent segment. Neither is asserted to be the shortest continuous surface path.", edges = line.edges)
)
segment.length <- edge.lengths.synthetic.geometry(saddle,
  line.uv[1, , drop = FALSE], line.uv[61, , drop = FALSE], tolerance = 1e-10)
c(chord = sqrt(sum((line.X[61, ] - line.X[1, ])^2)), lifted.segment = segment.length)

## ----quad-paths-view, echo=FALSE, fig.height=4, fig.alt="Quadratic geometry in perspective with labeled axes; examples and color meanings are described in the surrounding text."----
quad.gallery(path.views, "quad-paths")

## ----simplex------------------------------------------------------------------
composition <- sample.synthetic.geometry(
  synthetic.simplex(parts = 3),
  synthetic.sampling.dirichlet.zeros(
    concentration = rep(1, 3), zero.fraction = 0.25, zero.parts = 1L
  ), n = 40, seed = 31
)
table(composition$region)
composition$intrinsic.dim.by.region
range(rowSums(composition$predictors))
stopifnot(is.null(composition$latent),
          all(abs(rowSums(composition$predictors) - 1) < 1e-12))
composition.graph <- create.sknn.graph(composition$predictors, k = 4,
                                       connect.components = TRUE)

## ----reproducibility----------------------------------------------------------
set.seed(800)
caller.state <- .Random.seed
caller.kinds <- RNGkind()
uniform <- synthetic.sampling.uniform.interval(0, 2 * pi, order = "draw")
first <- sample.synthetic.geometry(circle, uniform, n = 5, seed = 42)
again <- sample.synthetic.geometry(circle, uniform, n = 5, seed = 42)
stopifnot(identical(first$predictors, again$predictors),
          identical(.Random.seed, caller.state),
          identical(RNGkind(), caller.kinds))

## ----continuation-------------------------------------------------------------
next.plan <- first$rng$plan
next.plan$sampling <- first$rng$sampling.after
second <- sample.synthetic.geometry(circle, uniform, n = 5, rng.plan = next.plan)
whole <- sample.synthetic.geometry(circle, uniform, n = 10, seed = 42)
stopifnot(identical(rbind(first$latent, second$latent), whole$latent),
          identical(.Random.seed, caller.state))

## ----current-stream-----------------------------------------------------------
set.seed(42)
current <- sample.synthetic.geometry(circle, uniform, n = 5,
                                      rng.plan = "current")
set.seed(42)
stopifnot(identical(current$latent[, 1], runif(5, 0, 2 * pi)))

