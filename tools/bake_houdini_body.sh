#!/usr/bin/env bash
# Bakes the prepared Houdini base bodies (HoudiniBody.bake): run after changing game/skater/houdini_body.gd or a
# base_body_<type>.glb. tests/unit/test_houdini_body.gd fails while a bake is stale.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
exec 9>/tmp/skate_import.lock
flock 9
"$GODOT" --headless --path . --import >/tmp/godot_import.log 2>&1 || { cat /tmp/godot_import.log; exit 1; }
flock -u 9
"$GODOT" --headless --path . -s res://tools/bake_houdini_body.gd
