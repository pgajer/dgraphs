args<-commandArgs(TRUE);stopifnot(length(args)==3L)
# Build metadata and elapsed timings are the only excluded diagnostic values.
clean<-function(x) {
 if(!is.list(x))return(x)
 n<-names(x)
 if(!is.null(n)) x<-x[!n %in% c("seconds","source_identity","configuration_identity","trace_format")]
 lapply(x,clean)
}
files<-sort(basename(list.files(args[1],pattern="[.]rds$",full.names=TRUE)));files<-setdiff(files,"ledger.rds")
checks<-setNames(lapply(files,function(f){a<-readRDS(file.path(args[1],f));b<-readRDS(file.path(args[2],f));identical(clean(a),clean(b))}),files)
saveRDS(checks,args[3]);print(checks);stopifnot(all(unlist(checks)))
