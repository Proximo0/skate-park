#!/usr/bin/env bash
# Replays a flight-recorder log headless and compares it with what was recorded.
# Usage: tools/replay.sh <log.json> [--tune=preset.json] [--from=tick] [--ticks=N] [--csv=out.csv]
# Prints "REPLAY divergence max=<m> at tick <t> mean=<m>", event mismatches, a what-if summary when --tune is given,
# and writes a CSV (default: <log>.replay.csv). Exit 1 on a bad log, or when an unmodified replay diverges > 1e-3 m.
set -uo pipefail
if [ $# -eq 0 ]; then sed -n 2,5p "$0"; exit 2; fi
# Absolute paths: godot runs from the project root.
ARGS=()
for a in "$@"; do
  case "$a" in
    --tune=*|--csv=*) ARGS+=("${a%%=*}=$(realpath -m "${a#*=}")") ;;
    --*) ARGS+=("$a") ;;
    *) ARGS+=("$(realpath -m "$a")") ;;
  esac
done
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
(flock 9; "$GODOT" --headless --path . --import) 9>/tmp/skate_import.lock >/tmp/godot_import.log 2>&1 || { cat /tmp/godot_import.log; exit 1; }
out=$(timeout 300 "$GODOT" --headless --fixed-fps 60 --path . res://tests/replay/replay_runner.tscn -- "${ARGS[@]}" 2>&1 \
  | grep -vE '^(Godot Engine v|$|WARNING: .*audio|   at: )')
echo "$out"
if ! echo "$out" | grep -q '^REPLAY divergence '; then
  echo "REPLAY crash scene ended without a divergence line (bad log, script error or timeout)"
  exit 1
fi
echo "$out" | grep -q '^REPLAY FAIL ' && exit 1
exit 0
