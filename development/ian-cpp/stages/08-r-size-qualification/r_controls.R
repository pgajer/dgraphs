a<-commandArgs(TRUE);P<-a[1];backend<-a[2];out<-a[3];dir.create(out,recursive=TRUE);.libPaths(c(file.path(P,'library-v3'),.libPaths()));library(dgraphs)
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
# The new wrapper must refuse a module without the checked-size entry point.
old.module<-file.path(dirname(P),'connected-pruning/build-v2/dgraphs_ian.so')
e<-tryCatch({dgraphs:::.ian.backend(old.module);NULL},error=function(e)conditionMessage(e))
stopifnot(is.character(e),grepl('checked-size interface',e,fixed=TRUE))
# Old call signatures continue to dispatch through the new implementation.
dll<-dyn.load(backend);d<-as.matrix(dist(x));ids<-as.character(seq_len(nrow(x)))
legacy<-function(name,symbol,connected){ledger[[name]]<<-list(state='reserved');save();args<-list(getNativeSymbolInfo(symbol,dll)$address,x,d,ids,character(),TRUE,1500L,'none',policy);if(connected)args<-c(args,list(TRUE));z<-do.call(.Call,args);saveRDS(z,file.path(out,paste0(name,'.rds')));lines<<-c(lines,vapply(z$diagnostics$trace,ian.trace.json,''));ledger[[name]]<<-list(state='returned',complete=z$complete,solves=z$diagnostics$solves,error=z$error);save();stopifnot(z$complete,identical(z$scales,unname(r$scales)),identical(z$affinity,unname(r$affinity)));z}
z2<-legacy('legacy-v2','dgraphs_ian_run_v2',TRUE)
stopifnot(identical(clean(z2$diagnostics$trace),clean(r$diagnostics$trace)))
z1<-legacy('legacy-v1','dgraphs_ian_run',FALSE)
jsonlite::write_json(list(passed=TRUE,engine.entries=length(ledger),solves=sum(vapply(ledger,function(x)x$solves,0)),specimen.rows=501,unique.profiles=3),file.path(out,'checks.json'),auto_unbox=TRUE,pretty=TRUE)
