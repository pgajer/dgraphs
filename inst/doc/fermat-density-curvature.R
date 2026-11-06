## ----setup,include=FALSE------------------------------------------------------
knitr::opts_chunk$set(collapse=TRUE,comment='#>',message=FALSE,warning=FALSE,
                     out.width='100%',fig.align='center')
# Prefer this checkout's snapshot when rendering the maintained source.
bundle <- '../inst/extdata/fermat-density-curvature/benchmark.rds'
if(!file.exists(bundle)) bundle <- system.file('extdata','fermat-density-curvature',
                                              'benchmark.rds',package='dgraphs',mustWork=TRUE)
b <- readRDS(bundle); m <- b$metrics; s <- b$summary; power_data <- b$power_tuning
surface_names <- c(paraboloid_a1='Paraboloid, $a=1$',paraboloid_a2='Paraboloid, $a=2$',
 paraboloid_a4='Paraboloid, $a=4$',saddle_a1='Saddle, $a=1$',saddle_a2='Saddle, $a=2$',
 saddle_a4='Saddle, $a=4$',swiss_roll='Swiss roll')
helper <- '../inst/doc-tools/compact-figures.R'
if(!file.exists(helper)) helper <- system.file('doc-tools','compact-figures.R',package='dgraphs',mustWork=TRUE)
source(helper,local=TRUE)
figure <- function(name) knitr::include_graphics(dgraphs_document_figure(
  paste0('figures/fermat-density-curvature/',name,'.png')), rel_path=FALSE)

## ----small-sample,eval=FALSE--------------------------------------------------
# library(dgraphs)
# A <- diag(c(2,-2))
# geometry <- synthetic.quadform(2L,3L,forms=list(A))
# sampling <- synthetic.sampling.quadform.lab('disk',extent=1,mode='area')
# sample <- sample.synthetic.geometry(geometry,sampling,n=300L,seed=62117L)
# X <- sample$predictors
# endpoints <- 1:12
# D150 <- fermat.distances(points=X[1:150,],p=1.25,backend='implicit',
#                         sources=endpoints,targets=endpoints,rooted=FALSE)
# D300 <- fermat.distances(points=X,p=1.25,backend='implicit',
#                         sources=endpoints,targets=endpoints,rooted=FALSE)
# stopifnot(all(D300 <= D150 + 1e-10))

## ----small-graph,eval=FALSE---------------------------------------------------
# graph <- create.sknn.graph(X,k=10,neighbor.method='exact',
#                           connect.components=FALSE)
# edges <- graph.edges(graph)
# ig <- igraph::graph_from_data_frame(edges[,1:2],directed=FALSE,
#                                   vertices=data.frame(name=seq_len(nrow(X))))
# Dknn <- igraph::distances(ig,v=endpoints,to=endpoints,weights=edges$length)
# igraph::components(ig)$no

## ----surfaces,echo=FALSE,fig.alt='Paraboloid and saddle patches at three coefficients, with a common vertical range within each family.'----
figure('surfaces')

## ----interactive-surfaces,echo=FALSE------------------------------------------
have.ivue <- !identical(Sys.getenv('DGRAPHS_STATIC_VIGNETTES','true'),'true') &&
 requireNamespace('ivue',quietly=TRUE) && requireNamespace('rgl',quietly=TRUE) &&
 requireNamespace('htmlwidgets',quietly=TRUE) && requireNamespace('htmltools',quietly=TRUE) &&
 all(c('plot3D.plain','layer3D.callback','layer3D.axes','camera.zup') %in% getNamespaceExports('ivue')) &&
 'limits' %in% names(formals(ivue::plot3D.plain))
if(have.ivue) {
 options(rgl.useNULL=TRUE)
 helper <- '../inst/doc-tools/fermat-surface-views.R'
 if(!file.exists(helper)) helper <- system.file('doc-tools','fermat-surface-views.R',package='dgraphs',mustWork=TRUE)
 source(helper,local=TRUE)
 surface_views <- readRDS(file.path(dirname(bundle),'surface-views.rds'))
 fermat_surface_gallery(surface_views)
} else {
 cat('The installed guide uses the static surface views in Figure 1. Interactive views are available when rebuilding with DGRAPHS_STATIC_VIGNETTES=false and the optional visualization packages.')
}

## ----coverage,echo=FALSE------------------------------------------------------
q <- subset(m,family=='euclidean_knn')
coverage <- do.call(rbind,lapply(split(q,q$policy),function(x)
 data.frame(Rule=x$policy[1],Minimum.coverage=100*min(x$test_pairs/x$requested_test),
            Disconnected=sum(x$components>1))))
knitr::kable(coverage,row.names=FALSE,digits=1,
 col.names=c('$k$ rule','Minimum evaluation coverage (%)','Disconnected conditions'))

## ----paraboloid,echo=FALSE,fig.alt='Fermat distance errors across sample sizes on three paraboloids; intermediate powers outperform ambient chords.'----
figure('paraboloid_fermat')

## ----saddle,echo=FALSE,fig.alt='Fermat distance errors on three saddles, showing the benefit of a larger intermediate power on the strongest saddle.'----
figure('saddle_fermat')

