#!/usr/bin/env bash
# Every physics check at once, in parallel: unit tests, both sim scenes, the physics lab, the play-bot (sharded)
# and the snag sweep (sharded). JOBS (default: CPU count) caps how many Godot processes run together.
# Usage: tools/check_all.sh [--quick]   (--quick skips the per-level snag sweeps, the slowest check)
# Logs go to /tmp/check/<name>.log; the last lines print one summary row per check. Exit 1 if any check fails.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
JOBS="${JOBS:-$(nproc)}"
QUICK=0; [[ " $* " == *" --quick "* ]] && QUICK=1
OUT=/tmp/check; rm -rf "$OUT"; mkdir -p "$OUT" /tmp/bot /tmp/lab
rm -f /tmp/bot/report.json /tmp/bot/report_shard*.json   # never leave a stale report behind
FILTER='^(Godot Engine v|$|WARNING: .*audio|   at: )'
start=$(date +%s)
(flock 9; "$GODOT" --headless --path . --import) 9>/tmp/skate_import.lock >"$OUT/import.log" 2>&1 || { cat "$OUT/import.log"; exit 1; }

# One command per line: name|command. The snag sweep shards itself, so it counts as SHARDS jobs and goes first.
BOT_SHARDS=3
TASKS=()
SNAG_LEVELS=(practice warehouse beach school downtown hills)
if (( ! QUICK )); then
  for lv in "${SNAG_LEVELS[@]}"; do
    n=2500; [[ $lv == hills ]] && n=1500
    TASKS+=("snags_$lv|LEVEL=$lv MAXRUNS=$n SHARDS=1 tools/snag_sweep.sh")
  done
fi
for ((i = 0; i < BOT_SHARDS; i++)); do
  TASKS+=("bot$i|timeout 240 $GODOT --headless --fixed-fps 60 --path . res://tests/bot/bot.tscn -- --shard=$i --nshards=$BOT_SHARDS")
done
TASKS+=("sims_controller|timeout 600 $GODOT --headless --path . res://tests/sim/controller_sims.tscn")
TASKS+=("sims_suite|timeout 600 $GODOT --headless --path . res://tests/sim/sim_suite.tscn")
TASKS+=("lab|timeout 600 $GODOT --headless --fixed-fps 60 --path . res://tests/lab/physics_lab.tscn")
TASKS+=("unit|timeout 600 $GODOT --headless --path . -s res://tests/runner.gd")
TASKS+=("lint|tools/lint.sh")

running=0
for t in "${TASKS[@]}"; do
  name="${t%%|*}"; cmd="${t#*|}"
  w=1
  while (( running + w > JOBS )); do wait -n; running=$((running - 1)); done
  ( eval "$cmd" 2>&1 | grep -vE "$FILTER" >"$OUT/$name.log" ) &
  running=$((running + w))
done
wait

rc=0
row() { printf '%-16s %s\n' "$1" "$2"; }
echo "=== check_all ($(( $(date +%s) - start )) s, $JOBS jobs) ==="
u=$(grep -E '^TESTS passed=' "$OUT/unit.log" | tail -1); row unit "${u:-CRASH}"
[[ "$u" == *"failed=0"* ]] || rc=1
for s in sims_controller sims_suite; do
  t=$(grep -E '^SIMS passed=' "$OUT/$s.log" | tail -1); row "$s" "${t:-CRASH}"
  [[ "$t" == *"failed=0" ]] || rc=1
  grep -E '^SIM .* FAIL ' "$OUT/$s.log" | sed 's/^/    /'
done
l=$(grep -E '^LAB summary' "$OUT/lab.log" | tail -1); row lab "${l:-CRASH}"; [[ -n "$l" ]] || rc=1
grep -E '^LAB .* WARN$' "$OUT/lab.log" | sed 's/^/    /'
python3 -I - "$OUT" <<'PY' || rc=1
import glob, json, re, sys
out = sys.argv[1]
lines, issues, scores, crashed = [], [], [], False
for f in sorted(glob.glob(out + "/bot*.log")):
    txt = open(f).read()
    m = re.search(r"^BOT score=(\d+) issues=(\d+)", txt, re.M)
    if not m:
        crashed = True
        print(f"{'bot':<16} CRASH in {f}")
        continue
    scores.append(int(m.group(1)))
    lines += [l for l in txt.splitlines() if re.match(r"^BOT \S+ (DONE|FAIL)", l)]
    issues += [l for l in txt.splitlines() if l.startswith("BOTISSUE")]
# merge the shard reports into /tmp/bot/report.json (same score formula as bot_main.gd)
PEN = {"bail": 5, "snag": 4, "hard_stop": 4, "stuck": 8, "respawn": 15, "below_kill_plane": 15, "jitter_normal": 2, "jitter_y": 2,
       "floor_flicker": 2, "teleport": 3, "overspeed": 6, "nan": 20, "grind_miss": 3, "action_miss": 2, "wp_timeout": 3, "gap_miss": 3}
shards = [json.load(open(f)) for f in sorted(glob.glob("/tmp/bot/report_shard*.json"))]
if shards and not crashed:
    lines_j = [l for sh in shards for l in sh["lines"]]
    counts = {}
    for l in lines_j:
        for k, c in l["issue_counts"].items():
            counts[k] = counts.get(k, 0) + c
    failed_n = sum(1 for l in lines_j if not l["ok"])
    pen = 5.0 * failed_n + sum(PEN.get(k, 2) * min(c, 6) for l in lines_j for k, c in l["issue_counts"].items())
    merged = {"version": 1, "score": max(0, round(100 - pen)), "issues": sum(counts.values()), "issue_counts": counts, "lines": lines_j,
              "issue_list": [i for sh in shards for i in sh["issue_list"]], "tuning": shards[0].get("tuning", ""),
              "tuning_diff": shards[0].get("tuning_diff", {}), "wall_seconds": max(sh.get("wall_seconds", 0) for sh in shards), "shards": len(shards)}
    json.dump(merged, open("/tmp/bot/report.json", "w"), indent=2)
    print(f"{'bot merged':<16} /tmp/bot/report.json score={merged['score']} issues={merged['issues']} lines={len(lines_j)} failed={failed_n}")
fails = [l for l in lines if " FAIL " in l]
print(f"{'bot':<16} lines={len(lines)} failed={len(fails)} issues={len(issues)} worst_shard_score={min(scores) if scores else 'n/a'}")
for l in fails + issues:
    print("    " + l)
sys.exit(1 if crashed or fails else 0)
PY
lint=$(tail -1 "$OUT/lint.log"); row lint "$lint"; [[ "$lint" == *"problems=0"* ]] || rc=1
if (( ! QUICK )); then
  # per-level sweep; "real" snags are gated against data/snag_baseline.json (raise it only with a reason)
  for lv in "${SNAG_LEVELS[@]}"; do
    s=$(grep -E '^SNAG summary' "$OUT/snags_$lv.log" | tail -1); row "snags $lv" "${s:-CRASH}"; [[ -n "$s" ]] || { rc=1; continue; }
    r=$(sed -n 's/.*real=\([0-9]*\) real_hotspots.*/\1/p' <<<"$s")
    b=$(python3 -c "import json;print(json.load(open('data/snag_baseline.json')).get('$lv',0))")
    if [[ -n "$r" ]] && (( r > b )); then echo "    FAIL $lv: real=$r exceeds baseline $b"; rc=1; fi
  done
fi
exit $rc
