library(testthat)
app_root<-normalizePath(if(file.exists('R/engine.R')) '.' else 'dev/apps/embedding-explorer')
source(file.path(app_root,'R/engine.R'))

test_that('all surface/domain/sampling combinations preserve geometry and sample count', {
  for(surface in names(surface_presets)) for(domain in c('square','disk'))
    for(sampling in c('uniform','area','grid','center','gap')) {
      s<-default_spec();s$n<-60L;s$surface<-surface;s$coefficients<-surface_presets[[surface]]
      s$domain<-domain;s$sampling<-sampling
      b<-make_experiment(s);c<-b$cloud
      expect_equal(dim(c$truth),c(60L,3L));expect_equal(c$truth,lift_quad(c$uv,s$coefficients))
      expect_true(all(abs(c$uv)<=s$extent+1e-10))
      if(domain=='disk')expect_true(all(rowSums(c$uv^2)<=s$extent^2+1e-10))
      if(sampling=='gap') {
        expect_true(all(abs(c$uv[,1])>s$gap*s$extent))
        us<-matrix(c$uv[c$triangles,1],ncol=3)
        expect_false(any(apply(us,1,min)< -s$gap*s$extent & apply(us,1,max)>s$gap*s$extent))
      }
      expect_silent(validate_bundle(b))
    }
})
test_that('seeds reproduce samples and noise remains separate from truth', {
  s<-default_spec();s$n<-100L
  a<-make_experiment(s);b<-make_experiment(s);expect_identical(a,b)
  s$noise<-.1;c<-make_experiment(s)
  expect_identical(a$cloud$truth,c$cloud$truth)
  expect_gt(sum((c$cloud$observed-c$cloud$truth)^2),0)
  expect_false(identical(a$cloud$id,c$cloud$id))
})
test_that('surface area sampling changes the expected distribution', {
  s<-default_spec();s$n<-1200L;s$surface<-'steep_bowl';s$coefficients<-surface_presets$steep_bowl
  u<-make_experiment(s)$cloud$uv;s$sampling<-'area';a<-make_experiment(s)$cloud$uv
  expect_gt(mean(rowSums(a^2)),mean(rowSums(u^2))+.05)
})
test_that('alignment and neighborhood metrics have known limiting values', {
  s<-default_spec();s$n<-80L;c<-make_experiment(s)$cloud
  rotation<-qr.Q(qr(matrix(c(1,3,2,-1,2,4,3,1,2),3)))
  Z<-sweep(3*c$truth%*%rotation,2,c(8,-2,4),'+')
  a<-align_coords(Z,c$truth)
  expect_equal(a$coords,c$truth,tolerance=1e-10);expect_equal(a$scale,1/3,tolerance=1e-10)
  expect_gt(sum((align_coords(Z,c$truth,'rigid')$coords-c$truth)^2),1)
  scores<-score_fit(Z,c,NULL,10L)
  expect_lt(scores$correspondence_nrmse,1e-12);expect_lt(scores$chord_nrmse,1e-12)
  expect_equal(scores$trustworthiness,1);expect_equal(scores$continuity,1);expect_equal(scores$neighbor_recall,1)
  set.seed(42);bad<-score_fit(Z[sample(nrow(Z)),],c,NULL,10L)
  expect_lt(bad$neighbor_recall,.4);expect_lt(bad$trustworthiness,.8)
  expect_error(score_fit(Z,c,NULL,60L),'Evaluation q')
})
test_that('graph identities and disconnected errors are explicit', {
  s<-default_spec();s$n<-80L;c<-make_experiment(s)$cloud;g<-make_neighbor_graph(c$observed,8L)
  expect_equal(g$indices[,1],1:80)
  expect_equal(g$weights,as.matrix(dist(c$observed))[g$edges])
  expect_equal(ncol(g$indices),9L)
  X<-rbind(cbind(seq(0,.01,length.out=20),0,0),cbind(seq(10,10.01,length.out=20),0,0))
  g<-make_neighbor_graph(X,3L);expect_equal(g$components,2)
  expect_error(graph_distances(g,nrow(X)),'components')
})
test_that('embedding adapters and refinement return finite matched coordinates', {
  s<-default_spec();s$n<-70L;c<-make_experiment(s)$cloud
  for(method in c('pca','isomap','mds','grip')) {
    f<-default_fit_spec();f$method<-method;f$iterations<-20L;f$rounds<-10L;f$final_rounds<-20L
    f$refine<-TRUE;f$kk_iterations<-3L
    fits<-run_fit(c,f,app_root)
    expect_length(fits,2);expect_equal(fits[[2]]$parent,fits[[1]]$id)
    for(z in fits) {expect_equal(dim(z$coords),c(70L,3L));expect_true(all(is.finite(z$coords)));expect_identical(z$cloud_id,c$id)}
    if(method=='pca')expect_lt(fits[[1]]$scores$correspondence_nrmse,1e-12)
  }
})
test_that('flat PCA reconstructs truth and import rejects invalid identities', {
  s<-default_spec();s$surface<-'flat';s$coefficients<-c(0,0,0);s$n<-60L
  b<-make_experiment(s);f<-default_fit_spec();f$method<-'pca';b$fits<-run_fit(b$cloud,f,app_root)
  expect_lt(b$fits[[1]]$scores$correspondence_nrmse,1e-12)
  file<-tempfile(fileext='.rds');saveRDS(b,file);expect_identical(validate_bundle(readRDS(file)),b);unlink(file)
  bad<-b;bad$fits[[1]]$cloud_id<-'different';expect_error(validate_bundle(bad),'mismatch')
  bad<-b;bad$cloud$ids[2]<-bad$cloud$ids[1];expect_error(validate_bundle(bad),'unique')
  bad<-b;bad$cloud$triangles[1,1]<-999;expect_error(validate_bundle(bad),'mesh')
  bad<-b;bad$fits[[1]]$coords[1,1]<-Inf;expect_error(validate_bundle(bad),'mismatch')
})

