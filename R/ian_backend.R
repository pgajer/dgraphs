#' Build the Optional IAN Backend
#'
#' Compile the pinned IAN and Clarabel sources installed with dgraphs in a new
#' directory. The supported build target is macOS arm64. Setup requires Python 3,
#' Apple's C++ compiler/SDK, and matching native Cargo/Rust tools (Rust >= 1.77).
#' An initial build needs cached crates or network access. No tools are installed
#' by this function. Compilation is explicit and never starts inside
#' [create.ian.graph()] or ordinary package installation.
#'
#' @param build.dir New output directory, including logs and source copies.
#'   Existing files/directories are refused. A path containing spaces is allowed.
#' @param python Python 3 command or executable path.
#' @param cargo Cargo command or executable path from a native arm64 toolchain.
#' @param rustc Rust compiler command or path from the same toolchain as `cargo`.
#' @param cxx C++ compiler command or executable path.
#' @param offline Logical scalar. If `TRUE`, Cargo uses only cached dependencies.
#' @return The absolute path to `dgraphs_ian.so`, invisibly. Save this path and pass
#'   it to `create.ian.graph(..., backend = path)`. Reuse the built module with the
#'   same R installation; rebuild when changing R runtime or backend sources.
#'   Build errors retain available logs and raise an R error. No shared package
#'   library is modified. Build records identify source files and tool commands.
#' @examples
#' \dontrun{
#' backend <- build.ian.backend("ian-build")
#' fit <- create.ian.graph(matrix(c(0, 1, 2), ncol = 1), backend = backend)
#' stopifnot(fit$complete)
#' }
#' @seealso [create.ian.graph()]
#' @export
build.ian.backend <- function(build.dir, python = "python3", cargo = "cargo",
                              rustc = "rustc", cxx = "clang++", offline = FALSE) {
    scalar.text <- function(x) is.character(x) && length(x) == 1L &&
        !is.na(x) && nzchar(x)
    if (!scalar.text(build.dir)) stop("build.dir must be one nonempty path.", call. = FALSE)
    build.dir <- path.expand(build.dir)
    if (file.exists(build.dir) || dir.exists(build.dir))
        stop("build.dir must be a new directory; existing paths are not overwritten.", call. = FALSE)
    if (!is.logical(offline) || length(offline) != 1L || is.na(offline))
        stop("offline must be TRUE or FALSE.", call. = FALSE)
    resolve.tool <- function(value, name) {
        if (!scalar.text(value)) stop(name, " must name one executable.", call. = FALSE)
        value <- path.expand(value)
        found <- if (file.exists(value)) value else unname(Sys.which(value))
        if (!nzchar(found) || dir.exists(found) || file.access(found, 1L) != 0L)
            stop(name, " executable is unavailable: ", value, call. = FALSE)
        # Keep the executable name: Cargo/Rustup proxies use argv[0].
        file.path(normalizePath(dirname(found), mustWork = TRUE), basename(found))
    }
    python <- resolve.tool(python, "python")
    cargo <- resolve.tool(cargo, "cargo")
    rustc <- resolve.tool(rustc, "rustc")
    cxx <- resolve.tool(cxx, "cxx")
    if (!identical(Sys.info()[["sysname"]], "Darwin") ||
        !R.version$arch %in% c("aarch64", "arm64"))
        stop("The IAN backend build is currently supported on macOS arm64 only.", call. = FALSE)
    helper <- system.file("ian", "build_backend.py", package = "dgraphs")
    if (!nzchar(helper)) stop("Installed IAN build sources are unavailable.", call. = FALSE)
    args <- c(helper, "--build-dir", build.dir, "--cargo", cargo, "--rustc", rustc,
              "--cxx", cxx, "--r", file.path(R.home("bin"), "R"),
              "--rscript", file.path(R.home("bin"), "Rscript"),
              if (offline) "--offline")
    status <- system2(python, args = vapply(args, shQuote, ""))
    if (status != 0L) stop("IAN backend build failed; available logs are in ",
                           build.dir, ".", call. = FALSE)
    module <- file.path(build.dir, "dgraphs_ian.so")
    if (!file.exists(module)) stop("IAN build returned without a module; see ",
                                  build.dir, ".", call. = FALSE)
    invisible(normalizePath(module, mustWork = TRUE))
}
