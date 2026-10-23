#!/usr/bin/env bash
# Camera continuity report: rides bot lines with the real SkateCamera, headless, and checks that the view never whips
# (max yaw rate of the view, rad/s) and never pops (max single-tick camera displacement, m; respawns excluded).
# Also that the rider stays in frame and sized: the farthest / nearest the camera gets (bails excluded), ticks with the
# rider out of frame, and on loops the whole rotation of the view (it rolls with the board there, so the heading-based
# yaw is not gated). Usage: tools/camera_report.sh [level:line ...]   (default: the round-5 whip/pop lines plus the
# round-10 drop-in, roll-in, loop and big-drop lines). Prints the lab's "CAM <level> <line> ..." per line + PASS/FAIL,
# then "CAM summary pass=N fail=M".
# Limits: max_yaw <= 4.0 rad/s (was 9-17; loops: max_rot <= 14), max_jump <= 0.8 m (was 1.1-2.6), min_dist >= 1.5 m
# (loop was 0.34, spine 0.86), off_frame == 0 (halfpipe was 75 ticks), max_dist <= 6.5 m on drop/roll-in/snap lines
# (the 8 m tower was 11.8) and <= 8.0 m elsewhere (a big vert air pulls back to frame rider, coping and sky).
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
(flock 9; "$GODOT" --headless --path . --import) 9>/tmp/skate_import.lock >/tmp/godot_import.log 2>&1 || { cat /tmp/godot_import.log; exit 1; }
LINES=("$@")
[ ${#LINES[@]} -eq 0 ] && LINES=(practice:halfpipe practice:street_run practice:mega warehouse:spine downtown:hubba beach:pier_rail
  practice:auto_snap_a practice:auto_roll_in_a practice:auto_big_drop practice:drop_loop warehouse:auto_roll_in_a)
MAX_YAW=4.0
MAX_ROT_LOOP=14.0
MAX_JUMP=0.8
MIN_DIST=1.5
MAX_DIST_DROP=6.5
MAX_DIST=8.0
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
  v(){ sed -E "s/.* $1=([0-9.]+).*/\1/" <<<"$l"; }
  y=$(v max_yaw); r=$(v max_rot); m=$(v max_jump); dmax=$(v max_dist); dmin=$(v min_dist); off=$(v off_frame)
  lim_d=$MAX_DIST; [[ ${LINES[$j]} =~ drop|roll_in|snap ]] && lim_d=$MAX_DIST_DROP
  turn="$y <= $MAX_YAW"; [[ ${LINES[$j]} =~ loop ]] && turn="$r <= $MAX_ROT_LOOP"
  if awk "BEGIN{exit !($turn && $m <= $MAX_JUMP && $dmin >= $MIN_DIST && $off == 0 && $dmax <= $lim_d)}"; then
    echo "$l PASS"; pass=$((pass + 1))
  else echo "$l FAIL"; fail=$((fail + 1)); fi
done
rm -rf "$tmp"
echo "CAM summary pass=$pass fail=$fail"
[ $fail -eq 0 ]
