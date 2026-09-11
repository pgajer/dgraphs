library(testthat)
app_root<-normalizePath(if(file.exists('app.R')) '.' else 'dev/apps/embedding-explorer')
Sys.setenv(GEOMETRY_LAB_ROOT=app_root)
env<-new.env(parent=globalenv());app<-source(file.path(app_root,'app.R'),local=env)$value
test_that('server jobs complete, view edits are isolated and failed runs retain history', {
  shiny::testServer(env$server, {
    values<-env$default_fit_spec()
    values$surface<-'saddle';values$domain<-'square';values$extent<-1;values$sampling<-'uniform'
    values$n<-60;values$sample_seed<-4101;values$noise<-0;values$gap<-.2
    values$method<-'pca';values$layout_seed<-5101;values$umap_init<-'spectral'
    values$q<-10;values$alignment<-'similarity';values$mouse_mode<-'rotate'
    values$fit_a<-'observed';values$fit_b<-'observed'
    do.call(session$setInputs,values)
    session$setInputs(generate=1);expect_equal(length(state()$cloud$ids),60)
    session$setInputs(run_fit=1);expect_true(busy())
    for(i in 1:150) {Sys.sleep(.05);session$elapse(400);if(!busy())break}
    expect_false(busy());expect_length(state()$fits,1)
    old<-state()
    session$setInputs(show_mesh=TRUE,color='height',q=15,point_size=5)
    expect_identical(state(),old)
    session$setInputs(method='umap',min_dist=2,spread=1,run_fit=2)
    for(i in 1:150) {Sys.sleep(.05);session$elapse(400);if(!busy())break}
    expect_false(busy());expect_identical(state(),old);expect_true(status()$error)
    session$setInputs(method='umap',min_dist=.1,spread=1,epochs=2000,run_fit=3)
    expect_true(busy());session$setInputs(cancel_fit=1)
    expect_false(busy());expect_identical(state(),old);expect_match(status()$text,'cancelled')
    file<-tempfile(fileext='.rds');saveRDS(old,file)
    session$setInputs(sample_seed=9001,generate=2);expect_false(identical(state()$cloud$id,old$cloud$id))
    session$setInputs(import_bundle=list(datapath=file,name='restored.rds'))
    expect_identical(state(),old);expect_match(status()$text,'restored');unlink(file)
  })
})
cat('Geometry Lab server lifecycle checks completed.\n')
