#!/usr/bin/env bash
# Play bot: skates the real park headless and reports everything that feels broken.
# Usage: tools/bot_run.sh [--only=<line>] [--tune=<preset.json>] [--record] [--list]
# Prints "BOT <line> DONE|FAIL ...", "BOTISSUE ..." and "BOT score=N issues=N". Writes /tmp/bot/report.json (+ per-line recordings with --record).
# Exit 0 even with issues; 1 only if the bot crashed or never printed its score.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
(flock 9; "$GODOT" --headless --path . --import) 9>/tmp/skate_import.lock >/tmp/godot_import.log 2>&1 || { cat /tmp/godot_import.log; exit 1; }
mkdir -p /tmp/bot
out=$(timeout 240 "$GODOT" --headless --fixed-fps 60 --path . res://tests/bot/bot.tscn -- "$@" 2>&1 \
  | grep -vE '^(Godot Engine v|$|WARNING: .*audio|   at: )')
echo "$out"
if [[ " $* " == *" --list "* ]]; then exit 0; fi
if ! echo "$out" | grep -q '^BOT score='; then
  echo "BOT crash scene ended without printing its score (crash, script error or timeout)"
  exit 1
fi
exit 0
