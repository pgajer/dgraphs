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

# Check the frozen calibration-only selection and transfer snapshot.
p <- b$power_tuning
stopifnot(nrow(p$selection)==9L,nrow(p$folds)==3000L,nrow(p$cv_summary)==301L,
 nrow(p$fold_scores)==7525L,nrow(p$transfer_metrics)==1275L,nrow(p$transfer_summary)==255L,
 all(table(p$folds$id,p$folds$fold)==100L),all(p$folds$pair<=500L),
 all(p$fold_scores$training_pairs==400L),all(p$fold_scores$validation_pairs==100L),
 all(p$transfer_metrics$calibration_pairs==500L),all(p$transfer_metrics$test_pairs==1000L),
 !anyDuplicated(p$fold_scores[c('id','rep','p','reference','fold')]),
 identical(p$provenance$selection_md5,p$completion$selection_md5))
for(i in seq_len(nrow(p$selection))) {
 x<-p$selection[i,];q<-p$cv_summary[p$cv_summary$id==x$id & p$cv_summary$reference==x$reference,]
 stopifnot(abs(x$cv_error-min(q$mean))<1e-12,x$p==q$p[order(q$mean,q$p)[1]])
}
for(i in seq_len(nrow(p$cv_repetitions))) {
 x<-p$cv_repetitions[i,];q<-p$fold_scores
 q<-q[q$id==x$id & q$rep==x$rep & q$p==x$p & q$reference==x$reference,]
 stopifnot(nrow(q)==5L,abs(x$error-sqrt(sum(q$sse)/sum(q$reference_ss)))<1e-12)
}
for(i in seq_len(nrow(p$transfer_summary))) {
 x<-p$transfer_summary[i,];q<-p$transfer_metrics
 q<-q[q$id==x$id & q$n==x$n & q$method==x$method & q$reference==x$reference,]
 stopifnot(nrow(q)==5L,abs(x$mean-mean(q$nrmse))<1e-12,
           abs(x$se-sd(q$nrmse)/sqrt(5))<1e-12)
}
cat('Verified power selection, all out-of-fold aggregates, and 255 transfer summaries.\n')
