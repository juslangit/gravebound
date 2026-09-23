#!/usr/bin/env python3
"""Build Gravebound's record from its knowledge base and screenshots; publish locally."""
from pathlib import Path
import runpy
import sys
import subprocess

ROOT = Path(__file__).resolve().parents[2]
GALLERIES = ["default", "draw", "volley", "run", "animation_attack", "animation_run"]
if __name__ == "__main__":
    builder = runpy.run_path(str(Path.home() / ".local/bin/docs-build"))
    builder["build"].__globals__["pictures"] = lambda project: [
        (f"docs/shots/{name}.png", "Gameplay and animation review") for name in GALLERIES
        if (project / f"docs/shots/{name}.png").exists()
    ]
    builder["build"](ROOT)
    if "--publish" in sys.argv:
        subprocess.run([str(Path.home() / ".local/bin/docs-site"), "publish"], check=True)
