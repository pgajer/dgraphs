a<-commandArgs(TRUE);.libPaths(c(a[1],.libPaths()));library(dgraphs)
stopifnot(normalizePath(find.package('dgraphs'))==normalizePath(file.path(a[1],'dgraphs')))
source(file.path(dirname(sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE))),'../01-numerical-policy/trace_json.R'))
spec<-jsonlite::fromJSON(a[2],simplifyVector=FALSE);out<-a[4];dir.create(out,recursive=TRUE)
if(!is.null(spec$metadata)){
 f<-jsonlite::fromJSON(spec$metadata)
 read.matrix<-function(path,n,p){con<-file(path,'rb');on.exit(close(con));matrix(readBin(con,'double',n=as.double(n)*p,size=8,endian='little'),n,p)}
 X<-read.matrix(f$features,f$n,f$p);D<-read.matrix(f$distances,f$n,f$n);ids<-f$ids
}else{
 f<-jsonlite::fromJSON(spec$fixture,simplifyVector=FALSE);mat<-function(x)do.call(rbind,lapply(x,unlist));X<-mat(f$features);D<-mat(f$distances);ids<-unlist(f$ids)
}
args<-list(X=X,distances=D,specimen.ids=ids,backend=a[3],max.solves=1500L,diagnostics=spec$detail)
if(spec$mode=='strict')args<-c(args,list(numerical.policy='IAN evaluated-LP 1.0',preserve.connectivity=FALSE))
if(spec$mode=='explicit')args<-c(args,list(numerical.policy='IAN evaluated-LP retry-power 0.1',preserve.connectivity=TRUE))
jsonlite::write_json(list(state='reserved',mode=spec$mode,rows=nrow(X),arguments=names(args)),file.path(out,'reservation.json'),auto_unbox=TRUE)
r<-do.call(create.ian.graph,args);saveRDS(r,file.path(out,'result.rds'))
events<-if(spec$detail=='full')r$diagnostics$trace else r$diagnostics$solver_history
con<-file(file.path(out,'trace.jsonl'),'w');for(e in events)writeLines(ian.trace.json(e),con);close(con)
clean<-function(x){if(!is.list(x))return(x);if(!is.null(names(x)))x<-x[!names(x)%in%c('seconds','source_identity','configuration_identity','requested_max_solves',if(spec$detail=='summary')'trace')];y<-lapply(x,clean);attributes(y)<-attributes(x);y}
old<-readRDS(spec$baseline);stopifnot(r$complete,identical(clean(r),clean(old)))
if(spec$mode!='strict')stopifnot(length(unique(graph.connected.components(r$final_graph)))==1L,r$backend$numerical_policy=='IAN evaluated-LP retry-power 0.1',r$backend$pruning_policy=='IAN bridge-protected 0.1')
jsonlite::write_json(list(complete=r$complete,solves=r$diagnostics$solves,exact_saved_R=TRUE,mode=spec$mode),file.path(out,'status.json'),auto_unbox=TRUE)
writeLines(capture.output(sessionInfo()),file.path(out,'session.txt'))
