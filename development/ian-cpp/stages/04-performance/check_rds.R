# Read-only exact comparisons of saved binary R outputs; no engine calls.
args<-commandArgs(TRUE);stopifnot(length(args)==2L)
root<-normalizePath(args[1],mustWork=TRUE);out<-args[2];stopifnot(!dir.exists(out));dir.create(out,recursive=TRUE)
script<-dirname(sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE)))
source(file.path(script,'../01-numerical-policy/trace_json.R'))
strip.seconds<-function(x){
 if(!is.list(x))return(x)
 if(!is.null(names(x)))x<-x[names(x)!='seconds']
 attrs<-attributes(x);x<-lapply(x,strip.seconds);attributes(x)<-attrs;x
}
summary.object<-function(x){x$diagnostics$trace<-NULL;strip.seconds(x)}
checks<-list();count<-0L;attempts<-0L;qualified.attempts<-0L
for(name in c('pressmat_hellinger_subset','helix_500')){
 qdir<-file.path(root,paste0('qual-R-',name),'child','0');q<-readRDS(file.path(qdir,'result.rds'))
 stopifnot(q$complete,length(q$diagnostics$trace)>0L)
 # The original full trace uses explicit 17-significant-digit encoding.
 encoded<-vapply(q$diagnostics$trace,ian.trace.json,'')
 stopifnot(identical(unname(encoded),readLines(file.path(qdir,'trace.jsonl'),warn=FALSE)))
 # All summary-history fields must equal their exact full-trace counterparts.
 solves<-Filter(function(e)identical(e$event,'solve'),q$diagnostics$trace)
 stopifnot(length(solves)==length(q$diagnostics$solver_history))
 for(i in seq_along(solves)){
  h<-q$diagnostics$solver_history[[i]]
  stopifnot(identical(strip.seconds(h),strip.seconds(solves[[i]][names(h)])))
 }
 # Reference objects come from the independently accepted Stage-3 package study.
 stage3<-file.path(dirname(root),'stage03-package')
 bpath<-if(name=='helix_500')file.path(stage3,'numerical-v2/rdevel-v2/candidate-helix_500/child/result.rds') else file.path(stage3,'numerical-v1/rdevel/candidate-pressmat_hellinger_subset/child/result.rds')
 b<-readRDS(bpath)
 stopifnot(identical(strip.seconds(q),strip.seconds(b)))
 qualified.attempts<-qualified.attempts+q$diagnostics$solves
 checks[[paste0('qualification-',name)]]<-list(reference=bpath,exact.complete.R.object=TRUE,exact.full.trace=TRUE,complete.history.fields=TRUE,solves=q$diagnostics$solves)
 for(block in 0:2)for(rep in 0:3){
  index<-if(name=='helix_500')rep+4L else rep
  path<-file.path(root,paste0('block-',block,'-R'),'child',index,'result.rds');r<-readRDS(path)
  stopifnot(identical(summary.object(r),summary.object(q)))
  count<-count+1L;attempts<-attempts+r$diagnostics$solves
  checks[[paste(block,name,rep,sep='-')]]<-list(path=path,exact.R.object.except.full.trace.and.seconds=TRUE,solves=r$diagnostics$solves)
 }
}
stopifnot(count==24L,attempts==1080L,qualified.attempts==90L)
result<-list(passed=TRUE,qualified.objects=2L,persistent.objects=count,all.objects=26L,qualified.attempts=qualified.attempts,persistent.attempts=attempts,total.attempts=attempts+qualified.attempts,exclusions=c('elapsed seconds','full trace omitted only when comparing summary to full diagnostics'),checks=checks)
saveRDS(result,file.path(out,'checks.rds'));jsonlite::write_json(result,file.path(out,'summary.json'),auto_unbox=TRUE,pretty=TRUE)
writeLines(capture.output(sessionInfo()),file.path(out,'session.txt'));cat('26 exact R objects and 1170 histories checked; zero engine calls.\n')
