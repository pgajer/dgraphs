# Build evidence notes

The development extraction build at `67bb6ce` succeeded. The frozen regression
driver at `984ea50` completed with exact native traces apart from elapsed time.

The first clean build, at `264309d`, rebuilt the solver, core, installed-header
consumer and R bridge successfully. Inspection afterward found a logging error
in the build harness: the vendor command's log directory was also its crate
destination. Cargo replaced that directory, unlinking the open stdout/stderr
files. The command's recorded exit status is zero and the later build logs remain,
but the initial vendoring log text is unavailable. This is an evidence-harness
defect, not a failed optimization or a numerical implementation discrepancy.

The correction separates `vendor-command` logs from `vendor` crate sources. A
second clean namespace repeats the build with preserved logs. The first build is
retained. No numerical run used that first clean build. R comparison data are
transferred as little-endian binary doubles to avoid introducing a decimal-parser
comparison into the core/R interface test. No solver or algorithm policy changes.
