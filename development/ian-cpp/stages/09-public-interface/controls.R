a<-commandArgs(TRUE);.libPaths(c(a[1],.libPaths()));library(dgraphs)
source(file.path(dirname(sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE))),'../01-numerical-policy/trace_json.R'))
backend<-a[2];out<-a[3];dir.create(out,recursive=TRUE);ledger<-list();lines<-character();checks<-list()
save<-function(){jsonlite::write_json(list(calls=ledger,checks=checks),file.path(out,'ledger.json'),auto_unbox=TRUE,pretty=TRUE);writeLines(lines,file.path(out,'trace.jsonl'))}
check<-function(name,x){checks[[name]]<<-isTRUE(x);save();stopifnot(isTRUE(x))}
x<-rbind(c(0,0),c(1,0),c(2,0),c(0,0));ids<-c('alpha','beta','gamma','delta');participants<-c('p1','p1','p2','p3')
run<-function(name,X=x,D=NULL,detail='full',fault='none',budget=1500L){
 ledger[[name]]<<-list(state='reserved');save()
 r<-if(fault=='none')create.ian.graph(X,distances=D,specimen.ids=if(nrow(X)==4L)ids else NULL,participant.ids=if(nrow(X)==4L)participants else NULL,diagnostics=detail,backend=backend,max.solves=budget) else dgraphs:::.ian.adapter(X,D,ids,participants,NULL,detail,backend,budget,fault,'IAN evaluated-LP retry-power 0.1',TRUE)
 saveRDS(r,file.path(out,paste0(name,'.rds')));events<-if(detail=='full')r$diagnostics$trace else r$diagnostics$solver_history;lines<<-c(lines,vapply(events,ian.trace.json,''));ledger[[name]]<<-list(state='returned',complete=r$complete,solves=r$diagnostics$solves,error=r$error);save();r
}
named.x<-x;rownames(named.x)<-ids
a0<-run('computed',detail='summary');b<-run('supplied',D=unname(as.matrix(dist(x))),detail='summary');c<-run('dist',D=dist(named.x),detail='summary');d<-run('full',D=unname(as.matrix(dist(x))))
clean<-function(x){if(!is.list(x))return(x);if(!is.null(names(x)))x<-x[!names(x)%in%c('seconds','trace','input_mode')];z<-lapply(x,clean);attributes(z)<-attributes(x);z}
check('computed supplied dist full',a0$complete && b$complete && c$complete && d$complete && identical(clean(a0),clean(b)) && identical(clean(b),clean(c)) && identical(clean(c),clean(d)))
check('profile and participant mapping',identical(a0$mapping$member_to_profile,c(1L,2L,3L,1L)) && identical(a0$mapping$participant_ids,participants))
budget<-run('budget',budget=1L);check('budget refusal',!budget$complete && is.null(budget$final_graph) && budget$diagnostics$solves==1L)
n<-run('invalid-solver',fault='invalid_solver');check('numerical refusal',!n$complete && is.null(n$final_graph) && n$error$kind=='numerical')
i<-run('interrupt',fault='interrupt_after_initial');check('event interruption',!i$complete && i$error$kind=='cancelled' && i$diagnostics$solves==0L && !is.null(i$initial_graph))
f<-run('after-graph',fault='after_graph');check('partial graph diagnostics',!f$complete && is.null(f$final_graph) && !is.null(f$last_valid_graph) && nrow(f$diagnostics$connectivity$protected.edges)==2L)
u<-run('all-duplicates',X=matrix(0,3,2));check('all duplicate refusal',!u$complete && u$error$code=='fewer_than_two_unique_profiles' && u$diagnostics$solves==0L)
distances<-unname(as.matrix(dist(x)));distances[4,2]<-distances[2,4]<-1.1
u<-run('inconsistent-duplicate',D=distances);check('duplicate distances refused',!u$complete && u$error$code=='duplicate_distance_inconsistency' && u$diagnostics$solves==0L)
# The installed public help example is the eleventh reserved entry.
ledger[['help-example']]<-list(state='reserved');save();Sys.setenv(DGRAPHS_IAN_BACKEND=backend);e<-new.env(parent=globalenv());example('create.ian.graph',package='dgraphs',local=e,echo=FALSE,ask=FALSE)
r<-e$fit;saveRDS(r,file.path(out,'help-example.rds'));lines<-c(lines,vapply(r$diagnostics$solver_history,ian.trace.json,''));ledger[['help-example']]<-list(state='returned',complete=r$complete,solves=r$diagnostics$solves,error=r$error);save();check('installed help example',r$complete && length(unique(graph.connected.components(r$final_graph)))==1L)
check('public exports',all(c('create.ian.graph','build.ian.backend')%in%getNamespaceExports('dgraphs')))
jsonlite::write_json(list(passed=TRUE,engine_entries=length(ledger),solves=sum(vapply(ledger,function(x)x$solves,0))),file.path(out,'status.json'),auto_unbox=TRUE)
