# Selection uses calibration references only. Run before power_transfer.R.
source('power_common.R'); workers <- power_workers()
stopifnot(!file.exists(file.path(power_root,'selection.csv')))
refs <- subset(read.csv('results/references.csv'),split=='calibration')
folds <- do.call(rbind,lapply(seq_len(nrow(power_models)),function(i) {
 id <- power_models$id[i]; d <- readRDS(file.path('results',id,'design.rds'))
 stopifnot(length(d$cal)==500L,length(d$test)==1000L,!length(intersect(d$cal,d$test)))
 set.seed(63100L+i)
 data.frame(id=id,pair=d$cal,fold=sample(rep(1:5,each=100)))
}))
write.csv(folds,file.path(power_root,'folds.csv'),row.names=FALSE)
cv_for <- function(id,rep,p,reference) {
 f <- folds[folds$id==id,]; r <- refs[refs$id==id,]
 truth <- r[[if(reference=='best_of_six')'reference' else 'clairaut']][match(f$pair,r$pair)]
 est <- power_distances(id,rep,300L,p)[f$pair]
 cbind(data.frame(id=id,rep=rep,p=p,reference=reference),power_cv(est,truth,f$fold))
}
summary_cv <- function(z) {
 rr <- do.call(rbind,lapply(split(z,interaction(z$id,z$reference,z$p,z$rep,drop=TRUE)),function(x)
  data.frame(id=x$id[1],reference=x$reference[1],p=x$p[1],rep=x$rep[1],
             error=sqrt(sum(x$sse)/sum(x$reference_ss)))))
 ss <- do.call(rbind,lapply(split(rr,interaction(rr$id,rr$reference,rr$p,drop=TRUE)),function(x)
  data.frame(id=x$id[1],reference=x$reference[1],p=x$p[1],mean=mean(x$error),
             sd=sd(x$error),se=sd(x$error)/sqrt(5))))
 list(repetitions=rr,summary=ss)
}
coarse_work <- function(i) {
 id <- power_models$id[i]; cap <- if(grepl('saddle_a[24]',id))2 else 1.5
 refs_here <- c('best_of_six',if(grepl('paraboloid',id))'clairaut')
 out <- list(); j <- 0L
 for(rep in 1:5)for(p in seq(1,cap,by=.025))for(reference in refs_here) {
  j<-j+1L;out[[j]]<-cv_for(id,rep,p,reference)
 }
 z <- do.call(rbind,out);saveRDS(z,file.path(power_root,paste0(id,'_coarse.rds')))
 cat(id,'coarse complete\n');flush.console();z
}
ans <- parallel::mclapply(seq_len(nrow(power_models)),coarse_work,mc.cores=workers,mc.preschedule=FALSE)
stopifnot(!any(vapply(ans,inherits,FALSE,'try-error')))
coarse <- do.call(rbind,ans); sm <- summary_cv(coarse)$summary
winners <- do.call(rbind,lapply(split(sm,interaction(sm$id,sm$reference,drop=TRUE)),function(x)x[order(x$mean,x$p)[1],]))
write.csv(winners,file.path(power_root,'coarse_winners.csv'),row.names=FALSE)
refine_work <- function(i) {
 id <- power_models$id[i]; cap <- if(grepl('saddle_a[24]',id))2 else 1.5
 ww <- winners[winners$id==id,];out<-list();j<-0L
 for(w in seq_len(nrow(ww))) {
  candidate <- unique(round(c(seq(1,cap,by=.025),seq(max(1,ww$p[w]-.025),min(cap,ww$p[w]+.025),by=.005)),3))
  for(rep in 1:5)for(p in candidate) {
   j<-j+1L;out[[j]]<-cv_for(id,rep,p,ww$reference[w])
  }
 }
 z<-do.call(rbind,out);saveRDS(z,file.path(power_root,paste0(id,'_refined.rds')))
 cat(id,'refinement complete\n');flush.console();z
}
ans <- parallel::mclapply(seq_len(nrow(power_models)),refine_work,mc.cores=workers,mc.preschedule=FALSE)
stopifnot(!any(vapply(ans,inherits,FALSE,'try-error')))
fold_scores <- do.call(rbind,ans);cv <- summary_cv(fold_scores)
selected <- do.call(rbind,lapply(split(cv$summary,interaction(cv$summary$id,cv$summary$reference,drop=TRUE)),function(x) {
 b <- x[order(x$mean,x$p)[1],]; near <- x$p[x$mean<=1.01*b$mean]
 cap <- if(grepl('saddle_a[24]',b$id))2 else 1.5
 data.frame(id=b$id,reference=b$reference,p=b$p,cv_error=b$mean,cv_se=b$se,
  near_min=min(near),near_max=max(near),near_powers=paste(sort(near),collapse=';'),
  search_max=cap,boundary=b$p==1 || b$p==cap,candidates=nrow(x))
}))
write.csv(fold_scores,file.path(power_root,'fold_scores.csv'),row.names=FALSE)
write.csv(cv$repetitions,file.path(power_root,'cv_repetitions.csv'),row.names=FALSE)
write.csv(cv$summary,file.path(power_root,'cv_summary.csv'),row.names=FALSE)
write.csv(selected,file.path(power_root,'selection.csv'),row.names=FALSE)
inputs<-c('common.R','power_common.R','power_tuning.R','results/references.csv',
 unlist(lapply(power_models$id,function(id)file.path('results',id,c('design.rds',paste0('sample_',1:5,'.rds'))))))
manifest<-list(completed=format(Sys.time(),tz='America/New_York',usetz=TRUE),
 objective='Mean over five repetitions of pooled out-of-fold normalized RMS error across 500 calibration pairs; five folds, 400 training and 100 validation pairs each.',
 folds_seed=63101:63106,coarse_step=.025,refined_step=.005,refined_halfwidth=.025,
 near_minimum='Tested powers with CV error within 1% relative to the smallest CV error; descriptive, not an uncertainty interval.',
 tie_rule='Lowest power among exact equal minimum scores.',
 evaluation_access='Evaluation pair scores are not used in this script. Selection frozen before running power_transfer.R.',
 selection_md5=unname(tools::md5sum(file.path(power_root,'selection.csv'))),
 source_md5=as.list(tools::md5sum(inputs)),dgraphs=as.character(packageVersion('dgraphs')))
jsonlite::write_json(manifest,'power_tuning_provenance.json',pretty=TRUE,auto_unbox=TRUE)
writeLines(capture.output(sessionInfo()),file.path(power_root,'sessionInfo.txt'))
print(selected);cat('ALL NINE SELECTIONS FROZEN\n')
