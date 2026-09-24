a <- commandArgs(TRUE);root <- a[1];backend <- a[2];out <- a[3];dir.create(out,recursive=TRUE)
.libPaths(c(file.path(root,'library'),.libPaths()));library(dgraphs)
source(file.path(dirname(sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE))),'../01-numerical-policy/trace_json.R'))
x <- rbind(c(0,0),c(1,0),c(2,0),c(0,0));f <- get('.ian.adapter',asNamespace('dgraphs'));policy <- 'IAN evaluated-LP retry-power 0.1';ledger <- list();lines <- character()
save <- function(){saveRDS(ledger,file.path(out,'ledger.rds'));jsonlite::write_json(ledger,file.path(out,'ledger.json'),auto_unbox=TRUE,pretty=TRUE);writeLines(lines,file.path(out,'trace.jsonl'))}
call <- function(name,detail='full',fault='none',input=x,limit=1500L){
 ledger[[name]] <<- list(state='reserved');save()
 r <- f(input,NULL,NULL,c('p1','p2','p3','p4')[seq_len(nrow(input))],NULL,detail,backend,limit,fault,policy,TRUE)
 saveRDS(r,file.path(out,paste0(name,'.rds')))
 traces <- if(detail=='full') r$diagnostics$trace else r$diagnostics$solver_history
 lines <<- c(lines,vapply(traces,ian.trace.json,''));ledger[[name]] <<- list(state='returned',solves=r$diagnostics$solves,complete=r$complete,error=r$error);save();r
}
r <- call('full');s <- call('summary',detail='summary')
clean <- function(x){if(!is.list(x))return(x);if(!is.null(names(x)))x <- x[!names(x)%in%c('seconds','trace')];attrs<-attributes(x);x<-lapply(x,clean);attributes(x)<-attrs;x}
stopifnot(r$complete,s$complete,identical(clean(r),clean(s)),identical(r$mapping$member_to_profile,c(1L,2L,3L,1L)),nrow(r$diagnostics$connectivity$protected.edges)==2L)
b <- call('after-graph',fault='after_graph');stopifnot(!b$complete,is.null(b$final_graph),!is.null(b$last_valid_graph),nrow(b$diagnostics$connectivity$protected.edges)==2L,nzchar(b$diagnostics$connectivity$stop.reason))
z <- call('budget',limit=1L);stopifnot(!z$complete,is.null(z$final_graph),z$diagnostics$solves==1L)
i <- call('interrupt',fault='interrupt_after_initial');stopifnot(!i$complete,i$error$kind=='cancelled',i$diagnostics$solves==0L,!is.null(i$initial_graph))
old <- '/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage01-policy/build-v1/dgraphs_ian.so'
e <- tryCatch(dgraphs:::create.ian.graph(x,backend=old,preserve.connectivity=TRUE),error=identity)
stopifnot(inherits(e,'error'),grepl('needs rebuilding',conditionMessage(e)))
# New native module still accepts the previous eight-argument ABI.
dll <- dyn.load(backend,local=TRUE);symbol <- getNativeSymbolInfo('dgraphs_ian_run',dll)$address
ledger$legacy <- list(state='reserved');save()
legacy <- .Call(symbol,x,as.matrix(stats::dist(x)),as.character(1:4),character(),TRUE,1500L,'none',policy)
saveRDS(legacy,file.path(out,'legacy.rds'));lines <- c(lines,vapply(legacy$diagnostics$trace,ian.trace.json,''));ledger$legacy <- list(state='returned',complete=legacy$complete,solves=legacy$diagnostics$solves);save();stopifnot(legacy$complete,is.null(legacy$backend$pruning_policy))
jsonlite::write_json(list(passed=TRUE,calls=length(ledger),solves=sum(vapply(ledger,function(x)x$solves,0)),old.module.refused=TRUE),file.path(out,'checks.json'),auto_unbox=TRUE,pretty=TRUE)
