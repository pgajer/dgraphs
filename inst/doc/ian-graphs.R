## ----setup-backend, eval=FALSE------------------------------------------------
# library(dgraphs)
# backend <- build.ian.backend("ian-build")

## ----graph-example, eval=FALSE------------------------------------------------
# X <- rbind(c(0, 0), c(1, 0), c(2, 0), c(0, 0))
# fit <- create.ian.graph(X, backend = backend,
#     specimen.ids = c("alpha", "beta", "gamma", "delta"),
#     participant.ids = c("p1", "p1", "p2", "p3"))
# if (!fit$complete) stop(fit$error$message)
# graph.edges(fit$initial_graph)
# graph.edges(fit$final_graph)
# fit$mapping$member_to_profile
# fit$scales
# fit$affinity
# fit$diagnostics$connectivity$protected.edges
# fit$diagnostics$connectivity$history

## ----reference-example, eval=FALSE--------------------------------------------
# reference <- create.ian.graph(X, backend = backend,
#     numerical.policy = "IAN evaluated-LP 1.0",
#     preserve.connectivity = FALSE)

