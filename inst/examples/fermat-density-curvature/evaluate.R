source('common.R');models<-read.csv('results/models.csv');rows<-list();refs<-list();rr<-0L
for(id in models$id){
 root<-file.path('results',id);d<-readRDS(file.path(root,'design.rds'));files<-list.files(file.path(root,'references'),pattern='rds$',full.names=TRUE)
 stopifnot(length(files)==60L)
 ref<-unlist(lapply(files,readRDS),recursive=FALSE);ref<-ref[order(vapply(ref,`[[`,0,'pair'))]
 stopifnot(identical(as.integer(vapply(ref,`[[`,0,'pair')),1:1500))
 truth<-vapply(ref,`[[`,0,'length');status<-vapply(ref,`[[`,'','status');truth[!status %in% c('candidate','analytic')]<-NA_real_
 chord<-as.matrix(dist(d$anchor$X))[d$pairs];clairaut<-vapply(ref,`[[`,0,'clairaut')
 upper<-if(id=='swiss_roll')truth else vapply(seq_len(nrow(d$pairs)),function(j){
  u<-d$anchor$uv[d$pairs[j,1],];v<-d$anchor$uv[d$pairs[j,2],]-u;A<-d$anchor$A
  integrate(function(t)sqrt(sum(v*v)+4*(sum(v*(A%*%u))+t*sum(v*(A%*%v)))^2),0,1,rel.tol=1e-10)$value
 },0)
 refs[[id]]<-data.frame(id=id,pair=1:1500,split=ifelse(1:1500 %in% d$cal,'calibration','evaluation'),stratum=d$strata,reference=truth,status=status,chord=chord,straight_lift=upper,clairaut=clairaut,seconds=vapply(ref,`[[`,0,'seconds'))
 saveRDS(list(design=d,truth=truth,reference=ref),file.path(root,'reference.rds'))
 for(rep in config$repetitions)for(n in config$n){
  bundle<-readRDS(file.path(root,sprintf('distances_r%d_n%d.rds',rep,n)))
  for(key in names(bundle$results)){
   q<-bundle$results[[key]]
   for(stratum in c('all','interior','middle','boundary')){
    test<-d$test;if(stratum!='all')test<-test[d$strata[test]==stratum]
    sc<-score(q$distance,truth,d$cal,test)
    matched<-test[is.finite(q$distance[test])]
    ambient<-score(chord,truth,d$cal,matched)
    cc<-score(q$distance,clairaut,d$cal,test);ca<-score(chord,clairaut,d$cal,matched)
    rr<-rr+1L;rows[[rr]]<-data.frame(id=id,shape=d$model$shape,a=d$model$a,rep=rep,n=n,method=key,family=q$family,p=q$p,k=q$k,policy=q$policy,stratum=stratum,requested_test=length(test),as.list(sc),ambient_matched_nrmse=unname(ambient['nrmse']),difference_from_ambient=unname(sc['nrmse']-ambient['nrmse']),clairaut_nrmse=unname(cc['nrmse']),clairaut_ambient_nrmse=unname(ca['nrmse']),components=q$components,largest=q$largest,seconds=q$seconds,area=d$anchor$area,samples_per_area=n/d$anchor$area)
   }
  }
 }
}
metrics<-do.call(rbind,rows);references<-do.call(rbind,refs)
write.csv(metrics,'results/metrics.csv',row.names=FALSE);write.csv(references,'results/references.csv',row.names=FALSE)
main<-metrics[metrics$stratum=='all',]
stopifnot(nrow(main)==7*5*5*12)
jsonlite::write_json(list(completed=format(Sys.time(),tz='America/New_York',usetz=TRUE),distance_conditions=nrow(main),reference_pairs=nrow(references),reference_failures=sum(!is.finite(references$reference)),unreachable_evaluation_pairs=sum(main$requested_test-main$test_pairs),disconnected_conditions=sum(main$components>1)), 'results/completion.json',pretty=TRUE,auto_unbox=TRUE)
cat('Evaluated',nrow(main),'conditions and',nrow(references),'reference pairs.\n')

files<-list.files('results/reference_sensitivity',pattern='rds$',full.names=TRUE)
if(length(files)==150L){
 ss<-lapply(files,function(f){x<-readRDS(f);id<-as.character(x$id);old<-references$reference[references$id==id & references$pair==x$pair];data.frame(id=id,pair=x$pair,original=old,refined=x$length,relative_reduction=(old-x$length)/old,status=x$status,seconds=x$seconds)})
 write.csv(do.call(rbind,ss),'results/reference_sensitivity.csv',row.names=FALSE)
}
