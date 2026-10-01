# Shared, reproducible scientific example for the dgraphs and grip vignettes.
# No sampler is implemented here: all observations come from dgraphs samplers.
fermat.surface.sample <- function(shape = c('paraboloid', 'saddle', 'helix'),
                                  n = 150L, seed = 4101L) {
  shape <- match.arg(shape)
  if (shape == 'helix') {
    geometry <- dgraphs::synthetic.helix(pitch = .2, t.range = c(0, 4*pi))
    sampling <- dgraphs::synthetic.sampling.uniform.interval(0, 4*pi)
  } else {
    A <- diag(c(1, if (shape == 'paraboloid') 1 else -1))
    geometry <- dgraphs::synthetic.quadform(2L, 3L, forms = list(A))
    sampling <- dgraphs::synthetic.sampling.quadform.lab('disk', extent = 1,
                                                       mode = 'area')
  }
  s <- dgraphs::sample.synthetic.geometry(geometry, sampling, n, seed = seed)
  s$shape <- shape; s$seed <- seed
  s
}

# Numerical references concern sampled endpoint pairs, not an all-pairs truth.
fermat.surface.reference <- function(sample, n.pairs = 1000L) {
  X <- sample$predictors; n <- nrow(X)
  set.seed(sample$seed + 700L)
  pairs <- t(utils::combn(n, 2L))
  pairs <- pairs[sample.int(nrow(pairs), min(n.pairs, nrow(pairs))), , drop=FALSE]
  if (sample$shape == 'helix') {
    d <- abs(sample$latent[pairs[,1],1] - sample$latent[pairs[,2],1])*sqrt(1+.2^2)
    return(list(pairs=pairs, distances=d, status=rep('analytic',length(d)),
                check.distances=d, check.index=seq_along(d), method='helix arc length'))
  }
  A <- sample$geometry.spec$parameters$forms[[1L]]
  domain <- list(kind='ball',center=c(0,0),radius=1)
  # Six searches per pair, default 64 rounds per search; retain failed statuses.
  solved <- lapply(seq_len(nrow(pairs)),function(j)
    dgraphs:::quadform_geodesics(A, sample$latent[pairs[j,1],],
      sample$latent[pairs[j,2],], domain, method='best_of_six',
      control=list(seed=sample$seed*10000+j)))
  sm <- do.call(rbind,lapply(solved,`[[`,'summary')); sm$pair <- seq_len(nrow(pairs))
  check.index <- if(sample$shape=='paraboloid') seq_len(nrow(pairs)) else integer()
  qc <- if(length(check.index)) dgraphs:::quadform_geodesics(A,
    sample$latent[pairs[,1],,drop=FALSE],sample$latent[pairs[,2],,drop=FALSE],
    domain,method='paraboloid_clairaut') else NULL
  list(pairs=pairs,distances=sm$length,status=sm$status,method='best_of_six',
       check.distances=if(is.null(qc))numeric() else qc$summary$length,
       check.index=check.index,summary=sm,check.summary=qc$summary,
       check.method=if(length(check.index))'paraboloid_clairaut' else 'none')
}

fermat.surface.score <- function(estimate, reference, rescale=TRUE) {
  ok <- is.finite(estimate) & is.finite(reference) & reference>0
  a <- if (rescale) sum(estimate[ok]*reference[ok])/sum(estimate[ok]^2) else 1
  c(n=sum(ok),scale=a,nrmse=sqrt(sum((a*estimate[ok]-reference[ok])^2)/
    sum(reference[ok]^2)),spearman=stats::cor(estimate[ok],reference[ok],method='spearman'))
}

fermat.surface.fit <- function(D, init) {
  warnings <- character()
  fit <- withCallingHandlers(grip::metric.mds(distance.matrix=D, dim=3L,
    backend='sgd', approximation='full', init=init, seed=3051L,
    max.iter=300L, diagnostics=FALSE, pair.weights='uniform',
    sgd.control=list(final.rate=1e-5,checkpoint.every=10L)),
    warning=function(w){warnings <<- c(warnings,conditionMessage(w));invokeRestart('muffleWarning')})
  list(coords=fit$coords,metadata=fit$metadata,warnings=warnings)
}

