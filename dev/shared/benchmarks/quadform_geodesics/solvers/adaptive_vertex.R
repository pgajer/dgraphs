# Development adapter; shared runtime must meet adaptive/README.md requirements.
.qga_files <- Filter(Negate(is.null), lapply(sys.frames(), function(f) f$ofile))
.qga_directory <- dirname(normalizePath(tail(.qga_files, 1L)[[1L]]))
.qga_namespace <- new.env(parent = environment())
sys.source(file.path(.qga_directory, "adaptive/common.R"), envir = .qga_namespace)
.qga_namespace$qga.adapter("adaptive_vertex")
