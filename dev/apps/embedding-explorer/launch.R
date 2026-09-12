args <- commandArgs(trailingOnly=FALSE)
file <- sub('^--file=', '', args[grepl('^--file=',args)][1])
root <- dirname(normalizePath(file,mustWork=TRUE))
Sys.setenv(GEOMETRY_LAB_ROOT=root)
options(rgl.useNULL=TRUE)
required <- c('dgraphs','shiny','bslib','DT','plotly','ivue','rgl','geometry','grip','igraph',
  'callr','jsonlite','digest','htmlwidgets')
missing <- required[!vapply(required,requireNamespace,FALSE,quietly=TRUE)]
if(length(missing)) stop('Missing R packages: ',paste(missing,collapse=', '),'. See README.md.')
if (utils::packageVersion('dgraphs') < '0.2.1.9000' ||
    !all(c('sample.synthetic.geometry','synthetic.sampling.quadform.lab') %in%
      getNamespaceExports('dgraphs')))
  stop('Geometry Lab requires the migrated dgraphs development installation; check R_LIBS.')
message('Geometry Lab dgraphs library: ', find.package('dgraphs'))
port <- as.integer(Sys.getenv('GEOMETRY_LAB_PORT','8462'))
shiny::runApp(root,host='127.0.0.1',port=port,launch.browser=FALSE)