if(file.exists(file.path(study_root_default(),'outputs/layouts.csv'))) {
  test_that('saved-study adapter preserves exact fitted coordinates and scores', {
    s<-read_study(study_root_default());ix<-which(s$table$status%in%c('finite_budget','ok'))[1]
    b<-load_study_fit(s,s$table$row_id[ix]);f<-b$fits[[1]];original<-readRDS(f$provenance$file)
    expect_identical(f$coords,original$coords);expect_identical(f$original_scores,original$scores)
    expect_identical(f$provenance$md5,unname(tools::md5sum(f$provenance$file)))
    expect_error(safe_asset(s$root,'fits','../escape'),'Invalid')
  })
}

python<-Sys.getenv('GEOMETRY_LAB_PYTHON','')
if(!nzchar(python) && file.exists(file.path(study_root_default(),'settings.rds')))
  python<-readRDS(file.path(study_root_default(),'settings.rds'))$python
if(nzchar(python) && file.exists(python)) {
  test_that('every UMAP initialization uses exact neighbors and reproducible seeds', {
    s<-default_spec();s$n<-60L;c<-make_experiment(s)$cloud;f<-default_fit_spec();f$method<-'umap';f$epochs<-20L
    first<-NULL
    for(init in c('spectral','random','pca','graph_mds')) {
      f$init<-init;z<-run_fit(c,f,app_root,python)[[1]]
      expect_equal(dim(z$coords),c(60L,3L));expect_true(all(is.finite(z$coords)))
      expect_equal(z$metadata$n_neighbors,f$k+1);expect_equal(z$metadata$init,init)
      if(init=='spectral')first<-z$coords
    }
    f$init<-'spectral';again<-run_fit(c,f,app_root,python)[[1]]
    expect_identical(first,again$coords)
  })
}
cat('Geometry Lab numerical and import checks completed.\n')
