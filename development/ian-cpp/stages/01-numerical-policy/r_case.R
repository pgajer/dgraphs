args<-commandArgs(TRUE);stopifnot(length(args)==5)
.libPaths(c('/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/typed-core/evidence/library',.libPaths()))
library(dgraphs);source(args[1])
f<-jsonlite::fromJSON(args[2],simplifyVector=FALSE);out<-args[4];dir.create(out,recursive=TRUE)
mat<-function(x) do.call(rbind,lapply(x,unlist))
writeLines('reserved one R engine call',file.path(out,'reservation.txt'))
r<-create.ian.graph(mat(f$features),distances=mat(f$distances),specimen.ids=unlist(f$ids),diagnostics='full',backend=args[3],max.solves=1000L,numerical.policy=f$numerical_policy)
saveRDS(r,file.path(out,'result.rds'))
con<-file(file.path(out,'trace.jsonl'),'w');for(e in r$diagnostics$trace)writeLines(jsonlite::toJSON(e,auto_unbox=TRUE,digits=NA,null='null'),con);close(con)
jsonlite::write_json(list(complete=r$complete,solves=r$diagnostics$solves,error=r$error),file.path(out,'status.json'),auto_unbox=TRUE,digits=NA)
stopifnot(r$complete,identical(r$backend$numerical_policy,f$numerical_policy),length(r$diagnostics$solver_history)==r$diagnostics$solves)
stopifnot(inherits(r$initial_graph,'dgraph'),inherits(r$final_graph,'dgraph'),identical(r$final_graph$metadata$method,f$numerical_policy))
stopifnot(all(vapply(r$diagnostics$solver_history,function(e)!any(c('backend_rhs','backend_primal','backend_dual','backend_slack') %in% names(e)),TRUE)))
if(args[5]!='none') {
 b<-readRDS(args[5]);clean<-function(x){if(!is.list(x))return(x);n<-names(x);if(!is.null(n))x<-x[!n%in%c('seconds','source_identity','configuration_identity','trace_format','requested_max_solves')];z<-lapply(x,clean);attributes(z)<-attributes(x);z}
 stopifnot(identical(clean(r),clean(b)))
}
writeLines(capture.output(sessionInfo()),file.path(out,'session.txt'));cat('R complete',r$diagnostics$solves,'attempts\n')
