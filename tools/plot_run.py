#!/usr/bin/env python3
"""Plot a flight-recorder log (.json) or a replay CSV (.csv): speed, height, vertical velocity, state strip.

Usage: python3 -I tools/plot_run.py <log.json|replay.csv> [-o out.png]
A replay CSV overlays recorded (solid) and replayed (dashed). Events (ollie, land, bail, grind) are labelled.
Needs matplotlib (pip install matplotlib).
"""
import argparse
import csv
import json
import os
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

EVENT_KEYS = ("ollie", "land", "bail", "grind")
STATE_COLORS = {
    "ROLLING": "#4C78A8", "MANUAL": "#72B7B2", "AIR": "#F58518", "GRIND": "#B279A2",
    "LIP": "#9D755D", "WALLRIDE": "#E45756", "BAIL": "#7F1D1D",
}
REC_COLOR = "#1F5FA8"
REP_COLOR = "#D1495B"


def load_json(path):
    with open(path) as f:
        doc = json.load(f)
    rows = []
    for fr in doc["frames"]:
        rows.append({
            "t": fr["t"], "state": fr["state"], "y": fr["pos"][1], "vy": fr["vel"][1],
            "speed": fr["speed"], "events": fr["events"],
        })
    return {"rec": rows, "rep": None, "title": "%s (%s park)" % (os.path.basename(path), doc.get("park", "?"))}


def load_csv(path):
    rec, rep = [], []
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            t = float(r["t"])
            rec.append({"t": t, "state": r["rec_state"], "y": float(r["rec_py"]), "vy": float(r["rec_vy"]),
                        "speed": float(r["rec_speed"]), "events": [e for e in r["rec_events"].split("|") if e]})
            rep.append({"t": t, "state": r["rep_state"], "y": float(r["rep_py"]), "vy": float(r["rep_vy"]),
                        "speed": float(r["rep_speed"]), "events": [e for e in r["rep_events"].split("|") if e]})
    return {"rec": rec, "rep": rep, "title": "%s: recorded vs replayed" % os.path.basename(path)}


def strip(ax, rows, y0, h):
    i = 0
    while i < len(rows):
        j = i
        while j + 1 < len(rows) and rows[j + 1]["state"] == rows[i]["state"]:
            j += 1
        t0 = rows[i]["t"]
        t1 = rows[j]["t"] + (rows[j]["t"] - rows[j - 1]["t"] if j > 0 else 1 / 60)
        ax.broken_barh([(t0, t1 - t0)], (y0, h), facecolors=STATE_COLORS.get(rows[i]["state"], "#888888"))
        i = j + 1


def mark_events(axes, rows, color):
    n = 0
    for r in rows:
        for e in r["events"]:
            if e.split(":")[0] not in EVENT_KEYS:
                continue
            for ax in axes:
                ax.axvline(r["t"], color=color, alpha=0.25, lw=0.8)
            top = axes[0].get_ylim()[1]
            axes[0].annotate(e, (r["t"], top), xytext=(2, -10 - 11 * (n % 3)), textcoords="offset points",
                             fontsize=7, color=color, rotation=0, clip_on=True)
            n += 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("-o", "--out", default=None)
    a = ap.parse_args()
    data = load_csv(a.src) if a.src.endswith(".csv") else load_json(a.src)
    out = a.out or os.path.splitext(a.src)[0] + ".png"
    fig, axes = plt.subplots(4, 1, figsize=(13, 8), sharex=True, gridspec_kw={"height_ratios": [3, 3, 3, 1]})
    series = [("speed", "Speed (m/s)"), ("y", "Height (m)"), ("vy", "Vertical velocity (m/s)")]
    for ax, (key, label) in zip(axes[:3], series):
        ax.plot([r["t"] for r in data["rec"]], [r[key] for r in data["rec"]], color=REC_COLOR, lw=1.5,
                label="recorded" if data["rep"] else None)
        if data["rep"]:
            ax.plot([r["t"] for r in data["rep"]], [r[key] for r in data["rep"]], color=REP_COLOR, lw=1.2, ls="--",
                    label="replayed")
        ax.set_ylabel(label)
        ax.grid(alpha=0.25)
    axes[2].axhline(0, color="#666666", lw=0.6)
    if data["rep"]:
        axes[0].legend(loc="upper right", fontsize=8)
    axes[0].set_title(data["title"])
    fig.canvas.draw()
    mark_events(axes[:3], data["rec"], REC_COLOR)
    if data["rep"]:
        mark_events(axes[:3], data["rep"], REP_COLOR)
        strip(axes[3], data["rec"], 0.55, 0.4)
        strip(axes[3], data["rep"], 0.05, 0.4)
        axes[3].set_yticks([0.25, 0.75])
        axes[3].set_yticklabels(["replay", "rec"], fontsize=8)
    else:
        strip(axes[3], data["rec"], 0.1, 0.8)
        axes[3].set_yticks([])
    axes[3].set_ylim(0, 1)
    seen = []
    for r in data["rec"] + (data["rep"] or []):
        if r["state"] not in seen:
            seen.append(r["state"])
    handles = [plt.Rectangle((0, 0), 1, 1, color=STATE_COLORS.get(s, "#888888")) for s in seen]
    fig.legend(handles, seen, ncol=len(seen), fontsize=8, loc="lower center")
    axes[3].set_xlabel("time (s)")
    fig.tight_layout(rect=(0, 0.035, 1, 1))
    fig.savefig(out, dpi=110)
    print("wrote", out)


if __name__ == "__main__":
    sys.exit(main())
