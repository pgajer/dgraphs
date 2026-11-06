test_that('max simplex distances preserve scale and same-face chords', {
 X <- rbind(c(1,.2,.4),c(1,.9,.1),c(0,1,0))
 D <- linf.simplex.distances(X)
 expect_equal(D,t(D));expect_equal(diag(D),rep(0,3))
 expect_equal(D[1,2],sqrt(.7^2+.3^2))
 expect_equal(linf.simplex.distances(X*c(3,20,.01)),D)
 expect_equal(linf.simplex.distances(X,sources=c(3,1),targets=c(2,1)),D[c(3,1),c(2,1)])
 expect_equal(linf.simplex.distances(X,pairs=rbind(c(1,3),c(2,1))),D[rbind(c(1,3),c(2,1))])
 expect_equal(linf.simplex.distances(matrix(c(1,0,0,1),2,2))[1,2],2)
 expect_equal(linf.simplex.distances(matrix(c(2,7),2,1)),matrix(0,2,2))
})
test_that('an intermediate face gives the shorter route', {
 X <- rbind(c(1,0,.99),c(0,1,.99))
 z <- linf.simplex.distances(X,pairs=matrix(c(1,2),1,2),return.paths=TRUE)
 expect_equal(z$distances,sqrt(2)*1.01)
 expect_equal(z$paths[[1]]$faces,c(1L,3L,2L))
 P <- z$paths[[1]]$points
 expect_equal(sum(sqrt(rowSums((P[-1,]-P[-nrow(P),])^2))),z$distances)
})
test_that('returned paths realize distances, stay on faces, and obey metric bounds', {
 set.seed(314)
 X <- matrix(runif(80*7),80,7);X[X<.2]<-0
 D <- linf.simplex.distances(X)
 U <- X/apply(X,1,max)
 expect_true(all(D+1e-12>=as.matrix(dist(U))))
 for(k in 1:80)expect_true(all(D<=outer(D[,k],D[k,],'+')+1e-10))
 pairs <- cbind(sample(80,100,TRUE),sample(80,100,TRUE))
 z <- linf.simplex.distances(X,pairs=pairs,return.paths=TRUE)
 expect_equal(z$distances,D[pairs])
 for(k in 1:nrow(pairs)){
  P <- z$paths[[k]]$points
  expect_equal(P[1,],U[pairs[k,1],]);expect_equal(P[nrow(P),],U[pairs[k,2],])
  expect_true(all(P>=-1e-12 & P<=1+1e-12))
  expect_true(all(diff(z$paths[[k]]$times)>=-1e-12))
  expect_equal(apply((P[-1,,drop=FALSE]+P[-nrow(P),,drop=FALSE])/2,1,max),rep(1,nrow(P)-1))
  expect_equal(sum(sqrt(rowSums((P[-1,,drop=FALSE]-P[-nrow(P),,drop=FALSE])^2))),z$distances[k],tolerance=1e-10)
 }
})
test_that('three-feature distances agree with independent constrained path optimization', {
 set.seed(71)
 for(k in 1:25){
  u<-c(1,runif(2));v<-c(runif(1),1,runif(1));X<-rbind(u,v)
  # Route 1 -> 2: one knot on their shared edge.
  f2<-function(t){w<-c(1,1,t);sqrt(sum((u-w)^2))+sqrt(sum((v-w)^2))}
  a<-optimize(f2,c(0,1),tol=1e-12)$objective
  # Route 1 -> 3 -> 2: optimize its two edge knots, independently of unfolding.
  f3<-function(t){w<-c(1,t[1],1);z<-c(t[2],1,1);sqrt(sum((u-w)^2))+sqrt(sum((w-z)^2))+sqrt(sum((z-v)^2))}
  b<-optim(c(.5,.5),f3,method='L-BFGS-B',lower=c(0,0),upper=c(1,1),control=list(factr=1,pgtol=1e-10))$value
  expect_equal(linf.simplex.distances(X)[1,2],min(a,b),tolerance=1e-5)
 }
})
test_that('invalid data and indices fail clearly', {
 expect_error(linf.simplex.distances(matrix(0,2,2)),'positive')
 expect_error(linf.simplex.distances(matrix(c(1,NA),1,2)),'finite')
 expect_error(linf.simplex.distances(matrix(c(1,-1),1,2)),'nonnegative')
 X<-diag(2)
 expect_error(linf.simplex.distances(X,sources=1.5),'indices')
 expect_error(linf.simplex.distances(X,pairs=matrix(c(1,3),1,2)),'indices')
 expect_error(linf.simplex.distances(X,pairs=matrix(c(1,2),1,2),sources=1),'cannot')
})
