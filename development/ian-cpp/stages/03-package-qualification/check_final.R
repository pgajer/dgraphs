args<-commandArgs(TRUE);stopifnot(length(args)==2L);root<-args[1];runtime<-args[2]
base<-file.path(root,'numerical-v2',runtime);old<-file.path(root,'numerical-v1',sub('-v2$','',runtime));out<-file.path(root,runtime,'result-checks-v2');dir.create(out)
.libPaths(c(file.path(root,runtime,'library'),.libPaths()));library(dgraphs)
source(file.path(dirname(sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE))),'../01-numerical-policy/trace_json.R'))
clean<-function(x){if(!is.list(x))return(x);n<-names(x);if(!is.null(n))x<-x[!n%in%c('seconds','source_identity','configuration_identity','trace_format','requested_max_solves')];z<-lapply(x,clean);attributes(z)<-attributes(x);z}
prototype<-readRDS('/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage01-policy/supplement-v1/R-strict-nonuniform_curve/child/result.rds')$diagnostics$solver_history[[1]]$settings
build<-jsonlite::fromJSON(file.path(root,runtime,'backend-v2/build-record.json'),simplifyVector=FALSE)
files<-list.files(base,pattern='[.]rds$',recursive=TRUE,full.names=TRUE);files<-files[basename(files)!='ledger.rds'];checks<-list();attempts<-0L;entries<-0L;retries<-0L
for(path in files) {
 r<-readRDS(path);if(is.null(r$diagnostics))next
 relative<-substring(path,nchar(base)+2L);checks[[relative]]<-identical(clean(r),clean(readRDS(file.path(old,relative))));entries<-entries+1L
 stopifnot(identical(r$backend$source_identity,build$core_source_identity),r$diagnostics$solves==length(r$diagnostics$solver_history));attempts<-attempts+r$diagnostics$solves
 for(e in r$diagnostics$solver_history) {
  expected<-prototype;tol<-if(is.null(e$solver_tolerance))1e-9 else e$solver_tolerance;for(k in c('tol_feas','tol_gap_abs','tol_gap_rel'))expected[[k]]<-tol
  stopifnot(length(e$settings)==41L,identical(e$settings,expected));retries<-retries+as.integer(!is.null(e$attempt)&&e$attempt==1)
 }
}
# Read-only export of the earlier full duplicate trace; no repeat engine call.
duplicate<-readRDS(file.path(old,'interface/child/duplicates_full.rds'));writeLines(vapply(duplicate$diagnostics$trace,ian.trace.json,''),file.path(out,'strict-duplicates.jsonl'))
dll<-dyn.load(file.path(root,runtime,'library/dgraphs/ian/native/dgraphs_ian.so'),local=TRUE)
registration<-getDLLRegisteredRoutines(dll)[['.Call']];symbol<-getNativeSymbolInfo('dgraphs_ian_run',dll)
stopifnot(length(registration)==1L,registration[['dgraphs_ian_run']]$numParameters==8L,inherits(symbol,'CallRoutine'),!dll[['dynamicLookup']])
stopifnot(entries==6L,all(unlist(checks)),! 'create.ian.graph'%in%getNamespaceExports('dgraphs'))
result<-list(runtime=runtime,initial_package_comparisons=checks,engine_entries=entries,attempts=attempts,settings_snapshots_checked=attempts,retries=retries,registration=list(name=symbol$name,numParameters=symbol$numParameters,class=class(symbol),dynamicLookup=dll[['dynamicLookup']]),passed=TRUE)
saveRDS(result,file.path(out,'summary.rds'));jsonlite::write_json(result,file.path(out,'summary.json'),auto_unbox=TRUE,pretty=TRUE);print(result)
