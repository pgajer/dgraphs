a <- commandArgs(TRUE)
.libPaths(c(a[1], .libPaths())); library(dgraphs)
stopifnot(normalizePath(find.package('dgraphs')) == normalizePath(file.path(a[1], 'dgraphs')))
source(file.path(dirname(sub('^--file=', '', grep('^--file=', commandArgs(), value=TRUE))), '../01-numerical-policy/trace_json.R'))
f <- jsonlite::fromJSON(a[2], simplifyVector=FALSE)
mat <- function(x) do.call(rbind, lapply(x, unlist))
out <- a[4]; dir.create(out, recursive=TRUE)
r <- dgraphs:::create.ian.graph(mat(f$features), distances=mat(f$distances),
    specimen.ids=unlist(f$ids), diagnostics='full', backend=a[3],
    max.solves=1500L, numerical.policy=f$numerical_policy,
    preserve.connectivity=isTRUE(f$preserve_connectivity))
saveRDS(r, file.path(out, 'result.rds'))
con <- file(file.path(out, 'trace.jsonl'), 'w')
for (e in r$diagnostics$trace) writeLines(ian.trace.json(e), con)
close(con)
jsonlite::write_json(list(complete=r$complete, solves=r$diagnostics$solves, error=r$error), file.path(out,'status.json'), auto_unbox=TRUE, digits=NA)
stopifnot(r$complete, inherits(r$initial_graph,'dgraph'), inherits(r$final_graph,'dgraph'))
if (isTRUE(f$preserve_connectivity)) {
    d <- r$diagnostics$connectivity
    stopifnot(d$index.base == 1L, d$iteration.base == 1L,
              sum(d$history$bridge.skips) == sum(d$protected.edges$encounters),
              all(d$history$removed <= d$history$allowance),
              all(d$protected.edges$from.id == r$mapping$profile_ids[d$protected.edges$from]),
              all(d$protected.edges$to.id == r$mapping$profile_ids[d$protected.edges$to]))
}
writeLines(capture.output(sessionInfo()), file.path(out, 'session.txt'))
cat('R complete',r$diagnostics$solves,'attempts\n')
