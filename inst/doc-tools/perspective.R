# Deterministic base-graphics perspective for offline documentation and README.
# Orthographic rotation preserves equal data-unit scales on x, y and z.
dgraphs_perspective <- function(X, title = "", labels = c("x", "y", "z"),
                                values = X[,3], triangles = NULL, edges = NULL,
                                limits = NULL, caption = TRUE) {
    az <- -125*pi/180; el <- 25*pi/180
    rotation <- rbind(c(cos(az), -sin(az), 0),
                      c(sin(az)*sin(el), cos(az)*sin(el), cos(el)))
    project <- function(x) x %*% t(rotation)
    all <- if (is.null(limits)) X else limits
    span <- max(apply(all, 2, function(x) diff(range(x))))
    if (!is.finite(span) || span == 0) span <- 1
    origin <- apply(all, 2, min)
    axes <- rbind(origin, sweep(diag(3)*span*.6, 2, origin, "+"))
    bounds <- project(rbind(all, axes)); xy <- project(X)
    plot(bounds, type="n", asp=1, axes=FALSE, xlab="", ylab="", main=title)
    if (!is.null(triangles)) for (i in seq_len(nrow(triangles)))
        polygon(xy[triangles[i,],,drop=FALSE], col=grDevices::adjustcolor("#b7cbd6",.35), border="#c9d6dc")
    if (!is.null(edges) && length(edges)) {
        edges <- as.matrix(edges[,1:2,drop=FALSE])
        segments(xy[edges[,1],1],xy[edges[,1],2],xy[edges[,2],1],xy[edges[,2],2],col="#64748b80")
    }
    palette <- grDevices::colorRampPalette(c("#244b94","#f1df9d","#b64036"))(101)
    r <- range(values); scaled <- if(diff(r)==0) rep(51L,length(values)) else 1L+floor(100*(values-r[1])/diff(r))
    points(xy,pch=19,cex=.6,col=palette[scaled])
    ax <- project(axes)
    for (j in 1:3) {
        arrows(ax[1,1],ax[1,2],ax[j+1,1],ax[j+1,2],length=.06,col=c("#b33f40","#287854","#3259a8")[j])
        text(ax[j+1,1],ax[j+1,2],labels[j],pos=3,cex=.8)
    }
    if (caption) mtext("Perspective · equal coordinate units",side=1,line=0,cex=.65)
    invisible(xy)
}
