local({
  solve <- getFromNamespace("quadform_geodesics", "dgraphs")
  native <- getFromNamespace("quadform_geodesics_solver", "dgraphs")
  disk <- list(kind = "ball", center = c(0,0), radius = 2)
  box <- list(kind = "box", lower = c(-2,-2), upper = c(2,2))
  pair <- function(A = diag(2), from = c(.2,.1), to = c(.8,-.3),
                   domain = disk, method = "paraboloid_clairaut", control = list(), paths = TRUE)
    solve(A, from, to, domain, method, control, return.paths = paths)$results[[1L]]
  integrate_path <- function(U,A) sum(vapply(seq_len(nrow(U)-1L),function(i){
    p<-U[i,];h<-U[i+1L,]-p
    integrate(function(t)sqrt(sum(h*h)+(2*sum(p*(A%*%h))+2*t*sum(h*(A%*%h)))^2),
              0,1,rel.tol=1e-11,abs.tol=1e-13,subdivisions=1000)$value
  },0))

  test_that("the common interface validates geometry, pairs, methods and controls", {
    expect_error(solve(diag(2),c(0,0),c(.1,0),disk),"explicitly")
    expect_error(pair(method="grid"),"explicitly")
    expect_error(pair(A=diag(3)),"2 by 2")
    expect_error(pair(A=matrix(1:4,2)),"symmetric")
    expect_error(pair(A=diag(c(NA,1))),"finite")
    expect_error(pair(from=c(3,0)),"inside")
    expect_error(pair(from=matrix(0,2,2)),"same number")
    expect_error(pair(domain=c(disk,list(hull=TRUE))),"Invalid ball")
    expect_error(pair(control=list(seed=1)),"Unsupported controls")
    expect_error(pair(control=list(iterations=1,iterations=2)),"uniquely named")
    expect_error(pair(control=list(path_samples=NA)),"path_samples")
    expect_error(pair(control=list(angle_tolerance=0)),"angle_tolerance")
    expect_error(pair(method="grid_dijkstra",control=list(grid_size=3)),"grid_size")
    expect_error(pair(method="grid_dijkstra",control=list(direction_radius=0)),"direction_radius")
    expect_error(pair(paths=NA),"return.paths")
  })
  test_that("native refinements retain their coordinates, uncertainty and ensemble outcomes", {
    for(method in c("single_point","local_network")) {
      x<-pair(method=method,control=list(max_epochs=2L,seed=73))
      y<-native(diag(2),c(.2,.1),c(.8,-.3),disk,method=method,
                max_epochs=2L,seed=73,cache_edges=0L)
      expect_identical(x$path,y$path);expect_identical(x$length,y$length)
      expect_identical(x$length_error_estimate,y$error_estimate)
      expect_false(x$global_optimality_certified)
    }
    x<-pair(method="best_of_six",control=list(max_epochs=1L))
    expect_length(x$backend_result$ensemble$results,6L)
    expect_equal(x$length,min(x$backend_result$ensemble$summary$length))
    expect_gte(x$backend_result$ensemble$total_edge_calls,x$backend_result$counters$edge_calls)
    z<-pair(method="single_point",control=list(max_seconds=0))
    expect_true(z$status %in% c("failed","partial"))
  })
  test_that("paired queries and optional paths preserve identity without changing R RNG", {
    had_seed<-exists(".Random.seed",.GlobalEnv,inherits=FALSE)
    if(had_seed)old_seed<-get(".Random.seed",.GlobalEnv)
    on.exit(if(had_seed)assign(".Random.seed",old_seed,.GlobalEnv)else
      rm(".Random.seed",envir=.GlobalEnv),add=TRUE)
    set.seed(419);before<-.Random.seed
    from<-rbind(c(.2,.1),c(0,0),c(.4,.2));to<-rbind(c(.8,-.3),c(.3,.2),c(.4,.2))
    for(method in c("grid_dijkstra","paraboloid_clairaut","single_point","best_of_six")) {
      control<-if(method %in% c("single_point","best_of_six"))list(max_epochs=1L)else list()
      x<-solve(diag(2),from,to,disk,method,control,return.paths=TRUE)
      y<-solve(diag(2),from,to,disk,method,control)
      expect_equal(x$summary$length,y$summary$length,tolerance=0)
      expect_identical(x$summary$pair,1:3)
      for(i in 1:3){expect_equal(x$results[[i]]$path[1,],from[i,],tolerance=0)
        expect_equal(tail(x$results[[i]]$path,1)[1,],to[i,],tolerance=0)
        expect_null(y$results[[i]]$path);expect_null(y$results[[i]]$backend_result$path)
        expect_false(x$results[[i]]$state_saving)}
    }
    expect_identical(.Random.seed,before)
    expect_false("quadform_geodesics" %in% getNamespaceExports("dgraphs"))
  })
  test_that("grid spacing and available directions are distinct accuracy controls", {
    d<-list(kind="box",lower=c(0,0),upper=c(2,1))
    calc<-function(n,direction)pair(A=matrix(0,2,2),from=c(0,0),to=c(2,1),domain=d,
      method="grid_dijkstra",control=list(grid_size=n,direction_radius=direction,include_direct=FALSE))
    a<-calc(c(5,3),1L);b<-calc(c(9,5),1L);c<-calc(c(5,3),2L)
    expect_equal(a$length,1+sqrt(2),tolerance=1e-14)
    expect_equal(a$length,b$length,tolerance=1e-14)
    expect_equal(c$length,sqrt(5),tolerance=1e-14)
    expect_gt(a$length/sqrt(5)-1,.079)
    direct<-pair(A=matrix(0,2,2),from=c(0,0),to=c(2,1),domain=d,method="grid_dijkstra")
    expect_equal(direct$length,sqrt(5),tolerance=1e-14)
  })
  test_that("grid weights and shortest paths agree with independent integration and dgraphs", {
    for(A in list(diag(2),diag(c(8,-2)),matrix(c(2,1,1,.5),2))) {
      x<-pair(A=A,domain=box,method="grid_dijkstra",control=list(grid_size=c(9,9),keep_graph=TRUE))
      expect_identical(x$status,"candidate")
      graph<-x$backend_result$graph;g<-w<-rep(list(numeric()),nrow(graph$vertices))
      for(i in seq_len(nrow(graph$edges))){a<-graph$edges[i,1];b<-graph$edges[i,2]
        g[[a]]<-c(g[[a]],b);w[[a]]<-c(w[[a]],graph$weights[i])
        g[[b]]<-c(g[[b]],a);w[[b]]<-c(w[[b]],graph$weights[i])}
      ids<-unlist(x$backend_result$diagnostics[c("source_index","target_index")])
      reference<-dgraphs::shortest.path(g,w,ids)[1,2]
      expect_equal(x$length,reference,tolerance=1e-13)
      expect_equal(x$length,integrate_path(x$path,A),tolerance=1e-11)
      expect_equal(x$surface_path[,3],rowSums((x$path%*%A)*x$path),tolerance=1e-13)
      y<-pair(A=A,from=c(.8,-.3),to=c(.2,.1),domain=box,method="grid_dijkstra",control=list(grid_size=c(9,9)))
      expect_identical(x$path,y$path[nrow(y$path):1L,]);expect_identical(x$length,y$length)
    }
    for(control in list(list(max_seconds=0),list(max_edges=0))) {
      x<-pair(method="grid_dijkstra",control=control)
      expect_identical(x$status,"failed");expect_true(is.na(x$length));expect_equal(nrow(x$path),0)
    }
  })
  test_that("Clairaut covers flat, radial, apex and both antipodal branches", {
    x<-pair(A=matrix(0,2,2),domain=box)
    expect_equal(x$length,sqrt(.6^2+.4^2),tolerance=1e-14)
    for(points in list(list(c(0,0),c(.8,0)),list(c(.1,0),c(.8,0)),list(c(.1,0),c(-.1,0)))) {
      x<-pair(from=points[[1]],to=points[[2]])
      expect_identical(x$status,"candidate")
      expect_equal(x$length,integrate_path(rbind(points[[1]],points[[2]]),diag(2)),tolerance=1e-12)
    }
    x<-pair(from=c(1.8,0),to=c(-1.8,0))
    expect_identical(x$status,"candidate")
    expect_identical(x$backend_result$diagnostics$branch,"turning")
    expect_gt(x$curve_parameters[["c"]],0)
    expect_lt(x$length,integrate_path(rbind(c(1.8,0),c(-1.8,0)),diag(2)))
    z<-pair(from=c(.2,.1),to=c(.2,.1))
    expect_equal(z$length,0);expect_identical(z$termination,"identity")
  })
  test_that("Clairaut lengths and angles pass independent quadrature", {
    for(coef in c(.1,1,8,-2))for(points in list(
      list(c(.2,.1),c(.8,-.3)),list(c(.8,0),c(0,.8)),
      list(c(.2,.1),c(.20000001,.10000002)),list(c(1.8,0),c(-1.8,0)))) {
      x<-pair(A=diag(rep(coef,2)),from=points[[1]],to=points[[2]])
      expect_identical(x$status,"candidate")
      if(x$path_representation!="analytic_clairaut_curve")next
      p<-as.list(x$curve_parameters)
      length<-p$t_span*integrate(function(s)sqrt(1+(p$k*p$c)^2+
         (p$k*(p$t_from+s*p$t_span))^2),
         0,1,rel.tol=1e-11,abs.tol=1e-13,subdivisions=1000)$value
      expect_equal(x$length,length,tolerance=1e-10)
      angle<-integrate(function(phi)sqrt(1+(p$k*p$c/cos(phi))^2),
         atan(p$t_from/p$c),atan(p$t_to/p$c),rel.tol=1e-10,abs.tol=1e-12,subdivisions=1000)$value
      a<-points[[1]];b<-points[[2]]
      gap<-atan2(abs(a[1]*b[2]-a[2]*b[1]),sum(a*b))
      expect_equal(angle,gap,tolerance=1e-8)
      y<-pair(A=diag(rep(coef,2)),from=points[[2]],to=points[[1]])
      expect_identical(x$length,y$length);expect_identical(x$path,y$path[nrow(y$path):1L,])
    }
  })
  test_that("Clairaut distinguishes sampled polyline lengths from the continuous curve", {
    coarse<-pair(from=c(1,0),to=c(0,1),control=list(path_samples=9L))
    fine<-pair(from=c(1,0),to=c(0,1),control=list(path_samples=257L))
    expect_identical(coarse$length,fine$length)
    a<-integrate_path(coarse$path,diag(2));b<-integrate_path(fine$path,diag(2))
    expect_gt(a-coarse$length,1e-6)
    expect_lt(abs(b-fine$length),abs(a-coarse$length)/100)
    expect_lte(abs(b-fine$length),1e-5)
  })
  test_that("whole-path domains and unsupported scientific scope remain explicit", {
    expect_identical(pair(A=diag(c(1,2)))$termination,"requires_isotropic_form")
    expect_identical(pair(A=matrix(c(1,.1,.1,1),2))$status,"unsupported")
    expect_identical(pair(domain=box)$status,"candidate")
    narrow<-list(kind="box",lower=c(.89,-1),upper=c(.91,1))
    x<-pair(A=diag(c(8,8)),from=c(.9,-.9),to=c(.9,.9),domain=narrow)
    expect_identical(x$status,"unsupported")
    expect_true(x$termination %in% c("path_leaves_domain","domain_containment_unresolved"))
    expect_true(is.na(x$length));expect_equal(nrow(x$path),0)
    expect_identical(pair(control=list(iterations=1))$status,"failed")
    expect_identical(pair(control=list(max_seconds=0))$termination,"time_limit")
    expect_identical(pair(A=diag(c(1e8,1e8)))$termination,"polar_numerical_range")
  })
  test_that("new methods respect changes of length unit and translated disk domains", {
    for(method in c("grid_dijkstra","paraboloid_clairaut")) {
      base<-pair(method=method)
      for(scale in c(.001,1000)) {
        x<-pair(A=diag(2)/scale,from=c(.2,.1)*scale,to=c(.8,-.3)*scale,
          domain=list(kind="ball",center=c(0,0),radius=2*scale),method=method)
        expect_identical(x$status,"candidate")
        expect_equal(x$length/scale,base$length,tolerance=1e-11)
      }
      shifted<-pair(domain=list(kind="ball",center=c(.5,.1),radius=2),method=method)
      expect_identical(shifted$status,"candidate")
    }
  })
})
