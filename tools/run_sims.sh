#!/usr/bin/env bash
# Scripted skater controller sims, headless. Usage: tools/run_sims.sh
# Runs the controller scenarios (tests/sim/controller_sims.tscn) and the ride-feel regression sims
# (tests/sim/sim_suite.tscn: sim_*.gd). Prints one "SIM <name> PASS|FAIL <detail>" line per scenario (INFO = report only)
# and one combined "SIMS passed=N failed=M total=T". Exit 1 on any failure or if a scene dies before printing its totals.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# Only the import needs the shared lock; the scene runs take none.
(flock 9; "$GODOT" --headless --path . --import) 9>/tmp/skate_import.lock >/tmp/godot_import.log 2>&1 || { cat /tmp/godot_import.log; exit 1; }
passed=0; failed=0; rc=0
for scene in controller_sims sim_suite; do
  out=$(timeout 600 "$GODOT" --headless --path . "res://tests/sim/$scene.tscn" 2>&1 \
    | grep -vE '^(Godot Engine v|$|WARNING: .*audio|   at: )')
  echo "$out" | grep -v '^SIMS passed='
  totals=$(echo "$out" | grep '^SIMS passed=' | tail -1)
  if [[ -z "$totals" ]]; then
    echo "SIM $scene FAIL scene ended without printing its SIMS totals (crash, script error or timeout)"
    failed=$((failed + 1)); rc=1; continue
  fi
  p=${totals#SIMS passed=}; p=${p%% *}
  f=${totals##*failed=}
  passed=$((passed + p)); failed=$((failed + f))
done
(( failed > 0 )) && rc=1
echo "SIMS passed=$passed failed=$failed total=$((passed + failed))"
exit "$rc"
