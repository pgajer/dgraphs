# Display helpers for the density/curvature article, not exported package APIs.
fermat_surface_mesh <- function(id) {
 if(id=='swiss_roll') {
  t<-seq(1.5*pi,4.5*pi,length.out=101);h<-seq(0,20,length.out=25)
  uv<-expand.grid(t=t,h=h);X<-cbind(uv$t*cos(uv$t),uv$h,uv$t*sin(uv$t))
  grid<-matrix(seq_len(nrow(X)),length(t),length(h))
  a<-as.vector(grid[-nrow(grid),-ncol(grid)]);b<-as.vector(grid[-1,-ncol(grid)])
  c<-as.vector(grid[-1,-1]);d<-as.vector(grid[-nrow(grid),-1])
  triangles<-rbind(cbind(a,b,c),cbind(a,c,d))
 } else {
  # Polar rings triangulate the disk; these are drawing vertices, not samples.
  nr<-20L;nt<-80L;theta<-2*pi*(0:(nt-1))/nt
  uv<-rbind(c(0,0),do.call(rbind,lapply(seq_len(nr)/nr,function(r)cbind(r*cos(theta),r*sin(theta)))))
  ring<-function(r,j)1L+(r-1L)*nt+((j-1L)%%nt)+1L
  j<-seq_len(nt);triangles<-cbind(1L,ring(1L,j),ring(1L,j+1L))
  for(r in 1:(nr-1L))triangles<-rbind(triangles,
   cbind(ring(r,j),ring(r+1L,j),ring(r+1L,j+1L)),
   cbind(ring(r,j),ring(r+1L,j+1L),ring(r,j+1L)))
  coefficient<-as.numeric(sub('.*_a','',id));sign<-if(startsWith(id,'saddle'))-1 else 1
  X<-cbind(uv,coefficient*(uv[,1]^2+sign*uv[,2]^2))
 }
 list(X=X,triangles=triangles)
}
fermat_surface_gallery <- function(views) {
 titles<-c(paste('Paraboloid, a =',c(1,2,4)),paste('Saddle, a =',c(1,2,4)),'Swiss roll')
 widgets<-lapply(seq_along(views),function(j) {
  id<-names(views)[j];v<-views[[j]];mesh<-fermat_surface_mesh(id)
  bounds<-if(startsWith(id,'paraboloid'))rbind(c(-1,-1,0),c(1,1,4)) else
   if(startsWith(id,'saddle'))rbind(c(-1,-1,-4),c(1,1,4)) else apply(mesh$X,2,range)
  bounds<-t(bounds);pad<-.07*(bounds[,2]-bounds[,1]);bounds<-bounds+cbind(-pad,pad)
  surface<-ivue::layer3D.callback(function(ctx,mesh) {
   rgl::triangles3d(mesh$X[as.vector(t(mesh$triangles)),],col='#90B8CA',alpha=.28,lit=FALSE)
  },args=list(mesh=mesh))
  ivue::plot3D.plain(v$X,col=ifelse(seq_len(nrow(v$X))%in%v$endpoints,'#D55E00','#0072B2'),
   point.size=5,axes=FALSE,aspect='equal',limits=bounds,
   layers=list(surface,ivue::layer3D.axes(labels=c('x','y','z'),limits=bounds)),
   camera=ivue::camera.zup(elevation=22,turn=-125,zoom=.7),height=520,
   description='Interactive target surface. Select a surface above; drag to rotate and scroll to zoom.',controls=FALSE)
 })
 id<-'fermat-recovery-surfaces';w<-widgets[[1]];w$elementId<-paste0(id,'-view')
 captions<-paste0(titles,': 300 original observations from repetition 1. Orange: 64 fixed endpoints; blue: 236 additional path vertices. Translucent mesh: target surface.')
 w<-htmlwidgets::onRender(w,"function(el,x,data) {
   var box=document.getElementById(data.id), choice=box.querySelector('select');
   function describe(j) {
     box.querySelector('.surface-caption').textContent=data.captions[j];
     el.setAttribute('aria-label',data.captions[j]);
     var canvas=el.querySelector('canvas');if(canvas)canvas.setAttribute('aria-label',data.captions[j]);
   }
   function show() {
     var j=Number(choice.value);
     HTMLWidgets.find('#'+el.id).renderValue(JSON.parse(JSON.stringify(data.scenes[j])));
     describe(j);
   }
   choice.addEventListener('change',show);
   box.querySelector('button').addEventListener('click',show);
   describe(0);
 }",data=list(id=id,scenes=unname(lapply(widgets,function(w)w$x)),captions=unname(captions)))
 htmltools::tags$div(id=id,
  htmltools::tags$div(class='surface-controls',
   htmltools::tags$label(`for`=paste0(id,'-choice'),'Surface: '),
   htmltools::tags$select(id=paste0(id,'-choice'),lapply(seq_along(titles),function(j)
    htmltools::tags$option(value=j-1L,titles[j]))),
   htmltools::tags$button(type='button','Reset view')),
  htmltools::tags$p(class='surface-caption',`aria-live`='polite',captions[1]),w)
}
