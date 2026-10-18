#!/usr/bin/env python3
import re
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
missing = []
for source in sorted((root / "skills").rglob("*.md")):
    if "node_modules" in source.relative_to(root).parts:
        continue
    for target in re.findall(r"\]\(([^)]+)\)", source.read_text()):
        target = target.split("#", 1)[0]
        if not target or re.match(r"[a-zA-Z][a-zA-Z0-9+.-]*:", target):
            continue
        # Upstream's citation template uses [label](url), not a local file.
        if target == "url":
            continue
        if not (source.parent / target).exists():
            missing.append(f"{source.relative_to(root)}: {target}")
for item in missing:
    print(item)
sys.exit(bool(missing))
