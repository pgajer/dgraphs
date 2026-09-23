# Stage 3: correct the private R 4.5.2 build environment

23 September 2026, before replacement builds or further IAN calls.

The full R 4.5.2 package check exposed a mixed-runtime installation: its standard framework link flag resolves to the current R-devel library despite the corrected R 4.5.2 launcher. Both the main dgraphs library and reused RcppEigen link to R-devel. Several ordinary graph examples, tests and vignettes crash. Preserve all earlier package and numerical results; they demonstrate those actual installations only and do not qualify a consistently linked R 4.5.2 target. The IAN optional module has no direct libR linkage, but its host package must still be valid.

Create a new private R 4.5.2 library. Reuse a separately inventoried RcppEigen installation whose dynamic dependencies point to R 4.5, rather than the earlier mixed library. Use a private Makevars file with an explicit versioned libR path and MAKEFLAGS=-j2. The user's ordinary Makevars contains -j16; earlier command environments declared -j2 but did not isolate that file, so the actual compiler-job maximum for those builds was not established. Preserve this departure; future builds isolate the configuration. Do not alter the shared R framework or user Makevars.

Install the unchanged corrected dgraphs archive into the new library, inspect linkage, freshly build its optional backend and run full package checks. Keep upstream compiler warnings visible. Repeat the entire 26-entry R panel under the corrected environment, with accepted native/R references. This bounded continuation adds at most 26 entries and retains the cumulative 2,000-attempt, 3,600-second numerical, 4-GiB per-process and 24-GiB numerical-output limits. The new cumulative engine-entry ceiling is 90. This declared expansion corrects invalid platform evidence under the owner's authorized completion sequence; it is not a silent extension or an expanded scientific scope. No other numerical changes or new examples are planned. Resolve discrepancies before dependent calls.

Stage 4 remains gated on independent audit acceptance with every finding closed.
