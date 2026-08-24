#!/usr/bin/env python3
"""Scan the R Journal sources and rendered artifacts for release defects."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TEXT = [
    ROOT / "dgraphs.Rmd",
    ROOT / "RJreferences.bib",
    ROOT / "citation_verification.html",
    ROOT / "motivation-letter" / "motivation-letter.md",
    ROOT / "data" / "benchmark-session.txt",
]
TEXT.extend(sorted((ROOT / "scripts").glob("*.R")))
TEXT.extend(path for path in sorted((ROOT / "scripts").glob("*.py"))
            if path.name != Path(__file__).name)

PATTERNS = {
    "private absolute path": re.compile(r"/Users/|/home/|[A-Za-z]:\\\\"),
    "prompt trace": re.compile(r"(?i)ignore previous|system prompt|chatgpt said|as an ai"),
    "unresolved marker": re.compile(r"(?i)\b(?:TODO|FIXME|TBD|XXX)\b|\[\s*insert\b"),
    "template residue": re.compile(r"(?i)quokka|bilby|penguins|ToOoOlTiPs"),
}

errors: list[str] = []
for path in TEXT:
    if not path.exists():
        errors.append(f"missing source: {path.relative_to(ROOT)}")
        continue
    source = path.read_text(encoding="utf-8", errors="replace")
    for label, pattern in PATTERNS.items():
        for match in pattern.finditer(source):
            line = source.count("\n", 0, match.start()) + 1
            errors.append(f"{path.relative_to(ROOT)}:{line}: {label}: {match.group(0)!r}")

rmd_source = (ROOT / "dgraphs.Rmd").read_text(encoding="utf-8")
table_alt_chunks = re.findall(r"^```\{r [^\n]*\btab\.alt=", rmd_source, re.MULTILINE)
if len(table_alt_chunks) != 5:
    errors.append(
        f"expected five table chunks with tab.alt metadata; found {len(table_alt_chunks)}"
    )
if rmd_source.count("accessible.kable(") != 5:
    errors.append("expected five tables rendered through accessible.kable()")
if re.search(r"(?m)^draft\s*:", rmd_source):
    errors.append("article YAML still marks the manuscript as a draft")
if "normalized_mae" in rmd_source or "Stress-1" not in rmd_source:
    errors.append("article does not consistently distinguish relative RMSE from Stress-1")

letter_source = (ROOT / "motivation-letter" / "motivation-letter.md").read_text(
    encoding="utf-8"
)
if "official spelling" not in letter_source or "title-case diagnostic" not in letter_source:
    errors.append("motivation letter does not document the lowercase title exception")

bib_source = (ROOT / "RJreferences.bib").read_text(encoding="utf-8")
if "note = {R package version 0.2.0}" not in bib_source:
    errors.append("dgraphs bibliography entry does not identify version 0.2.0")

pdf = ROOT / "output" / "pdf" / "dgraphs-r-journal.pdf"
html = ROOT / "output" / "html" / "dgraphs-r-journal.html"
for path in (pdf, html):
    if not path.exists() or path.stat().st_size == 0:
        errors.append(f"missing or empty artifact: {path.relative_to(ROOT)}")

if pdf.exists():
    info = subprocess.run(["pdfinfo", str(pdf)], capture_output=True, text=True)
    page_match = re.search(r"^Pages:\s+(\d+)", info.stdout, re.MULTILINE)
    if info.returncode or not page_match:
        errors.append("could not determine PDF page count")
    elif int(page_match.group(1)) > 20:
        errors.append(f"PDF exceeds 20 pages: {page_match.group(1)}")

    fonts = subprocess.run(["pdffonts", str(pdf)], capture_output=True, text=True)
    if fonts.returncode:
        errors.append("pdffonts could not inspect the PDF")
    else:
        for line in fonts.stdout.splitlines()[2:]:
            fields = line.split()
            if len(fields) >= 8 and fields[-5] == "no":
                errors.append("unembedded PDF font: " + line.strip())

    rendered = subprocess.run(
        ["pdftotext", str(pdf), "-"], capture_output=True, text=True
    )
    if rendered.returncode:
        errors.append("pdftotext could not inspect the PDF")
    elif re.search(r"\?\?|Quietest Quokka|ToOoOlTiPs", rendered.stdout):
        errors.append("rendered PDF contains unresolved or template text")

tex = ROOT / "dgraphs.tex"
if not tex.exists():
    errors.append("missing generated dgraphs.tex")
else:
    tex_text = tex.read_text(encoding="utf-8", errors="replace")
    if tex_text.count(r"\includegraphics") < 3:
        errors.append("generated TeX contains fewer than three plot inclusions")
    if len(re.findall(r"\\caption\{\\label\{tab:", tex_text)) < 5:
        errors.append("generated TeX contains fewer than five captioned tables")

for log in sorted(ROOT.glob("*.log")) + sorted((ROOT / "build").glob("*.log")):
    content = log.read_text(encoding="utf-8", errors="replace")
    for pattern, label in [
        (r"undefined references", "undefined references"),
        (r"Citation [`'][^`']+['`].*undefined", "undefined citation"),
        (r"Overfull \\hbox", "overfull box"),
    ]:
        if re.search(pattern, content, re.IGNORECASE):
            errors.append(f"{log.relative_to(ROOT)}: {label}")

if html.exists():
    html_text = html.read_text(encoding="utf-8", errors="replace")
    if re.search(r"citeproc-not-found|data-cites=\"\"", html_text):
        errors.append("rendered HTML contains unresolved citations")
    if html_text.count("<table aria-label=") < 5:
        errors.append("rendered HTML contains fewer than five accessible tables")

if errors:
    print("R Journal readiness scan failed:")
    for error in errors:
        print("-", error)
    raise SystemExit(1)
print("R Journal readiness scan passed.")
