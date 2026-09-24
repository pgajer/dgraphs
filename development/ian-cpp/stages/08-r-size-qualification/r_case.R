a <- commandArgs(TRUE);.libPaths(c(a[1],.libPaths()));library(dgraphs)
stopifnot(normalizePath(find.package('dgraphs'))==normalizePath(file.path(a[1],'dgraphs')))
source(file.path(dirname(sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE))),'../01-numerical-policy/trace_json.R'))
f <- jsonlite::fromJSON(a[2]);out <- a[4];dir.create(out,recursive=TRUE);detail <- a[6]
read.matrix <- function(path,n,p){con<-file(path,'rb');on.exit(close(con));matrix(readBin(con,'double',n=as.double(n)*p,size=8,endian='little'),n,p)}
X<-read.matrix(f$features,f$n,f$p);D<-read.matrix(f$distances,f$n,f$n)
start<-proc.time()[3];r<-dgraphs:::create.ian.graph(X,distances=D,specimen.ids=f$ids,diagnostics=detail,backend=a[3],max.solves=1500L,numerical.policy=f$numerical_policy,preserve.connectivity=a[5]=='connected');elapsed<-proc.time()[3]-start
saveRDS(r,file.path(out,'result.rds'));events<-if(detail=='full')r$diagnostics$trace else r$diagnostics$solver_history
con<-file(file.path(out,'trace.jsonl'),'w');for(e in events)writeLines(ian.trace.json(e),con);close(con)
jsonlite::write_json(list(complete=r$complete,solves=r$diagnostics$solves,error=r$error,engine_seconds=unname(elapsed),detail=detail),file.path(out,'status.json'),auto_unbox=TRUE,digits=NA)
writeLines(capture.output(sessionInfo()),file.path(out,'session.txt'))
if(!r$complete)quit(status=1)
