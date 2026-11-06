## ----setup, include=FALSE-----------------------------------------------------
knitr::opts_chunk$set(collapse=TRUE,comment='#>',fig.width=7,fig.height=5,
                     warning=FALSE,message=FALSE)
# Prefer the current source tree; otherwise use the installed package assets.
asset <- function(...) {
  local <- file.path('..','inst',...)
  if(file.exists(local)) return(local)
  system.file(...,package='dgraphs',mustWork=TRUE)
}
source(asset('doc-tools','fermat-surfaces-snapshot.R'),local=TRUE)
snapshot <- fermat_surfaces_snapshot(asset('extdata','fermat-surfaces','snapshot.rds'))
metrics <- snapshot$metrics

## ----sampler, eval=FALSE------------------------------------------------------
# library(dgraphs)
# geometry <- synthetic.quadform(2, 3, forms=list(diag(c(1,-1))))
# sampling <- synthetic.sampling.quadform.lab('disk',extent=1,mode='area')
# sample <- sample.synthetic.geometry(geometry,sampling,n=150,seed=4101)
# X <- sample$predictors

## ----distances, eval=FALSE----------------------------------------------------
# result <- fermat.distances(points=X,p=2,backend='implicit',rooted=FALSE,
#                           return.graph=TRUE)
# D <- result$distances
# graph <- result$graph
# head(graph.edges(graph))
# result$metadata

## ----sknn, eval=FALSE---------------------------------------------------------
# g <- create.fermat.sknn.graph(X,k=5,p=2,rooted=FALSE)

## ----distance-table, echo=FALSE-----------------------------------------------
knitr::kable(metrics[metrics$k==0,c('shape','p','n','distance_scale',
 'distance_nrmse','distance_spearman')],digits=3,row.names=FALSE,
 col.names=c('Example','p','Samples','Scale','Scaled error','Rank correlation'))

## ----graph-error, echo=FALSE--------------------------------------------------
old <- par(mfrow=c(1,3),mar=c(4,4,2,1))
for(shape in unique(metrics$shape)) {
 z<-metrics[metrics$shape==shape & metrics$k>0,]
 plot(range(z$k),c(0,1.3*max(c(0,z$restriction_nrmse),na.rm=TRUE)),type='n',xlab='Neighbors k',
      ylab='Graph restriction error',main=shape)
 for(p in 1:4){q<-z[z$p==p,];lines(q$k,q$restriction_nrmse,col=p,pch=p,type='b')}
 legend('topright',legend=paste('p =',1:4),col=1:4,lty=1,pch=1:4,bty='n',cex=.7)
}
par(old)

## ----coverage, echo=FALSE-----------------------------------------------------
z<-metrics[metrics$components>1,]
coverage <- do.call(rbind,lapply(split(z,list(z$shape,z$p),drop=TRUE),function(q) {
 data.frame(Example=q$shape[1],p=q$p[1],
            Retained=paste(range(q$retained),collapse='–'),
            Components=paste(range(q$components),collapse='–'))
}))
knitr::kable(coverage,row.names=FALSE,
 col.names=c('Example','p','Retained samples: min–max','Components: min–max'))

## ----overlay, echo=FALSE, fig.alt="Saved saddle observations, aligned MDS coordinates and Fermat path edges shown in an orthographic view with equal coordinate units."----
if (identical(Sys.getenv('DGRAPHS_STATIC_VIGNETTES','true'),'true')) {
  fermat_surfaces_saved_plot(snapshot)
} else {
  fermat_surfaces_saved_widget(snapshot)
}

## ----chord-audit,echo=FALSE---------------------------------------------------
z <- snapshot$chords
z <- z[match(c('paraboloid','saddle','helix'),z$shape),]
knitr::kable(z[,c('shape','pairs','scale','raw_nrmse','scaled_nrmse',
                  'median_ratio','max_ratio')],digits=4,row.names=FALSE,
 col.names=c('Example','Pairs','Scale','Raw error','Scaled error','Median ratio','Maximum ratio'))

## ----reference-success,echo=FALSE---------------------------------------------
z <- snapshot$checks
z <- z[match(c('paraboloid','saddle','helix'),z$shape),]
z$method <- c('Clairaut (same 1,000 pairs)','Original shooting check (80 pairs)','Analytic identity')
knitr::kable(z[,c('shape','attempted','finite','failed','method')],row.names=FALSE,
 col.names=c('Example','Attempted','Finite','Failed','Check'))

## ----clairaut-comparison,echo=FALSE-------------------------------------------
z <- snapshot$comparisons
ok <- is.finite(z$best)&is.finite(z$other)&z$other>0
delta <- z$relative_difference[ok]
knitr::kable(data.frame(Pairs=sum(ok),Median.signed=median(delta),
 Maximum.absolute=max(abs(delta))),digits=6)
z <- metrics[metrics$shape=='paraboloid' & metrics$k==0,]
knitr::kable(z[,c('p','distance_nrmse','clairaut_distance_nrmse')],digits=5,row.names=FALSE,
 col.names=c('p','Best of six','Clairaut'))

## ----snapshot-provenance------------------------------------------------------
snapshot$provenance[c('experiment','results_date','sample_seed',
                      'samples_per_shape','reference_pairs_per_shape',
                      'mds_backend','mds_epochs')]

