options(stringsAsFactors=FALSE)
config <- list(version=1L,n=c(150L,300L,600L,1200L,2400L),powers=c(1,1.25,1.5,1.75,2,3,4),repetitions=1:5,anchors=64L,calibration=500L,evaluation=1000L,curvature=c(1,2,4),knn=c(5L,10L,20L,40L),seed=62001L)
arc <- function(t) (t*sqrt(1+t*t)+asinh(t))/2
sample_surface <- function(shape,a,n,seed) {
 if(shape!='swiss_roll') {
  A<-diag(c(a,if(shape=='saddle')-a else a))
  s<-dgraphs::sample.synthetic.geometry(dgraphs::synthetic.quadform(2L,3L,list(A)),dgraphs::synthetic.sampling.quadform.lab('disk',extent=1,mode='area'),n,seed=seed)
  return(list(X=s$predictors,uv=s$latent,A=A,area=pi*((1+4*a*a)^1.5-1)/(6*a*a)))
 }
 # Arc length and height form an isometric rectangle; uniform draws are area uniform.
 set.seed(seed);lo<-1.5*pi;hi<-4.5*pi; ss<-runif(n,arc(lo),arc(hi));h<-runif(n,0,20)
 tt<-vapply(ss,function(s)uniroot(function(t)arc(t)-s,c(lo,hi),tol=1e-12)$root,0)
 list(X=cbind(tt*cos(tt),h,tt*sin(tt)),uv=cbind(ss,h),t=tt,A=NULL,area=(arc(hi)-arc(lo))*20)
}
score <- function(est,truth,cal,test) {
 okcal<-cal[is.finite(est[cal]) & is.finite(truth[cal]) & truth[cal]>0];ok<-test[is.finite(est[test]) & is.finite(truth[test]) & truth[test]>0]
 scale<-if(length(okcal)>0 && sum(est[okcal]^2)>0)sum(est[okcal]*truth[okcal])/sum(est[okcal]^2) else NA_real_
 c(calibration_pairs=length(okcal),test_pairs=length(ok),scale=scale,nrmse=if(length(ok))sqrt(sum((scale*est[ok]-truth[ok])^2)/sum(truth[ok]^2)) else NA_real_,raw_nrmse=if(length(ok))sqrt(sum((est[ok]-truth[ok])^2)/sum(truth[ok]^2)) else NA_real_,spearman=if(length(ok)>2)cor(est[ok],truth[ok],method='spearman') else NA_real_)
}
