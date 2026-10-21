#!/usr/bin/env bash
# Screenshot goldens: capture the golden views, then compare with tests/goldens/world (or bless them).
# Usage: tools/golden.sh [--bless]
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
if [ $# -gt 1 ] || { [ $# -eq 1 ] && [ "$1" != "--bless" ]; }; then
	echo "usage: tools/golden.sh [--bless]" >&2
	exit 1
fi
BLESS=0
[ $# -eq 1 ] && BLESS=1

VIEWS="capture/views/golden_world.json"
ACTUAL="out/golden_actual"
GOLDEN="tests/goldens/world"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

rm -rf "$ACTUAL"
if ! tools/capture.sh "$VIEWS" "$ACTUAL" >"$LOG" 2>&1; then
	cat "$LOG"
	echo "golden: FAIL capture"
	exit 1
fi

if [ "$BLESS" -eq 1 ]; then
	mkdir -p "$GOLDEN"
	N=0
	for f in "$ACTUAL"/*.png; do
		[ -f "$f" ] || continue
		cp "$f" "$GOLDEN/"
		N=$((N + 1))
	done
	echo "golden: blessed $N views into $GOLDEN"
	exit 0
fi

ACTUAL_ABS="$(realpath "$ACTUAL")"
GOLDEN_ABS="$(realpath -m "$GOLDEN")"
# One Godot at a time: parallel agents share the .godot import cache.
(
	exec 9>/tmp/skate_godot.lock
	flock 9
	"$GODOT" --headless --path . -s res://tools/golden.gd -- \
		"--actual=$ACTUAL_ABS" "--golden=$GOLDEN_ABS" >"$LOG" 2>&1
)
RC=$?
grep -E '^GOLDEN ' "$LOG"
grep -E 'ERROR|Parse Error' "$LOG" | grep -v '^Godot Engine' || true
if [ "$RC" -ne 0 ]; then
	echo "golden: FAIL (exit $RC)"
	exit 1
fi
if ! grep -q '^GOLDEN summary pass=' "$LOG"; then
	echo "golden: FAIL no summary line"
	exit 1
fi
