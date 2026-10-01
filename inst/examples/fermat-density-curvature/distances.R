source('common.R');workers<-as.integer(commandArgs(TRUE)[1]);models<-read.csv('results/models.csv');tasks<-expand.grid(model=seq_len(nrow(models)),rep=config$repetitions,n=config$n)
work<-function(task){
 id<-models$id[tasks$model[task]];rep<-tasks$rep[task];n<-tasks$n[task];root<-file.path('results',id);file<-file.path(root,sprintf('distances_r%d_n%d.rds',rep,n));if(file.exists(file))return(TRUE)
 s<-readRDS(file.path(root,paste0('sample_',rep,'.rds')));X<-s$X[seq_len(n),];d<-readRDS(file.path(root,'design.rds'));stopifnot(identical(unname(X[1:config$anchors,]),unname(d$anchor$X)))
 out<-list();ij<-d$pairs
 for(p in config$powers){
  start<-proc.time()[3];D<-if(p==1)as.matrix(dist(d$anchor$X)) else dgraphs::fermat.distances(points=X,p=p,backend='implicit',sources=seq_len(config$anchors),targets=seq_len(config$anchors),rooted=FALSE)
  stopifnot(all(is.finite(D)),max(abs(D-t(D)))<1e-8,max(abs(diag(D)))<1e-12)
  out[[paste0('p',p)]]<-list(family='complete',p=p,k=NA_integer_,policy='none',distance=D[ij],seconds=unname(proc.time()[3]-start),components=1L,largest=n,anchor_matrix=D)
 }
 for(policy in c(as.character(config$knn),'adaptive')){
  k<-if(policy=='adaptive')ceiling(2*log(n)) else as.integer(policy);start<-proc.time()[3];graph<-dgraphs::create.sknn.graph(X,k=k,neighbor.method='exact',connect.components=FALSE)
  el<-dgraphs::graph.edges(graph);ig<-igraph::graph_from_data_frame(el[,1:2],directed=FALSE,vertices=data.frame(name=seq_len(n)))
  cc<-igraph::components(ig);D<-igraph::distances(ig,v=1:config$anchors,to=1:config$anchors,weights=el$length)
  out[[paste0('knn_',policy)]]<-list(family='euclidean_knn',p=1,k=k,policy=policy,distance=D[ij],seconds=unname(proc.time()[3]-start),components=cc$no,largest=max(cc$csize),anchor_matrix=D)
 }
 saveRDS(list(id=id,rep=rep,n=n,results=out),file);cat(id,'rep',rep,'n',n,'complete\n');flush.console();TRUE
}
ans<-parallel::mclapply(seq_len(nrow(tasks)),work,mc.cores=workers,mc.preschedule=FALSE);stopifnot(all(vapply(ans,isTRUE,FALSE)));cat('DISTANCE TASKS COMPLETE\n')
