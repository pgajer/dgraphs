a <- commandArgs(TRUE); root <- a[1]; out <- a[2]; dir.create(out,recursive=TRUE)
.libPaths(c(file.path(root,'library'),.libPaths()));library(dgraphs)
source(file.path(dirname(sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE))),'../01-numerical-policy/trace_json.R'))
mat <- function(x) do.call(rbind,lapply(x,unlist))
rows <- list()
for (case in jsonlite::fromJSON(file.path(root,'fixtures.json'),simplifyVector=FALSE)$cases) {
 if (!case$variant) next
 folder <- file.path(root,'runs',case$name)
 r <- readRDS(file.path(folder,'R/child/result.rds'))
 n <- jsonlite::fromJSON(file.path(folder,'native/child/result.json'),simplifyVector=FALSE)
 stopifnot(identical(unname(r$scales),unlist(n$scales)),identical(unname(r$affinity),unname(mat(n$affinity))))
 g <- graph.adjacency(r$final_graph)
 for (i in seq_along(g)) {
  wanted <- integer()
  for (e in n$graph$edges) {e <- unlist(e)+1L;if(i %in% e)wanted <- c(wanted,e[e!=i])}
  stopifnot(identical(sort(as.integer(g[[i]])),sort(as.integer(wanted))))
 }
 d <- r$diagnostics$connectivity
 stopifnot(nrow(d$protected.edges)==length(n$pruning$protected_bridges),identical(d$stop.reason,n$pruning$stop_reason))
 for (k in seq_len(nrow(d$protected.edges))) {
  b <- n$pruning$protected_bridges[[k]];row <- d$protected.edges[k,]
  stopifnot(identical(c(row$from,row$to),as.integer(unlist(b$edge))+1L),row$trigger==b$trigger+1L,
    row$first.iteration==b$first_iteration+1L,row$last.iteration==b$last_iteration+1L,
    row$encounters==b$encounters,identical(row$statistic,b$statistic),identical(row$threshold,b$threshold),identical(row$margin,b$margin))
 }
 h <- r$diagnostics$solver_history;s <- Filter(function(e)e$event=='solve',r$diagnostics$trace)
 for(k in seq_along(h))stopifnot(identical(h[[k]],s[[k]][names(h[[k]])]))
 stopifnot(identical(unname(vapply(r$diagnostics$trace,ian.trace.json,'')),readLines(file.path(folder,'R/child/trace.jsonl'))))
 rows[[case$name]] <- list(exact.scales.and.affinity=TRUE,graph.and.mapping=TRUE,protection.diagnostics=TRUE,solver.history=length(h))
}
saveRDS(rows,file.path(out,'checks.rds'));jsonlite::write_json(list(passed=TRUE,cases=rows,engine.calls=0),file.path(out,'summary.json'),auto_unbox=TRUE,pretty=TRUE)
