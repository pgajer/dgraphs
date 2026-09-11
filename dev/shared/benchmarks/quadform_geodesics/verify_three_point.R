#!/usr/bin/env Rscript
# Targeted development verification, not the frozen calibration campaign.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L)
script <- normalizePath(sub("^--file=", "", grep("^--file=",commandArgs(),value=TRUE)[1]))
home <- dirname(script); output <- args[1L]
stopifnot(!file.exists(output), dir.exists(dirname(output)))
output <- file.path(normalizePath(dirname(output),mustWork=TRUE),basename(output))
project <- normalizePath(file.path(home,"../../../.."),mustWork=TRUE)
if (startsWith(output,paste0(project,"/"))) stop("Verification output must be outside the package checkout")
stopifnot(dir.create(output))
helpers <- normalizePath(file.path(home,"../../fixtures/quadform_geodesics/collection.R"))
source(helpers); source(file.path(home,"interface.R")); source(file.path(home,"runner.R"))
collection <- qg.read(file.path(dirname(helpers),"v1"))
methods <- lapply(c("three_point_vertex","three_point_local_graph"),function(id)
  list(id=id,file=paste0("solvers/",id,".R"),sources=c("solvers/adaptive/common.R",
    "solvers/adaptive/three_point.R",if(id=="three_point_local_graph")"solvers/adaptive/local_graph.R")))
plan <- list()
for(case in c("flat2_box","paraboloid2_high_curvature","saddle2_disk"))
  for(seed in if(case=="paraboloid2_high_curvature")c("4101","4102","4103") else "4101")
    for(direction in c("forward","reverse")) for(method in methods)
      plan[[length(plan)+1L]] <- list(case=case,pair=if(case=="flat2_box")"grid_direction" else "ab",
        seed=seed,direction=direction,method=method,reproduction=FALSE)
# Repeat two complete runs to test seeded reproducibility in fresh processes.
for(method in methods) plan[[length(plan)+1L]] <- list(case="paraboloid2_high_curvature",pair="ab",
  seed="4101",direction="forward",method=method,reproduction=TRUE)
sources <- list()
for(method in methods) sources <- c(sources,qgs.sources(home,method,helpers))
sources <- c(sources,list(list(path=script,sha256=digest::digest(file=script,algo="sha256"))))
sources <- sources[!duplicated(vapply(sources,`[[`,"","path"))]
qgs.write(list(configuration="qg-three-point-center-v1",plan=plan,sources=sources,
  limits=list(seconds=120,edge_calls=200000,rss_mib=512,max_vertices=257),
  purpose="Targeted R verification; no calibration acceptance or C++ performance claim",
  session=capture.output(sessionInfo()),python=Sys.getenv("RETICULATE_PYTHON")),file.path(output,"manifest.json"))
summary <- list()
for(i in seq_along(plan)) {
  job <- plan[[i]]; method <- job$method; d <- file.path(output,sprintf("%03d",i)); dir.create(d)
  r <- qgs.request(collection,job$case,job$pair,job$direction,job$seed)
  r$method_id <- method$id; r$config_id <- "qg-three-point-center-v1"
  qgs.binary(r,file.path(d,"request.rds")); qgs.write(sources,file.path(d,"sources.json"))
  cat("START",i,method$id,job$case,job$direction,job$seed,"\n"); flush.console()
  record <- qgs.job(home,helpers,file.path(home,method$file),method,r,d,sources)
  qgs.binary(record,file.path(d,"record.rds"))
  search <- record$search
  num <- function(x) if(is.numeric(x)&&length(x)==1L)x else NA_real_
  txt <- function(x) if(is.character(x)&&length(x)==1L)x else "unavailable"
  values <- vapply(search$history,function(z)z$candidate$length,0)
  summary[[i]] <- data.frame(job=i,method=method$id,case=job$case,direction=job$direction,
    seed=job$seed,reproduction=job$reproduction,status=txt(search$status),termination=txt(search$termination),
    initializer_audit=txt(record$audits$initializer$status),terminal_audit=txt(record$final_audit$status),
    initial_length=num(record$audits$initializer$length),final_length=num(record$final_audit$length),
    epochs=num(search$adapter_state$sweep),vertices=if(!is.null(search$incumbent))nrow(search$incumbent$candidate$path$vertices) else NA_integer_,
    monotone=length(values)>0L&&all(diff(values)<=1e-10*r$length_scale),
    calls=num(search$counters$edge_calls),seconds=num(search$counters$algorithm_seconds),
    peak_mib=num(record$search_monitor$peak_rss_bytes)/1024^2)
  write.csv(do.call(rbind,summary),file.path(output,"summary.csv"),row.names=FALSE)
  cat("END",i,txt(search$status),txt(search$termination),txt(record$final_audit$status),
      "length",num(record$final_audit$length),"\n"); flush.console()
}
qgs.verify.sources(sources)
invisible(qg.read(file.path(dirname(helpers),"v1")))
cat("Verification calculations complete; inspect summary.csv before drawing conclusions.\n")
