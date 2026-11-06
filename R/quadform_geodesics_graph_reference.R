# Internal preparation shared by the mesh and graph references. Qhull provides
# topology only; lifted lengths and path search are evaluated in native code.
quadform_geodesics_graph_reference <- function(A, from, to, domain, method,
                                               control, return.paths) {
  if (!is.matrix(A) || !is.numeric(A) || !nrow(A) %in% 2:4 || nrow(A) != ncol(A) ||
      any(!is.finite(A)) || any(A != t(A))) stop("A must be a finite symmetric 2, 3 or 4 dimensional matrix")
  d <- nrow(A)
  backend <- c(polyhedral_mesh="qhull-kirsanov-mesh-v1",delaunay_graph="qhull-boost-delaunay-graph-v1",
    radius_graph="native-boost-radius-graph-v1")[[method]]
  endpoints <- function(x) {
    if (is.numeric(x) && is.null(dim(x)) && length(x) == d) x <- matrix(x, 1L)
    if (!is.matrix(x) || !is.numeric(x) || ncol(x) != d || !nrow(x) || any(!is.finite(x)))
      stop("Endpoints must be finite vectors or matrices matching A")
    unname(x)
  }
  from <- endpoints(from); to <- endpoints(to)
  if (nrow(from) != nrow(to)) stop("from and to must have the same number of rows")
  if (!is.logical(return.paths) || length(return.paths) != 1L || is.na(return.paths)) stop("return.paths must be TRUE or FALSE")
  vec <- function(x) is.numeric(x) && is.null(dim(x)) && length(x) == d && all(is.finite(x))
  if (!is.list(domain) || is.null(names(domain)) || anyDuplicated(names(domain)) ||
      !is.character(domain$kind) || length(domain$kind) != 1L || is.na(domain$kind)) stop("Invalid domain")
  if (domain$kind == "ball") {
    if (!setequal(names(domain), c("kind","center","radius")) || !vec(domain$center) ||
        !is.numeric(domain$radius) || length(domain$radius) != 1L || !is.finite(domain$radius) ||
        domain$radius < 1e-100 || domain$radius > 1e100) stop("Invalid ball domain")
    lo <- domain$center-domain$radius; hi <- domain$center+domain$radius
    inside <- function(x) rowSums((sweep(x,2L,domain$center)/domain$radius)^2) <= 1
  } else if (domain$kind == "box") {
    if (!setequal(names(domain), c("kind","lower","upper")) || !vec(domain$lower) ||
        !vec(domain$upper) || any(domain$lower >= domain$upper)) stop("Invalid box domain")
    lo <- domain$lower; hi <- domain$upper
    inside <- function(x) rowSums(sweep(x,2L,lo,">=") & sweep(x,2L,hi,"<=")) == d
  } else stop("domain kind must be ball or box")
  if (any(!is.finite(c(lo,hi,hi-lo)))) stop("Nonfinite domain bounds")
  if (!all(inside(from)) || !all(inside(to))) stop("Endpoints must be inside the domain")
  if (!is.list(control) || (length(control) && (is.null(names(control)) || anyNA(names(control)) ||
      any(!nzchar(names(control))) || anyDuplicated(names(control))))) stop("control must be a uniquely named list")
  mesh <- method == "polyhedral_mesh"
  defaults <- list(resolution = c(17L,5L,3L)[d-1L], vertices = NULL,
    max_vertices = if(mesh) 1024L else if(method=="delaunay_graph") c(2048L,512L,128L)[d-1L] else 4096L,
    max_edges = 200000L, max_pair_checks = 1000000L, max_seconds = Inf,
    keep_graph = FALSE)
  if (method == "radius_graph") defaults$radius <- 2*max(hi-lo)/(defaults$resolution-1)
  if (mesh) defaults <- c(defaults,list(max_faces=2048L,max_propagations=100000L,max_intervals=200000L,keep_mesh=FALSE))
  if (length(setdiff(names(control),names(defaults)))) stop("Unsupported controls for ",method)
  defaults[names(control)] <- control
  integer_control <- function(n,lower,upper) {
    x<-defaults[[n]]
    if(!is.numeric(x)||length(x)!=1L||!is.finite(x)||x!=floor(x)||x<lower||x>upper)stop("Invalid ",n)
  }
  integer_control("resolution",2,33);integer_control("max_vertices",2,4096)
  if(mesh)defaults$max_vertices<-min(defaults$max_vertices,1024L)
  if(method=="delaunay_graph")defaults$max_vertices<-min(defaults$max_vertices,c(2048L,512L,128L)[d-1L])
  integer_control("max_edges",0,2000000);integer_control("max_pair_checks",0,10000000)
  if(!is.numeric(defaults$max_seconds)||length(defaults$max_seconds)!=1L||is.na(defaults$max_seconds)||defaults$max_seconds<0)stop("Invalid max_seconds")
  if(!is.logical(defaults$keep_graph)||length(defaults$keep_graph)!=1L||is.na(defaults$keep_graph))stop("Invalid keep_graph")
  if(method=="radius_graph") {
    if(!"radius" %in% names(control))defaults$radius<-2*max(hi-lo)/(defaults$resolution-1)
    if(!is.numeric(defaults$radius)||length(defaults$radius)!=1L||!is.finite(defaults$radius)||defaults$radius<=0)stop("Invalid radius")
  }
  if(mesh){
    integer_control("max_faces",1,4096);integer_control("max_propagations",0,1000000);integer_control("max_intervals",1,1000000)
    if(!is.logical(defaults$keep_mesh)||length(defaults$keep_mesh)!=1L||is.na(defaults$keep_mesh))stop("Invalid keep_mesh")
  }
  if(!is.null(defaults$vertices)){
    v<-defaults$vertices
    if(!is.matrix(v)||!is.numeric(v)||ncol(v)!=d||!nrow(v)||any(!is.finite(v))||!all(inside(v)))stop("vertices must be a finite matrix inside the domain")
  }
  raw_failure <- function(status,reason,message=NULL) list(status=status,termination=reason,
    implementation=backend,length=NA_real_,error_estimate=NA_real_,
    path=matrix(numeric(),0,d),surface_path=matrix(numeric(),0,d+1L),
    path_representation=if(mesh)"polyhedral_surface_polyline" else "lifted_domain_polyline",
    curve_parameters=NULL,diagnostics=list(message=message),graph=NULL,configuration=defaults,state_saving=FALSE)
  results <- lapply(seq_len(nrow(from)),function(i){
    start<-proc.time()[["elapsed"]]
    remaining<-function()defaults$max_seconds-(proc.time()[["elapsed"]]-start)
    calculate<-function(){
      if(mesh&&d!=2L)return(raw_failure("unsupported","mesh_requires_two_dimensional_domain"))
      if(remaining()<=0)return(raw_failure("failed","time_limit"))
      cap<-if(mesh)min(defaults$max_vertices,1024L) else if(method=="delaunay_graph")min(defaults$max_vertices,c(2048L,512L,128L)[d-1L]) else defaults$max_vertices
      if(is.null(defaults$vertices)){
        if(defaults$resolution^d>cap)return(raw_failure("failed","vertex_limit"))
        points<-as.matrix(do.call(expand.grid,c(lapply(seq_len(d),function(j)seq(lo[j],hi[j],length.out=defaults$resolution)),KEEP.OUT.ATTRS=FALSE)))
        points<-points[inside(points),,drop=FALSE]
      }else points<-defaults$vertices
      points<-unique(rbind(points,from[i,],to[i,]))
      if(nrow(points)>cap)return(raw_failure("failed","vertex_limit"))
      points<-unname(points[do.call(order,as.data.frame(points)),,drop=FALSE])
      cells<-matrix(integer(),0,d+1L)
      if(method!="radius_graph"&&!identical(from[i,],to[i,])){
        if(!requireNamespace("geometry",quietly=TRUE))return(raw_failure("unsupported","geometry_dependency_unavailable"))
        if(nrow(points)<d+1L)return(raw_failure("failed","insufficient_triangulation_vertices"))
        cells<-tryCatch(geometry::delaunayn(points,options="Qt Qbb Qc Qz"),error=function(e)e)
        if(inherits(cells,"error"))return(raw_failure("failed","triangulation_failed",conditionMessage(cells)))
        if(!is.matrix(cells)||!nrow(cells))return(raw_failure("failed","empty_triangulation"))
        storage.mode(cells)<-"integer"
        if(mesh&&nrow(cells)>defaults$max_faces)return(raw_failure("failed","face_limit"))
      }
      if(remaining()<=0)return(raw_failure("failed","time_limit"))
      native<-defaults;native$prepared_vertices<-points;native$prepared_cells<-cells
      native$max_seconds<-remaining()
      rcpp_quadform_geodesics_method(A,from[i,],to[i,],domain,method,native)
    }
    raw<-calculate();raw$configuration<-defaults
    raw$diagnostics$total_seconds<-proc.time()[["elapsed"]]-start
    if(!return.paths)raw[c("path","surface_path")]<-list(NULL,NULL)
    list(method=method,backend=raw$implementation,status=raw$status,termination=raw$termination,
      length=raw$length,length_error_estimate=raw$error_estimate,approximation_error=NA_real_,
      global_optimality_certified=FALSE,path_representation=raw$path_representation,
      path=raw$path,surface_path=raw$surface_path,curve_parameters=raw$curve_parameters,
      backend_result=raw,state_saving=FALSE)
  })
  summary<-data.frame(pair=seq_len(nrow(from)),length=vapply(results,`[[`,0,"length"),
    length_error_estimate=vapply(results,`[[`,0,"length_error_estimate"),approximation_error=NA_real_,
    global_optimality_certified=FALSE,status=vapply(results,`[[`,"","status"),
    termination=vapply(results,`[[`,"","termination"),backend=vapply(results,`[[`,"","backend"))
  list(interface_version="1.0.0-internal",method=method,geometry=list(A=A),domain=domain,
    from=from,to=to,control=defaults,summary=summary,results=results)
}
