#!/usr/bin/env bash
# Export the local Mac prototype and sign it with this Mac's stable certificate.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
mkdir -p "$ROOT/build"
"$GODOT" --headless --path "$ROOT" --editor --import --quit
"$GODOT" --headless --path "$ROOT" --export-release macOS "$ROOT/build/Gravebound.app"
"$HOME/Desktop/project/3d/bengkel/common/sign.sh" "$ROOT/build/Gravebound.app"
