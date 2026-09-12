qgc.method <- function(id) {
  method <- qgx.method(id)
  method$file <- paste0("native/",if(id=="sensitivity_vertex")"vertex" else "local_graph",".R")
  method$sources <- unique(c(method$sources,"native/core.cpp","native/load.R",
    "native/parallel.R","native/run.R","native/report.R"))
  method
}
qgc.request <- function(collection, job) {
  r <- qgx.request(collection,job)
  r$config_id <- paste0("cpp-core-v1/",r$config_id)
  r$backend <- "cpp-core-v1"
  r
}
qgc.csv <- function(x,path) {
  temporary <- tempfile(".csv-",tmpdir=dirname(path))
  on.exit(unlink(temporary))
  write.csv(x,temporary,row.names=FALSE)
  stopifnot(file.rename(temporary,path))
}
qgc.sources <- function(home,helpers) {
  sources <- unlist(lapply(qgx.methods,function(id)qgs.sources(home,qgc.method(id),helpers)),recursive=FALSE)
  sources[!duplicated(vapply(sources,`[[`,"","path"))]
}
qgc.environment <- function() list(R=R.version.string, platform=R.version$platform,
  packages=vapply(c("Rcpp","digest","jsonlite","ps","processx","callr","reticulate"),
    function(p)as.character(utils::packageVersion(p)),""),
  python=Sys.getenv("RETICULATE_PYTHON"), build_cache=Sys.getenv("QGC_BUILD_CACHE"),
  compiler_flags="-ffp-contract=off -fno-fast-math")
