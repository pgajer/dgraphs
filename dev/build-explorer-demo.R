# Reproduce the tiny installed benchmark. Runtime viewing does not require grip.
pkgload::load_all(".", quiet=TRUE)
root <- file.path("inst", "extdata", "graph-explorer-demo")
dir.create(root, recursive=TRUE, showWarnings=FALSE)
n <- 12L; theta <- 2*pi*(0:(n-1))/n
X <- cbind(x=cos(theta),y=sin(theta),z=0)
saveRDS(list(coords=X), file.path(root,"circle.rds"), version=2)
base <- data.frame(dataset_id="circle12", surface="unit circle", curvature_label="radius 1",
                   domain_shape="circle", sampling_profile="regular", n=n, seed=17L)
write.csv(base,file.path(root,"dataset_manifest.csv"),row.names=FALSE)
write.csv(data.frame(dataset_id="circle12",dataset_asset_file="circle.rds"),file.path(root,"dataset_assets.csv"),row.names=FALSE)
settings <- assets <- layouts <- metrics <- diagnostics <- list()
reference <- abs(outer(theta,theta,"-")); reference <- pmin(reference,2*pi-reference)
for (k in c(2L,4L)) {
    id <- paste0("k",k); graph <- create.sknn.graph(X,k=k,connect.components=FALSE)
    file <- paste0(id,"-graph.rds"); layoutfile <- paste0(id,"-layout.rds")
    saveRDS(list(adj_list=graph.adjacency(graph),weight_list=graph.lengths(graph)),file.path(root,file),version=2)
    layout <- grip::grip(adj_list=graph.adjacency(graph),weight_list=graph.lengths(graph),
                         metric="edge_length",dim=3,seed=17,rounds=40,final_rounds=80)
    saveRDS(list(coords=layout,provenance=paste("grip",packageVersion("grip"),"edge_length; seed 17")),
            file.path(root,layoutfile),version=2)
    settings[[id]] <- cbind(base,setting_id=id,graph_family="sknn",k=k,prune_method="none",stage="final")
    assets[[id]] <- data.frame(dataset_id="circle12",setting_id=id,stage="final",graph_family="sknn",
        graph_asset_file=file,n_vertices=n,n_edges=nrow(graph.edges(graph)),n_components=1L)
    layouts[[id]] <- data.frame(dataset_id="circle12",setting_id=id,stage="final",method="weighted_grip",
        layout_asset_file=layoutfile,n_vertices=n)
    D <- graph.geodesic.distances(graph); take <- upper.tri(D)
    error <- D[take]-reference[take]
    metrics[[id]] <- cbind(settings[[id]],target="surface",metric_stage="final",status="ok",
        rel_rms_error=sqrt(mean(error^2))/sqrt(mean(reference[take]^2)),
        rel_abs_error_q95=as.numeric(quantile(abs(error)/reference[take],.95)),
        pearson_cor=cor(D[take],reference[take]))
    diagnostics[[id]] <- data.frame(dataset_id="circle12",setting_id=id,stage="final",
                                    n_edges_raw_repaired=nrow(graph.edges(graph)))
}
for (name in c("settings","assets","layouts","metrics","diagnostics")) {
    file <- switch(name,settings="graph_settings",assets="graph_assets",layouts="layout_assets",
                   metrics="metrics",diagnostics="graph_diagnostics")
    write.csv(do.call(rbind,get(name)),file.path(root,paste0(file,".csv")),row.names=FALSE)
}
saveRDS(list(version="1",project="Installed circle demonstration",graph_settings=do.call(rbind,settings)),
        file.path(root,"quadform_benchmark_manifest.rds"),version=2)
writeLines('{"version":"1","project":"Installed circle demonstration"}',file.path(root,"quadform_benchmark_manifest.json"))
