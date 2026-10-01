# Fast, source-based preview; does not claim installed-package or CRAN validation.
options(rgl.useNULL=TRUE)
pkgload::load_all('.',quiet=TRUE)
dir.create('build/validation/articles',recursive=TRUE,showWarnings=FALSE)
rmarkdown::render('vignettes/articles/fermat-density-curvature.Rmd',
 output_dir=normalizePath('build/validation/articles'),quiet=TRUE,
 envir=new.env(parent=globalenv()))
