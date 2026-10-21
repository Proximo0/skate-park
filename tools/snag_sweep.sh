#!/usr/bin/env bash
# Snag sweep: scripted skaters approach every park piece's sides, corners, ramp feet and deck edges, and the hotspots where
# energy is lost without a bail or landing are ranked.
# Usage: tools/snag_sweep.sh [--only=piece] [--keep=PCT] [--speeds=4,8,12] [--fwd=0] [--show=N] [--shards=N] [--include_headon]
#        tools/snag_sweep.sh --list            (print the pieces)
#        tools/snag_sweep.sh --replay=<rank>   (re-run hotspot <rank> from /tmp/lab/snags.json alone and print a tick-by-tick trace)
# Default grid: --keep=45 (45% of the approach geometries), neutral stick at 4/8/12 m/s plus a held-forward pass at 8/12 m/s,
# split over 3 parallel Godot processes (SHARDS env or --shards=N) to stay under 5 minutes. --keep=100 is the full grid (~10 min).
# Prints `SNAG <piece> <pos> count=.. worst_loss=..% kind=.. ...` lines and `SNAG summary runs=N snags=M hotspots=K`.
# Real snags are counted apart from excluded categories (bail slides, ramp apex stops, square head-on wall hits): see the `SNAG excluded` line.
# Writes /tmp/lab/snags.json. Exit 0 unless a shard died before finishing.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
SHARDS="${SHARDS:-3}"
ARGS=()
for a in "$@"; do
  case "$a" in
    --shards=*) SHARDS="${a#--shards=}" ;;
    *) ARGS+=("$a") ;;
  esac
done
HAS_KEEP=0; SINGLE=0
for a in "${ARGS[@]+"${ARGS[@]}"}"; do
  case "$a" in --keep=*) HAS_KEEP=1 ;; --list|--replay=*|--list=*) SINGLE=1 ;; esac
done
[ "$HAS_KEEP" = 0 ] && ARGS+=("--keep=45")
(flock 9; "$GODOT" --headless --path . --import) 9>/tmp/skate_import.lock >/tmp/godot_import.log 2>&1 || { cat /tmp/godot_import.log; exit 1; }
FILTER='^(Godot Engine v|$|WARNING: .*audio|   at: )'
SCENE=res://tests/lab/snag_sweep.tscn
start=$(date +%s)
if [ "$SINGLE" = 1 ] || [ "$SHARDS" -le 1 ]; then
  out=$(timeout 290 "$GODOT" --headless --fixed-fps 60 --path . $SCENE -- "${ARGS[@]}" 2>&1 | grep -vE "$FILTER")
  echo "$out"
  echo "$out" | grep -qE '^(SNAG summary |SNAG runtime |TRACE |SNAGPIECE total)' || { echo "SNAG crash scene ended without printing its summary (crash, script error or timeout)"; exit 1; }
  exit 0
fi
rm -f /tmp/lab/snags_raw_*.json
pids=()
for ((i = 0; i < SHARDS; i++)); do
  timeout 280 "$GODOT" --headless --fixed-fps 60 --path . $SCENE -- "${ARGS[@]}" --shard=$i --nshards=$SHARDS 2>&1 | grep -vE "$FILTER" >/tmp/lab/snag_shard_$i.log &
  pids+=($!)
done
wait
cat /tmp/lab/snag_shard_*.log | grep -E 'SCRIPT ERROR|SNAG planned|SNAG crash' | sort | uniq -c | head -5
for ((i = 0; i < SHARDS; i++)); do
  grep -q "^SNAG shard $i done" /tmp/lab/snag_shard_$i.log || { echo "SNAG crash shard $i did not finish (see /tmp/lab/snag_shard_$i.log)"; exit 1; }
done
timeout 60 "$GODOT" --headless --path . $SCENE -- --merge=$SHARDS "${ARGS[@]}" 2>&1 | grep -vE "$FILTER" | grep -v '^SNAG runtime'
echo "SNAG wall_time $(( $(date +%s) - start )) s over $SHARDS shards"
exit 0