qgc.same.run <- function(reference,actual) {
  a <- reference$search; b <- actual$search
  diagnostic <- function(s) lapply(s$adapter_state$diagnostics,function(d) {
    d$counters <- NULL;d$before <- NULL;d$after <- NULL;d
  })
  counters <- setdiff(names(a$counters),"algorithm_seconds")
  tests <- c(status=identical(a$status,b$status),termination=identical(a$termination,b$termination),
    paths=identical(lapply(a$history,`[[`,"candidate"),lapply(b$history,`[[`,"candidate")),
    initializer=identical(a$initializer$candidate,b$initializer$candidate),
    final=identical(a$incumbent$candidate,b$incumbent$candidate),
    random_streams=identical(a$adapter_state$rng_state,b$adapter_state$rng_state),
    diagnostics=identical(diagnostic(a),diagnostic(b)),
    counts=identical(a$counters[counters],b$counters[counters]),
    audit=identical(actual$final_audit$status,"passed"))
  tests
}
qgc.run <- function(home,output,plan,workers,purpose,resume=FALSE) {
  stopifnot(workers %in% 1:12,nrow(plan)>0L,!anyDuplicated(plan$job))
  home <- normalizePath(home); project <- normalizePath(file.path(home,"../../../.."))
  stopifnot(dir.exists(dirname(output)))
  output <- file.path(normalizePath(dirname(output)),basename(output))
  if (file.exists(output)) output <- normalizePath(output)
  if (output==project||startsWith(output,paste0(project,"/"))) stop("Private output required")
  helpers <- normalizePath(file.path(home,"../../fixtures/quadform_geodesics/collection.R"))
  collection <- qg.read(file.path(dirname(helpers),"v1"))
  sources <- qgc.sources(home,helpers)
  manifest <- list(backend="cpp-core-v1",purpose=purpose,workers=workers,plan=plan,sources=sources,
    collection_sha256=attr(collection,"sha256"),environment=qgc.environment(),
    limits=lapply(qgx.cohorts,qgx.limits),search_return_grace_seconds=5,
    timing="Concurrent cold-worker wall time; never pool with serial R timing distributions")
  if (resume) {
    stopifnot(identical(readRDS(file.path(output,"manifest.rds")),manifest))
  } else {
    stopifnot(!file.exists(output),dir.create(output))
    qgs.binary(manifest,file.path(output,"manifest.rds"));qgs.write(manifest,file.path(output,"manifest.json"))
    qgc.csv(plan,file.path(output,"plan.csv"))
    for(s in sources) {
      relative <- if(startsWith(s$path,paste0(home,"/")))substring(s$path,nchar(home)+2L) else "collection.R"
      dest <- file.path(output,"sources",relative);dir.create(dirname(dest),recursive=TRUE,showWarnings=FALSE)
      stopifnot(file.copy(s$path,dest),identical(digest::digest(file=dest,algo="sha256"),s$sha256))
    }
  }
  lock <- file.path(output,"coordinator.lock")
  if(!dir.create(lock,showWarnings=FALSE))stop("A coordinator lock already exists")
  on.exit(unlink(lock,recursive=TRUE),add=TRUE)
  qgs.write(list(pid=Sys.getpid(),started_utc=format(Sys.time(),tz="UTC",usetz=TRUE)),file.path(output,"coordinator.json"))
  # Compile once before workers launch; child processes only load the cached build.
  qgc.load(home);invisible(qgs.clock())
  rows <- lapply(seq_len(nrow(plan)),function(i)qgx.row(plan[i,]))
  trajectories <- vector("list",nrow(plan));comparisons <- list();active <- list();pending <- integer()
  consume <- function(i,record) {
    rows[[i]] <<- qgx.row(plan[i,],record,collection)
    trajectories[[i]] <<- qgx.trajectory(plan[i,],record)
    if("reference_record" %in% names(plan) && nzchar(plan$reference_record[i]) && plan$cohort[i]!="seconds") {
      ref <- readRDS(plan$reference_record[i]);tests <- qgc.same.run(ref,record)
      comparisons[[as.character(i)]] <<- cbind(plan[i,],as.data.frame(as.list(tests)),all_passed=all(tests))
    }
  }
  for(i in seq_len(nrow(plan))) {
    path <- file.path(output,sprintf("%05d",plan$job[i]),"record.rds")
    if(file.exists(path)) {
      record <- readRDS(path);stopifnot(identical(record$request,qgc.request(collection,plan[i,])))
      consume(i,record)
    } else pending <- c(pending,i)
  }
  started <- qgs.clock();max_supervisor_rss <- 0
  cleanup <- function() {
    for(x in active) if(x$process$is_alive()) x$process$kill_tree()
  }
  on.exit(cleanup(),add=TRUE,after=FALSE)
  update <- function() {
    allrows <- qgx.initializer.gate(do.call(rbind,rows))
    qgc.csv(allrows,file.path(output,"runs.csv"))
    qgs.write(list(planned=nrow(plan),recorded=sum(allrows$run_status=="recorded"),
      available=sum(allrows$available),active=length(active),pending=length(pending),workers=workers,
      updated_utc=format(Sys.time(),tz="UTC",usetz=TRUE),elapsed_seconds=qgs.clock()-started,
      coordinator_peak_sampled_mib=max_supervisor_rss),file.path(output,"progress.json"))
  }
  update()
  repeat {
    while(length(active)<workers&&length(pending)&&!file.exists(file.path(output,"STOP_AFTER_CURRENT"))) {
      i <- pending[1L];pending <- pending[-1L]
      dir <- file.path(output,sprintf("%05d",plan$job[i]))
      if(dir.exists(dir))stop("Interrupted attempt retained; explicit review required: ",dir)
      stopifnot(dir.create(dir));r <- qgc.request(collection,plan[i,]);method <- qgc.method(plan$method[i])
      qgs.verify.sources(sources);qgs.binary(r,file.path(dir,"request.rds"))
      process <- callr::r_bg(function(home,helpers,method,request,directory,sources) {
        source(helpers);source(file.path(home,"interface.R"));source(file.path(home,"runner.R"))
        source(file.path(home,"experiments/sensitivity.R"))
        record <- qgx.supervisor(home)(home,helpers,file.path(home,method$file),method,request,directory,sources)
        qgs.binary(record,file.path(directory,"record.rds"))
        TRUE
      },args=list(home,helpers,method,r,dir,sources),supervise=TRUE,
        stdout=file.path(dir,"supervisor.stdout.log"),stderr=file.path(dir,"supervisor.stderr.log"),
        user_profile=FALSE,env=c(OMP_NUM_THREADS="1",OPENBLAS_NUM_THREADS="1",MKL_NUM_THREADS="1"))
      active[[as.character(i)]] <- list(process=process,index=i,request=r,directory=dir)
    }
    changed <- FALSE
    for(key in names(active)) {
      x <- active[[key]]
      if(!x$process$is_alive()) {
        error <- tryCatch({x$process$get_result();NULL},error=conditionMessage)
        path <- file.path(x$directory,"record.rds")
        if(file.exists(path))record <- readRDS(path) else {
          record <- list(request=x$request,search=list(status="failed",termination="supervisor_failure",diagnostic=error),
            final_audit=list(status="unavailable"),end_to_end_seconds=NA_real_)
          qgs.binary(record,path)
        }
        consume(x$index,record);active[[key]] <- NULL;changed <- TRUE
        cat("END",x$index,"of",nrow(plan),record$search$status,record$search$termination,record$final_audit$status,"\n")
        flush.console()
      }
    }
    rss <- tryCatch(unname(ps::ps_memory_info(ps::ps_handle())[["rss"]])/1024^2,error=function(e)0)
    max_supervisor_rss <- max(max_supervisor_rss,rss)
    if(changed)update()
    if(!length(active)&&(!length(pending)||file.exists(file.path(output,"STOP_AFTER_CURRENT"))))break
    Sys.sleep(.05)
  }
  qgs.verify.sources(sources);invisible(qg.read(file.path(dirname(helpers),"v1")))
  qgx.write.summaries(do.call(rbind,rows),do.call(rbind,trajectories),output)
  if(length(comparisons))qgc.csv(do.call(rbind,comparisons),file.path(output,"r-cpp-comparison.csv"))
  update()
  qgs.write(list(status=if(length(pending))"paused_between_runs" else "completed",
    finished_utc=format(Sys.time(),tz="UTC",usetz=TRUE),elapsed_seconds=qgs.clock()-started,
    workers=workers,remaining=length(pending)),file.path(output,"completion.json"))
  qgc.report(output)
  invisible(output)
}
