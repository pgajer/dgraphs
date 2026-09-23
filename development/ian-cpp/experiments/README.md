# IAN experiment catalogue

Start with the [project aims](../docs/project-aims.md), [synthesis](synthesis.md) and [HTML catalogue](build/index.html). The catalogue contains 18 executed questions across 17 independently accepted bounded milestones, three newly executed studies awaiting independent review, and five separate unexecuted proposals. Historical phases and evidence stay in place. `.yml` files use JSON syntax, valid YAML 1.2, so no YAML package is needed.

## Rebuild presentation only

Working directory: the implementation worktree containing this file. Use Python 3 with ReportLab, pypdf and Pillow, Pandoc on PATH, and Poppler's pdftoppm. On the authoring host the bundled Python is `/Users/pgajer/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3`, Pandoc is `/Users/pgajer/bin/pandoc`, and pdftoppm is `/opt/homebrew/bin/pdftoppm`. The PDF font is `/Library/Fonts/Arial Unicode.ttf`; pass `IAN_CATALOGUE_FONT` to use a compatible Unicode TrueType font on another host.

```sh
python3 development/ian-cpp/experiments/scripts/build_figures.py
python3 development/ian-cpp/experiments/026-helix-arithmetic/build_figure.py
python3 development/ian-cpp/experiments/scripts/build_catalogue.py
python3 development/ian-cpp/experiments/scripts/check_catalogue.py
```

The first command reconstructs four presentation figures from the maintained aggregate snapshot. The new helix figure command reconstructs its separately bound snapshot. The catalogue command renders all records and shared documents, then assembles a bookmarked PDF book. Neither runs an optimizer or reads private operational evidence. The final command validates maintained identities, dependencies, local links, source-to-render hashes and book assembly. It is an author check, not an independent numerical audit.

All generated assets and QA belong in ignored `build/` directories. Rendering never edits maintained prose, metadata or audit summaries. Do not reuse stale partial builds. The renderer rebuilds every HTML record and preserves an existing independently reviewed PDF only when its bytes match the accepted hash; otherwise it renders the reviewed source anew. External backup/archive coverage is unknown. These files are local project artifacts: absolute evidence links require the original authorized filesystem.

## Maintenance

Edit reports directly; never rerun the private one-time authoring scripts over maintained records. Give a new scientific question a stable identifier; record new analyses separately from chart reconstruction and rendering. Update audit-summary.json deliberately when a report changes, retaining the earlier report hash/review in audit history. Acceptance of historical evidence never automatically covers changed prose. Add substantive corrections as maintained sources and link their exact independent review.

The [discovery inventory](discovery-inventory.json), [audit coverage](audit-coverage.md), [policy registry](numerical-policies.yml), [fixture register](fixture-register.yml), [correction register](correction-dispositions.json), [figure selection](meeting-figure-selection.md) and [analysis queue](analysis-queue.md) define the catalogue's scope and limits. The private handoff records the organization and author QA; it is not a scientific build dependency.
