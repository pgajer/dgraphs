a<-commandArgs(TRUE);.libPaths(c(a[1],.libPaths()));library(dgraphs)
source(file.path(dirname(sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE))),'../01-numerical-policy/trace_json.R'))
n<-jsonlite::fromJSON(file.path(a[2],'result.json'),simplifyVector=FALSE);r<-readRDS(file.path(a[3],'result.rds'));mat<-function(x)do.call(rbind,lapply(x,unlist))
stopifnot(identical(r$complete,n$complete))
if(r$complete){
 affinity<-if(!is.null(n$affinity_binary)){con<-file(file.path(a[2],n$affinity_binary),'rb');z<-matrix(readBin(con,'double',n=as.double(length(n$scales))^2,size=8,endian='little'),length(n$scales),byrow=TRUE);close(con);z}else mat(n$affinity)
 stopifnot(identical(unname(r$scales),unlist(n$scales)),identical(unname(r$affinity),unname(affinity)))
 check.graph<-function(g,e){adj<-graph.adjacency(g);wanted<-rep(list(integer()),length(adj));for(edge in e){edge<-as.integer(unlist(edge))+1L;wanted[[edge[1]]]<-c(wanted[[edge[1]]],edge[2]);wanted[[edge[2]]]<-c(wanted[[edge[2]]],edge[1])};stopifnot(identical(lapply(adj,function(x)sort(as.integer(x))),lapply(wanted,sort)))}
 check.graph(r$final_graph,n$graph$edges)
 stopifnot(identical(r$mapping$profile_ids,unlist(n$mapping$profile_ids)),identical(r$mapping$member_to_profile,as.integer(unlist(n$mapping$member_to_profile))+1L))
 if(!is.null(n$pruning)){
  d<-r$diagnostics$connectivity;stopifnot(d$stop.reason==n$pruning$stop_reason,nrow(d$history)==length(n$pruning$history),nrow(d$protected.edges)==length(n$pruning$protected_bridges))
  for(i in seq_len(nrow(d$history)))for(k in names(n$pruning$history[[i]])){value<-n$pruning$history[[i]][[k]];if(k=='iteration')value<-value+1L;stopifnot(identical(unname(d$history[i,gsub('_','.',k,fixed=TRUE)]),value))}
  for(i in seq_len(nrow(d$protected.edges))){b<-n$pruning$protected_bridges[[i]];v<-d$protected.edges[i,];ee<-as.integer(unlist(b$edge))+1L;stopifnot(identical(c(v$from,v$to),ee),identical(c(v$from.id,v$to.id),r$mapping$profile_ids[ee]),v$trigger==b$trigger+1L,v$first.iteration==b$first_iteration+1L,v$last.iteration==b$last_iteration+1L,v$encounters==b$encounters,identical(v$statistic,b$statistic),identical(v$threshold,b$threshold),identical(v$margin,b$margin))}
 }
}
# For summary R mode, compare the projected native solve history exactly.
if(!length(r$diagnostics$trace)){
 expected<-vapply(r$diagnostics$solver_history,function(e){e$seconds<-NULL;ian.trace.json(e)},'')
 source<-file(file.path(a[2],'trace.jsonl'),'r');actual<-character()
 dense<-c('A_data','A_indices','A_indptr','A_shape','b','c','upper','active','scales','dual','backend_rhs','backend_primal','backend_dual','backend_slack','seconds')
 repeat{line<-readLines(source,n=1,warn=FALSE);if(!length(line))break;e<-jsonlite::fromJSON(line,simplifyVector=FALSE);if(e$event=='solve')actual<-c(actual,ian.trace.json(e[!names(e)%in%dense]))};close(source)
 stopifnot(identical(unname(expected),unname(actual)))
}
jsonlite::write_json(list(passed=TRUE,complete=r$complete,exact.scales.affinity.graph.mapping=TRUE,diagnostics=TRUE,engine.calls=0),a[4],auto_unbox=TRUE,pretty=TRUE)
