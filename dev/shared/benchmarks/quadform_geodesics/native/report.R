qgc.report <- function(output) {
  manifest <- readRDS(file.path(output,"manifest.rds"))
  rows <- read.csv(file.path(output,"runs.csv"));done <- rows$run_status=="recorded"
  method <- c(sensitivity_vertex="Single-point refinement",sensitivity_local_graph="Local-network refinement")
  policy <- c(neighbors="Immediate neighbors",fixed_disk="Fixed disk",fixed_span="Fixed disk and distance-based section")
  cohort <- c(epochs="Up to eight rounds",edges="10,000 length calculations",seconds="Ten seconds")
  lines <- c("# C++ Refinement Study", "",sprintf("Recorded **%d of %d** planned runs; **%d** have results eligible for comparison.",
    sum(done),nrow(rows),sum(rows$available)),"",
    "## What Was Tested","",
    "Single-point and local-network refinement were tested on a steep quadratic bowl over the unit disk. The surface is z = 8(u^2 + v^2), with domain endpoints (-0.45, -0.20) and (0.40, -0.10). Each search starts with the same 16 equal-surface-length segments and uses 32 sampled candidates per visit.","",
    "Three neighborhood rules compare immediate neighbors, a fixed sampling radius, and that fixed radius combined with distance-based path sections. Separate searches stop after up to eight rounds, 10,000 segment-length calculations, or ten seconds. Each run allows 1,024 MiB and at most 257 path points.","",
    sprintf("This is the separately identified C++-accelerated study, with up to **%d simultaneous runs**. The random streams, acceptance rule, R integration driver and independent R path checker are retained. C++ performs binary key construction, graph construction and search, compensated sums, and tangent-speed evaluation. It is not an all-C++ runtime.",manifest$workers),"",
    "## Results","",
    "The following path lengths use only runs that reached their intended stopping condition and passed the required checks. Missing results remain in the denominators. Forward and reverse runs are pooled only in this descriptive table; the direction table below treats them separately.","",
    "| Stopping condition | Neighborhood | Method | Available / planned | Median length |",
    "|---|---|---|---:|---:|")
  groups <- qgx.groups(rows,c("cohort","neighborhood","method"))
  for(z in groups) lines <- c(lines,sprintf("| %s | %s | %s | %d / %d | %s |",cohort[z$cohort[1]],
    policy[z$neighborhood[1]],method[z$method[1]],sum(z$available),nrow(z),
    if(any(z$available))sprintf("%.6f",median(z$length[z$available])) else "Unavailable"))
  lines <- c(lines,"","## Direction Differences","",
    "Positive differences mean forward paths were longer. Intervals are pointwise 95% bootstrap intervals for the difference of means, based on independent forward and reverse runs; they are exploratory and do not establish equivalence when they include zero.","",
    "| Stopping condition | Neighborhood | Method | Forward / reverse available | Mean difference | 95% interval |",
    "|---|---|---|---:|---:|---|")
  d <- read.csv(file.path(output,"direction-comparison.csv"))
  for(i in seq_len(nrow(d))) {
    z <- d[i,];lines <- c(lines,sprintf("| %s | %s | %s | %d / %d | %s | %s |",cohort[z$cohort],
      policy[z$neighborhood],method[z$method],z$forward_available,z$reverse_available,
      if(is.finite(z$mean_difference))sprintf("%.6f",z$mean_difference) else "Unavailable",
      if(is.finite(z$mean_low))sprintf("[%.6f, %.6f]",z$mean_low,z$mean_high) else "Insufficient repeats"))
  }
  lines <- c(lines,"","## Limits of These Results","",
    "An accepted path was checked for valid endpoints, domain membership, numerical length, and shortening relative to its initialization. These checks do not prove that a path is globally shortest. All distribution summaries are conditional on available runs, and failed or unavailable runs are listed in runs.csv.","",
    "Ten-second outcomes must not be pooled with the serial R study: both the faster backend and concurrency change how much work fits into ten seconds. The earlier R results are preserved separately. Compilation is performed before worker searches begin. Shared disk activity and the operating system can affect wall time.","",
    "## Supporting Records","",
    "The manifest records the plan, code hashes, dependencies, concurrency and limits. Per-run directories retain paths, random states, resource records and independent audits. distributions.csv, method-comparison.csv and neighborhood-effects.csv contain the full comparisons; rounds.csv records the development of paths and neighborhood sizes. r-cpp-comparison.csv, when present, records exact agreement checks against saved R searches.")
  writeLines(lines,file.path(output,"report.md"))
}
