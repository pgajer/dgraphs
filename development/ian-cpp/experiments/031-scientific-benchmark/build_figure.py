"""Render saved scientific summaries with base R; no analysis or optimizer calls."""
import subprocess,json,hashlib
from pathlib import Path
E=Path(__file__).resolve().parent;B=E/'build';B.mkdir(exist_ok=True)
code=r'''
a<-commandArgs(TRUE);d<-jsonlite::fromJSON(a[1]);out<-a[2]
render<-function(){
 par(mfrow=c(2,3),mar=c(6.5,5,3,1),oma=c(1,0,1,0),mgp=c(3,0.8,0),cex=0.9)
 geom<-c('square','helix','sphere');titles<-c('Flat square','Two-turn helix','Unit sphere')
 methods<-c('Gabriel','IAN','knn_5','knn_10','knn_20');labs<-c('Gabriel','IAN','5-neighbor','10-neighbor','20-neighbor');colors<-c('#758796','#126c8a','#758796','#758796','#758796')
 for(g in seq_along(geom)){
  plot(NA,xlim=c(.5,5.5),ylim=c(0,.8),xlab='',ylab=if(g==1)'Distance loss (lower is better)' else '',xaxt='n',main=titles[g]);abline(h=seq(0,.8,.2),col='#e2e7eb');axis(1,at=1:5,labels=labs,las=2)
  for(j in seq_along(methods)){v<-d$geometry$bounded_distance_loss[d$geometry$geometry==geom[g]&d$geometry$method==methods[j]];stopifnot(length(v)==3);points(j+c(-.1,0,.1),v,pch=16,col=colors[j],cex=1.2);segments(j-.23,mean(v),j+.23,mean(v),col=colors[j],lwd=3)}
 }
 methods<-c('training_mean','euclidean_knn','euclidean_kernel','IAN_distance_kernel','IAN_affinity','oracle_kernel');labs<-c('Mean','k-neighbor','Euclidean','IAN paths','IAN affinity','Oracle');colors<-c('#758796','#758796','#758796','#126c8a','#126c8a','#b58447')
 for(g in seq_along(geom)){
  plot(NA,xlim=c(.5,6.5),ylim=c(.007,.6),log='y',xlab='',ylab=if(g==1)'Known-mean squared error (log scale)' else '',xaxt='n');abline(h=c(.01,.02,.05,.1,.2,.5),col='#e2e7eb');axis(1,at=1:6,labels=labs,las=2)
  for(j in seq_along(methods)){v<-d$means$mean_squared_error[d$means$geometry==geom[g]&d$means$method==methods[j]];stopifnot(length(v)==3);points(j+c(-.1,0,.1),v,pch=16,col=colors[j],cex=1.2);segments(j-.23,mean(v),j+.23,mean(v),col=colors[j],lwd=3)}
 }
 mtext('Dots: independent coordinate datasets. Short bars: mean across three datasets. No confidence intervals.',outer=TRUE,side=1,cex=.85)
}
png(file.path(out,'benchmark.png'),width=1700,height=1150,res=145,type='cairo');render();dev.off()
pdf(file.path(out,'benchmark.pdf'),width=11.72,height=7.93,useDingbats=FALSE);render();dev.off()
'''
r=subprocess.run(['/Library/Frameworks/R.framework/Resources/bin/Rscript','--vanilla','-',str(E/'figure-data.json'),str(B)],input=code,text=True,capture_output=True)
(B/'figure-build.log').write_text(r.stdout+r.stderr);r.check_returncode();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(B/'figure-manifest.json').write_text(json.dumps(dict(operation='saved-summary rendering only; zero engine calls',data_sha256=sha(E/'figure-data.json'),script_sha256=sha(Path(__file__)),outputs={n:sha(B/n) for n in ['benchmark.png','benchmark.pdf']}),indent=2)+'\n')
print('Rendered six-panel geometry/known-mean comparison.')
