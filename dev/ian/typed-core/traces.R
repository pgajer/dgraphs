args <- commandArgs(TRUE)
stopifnot(length(args)==3L)
.libPaths(c(args[1],.libPaths()));library(dgraphs)
fixtures <- args[2];out<-args[3];stopifnot(!dir.exists(out));dir.create(out,recursive=TRUE)
ledger<-list();total<-0L
save<-function()saveRDS(list(calls=ledger,total_solves=total),file.path(out,"ledger.rds"))
for(name in c("nonuniform_curve","variable_density_patch","nearby_curved_arms","pressmat_hellinger_subset")) {
 path<-file.path(fixtures,name);ref<-jsonlite::fromJSON(file.path(path,"reference.json"))
 binary<-function(file,n,p)matrix(readBin(file.path(path,file),"double",n=n*p,size=8,endian="little"),n,p,byrow=TRUE)
 ledger[[name]]<-list(status="started",limit=80L);save()
 r<-dgraphs::create.ian.graph(binary("features.bin",ref$n,ref$p),distances=binary("distances.bin",ref$n,ref$n),specimen.ids=ref$ids,diagnostics="full",max.solves=80L,numerical.policy="IAN evaluated-LP 1.0",preserve.connectivity=FALSE)
 saveRDS(r,file.path(out,paste0(name,".rds")))
 total<-total+r$diagnostics$solves;ledger[[name]]<-list(status="returned",solves=r$diagnostics$solves,complete=r$complete,events=length(r$diagnostics$trace));save()
 stopifnot(r$complete,total<=320L,r$diagnostics$solves==length(r$diagnostics$solver_history))
}
cat(length(ledger),"calls",total,"attempts\n")
