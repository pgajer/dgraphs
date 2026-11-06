# Separate diagnostic: four times the search rounds on 50 fixed pairs per saddle.
source('common.R');tasks<-expand.grid(id=paste0('saddle_a',c(1,2,4)),pair=seq(1,1500,by=30))
dir.create('results/reference_sensitivity',showWarnings=FALSE)
work<-function(i){
 id<-tasks$id[i];j<-tasks$pair[i];file<-file.path('results/reference_sensitivity',paste0(id,'_',j,'.rds'));if(file.exists(file))return(TRUE)
 d<-readRDS(file.path('results',id,'design.rds'));ij<-d$pairs[j,];u<-d$anchor$uv[ij[1],];v<-d$anchor$uv[ij[2],]
 start<-proc.time()[3];q<-dgraphs:::quadform_geodesics(d$anchor$A,u,v,list(kind='ball',center=c(0,0),radius=1),method='best_of_six',control=list(seed=config$seed+match(id,read.csv('results/models.csv')$id)*10000+j,max_epochs=256L),return.paths=TRUE)
 saveRDS(list(id=id,pair=j,length=q$summary$length,status=q$summary$status,seconds=unname(proc.time()[3]-start),path=q$results[[1]]$path,ensemble=q$results[[1]]$backend_result$ensemble),file)
 cat(id,j,'complete\n');flush.console();TRUE
}
args<-commandArgs(TRUE); workers<-if(length(args))as.integer(args[1]) else 1L
a<-parallel::mclapply(seq_len(nrow(tasks)),work,mc.cores=workers,mc.preschedule=FALSE);stopifnot(all(vapply(a,isTRUE,FALSE)))
