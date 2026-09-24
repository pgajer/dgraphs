# Use pinned dgraphs geometry/sampling API without installing or loading a package.
args <- commandArgs(trailingOnly=TRUE)
root <- normalizePath(args[1], mustWork=TRUE)
out <- args[2]
stopifnot(!dir.exists(out)); dir.create(out, recursive=TRUE)
for (f in c("synthetic_components.R", "synthetic_geometry.R",
            "synthetic_sampling.R", "synthetic_realization.R"))
    source(file.path(root, "R", f), local=.GlobalEnv)
writeLines(capture.output(sessionInfo()), file.path(out,"session-info.txt"))
for (d in 2:5) {
    seed <- 2026091700L+d
    A <- diag((-1)^(seq_len(d)-1L)*0.5/sqrt(d))
    geometry <- synthetic.quadform(d,d+1L,forms=list(A))
    sampling <- synthetic.sampling.uniform.box(rep(-1,d),rep(1,d))
    sample <- sample.synthetic.geometry(geometry,sampling,n=1000L,seed=seed)
    stopifnot(identical(dim(sample$latent),c(1000L,d)),
              identical(dim(sample$predictors),c(1000L,d+1L)))
    case <- file.path(out,paste0("quadform_d",d));dir.create(case)
    saveRDS(sample,file.path(case,"sample.rds"),version=3)
    for (name in c("latent","predictors"))
        writeBin(as.double(sample[[name]]),file.path(case,paste0(name,".bin")),size=8,endian="little")
    writeBin(as.double(A),file.path(case,"form.bin"),size=8,endian="little")
    dput(list(intrinsic.dim=d,ambient.dim=d+1L,n=1000L,seed=seed,
              geometry=geometry,sampling=sampling,rng=sample$rng),file.path(case,"specification.R"))
}
