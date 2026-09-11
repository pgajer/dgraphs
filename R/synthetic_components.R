# Synthetic data component and specification infrastructure.

.synthetic.scalar.character <- function(x, name, null.ok = FALSE) {
  if (null.ok && is.null(x)) return(NULL)
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    stop(name, " must be one nonempty character value.", call. = FALSE)
  }
  x
}

.synthetic.scalar.integer <- function(x, name, lower = NULL) {
  if (length(x) != 1L || is.na(x) || !is.numeric(x) || !is.finite(x) ||
      x != trunc(x)) {
    stop(name, " must be one finite whole number.", call. = FALSE)
  }
  if (x < -.Machine$integer.max || x > .Machine$integer.max) {
    stop(name, " is outside R's representable integer seed range.",
         call. = FALSE)
  }
  value <- as.integer(x)
  if (!is.null(lower) && value < lower) {
    stop(name, " must be at least ", lower, ".", call. = FALSE)
  }
  value
}

.synthetic.scalar.double <- function(x, name, lower = NULL,
                                     strict = FALSE) {
  if (length(x) != 1L || is.na(x) || !is.numeric(x) || !is.finite(x)) {
    stop(name, " must be one finite numeric value.", call. = FALSE)
  }
  value <- as.double(x)
  if (!is.null(lower) &&
      if (strict) value <= lower else value < lower) {
    relation <- if (strict) "greater than" else "at least"
    stop(name, " must be ", relation, " ", lower, ".", call. = FALSE)
  }
  value
}

.synthetic.prohibited <- function(x) {
  if (is.function(x) || is.environment(x) || is.language(x) ||
      typeof(x) %in% c("externalptr", "weakref")) {
    return(TRUE)
  }
  if (is.list(x)) return(any(vapply(x, .synthetic.prohibited, logical(1))))
  FALSE
}

.new.synthetic.component <- function(kind, family, parameters,
                                     version = 1L, subclass) {
  kind <- .synthetic.scalar.character(kind, "kind")
  family <- .synthetic.scalar.character(family, "family")
  version <- .synthetic.scalar.integer(version, "version", 1L)
  if (.synthetic.prohibited(parameters)) {
    stop("Component parameters must be canonically serializable.",
         call. = FALSE)
  }
  structure(
    list(
      kind = kind,
      family = family,
      version = version,
      parameters = parameters
    ),
    class = c(subclass, paste0("synthetic_", kind), "synthetic_component")
  )
}

.is.synthetic.component <- function(x, kind) {
  inherits(x, paste0("synthetic_", kind)) &&
    identical(x$kind, kind)
}

.with.synthetic.rng.preserved <- function(code) {
  kinds <- RNGkind()
  had.seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had.seed) old.seed <- get(".Random.seed", envir = .GlobalEnv)
  on.exit({
    do.call(RNGkind, as.list(kinds))
    if (had.seed) {
      assign(".Random.seed", old.seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  force(code)
}
