#!/usr/bin/env bash
# Play bot: skates the real park headless and reports everything that feels broken.
# Usage: [LEVEL=<id>] tools/bot_run.sh [--only=<line>] [--tune=<preset.json>] [--record] [--list]
# LEVEL picks a LevelRegistry level (default practice); other levels ride the lines in their bot_route.json.
# Prints "BOT <line> DONE|FAIL ... landed_total=N", "BOTISSUE ...", "BOT score=N issues=N ... landed_total=N",
# and a "BOTLANDED <line> landed_total=N" table (plus "BOTLANDED total landed_total=N"). Writes /tmp/bot/report.json (+ per-line recordings with --record).
# Exit 0 even with issues; 1 only if the bot crashed or never printed its score.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
(flock 9; "$GODOT" --headless --path . --import) 9>/tmp/skate_import.lock >/tmp/godot_import.log 2>&1 || { cat /tmp/godot_import.log; exit 1; }
mkdir -p /tmp/bot
LEVEL_ARGS=()
[[ -n "${LEVEL:-}" && "${LEVEL}" != "practice" ]] && LEVEL_ARGS=("--level=${LEVEL}")
out=$(timeout 240 "$GODOT" --headless --fixed-fps 60 --path . res://tests/bot/bot.tscn -- "${LEVEL_ARGS[@]}" "$@" 2>&1 \
  | grep -vE '^(Godot Engine v|$|WARNING: .*audio|   at: )')
echo "$out"
if [[ " $* " == *" --list "* ]]; then exit 0; fi
# banked points per line (landed_total), then the run total
echo "$out" | sed -nE 's/^BOT ([^ ]+) (DONE|FAIL) .* (landed_total=[0-9]+).*/BOTLANDED \1 \3/p'
echo "$out" | sed -nE 's/^BOT score=.* (landed_total=[0-9]+)$/BOTLANDED total \1/p'
if ! grep -q '^BOT score=' <<<"$out"; then  # here-string: echo | grep -q dies of SIGPIPE under pipefail on big output
  echo "BOT crash scene ended without printing its score (crash, script error or timeout)"
  exit 1
fi
exit 0
