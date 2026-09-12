script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L]))
home <- dirname(dirname(script)); adaptive_home <- home
source(file.path(home, "interface.R")); source(file.path(home, "runner.R"))
source(file.path(home, "tests/adaptive_test_helpers.R"))
source(file.path(home, "solvers/adaptive/local_graph.R"))
source(file.path(home, "native/load.R"))
n <- qgc.load(home)
original.runtime <- mget(c("qgs.vertex.key", "qgs.edge.key", "qgs.kernel"), inherits = TRUE)
restore.runtime <- function() list2env(original.runtime, globalenv())
e <- new.env(parent = globalenv())
for (file in c("common.R", "local_graph.R", "three_point.R", "sensitivity.R"))
  sys.source(file.path(home, "solvers/adaptive", file), e)
qgc.install(e, n, new.env())
with_reporter(StopReporter$new(), {
test_that("native binary keys and edge ordering exactly preserve the R convention", {
  set.seed(101)
  values <- c(0, -0, 1e-200, -1e200, runif(30, -1, 1))
  for(i in seq_len(length(values)-1L)) {
    u <- values[i:(i+1L)]
    expect_identical(n$qgc_key(u), qga.key(u))
    expect_identical(n$qgc_edge_key(u, rev(u)), qgs.edge.key(u, rev(u)))
  }
  edges <- list(rbind(c(.1,-0),c(-.2,0)), rbind(c(-.2,0),c(.1,-0)),
    rbind(c(0,0),c(0,0)),rbind(c(0,-0),c(0,0)))
  expect_identical(e$qga.edge.list(edges), qga.edge.list(edges))
  expect_error(n$qgc_key(c(Inf,0)), "Invalid")
})
test_that("native compensated sums and tangent speeds match R exactly", {
  set.seed(44)
  for(i in 1:100) {
    x <- c(rnorm(30),1e16,1,-1e16)
    expect_identical(n$qgc_sum(x), qga.sum(x))
    h <- rnorm(2); a <- rnorm(1); b <- rnorm(1); t <- runif(21)
    expected <- vapply(t,function(tt)qg.norm(c(h,a+b*tt)),0)
    expect_identical(n$qgc_speeds(t,h,a,b), expected)
  }
  expect_identical(n$qgc_speeds(c(0,1),c(1e-200,0),0,0),c(1e-200,1e-200))
  expect_identical(n$qgc_speeds(1,c(1e200,0),0,0),1e200)
  expect_identical(n$qgc_speeds(1,c(0,0),Inf,-Inf),Inf)
})
test_that("native graph decisions preserve ties, disconnection and budget conditions", {
  set.seed(89)
  for(i in 1:20) {
    U <- rbind(c(-.5,0),c(0,.2),c(.5,0), matrix(runif(12,-.5,.5),ncol=2))
    edges <- qga.edge.list(n$qgc_complete_edges(U)); s <- qga.state(req(),control_test(),rng_test())
    batch <- qga.batch(s,edges)
    expect_identical(e$qga.dijkstra(U,edges,batch,1L,3L,s$control),
      qga.dijkstra(U,edges,batch,1L,3L,s$control))
  }
  U <- rbind(c(-1,0),c(0,1),c(0,-1),c(1,0)); edges <- qga.path.edges(U)
  s <- qga.state(req(),control_test(function(a,b,t)list(length=1,error_estimate=0)),rng_test())
  batch <- qga.batch(s,edges)
  expect_identical(e$qga.dijkstra(U,edges,batch,1L,4L,s$control),qga.dijkstra(U,edges,batch,1L,4L,s$control))
  expect_null(e$qga.dijkstra(U,edges[1],batch,1L,4L,s$control))
  s$control$poll <- budget_failure
  expect_error(e$qga.dijkstra(U,edges,batch,1L,4L,s$control),class="qgs_budget")
})
test_that("native kernel keeps the R integration values and uncertainty estimates", {
  qgc.install(e,n,globalenv()); on.exit(restore.runtime(),add=TRUE)
  set.seed(72)
  for(i in 1:50) {
    a <- runif(2,-.5,.5);b <- runif(2,-.5,.5)
    forms <- list(diag(c(8,-2)))
    calls.r <- calls.c <- 0L
    r <- original.runtime$qgs.kernel(a,b,forms,1,i%%2==0,function()NULL,function(k)calls.r<<-calls.r+k)
    cpp <- qgs.kernel(a,b,forms,1,i%%2==0,function()NULL,function(k)calls.c<<-calls.c+k)
    expect_identical(cpp,r);expect_identical(calls.c,calls.r)
  }
  restore.runtime()
})
test_that("complete flat and saddle searches retain paths, decisions and streams", {
  for(case in c("flat2_box","saddle2_disk")) for(id in c("sensitivity_vertex","sensitivity_local_graph")) {
    r <- req(case, if(case=="flat2_box")"grid_direction" else "ab")
    r$parameters <- list(neighborhood="neighbors",cohort="epochs")
    restore.runtime(); reference <- source(file.path(home,"solvers",paste0(id,".R")))$value
    a <- qgs.execute(reference,r,persist.state=function(state)NULL)
    native <- qgc.adapter(home,id)
    b <- qgs.execute(native,r,persist.state=function(state)NULL)
    expect_identical(b$status,a$status);expect_identical(b$termination,a$termination)
    expect_identical(b$incumbent$candidate,a$incumbent$candidate)
    expect_identical(b$adapter_state$rng_state,a$adapter_state$rng_state)
    expect_identical(b$counters$edge_calls,a$counters$edge_calls)
    expect_identical(lapply(b$history,`[[`,"candidate"),lapply(a$history,`[[`,"candidate"))
    expect_identical(qgs.audit(b$incumbent$candidate,r)$status,"passed")
    restore.runtime()
  }
})
})
cat("Native backend tests passed.\n")
