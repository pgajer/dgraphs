#' Versioned quadratic-surface sampling used by Geometry Lab
#' @param domain Square or disk parameter domain.
#' @param extent Positive domain radius or half-width, from 0.1 to 5.
#' @param mode Parameter-uniform, surface-area, grid, center, or gap sampling.
#' @param gap Empty strip half-width as a fraction of extent, from 0.01 to 0.8.
#' @param algorithm The fixed version-1 draw and arithmetic policy.
#' @return A sampling component for a canonical two-dimensional quadratic
#'   surface in three dimensions. Area sampling uses rejection sampling.
#' @examples
#' sampling <- synthetic.sampling.quadform.lab("disk", mode = "area")
#' surface <- synthetic.quadform(2, 3, list(diag(c(1, -1))))
#' sample.synthetic.geometry(surface, sampling, 30, seed = 4101)$n
#' @export
synthetic.sampling.quadform.lab <- function(domain = c("square", "disk"),
    extent = 1, mode = c("uniform", "area", "grid", "center", "gap"),
    gap = .2, algorithm = "geometry.lab.v1") {
  domain <- match.arg(domain); mode <- match.arg(mode)
  extent <- .synthetic.scalar.double(extent, "extent")
  gap <- .synthetic.scalar.double(gap, "gap")
  if (extent < .1 || extent > 5 || gap < .01 || gap > .8)
    stop("extent must be in [0.1,5] and gap in [0.01,0.8].", call. = FALSE)
  if (!identical(algorithm, "geometry.lab.v1")) stop("Unknown Geometry Lab algorithm.", call. = FALSE)
  .new.synthetic.sampling("quadform.lab", list(domain = domain, extent = extent,
    mode = mode, gap = gap, algorithm = algorithm))
}

#' Lift coordinates onto a quadratic surface using Geometry Lab arithmetic
#' @param latent Finite numeric matrix with two columns.
#' @param coefficients Three finite coefficients for u^2, 2uv and v^2.
#' @return A three-column matrix. Version-1 arithmetic preserves existing
#'   Geometry Lab cloud identities and reference meshes.
#' @examples
#' embed.quadform.surface(matrix(c(0, 1, 0, 1), ncol = 2), c(1, 0, -1))
#' @export
embed.quadform.surface <- function(latent, coefficients) {
  if (!is.matrix(latent) || !is.numeric(latent) || ncol(latent) != 2L ||
      any(!is.finite(latent))) stop("latent must be a finite two-column matrix.", call. = FALSE)
  if (!is.numeric(coefficients) || length(coefficients) != 3L || any(!is.finite(coefficients)))
    stop("Three finite coefficients are required.", call. = FALSE)
  uv <- latent; co <- coefficients
  cbind(uv, co[1]*uv[,1]^2 + 2*co[2]*uv[,1]*uv[,2] + co[3]*uv[,2]^2)
}

.draw.synthetic.quadform.lab <- function(p, n, geometry) {
  a <- geometry$parameters$forms[[1L]]
  co <- c(a[1,1], a[1,2], a[2,2]); e <- p$extent
  candidate <- function(m) {
    if (p$domain=='disk') {
      r <- sqrt(stats::runif(m))*e; theta <- stats::runif(m,0,2*pi)
      cbind(r*cos(theta),r*sin(theta))
    } else matrix(stats::runif(2*m,-e,e),ncol=2)
  }
  if (p$mode=='grid') {
    side <- ceiling(sqrt(n * if (p$domain=='disk') 4/pi else 1))
    repeat {
      uv <- as.matrix(expand.grid(seq(-e,e,length.out=side),seq(-e,e,length.out=side)))
      if (p$domain=='disk') uv <- uv[rowSums(uv^2)<=e^2,,drop=FALSE]
      if (nrow(uv)>=n) break
      side <- side+1L
    }
    # Systematic thinning spreads the requested exact count over the full grid.
    uv <- uv[unique(round(seq(1,nrow(uv),length.out=n))),,drop=FALSE]
  } else if (p$mode %in% c('area','gap','center')) {
    uv <- matrix(numeric(),0,2)
    bound <- sqrt(1 + (2*e*(abs(co[1])+abs(co[2])))^2 + (2*e*(abs(co[2])+abs(co[3])))^2)
    while(nrow(uv)<n) {
      x <- candidate(max(1000,n*3))
      keep <- if(p$mode=='gap') abs(x[,1])>p$gap*e else if(p$mode=='center')
        stats::runif(nrow(x)) < exp(-rowSums(x^2)/(2*(.32*e)^2)) else {
          du <- 2*co[1]*x[,1]+2*co[2]*x[,2]; dv <- 2*co[2]*x[,1]+2*co[3]*x[,2]
          stats::runif(nrow(x)) < sqrt(1+du^2+dv^2)/bound
        }
      uv <- rbind(uv,x[keep,,drop=FALSE])
    }
    uv <- uv[seq_len(n),,drop=FALSE]
  } else uv <- candidate(n)
  list(latent = uv, predictors = embed.quadform.surface(uv, co),
    latent.mask = NULL, region = NULL, parameters = list(algorithm = p$algorithm))
}
