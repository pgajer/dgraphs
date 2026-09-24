a<-commandArgs(TRUE);.libPaths(c(file.path(a[1],'library-v3'),.libPaths()));library(dgraphs)
source(file.path(dirname(sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE))),'../01-numerical-policy/trace_json.R'))
j<-jsonlite::fromJSON(a[2],simplifyVector=FALSE);mat<-function(x)do.call(rbind,lapply(x,unlist));out<-a[4];dir.create(out,recursive=TRUE)
r<-dgraphs:::create.ian.graph(mat(j$features),distances=mat(j$distances),specimen.ids=unlist(j$ids),backend=a[3],numerical.policy=j$numerical_policy,preserve.connectivity=isTRUE(j$preserve_connectivity),diagnostics='full',max.solves=1500L)
saveRDS(r,file.path(out,'result.rds'));con<-file(file.path(out,'trace.jsonl'),'w');for(e in r$diagnostics$trace)writeLines(ian.trace.json(e),con);close(con)
old<-readRDS(a[5]);clean<-function(x){if(!is.list(x))return(x);n<-names(x);if(!is.null(n))x<-x[!n%in%c('seconds','source_identity','configuration_identity','requested_max_solves')];z<-lapply(x,clean);attributes(z)<-attributes(x);z}
stopifnot(r$complete,identical(clean(r),clean(old)));jsonlite::write_json(list(complete=r$complete,solves=r$diagnostics$solves,exact_saved_R=TRUE),file.path(out,'status.json'),auto_unbox=TRUE)
