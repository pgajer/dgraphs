args <- commandArgs(TRUE)
if(length(args)!=1L)stop("Supply an empty output directory outside the repository")
script <- normalizePath(sub("^--file=","",grep("^--file=",commandArgs(),value=TRUE)[1L]))
repo <- normalizePath(file.path(dirname(script),"../../../.."))
out <- normalizePath(args[[1]],mustWork=FALSE)
if(startsWith(paste0(out,"/"),paste0(repo,"/")))stop("Output must be outside the repository")
if(dir.exists(out) && length(list.files(out,all.files=TRUE,no..=TRUE)))stop("Output must be empty")
dir.create(out,recursive=TRUE,showWarnings=FALSE)
solve <- getFromNamespace("quadform_geodesics", "dgraphs")
fixture <- jsonlite::fromJSON(file.path(repo,"dev/shared/fixtures/quadform_geodesics/v1/collection.json"), simplifyVector=FALSE)
methods <- c("single_point","local_network","best_of_six","grid_dijkstra","paraboloid_clairaut")
records <- list(); checks <- list(); index <- 0L
record_check <- function(case,pair,method,name,pass,error=NA_real_,required=TRUE) {
  checks[[length(checks)+1L]] <<- data.frame(case,pair,method,check=name,pass,error,required)
}
path_length <- function(U,A) {
  if(nrow(U)<2)return(0)
  sum(vapply(seq_len(nrow(U)-1L),function(i){p<-U[i,];h<-U[i+1L,]-p
    integrate(function(t)sqrt(sum(h*h)+(2*sum(p*(A%*%h))+2*t*sum(h*(A%*%h)))^2),
      0,1,rel.tol=1e-10,abs.tol=1e-14,subdivisions=1000L)$value},0))
}
for(case in fixture$cases) {
  eligible <- case$geometry$intrinsic_dim==2 && length(case$geometry$forms)==1 &&
    case$geometry$frame=="canonical" && all(unlist(case$geometry$offset)==0)
  if(eligible) {
    A<-matrix(unlist(case$geometry$forms[[1]]),2,byrow=TRUE)
    domain<-lapply(case$domain,unlist)
  }
  for(p in case$pairs) for(method in methods) {
    lengths<-numeric()
    for(reverse in c(FALSE,TRUE)) {
      index<-index+1L;reason<-"interface_requires_canonical_two_dimensional_single_form"
      status<-"unsupported";len<-NA_real_;seconds<-0
      if(eligible) {
        from<-as.double(unlist(if(reverse)p$to else p$from));to<-as.double(unlist(if(reverse)p$from else p$to))
        control<-switch(method,grid_dijkstra=list(grid_size=c(17L,17L)),paraboloid_clairaut=list(),
          list(max_epochs=4L,initial_edges=8L,candidates=16L,cache_edges=0L,
               length_scale=case$length_scale,seed=731L))
        start<-proc.time()[[3]]
        result<-tryCatch(solve(A,from,to,domain,method,control,return.paths=TRUE)$results[[1]],error=identity)
        seconds<-proc.time()[[3]]-start
        if(inherits(result,"error")) {status<-"input_error";reason<-conditionMessage(result)} else {
          status<-result$status;reason<-result$termination;len<-result$length
          if(status %in% c("candidate","partial")) {
            tol<-1e-12*case$length_scale+1e-8*max(abs(len),abs(p$bounds$segment_upper))
            record_check(case$id,p$id,method,"finite_nonnegative",is.finite(len)&&len>=0)
            record_check(case$id,p$id,method,"chord_lower",len+tol>=p$bounds$chord_lower)
            record_check(case$id,p$id,method,"segment_upper",len<=p$bounds$segment_upper+tol)
            U<-result$path
            record_check(case$id,p$id,method,"endpoints",identical(unname(U[1,]),from)&&identical(unname(U[nrow(U),]),to))
            inside<-if(domain$kind=="ball")rowSums(sweep(U,2,domain$center)^2)<=domain$radius^2*(1+1e-13) else
              apply(sweep(U,2,domain$lower)>=-tol & sweep(U,2,domain$upper)<=tol,1,all)
            record_check(case$id,p$id,method,"sampled_domain",all(inside))
            if(!is.null(p$exact$value))record_check(case$id,p$id,method,"known_distance",abs(len-p$exact$value)<=tol,abs(len-p$exact$value))
            if(method %in% c("grid_dijkstra","paraboloid_clairaut")) {
              if(result$path_representation=="analytic_clairaut_curve") {
                q<-as.list(result$curve_parameters)
                measured<-q$t_span*integrate(function(s)sqrt(1+(q$k*q$c)^2+(q$k*(q$t_from+s*q$t_span))^2),
                    0,1,rel.tol=1e-10,abs.tol=1e-13,subdivisions=1000L)$value
              } else measured<-path_length(U,A)
              record_check(case$id,p$id,method,"independent_length",abs(len-measured)<=tol,abs(len-measured))
            }
          }
        }
      }
      lengths<-c(lengths,len)
      records[[index]]<-data.frame(case=case$id,pair=p$id,method,reverse,status,termination=reason,length=len,seconds)
    }
    if(all(is.finite(lengths)))record_check(case$id,p$id,method,"reversal_length",
      abs(diff(lengths))<=1e-12*case$length_scale+1e-8*max(lengths),abs(diff(lengths)),
      required=method %in% c("grid_dijkstra","paraboloid_clairaut"))
  }
  cat(case$id,"completed\n");flush.console()
}
records<-do.call(rbind,records)
matched<-merge(subset(records,method=="paraboloid_clairaut" & status=="candidate"),
  subset(records,method!="paraboloid_clairaut" & status=="candidate"),
  by=c("case","pair","reverse"),suffixes=c("_clairaut","_polyline"))
for(i in seq_len(nrow(matched))) {
  row<-matched[i,];difference<-row$length_clairaut-row$length_polyline
  record_check(row$case,row$pair,row$method_polyline,"not_shorter_than_clairaut",
    difference<=1e-12+1e-8*row$length_clairaut,difference)
}
checks<-do.call(rbind,checks)
write.csv(records,file.path(out,"fixture-results.csv"),row.names=FALSE)
write.csv(checks,file.path(out,"fixture-checks.csv"),row.names=FALSE)
print(with(records,table(method,status)));print(subset(checks,required & !pass))
cat(nrow(records),"requests;",sum(checks$required),"required checks;",
  sum(checks$required & !checks$pass),"failed required checks;",
  sum(!checks$required),"stochastic reversal observations;",
  sum(!checks$required & !checks$pass),"differ beyond the deterministic tolerance\n")
stopifnot(all(checks$pass[checks$required]),!any(records$status=="input_error"))
