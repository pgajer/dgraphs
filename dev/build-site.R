# Build from a verified installation, using the same sources as its guides.
args <- commandArgs(trailingOnly=TRUE)
lib <- if(length(args)) normalizePath(args[1]) else if(dir.exists("build/site-library/dgraphs")) normalizePath("build/site-library") else normalizePath("build/dgraphs.Rcheck")
if(system2("python3",c("dev/artifact-provenance.py","verify",shQuote(lib))) != 0L)
  stop("Rebuild and install the current archive before building its website.")
.libPaths(c(lib,.libPaths()))
pkgdown::build_site(new_process=FALSE,install=FALSE)
# Installed overview links use ../doc; pkgdown articles live in ../articles.
# The installed help remains portable and unchanged.
for(p in list.files("build/site", "[.]html$",recursive=TRUE,full.names=TRUE)) {
  text <- readLines(p,warn=FALSE)
  text <- gsub('href="../doc/', 'href="../articles/', text, fixed=TRUE)
  writeLines(text,p)
}
writeLines(capture.output(sessionInfo()),"build/site/session-info.txt")
file.copy(list.files("build","[.]provenance[.]json$",full.names=TRUE),"build/site")
