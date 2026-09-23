# Preserve binary64 round trips; jsonlite's usual numeric output rounds values.
# Native trace arrays are R lists, so list shape and scalar types stay explicit.
ian.trace.json <- function(x) {
    if (is.null(x)) return('null')
    if (is.list(x)) {
        values <- vapply(x, ian.trace.json, '')
        if (!is.null(names(x))) {
            keys <- vapply(names(x), function(k) as.character(jsonlite::toJSON(k, auto_unbox=TRUE)), '')
            return(paste0('{', paste(paste0(keys, ':', values), collapse=','), '}'))
        }
        return(paste0('[', paste(values, collapse=','), ']'))
    }
    if (length(x) != 1L) return(paste0('[',paste(vapply(as.list(x),ian.trace.json,''),collapse=','),']'))
    if (is.numeric(x)) return(if (is.finite(x)) sprintf('%.17g',x) else 'null')
    as.character(jsonlite::toJSON(x, auto_unbox=TRUE))
}
