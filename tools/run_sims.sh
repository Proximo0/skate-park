#!/usr/bin/env bash
# Scripted skater controller sims, headless. Usage: tools/run_sims.sh
# Prints one "SIM <name> PASS|FAIL <detail>" line per scenario and "SIMS passed=N failed=M". Exit code passes through.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# Only the import needs the shared lock; the scene run takes none.
(flock 9; "$GODOT" --headless --path . --import) 9>/tmp/skate_import.lock >/tmp/godot_import.log 2>&1 || { cat /tmp/godot_import.log; exit 1; }
"$GODOT" --headless --path . res://tests/sim/controller_sims.tscn 2>&1 \
  | grep -vE '^(Godot Engine v|$|WARNING: .*audio|   at: )'
exit "${PIPESTATUS[0]}"
