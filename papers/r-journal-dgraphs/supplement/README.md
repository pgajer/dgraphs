# dgraphs R Journal benchmark supplement

This supplement contains the recorded benchmark inputs used by the dgraphs
package article and the script that produced them. It is intentionally separate
from the editor-facing submission archive: it contains no motivation letter,
rendered article products, installed package library, or package source
tarball.

## File map

| File | Purpose |
| --- | --- |
| `data/pipeline-benchmark.csv` | Raw runs for the symmetric-kNN parity and timing comparison shown in Figure 2. |
| `data/graph-family-benchmark.csv` | Raw replicate-level results summarized in Figure 3 and Table 6. |
| `data/benchmark-session.txt` | R, platform, dgraphs, FNN, dbscan, and igraph versions for the recorded runs. |
| `scripts/generate-results.R` | Regenerates both CSV files and the environment record. |
| `SUPPLEMENT-MANIFEST.txt` | SHA-256 checksums for every other file in the ZIP. |

## Reproduce the article and benchmarks

The article is rendered from the repository or editor submission archive with:

```sh
cd papers/r-journal-dgraphs
make render
```

To regenerate the benchmark results from an unpacked supplement after
installing dgraphs 0.2.0, FNN 1.1.4.1, dbscan 1.2.3, and igraph 2.3.3, run:

```sh
Rscript scripts/generate-results.R
```

On the recorded Apple-silicon system, benchmark regeneration took about 35
seconds and a clean article reproduction, including package installation and
checks, took about two minutes. These are planning estimates, not performance
guarantees. Timing columns are hardware-, operating-system-, R-version-, and
load-specific; substantive comparisons should emphasize edge-set parity and
the non-timing graph summaries.

The recorded environment was R 4.6.1 on `aarch64-apple-darwin23`, with dgraphs
0.2.0, FNN 1.1.4.1, dbscan 1.2.3, and igraph 2.3.3. See
`data/benchmark-session.txt` for the timestamped record. After unpacking, verify
file integrity with:

```sh
shasum -a 256 -c SUPPLEMENT-MANIFEST.txt
```

The workflow, candidate graph, parameter-sequence, and geodesic examples are
evaluated during manuscript rendering. The two benchmark figures and the final
benchmark table use the precomputed CSV files listed above.
