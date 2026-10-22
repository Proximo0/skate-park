#!/usr/bin/env python3
"""Agent tracker data: every Claude Code session and subagent on this machine, for the agent tracker dashboard.

Reads the transcripts under ~/.claude/projects/ (each <session>.jsonl and its subagents/agent-*.jsonl with their
.meta.json) and the repo's git history, and writes row files (JSON arrays) into --out:
  sessions.json  one row per session: project, title, model, status, turns, tool calls, subagents, tokens
  agents.json    one row per subagent: parent session, type, task, model, status, tool calls, tokens
  tokens.json    token pull per 10 minutes and model over the last 48 hours (zeros left out)
  tools.json     tool calls by tool name: last 24 hours and last 7 days
  events.json    the latest 120 tool calls: time, session, agent, tool and a short label (never raw commands)
  commits.json   commits on every branch of --repo over the last 14 days
Token pull = input + cache reads + cache writes + output, each API response counted once.
Usage: python tools/agent_tracker/agent_tracker.py --out DIR [--repo PATH] [--days 14]
Standard library only.
"""
import argparse
import glob
import json
import os
import re
import subprocess
from collections import defaultdict
from datetime import datetime, timedelta, timezone

RUNNING_S = 300  # active in the last 5 minutes
IDLE_S = 3600  # active in the last hour
BUCKET_MIN = 10


