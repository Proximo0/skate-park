#!/usr/bin/env bash
# Physics lab: runs scripted manoeuvres headless and prints a metrics table against data/physics_targets.json.
# Usage: tools/physics_report.sh [--tune=preset.json] [--only=metric_prefix]
# Prints "LAB <metric> <value> <unit> target=<t> ok=[min,max] PASS|WARN" lines and "LAB summary pass=N warn=M".
# Writes /tmp/lab/report.json and /tmp/lab/report.md. Exit 0 even with WARNs; 1 only if a manoeuvre crashed or the scene died.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# Only the import needs the shared lock; the scene run takes none.
(flock 9; "$GODOT" --headless --path . --import) 9>/tmp/skate_import.lock >/tmp/godot_import.log 2>&1 || { cat /tmp/godot_import.log; exit 1; }
out=$(timeout 600 "$GODOT" --headless --fixed-fps 60 --path . res://tests/lab/physics_lab.tscn -- "$@" 2>&1 \
  | grep -vE '^(Godot Engine v|$|WARNING: .*audio|   at: )')
echo "$out"
if ! echo "$out" | grep -q '^LAB summary '; then
  echo "LAB crash scene ended without printing its summary (crash, script error or timeout)"
  exit 1
fi
echo "$out" | grep -q '^LAB crash ' && exit 1
exit 0
