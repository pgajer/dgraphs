# Generate version-matched offline reference from the installed Rd database.
# This is a documentation build helper, not a public package entry point.
render_dgraphs_reference <- function() {
    db <- tools::Rd_db("dgraphs")
    aliases <- lapply(db, function(rd) vapply(Filter(function(x)
        identical(attr(x, "Rd_tag"), "\\alias"), rd), function(x) paste(unlist(x), collapse = ""), ""))
    all.aliases <- unique(unlist(aliases))
    methods <- getNamespaceInfo("dgraphs", "S3methods")
    public <- c(getNamespaceExports("dgraphs"), paste(methods[,1], methods[,2], sep="."))
    esc <- function(x) as.character(htmltools::htmlEscape(x, attribute = TRUE))
    for (i in seq_along(db)) {
        aa <- aliases[[i]]
        file <- tempfile(fileext=".html")
        tools::Rd2HTML(db[[i]], out=file, package="dgraphs", fragment=TRUE)
        html <- paste(readLines(file, warn=FALSE), collapse="\n"); unlink(file)
        links <- regmatches(html, gregexpr('href="[^"]+"', html))[[1]]
        for (link in unique(links)) {
            url <- sub('^href="|"$', '', link)
            topic <- sub('[.]html$', '', basename(url))
            replacement <- if (topic %in% all.aliases) {
                paste0('href="#help-', esc(topic), '"')
            } else if (basename(url) %in% paste0(c("function-guide", "synthetic-geometry", "data-derived-graph-workflow"), ".html")) {
                paste0('href="', basename(url), '"')
            } else if (!grepl('^(https?:|#|mailto:)', url)) {
                # Other packages' reference links are explicitly online fallbacks.
                package <- if (grepl('^../../',url)) strsplit(url,'/')[[1]][3] else 'base'
                paste0('href="https://stat.ethz.ch/R-manual/R-patched/library/',package,'/html/',basename(url),'"')
            } else link
            html <- gsub(link, replacement, html, fixed=TRUE)
        }
        cat('<details class="offline-help"><summary>',esc(aa[1]),' — detailed help</summary>',sep='')
        for (alias in aa) cat('<span id="help-',esc(alias),'"></span>',sep='')
        cat(html, '</details>\n')
    }
    cat('<script>
    function openHelpTarget() {
      var id = decodeURIComponent(location.hash.slice(1));
      var target = document.getElementById(id);
      if (target && id.indexOf("help-") === 0) {
        var detail = target.closest("details"); if (detail) detail.open = true;
        target.scrollIntoView();
      }
    }
    window.addEventListener("hashchange", openHelpTarget); openHelpTarget();
    </script>')
}
