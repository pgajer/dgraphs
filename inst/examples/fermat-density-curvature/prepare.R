source('common.R');dir.create('results',showWarnings=FALSE)
models<-expand.grid(shape=c('paraboloid','saddle'),a=config$curvature);models<-rbind(models,data.frame(shape='swiss_roll',a=NA_real_));models$id<-paste0(models$shape,ifelse(is.na(models$a),'',paste0('_a',models$a)))
for(j in seq_len(nrow(models))) {
 model<-models[j,];id<-model$id;dir.create(file.path('results',id),showWarnings=FALSE)
 anchor<-sample_surface(model$shape,model$a,config$anchors,config$seed+j)
 set.seed(config$seed+100+j);all<-t(combn(config$anchors,2));ij<-all[sample.int(nrow(all),config$calibration+config$evaluation),,drop=FALSE]
 rad<-if(model$shape=='swiss_roll')NULL else sqrt(rowSums(anchor$uv^2))
 if(is.null(rad)) {
  q<-anchor$uv;lower<-c(arc(1.5*pi),0);upper<-c(arc(4.5*pi),20)
  normalized<-sweep(sweep(q,2,lower,'-'),2,upper-lower,'/');clearance<-apply(pmin(normalized,1-normalized),1,min)
  near<-clearance<.075;inside<-clearance>.175
 } else {near<-rad>.85;inside<-rad<.65}
 strata<-ifelse(near[ij[,1]]|near[ij[,2]],'boundary',ifelse(inside[ij[,1]]&inside[ij[,2]],'interior','middle'))
 d<-list(model=model,anchor=anchor,pairs=ij,cal=seq_len(config$calibration),test=config$calibration+seq_len(config$evaluation),strata=strata)
 saveRDS(d,file.path('results',id,'design.rds'))
 for(rep in config$repetitions) {
  background<-sample_surface(model$shape,model$a,max(config$n)-config$anchors,config$seed+1000*j+rep)
  saveRDS(list(X=rbind(anchor$X,background$X),uv=rbind(anchor$uv,background$uv),rep=rep),file.path('results',id,paste0('sample_',rep,'.rds')))
 }
}
saveRDS(config,'results/config.rds');write.csv(models,'results/models.csv',row.names=FALSE)
jsonlite::write_json(list(config=config,created=format(Sys.time(),tz='America/New_York',usetz=TRUE),packages=lapply(c('dgraphs','igraph'),function(p)list(name=p,version=as.character(packageVersion(p)))),sampler='dgraphs::sample.synthetic.geometry with synthetic.sampling.quadform.lab(mode="area")',fixed_endpoints=64,conditional_replicates=5),'provenance.json',pretty=TRUE,auto_unbox=TRUE)
cat('Prepared 7 surfaces, 35 nested sample pools and 1500 fixed pairs per surface.\n')
