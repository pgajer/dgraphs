args <- commandArgs(trailingOnly=FALSE)
file <- sub('^--file=', '', args[grepl('^--file=',args)][1])
root <- dirname(normalizePath(file,mustWork=TRUE))
Sys.setenv(GEOMETRY_LAB_ROOT=root)
options(rgl.useNULL=TRUE)
required <- c('shiny','bslib','DT','plotly','ivue','rgl','geometry','grip','igraph',
  'callr','jsonlite','digest','htmlwidgets')
missing <- required[!vapply(required,requireNamespace,FALSE,quietly=TRUE)]
if(length(missing)) stop('Missing R packages: ',paste(missing,collapse=', '),'. See README.md.')
port <- as.integer(Sys.getenv('GEOMETRY_LAB_PORT','8462'))
shiny::runApp(root,host='127.0.0.1',port=port,launch.browser=FALSE)
