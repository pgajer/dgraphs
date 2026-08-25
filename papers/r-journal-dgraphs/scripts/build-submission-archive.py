#!/usr/bin/env python3
"""Build a clean, explicit R Journal submission archive."""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = ROOT.parents[1]
ARCHIVE_ROOT = "dgraphs-r-journal"
MAX_ARCHIVE_BYTES = 10 * 1024 * 1024

FILES = (
    "Makefile",
    "dgraphs.Rmd",
    "dgraphs.R",
    "dgraphs.html",
    "dgraphs.tex",
    "dgraphs.pdf",
    "RJwrapper.tex",
    "RJournal.sty",
    "RJreferences.bib",
    "_Rpackages.txt",
    "citation_verification.html",
    "motivation-letter/motivation-letter.md",
    "motivation-letter/motivation-letter.pdf",
    "data/benchmark-session.txt",
    "data/graph-family-benchmark.csv",
    "data/pipeline-benchmark.csv",
    "dgraphs_files/figure-latex/workflow-figure-1.pdf",
    "dgraphs_files/figure-latex/pipeline-timing-1.pdf",
    "dgraphs_files/figure-latex/family-fidelity-1.pdf",
    "scripts/check-citation-verification.py",
    "scripts/check-public-version.R",
    "scripts/check-submission-date.R",
    "scripts/generate-results.R",
    "scripts/readiness-scan.py",
    "scripts/render-paper.R",
    "scripts/run-rjtools-checks.R",
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def copy_required_files(stage: Path) -> None:
    missing = [relative for relative in FILES if not (ROOT / relative).is_file()]
    if missing:
        raise SystemExit(
            "Render the article before archiving; missing: " + ", ".join(missing)
        )
    for relative in FILES:
        destination = stage / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / relative, destination)


def build_package(stage: Path, work: Path) -> Path:
    environment = os.environ.copy()
    environment["R_MAKEVARS_USER"] = "/dev/null"
    subprocess.run(
        ["R", "CMD", "build", str(REPOSITORY)],
        cwd=work,
        env=environment,
        check=True,
    )
    tarballs = sorted(work.glob("dgraphs_*.tar.gz"))
    if len(tarballs) != 1:
        raise SystemExit("Expected exactly one freshly built dgraphs source tarball")
    destination = stage / "package" / tarballs[0].name
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(tarballs[0], destination)
    return destination


def write_manifest(stage: Path) -> None:
    entries = []
    for path in sorted(item for item in stage.rglob("*") if item.is_file()):
        relative = path.relative_to(stage).as_posix()
        entries.append(f"{sha256(path)}  {relative}")
    (stage / "SUBMISSION-MANIFEST.txt").write_text(
        "SHA-256 checksums for the dgraphs R Journal submission\n\n"
        + "\n".join(entries)
        + "\n",
        encoding="utf-8",
    )


def build_zip(stage: Path, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary_output = output.with_suffix(output.suffix + ".tmp")
    if temporary_output.exists():
        temporary_output.unlink()
    with zipfile.ZipFile(
        temporary_output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
    ) as archive:
        for path in sorted(item for item in stage.rglob("*") if item.is_file()):
            relative = path.relative_to(stage)
            archive.write(path, (Path(ARCHIVE_ROOT) / relative).as_posix())
    temporary_output.replace(output)
    if output.stat().st_size > MAX_ARCHIVE_BYTES:
        raise SystemExit(
            f"Submission archive exceeds 10 MiB: {output.stat().st_size} bytes"
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    arguments = parser.parse_args()
    output = arguments.output
    if not output.is_absolute():
        output = ROOT / output

    with tempfile.TemporaryDirectory(prefix="dgraphs-r-journal-archive-") as tmp:
        work = Path(tmp)
        stage = work / ARCHIVE_ROOT
        stage.mkdir()
        copy_required_files(stage)
        build_package(stage, work)
        write_manifest(stage)
        build_zip(stage, output)

    print(f"Built {output} ({output.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
