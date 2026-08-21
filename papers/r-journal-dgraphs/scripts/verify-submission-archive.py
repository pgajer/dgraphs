#!/usr/bin/env python3
"""Inspect and reproduce an R Journal submission ZIP in isolation."""

from __future__ import annotations

import argparse
import os
import subprocess
import tempfile
import time
import zipfile
from pathlib import Path, PurePosixPath


MAX_ARCHIVE_BYTES = 10 * 1024 * 1024
FORBIDDEN_PARTS = {
    "build",
    "library",
    "output",
    "tmp",
    "__pycache__",
    ".cache",
}
FORBIDDEN_SUFFIXES = {
    ".aux",
    ".bbl",
    ".blg",
    ".log",
    ".out",
    ".toc",
}
REQUIRED = {
    "Makefile",
    "dgraphs.Rmd",
    "dgraphs.R",
    "dgraphs.tex",
    "dgraphs.pdf",
    "RJwrapper.tex",
    "RJournal.sty",
    "RJreferences.bib",
    "_Rpackages.txt",
    "citation_verification.html",
    "SUBMISSION-MANIFEST.txt",
    "motivation-letter/motivation-letter.md",
    "motivation-letter/motivation-letter.pdf",
    "data/benchmark-session.txt",
    "data/graph-family-benchmark.csv",
    "data/pipeline-benchmark.csv",
    "dgraphs_files/figure-latex/workflow-figure-1.pdf",
    "dgraphs_files/figure-latex/pipeline-timing-1.pdf",
    "dgraphs_files/figure-latex/family-fidelity-1.pdf",
    "scripts/generate-results.R",
    "scripts/render-paper.R",
}


def inspect_archive(archive_path: Path) -> str:
    if archive_path.stat().st_size > MAX_ARCHIVE_BYTES:
        raise SystemExit("Submission ZIP exceeds 10 MiB")
    with zipfile.ZipFile(archive_path) as archive:
        names = [PurePosixPath(name) for name in archive.namelist()]
    roots = {name.parts[0] for name in names if name.parts}
    if len(roots) != 1:
        raise SystemExit("Submission ZIP must have exactly one top-level directory")
    root = next(iter(roots))
    errors = []
    relative_names = set()
    for name in names:
        if name.is_absolute() or ".." in name.parts:
            errors.append(f"unsafe archive path: {name}")
            continue
        relative = PurePosixPath(*name.parts[1:])
        relative_names.add(relative.as_posix())
        if FORBIDDEN_PARTS.intersection(relative.parts):
            errors.append(f"forbidden directory in archive: {relative}")
        if relative.suffix.lower() in FORBIDDEN_SUFFIXES:
            errors.append(f"forbidden build product in archive: {relative}")
        if relative.name == "dgraphs.html":
            errors.append("duplicate rendered HTML article is present")
    missing = sorted(REQUIRED.difference(relative_names))
    if missing:
        errors.append("missing required files: " + ", ".join(missing))
    package_tarballs = [
        name for name in relative_names
        if name.startswith("package/dgraphs_") and name.endswith(".tar.gz")
    ]
    if len(package_tarballs) != 1:
        errors.append("archive must contain exactly one dgraphs source tarball")
    if errors:
        raise SystemExit("\n".join(errors))
    return root


def reproduce(archive_path: Path, root: str) -> float:
    environment = os.environ.copy()
    environment["R_MAKEVARS_USER"] = "/dev/null"
    with tempfile.TemporaryDirectory(prefix="dgraphs-r-journal-verify-") as tmp:
        destination = Path(tmp)
        with zipfile.ZipFile(archive_path) as archive:
            archive.extractall(destination)
        article = destination / root
        started = time.monotonic()
        subprocess.run(
            ["make", "reproduce"],
            cwd=article,
            env=environment,
            check=True,
            timeout=600,
        )
        elapsed = time.monotonic() - started
        expected = (
            article / "output" / "pdf" / "dgraphs-r-journal.pdf",
            article / "output" / "html" / "dgraphs-r-journal.html",
        )
        if any(not path.is_file() or path.stat().st_size == 0 for path in expected):
            raise SystemExit("Isolated reproduction did not create both article outputs")
    return elapsed


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    arguments = parser.parse_args()
    archive_path = arguments.archive.resolve()
    root = inspect_archive(archive_path)
    elapsed = reproduce(archive_path, root)
    print(
        f"Submission archive passed structural and isolated reproduction checks "
        f"in {elapsed:.1f} seconds."
    )


if __name__ == "__main__":
    main()
