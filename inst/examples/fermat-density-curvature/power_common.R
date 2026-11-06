# Best-power follow-up: reuse the fixed endpoints, nested samples and references.
source('common.R')
power_root <- 'results/power_tuning'
dir.create(file.path(power_root,'cache'),recursive=TRUE,showWarnings=FALSE)
power_models <- subset(read.csv('results/models.csv'),shape!='swiss_roll')
power_workers <- function() {
 a <- commandArgs(TRUE); w <- if(length(a))as.integer(a[1]) else 1L
 stopifnot(length(w)==1L,is.finite(w),w>=1L); w
}
power_key <- function(p) sprintf('%04d',as.integer(round(p*1000)))
power_distances <- function(id,rep,n,p) {
 file <- file.path(power_root,'cache',sprintf('%s_r%d_n%d_p%s.rds',id,rep,n,power_key(p)))
 if(file.exists(file))return(readRDS(file)$distance)
 root <- file.path('results',id); d <- readRDS(file.path(root,'design.rds'))
 s <- readRDS(file.path(root,sprintf('sample_%d.rds',rep)))
 X <- s$X[seq_len(n),,drop=FALSE]
 stopifnot(identical(unname(X[1:64,]),unname(d$anchor$X)))
 old <- readRDS(file.path(root,sprintf('distances_r%d_n%d.rds',rep,n)))$results
 hit <- which(vapply(old,function(z)z$family=='complete' && abs(z$p-p)<1e-10,FALSE))
 start <- proc.time()[3]
 if(length(hit)) { D <- old[[hit[1]]]$anchor_matrix; origin <- 'original distance cache' }
 else { D <- dgraphs::fermat.distances(points=X,p=p,backend='implicit',
           sources=1:64,targets=1:64,rooted=FALSE); origin <- 'new exact implicit search' }
 stopifnot(identical(dim(D),c(64L,64L)),all(is.finite(D)),
           max(abs(D-t(D)))<1e-8,max(abs(diag(D)))<1e-12)
 if(p==1)stopifnot(max(abs(D-as.matrix(dist(d$anchor$X))))<1e-10)
 z <- list(id=id,rep=rep,n=n,p=p,distance=D[d$pairs],anchor_matrix=D,
           origin=origin,seconds=unname(proc.time()[3]-start))
 saveRDS(z,file); z$distance
}
power_cv <- function(est,truth,fold) {
 stopifnot(length(est)==500L,length(truth)==500L,all(is.finite(est)),
           all(is.finite(truth)),all(est>0),all(truth>0))
 do.call(rbind,lapply(1:5,function(f) {
  train <- fold!=f; valid <- fold==f
  scale <- sum(est[train]*truth[train])/sum(est[train]^2)
  data.frame(fold=f,training_pairs=sum(train),validation_pairs=sum(valid),scale=scale,
    sse=sum((scale*est[valid]-truth[valid])^2),reference_ss=sum(truth[valid]^2))
 }))
}
