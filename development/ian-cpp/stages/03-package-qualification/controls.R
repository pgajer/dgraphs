args<-commandArgs(TRUE);stopifnot(length(args)==3)
.libPaths(c(args[1],.libPaths()));library(dgraphs)
source(file.path(dirname(sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE))),'../01-numerical-policy/trace_json.R'))
mode<-args[2];out<-args[3];dir.create(out,recursive=TRUE);f<-get('create.ian.graph',asNamespace('dgraphs'));internal<-get('.ian.adapter',asNamespace('dgraphs'))
x<-rbind(c(0,0),c(1,0),c(2,0),c(0,0));policy<-'IAN evaluated-LP retry-power 0.1'
ledger<-list();alltrace<-character()
save<-function(){saveRDS(ledger,file.path(out,'ledger.rds'));jsonlite::write_json(ledger,file.path(out,'ledger.json'),auto_unbox=TRUE,digits=NA);tmp<-file.path(out,'trace.tmp');writeLines(alltrace,tmp);stopifnot(file.rename(tmp,file.path(out,'trace.jsonl')))}
run<-function(name,fault,limit=80L,backend=NULL) {
 ledger[[name]]<<-list(status='started',max_solves=limit);save()
 r<-internal(x,NULL,NULL,NULL,NULL,'full',backend,limit,fault,policy)
 saveRDS(r,file.path(out,paste0(name,'.rds')))
 lines<-vapply(r$diagnostics$trace,ian.trace.json,'');writeLines(lines,file.path(out,paste0(name,'.jsonl')));alltrace<<-c(alltrace,lines)
 ledger[[name]]<<-list(status='returned',solves=r$diagnostics$solves,complete=r$complete,error=r$error);save()
 stopifnot(r$diagnostics$solves==length(r$diagnostics$solver_history),r$diagnostics$solves<=limit)
 r
}
if(mode=='unavailable') {
 stopifnot(!'create.ian.graph'%in%getNamespaceExports('dgraphs'))
 e<-tryCatch(f(x),error=identity);stopifnot(inherits(e,'error'),grepl('unavailable',conditionMessage(e)))
 for(p in list('unknown',NA_character_,character(),c('IAN evaluated-LP 1.0','bad'))) {
  e<-tryCatch(f(x,numerical.policy=p),error=identity);stopifnot(inherits(e,'error'),grepl('Unsupported numerical.policy',conditionMessage(e)))
 }
 saveRDS(list(passed=TRUE,engine_calls=0),file.path(out,'checks.rds'));cat('Unexported and unavailable/invalid-policy checks passed; zero core entries.\n')
} else if(mode=='candidate') {
 a<-run('invalid','invalid_solver');stopifnot(!a$complete,is.null(a$final_graph),a$diagnostics$solves==1L,!a$diagnostics$solver_history[[1]]$accepted)
 b<-run('budget','none',1L);stopifnot(!b$complete,is.null(b$final_graph),b$diagnostics$solves==1L,grepl('adapter_solve_budget',b$error$message))
 c<-run('interrupt','interrupt_after_initial');stopifnot(!c$complete,is.null(c$final_graph),c$error$kind=='cancelled',c$diagnostics$solves==0L)
 cat('Three explicit-policy refusal controls passed.\n')
} else {
 r<-run('relocation','none',backend=mode);stopifnot(r$complete,inherits(r$initial_graph,'dgraph'),inherits(r$final_graph,'dgraph'));cat('Relocated module complete.\n')
}
