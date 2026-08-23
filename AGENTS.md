# Repository Instructions

## Scope

This repository is the development home for the `dgraphs` R package split
from `gflow`.

`dgraphs` owns data-derived graph construction utilities, including local
ANN-backed MkNN, intersection-kNN, graph-geodesic kNN, radius,
adaptive-radius, SkNN, MST-completion, graph utility, and graph diagnostic
code.

## Preferred Skills

- Prefer `$r-package-qa` for package QA, documentation drift, native build
  issues, and release-readiness work.

## R Style

- Prefer dot-delimited function and variable names for new R code.
- Keep public function names unchanged while moving methods from `gflow`; API
  cleanup should happen after the package is self-hosted and tested.
- Use leading-dot names only for private helpers.

## Package Hygiene

- Validate focused changes first:
  - `Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_dir("tests/testthat")'`
- Run `Rscript -e 'roxygen2::roxygenise()'` after exported API, native
  registration, or documentation changes.
- Run a package check equivalent after native code, dependency, or
  cross-package interface changes.
- Keep local build products, check directories, compiled objects, shared
  libraries, generated tarballs, and logs out of commits.

## Research Reports

- For HTML research reports, dashboards, and generated analysis summaries,
  follow
  `/Users/pgajer/.codex/notes/agent_instructions/reports/html_report_style_guide.md`.
- Before treating an HTML report as complete, run a figure/table quality-control
  pass using
  `/Users/pgajer/.codex/notes/agent_instructions/reports/report_figure_table_qc.md`;
  check that report goals, definitions, figure captions, interpretation text,
  readable labels, linked source tables, and non-overlapping plots are present.

## Migration Discipline

- Follow `GRAPH_MIGRATION_ACTION_PLAN.md` for the DG phase sequence and
  validation contract.
- Do not create circular dependencies between `dgraphs` and `gflow`.
- Keep bridge functions only for unmigrated surfaces, and remove the bridge
  only once `dgraphs` is self-hosted for the relevant APIs.
- For native graph-constructor phases, preserve or add parity tests against
  the pre-migration `gflow` outputs before replacing old implementations.
- Do not silently change graph semantics, graph object fields, lifecycle-stage
  behavior, or edge/weight conventions during migration.

## Private Agent Work Products

- Store internal agent-only work products under `~/.codex/private/dgraphs/`,
  not in the repository. This includes internal audits, agent-to-agent
  handoffs, intermediate rewrites, working copies of reviewer reports used for
  agent tasks, historical prompts, and generated review diffs that are not
  intended as package, manuscript, reproducibility, or submission artifacts.
- Organize private material first by workstream and then, when useful, by
  artifact type. Use clearly named workstream directories with subdirectories
  such as `audits/`, `handoffs/`, `drafts/`, `prompts/`, and `diffs/`.
- Maintain a `README.md` in each workstream directory identifying every file's
  origin, former repository location, purpose, and possible future
  disposition.
- Keep formal and publication-facing assets in the repository. Do not move
  source code, tests, package documentation, manuscript source, bibliography,
  figures, rendering tools, citation-verification evidence, reproducibility
  inputs or scripts, checksums, provenance records, or formal submission files
  into the private tree.
- Treat draft responses, internal referee simulations, and agent working copies
  of received reports as private. If a response-to-reviewers document becomes
  part of an actual submission, copy its finalized version into the appropriate
  repository submission bundle.
- Do not make repository builds, tests, manuscript renders, or validation
  workflows depend on files under the private tree.
- When retiring a tracked internal file from the repository, preserve its
  existing Git history through the normal repository deletion and record its
  private destination in the workstream README.
- The private directory is not a credentials store. Never place passwords,
  access tokens, private keys, or other authentication secrets there.
