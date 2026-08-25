#!/usr/bin/env python3
"""Build the public, benchmark-focused R Journal supplement."""

from __future__ import annotations

import argparse
import hashlib
import shutil
import tempfile
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARCHIVE_ROOT = "dgraphs-r-journal-supplement"
MAX_ARCHIVE_BYTES = 10 * 1024 * 1024
FILES = (
    ("supplement/README.md", "README.md"),
    ("data/benchmark-session.txt", "data/benchmark-session.txt"),
    ("data/graph-family-benchmark.csv", "data/graph-family-benchmark.csv"),
    ("data/pipeline-benchmark.csv", "data/pipeline-benchmark.csv"),
    ("scripts/generate-results.R", "scripts/generate-results.R"),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def stage_files(stage: Path) -> None:
    missing = [source for source, _ in FILES if not (ROOT / source).is_file()]
    if missing:
        raise SystemExit("Missing supplement inputs: " + ", ".join(missing))
    for source, destination in FILES:
        target = stage / destination
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / source, target)


def write_manifest(stage: Path) -> None:
    entries = []
    for path in sorted(item for item in stage.rglob("*") if item.is_file()):
        relative = path.relative_to(stage).as_posix()
        entries.append(f"{sha256(path)}  {relative}")
    (stage / "SUPPLEMENT-MANIFEST.txt").write_text(
        "\n".join(entries) + "\n", encoding="utf-8"
    )


def build_zip(stage: Path, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + ".tmp")
    if temporary.exists():
        temporary.unlink()
    with zipfile.ZipFile(
        temporary, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
    ) as archive:
        for path in sorted(item for item in stage.rglob("*") if item.is_file()):
            relative = path.relative_to(stage)
            archive.write(path, (Path(ARCHIVE_ROOT) / relative).as_posix())
    temporary.replace(output)
    if output.stat().st_size > MAX_ARCHIVE_BYTES:
        raise SystemExit(f"Supplement exceeds 10 MiB: {output.stat().st_size} bytes")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    arguments = parser.parse_args()
    output = arguments.output
    if not output.is_absolute():
        output = ROOT / output
    with tempfile.TemporaryDirectory(prefix="dgraphs-r-journal-supplement-") as tmp:
        stage = Path(tmp) / ARCHIVE_ROOT
        stage.mkdir()
        stage_files(stage)
        write_manifest(stage)
        build_zip(stage, output)
    print(f"Built {output} ({output.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
