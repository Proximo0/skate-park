#!/usr/bin/env bash
# Pro Challenge check: the play-bot rides each level's signature line (the "pro.line" of its goals.json) and must earn at
# least the bronze medal. Prints `PRO <level> bronze|silver|gold|NONE` (best medal) and exits 1 when a level misses bronze.
# Usage: tools/pro_check.sh [level ...]   (default: every level)
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LEVELS=("$@")
[[ ${#LEVELS[@]} -eq 0 ]] && LEVELS=(practice warehouse beach school downtown hills)
(flock 9; "$GODOT" --headless --path . --import) 9>/tmp/skate_import.lock >/tmp/godot_import_pro.log 2>&1 || { cat /tmp/godot_import_pro.log; exit 1; }
fail=0
for lvl in "${LEVELS[@]}"; do
  file="game/levels/$lvl/goals.json"; [[ -f "$file" ]] || file="data/goals.json"
  line=$(python3 -c "import json,sys; print(json.load(open('$file')).get('pro',{}).get('line',''))")
  args=(--noauto "--only=$line")
  [[ "$lvl" != "practice" ]] && args=("--level=$lvl" "${args[@]}")
  out=$(timeout 240 "$GODOT" --headless --fixed-fps 60 --path . res://tests/bot/bot.tscn -- "${args[@]}" 2>&1)
  best=NONE
  for t in bronze silver gold; do grep -q "^PROMEDAL $lvl $t" <<<"$out" && best=$t; done
  echo "PRO $lvl $best (line $line)"
  [[ "$best" == NONE ]] && fail=1
done
exit $fail