def parse_ts(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def iso(t):
    return t.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def project_name(folder):
    name = os.path.basename(folder.rstrip("/\\"))
    m = re.search(r"scratch-(\d{4})-(\d{2})-(\d{2})", name)
    if m:
        return "Scratch %s-%s" % (m.group(2), m.group(3))
    parts = [p for p in re.split(r"-+", name) if p]
    if len(parts) > 3 and parts[1].lower() == "users":
        parts = parts[3:]  # drop the drive and C:/Users/<name>
    return " / ".join(parts[-2:]) if parts else name


def label_for(tool, inp):
    """A short, safe label for a tool call: its description, a file name or a pattern, never a raw command."""
    if not isinstance(inp, dict):
        return ""
    if inp.get("description"):
        return str(inp["description"])[:90]
    for k in ("file_path", "path", "notebook_path"):
        if inp.get(k):
            return os.path.basename(str(inp[k]))[:90]
    for k in ("pattern", "query", "skill", "subagent_type", "action"):
        if inp.get(k):
            return "%s: %s" % (k, str(inp[k])[:70])
    return ""


def first_prompt(d):
    m = d.get("message") or {}
    c = m.get("content")
    if isinstance(c, list):
        c = " ".join(x.get("text", "") for x in c if isinstance(x, dict) and x.get("type") == "text")
    if not isinstance(c, str):
        return None
    c = re.sub(r"<[^>]+>", " ", c)  # drop wrapper tags (wake envelopes, reminders)
    c = re.sub(r"\s+", " ", c).strip()
    if not c or c.startswith(("Caveat:", "[Request interrupted")):
        return None
    return c[:80]


def scan(path, now):
    """Usage, tool calls and timing of one transcript."""
    st = {"first": None, "last": None, "turns": 0, "tools": 0, "tokens": 0, "models": defaultdict(int),
          "title": None, "buckets": defaultdict(int), "tool_names": [], "events": []}
    seen = set()
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            ts = d.get("timestamp")
            if not ts:
                continue
            t = parse_ts(ts)
            st["first"] = st["first"] or t
            st["last"] = t
            if d.get("type") == "user" and st["title"] is None and not d.get("isMeta"):
                st["title"] = first_prompt(d)
            if d.get("type") != "assistant":
                continue
            m = d.get("message") or {}
            for c in m.get("content") or []:
                if isinstance(c, dict) and c.get("type") == "tool_use":
                    st["tools"] += 1
                    st["tool_names"].append((t, c.get("name", "?")))
                    st["events"].append((t, c.get("name", "?"), label_for(c.get("name"), c.get("input"))))
            u = m.get("usage")
            key = d.get("requestId") or m.get("id") or d.get("uuid")
            if not u or key in seen:
                continue
            seen.add(key)
            st["turns"] += 1
            tok = sum(int(u.get(k) or 0) for k in ("input_tokens", "cache_creation_input_tokens",
                                                     "cache_read_input_tokens", "output_tokens"))
            model = m.get("model", "unknown")
            st["tokens"] += tok
            st["models"][model] += tok
            if now - t <= timedelta(hours=48):
                b = t.replace(minute=t.minute - t.minute % BUCKET_MIN, second=0, microsecond=0)
                st["buckets"][(iso(b), model)] += tok
    return st


def status(last, now):
    age = (now - last).total_seconds()
    return "running" if age < RUNNING_S else "idle" if age < IDLE_S else "done"


def short_model(m):
    return re.sub(r"^claude-", "", m or "unknown")


def git_commits(repo, days):
    if not repo:
        return []
    try:
        out = subprocess.run(["git", "-C", repo, "log", "--all", "--source", "--since=%d.days" % days,
                              "--pretty=format:%H%x09%S%x09%cI%x09%s"], capture_output=True, text=True,
                             timeout=60).stdout
    except (OSError, subprocess.SubprocessError):
        return []
    rows = []
    for line in out.splitlines():
        parts = line.split("\t", 3)
        if len(parts) == 4:
            h, src, when, subj = parts
            branch = re.sub(r"^refs/(remotes/origin/|heads/)", "", src)
            rows.append({"time": iso(parse_ts(when)), "branch": branch, "hash": h[:7], "subject": subj[:90]})
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--repo")
    ap.add_argument("--days", type=int, default=14)
    a = ap.parse_args()
    now = datetime.now(timezone.utc)
    since = now - timedelta(days=a.days)
    sessions, agents, buckets = [], [], defaultdict(int)
    tools24, tools7 = defaultdict(int), defaultdict(int)
    events = []
    for main_path in glob.glob(os.path.expanduser("~/.claude/projects/*/*.jsonl")):
        if datetime.fromtimestamp(os.path.getmtime(main_path), timezone.utc) < since:
            continue
        folder = os.path.dirname(main_path)
        sid = os.path.basename(main_path)[:-len(".jsonl")]
        st = scan(main_path, now)
        if not st["last"]:
            continue
        subs = sorted(glob.glob(os.path.join(folder, sid, "subagents", "agent-*.jsonl")))
        sub_tokens = 0
        for sp in subs:
            ss = scan(sp, now)
            if not ss["last"]:
                continue
            meta = {}
            mp = sp[:-len(".jsonl")] + ".meta.json"
            if os.path.exists(mp):
                try:
                    meta = json.load(open(mp, encoding="utf-8"))
                except ValueError:
                    meta = {}
            sub_tokens += ss["tokens"]
            atype = meta.get("agentType") or meta.get("subagent_type") or "subagent"
            agents.append({
                "agent": os.path.basename(sp)[6:14], "session": sid[:8], "project": project_name(folder),
                "type": atype, "task": str(meta.get("description") or "")[:80],
                "model": short_model(max(ss["models"], key=ss["models"].get) if ss["models"] else None),
                "status": status(ss["last"], now), "started": iso(ss["first"]), "last_active": iso(ss["last"]),
                "minutes": round((ss["last"] - ss["first"]).total_seconds() / 60, 1), "turns": ss["turns"],
                "tool_calls": ss["tools"], "tokens": ss["tokens"]})
            for k, v in ss["buckets"].items():
                buckets[k] += v
            for t, n in ss["tool_names"]:
                if now - t <= timedelta(days=7):
                    tools7[n] += 1
                if now - t <= timedelta(hours=24):
                    tools24[n] += 1
            events += [(t, sid[:8], atype, n, lab) for t, n, lab in ss["events"]]
        for k, v in st["buckets"].items():
            buckets[k] += v
        for t, n in st["tool_names"]:
            if now - t <= timedelta(days=7):
                tools7[n] += 1
            if now - t <= timedelta(hours=24):
                tools24[n] += 1
        events += [(t, sid[:8], "lead", n, lab) for t, n, lab in st["events"]]
        sessions.append({
            "session": sid[:8], "project": project_name(folder), "title": st["title"] or "(no prompt)",
            "model": short_model(max(st["models"], key=st["models"].get) if st["models"] else None),
            "status": status(st["last"], now), "started": iso(st["first"]), "last_active": iso(st["last"]),
            "hours": round((st["last"] - st["first"]).total_seconds() / 3600, 2), "turns": st["turns"],
            "tool_calls": st["tools"], "subagents": len(subs), "tokens": st["tokens"] + sub_tokens})
    sessions.sort(key=lambda r: r["last_active"], reverse=True)
    agents.sort(key=lambda r: r["last_active"], reverse=True)
    tokens = [{"time": t, "model": short_model(m), "tokens": v} for (t, m), v in sorted(buckets.items())]
    tools = [{"tool": n, "last_24h": tools24.get(n, 0), "last_7d": c} for n, c in tools7.items()]
    tools.sort(key=lambda r: (r["last_24h"], r["last_7d"]), reverse=True)
    events.sort(key=lambda e: e[0], reverse=True)
    ev = [{"time": iso(t), "session": s, "agent": ag, "tool": n, "label": lab} for t, s, ag, n, lab in events[:120]]
    commits = git_commits(a.repo, a.days)
    os.makedirs(a.out, exist_ok=True)
    for name, rows in (("sessions", sessions), ("agents", agents), ("tokens", tokens), ("tools", tools),
                       ("events", ev), ("commits", commits)):
        with open(os.path.join(a.out, name + ".json"), "w", encoding="utf-8") as f:
            json.dump(rows, f, separators=(",", ":"))
    running = sum(1 for r in sessions + agents if r["status"] == "running")
    print("AGENT_TRACKER sessions=%d agents=%d running=%d tokens_48h=%d commits=%d" % (
        len(sessions), len(agents), running, sum(r["tokens"] for r in tokens), len(commits)))


if __name__ == "__main__":
    main()
