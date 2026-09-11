# Deliberate failures for process-isolation tests, never a benchmark method.
qgs.adapter("test_fault",
  supports = function(request) list(supported = TRUE, reason = "test only"),
  prepare = function(request, control) NULL,
  solve = function(state, request, control) {
    if (request$parameters$behavior == "exit") quit(save = "no", status = 7L, runLast = FALSE)
    if (request$parameters$behavior == "hang") Sys.sleep(60)
    stop("deliberate worker error")
  }
)
