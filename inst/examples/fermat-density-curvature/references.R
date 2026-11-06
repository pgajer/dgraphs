source('common.R');workers<-as.integer(commandArgs(TRUE)[1]);models<-read.csv('results/models.csv');tasks<-expand.grid(model=seq_len(nrow(models)),chunk=1:60)
work<-function(t) {
 id<-models$id[tasks$model[t]];chunk<-tasks$chunk[t];root<-file.path('results',id);dir.create(file.path(root,'references'),showWarnings=FALSE)
 file<-file.path(root,'references',sprintf('%03d.rds',chunk));if(file.exists(file))return(TRUE)
 d<-readRDS(file.path(root,'design.rds'));ix<-seq((chunk-1)*25+1,chunk*25)
 out<-lapply(ix,function(j){
  ij<-d$pairs[j,];u<-d$anchor$uv[ij[1],];v<-d$anchor$uv[ij[2],];start<-proc.time()[3]
  if(id=='swiss_roll')return(list(pair=j,length=sqrt(sum((u-v)^2)),status='analytic',seconds=0,clairaut=NA_real_))
  tryCatch({q<-dgraphs:::quadform_geodesics(d$anchor$A,u,v,list(kind='ball',center=c(0,0),radius=1),method='best_of_six',control=list(seed=config$seed+tasks$model[t]*10000+j),return.paths=TRUE)
   cc<-if(d$model$shape=='paraboloid')dgraphs:::quadform_geodesics(d$anchor$A,u,v,list(kind='ball',center=c(0,0),radius=1),method='paraboloid_clairaut',return.paths=FALSE)$summary$length else NA_real_
   z<-q$results[[1]];list(pair=j,length=q$summary$length,status=q$summary$status,seconds=unname(proc.time()[3]-start),clairaut=cc,path=z$path,ensemble=z$backend_result$ensemble)
  },error=function(e)list(pair=j,length=NA_real_,status='error',message=conditionMessage(e),seconds=unname(proc.time()[3]-start),clairaut=NA_real_))
 });saveRDS(out,file);cat(id,'reference',chunk,'/60 complete\n');flush.console();TRUE
}
ans<-parallel::mclapply(seq_len(nrow(tasks)),work,mc.cores=workers,mc.preschedule=FALSE);stopifnot(all(vapply(ans,isTRUE,FALSE)));cat('REFERENCE TASKS COMPLETE\n')
