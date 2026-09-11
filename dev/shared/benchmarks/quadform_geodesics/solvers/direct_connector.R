qgs.adapter(
  "direct_connector",
  supports = function(request) {
    qg.assert(length(request$parameters) == 0L, "direct_connector accepts no parameters")
    list(supported = request$domain$kind %in% c("ball", "box"),
         reason = "Lifted direct connector on a convex ball or box")
  },
  prepare = function(request, control) {
    control$poll()
    list(from = request$from, to = request$to)
  },
  solve = function(state, request, control) {
    edge <- control$edge(state$from, state$to)
    control$publish(qgs.candidate(rbind(state$from, state$to), edge$length,
                                  edge$error_estimate), phase = "initializer")
    list(status = "candidate", termination = "initializer_complete",
         diagnostic = "Feasible upper-bound control; not a general shortest-path solver")
  }
)
