#!/usr/bin/env python3
"""Check rendered citations, BibTeX entries, and verification evidence."""

from __future__ import annotations

import argparse
import re
from collections import Counter
from html.parser import HTMLParser
from pathlib import Path


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


class VerificationParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.entries: list[dict[str, object]] = []
        self.active: list[dict[str, object]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = {key: value or "" for key, value in attrs}
        if "data-citation-key" in values:
            entry = {
                "key": values["data-citation-key"].strip(),
                "status": values.get("data-status", "").strip(),
                "links": [],
                "tag": tag,
            }
            self.entries.append(entry)
            self.active.append(entry)
        if self.active and tag == "a" and "data-source-link" in values:
            self.active[-1]["links"].append(values.get("href", "").strip())

    def handle_endtag(self, tag: str) -> None:
        if self.active and self.active[-1]["tag"] == tag:
            self.active.pop()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tex", required=True, type=Path)
    parser.add_argument("--bib", required=True, type=Path)
    parser.add_argument("--html", required=True, type=Path)
    parser.add_argument("--log", type=Path)
    args = parser.parse_args()

    missing = [path for path in (args.tex, args.bib, args.html) if not path.exists()]
    if missing:
        raise SystemExit("Missing citation input: " + ", ".join(map(str, missing)))

    tex = re.sub(r"(?m)(?<!\\)%.*$", "", read(args.tex))
    cited: set[str] = set()
    for match in re.finditer(
        r"\\(?:[A-Za-z]*cite[A-Za-z]*|nocite)\*?(?:\s*\[[^]]*\])*\s*\{([^{}]+)\}",
        tex,
    ):
        cited.update(key.strip() for key in match.group(1).split(",") if key.strip() != "*")

    bib = set(re.findall(r"@\s*[A-Za-z]+\s*[({]\s*([^,\s]+)\s*,", read(args.bib)))
    verification = VerificationParser()
    verification.feed(read(args.html))
    keys = [str(entry["key"]) for entry in verification.entries]
    entries = {str(entry["key"]): entry for entry in verification.entries}

    errors: list[str] = []
    if not cited:
        errors.append("no citations found in rendered TeX")
    if cited - bib:
        errors.append("missing BibTeX keys: " + ", ".join(sorted(cited - bib)))
    if cited - set(keys):
        errors.append("missing verification entries: " + ", ".join(sorted(cited - set(keys))))
    if set(keys) - cited:
        errors.append("uncited verification entries: " + ", ".join(sorted(set(keys) - cited)))
    duplicates = [key for key, count in Counter(keys).items() if count > 1]
    if duplicates:
        errors.append("duplicate verification entries: " + ", ".join(sorted(duplicates)))
    for key in cited & set(keys):
        entry = entries[key]
        if entry["status"] != "verified":
            errors.append(f"non-passing status for {key}: {entry['status']}")
        if not any(str(link) for link in entry["links"]):
            errors.append(f"missing source link for {key}")
    if args.log and args.log.exists():
        log = read(args.log)
        if re.search(r"Citation [`'][^`']+['`].*undefined", log, re.IGNORECASE):
            errors.append("LaTeX log reports an undefined citation")

    if errors:
        print("Citation verification failed:")
        for error in errors:
            print("-", error)
        return 1
    print("Citation verification passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
