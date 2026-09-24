# Run after loading the intended private dgraphs installation and building its
# optional backend. This example itself runs IAN; it is not part of package tests.
# Set backend to the path returned by dgraphs::build.ian.backend().
x <- rbind(c(0, 0), c(1, 0), c(2, 0), c(0, 0))
result <- dgraphs::create.ian.graph(
    x, backend = backend,
    specimen.ids = c("alpha", "beta", "gamma", "delta"),
    participant.ids = c("p1", "p1", "p2", "p3")
)
stopifnot(result$complete)
dgraphs::graph.edges(result$initial_graph) # Actual Gabriel graph before pruning
dgraphs::graph.edges(result$final_graph)   # Metric edge lengths, not affinities
result$mapping                           # Four specimens map to three profiles
result$affinity                          # Profile-by-profile similarity matrix
result$diagnostics$solver_history         # Settings and acceptance for every solve
