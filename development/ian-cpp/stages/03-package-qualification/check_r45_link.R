args<-commandArgs(TRUE);stopifnot(length(args)==2L);root<-args[1];runtime<-args[2]
base<-file.path(root,'numerical-v3',runtime);out<-file.path(root,runtime,'result-checks-v3');dir.create(out)
clean<-function(x) {
 if(!is.list(x))return(x)
 n<-names(x);if(!is.null(n))x<-x[!n%in%c('seconds','source_identity','configuration_identity','trace_format','requested_max_solves')]
 z<-lapply(x,clean);attributes(z)<-attributes(x);z
}
old<-'/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/typed-core/evidence/qualification-v1'
checks<-list();for(name in setdiff(list.files(old,pattern='[.]rds$'),'ledger.rds')) {
 a<-readRDS(file.path(old,name));b<-readRDS(file.path(base,'interface/child',name));checks[[name]]<-identical(clean(a),clean(b))
}
prototype<-readRDS('/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage01-policy/supplement-v1/R-strict-nonuniform_curve/child/result.rds')$diagnostics$solver_history[[1]]$settings
objects<-list.files(base,pattern='[.]rds$',recursive=TRUE,full.names=TRUE);objects<-objects[!basename(objects)%in%c('ledger.rds')]
settings_checked<-0L;attempts<-0L;entries<-0L;retries<-0L
for(path in objects) {
 r<-readRDS(path);if(is.null(r$diagnostics))next
 entries<-entries+1L;stopifnot(r$diagnostics$solves==length(r$diagnostics$solver_history));attempts<-attempts+r$diagnostics$solves
 for(e in r$diagnostics$solver_history) {
  expected<-prototype;tol<-if(is.null(e$solver_tolerance))1e-9 else e$solver_tolerance
  for(k in c('tol_feas','tol_gap_abs','tol_gap_rel'))expected[[k]]<-tol
  stopifnot(length(e$settings)==41L,identical(e$settings,expected));settings_checked<-settings_checked+1L
  retries<-retries+as.integer(!is.null(e$attempt)&&e$attempt==1)
 }
}
stopifnot(entries==26L,all(unlist(checks)),attempts==settings_checked)
result<-list(runtime=runtime,interface_baseline_checks=checks,engine_entries=entries,attempts=attempts,settings_snapshots_checked=settings_checked,retries=retries,passed=TRUE)
saveRDS(result,file.path(out,'summary.rds'));jsonlite::write_json(result,file.path(out,'summary.json'),auto_unbox=TRUE,pretty=TRUE);print(result)

.libPaths(c(file.path(root,runtime,'library'),.libPaths()));library(dgraphs)
source(file.path(dirname(sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE))),'../01-numerical-policy/trace_json.R'))
duplicate<-readRDS(file.path(base,'interface/child/duplicates_full.rds'));writeLines(vapply(duplicate$diagnostics$trace,ian.trace.json,''),file.path(out,'strict-duplicates.jsonl'))
dll<-dyn.load(file.path(root,runtime,'library/dgraphs/ian/native/dgraphs_ian.so'),local=TRUE);registration<-getDLLRegisteredRoutines(dll)[['.Call']];symbol<-getNativeSymbolInfo('dgraphs_ian_run',dll)
stopifnot(length(registration)==1L,registration[['dgraphs_ian_run']]$numParameters==8L,inherits(symbol,'CallRoutine'),!dll[['dynamicLookup']],! 'create.ian.graph'%in%getNamespaceExports('dgraphs'))
print(sessionInfo());print(getLoadedDLLs())
