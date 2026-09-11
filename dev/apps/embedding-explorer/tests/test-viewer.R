options(rgl.useNULL=TRUE)
library(testthat)
app_root<-normalizePath(if(file.exists('R/viewer.R')) '.' else 'dev/apps/embedding-explorer')
source(file.path(app_root,'R/engine.R'));source(file.path(app_root,'R/viewer.R'))
test_that('linked scene construction handles empty and full selections and graph routes', {
  s<-default_spec();s$n<-60L;c<-make_experiment(s)$cloud;g<-make_neighbor_graph(c$observed,8)
  colors<-cloud_colors(c)$colors
  bounds<-as.matrix(expand.grid(c(-2,2),c(-2,2),c(-2,2)))
  cfg<-list(mesh=TRUE,mesh_alpha=.2,edges=TRUE,axes=TRUE,surface=TRUE,surface_alpha=.15,
    displacements=TRUE,segments=20,size=3,mouse='brush',bounds=bounds)
  path<-route_vertices(g,60,1,60);expect_true(length(path)>1)
  expect_length(route_vertices(g,60,NA_integer_,60),0)
  for(sel in list(integer(),1:60)) {
    w<-withCallingHandlers(lab_widget(c$truth,c,cfg,colors,sel,graph=g,other=c$truth+.1,route=path,panel='overlay'),
      warning=function(w) {if(grepl("shinySelectionInput.*only used in Shiny",conditionMessage(w))) invokeRestart('muffleWarning')})
    expect_s3_class(w,'rglWebGL');expect_s3_class(w,'htmlwidget')
  }
})
cat('Geometry Lab renderer checks completed.\n')
