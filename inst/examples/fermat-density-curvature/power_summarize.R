library(ggplot2)
root<-'results/power_tuning'
dir.create('results/figures',recursive=TRUE,showWarnings=FALSE)
sel<-read.csv(file.path(root,'selection.csv'));cv<-read.csv(file.path(root,'cv_summary.csv'))
rr<-read.csv(file.path(root,'cv_repetitions.csv'))
tm<-read.csv(file.path(root,'transfer_metrics.csv'));ts<-read.csv(file.path(root,'transfer_summary.csv'))
models<-subset(read.csv('results/models.csv'),shape!='swiss_roll')
models<-models[order(models$shape,models$a),]
labels<-setNames(paste0(tools::toTitleCase(models$shape),'~(a==',models$a,')'),models$id)
for(name in c('sel','cv','rr','tm','ts')) {z<-get(name);z$surface<-factor(labels[z$id],levels=labels);assign(name,z)}
theme_set(theme_bw(base_size=13)+theme(legend.position='bottom',panel.grid.minor=element_blank()))
saveplot<-function(plot,name,height=8.5)ggsave(file.path('results/figures',paste0(name,'.png')),plot,width=12,height=height,dpi=160)
q<-subset(cv,reference=='best_of_six');raw<-subset(rr,reference=='best_of_six');chosen<-subset(sel,reference=='best_of_six')
fig<-ggplot(raw,aes(p,100*error))+geom_line(aes(group=rep),color='#7c9bab',alpha=.55,linewidth=.4)+
 geom_ribbon(data=q,aes(y=NULL,ymin=100*(mean-qt(.975,4)*se),ymax=100*(mean+qt(.975,4)*se)),fill='#0072B2',alpha=.12)+
 geom_line(data=q,aes(y=100*mean),color='#0072B2',linewidth=.8)+geom_point(data=q,aes(y=100*mean),color='#0072B2',size=1)+
 geom_vline(data=chosen,aes(xintercept=p),linetype='dotted',color='#b74020')+
 geom_point(data=chosen,aes(y=100*cv_error),color='#b74020',shape=23,fill='white',size=3)+
 facet_wrap(~surface,ncol=3,scales='free',labeller=label_parsed)+
 labs(x=expression(paste('Fermat power ',p)),y='Cross-validated scaled distance error (%)')
saveplot(fig,'power_tuning_full')
# Relative loss around the chosen power makes a shallow minimum visible.
q$offset<-q$p-chosen$p[match(q$id,chosen$id)]
q$relative<-q$mean/chosen$cv_error[match(q$id,chosen$id)]-1
q$relative_se<-vapply(seq_len(nrow(q)),function(i) {
 x<-q[i,];pstar<-chosen$p[match(x$id,chosen$id)]
 a<-raw[raw$id==x$id & raw$p==x$p,]
 b<-raw[raw$id==x$id & raw$p==pstar,]
 sd(a$error-b$error[match(a$rep,b$rep)])/sqrt(5)/chosen$cv_error[match(x$id,chosen$id)]
},0)
q<-q[abs(q$offset)<=.03+1e-10,]
fig<-ggplot(q,aes(offset,100*relative))+geom_hline(yintercept=1,color='#777777',linetype='dashed')+
 geom_vline(xintercept=0,linetype='dotted',color='#b74020')+
 geom_ribbon(aes(ymin=100*(relative-qt(.975,4)*relative_se),ymax=100*(relative+qt(.975,4)*relative_se)),fill='#0072B2',alpha=.12)+
 geom_line(color='#0072B2')+geom_point(color='#0072B2',size=1.6)+
 facet_wrap(~surface,ncol=3,scales='free_y',labeller=label_parsed)+
 scale_x_continuous(breaks=c(-.03,0,.03))+coord_cartesian(xlim=c(-.03,.03))+
 labs(x=expression(p-p[chosen]),y='Relative excess over minimum mean CV error (%)')
