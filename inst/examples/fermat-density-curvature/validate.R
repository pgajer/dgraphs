source('common.R');stopifnot(abs(score(1:6,2*(1:6),1:3,4:6)['scale']-2)<1e-12, score(1:6,2*(1:6),1:3,4:6)['nrmse']==0)
models<-read.csv('results/models.csv');checked<-0L;max.increase<-0;explicit.error<-0;radial.deviation<-numeric()
for(id in models$id){
 root<-file.path('results',id);d<-readRDS(file.path(root,'design.rds'));stopifnot(!length(intersect(d$cal,d$test)),!anyDuplicated(apply(d$pairs,1,paste,collapse=':')))
 chord<-as.matrix(dist(d$anchor$X))
 for(rep in config$repetitions){
  previous<-NULL
  for(n in config$n){
   r<-readRDS(file.path(root,sprintf('distances_r%d_n%d.rds',rep,n)))
   stopifnot(max(abs(r$results$p1$anchor_matrix-chord))<1e-12)
   for(p in config$powers){
    D<-r$results[[paste0('p',p)]]$anchor_matrix
    if(!is.null(previous)){increase<-max(D-previous[[paste0('p',p)]]$anchor_matrix);max.increase<-max(max.increase,increase);stopifnot(increase<1e-8)}
   }
   for(q in r$results){
    stopifnot(all(q$anchor_matrix>=0),max(abs(diag(q$anchor_matrix)))<1e-12,identical(unname(q$distance),unname(q$anchor_matrix[d$pairs])))
    if(q$family=='euclidean_knn')stopifnot(all(q$anchor_matrix>=chord-1e-8))
   }
   previous<-r$results;checked<-checked+1L
  }
 }
 s<-readRDS(file.path(root,'sample_1.rds'));X<-s$X[1:150,]
 if(d$model$shape!='swiss_roll'){
  stopifnot(max(abs(s$X[,3]-rowSums((s$uv%*%d$anchor$A)*s$uv)))<1e-12)
  a<-d$model$a;r2<-rowSums(s$uv^2);cdf<-((1+4*a*a*r2)^1.5-1)/((1+4*a*a)^1.5-1)
  radial.deviation<-c(radial.deviation,unname(ks.test(cdf,'punif')$statistic))
 }
 for(p in c(1.25,2,4)){
  exact<-dgraphs::fermat.distances(points=X,p=p,backend='explicit')
  saved<-readRDS(file.path(root,'distances_r1_n150.rds'))$results[[paste0('p',p)]]$anchor_matrix
  e<-max(abs(saved-exact[1:64,1:64]));explicit.error<-max(explicit.error,e);stopifnot(e<1e-8)
 }
}
refs<-read.csv('results/references.csv');finite<-is.finite(refs$reference)
sensitivity<-read.csv('results/reference_sensitivity.csv');stopifnot(nrow(sensitivity)==150L,all(is.finite(sensitivity$refined)),all(sensitivity$status=='candidate'))
stopifnot(all(refs$reference[finite]>=refs$chord[finite]-1e-7))
jsonlite::write_json(list(batches_checked=checked,refinement_pairs=nrow(sensitivity),max_refinement_relative_reduction=max(sensitivity$relative_reduction),area_sampler_radial_cdf_max_deviation=max(radial.deviation),explicit_comparisons=21,max_explicit_difference=explicit.error,max_nested_distance_increase=max.increase,finite_reference_pairs=sum(finite),failed_reference_pairs=sum(!finite),reference_exceeding_straight_lift=sum(refs$reference>refs$straight_lift+1e-6,na.rm=TRUE)), 'validation.json',pretty=TRUE,auto_unbox=TRUE)
cat('Validated nested sampling, held-out pairs, Euclidean identities and explicit Fermat references.\n')
