cloud_colors <- function(cloud,mode='u',fit=NULL) {
  value<-switch(mode,u=cloud$uv[,1],v=cloud$uv[,2],height=cloud$truth[,3],
    noise=sqrt(rowSums((cloud$observed-cloud$truth)^2)),
    error=if(!is.null(fit)) sqrt(rowSums((align_coords(fit$coords,cloud$truth)$coords-cloud$truth)^2)) else rep(0,nrow(cloud$truth)),
    cloud$uv[,1])
  limits<-range(value);p<-grDevices::hcl.colors(256,'Viridis')
  index<-if(diff(limits)>0) 1+floor(255*(value-limits[1])/diff(limits)) else rep(128,length(value))
  list(colors=p[index],values=value,limits=limits)
}
route_vertices <- function(graph,n,from,to) {
  if(is.null(graph)||length(from)!=1L||length(to)!=1L||is.na(from)||is.na(to)||from==to) return(integer())
  suppressWarnings(as.integer(igraph::shortest_paths(as_igraph(graph,n),from=from,to=to,
    weights=graph$weights,output='vpath')$vpath[[1]]))
}
draw_mesh <- function(coords,triangles,color,alpha) {
  if(nrow(triangles)) rgl::triangles3d(coords[as.vector(t(triangles)),,drop=FALSE],
    col=color,alpha=alpha,lit=FALSE,front='filled',back='filled',polygon_offset=c(1,1))
}
lab_widget <- function(coords,cloud,config,colors,selected,graph=NULL,other=NULL,
                       route=integer(),panel='truth',key='default',session_group='lab') {
  shared<-NULL;n<-nrow(coords)
  layers<-list()
  if(isTRUE(config$mesh)) layers<-c(layers,list(ivue::layer3D.mesh(cloud$triangles,
    col=if(panel=='overlay') '#287db3' else '#6a929e',alpha=config$mesh_alpha,
    edges=FALSE)))
  if(isTRUE(config$edges)&&!is.null(graph)) layers<-c(layers,list(ivue::layer3D.edges(graph$edges,col='#a1acb477',width=1)))
  if(length(route)>1) layers<-c(layers,list(ivue::layer3D.path(route,col='#dd7d24',width=4)))
  if(isTRUE(config$axes)) {
    extent<-pmax(apply(abs(config$bounds),2,max),.01)
    layers<-c(layers,list(ivue::layer3D.axes(limits=cbind(-extent,extent),width=1,cex=.8,col='#566978')))
  }
  layers<-c(layers,list(ivue::layer3D.callback(function(ctx) {
    if(isTRUE(config$surface)) draw_mesh(cloud$reference$coords,cloud$reference$triangles,'#b2bec9',config$surface_alpha)
    if(!is.null(other)) {
      draw_mesh(other,cloud$triangles,'#e89843',config$mesh_alpha)
      if(length(selected)) {
        if(length(selected)<nrow(other)) rgl::points3d(other[-selected,,drop=FALSE],col='#cbd5db',size=config$size,alpha=.22)
        rgl::points3d(other[selected,,drop=FALSE],col='#df8a2f',size=config$size+3,alpha=1)
      } else rgl::points3d(other,col='#df8a2f',size=config$size,alpha=.7)
    }
    if(isTRUE(config$displacements)) {
      dest<-other %||% cloud$truth
      ix<-unique(round(seq(1,n,length.out=min(n,config$segments))))
      lines<-rbind(coords[ix,,drop=FALSE],dest[ix,,drop=FALSE])
      order<-as.vector(rbind(seq_along(ix),seq_along(ix)+length(ix)))
      rgl::segments3d(lines[order,,drop=FALSE],col='#aa4c6c',alpha=.7,lwd=1.5)
    }
    # A shared cube gives every comparison the same orthographic spatial scale.
    if(!is.null(config$bounds)) rgl::points3d(config$bounds,col='white',alpha=0,size=1)
    rgl::par3d(mouseMode=c('none',if(config$mouse=='brush') 'selecting' else 'trackball','selecting','zoom','pull'))
    shared<<-lapply(unique(ctx$draw.ids$object),function(object) {
      rows<-ctx$draw.ids$row[ctx$draw.ids$object==object]
      rgl::rglShared(object,key=cloud$ids[rows],group=paste(session_group,panel,sep='-'),deselectedFade=1)
    })
  })))
  active<-length(selected)>0
  w<-ivue::plot3D.plain(coords,col=if(panel=='overlay') rep('#287db3',n) else colors,
    point.size=config$size,alpha=.85,highlight=if(active) seq_len(n)%in%selected else NULL,
    highlight.style=list(point.size=config$size+3,alpha=1),
    non.highlight.style=list(col='#cbd5db',alpha=.22),axes=FALSE,aspect='equal',
    height=config$height %||% 390,camera=ivue::camera.zup(elevation=25,turn=-125,zoom=.8),
    layers=layers,shiny.brush=paste0('brush_',panel),background.color='#ffffff')
  w<-rgl::rglwidget(attr(w,'ivue')$scene,shared=shared,shinyBrush=paste0('brush_',panel),
    width=NULL,height=config$height %||% 390)
  w$width<-'100%'
  htmlwidgets::onRender(w,'function(el,x,data){window.labBindWidget(el,data);}',data=list(
    cameraKey=key,commit=paste0('brush_commit_',panel),label=paste(panel,'3D geometry'),
    rows=n,selected=length(selected),panel=panel))
}

view_card <- function(panel,title,selector=NULL,height='390px') div(class='view-card',
  div(class='view-heading',span(class='panel-dot',toupper(substr(panel,1,1))),tags$strong(title)),
  if(!is.null(selector)) selector else div(class='truth-caption',if(panel=='overlay')
    'Corresponding meshes in shared display coordinates' else 'Known noiseless sample positions'),
  div(class='zoom-controls',tags$button(type='button',class='zoom-button',`data-zoom`='out',`aria-label`=paste('Zoom out',title),'−'),
    tags$output(class='zoom-value','100%'),tags$button(type='button',class='zoom-button',`data-zoom`='in',`aria-label`=paste('Zoom in',title),'+'),
    tags$button(type='button',class='zoom-reset',`data-zoom`='reset','Reset zoom')),
  rgl::rglwidgetOutput(paste0('view_',panel),height=height,width='100%'),
  uiOutput(paste0('metric_',panel)))