## ----roll,echo=FALSE,fig.alt='Swiss-roll errors across sample sizes: larger Fermat powers suppress shortcuts more effectively than powers close to one.'----
figure('swiss_roll_fermat')

## ----winners,echo=FALSE-------------------------------------------------------
z <- subset(s,n==2400 & family=='complete' & p>1)
w <- do.call(rbind,lapply(split(z,z$id),function(x)x[which.min(x$mean),]))
knitr::kable(data.frame(Surface=unname(surface_names[w$id]),Power=w$p,
 Fermat=100*w$mean,Ambient=100*w$ambient,Wins=w$wins),row.names=FALSE,digits=2,
 col.names=c('Surface','Best tested $p$','Fermat error (%)','Ambient error (%)','Wins out of 5'))

## ----ratios,echo=FALSE,fig.alt='Geodesic-to-chord ratios on seven surfaces, with a logarithmic ratio axis and a long Swiss-roll tail.'----
figure('chord_distortion')

## ----knn,echo=FALSE,fig.alt='Euclidean symmetric kNN errors on paraboloids, saddles and the Swiss roll, with ambient baselines and conditional intervals.'----
figure(c('paraboloid_knn','saddle_knn','swiss_roll_knn'))

## ----clairaut,echo=FALSE,fig.alt='Paraboloid errors using Clairaut references, showing reduced apparent error on the strongest patch.'----
figure('paraboloid_clairaut')

## ----paired,echo=FALSE,fig.alt='Paired Fermat-minus-ambient errors at 2,400 observations, showing replicate differences and conditional intervals.'----
figure('paired_difference')

## ----power-full,echo=FALSE,fig.alt='Full cross-validation curves for all six quadforms, including ambient power one and the selected interior minima.'----
figure('power_tuning_full')

## ----power-near,echo=FALSE,fig.alt='Enlarged neighborhoods of each tuning minimum, displaying relative excess error and a one-percent threshold.'----
figure('power_tuning_near')

## ----power-choices,echo=FALSE-------------------------------------------------
x<-subset(power_data$selection,reference=='best_of_six')
z<-subset(power_data$transfer_summary,reference=='best_of_six' & method=='selected_best_of_six')
at_n<-function(n)z$mean[match(paste(x$id,n),paste(z$id,z$n))]
knitr::kable(data.frame(Surface=surface_names[x$id],`Selected $p$`=sprintf('%.3f',x$p),
 `Within 1% of minimum`=sprintf('%.3f–%.3f',x$near_min,x$near_max),
 `Test error, $n=300$ (%)`=round(100*at_n(300),2),
 `Test error, $n=2400$ (%)`=round(100*at_n(2400),2),check.names=FALSE),row.names=FALSE)

## ----power-transfer,echo=FALSE,fig.alt='Frozen selected-power error across five sample sizes, with ambient, fixed powers, and ordinary Euclidean neighborhood-graph comparisons.'----
figure('power_transfer')

## ----power-difference,echo=FALSE,fig.alt='Paired selected-power minus fixed power 1.25 errors, showing a reversal on the intermediate saddle as sample size increases.'----
figure('power_transfer_difference')

## ----power-clairaut-tuning,echo=FALSE,fig.alt='Paraboloid cross-validation curves against best-of-six and Clairaut references, with separate selected powers.'----
figure('power_clairaut_tuning')

## ----power-clairaut-table,echo=FALSE------------------------------------------
x<-subset(power_data$selection,reference=='clairaut')
a<-subset(power_data$selection,reference=='best_of_six')
z<-subset(power_data$transfer_summary,reference=='clairaut' & n==2400)
value<-function(method) {q<-z[z$method==method,];round(100*q$mean[match(x$id,q$id)],2)}
knitr::kable(data.frame(Surface=surface_names[x$id],
 `Best-of-six $p$`=sprintf('%.3f',a$p[match(x$id,a$id)]),
 `Clairaut $p$`=sprintf('%.3f',x$p),
 `Best-of-six choice error (%)`=value('selected_best_of_six'),
 `Clairaut choice error (%)`=value('selected_clairaut'),check.names=FALSE),row.names=FALSE)

## ----power-clairaut-transfer,echo=FALSE,fig.alt='Sample-size transfer curves scored against Clairaut, comparing powers selected with each reference and the unchanged baselines.'----
figure('power_clairaut_transfer')

## ----read-snapshot,eval=FALSE-------------------------------------------------
# path <- system.file('extdata','fermat-density-curvature','benchmark.rds',
#                     package='dgraphs',mustWork=TRUE)
# benchmark <- readRDS(path)
# nrow(benchmark$metrics)       # 2,100 condition-level records
# nrow(benchmark$references)    # 10,500 main reference pairs
# benchmark$power_tuning$selection
# nrow(benchmark$power_tuning$transfer_metrics)  # 1,275 follow-up records
# benchmark$provenance

## ----copy-workflow,eval=FALSE-------------------------------------------------
# src <- system.file('examples','fermat-density-curvature',package='dgraphs',
#                    mustWork=TRUE)
# work <- file.path(tempdir(),'fermat-recovery-reproduction')
# dir.create(work,showWarnings=FALSE)
# file.copy(list.files(src,full.names=TRUE),work,overwrite=FALSE)

