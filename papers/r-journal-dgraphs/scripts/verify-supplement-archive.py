#!/usr/bin/env python3
"""Verify the public R Journal supplement and optionally regenerate results."""

from __future__ import annotations

import argparse
import csv
import hashlib
import os
import subprocess
import tempfile
import zipfile
from pathlib import Path, PurePosixPath


MAX_ARCHIVE_BYTES = 10 * 1024 * 1024
REQUIRED = {
    "README.md",
    "SUPPLEMENT-MANIFEST.txt",
    "data/benchmark-session.txt",
    "data/graph-family-benchmark.csv",
    "data/pipeline-benchmark.csv",
    "scripts/generate-results.R",
}
FORBIDDEN_PARTS = {"build", "library", "output", "package", "motivation-letter"}
FORBIDDEN_SUFFIXES = {".aux", ".bbl", ".blg", ".log", ".pdf", ".tex", ".tar.gz"}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def inspect(archive_path: Path) -> str:
    if archive_path.stat().st_size > MAX_ARCHIVE_BYTES:
        raise SystemExit("Supplement ZIP exceeds 10 MiB")
    with zipfile.ZipFile(archive_path) as archive:
        names = [PurePosixPath(name) for name in archive.namelist()]
        roots = {name.parts[0] for name in names if name.parts}
        if len(roots) != 1:
            raise SystemExit("Supplement must have exactly one top-level directory")
        root = next(iter(roots))
        relative = {PurePosixPath(*name.parts[1:]).as_posix() for name in names}
        errors = []
        for name in names:
            if name.is_absolute() or ".." in name.parts:
                errors.append(f"unsafe archive path: {name}")
                continue
            item = PurePosixPath(*name.parts[1:])
            if FORBIDDEN_PARTS.intersection(item.parts):
                errors.append(f"editor/build material in public supplement: {item}")
            if any(item.as_posix().endswith(suffix) for suffix in FORBIDDEN_SUFFIXES):
                errors.append(f"forbidden file type in public supplement: {item}")
        missing = sorted(REQUIRED.difference(relative))
        if missing:
            errors.append("missing required files: " + ", ".join(missing))
        if errors:
            raise SystemExit("\n".join(errors))

        manifest_name = f"{root}/SUPPLEMENT-MANIFEST.txt"
        manifest = archive.read(manifest_name).decode("utf-8")
        for line in manifest.splitlines():
            expected, item = line.split("  ", 1)
            actual = digest(archive.read(f"{root}/{item}"))
            if actual != expected:
                raise SystemExit(f"checksum mismatch: {item}")
    return root


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def compare_non_timing(before: list[dict[str, str]], after: list[dict[str, str]]) -> None:
    stripped_before = [{k: v for k, v in row.items() if k != "elapsed_seconds"}
                       for row in before]
    stripped_after = [{k: v for k, v in row.items() if k != "elapsed_seconds"}
                      for row in after]
    if stripped_before != stripped_after:
        raise SystemExit("regeneration changed non-timing benchmark fields")


def validate_data(root: Path) -> None:
    pipeline = read_rows(root / "data/pipeline-benchmark.csv")
    families = read_rows(root / "data/graph-family-benchmark.csv")
    if len(pipeline) != 81 or len(families) != 96:
        raise SystemExit(
            f"unexpected benchmark row counts: pipeline={len(pipeline)}, families={len(families)}"
        )
    if any(row.get("edge_set_matches") != "TRUE" for row in pipeline):
        raise SystemExit("pipeline benchmark contains a failed edge-set parity row")
    session = (root / "data/benchmark-session.txt").read_text(encoding="utf-8")
    for marker in ("dgraphs: 0.2.0", "FNN:", "dbscan:", "igraph:"):
        if marker not in session:
            raise SystemExit(f"environment record lacks {marker}")


def regenerate(root: Path) -> None:
    before_pipeline = read_rows(root / "data/pipeline-benchmark.csv")
    before_families = read_rows(root / "data/graph-family-benchmark.csv")
    environment = os.environ.copy()
    environment["R_MAKEVARS_USER"] = "/dev/null"
    subprocess.run(
        ["Rscript", "scripts/generate-results.R"],
        cwd=root,
        env=environment,
        check=True,
        timeout=300,
    )
    compare_non_timing(before_pipeline, read_rows(root / "data/pipeline-benchmark.csv"))
    compare_non_timing(before_families, read_rows(root / "data/graph-family-benchmark.csv"))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("--execute", action="store_true")
    arguments = parser.parse_args()
    archive_path = arguments.archive.resolve()
    archive_root = inspect(archive_path)
    with tempfile.TemporaryDirectory(prefix="dgraphs-supplement-verify-") as tmp:
        destination = Path(tmp)
        with zipfile.ZipFile(archive_path) as archive:
            archive.extractall(destination)
        root = destination / archive_root
        validate_data(root)
        subprocess.run(
            ["Rscript", "-e", "parse(file='scripts/generate-results.R')"],
            cwd=root,
            check=True,
            stdout=subprocess.DEVNULL,
        )
        if arguments.execute:
            regenerate(root)
    suffix = " and regeneration parity" if arguments.execute else ""
    print(f"Supplement passed structural, checksum, data{suffix} checks.")


if __name__ == "__main__":
    main()
