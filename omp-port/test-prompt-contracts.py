#!/usr/bin/env python3
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

port_dir = Path(__file__).resolve().parent
plugin = port_dir.parent / "plugins" / "pstack"
with tempfile.TemporaryDirectory(prefix="pstack-contracts-") as temp:
    fixture = Path(temp) / "plugin"
    shutil.copytree(plugin, fixture)
    link_check = [sys.executable, str(port_dir / "check-links.py"), str(fixture)]
    baseline = subprocess.run(link_check, capture_output=True, text=True)
    if baseline.returncode:
        raise SystemExit(baseline.stdout + baseline.stderr)
    help_file = fixture / "skills" / "poteto-help" / "SKILL.md"
    help_file.write_text(help_file.read_text() + "\n[missing guide](../../docs/guide/missing.md)\n")
    broken = subprocess.run(link_check, capture_output=True, text=True)
    assert broken.returncode == 1 and "missing.md" in broken.stdout, broken
    print("Missing local guide links are rejected.")
