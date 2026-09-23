"""Draw saved first-cut geometry and complete component histories; no engine calls."""
import json,subprocess,hashlib
from pathlib import Path
E=Path(__file__).resolve().parent;B=E/'build';B.mkdir(exist_ok=True)
code=r'''
a<-commandArgs(TRUE);d<-jsonlite::fromJSON(a[1],simplifyVector=FALSE);out<-a[2]
render<-function(){
 par(mfrow=c(2,3),mar=c(3.2,3.8,3.8,1),oma=c(1,0,1,0),mgp=c(2.3,.6,0),cex=.9)
 for(c in d$cases){
  X<-do.call(rbind,c$coordinates);ee<-do.call(rbind,c$edges_before)+1;cut<-unlist(c$edge)+1;groups<-c$groups
  pm<-persp(c(-1.1,1.1),c(-1.1,1.1),matrix(0,2,2),zlim=c(0,2),theta=35,phi=22,expand=.8,box=FALSE,axes=FALSE,col=NA,border=NA,xlab='',ylab='',zlab='',main=paste('Helix seed',c$seed))
  xy<-trans3d(X[,1],X[,2],X[,3],pm)
  colors<-rep('#16728b',nrow(X));colors[unlist(groups[[2]])+1]<-'#bd7727'
  for(k in seq_len(nrow(ee))){e<-ee[k,];segments(xy$x[e[1]],xy$y[e[1]],xy$x[e[2]],xy$y[e[2]],col=colors[e[1]],lwd=1.6)}
  points(xy$x,xy$y,pch=16,cex=.38,col=colors)
  segments(xy$x[cut[1]],xy$y[cut[1]],xy$x[cut[2]],xy$y[cut[2]],col='#c83938',lwd=4)
  points(xy$x[cut],xy$y[cut],pch=1,cex=1.35,col='#c83938',lwd=1.8)
  mtext(paste('First cut: step',c$step,' | groups',paste(unlist(c$sizes),collapse=' + ')),side=3,line=.2,cex=.85)
 }
 for(c in d$cases){
  steps<-c(0,unlist(c$steps));nc<-c(1,unlist(c$components));plot(steps,nc,type='s',lwd=2,col='#16728b',xlim=c(0,46),ylim=c(.7,6.3),xlab='Completed pruning steps',ylab='Connected components',yaxt='n');axis(2,at=1:6,las=1);abline(h=1,col='#aab5bc',lty=3)
  abline(v=c$step,col='#c83938',lty=2);points(c$step,2,pch=16,col='#c83938');text(c$step-1,5.7,labels=paste('First split:',c$step),adj=1,col='#c83938',cex=.9)
 }
 mtext('Red edge: first deleted bridge. All three graphs are intact consecutive-point chains immediately beforehand.',outer=TRUE,side=1,cex=.85)
}
png(file.path(out,'pruning.png'),width=1700,height=1050,res=145,type='cairo');render();dev.off()
pdf(file.path(out,'pruning.pdf'),width=11.72,height=7.24,useDingbats=FALSE);render();dev.off()
'''
r=subprocess.run(['/Library/Frameworks/R.framework/Resources/bin/Rscript','--vanilla','-',str(E/'figure-data.json'),str(B)],input=code,text=True,capture_output=True);(B/'figure-build.log').write_text(r.stdout+r.stderr);r.check_returncode()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(B/'figure-manifest.json').write_text(json.dumps(dict(operation='saved-data rendering; zero engine calls',data_sha256=sha(E/'figure-data.json'),script_sha256=sha(Path(__file__)),outputs={n:sha(B/n) for n in ['pruning.png','pruning.pdf']}),indent=2)+'\n')
