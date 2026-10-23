#!/usr/bin/env bash
# End-to-end flight-recorder check: record a scripted 5 s ride on the test park, then replay the dump.
# Usage: tools/replay_selftest.sh [out.json]. Prints the RECORD line and the REPLAY lines; exit 1 if divergence > 1e-3 m.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="$(realpath -m "${1:-/tmp/skate_selftest/run.json}")"
mkdir -p "$(dirname "$OUT")"
(flock 9; "$GODOT" --headless --path . --import) 9>/tmp/skate_import.lock >/tmp/godot_import.log 2>&1 || { cat /tmp/godot_import.log; exit 1; }
timeout 120 "$GODOT" --headless --fixed-fps 60 --path . res://tests/replay/record_run.tscn -- "$OUT" 2>&1 | grep -E '^(RECORD|SCRIPT ERROR|ERROR)'
[ -s "$OUT" ] || { echo "SELFTEST FAIL no log written"; exit 1; }
tools/replay.sh "$OUT"
