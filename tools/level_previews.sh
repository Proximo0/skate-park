#!/usr/bin/env bash
# Renders the level-select preview images (game/levels/previews/<id>.png) with a real renderer under xvfb.
# Usage: tools/level_previews.sh [level_id ...]   (no ids = every LevelRegistry level)
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
(flock 9; "$GODOT" --headless --path . --import) 9>/tmp/skate_import.lock >/tmp/godot_import.log 2>&1 || { cat /tmp/godot_import.log; exit 1; }
timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --rendering-driver opengl3 --path . -s res://tools/level_previews.gd -- --scripted "$@" 2>&1 \
  | grep -E '^preview |ERROR|SCRIPT' | grep -v 'ERR_CANT_OPEN'
# re-import so the new pngs are textures the level select can load
(flock 9; "$GODOT" --headless --path . --import) 9>/tmp/skate_import.lock >/tmp/godot_import.log 2>&1
