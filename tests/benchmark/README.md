# create.rknn.graphs() backend parity benchmarks

This directory contains opt-in benchmark parity checks for the adaptive
radius-kNN graph sequence constructor. These scripts are not part of routine
`R CMD check` or `testthat` runs because they compare elapsed times.

Run from the package root:

```sh
Rscript tests/benchmark/run_create_rknn_graphs_backend_parity.R
```

The benchmark compares the public wrapper in both modes:

- `create.rknn.graphs(..., backend = "cpp", radius.search = "ann")`
- `create.rknn.graphs(..., backend = "r", radius.search = "ann")`

For each scenario, it removes timing-only fields and requires the remaining
graph sequence objects to match at numeric tolerance `1e-12`. It reports
wall-clock medians and speedup ratios, but it does not fail on speed by default
because machine load and compiler/runtime settings can make timing noisy.

Optional environment variables:

- `DGRAPHS_RKNN_BENCH_REPETITIONS`: number of repetitions per case, default `3`.
- `DGRAPHS_RKNN_BENCH_WARMUP_REPETITIONS`: unreported warm-up repetitions
  per case, default `1`.
- `DGRAPHS_RKNN_BENCH_OUTPUT_DIR`: directory where raw and summary CSV files
  should be written. No files are written by default.
