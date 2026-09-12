args <- commandArgs(TRUE)
stopifnot(length(args) == 1L)
source(file.path(args[1], "profile.R"))
timer <- new.env(); timer$value <- 0
p <- qgp.profiler(function() timer$value)
child <- qgp.wrap(function() { timer$value <- timer$value + 2; 9 }, "child", p)
parent <- qgp.wrap(function() {
  timer$value <- timer$value + 1; value <- child(); timer$value <- timer$value + 3; value
}, "parent", p)
stopifnot(parent() == 9, p$depth == 0L, p$counts["child"] == 1,
  p$total["parent"] == 6, p$self["parent"] == 4, p$self["child"] == 2)
failure <- qgp.wrap(function() { timer$value <- timer$value + 1; stop("expected failure") }, "failure", p)
outer <- qgp.wrap(function() failure(), "outer", p)
error <- tryCatch(outer(), error = conditionMessage)
stopifnot(error == "expected failure", p$depth == 0L,
  p$counts["failure"] == 1, p$counts["outer"] == 1,
  p$self["failure"] == 1, p$self["outer"] == 0)
stopifnot(parent() == 9, p$depth == 0L, p$counts["parent"] == 2,
  sum(p$self) == 13)
cat("Nested timing, return-value and error-cleanup checks passed.\n")
