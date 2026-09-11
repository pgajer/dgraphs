local({
  solve <- getFromNamespace("quadform_geodesics", "dgraphs")
  methods <- c("geodesic_shooting", "geodesic_collocation")
  disk <- list(kind="ball", center=c(0,0), radius=1)
  a <- c(-.45,-.2); b <- c(.4,-.1)
  run <- function(method, A=diag(c(2,-1)), from=a, to=b, domain=disk, control=list())
    solve(A,from,to,domain,method,control,return.paths=TRUE)$results[[1]]
  measure <- function(U,A) sum(vapply(seq_len(nrow(U)-1L),function(i){
    p<-U[i,];h<-U[i+1L,]-p
    integrate(function(t)sqrt(sum(h*h)+(2*sum(p*(A%*%h))+2*t*sum(h*(A%*%h)))^2),
      0,1,rel.tol=1e-11,abs.tol=1e-13)$value
  },0))
  test_that("continuous methods return exact flat and identity paths", {
    for(method in methods){
      z<-run(method,matrix(0,2,2));expect_identical(z$status,"candidate")
      expect_equal(z$length,sqrt(sum((b-a)^2)),tolerance=1e-13)
      expect_identical(z$termination,"flat")
      z<-run(method,from=a,to=a);expect_identical(z$termination,"identity")
      expect_identical(z$length,0);expect_false(z$global_optimality_certified)
    }
  })
  test_that("shooting and collocation solve the same moderate saddle independently", {
    values<-lapply(methods,run)
    for(z in values){
      expect_identical(z$status,"candidate")
      expect_identical(unname(z$path[1,]),a);expect_identical(unname(tail(z$path,1)),matrix(b,1))
      expect_true(all(rowSums(z$path^2)<=1))
      expect_equal(z$length,measure(z$path,diag(c(2,-1))),tolerance=1e-10)
      expect_lte(z$backend_result$diagnostics$endpoint_residual,1e-8)
      expect_lte(z$backend_result$diagnostics$equation_residual_estimate,1e-6)
      expect_identical(z$path_representation,"lifted_domain_polyline")
      expect_identical(z$backend_result$diagnostics$domain_check,"bezier_control_hulls_then_convex_polyline")
      expect_false(z$state_saving);expect_true(is.na(z$approximation_error))
    }
    expect_equal(values[[1]]$length,values[[2]]$length,tolerance=2e-6)
    expect_gt(values[[1]]$backend_result$diagnostics$integration_steps,0)
    expect_identical(values[[2]]$backend_result$diagnostics$integration_steps,0)
  })
  test_that("known saddle rulings and paraboloid references remain distinguishable", {
    p<-c(-.5,-.5);q<-c(.3,.3)
    for(method in methods){
      z<-run(method,diag(c(4,-4)),p,q,control=list(initial_bends=0))
      expect_identical(z$status,"candidate");expect_equal(z$length,sqrt(sum((q-p)^2)),tolerance=1e-9)
      z<-run(method,diag(2),control=list(initial_bends=0))
      ref<-run("paraboloid_clairaut",diag(2))
      expect_identical(z$status,"candidate");expect_equal(z$length,ref$length,tolerance=2e-6)
      expect_gte(z$length+z$length_error_estimate+1e-10,ref$length)
    }
  })
  test_that("canonical endpoint reversal preserves the realized path", {
    for(method in methods){
      x<-run(method,control=list(initial_bends=0));y<-run(method,from=b,to=a,control=list(initial_bends=0))
      expect_identical(x$length,y$length);expect_identical(x$path,y$path[nrow(y$path):1,,drop=FALSE])
      reflected<-run(method,-diag(c(2,-1)),control=list(initial_bends=0))
      expect_equal(x$length,reflected$length,tolerance=1e-12)
    }
  })
  test_that("resource failures cannot invent a candidate or conceal partial work", {
    for(method in methods){
      x<-run(method,control=list(max_seconds=0));expect_identical(x$status,"failed")
      expect_true(is.na(x$length));expect_identical(x$termination,"time_limit")
      x<-run(method,control=list(max_evaluations=0));expect_identical(x$status,"failed")
      expect_identical(x$termination,"evaluation_limit");expect_equal(nrow(x$path),0)
      one<-run(method,control=list(initial_bends=0))
      x<-run(method,control=list(max_evaluations=one$backend_result$diagnostics$rhs_evaluations))
      expect_identical(x$status,"partial");expect_identical(x$termination,"evaluation_limit")
      expect_identical(x$path,one$path);expect_identical(x$length,one$length)
      x<-run(method,control=list(max_path_vertices=3L));expect_identical(x$status,"failed")
      expect_true(is.na(x$length));expect_equal(nrow(x$path),0)
    }
  })
  test_that("input controls and numerical scope fail explicitly", {
    for(method in methods){
      for(control in list(list(ode_tolerance=0),list(endpoint_tolerance=NA_real_),
        list(max_nodes=4L),list(initial_bends=c(0,0)),list(initial_bends=Inf),
        list(initial_bends=numeric()),list(initial_bends=matrix(0)),
        list(max_evaluations=1.5),list(unknown=1)))
        expect_error(run(method,control=control))
      x<-run(method,diag(c(1e100,-1e100)))
      expect_identical(x$status,"unsupported");expect_identical(x$termination,"numeric_scope")
    }
  })
  test_that("uniform units and nearby endpoints do not weaken endpoint accuracy", {
    for(method in methods){
      base<-run(method,control=list(initial_bends=0))
      for(s in c(1e-6,1e6)){
        z<-run(method,diag(c(2,-1))/s,a*s,b*s,
          list(kind="ball",center=c(0,0),radius=s),list(initial_bends=0))
        expect_identical(z$status,"candidate")
        expect_equal(z$length/s,base$length,tolerance=1e-7)
        expect_lte(z$backend_result$diagnostics$endpoint_residual/s,1e-8)
      }
      p<-c(2,.3);q<-p+c(1e-8,-2e-8)
      z<-run(method,from=p,to=q,domain=list(kind="ball",center=c(0,0),radius=1e6),
        control=list(initial_bends=0))
      expect_identical(z$status,"candidate")
      expect_equal(z$length,measure(rbind(p,q),diag(c(2,-1))),tolerance=1e-7)
      expect_lte(z$backend_result$diagnostics$endpoint_residual,1e-8*sqrt(sum((q-p)^2)))
    }
  })
  test_that("continuous paths outside the declared rectangle are not clipped", {
    for(method in methods){
      z<-run(method,diag(1.2,2),c(.3,-.8),c(.3,.8),
        list(kind="box",lower=c(-.3,-1),upper=c(.3,1)),list(initial_bends=0))
      expect_identical(z$status,"unsupported")
      expect_identical(z$termination,"stationary_paths_outside_domain")
      expect_true(is.na(z$length));expect_equal(nrow(z$path),0)
      expect_gt(z$backend_result$diagnostics$start_1_outside_x,.3)
    }
  })
  test_that("mixed unresolved and outside starts are not called unsupported", {
    z<-run("geodesic_shooting",diag(1.2,2),c(.3,-.8),c(.3,.8),
      list(kind="box",lower=c(-.3,-1),upper=c(.3,1)))
    expect_identical(z$status,"failed")
    expect_identical(z$termination,"no_feasible_path_some_starts_unresolved")
    expect_true(is.na(z$length));expect_equal(nrow(z$path),0)
  })
  test_that("multiple stationary branches are compared without claiming global optimality", {
    for(method in methods){
      ctl<-list(max_nodes=4097L,max_path_vertices=65537L,max_evaluations=2000000L)
      z<-run(method,diag(2),c(-.9,0),c(.9,0),control=ctl)
      d<-z$backend_result$diagnostics
      expect_identical(z$status,"candidate")
      expect_lt(z$length,d$start_1_length-0.04)
      ref<-run("paraboloid_clairaut",diag(2),c(-.9,0),c(.9,0))
      expect_equal(z$length,ref$length,tolerance=2e-6)
      expect_false(z$global_optimality_certified)
    }
    # The resolved curved branch must remain available on a steeper bowl.
    ctl<-list(max_nodes=4097L,max_path_vertices=65537L,max_evaluations=2000000L)
    z<-run("geodesic_collocation",diag(8,2),c(-.9,0),c(.9,0),control=ctl)
    expect_identical(z$status,"candidate")
    expect_identical(z$termination,"stationary_path_converged")
    expect_true(is.finite(z$length))
    ref<-run("paraboloid_clairaut",diag(8,2),c(-.9,0),c(.9,0))
    expect_equal(z$length,ref$length,tolerance=2e-6)
  })
  test_that("local residual refinement resolves steep radial curves", {
    for(method in methods){
      z<-run(method,diag(8,2),c(0,0),c(.6,.8),control=list(initial_bends=0))
      ref<-run("paraboloid_clairaut",diag(8,2),c(0,0),c(.6,.8))
      expect_identical(z$status,"candidate")
      expect_equal(z$length,ref$length,tolerance=2e-6)
      expect_lte(z$backend_result$diagnostics$solution_nodes,1025)
      expect_lte(nrow(z$path),4097)
      expect_lte(z$backend_result$diagnostics$equation_residual_estimate,1e-6)
    }
    z<-run("geodesic_collocation",diag(2),c(0,0),c(38.4,51.2),
      list(kind="ball",center=c(0,0),radius=64),
      list(initial_bends=0,max_nodes=4097L,max_path_vertices=65537L,max_evaluations=4000000L))
    ref<-run("paraboloid_clairaut",diag(2),c(0,0),c(38.4,51.2),
      list(kind="ball",center=c(0,0),radius=64))
    expect_identical(z$status,"candidate");expect_equal(z$length,ref$length,tolerance=2e-6)
    expect_lte(z$backend_result$diagnostics$endpoint_residual,64e-8)
  })
  test_that("no state files or random-stream changes are introduced", {
    old<-get0(".Random.seed",envir=.GlobalEnv,inherits=FALSE)
    on.exit(if(is.null(old)) {if(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))rm(".Random.seed",envir=.GlobalEnv)} else assign(".Random.seed",old,envir=.GlobalEnv))
    for(method in methods){
      if(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))rm(".Random.seed",envir=.GlobalEnv)
      run(method,control=list(initial_bends=0))
      expect_false(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
      set.seed(731);before<-.Random.seed
      x<-solve(diag(2),rbind(a,a),rbind(b,a),disk,method,list(initial_bends=0))
      expect_identical(.Random.seed,before);expect_null(x$results[[1]]$path)
      expect_equal(nrow(x$summary),2);expect_identical(x$summary$termination[2],"identity")
    }
  })
})
