a<-commandArgs(TRUE);P<-a[1];backend<-a[2];out<-a[3];dir.create(out,recursive=TRUE);.libPaths(c(file.path(P,'library-v2'),.libPaths()));library(dgraphs)
source(file.path(dirname(sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE))),'../01-numerical-policy/trace_json.R'))
x<-matrix(rep(c(0,1,2),167),501,1);f<-get('.ian.adapter',asNamespace('dgraphs'));policy<-'IAN evaluated-LP retry-power 0.1';ledger<-list();lines<-character()
save<-function(){jsonlite::write_json(ledger,file.path(out,'ledger.json'),auto_unbox=TRUE,pretty=TRUE);writeLines(lines,file.path(out,'trace.jsonl'))}
call<-function(name,detail='full',fault='none',limit=1500L){ledger[[name]]<<-list(state='reserved');save();r<-f(x,NULL,NULL,NULL,NULL,detail,backend,limit,fault,policy,TRUE);saveRDS(r,file.path(out,paste0(name,'.rds')));tt<-if(detail=='full')r$diagnostics$trace else r$diagnostics$solver_history;lines<<-c(lines,vapply(tt,ian.trace.json,''));ledger[[name]]<<-list(state='returned',complete=r$complete,solves=r$diagnostics$solves,error=r$error);save();r}
r<-call('full');s<-call('summary',detail='summary')
clean<-function(x){if(!is.list(x))return(x);if(!is.null(names(x)))x<-x[!names(x)%in%c('seconds','trace')];z<-lapply(x,clean);attributes(z)<-attributes(x);z}
stopifnot(r$complete,s$complete,identical(clean(r),clean(s)),identical(r$mapping$member_to_profile,rep(1:3,167)))
b<-call('budget',limit=1L);stopifnot(!b$complete,is.null(b$final_graph),b$diagnostics$solves==1L)
i<-call('interrupt',fault='interrupt_after_initial');stopifnot(!i$complete,i$error$kind=='cancelled',i$diagnostics$solves==0L,!is.null(i$initial_graph))
g<-call('after-graph',fault='after_graph');stopifnot(!g$complete,is.null(g$final_graph),!is.null(g$last_valid_graph),nrow(g$diagnostics$connectivity$protected.edges)==2L)
jsonlite::write_json(list(passed=TRUE,engine.entries=length(ledger),solves=sum(vapply(ledger,function(x)x$solves,0)),specimen.rows=501,unique.profiles=3),file.path(out,'checks.json'),auto_unbox=TRUE,pretty=TRUE)
