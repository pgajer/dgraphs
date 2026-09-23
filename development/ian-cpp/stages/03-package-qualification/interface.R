# Stage-3 copy of the accepted interface schedule; trace.jsonl contains accounting only.
# Run only against an installed package, explicit prepared reference inputs and
# optional backend. This script records every engine call before continuing.
args <- commandArgs(TRUE)
stopifnot(length(args) == 4L)
.libPaths(c(args[1], .libPaths()))
library(dgraphs)
backend <- if (args[2] == "installed") NULL else normalizePath(args[2], mustWork=TRUE)
fixtures <- normalizePath(args[3], mustWork=TRUE)
out <- args[4]
stopifnot(!dir.exists(out))
prior_files <- Sys.glob(file.path(dirname(out), "qualification-*", "ledger.rds"))
prior <- lapply(prior_files, readRDS)
prior_solves <- sum(vapply(prior,function(x)x$total_solves,0L))
prior_calls <- sum(vapply(prior,function(x)length(x$calls),0L))
stopifnot(all(vapply(prior,function(x)all(vapply(x$calls,function(y)identical(y$status,"returned"),TRUE)),TRUE)))
dir.create(out, recursive=TRUE)
f <- get("create.ian.graph", asNamespace("dgraphs"))
internal <- get(".ian.adapter", asNamespace("dgraphs"))
ledger <- list(); checks <- list(); total <- 0L
save <- function() {
 state <- list(calls=ledger, checks=checks,total_solves=total,prior_calls=prior_calls,prior_solves=prior_solves,backend_discovery=if(is.null(backend))"installed default" else backend)
 saveRDS(state,file.path(out,"ledger.rds"));jsonlite::write_json(state,file.path(out,"ledger.json"),auto_unbox=TRUE,digits=NA)
 lines <- character()
 for(nm in names(ledger)) if(identical(ledger[[nm]]$status,"returned")) {
  value <- readRDS(file.path(out,paste0(nm,".rds")))
  for(s in value$diagnostics$solver_history) lines<-c(lines,as.character(jsonlite::toJSON(list(event="solve",case=nm,number=s$number,accepted=s$accepted),auto_unbox=TRUE)))
 }
 temporary<-file.path(out,"trace.tmp");writeLines(lines,temporary);stopifnot(file.rename(temporary,file.path(out,"trace.jsonl")))
}
check <- function(label, okay) { checks[[label]] <<- isTRUE(okay); save(); if(!isTRUE(okay))stop(label) }
run <- function(name, x, d=NULL, ids=NULL, participants=NULL, detail="summary", limit=80L, fault="none") {
 stopifnot(prior_calls+length(ledger)<30L, nrow(x)<=96L,prior_solves+total+limit<=600L)
 ledger[[name]] <<- list(status="started",max_solves=limit,rows=nrow(x));save()
 r <- if(fault=="none") f(x,distances=d,specimen.ids=ids,participant.ids=participants,diagnostics=detail,backend=backend,max.solves=limit) else internal(x,d,ids,participants,NULL,detail,backend,limit,fault)
 saveRDS(r,file.path(out,paste0(name,".rds")))
 count <- r$diagnostics$solves
 total <<- total+count
 ledger[[name]] <<- list(status="returned",solves=count,complete=r$complete,error=r$error,history_count=length(r$diagnostics$solver_history));save()
 check(paste(name,"attempt accounting"),count==length(r$diagnostics$solver_history))
 for(s in r$diagnostics$solver_history) check(paste(name,"settings",s$number),isTRUE(s$settings$settings_layout_verified) && identical(s$settings$input_sparse_dropzeros,FALSE) && s$settings$max_threads==1 && s$settings$max_iter==300 && s$settings$tol_feas==1e-9)
 r
}
close <- function(a,b) identical(dim(a),dim(b)) && length(a)==length(b) && all(abs(a-b)<=1e-7+1e-6*abs(b))
canonical <- function(x) {if(!length(x))return(matrix(integer(),0,2)); x <- matrix(as.integer(x),ncol=2);x[order(x[,1],x[,2]),,drop=FALSE]}
reference_runs <- list()
for(name in c("nonuniform_curve","variable_density_patch","nearby_curved_arms","pressmat_hellinger_subset")) {
 path <- file.path(fixtures,name);ref <- jsonlite::fromJSON(file.path(path,"reference.json"))
 binary <- function(file,n,p) matrix(readBin(file.path(path,file),"double",n=n*p,size=8,endian="little"),n,p,byrow=TRUE)
 x <- binary("features.bin",ref$n,ref$p);d <- binary("distances.bin",ref$n,ref$n)
 r <- run(name,x,d,ref$ids)
 check(paste(name,"complete"),r$complete)
 check(paste(name,"final graph"),identical(canonical(as.matrix(graph.edges(r$final_graph)[,c("from","to")])),canonical(ref$graph$edges+1L)))
 check(paste(name,"initial actual graph"),identical(canonical(as.matrix(graph.edges(r$initial_graph)[,c("from","to")])),canonical(ref$initial_edges+1L)))
 check(paste(name,"mapping"),identical(r$mapping$member_to_profile,as.integer(ref$graph$mapping$member_to_profile+1L)))
 check(paste(name,"scales"),close(unname(r$scales),ref$scales$scales))
 check(paste(name,"affinity"),close(unname(r$affinity),ref$affinity$affinity))
 ge <- graph.edges(r$final_graph);reps <- r$mapping$representatives
 check(paste(name,"metric lengths"),identical(ge$length,d[cbind(reps[ge$from],reps[ge$to])]))
 check(paste(name,"summary bounded"),length(r$diagnostics$trace)==0L && !any(c("A_data","scales","dual") %in% names(r$diagnostics$solver_history[[1]])))
 reference_runs[[name]] <- r
}
check("PreSSMat initial graph retains removed edges",nrow(graph.edges(reference_runs$pressmat_hellinger_subset$initial_graph))>nrow(graph.edges(reference_runs$pressmat_hellinger_subset$final_graph)))
x <- rbind(c(0,0),c(1,0),c(2,0),c(0,0));ids<-c("alpha","beta","gamma","delta");participants<-c("p1","p1","p2","p3")
a<-run("duplicates_computed",x,ids=ids,participants=participants)
b<-run("duplicates_supplied",x,unname(as.matrix(dist(x))),ids,participants)
c<-run("duplicates_full",x,unname(as.matrix(dist(x))),ids,participants,detail="full")
check("duplicate mapping first occurrence",identical(a$mapping$member_to_profile,c(1L,2L,3L,1L)) && identical(a$mapping$representatives,1:3) && identical(a$mapping$participant_ids,participants))
check("computed supplied equality",identical(a$scales,b$scales) && identical(a$affinity,b$affinity) && identical(graph.edges(a$final_graph),graph.edges(b$final_graph)))
check("full trace preserves results",identical(b$scales,c$scales) && identical(b$affinity,c$affinity) && length(c$diagnostics$trace)>0 && any(vapply(c$diagnostics$trace,function(e)identical(e$event,"solve") && !is.null(e$A_data),TRUE)))
refused<-run("numerical_refusal",x,ids=ids,fault="invalid_solver")
check("numerical refusal not final",!refused$complete && is.null(refused$final_graph) && inherits(refused$initial_graph,"dgraph") && refused$error$kind=="numerical" && !refused$diagnostics$solver_history[[1]]$accepted)
limited<-run("solve_budget",x,ids=ids,limit=1L)
check("budget record preserved",!limited$complete && is.null(limited$final_graph) && limited$diagnostics$solves==1 && grepl("adapter_solve_budget",limited$error$message))
after<-run("after_graph_failure",x,ids=ids,fault="after_graph")
check("post graph failure not final",!after$complete && is.null(after$final_graph) && after$diagnostics$graph_converged && inherits(after$last_valid_graph,"dgraph"))
interrupted<-run("signal_interrupt",x,ids=ids,fault="interrupt_after_initial")
check("signal interrupt preserves initial",!interrupted$complete && is.null(interrupted$final_graph) && inherits(interrupted$initial_graph,"dgraph") && interrupted$error$kind=="cancelled" && interrupted$error$code=="R_user_interrupt" && interrupted$diagnostics$solves==0)
all_dup<-run("all_duplicate_refusal",matrix(0,3,2))
check("all duplicates structured refusal",!all_dup$complete && all_dup$error$code=="fewer_than_two_unique_profiles" && all_dup$diagnostics$solves==0)
d <- unname(as.matrix(dist(x)));d[4,2]<-d[2,4]<-1.1
baddup<-run("inconsistent_duplicate_refusal",x,d,ids)
check("duplicate distances refused",!baddup$complete && baddup$error$code=="duplicate_distance_inconsistency" && baddup$diagnostics$solves==0)
check("unexported",!"create.ian.graph"%in%getNamespaceExports("dgraphs"))
cat(length(ledger),"calls;",total,"solver attempts;",length(checks),"checks passed\n")
writeLines(capture.output(str(list(calls=ledger,total_solves=total,checks=checks),max.level=2)),file.path(out,"summary.txt"))
