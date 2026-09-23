args<-commandArgs(TRUE);began<-proc.time()[['elapsed']]
schedule<-jsonlite::fromJSON(args[1],simplifyVector=FALSE);out<-args[2];dir.create(out,recursive=TRUE)
.libPaths(c(schedule$library,.libPaths()));library(dgraphs)
stopifnot(normalizePath(find.package('dgraphs'))==normalizePath(file.path(schedule$library,'dgraphs')))
source(schedule$trace.writer)
env<-new.env(parent=asNamespace('dgraphs'));sys.source(schedule$wrapper,env)
# Private profiling copy of the same wrapper; no namespace/package mutation.
env$.ian.adapter<-eval(parse(text=sub('.Call(native_run', '.timed.call(native_run',paste(deparse(env$.ian.adapter),collapse='\n'),fixed=TRUE)),env)
env$.timed.call<-function(...){t<-proc.time()[['elapsed']];r<-.Call(...);native.seconds<<-native.seconds+proc.time()[['elapsed']]-t;r}
original.graph<-env$.ian.graph
env$.ian.graph<-function(...){t<-proc.time()[['elapsed']];r<-original.graph(...);graph.seconds<<-graph.seconds+proc.time()[['elapsed']]-t;r}
mat<-function(x)do.call(rbind,lapply(x,unlist))
cases<-lapply(schedule$cases,function(c){f<-jsonlite::fromJSON(c$path,simplifyVector=FALSE);list(X=mat(f$features),D=mat(f$distances),ids=unlist(f$ids),policy=f$numerical_policy)})
write<-function(x,p)jsonlite::write_json(x,p,auto_unbox=TRUE,digits=NA)
account<-file(file.path(out,'account.jsonl'),'w');record<-function(x){writeLines(jsonlite::toJSON(x,auto_unbox=TRUE,digits=NA),account);flush(account)}
write(list(seconds=proc.time()[['elapsed']]-began),file.path(out,'setup.json'));entry<-0L
edge.matrix<-function(g){a<-graph.adjacency(g);stopifnot(!is.null(a));z<-do.call(rbind,lapply(seq_along(a),function(i){j<-a[[i]];j<-j[j>i];if(length(j))cbind(i,j)}));if(is.null(z))matrix(integer(),ncol=2) else z-1L}
for(k in seq_along(cases))for(rep in seq_len(schedule$repeats)-1L){
 f<-cases[[k]];folder<-file.path(out,entry);dir.create(folder);record(list(event='entry',entry=entry,fixture=schedule$cases[[k]]$name));native.seconds<-graph.seconds<-0
 start<-proc.time()[['elapsed']]
 r<-env$create.ian.graph(f$X,distances=f$D,specimen.ids=f$ids,diagnostics=if(schedule$full)'full' else 'summary',max.solves=250L,numerical.policy=f$policy)
 elapsed<-proc.time()[['elapsed']]-start
 record(list(event='returned',entry=entry,solves=r$diagnostics$solves,complete=r$complete))
 saveRDS(r,file.path(folder,'result.rds'));stopifnot(r$complete)
 h<-lapply(r$diagnostics$solver_history,function(s)lapply(s[c('number','attempt','iterations','accepted','solver_status','objective')],unlist))
 # dgraphs adjacency storage is checked against its actual constructor below.
 write(list(complete=r$complete,initial_edges=edge.matrix(r$initial_graph),edges=edge.matrix(r$final_graph),scales=unname(r$scales),affinity=unname(r$affinity),history=h),file.path(folder,'result.json'))
 write(list(fixture=schedule$cases[[k]]$name,rep=rep,total=elapsed,native_bridge=native.seconds,graph_conversion=graph.seconds,wrapper_other=elapsed-native.seconds-graph.seconds,solves=r$diagnostics$solves),file.path(folder,'timing.json'))
 if(schedule$full){con<-file(file.path(folder,'trace.jsonl'),'w');for(e in r$diagnostics$trace)writeLines(ian.trace.json(e),con);close(con)}
 rm(r);entry<-entry+1L
}
close(account);writeLines(capture.output(sessionInfo()),file.path(out,'session.txt'))
