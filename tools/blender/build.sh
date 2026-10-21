#!/usr/bin/env bash
# Rebuilds the Blender base bodies: Godot rig dump -> Blender model/rig/weights -> GLB -> import.
# Usage: tools/blender/build.sh [--render <dir>]   (BPY defaults to /tmp/lead/bpyenv/bin/python, see
# docs/blender_pipeline.md). Quiet: prints the per-body summary lines and any errors.
set -euo pipefail
cd "$(dirname "$0")/../.."
BPY="${BPY:-/tmp/lead/bpyenv/bin/python}"
GODOT="${GODOT:-godot}"
RENDER=""
[ "${1:-}" = "--render" ] && RENDER="${2:-/tmp/lead/blender}"
# The rig dump loads game classes, so the class cache must be fresh. Only the import takes the shared lock.
flock /tmp/skate_import.lock timeout 300 "$GODOT" --headless --path . --import >/tmp/blender_build_import.log 2>&1 \
  || { cat /tmp/blender_build_import.log; exit 1; }
# A dump taken while any game script fails to compile is wrong (missing garments, stale pivots): stop instead.
timeout 300 xvfb-run -a "$GODOT" --rendering-driver opengl3 --path . -s res://tools/blender/dump_rig.gd \
  -- --out=/tmp/blender_rig_dump.json >/tmp/blender_build_dump.log 2>&1 || true
if grep -q "SCRIPT ERROR" /tmp/blender_build_dump.log || ! grep -q "dump_rig: wrote" /tmp/blender_build_dump.log; then
  grep -E "SCRIPT ERROR|dump_rig" /tmp/blender_build_dump.log | head -5
  echo "build: rig dump failed (game scripts must compile); assets unchanged"; exit 1
fi
cp /tmp/blender_rig_dump.json tools/blender/rig_rest.json
"$BPY" tools/blender/base_body.py --out assets/characters 2>&1 | grep -E "base_body:|Error|Traceback" || true
flock /tmp/skate_import.lock timeout 300 "$GODOT" --headless --path . --import >/tmp/blender_build_import.log 2>&1 \
  || { cat /tmp/blender_build_import.log; exit 1; }
if [ -n "$RENDER" ]; then
  "$BPY" tools/blender/render_check.py --out "$RENDER" 2>&1 | grep -E "render_check|Error|Traceback" || true
fi
