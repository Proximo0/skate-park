#!/usr/bin/env bash
# Scripted screenshots: one Godot launch, one PNG plus JSON sidecar per view (xvfb on Linux).
# Usage: tools/capture.sh <views.json> <out_dir>
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
[ $# -eq 2 ] || { echo "usage: tools/capture.sh <views.json> <out_dir>" >&2; exit 1; }
VIEWS="$1"
case "$VIEWS" in
	res://*) ;;
	*) VIEWS="$(realpath "$VIEWS")" ;;
esac
mkdir -p "$2"
OUT="$(realpath "$2")"
[ -f "$VIEWS" ] || [[ "$VIEWS" == res://* ]] || { echo "capture: no views file $VIEWS" >&2; exit 1; }

# Imports take turns: parallel agents share the .godot import cache.
exec 9>/tmp/skate_import.lock
flock 9
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
"$GODOT" --headless --path . --import >"$LOG" 2>&1 || { cat "$LOG"; exit 1; }
flock -u 9  # only the import needs the lock; runs after it can overlap

timeout 300 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . \
	--rendering-driver opengl3 --resolution 1920x1080 --audio-driver Dummy \
	res://game/debug/capture.tscn -- --scripted "--views=$VIEWS" "--out=$OUT" >"$LOG" 2>&1
RC=$?
grep -E '^SHOT |^CAPTURE ' "$LOG"
grep -E 'ERROR|Parse Error|capture:' "$LOG" | grep -v '^Godot Engine' || true
if [ "$RC" -ne 0 ]; then
	echo "capture: FAIL godot exit $RC"
	exit 1
fi
if ! grep -q '^CAPTURE done' "$LOG"; then
	echo "capture: FAIL no 'CAPTURE done' line"
	exit 1
fi
MISSING="$(python3 -I - "$VIEWS" "$OUT" <<'PY'
import json, os, sys
views_path, out = sys.argv[1], sys.argv[2]
if views_path.startswith("res://"):
    views_path = os.path.join(os.getcwd(), views_path[len("res://"):])
with open(views_path, encoding="utf-8") as f:
    views = json.load(f)["views"]
for v in views:
    for ext in (".png", ".json"):
        p = os.path.join(out, v["name"] + ext)
        if not os.path.isfile(p):
            print(p)
PY
)"
if [ -n "$MISSING" ]; then
	echo "capture: FAIL missing output:"
	echo "$MISSING"
	exit 1
fi
echo "capture: ok out=$OUT"
