library(Rcpp)
a<-commandArgs(TRUE);dll<-dyn.load(a[1]);f<-getNativeSymbolInfo('ian_projection_probe',dll)$address;x<-.Call(f,0L);e<-tryCatch(.Call(f,1L),error=identity)
checks<-list(minimum.exact=identical(x$minimum,-2147483648),above.maximum.exact=identical(x$above_maximum,2147483648),double.limit.exact=identical(x$exact_double_limit,2^53),inexact.refused=inherits(e,'error')&&grepl('represented exactly',conditionMessage(e)))
jsonlite::write_json(list(checks=checks,passed=all(unlist(checks)),values=x,engine.calls=0),a[2],auto_unbox=TRUE,pretty=TRUE,digits=NA);if(a[3]=='after')stopifnot(all(unlist(checks)))
