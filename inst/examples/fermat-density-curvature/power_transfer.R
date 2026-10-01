# Transfer the frozen power, refitting only scale at each sample size.
source('power_common.R');workers<-power_workers()
selection_file<-file.path(power_root,'selection.csv')
manifest<-jsonlite::read_json('power_tuning_provenance.json')
selection_hash<-unname(tools::md5sum(selection_file))
stopifnot(identical(selection_hash,manifest$selection_md5))
selected<-read.csv(selection_file);stopifnot(nrow(selected)==9L)
refs<-read.csv('results/references.csv')
tasks<-expand.grid(model=seq_len(nrow(power_models)),rep=1:5)
work<-function(task) {
 id<-power_models$id[tasks$model[task]];rep<-tasks$rep[task]
 d<-readRDS(file.path('results',id,'design.rds'));r<-refs[refs$id==id,]
 b<-selected[selected$id==id & selected$reference=='best_of_six',]
 h<-selected[selected$id==id & selected$reference=='clairaut',]
 methods<-data.frame(method=c('ambient','fixed_1.25','fixed_2','selected_best_of_six','knn_20'),
                     p=c(1,1.25,2,b$p,1))
 if(nrow(h))methods<-rbind(methods,data.frame(method='selected_clairaut',p=h$p))
 out<-list();j<-0L
 for(n in config$n) {
  old<-readRDS(file.path('results',id,sprintf('distances_r%d_n%d.rds',rep,n)))$results
  for(a in seq_len(nrow(methods))) {
   method<-methods$method[a];p<-methods$p[a]
   est<-if(method=='knn_20')old$knn_20$distance else power_distances(id,rep,n,p)
   stopifnot(length(est)==1500L,all(is.finite(est)),all(est>0))
   for(reference in c('best_of_six',if(nrow(h))'clairaut')) {
    truth<-r[[if(reference=='best_of_six')'reference' else 'clairaut']][match(seq_len(1500),r$pair)]
    z<-score(est,truth,d$cal,d$test)
    j<-j+1L;out[[j]]<-data.frame(id=id,rep=rep,n=n,method=method,p=p,reference=reference,
                                as.list(z),check.names=FALSE)
   }
  }
 }
 z<-do.call(rbind,out);saveRDS(z,file.path(power_root,sprintf('%s_transfer_r%d.rds',id,rep)))
 cat(id,'repetition',rep,'transfer complete\n');flush.console();z
}
ans<-parallel::mclapply(seq_len(nrow(tasks)),work,mc.cores=workers,mc.preschedule=FALSE)
stopifnot(!any(vapply(ans,inherits,FALSE,'try-error')))
z<-do.call(rbind,ans)
key<-function(x)paste(x$id,x$rep,x$n,x$reference)
ambient<-z[z$method=='ambient',];fixed<-z[z$method=='fixed_1.25',]
z$difference_from_ambient<-z$nrmse-ambient$nrmse[match(key(z),key(ambient))]
z$difference_from_1.25<-z$nrmse-fixed$nrmse[match(key(z),key(fixed))]
write.csv(z,file.path(power_root,'transfer_metrics.csv'),row.names=FALSE)
s<-do.call(rbind,lapply(split(z,interaction(z$id,z$n,z$method,z$reference,drop=TRUE)),function(x) {
 stopifnot(nrow(x)==5L)
 data.frame(id=x$id[1],n=x$n[1],method=x$method[1],p=x$p[1],reference=x$reference[1],
 mean=mean(x$nrmse),se=sd(x$nrmse)/sqrt(5),
 difference=mean(x$difference_from_ambient),difference_se=sd(x$difference_from_ambient)/sqrt(5),
 difference_from_1.25=mean(x$difference_from_1.25),difference_from_1.25_se=sd(x$difference_from_1.25)/sqrt(5),
 wins_ambient=sum(x$difference_from_ambient<0),coverage=min(x$test_pairs))
}))
write.csv(s,file.path(power_root,'transfer_summary.csv'),row.names=FALSE)
stopifnot(identical(selection_hash,unname(tools::md5sum(selection_file))),
          all(z$calibration_pairs==500L),all(z$test_pairs==1000L),all(is.finite(z$nrmse)))
jsonlite::write_json(list(completed=format(Sys.time(),tz='America/New_York',usetz=TRUE),
 selection_md5=selection_hash,conditions=nrow(z),summaries=nrow(s),failed=0L,
 missing_calibration_pairs=0L,missing_evaluation_pairs=0L,
 source_md5=as.list(tools::md5sum(c('power_common.R','power_transfer.R')))),
 file.path(power_root,'transfer_completion.json'),pretty=TRUE,auto_unbox=TRUE)
cat('FROZEN-POWER EVALUATION COMPLETE:',nrow(z),'conditions\n')
