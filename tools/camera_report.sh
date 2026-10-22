#!/usr/bin/env bash
# Camera continuity report: rides bot lines with the real SkateCamera, headless, and checks that the view never whips
# (max yaw rate of the view, rad/s) and never pops (max single-tick camera displacement, m; respawns excluded).
# Usage: tools/camera_report.sh [level:line ...]   (default: the lines that exposed the round-5 whips and pops)
# Prints "CAM <level> <line> max_yaw=.. max_jump=.. dist_at_speed=.." per line, then "CAM summary pass=N fail=M".
# Limits: max_yaw <= 4.0 rad/s (was 9-17), max_jump <= 0.8 m (was 1.1-2.6).
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
(flock 9; "$GODOT" --headless --path . --import) 9>/tmp/skate_import.lock >/tmp/godot_import.log 2>&1 || { cat /tmp/godot_import.log; exit 1; }
LINES=("$@")
[ ${#LINES[@]} -eq 0 ] && LINES=(practice:halfpipe practice:street_run practice:mega warehouse:spine downtown:hubba beach:pier_rail)
MAX_YAW=4.0
MAX_JUMP=0.8
tmp=$(mktemp -d)
i=0
for ll in "${LINES[@]}"; do
  lvl=${ll%%:*}; line=${ll#*:}
  timeout 250 "$GODOT" --headless --fixed-fps 60 --path . res://tests/lab/camera_lines.tscn -- --level="$lvl" --line="$line" 2>&1 | grep '^CAM ' > "$tmp/$i.txt" &
  i=$((i + 1))
  (( i % 4 == 0 )) && wait
done
wait
pass=0; fail=0
for ((j = 0; j < i; j++)); do
  l=$(cat "$tmp/$j.txt" 2>/dev/null)
  if [ -z "$l" ]; then echo "CAM crash ${LINES[$j]} no result"; fail=$((fail + 1)); continue; fi
  y=$(sed -E 's/.*max_yaw=([0-9.]+).*/\1/' <<<"$l"); m=$(sed -E 's/.*max_jump=([0-9.]+).*/\1/' <<<"$l")
  if awk "BEGIN{exit !($y <= $MAX_YAW && $m <= $MAX_JUMP)}"; then echo "$l PASS"; pass=$((pass + 1)); else echo "$l FAIL"; fail=$((fail + 1)); fi
done
rm -rf "$tmp"
echo "CAM summary pass=$pass fail=$fail"
[ $fail -eq 0 ]
