#!/usr/bin/env python3
"""Keep manuscript workspaces out of the public package."""
from pathlib import Path
import subprocess
import sys
root = Path(__file__).resolve().parents[1]
paths = subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=root).decode().split("\0")
prefixes = ("papers/", "reports/", "dev/papers/")
research_notes = {"docs/radEmu_compositional_implications_for_dgraphs.md", "docs/compositional-references.bib", "docs/compositional-citation-verification.html"}
bad = sorted({p for p in paths if p and (p.startswith(prefixes) or p in research_notes)})
if bad:
    print("Manuscript assets belong in the private manuscript repository:", file=sys.stderr)
    print("\n".join(bad[:20]), file=sys.stderr)
    sys.exit(1)
print("No manuscript workspaces in the public source tree.")
