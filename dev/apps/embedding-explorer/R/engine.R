`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

surface_presets <- list(flat = c(0, 0, 0), bowl = c(1.2, 0, 1.2),
  saddle = c(1.2, 0, -1.2), steep_bowl = c(8, 0, 8),
  anisotropic_bowl = c(8, 0, .5), anisotropic_saddle = c(8, 0, -2),
  custom = c(.8, 0, -.8))
surface_labels <- c('Flat square / disk' = 'flat', 'Bowl' = 'bowl',
  'Saddle' = 'saddle', 'Steep bowl' = 'steep_bowl',
  'Anisotropic bowl' = 'anisotropic_bowl', 'Anisotropic saddle' = 'anisotropic_saddle',
  'Custom quadratic form' = 'custom')
method_labels <- c('PCA · ambient baseline' = 'pca',
  'Isomap · classical graph MDS' = 'isomap', 'Metric graph MDS' = 'mds',
  'Weighted GRIP' = 'grip', 'UMAP' = 'umap')

# Full optimizer diagnostics remain in the RDS bundle; keep UI/JSON readable.
compact_metadata <- function(x) {
  if(is.atomic(x) && length(x)>50) return(list(stored_in='Full experiment RDS',
    type=class(x)[1],dimensions=dim(x),length=length(x)))
  if(is.list(x)) {
    if(length(x)>100) return(list(stored_in='Full experiment RDS',type='list',length=length(x)))
    return(lapply(x,compact_metadata))
  }
  x
}

scalar_number <- function(x, label, lo, hi, whole = FALSE) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < lo || x > hi ||
      (whole && x != floor(x))) stop(label, ' must be ', if (whole) 'an integer ',
        'between ', lo, ' and ', hi, '.', call. = FALSE)
  x
}
default_spec <- function() list(surface = 'saddle', coefficients = c(1.2, 0, -1.2),
  domain = 'square', extent = 1, sampling = 'uniform', n = 300L,
  seed = 4101L, noise = 0, gap = .2)
lift_quad <- function(uv, co) cbind(uv, co[1]*uv[,1]^2 + 2*co[2]*uv[,1]*uv[,2] + co[3]*uv[,2]^2)

triangulate_uv <- function(uv, gap = NULL) {
  tri <- geometry::delaunayn(uv, options = 'QJ')
  # Exclude zero-area faces and faces spanning the intentionally empty strip.
  a <- uv[tri[,2],,drop=FALSE] - uv[tri[,1],,drop=FALSE]
  b <- uv[tri[,3],,drop=FALSE] - uv[tri[,1],,drop=FALSE]
  keep <- abs(a[,1]*b[,2]-a[,2]*b[,1]) > 1e-12
  if (!is.null(gap)) keep <- keep & !(apply(matrix(uv[tri,1], ncol=3),1,min) < -gap &
    apply(matrix(uv[tri,1], ncol=3),1,max) > gap)
  unname(tri[keep,,drop=FALSE])
}
reference_mesh <- function(spec) {
  s <- seq(-spec$extent, spec$extent, length.out=33)
  uv <- as.matrix(expand.grid(s,s))
  if (spec$domain == 'disk') {
    uv <- uv[rowSums(uv^2) < spec$extent^2,,drop=FALSE]
    theta <- seq(0,2*pi,length.out=97)[-97]
    uv <- rbind(uv, spec$extent*cbind(cos(theta),sin(theta)))
  }
  list(coords=lift_quad(uv,spec$coefficients), triangles=triangulate_uv(uv))
}
make_experiment <- function(spec = default_spec()) {
  stopifnot(spec$surface %in% names(surface_presets), spec$domain %in% c('square','disk'),
    spec$sampling %in% c('uniform','area','grid','center','gap'))
  n <- as.integer(scalar_number(spec$n,'Samples',30,1200,TRUE))
  scalar_number(spec$seed,'Sampling seed',0,.Machine$integer.max,TRUE)
  scalar_number(spec$extent,'Extent',.1,5)
  scalar_number(spec$noise,'Noise',0,2)
  scalar_number(spec$gap,'Gap width',.01,.8)
  if (length(spec$coefficients)!=3 || any(!is.finite(spec$coefficients)) ||
      any(abs(spec$coefficients)>20)) stop('Three finite coefficients in [-20,20] are required.')
  set.seed(spec$seed)
  e <- spec$extent
  candidate <- function(m) {
    if (spec$domain=='disk') {
      r <- sqrt(runif(m))*e; theta <- runif(m,0,2*pi)
      cbind(r*cos(theta),r*sin(theta))
    } else matrix(runif(2*m,-e,e),ncol=2)
  }
  if (spec$sampling=='grid') {
    side <- ceiling(sqrt(n * if (spec$domain=='disk') 4/pi else 1))
    repeat {
      uv <- as.matrix(expand.grid(seq(-e,e,length.out=side),seq(-e,e,length.out=side)))
      if (spec$domain=='disk') uv <- uv[rowSums(uv^2)<=e^2,,drop=FALSE]
      if (nrow(uv)>=n) break
      side <- side+1L
    }
    # Systematic thinning spreads the requested exact count over the full grid.
    uv <- uv[unique(round(seq(1,nrow(uv),length.out=n))),,drop=FALSE]
  } else if (spec$sampling %in% c('area','gap','center')) {
    uv <- matrix(numeric(),0,2)
    co <- spec$coefficients
    bound <- sqrt(1 + (2*e*(abs(co[1])+abs(co[2])))^2 + (2*e*(abs(co[2])+abs(co[3])))^2)
    while(nrow(uv)<n) {
      x <- candidate(max(1000,n*3))
      keep <- if(spec$sampling=='gap') abs(x[,1])>spec$gap*e else if(spec$sampling=='center')
        runif(nrow(x)) < exp(-rowSums(x^2)/(2*(.32*e)^2)) else {
          du <- 2*co[1]*x[,1]+2*co[2]*x[,2]; dv <- 2*co[2]*x[,1]+2*co[3]*x[,2]
          runif(nrow(x)) < sqrt(1+du^2+dv^2)/bound
        }
      uv <- rbind(uv,x[keep,,drop=FALSE])
    }
    uv <- uv[seq_len(n),,drop=FALSE]
  } else uv <- candidate(n)
  truth <- lift_quad(uv,spec$coefficients)
  observed <- truth + matrix(rnorm(n*3,sd=spec$noise),ncol=3)
  cloud <- list(spec=spec, ids=sprintf('sample-%04d',seq_len(n)), uv=uv,
    truth=truth, observed=observed,
    triangles=triangulate_uv(uv,if(spec$sampling=='gap') spec$gap*e else NULL),
    reference=reference_mesh(spec), provenance=list(source='Generated in Geometry Lab'))
  cloud$id <- digest::digest(list(spec,cloud$ids,truth,observed),algo='sha256')
  list(schema='geometry-lab/1',cloud=cloud,fits=list())
}

make_neighbor_graph <- function(X, k) {
  n <- nrow(X); k <- as.integer(scalar_number(k,'Graph k',2,n-2,TRUE))
  D <- as.matrix(dist(X))
  nn <- t(vapply(seq_len(n),function(i) { o<-order(D[i,],seq_len(n)); o[o!=i][seq_len(k)] },integer(k)))
  edges <- cbind(rep(seq_len(n),each=k),as.vector(t(nn)))
  edges <- unique(cbind(pmin(edges[,1],edges[,2]),pmax(edges[,1],edges[,2])))
  weights <- D[edges]
  if(any(weights<=0)) stop('Duplicate observed points create zero-length edges. Change sampling or noise.')
  g <- igraph::make_empty_graph(n,directed=FALSE)
  g <- igraph::add_edges(g,as.vector(t(edges)),attr=list(weight=weights))
  list(edges=edges,weights=weights,components=igraph::components(g)$no,k=k,
    indices=cbind(seq_len(n),nn), distances=matrix(D[cbind(rep(seq_len(n),each=k+1),
      as.vector(t(cbind(seq_len(n),nn))))],nrow=n,byrow=TRUE))
}
as_igraph <- function(graph,n) igraph::add_edges(igraph::make_empty_graph(n,directed=FALSE),
  as.vector(t(graph$edges)),attr=list(weight=graph$weights))
graph_distances <- function(graph,n) {
  if(graph$components!=1) stop('The neighbor graph has ',graph$components,
    ' components. Increase k or change sampling; this method needs a connected graph.')
  d <- igraph::distances(as_igraph(graph,n),weights=graph$weights)
  (d+t(d))/2
}
pad3 <- function(X) { X<-as.matrix(X); if(ncol(X)<3) X<-cbind(X,matrix(0,nrow(X),3-ncol(X))); unname(X[,1:3,drop=FALSE]) }
align_coords <- function(Z,X,mode='similarity') {
  if(mode=='raw') return(list(coords=Z,scale=1))
  z <- scale(Z,scale=FALSE); x <- scale(X,scale=FALSE)
  sv <- svd(crossprod(z,x)); rotation <- sv$u %*% t(sv$v)
  s <- if(mode=='similarity' && sum(z^2)>0) sum(sv$d)/sum(z^2) else 1
  list(coords=sweep(s*z%*%rotation,2,colMeans(X),'+'),scale=s)
}
rank_distances <- function(D) t(vapply(seq_len(nrow(D)),function(i) {
  o<-order(D[i,],seq_len(nrow(D)));o<-o[o!=i];r<-integer(nrow(D));r[o]<-seq_along(o);r
},integer(nrow(D))))
score_fit <- function(coords,cloud,graph,q=10L) {
  n <- nrow(coords); q<-as.integer(scalar_number(q,'Evaluation q',1,floor((n-1)/2),TRUE))
  d<-as.matrix(dist(coords)); target<-as.matrix(dist(cloud$observed)); upper<-upper.tri(d)
  scale_dist <- if(sum(d[upper]^2)>0) sum(d[upper]*target[upper])/sum(d[upper]^2) else 0
  rel <- function(x,y) if(sum(y^2)>0) sqrt(sum((x-y)^2)/sum(y^2)) else NA_real_
  aligned<-align_coords(coords,cloud$truth)$coords
  source<-rank_distances(target);dest<-rank_distances(d)
  intrusion<-dest>0 & dest<=q & source>q; extrusion<-source>0 & source<=q & dest>q
  f<-2/(n*q*(2*n-3*q-1))
  list(correspondence_nrmse=sqrt(sum((aligned-cloud$truth)^2)/sum(scale(cloud$truth,scale=FALSE)^2)),
    chord_nrmse=rel(scale_dist*d[upper],target[upper]),
    edge_nrmse=if(!is.null(graph)) rel(scale_dist*d[graph$edges],graph$weights) else NA_real_,
    trustworthiness=1-f*sum(source[intrusion]-q),continuity=1-f*sum(dest[extrusion]-q),
    neighbor_recall=sum(source>0 & source<=q & dest>0 & dest<=q)/(n*q),
    distance_scale=scale_dist,q=q)
}

default_fit_spec <- function() list(method='isomap',k=10L,seed=5101L,init='spectral',
  epochs=300L,min_dist=.1,spread=1,learning_rate=1,repulsion=1,negative_samples=5L,
  mds_init='classical',mds_starts=1L,iterations=150L,tolerance=1e-7,
  rounds=100L,final_rounds=240L,placement='barycenter',final_mode='fr',
  refine=FALSE,kk_iterations=60L,kk_scale='profiled',stiffness='uniform')

run_fit <- function(cloud,spec,app_root,python='') {
  scalar_number(spec$seed,'Layout seed',0,.Machine$integer.max,TRUE)
  stopifnot(spec$method %in% unname(method_labels))
  set.seed(spec$seed); start<-proc.time()[['elapsed']]
  graph<-make_neighbor_graph(cloud$observed,spec$k);n<-nrow(cloud$observed)
  warnings<-character();metadata<-list();initial<-NULL
  Z<-withCallingHandlers({
    if(spec$method=='pca') pad3(prcomp(cloud$observed,center=TRUE,scale.=FALSE)$x)
    else if(spec$method=='isomap') {
      d<-graph_distances(graph,n);pad3(cmdscale(as.dist(d),k=3))
    } else if(spec$method=='mds') {
      graph_distances(graph,n)
      fit<-grip::metric.mds(edges=graph$edges,n=n,edge_weights=graph$weights,dim=3,
        init=spec$mds_init,n_init=as.integer(spec$mds_starts),max_iter=as.integer(spec$iterations),
        eps=spec$tolerance,seed=as.integer(spec$seed))
      metadata<-fit$metadata
      if(metadata$termination %in% c('backend_error','rejected_increase')) stop('Metric MDS terminated: ',metadata$termination)
      fit$coords
    } else if(spec$method=='grip') {
      graph_distances(graph,n)
      grip::grip(edges=graph$edges,n=n,edge_weights=graph$weights,dim=3,metric='edge_length',
        rounds=as.integer(spec$rounds),final_rounds=as.integer(spec$final_rounds),
        placement=spec$placement,final_mode=spec$final_mode,seed=as.integer(spec$seed),disconnected='error')
    } else {
      if(!nzchar(python) || !file.exists(python)) stop('Set GEOMETRY_LAB_PYTHON to a Python executable with umap-learn installed; see README.')
      if(spec$min_dist>spec$spread) stop('UMAP min_dist must not exceed spread.')
      if(spec$init=='pca') initial<-pad3(prcomp(cloud$observed)$x)
      if(spec$init=='graph_mds') initial<-pad3(cmdscale(as.dist(graph_distances(graph,n)),k=3))
      jobdir<-tempfile('geometry-umap-');dir.create(jobdir);on.exit(unlink(jobdir,recursive=TRUE),add=TRUE)
      request<-file.path(jobdir,'request.json');result<-file.path(jobdir,'result.json')
      jsonlite::write_json(list(x=cloud$observed,indices=graph$indices-1L,distances=graph$distances,
        spec=spec,initial=initial),request,auto_unbox=TRUE,digits=NA,null='null')
      log<-file.path(jobdir,'python.log')
      status<-system2(python,c(shQuote(file.path(app_root,'scripts/umap_fit.py')),shQuote(request),shQuote(result)),
        stdout=log,stderr=log,timeout=240)
      if(status!=0 || !file.exists(result)) stop('UMAP failed: ',paste(tail(readLines(log,warn=FALSE),8),collapse='\n'))
      fit<-jsonlite::fromJSON(result);metadata<-fit$metadata;warnings<-c(warnings,fit$warnings)
      initial<-fit$initial;fit$coords
    }
  },warning=function(w) { warnings<<-c(warnings,conditionMessage(w));invokeRestart('muffleWarning') })
  if(!is.matrix(Z) || !identical(dim(Z),c(n,3L)) || any(!is.finite(Z))) stop('Method did not return finite n × 3 coordinates.')
  if(graph$components>1) warnings<-c(warnings,paste(graph$components,'graph components; their relative placement is not constrained by edges.'))
  versions<-vapply(c('grip','igraph','ivue'),function(p) as.character(utils::packageVersion(p)),'')
  fit<-list(id=paste0('fit-',substr(digest::digest(list(cloud$id,spec,Sys.time())),1,12)),
    cloud_id=cloud$id,label=names(method_labels)[match(spec$method,method_labels)],
    coords=unname(Z),graph=graph,spec=spec,initial=initial,metadata=metadata,
    warnings=unique(warnings),seconds=proc.time()[['elapsed']]-start,
    provenance=list(source='New fit',time=format(Sys.time(),tz='UTC',usetz=TRUE),R=R.version.string,
      packages=as.list(versions),backend=if(spec$method=='umap') python else 'R'))
  fit$label<-paste0(fit$label,' · k ',spec$k,' · seed ',spec$seed,
    if(spec$method=='umap') paste0(' · ',spec$init,' · min_dist ',spec$min_dist) else '',
    if(spec$method=='mds') paste0(' · ',spec$mds_init,' · ',spec$iterations,' iterations') else '')
  fit$scores<-score_fit(fit$coords,cloud,graph)
  fits<-list(fit)
  if(isTRUE(spec$refine)) {
    # A refinement failure must not discard the completed parent fit.
    refined<-tryCatch({
      start<-proc.time()[['elapsed']]
      z<-grip::edge.kk(coords=fit$coords,edges=graph$edges,n=n,edge_weights=graph$weights,dim=3,
        scale_mode=spec$kk_scale,stiffness_method=spec$stiffness,max_iter=as.integer(spec$kk_iterations),
        seed=as.integer(spec$seed),return_trace=TRUE)
      r<-fit;r$id<-paste0(fit$id,'-kk');r$label<-paste(fit$label,'+ edge-KK')
      r$coords<-z$coords;r$metadata<-z$metadata;r$trace<-z$trace;r$parent<-fit$id
      r$seconds<-proc.time()[['elapsed']]-start;r$scores<-score_fit(r$coords,cloud,graph);r
    },error=function(e) list(error=conditionMessage(e)))
    if(is.null(refined$error)) fits[[2]]<-refined else fits[[1]]$warnings<-c(fits[[1]]$warnings,paste('Refinement failed:',refined$error))
  }
  fits
}

validate_bundle <- function(bundle) {
  if(!is.list(bundle) || !identical(bundle$schema,'geometry-lab/1')) stop('Unsupported experiment bundle schema.')
  c<-bundle$cloud;n<-length(c$ids)
  if(n<30 || n>1200 || anyNA(c$ids) || anyDuplicated(c$ids)) stop('Bundle needs 30–1200 unique sample IDs.')
  matrix_ok<-function(x,rows,cols) is.matrix(x)&&is.numeric(x)&&identical(dim(x),c(as.integer(rows),as.integer(cols)))&&all(is.finite(x))
  if(!matrix_ok(c$truth,n,3)||!matrix_ok(c$observed,n,3)||!matrix_ok(c$uv,n,2)) stop('Invalid cloud coordinates.')
  indices_ok<-function(x,cols,limit) is.matrix(x)&&ncol(x)==cols&&is.numeric(x)&&all(is.finite(x))&&all(x==floor(x)&x>=1&x<=limit)
  if(!indices_ok(c$triangles,3,n)) stop('Invalid sample mesh.')
  if(!matrix_ok(c$reference$coords,nrow(c$reference$coords),3)||
    !indices_ok(c$reference$triangles,3,nrow(c$reference$coords))) stop('Invalid reference surface.')
  if(length(c$id)!=1||!is.character(c$id)||!nzchar(c$id)) stop('Missing cloud identity.')
  if(!is.list(bundle$fits)||length(bundle$fits)>40) stop('At most 40 fits may be imported.')
  for(f in bundle$fits) {
    if(!identical(f$cloud_id,c$id)||!matrix_ok(f$coords,n,3)) stop('Fit/cloud identity or coordinate mismatch.')
    if(length(f$id)!=1 || !is.character(f$id) || !nzchar(f$id) || length(f$label)!=1) stop('Invalid fit identity.')
    g<-f$graph
    if(!is.null(g) && (!indices_ok(g$edges,2,n)||length(g$weights)!=nrow(g$edges)||
      any(!is.finite(g$weights)|g$weights<=0))) stop('Invalid fit graph.')
  }
  if(anyDuplicated(vapply(bundle$fits,`[[`,'','id'))) stop('Duplicate fit IDs.')
  bundle
}

study_root_default <- function() path.expand('~/.codex/private/geosmooth/quadform-geodesics/best-of-six-embedding-20260911/main')
read_study <- function(path) {
  path<-normalizePath(path,mustWork=TRUE)
  if(basename(path)=='review') path<-file.path(dirname(path),'main')
  if(!file.exists(file.path(path,'outputs/layouts.csv')) && file.exists(file.path(path,'main/outputs/layouts.csv'))) path<-file.path(path,'main')
  table<-utils::read.csv(file.path(path,'outputs/layouts.csv'),stringsAsFactors=FALSE)
  required<-c('cloud_id','graph_id','surface','domain','n','cloud_seed','k','family','layout_seed','parameter','name','status')
  if(!all(required%in%names(table))) stop('This folder does not have the expected saved-study layout table.')
  table$row_id<-seq_len(nrow(table));list(root=path,table=table)
}
safe_asset <- function(root,dir,id,suffix='.rds') {
  if(length(id)!=1||!grepl('^[A-Za-z0-9_.-]+$',id)||id%in%c('.','..')) stop('Invalid asset identifier.')
  file.path(root,dir,paste0(id,suffix))
}
load_study_fit <- function(study,row_id) {
  row<-study$table[match(row_id,study$table$row_id),,drop=FALSE]
  if(nrow(row)!=1||is.na(row$row_id)) stop('Select one saved fit.')
  x<-readRDS(safe_asset(study$root,'clouds',row$cloud_id))
  spec<-default_spec();spec$surface<-x$surface;spec$coefficients<-c(x$A[1,1],x$A[1,2],x$A[2,2])
  spec$domain<-x$domain_name;spec$n<-x$n;spec$seed<-x$cloud_seed
  cloud<-list(spec=spec,ids=sprintf('%s-%04d',row$cloud_id,seq_len(x$n)),uv=x$uv,
    truth=x$X,observed=x$X,triangles=triangulate_uv(x$uv),reference=reference_mesh(spec),
    provenance=list(source='Saved best-of-six study',root=study$root,cloud=row$cloud_id))
  cloud$id<-digest::digest(list(cloud$ids,x$X),algo='sha256')
  fitdir<-safe_asset(study$root,'fits',row$graph_id,suffix='')
  file<-safe_asset(fitdir,'',row$name)
  f<-readRDS(file)
  if(is.null(f$coords)) stop('This historical attempt has no coordinates (status: ',row$status,').')
  g<-readRDS(file.path(fitdir,'graph.rds'));g$k<-row$k
  g<-g[c('edges','weights','components','k','indices','knn_distances')]
  fit<-list(id=paste(row$graph_id,row$name,sep='/'),cloud_id=cloud$id,
    label=paste(gsub('_',' ',row$family),'· k',row$k,'·',row$parameter,'· seed',row$layout_seed),
    coords=f$coords,graph=g,spec=as.list(row),metadata=f$metadata,
    initial=f$initial,warnings=f$warnings,seconds=f$call_seconds,
    original_scores=f$scores,provenance=list(source='Saved study; coordinates unchanged',file=file,status=row$status,
      md5=unname(tools::md5sum(file))))
  fit$scores<-score_fit(fit$coords,cloud,g)
  validate_bundle(list(schema='geometry-lab/1',cloud=cloud,fits=list(fit)))
}
