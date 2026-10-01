source('power_common.R')
s<-read.csv(file.path(power_root,'selection.csv'));f<-read.csv(file.path(power_root,'folds.csv'))
z<-read.csv(file.path(power_root,'fold_scores.csv'));cv<-read.csv(file.path(power_root,'cv_summary.csv'))
rr<-read.csv(file.path(power_root,'cv_repetitions.csv'))
tm<-read.csv(file.path(power_root,'transfer_metrics.csv'));ts<-read.csv(file.path(power_root,'transfer_summary.csv'))
manifest<-jsonlite::read_json('power_tuning_provenance.json')
for(path in names(manifest$source_md5))
 stopifnot(identical(unname(tools::md5sum(path)),manifest$source_md5[[path]]))
stopifnot(identical(unname(tools::md5sum(file.path(power_root,'selection.csv'))),manifest$selection_md5),
 nrow(s)==9L,nrow(f)==3000L,all(table(f$id,f$fold)==100L),all(z$training_pairs==400L),all(z$validation_pairs==100L),
 all(tm$calibration_pairs==500L),all(tm$test_pairs==1000L),nrow(tm)==1275L,nrow(ts)==255L,
 !anyDuplicated(z[c('id','rep','p','reference','fold')]),!anyDuplicated(tm[c('id','rep','n','method','reference')]),
 all(is.finite(tm$nrmse)),all(is.finite(z$scale)),all(is.finite(z$sse)))
# Independently reconstruct fold training scales and held-out residual sums.
refs<-read.csv('results/references.csv');max_fold_difference<-0
for(i in seq_len(nrow(s))) {
 a<-s[i,];id<-a$id;d<-readRDS(file.path('results',id,'design.rds'));ff<-f[f$id==id,]
 stopifnot(setequal(ff$pair,d$cal),!length(intersect(ff$pair,d$test)))
 r<-refs[refs$id==id,];truth<-r[[if(a$reference=='best_of_six')'reference' else 'clairaut']][match(d$cal,r$pair)]
 candidate<-cv[cv$id==id & cv$reference==a$reference,]
 stopifnot(abs(a$cv_error-min(candidate$mean))<1e-14,
           a$p==candidate$p[order(candidate$mean,candidate$p)[1]])
 for(rep in 1:5) {
  est<-power_distances(id,rep,300,a$p)[d$cal]
  for(fold in 1:5) {
   train<-which(ff$fold!=fold);valid<-which(ff$fold==fold)
   scale<-as.numeric(crossprod(est[train],truth[train])/crossprod(est[train]))
   q<-z[z$id==id & z$reference==a$reference & z$rep==rep & z$p==a$p & z$fold==fold,]
   stopifnot(nrow(q)==1L)
   delta<-max(abs(q$scale-scale),abs(q$sse-sum((scale*est[valid]-truth[valid])^2)))
   max_fold_difference<-max(max_fold_difference,delta)
  }
 }
}
stopifnot(max_fold_difference<1e-9)
for(i in seq_len(nrow(cv))) {
 a<-cv[i,];q<-rr[rr$id==a$id & rr$p==a$p & rr$reference==a$reference,]
 stopifnot(nrow(q)==5L,abs(mean(q$error)-a$mean)<1e-12,abs(sd(q$error)/sqrt(5)-a$se)<1e-12)
}
for(i in seq_len(nrow(ts))) {
 a<-ts[i,];q<-tm[tm$id==a$id & tm$n==a$n & tm$method==a$method & tm$reference==a$reference,]
 stopifnot(nrow(q)==5L,abs(mean(q$nrmse)-a$mean)<1e-12,abs(sd(q$nrmse)/sqrt(5)-a$se)<1e-12)
}
# Every newly selected power is identical across sizes, and raw distances cannot
# increase when path-support points are added to the same nested sample pool.
max_nested_increase<-0
for(i in seq_len(nrow(s)))for(rep in 1:5) {
 a<-s[i,];D<-lapply(config$n,function(n)power_distances(a$id,rep,n,a$p))
 for(j in 2:5)max_nested_increase<-max(max_nested_increase,max(D[[j]]-D[[j-1]]))
 method<-paste0('selected_',a$reference)
 q<-tm[tm$id==a$id & tm$rep==rep & tm$method==method,]
 stopifnot(all(q$p==a$p),setequal(q$n,config$n))
}
stopifnot(max_nested_increase<1e-8)
# Original comparison scores must be preserved, including Clairaut rescoring.
old<-subset(read.csv('results/metrics.csv'),stratum=='all')
max_original_difference<-0
for(method in c('ambient','fixed_1.25','fixed_2','knn_20')) {
 name<-c(ambient='p1',fixed_1.25='p1.25',fixed_2='p2',knn_20='knn_20')[[method]]
 q<-tm[tm$method==method,];orig<-old[old$method==name,]
 ii<-match(paste(q$id,q$rep,q$n),paste(orig$id,orig$rep,orig$n))
 err<-ifelse(q$reference=='clairaut',orig$clairaut_nrmse[ii],orig$nrmse[ii])
 max_original_difference<-max(max_original_difference,max(abs(q$nrmse-err)))
}
stopifnot(max_original_difference<1e-12)
# One explicit graph check for each new selected source/reference, against cache.
max_explicit_difference<-0
for(i in seq_len(nrow(s))) {
 a<-s[i,];X<-readRDS(file.path('results',a$id,'sample_1.rds'))$X[1:150,]
 D<-dgraphs::fermat.distances(points=X,p=a$p,backend='explicit',rooted=FALSE)[1:64,1:64]
 d<-readRDS(file.path('results',a$id,'design.rds'))
 max_explicit_difference<-max(max_explicit_difference,max(abs(D[d$pairs]-power_distances(a$id,1,150,a$p))))
}
stopifnot(max_explicit_difference<1e-8)
result<-list(completed=format(Sys.time(),tz='America/New_York',usetz=TRUE),selections=nrow(s),
 candidate_reference_combinations=nrow(cv),fold_scores=nrow(z),transfer_conditions=nrow(tm),
 all_calibration_pairs=500L,all_evaluation_pairs=1000L,selection_hash_unchanged=TRUE,
 max_fold_recalculation_difference=max_fold_difference,max_original_score_difference=max_original_difference,
 max_nested_distance_increase=max_nested_increase,max_explicit_implicit_difference=max_explicit_difference,
 source_md5=as.list(tools::md5sum(c('power_common.R','power_tuning.R','power_transfer.R','power_summarize.R','power_validate.R'))))
jsonlite::write_json(result,'power_tuning_validation.json',pretty=TRUE,auto_unbox=TRUE)
print(result)
