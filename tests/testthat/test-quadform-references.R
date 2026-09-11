local({
  solve<-getFromNamespace("quadform_geodesics","dgraphs")
  methods<-c("delaunay_graph","radius_graph","polyhedral_mesh")
  box<-function(d)list(kind="box",lower=rep(-1,d),upper=rep(1,d))
  run<-function(m,A=diag(c(2,-1)),a=c(-.45,-.2),b=c(.4,-.1),control=list(resolution=7L))
    solve(A,a,b,box(nrow(A)),m,control,TRUE)$results[[1]]
  measure<-function(p,A)sum(vapply(seq_len(nrow(p)-1),function(i){
    h<-p[i+1,]-p[i,];integrate(function(t)sqrt(sum(h*h)+(2*sum(p[i,]*(A%*%h))+2*t*sum(h*(A%*%h)))^2),0,1,rel.tol=1e-10)$value
  },0))
  test_that("all references retain declared path representations and endpoints",{
    skip_if_not_installed("geometry")
    for(m in methods){
      z<-run(m);expect_identical(z$status,"candidate")
      expect_identical(unname(z$path[1,]),c(-.45,-.2))
      expect_identical(unname(tail(z$path,1)),matrix(c(.4,-.1),1))
      expect_true(all(abs(z$path)<=1));expect_false(z$global_optimality_certified)
      expect_true(is.na(z$approximation_error));expect_false(z$state_saving)
      if(m=="polyhedral_mesh"){
        expect_identical(z$path_representation,"polyhedral_surface_polyline")
        expect_true(is.na(z$length_error_estimate))
        expect_equal(z$length,sum(sqrt(rowSums(diff(z$surface_path)^2))),tolerance=1e-12)
        expect_equal(z$backend_result$diagnostics$smooth_lifted_length,measure(z$path,diag(c(2,-1))),tolerance=1e-10)
      }else expect_equal(z$length,measure(z$path,diag(c(2,-1))),tolerance=1e-10)
    }
  })
  test_that("mesh routes cross triangle interiors rather than only mesh edges",{
    skip_if_not_installed("geometry")
    # A square split along one diagonal: the opposite diagonal crosses faces.
    points<-rbind(c(-1,-1),c(-1,1),c(1,-1),c(1,1))
    pairs<-list(list(c(-1,-1),c(1,1)),list(c(-1,1),c(1,-1)))
    mesh_lengths<-graph_lengths<-numeric()
    for(p in pairs){
      ctl<-list(vertices=points,keep_mesh=TRUE)
      z<-run("polyhedral_mesh",matrix(0,2,2),p[[1]],p[[2]],ctl)
      expect_identical(z$status,"candidate");expect_equal(z$length,sqrt(8),tolerance=1e-12)
      expect_equal(nrow(z$backend_result$mesh$triangles),2)
      mesh_lengths<-c(mesh_lengths,z$length)
      g<-run("delaunay_graph",matrix(0,2,2),p[[1]],p[[2]],list(vertices=points))
      graph_lengths<-c(graph_lengths,g$length)
    }
    expect_gt(max(graph_lengths-mesh_lengths),1)
  })
  test_that("reference graph distances agree with an independent graph engine",{
    skip_if_not_installed("geometry")
    for(d in 2:4)for(m in c("delaunay_graph","radius_graph")){
      A<-diag(seq_len(d)*rep(c(1,-1),length.out=d),d)
      ctl<-list(resolution=3L,keep_graph=TRUE)
      z<-run(m,A,rep(-.4,d),rep(.4,d),ctl)
      expect_identical(z$status,"candidate");expect_equal(ncol(z$path),d)
      expect_equal(z$length,measure(z$path,A),tolerance=1e-9)
      graph<-z$backend_result$graph;dg<-igraph::make_empty_graph(nrow(graph$vertices),directed=FALSE)
      dg<-igraph::add_edges(dg,as.vector(t(graph$edges)))
      diag<-z$backend_result$diagnostics
      value<-igraph::distances(dg,v=diag$source_index,to=diag$target_index,weights=graph$weights)[1,1]
      expect_equal(z$length,value,tolerance=1e-12)
    }
  })
  test_that("mesh segments lie on mesh triangles and resolution approaches Clairaut",{
    skip_if_not_installed("geometry")
    z<-run("polyhedral_mesh",control=list(resolution=5L,keep_mesh=TRUE))
    p<-z$surface_path;mesh<-z$backend_result$mesh
    for(i in seq_len(nrow(p)-1L)){
      samples<-rbind(p[i,],(p[i,]+p[i+1,])/2,p[i+1,])
      fits<-apply(mesh$triangles,1L,function(ids){
        vertices<-mesh$vertices[ids,,drop=FALSE]
        bary<-base::solve(rbind(t(vertices[,1:2]),1),rbind(t(samples[,1:2]),1))
        all(bary>=-1e-9)&&max(abs(as.vector(vertices[,3]%*%bary)-samples[,3]))<1e-9
      })
      expect_true(any(fits))
    }
    A<-diag(2);a<-c(-.6,-.15);b<-c(.55,.2)
    ref<-solve(A,a,b,box(2),"paraboloid_clairaut")$summary$length
    errors<-vapply(c(5L,9L,17L),function(n)abs(run("polyhedral_mesh",A,a,b,list(resolution=n))$length-ref),0)
    expect_true(all(diff(errors)<0));expect_lt(tail(errors,1),.006)
  })
  test_that("higher-dimensional analytic connector lengths match quadrature",{
    for(d in 3:4)for(s in c(1e-6,1,1e6)){
      A<-diag(seq_len(d))/s;p<-seq(-.3,.3,length.out=d)*s;q<-rev(p)+.1*s
      z<-solve(A,p,q,list(kind="box",lower=rep(-s,d),upper=rep(s,d)),"radius_graph",
        list(vertices=rbind(p,q),radius=10*s),TRUE)$results[[1]]
      expect_identical(z$status,"candidate")
      expect_equal(z$length,measure(rbind(p,q),A),tolerance=1e-10)
      expect_gte(z$length_error_estimate,0)
    }
  })
  test_that("resource exhaustion and disconnection do not return invented routes",{
    skip_if_not_installed("geometry")
    for(m in methods){
      z<-run(m,control=list(max_seconds=0));expect_identical(z$status,"failed");expect_true(is.na(z$length))
      z<-run(m,control=list(max_vertices=2));expect_identical(z$termination,"vertex_limit")
      expect_equal(nrow(z$path),0)
    }
    for(m in c("delaunay_graph","radius_graph")){
      z<-run(m,control=list(resolution=3L,max_edges=0));expect_identical(z$termination,"edge_limit")
      expect_true(is.na(z$length))
    }
    z<-run("radius_graph",control=list(resolution=3L,radius=1e-9))
    expect_identical(z$termination,"disconnected_reference_graph");expect_true(is.na(z$length))
    z<-run("radius_graph",control=list(max_pair_checks=0))
    expect_identical(z$termination,"pair_check_limit")
    z<-run("polyhedral_mesh",control=list(resolution=3L,max_faces=1L));expect_identical(z$termination,"face_limit")
    for(ctl in list(list(resolution=5L,max_propagations=0),list(resolution=5L,max_intervals=1L))){
      z<-run("polyhedral_mesh",control=ctl);expect_identical(z$status,"failed");expect_true(is.na(z$length));expect_equal(nrow(z$path),0)
    }
  })
  test_that("scope, malformed inputs and repeated points are explicit",{
    for(m in methods){
      for(ctl in list(list(resolution=1),list(vertices=matrix(Inf,2,2)),list(vertices=matrix(3,2,2)),
        list(max_edges=-1),list(unknown=1),list(keep_graph=NA)))expect_error(run(m,control=ctl))
    }
    z<-run("polyhedral_mesh",diag(3),rep(-.4,3),rep(.4,3),list(resolution=3))
    expect_identical(z$status,"unsupported");expect_true(is.na(z$length))
    z<-run("radius_graph",control=list(vertices=rbind(c(-.45,-.2),c(-.45,-.2),c(.4,-.1)),radius=2))
    expect_identical(z$status,"candidate");expect_equal(z$backend_result$diagnostics$vertices,2)
  })
  test_that("thin mesh rejections retain an informative nonzero angle",{
    skip_if_not_installed("geometry")
    z<-run("polyhedral_mesh",a=c(0,0),b=c(1e-9,2e-9),control=list(resolution=9L))
    expect_identical(z$termination,"mesh_degenerate_triangle")
    d<-z$backend_result$diagnostics
    angle<-min(d$rejected_triangle_angle,pi-d$rejected_triangle_angle)
    expect_gt(angle,0);expect_lt(angle,d$required_minimum_triangle_angle)
    expect_lt(d$endpoint_separation_over_mesh_scale,1e-8)
    expect_equal(nrow(z$path),0);expect_true(is.na(z$length))
  })
  test_that("endpoint reversal and R random state are preserved",{
    skip_if_not_installed("geometry")
    set.seed(74);before<-.Random.seed
    for(m in methods){
      x<-run(m);y<-run(m,a=c(.4,-.1),b=c(-.45,-.2))
      expect_identical(x$status,y$status);expect_identical(x$length,y$length)
      expect_identical(x$path,y$path[nrow(y$path):1,,drop=FALSE])
      z<-solve(diag(2),c(-.4,0),c(.4,0),box(2),m,list(resolution=5))
      expect_null(z$results[[1]]$path);expect_null(z$results[[1]]$surface_path)
    }
    expect_identical(before,.Random.seed)
  })
})