saveplot(fig,'power_tuning_near')
colors<-c(ambient='#222222',fixed_1.25='#009E73',fixed_2='#E69F00',selected_best_of_six='#0072B2',knn_20='#AA4499',selected_clairaut='#CC3311')
method_labels<-c(ambient='Ambient (p = 1)',fixed_1.25='Fixed p = 1.25',fixed_2='Fixed p = 2',selected_best_of_six='Power selected with best-of-six',knn_20='Euclidean kNN (k = 20)',selected_clairaut='Power selected with Clairaut')
curves<-function(raw,z,ncol=3)ggplot(raw,aes(n,100*nrmse,color=method))+
 geom_line(aes(group=interaction(method,rep)),alpha=.15,linewidth=.4)+
 geom_line(data=z,aes(y=100*mean,linetype=method),linewidth=.8)+
 geom_point(data=z,aes(y=100*mean,shape=method),size=2)+
 geom_errorbar(data=z,aes(y=100*mean,ymin=100*(mean-qt(.975,4)*se),ymax=100*(mean+qt(.975,4)*se)),width=.025,alpha=.45)+
 facet_wrap(~surface,ncol=ncol,scales='free_y',labeller=label_parsed)+
 scale_x_log10(breaks=c(150,300,600,1200,2400))+scale_color_manual(values=colors,labels=method_labels)+
 scale_linetype_manual(values=c(ambient='dashed',fixed_1.25='dotdash',fixed_2='longdash',selected_best_of_six='solid',knn_20='dotted',selected_clairaut='solid'),labels=method_labels)+
 scale_shape_manual(values=c(ambient=0,fixed_1.25=2,fixed_2=5,selected_best_of_six=16,knn_20=4,selected_clairaut=17),labels=method_labels)+
 labs(x='Total observations (log scale)',y='Held-out scaled distance error (%)',color=NULL,linetype=NULL,shape=NULL)+
 guides(color=guide_legend(nrow=2),linetype=guide_legend(nrow=2),shape=guide_legend(nrow=2))
saveplot(curves(subset(tm,reference=='best_of_six' & method!='selected_clairaut'),subset(ts,reference=='best_of_six' & method!='selected_clairaut')),'power_transfer')
q<-subset(cv,grepl('paraboloid',id));raw<-subset(rr,grepl('paraboloid',id));chosen<-subset(sel,grepl('paraboloid',id))
ref_labels<-c(best_of_six='Best-of-six reference',clairaut='Clairaut reference')
fig<-ggplot(raw,aes(p,100*error,color=reference))+
 geom_line(aes(group=interaction(reference,rep)),alpha=.18,linewidth=.4)+
 geom_line(data=q,aes(y=100*mean,linetype=reference),linewidth=.8)+
 geom_point(data=chosen,aes(y=100*cv_error,shape=reference),size=3)+
 facet_wrap(~surface,ncol=3,labeller=label_parsed)+
 scale_color_manual(values=c(best_of_six='#0072B2',clairaut='#CC3311'),labels=ref_labels)+
 scale_linetype_discrete(labels=ref_labels)+scale_shape_discrete(labels=ref_labels)+
 labs(x=expression(paste('Fermat power ',p)),y='Cross-validated scaled distance error (%)',color=NULL,shape=NULL,linetype=NULL)
saveplot(fig,'power_clairaut_tuning',5)
saveplot(curves(subset(tm,reference=='clairaut'),subset(ts,reference=='clairaut')),'power_clairaut_transfer',5.6)
# Paired selected-minus-fixed differences retain the comparison uncertainty.
q<-subset(tm,reference=='best_of_six' & method=='selected_best_of_six');z<-subset(ts,reference=='best_of_six' & method=='selected_best_of_six')
fig<-ggplot(q,aes(n,100*difference_from_1.25))+geom_hline(yintercept=0,linetype='dashed',color='#777777')+
 geom_line(aes(group=rep),alpha=.3,color='#7c9bab')+
 geom_line(data=z,aes(y=100*difference_from_1.25),color='#0072B2')+
 geom_point(data=z,aes(y=100*difference_from_1.25),color='#0072B2')+
 geom_errorbar(data=z,aes(y=100*difference_from_1.25,ymin=100*(difference_from_1.25-qt(.975,4)*difference_from_1.25_se),ymax=100*(difference_from_1.25+qt(.975,4)*difference_from_1.25_se)),width=.03,color='#0072B2')+
 facet_wrap(~surface,ncol=3,scales='free_y',labeller=label_parsed)+
 scale_x_log10(breaks=c(150,300,600,1200,2400))+
 labs(x='Total observations (log scale)',y='Selected minus fixed p = 1.25 error (percentage points)')
saveplot(fig,'power_transfer_difference')
cat('Saved six power-selection figures.\n')
