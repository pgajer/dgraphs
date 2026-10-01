b <- readRDS('inst/extdata/fermat-density-curvature/benchmark.rds')
m <- b$metrics; s <- b$summary
stopifnot(nrow(m)==2100L,nrow(s)==420L,nrow(b$references)==10500L,
 !anyDuplicated(m[c('id','rep','n','method')]),
 all(is.finite(m$nrmse)),all(m$calibration_pairs<=500L),all(m$calibration_pairs[m$family=="complete"]==500L),
 sum(m$components>1)==4L,sum(m$requested_test-m$test_pairs)==238L,
 all(is.finite(b$references$reference)))
for(i in seq_len(nrow(s))) {
 z <- m[m$id==s$id[i] & m$n==s$n[i] & m$method==s$method[i],]
 stopifnot(nrow(z)==5L,abs(mean(z$nrmse)-s$mean[i])<1e-12,
 abs(sd(z$nrmse)/sqrt(5)-s$se[i])<1e-12,
 abs(mean(z$difference_from_ambient)-s$difference[i])<1e-12)
}
for(p in list.files('inst/examples/fermat-density-curvature',pattern='[.]R$',full.names=TRUE)) parse(p)
figs <- list.files('vignettes/articles/figures/fermat-density-curvature',full.names=TRUE)
for(p in figs)stopifnot(unname(tools::md5sum(p))==b$provenance$source_md5[[paste0('results/figures/',basename(p))]])
source('inst/examples/fermat-density-curvature/common.R')
stopifnot(score(1:6,2*(1:6),1:3,4:6)['nrmse']==0)
cat('Verified all 420 aggregate rows against 2,100 saved conditions; coverage, figure hashes, and reproduction script syntax passed.\n')
