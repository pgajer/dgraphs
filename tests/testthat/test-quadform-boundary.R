local({
  solve<-getFromNamespace("quadform_geodesics","dgraphs")
  disk<-list(kind="ball",center=c(0,0),radius=1)
  run<-function(A=diag(c(2,-1)),a=c(-.45,-.2),b=c(.4,-.1),domain=disk,control=list())
    solve(A,a,b,domain,"boundary_optimization",control,TRUE)$results[[1]]
  test_that("boundary optimization preserves feasibility and improves curved paths",{
    z<-run(control=list(levels=1L,evaluations_per_start=500L))
    expect_true(z$status%in%c("candidate","partial"))
    expect_true(all(rowSums(z$path^2)<=1));expect_equal(unname(z$path[1,]),c(-.45,-.2))
    expect_equal(unname(tail(z$path,1)),matrix(c(.4,-.1),1))
    direct<-solve(diag(c(2,-1)),c(-.45,-.2),c(.4,-.1),disk,"grid_dijkstra",list(grid_size=c(3,3)),TRUE)
    expect_lt(z$length,direct$summary$length)
    p<-z$path;A<-diag(c(2,-1));length<-sum(vapply(seq_len(nrow(p)-1),function(i){
      h<-p[i+1,]-p[i,];integrate(function(t)sqrt(sum(h*h)+(2*sum(p[i,]*(A%*%h))+2*t*sum(h*(A%*%h)))^2),0,1)$value
    },0))
    expect_equal(z$length,length,tolerance=1e-10)
    expect_false(z$global_optimality_certified);expect_true(is.na(z$approximation_error))
    expect_false(z$state_saving)
  })
  test_that("boundary contact is allowed where continuous solutions leave the rectangle",{
    box<-list(kind="box",lower=c(-.3,-1),upper=c(.3,1))
    z<-run(diag(1.2,2),c(.3,-.8),c(.3,.8),box,list(levels=1L,evaluations_per_start=300L))
    expect_true(is.finite(z$length));expect_true(all(z$path[,1]<=.3&z$path[,1]>=-.3))
    expect_true(all(z$path[,2]>=-1&z$path[,2]<=1))
    ref<-solve(diag(1.2,2),c(.3,-.8),c(.3,.8),box,"geodesic_collocation")
    expect_identical(ref$summary$status,"unsupported")
  })
  test_that("limits retain only an explicit feasible starting path",{
    z<-run(control=list(max_seconds=0));expect_identical(z$status,"failed");expect_true(is.na(z$length))
    z<-run(control=list(max_evaluations=0));expect_identical(z$status,"partial")
    expect_identical(z$termination,"evaluation_limit");expect_equal(nrow(z$path),2)
    expect_equal(z$backend_result$diagnostics$objective_evaluations,0)
    z<-run(matrix(0,2,2));expect_identical(z$termination,"flat")
    expect_equal(z$length,sqrt(.85^2+.1^2),tolerance=1e-14)
    z<-run(a=c(0,0),b=c(0,0));expect_identical(z$termination,"identity");expect_equal(z$length,0)
  })
  test_that("warm starts and control validation are explicit",{
    p<-rbind(c(-.45,-.2),c(0,-.3),c(.4,-.1))
    z<-run(control=list(initial_path=p,max_evaluations=0));expect_true(is.finite(z$length))
    for(ctl in list(list(initial_path=p[-1,]),list(initial_path=rbind(p,c(2,2))),
      list(initial_edges=1),list(levels=4),list(position_tolerance=0),
      list(initial_bends=c(0,0)),list(initial_bends=NA_real_),list(initial_step=0)))expect_error(run(control=ctl))
  })
  test_that("boundary optimization is reproducible and leaves R random state alone",{
    set.seed(41);before<-.Random.seed
    ctl<-list(levels=1L,evaluations_per_start=100L)
    x<-run(control=ctl);y<-run(a=c(.4,-.1),b=c(-.45,-.2),control=ctl)
    expect_identical(x$length,y$length)
    expect_identical(x$path,y$path[nrow(y$path):1,,drop=FALSE])
    expect_identical(.Random.seed,before)
  })
})
