# Import existing synthetic observations for article display; never resample.
args <- commandArgs(TRUE)
if(length(args)!=1L)stop('Supply the completed density/curvature experiment directory.')
root <- normalizePath(args[1])
ids <- c(paste0('paraboloid_a',c(1,2,4)),paste0('saddle_a',c(1,2,4)),'swiss_roll')
files <- paste0('results/',ids,'/sample_1.rds')
views <- setNames(lapply(seq_along(ids),function(i) {
 sample <- readRDS(file.path(root,files[i]))
 stopifnot(nrow(sample$X)>=300L,ncol(sample$X)==3L)
 list(X=sample$X[1:300,,drop=FALSE],endpoints=1:64,rep=1L,n=300L)
}),ids)
out <- 'inst/extdata/fermat-density-curvature'
saveRDS(views,file.path(out,'surface-views.rds'),compress='xz',version=2)
provenance <- list(experiment='fermat_density_curvature_01_oct_2026',
 source_md5=setNames(unname(tools::md5sum(file.path(root,files))),files),
 display='First 300 observations of repetition 1; first 64 are fixed endpoints.',
 note='Reuses the original area-uniform samples; no distances, fits or references recomputed.')
dput(provenance,file=file.path(out,'surface-views-provenance.R'))
