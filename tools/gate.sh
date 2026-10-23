#!/usr/bin/env bash
# Milestone gate: lint, tests, smoke capture, goldens. Quick mode runs lint and tests only.
# Usage: tools/gate.sh [--quick]
# Quiet: one "GATE <step> PASS|FAIL|SKIP <s>s" line per step (last 15 output lines under a FAIL),
# then "GATE PASS" or "GATE FAIL (<failed steps>)". Writes out/gate/report.json, appends out/runs.csv.
# Env (for testing): GATE_OUT (default out), GATE_TIMEOUT (seconds, overrides every step limit), GODOT.
# Exit 0 only if every step passes.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="${GATE_OUT:-out}"

if [ $# -gt 1 ] || { [ $# -eq 1 ] && [ "$1" != "--quick" ]; }; then
	echo "usage: tools/gate.sh [--quick]" >&2
	exit 1
fi
MODE=all
[ $# -eq 1 ] && MODE=quick

# Per-step wall-clock limit in seconds.
step_limit() {
	if [ -n "${GATE_TIMEOUT:-}" ]; then
		echo "$GATE_TIMEOUT"
		return
	fi
	case "$1" in
		lint) echo 300 ;;
		tests) echo 600 ;;
		capture) echo 420 ;;
		golden) echo 600 ;;
		*) echo 300 ;;
	esac
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
STEPS="$WORK/steps.tsv"
: > "$STEPS"
N=0
FAILED_LIST=""
LAST_RESULT=""

# record <name> <result> <seconds> <tail-file>: keep the step for the report and print its GATE line.
record() {
	local name="$1" result="$2" secs="$3" tailf="$4"
	printf 'GATE %s %s %ss\n' "$name" "$result" "$secs"
	if [ "$result" = FAIL ]; then
		sed 's/^/    /' "$tailf"
		FAILED_LIST="${FAILED_LIST:+$FAILED_LIST,}$name"
	fi
	printf '%s\t%s\t%s\t%s\n' "$name" "$result" "$secs" "$tailf" >> "$STEPS"
	LAST_RESULT="$result"
}

# run_step <name> <script> [args...]: run one step under its time limit.
run_step() {
	local name="$1" script="$2"
	shift 2
	N=$((N + 1))
	local tailf="$WORK/tail.$N" log="$WORK/log.$N" result secs rc start end
	: > "$tailf"
	if [ ! -f "$script" ]; then
		echo "missing: $script" > "$tailf"
		record "$name" FAIL 0.0 "$tailf"
		return
	fi
	start=$(date +%s%N)
	timeout -k 10 "$(step_limit "$name")" bash "$script" "$@" >"$log" 2>&1
	rc=$?
	end=$(date +%s%N)
	secs=$(awk -v ms="$(( (end - start) / 1000000 ))" 'BEGIN { printf "%.1f", ms / 1000 }')
	if [ "$rc" -eq 0 ]; then
		result=PASS
	else
		result=FAIL
		if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
			echo "timeout after $(step_limit "$name")s" >>"$log"
		fi
		tail -n 15 "$log" >"$tailf"
	fi
	record "$name" "$result" "$secs" "$tailf"
}

# skip_step <name> <reason>: a step not run because an earlier step it depends on failed.
skip_step() {
	N=$((N + 1))
	local tailf="$WORK/tail.$N"
	echo "skipped: $2" >"$tailf"
	record "$1" SKIP 0.0 "$tailf"
}

mkdir -p "$OUT/gate"
WHEN="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TOTAL_START=$(date +%s%N)

run_step lint tools/lint.sh
run_step tests tools/run_tests.sh
TESTS_OK="$LAST_RESULT"
if [ "$MODE" = all ]; then
	if [ "$TESTS_OK" = PASS ]; then
		run_step capture tools/capture.sh capture/views/smoke.json "$OUT/gate/smoke"
		run_step golden tools/golden.sh
	else
		skip_step capture "tests failed"
		skip_step golden "tests failed"
	fi
fi

TOTAL_SECS=$(awk -v ms="$(( ($(date +%s%N) - TOTAL_START) / 1000000 ))" 'BEGIN { printf "%.1f", ms / 1000 }')
GIT_HASH="$(git rev-parse --short HEAD 2>/dev/null || true)"
GIT_HASH="${GIT_HASH:-unknown}"
ENGINE="$(timeout 60 "$GODOT" --version 2>/dev/null | head -n 1 || true)"
ENGINE="${ENGINE:-unknown}"

if [ -z "$FAILED_LIST" ]; then
	RESULT=PASS
else
	RESULT=FAIL
fi

# Report JSON and the runs.csv row, in one quiet python step (stdlib only).
python3 -I - "$STEPS" "$OUT/gate/report.json" "$OUT/runs.csv" "$RESULT" "$GIT_HASH" "$ENGINE" \
	"$MODE" "$WHEN" "$TOTAL_SECS" <<'PY'
import csv
import json
import os
import sys

steps_path, report_path, csv_path, result, git_hash, engine, mode, when, total = sys.argv[1:10]
steps = []
with open(steps_path, encoding="utf-8") as f:
    for line in f:
        name, res, secs, tailf = line.rstrip("\n").split("\t")
        with open(tailf, encoding="utf-8", errors="replace") as t:
            tail = t.read()
        steps.append({"name": name, "result": res, "seconds": float(secs), "tail": tail})

report = {"steps": steps, "result": result, "git_hash": git_hash, "engine": engine}
with open(report_path, "w", encoding="utf-8") as f:
    json.dump(report, f, indent=2)
    f.write("\n")

new_file = not os.path.isfile(csv_path) or os.path.getsize(csv_path) == 0
with open(csv_path, "a", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    if new_file:
        w.writerow(["when_utc", "tool", "step", "result", "seconds", "git_hash", "engine"])
    w.writerow([when, "gate", mode, result, total, git_hash, engine])
PY

if [ "$RESULT" = PASS ]; then
	echo "GATE PASS"
	exit 0
fi
echo "GATE FAIL ($FAILED_LIST)"
exit 1