fermat.surface.experiment <- function(sample, reference, powers=1:4, ks=3:10) {
  X <- sample$predictors; n <- nrow(X)
  set.seed(3051); init <- matrix(rnorm(n*3),n,3)
  records <- list(); layouts <- list(); matrices <- list(); graphs <- list()
  rr <- 0L
  for(p in powers) {
    full <- dgraphs::fermat.distances(points=X,p=p,backend='implicit',
                                     rooted=FALSE,return.graph=TRUE)
    D <- full$distances
    matrices[[as.character(p)]] <- D; graphs[[as.character(p)]] <- full$graph
    for(k in c(0L,ks)) {
      if(k==0L) {G <- D; ids <- seq_len(n); components <- 1L; edges <- full$graph}
      else {
        edges <- dgraphs::create.fermat.sknn.graph(X,k=k,p=p,rooted=FALSE)
        adj <- dgraphs::graph.adjacency(edges)
        # igraph is used solely for graph shortest paths/component bookkeeping.
        el <- dgraphs::graph.edges(edges)
        ig <- igraph::graph_from_data_frame(el[,1:2],directed=FALSE,
                                            vertices=data.frame(name=seq_len(n)))
        igraph::E(ig)$weight <- el$length
        membership <- igraph::components(ig)
        ids <- which(membership$membership==which.max(membership$csize))
        components <- membership$no
        G <- igraph::distances(ig,v=ids,to=ids,weights=igraph::E(ig)$weight)
      }
      fit <- fermat.surface.fit(G,init[ids,,drop=FALSE])
      E <- as.matrix(stats::dist(fit$coords)); lower <- lower.tri(G)
      # Same subset is used for the dense baseline comparison after disconnection.
      q <- reference$pairs; included <- q[,1] %in% ids & q[,2] %in% ids &
        is.finite(reference$distances) & reference$status %in% c('candidate','analytic')
      qlocal <- cbind(match(q[included,1],ids),match(q[included,2],ids))
      truth <- reference$distances[included]
      estimation <- fermat.surface.score(G[qlocal],truth)
      embedding <- fermat.surface.score(E[lower],G[lower],rescale=FALSE)
      restriction <- fermat.surface.score(G[lower],D[ids,ids][lower],rescale=FALSE)
      geometry <- fermat.surface.score(E[qlocal],truth)
      rr <- rr+1L; key <- paste0('p',p,'_k',k)
      records[[rr]] <- data.frame(shape=sample$shape,seed=sample$seed,p=p,k=k,
        n=n,retained=length(ids),components=components,
        reference_pairs=unname(estimation['n']),distance_scale=unname(estimation['scale']),
        distance_nrmse=unname(estimation['nrmse']),distance_spearman=unname(estimation['spearman']),
        restriction_nrmse=unname(restriction['nrmse']),embedding_nrmse=unname(embedding['nrmse']),
        embedded_geodesic_nrmse=unname(geometry['nrmse']),
        warnings=paste(unique(fit$warnings),collapse='; '))
      layouts[[key]] <- list(coords=fit$coords,ids=ids,graph=edges,metadata=fit$metadata)
    }
  }
  # Exact intrinsic baseline on the helix: its correct metric realization is a line.
  baseline <- NULL
  if(sample$shape=='helix') {
    D <- abs(outer(sample$latent[,1],sample$latent[,1],'-'))*sqrt(1+.2^2)
    baseline <- fermat.surface.fit(D,init)
    baseline$target <- D
  }
  list(sample=sample,reference=reference,records=do.call(rbind,records),
       layouts=layouts,matrices=matrices,graphs=graphs,geodesic_baseline=baseline)
}

# Orthogonal similarity alignment is only for display; scores use original fits.
fermat.surface.align <- function(Y,X) {
  yc <- scale(Y,scale=FALSE); xc <- scale(X,scale=FALSE)
  sv <- svd(crossprod(yc,xc)); R <- sv$u %*% t(sv$v)
  a <- sum(sv$d)/sum(yc^2)
  sweep(a*yc%*%R,2,colMeans(X),'+')
}

fermat.surface.overlay <- function(result,p=2L,k=0L,max.edges=1800L) {
  z <- result$layouts[[paste0('p',p,'_k',k)]]; ids<-z$ids
  X <- result$sample$predictors[ids,,drop=FALSE]
  Y <- fermat.surface.align(z$coords,X)
  fig <- plotly::plot_ly()
  if(result$sample$shape!='helix') {
    v <- seq(-1,1,length.out=45); uv<-as.matrix(expand.grid(v,v))
    co <- if(result$sample$shape=='paraboloid') c(1,0,1) else c(1,0,-1)
    xyz <- dgraphs::embed.quadform.surface(uv,co)
    zz <- matrix(xyz[,3],length(v)); zz[outer(v^2,v^2,'+')>1] <- NA
    fig <- plotly::add_surface(fig,x=v,y=v,z=zz,opacity=.2,showscale=FALSE,
      colorscale=list(c(0,'#999999'),c(1,'#999999')),name='Reference surface',inherit=FALSE)
  } else {
    tt <- seq(0,4*pi,length.out=400)
    fig <- plotly::add_trace(fig,x=cos(tt),y=sin(tt),z=.2*tt,type='scatter3d',
      mode='lines',line=list(color='#999999',width=5),name='Reference helix',inherit=FALSE)
  }
  edges <- dgraphs::graph.edges(z$graph)
  a<-match(edges[[1]],ids);b<-match(edges[[2]],ids)
  good<-which(!is.na(a)&!is.na(b)); total.edges<-length(good)
  if(length(good)>max.edges)good<-good[unique(round(seq(1,length(good),length.out=max.edges)))]
  e<-as.vector(rbind(a[good],b[good],NA_integer_))
  fig<-plotly::add_trace(fig,x=Y[e,1],y=Y[e,2],z=Y[e,3],type='scatter3d',
    mode='lines',line=list(color='rgba(50,100,160,0.25)',width=1),
    name=paste0('Path edges (',length(good),'/',total.edges,')'),inherit=FALSE)
  fig<-plotly::add_trace(fig,x=X[,1],y=X[,2],z=X[,3],type='scatter3d',mode='markers',
    marker=list(size=2,color='#777777'),name='Observed surface samples',inherit=FALSE)
  fig<-plotly::add_trace(fig,x=Y[,1],y=Y[,2],z=Y[,3],type='scatter3d',mode='markers',
    marker=list(size=3,color=result$sample$latent[ids,1],colorscale='Viridis',showscale=FALSE),
    text=paste('Sample',ids),name='MDS embedding',inherit=FALSE)
  plotly::layout(fig,title=paste(result$sample$shape,'p =',p,if(k==0)'complete targets' else paste('k =',k)),
    scene=list(aspectmode='data'),legend=list(orientation='h'),margin=list(t=45,b=20,l=0,r=0))
}
