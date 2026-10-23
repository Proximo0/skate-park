#!/usr/bin/env python3
"""Side-by-side deltas of two physics lab reports. Usage: tools/compare_reports.py a.json b.json
Each report is /tmp/lab/report.json from tools/physics_report.sh (copy it aside after each run)."""
import json
import sys


def load(path):
    with open(path) as f:
        return json.load(f)


def main():
    if len(sys.argv) != 3:
        print(__doc__.strip())
        return 2
    a, b = load(sys.argv[1]), load(sys.argv[2])
    ma, mb = a["metrics"], b["metrics"]
    print("A: %s\nB: %s\n" % (a.get("tuning", "?"), b.get("tuning", "?")))
    print("%-30s %10s %10s %10s %8s  %-9s %s" % ("metric", "A", "B", "delta", "delta%", "status", "target"))
    for k in ma:
        if k not in mb:
            continue
        va, vb = ma[k]["value"], mb[k]["value"]
        d = vb - va
        pct = "%+.1f%%" % (100.0 * d / va) if abs(va) > 1e-9 else "n/a"
        sa, sb = ma[k].get("status", "?"), mb[k].get("status", "?")
        status = sa if sa == sb else "%s>%s" % (sa, sb)
        tgt = "%s (%s..%s) %s" % (ma[k].get("target", "-"), ma[k].get("min_ok", "-"), ma[k].get("max_ok", "-"), ma[k].get("unit", ""))
        print("%-30s %10.3f %10.3f %+10.3f %8s  %-9s %s" % (k, va, vb, d, pct, status, tgt))
    da, db = a.get("tuning_diff", {}), b.get("tuning_diff", {})
    keys = sorted(set(da) | set(db))
    if keys:
        print("\ntuning fields that differ from the defaults in either run:")
        for k in keys:
            print("  %-20s A=%s B=%s" % (k, da.get(k, "default"), db.get(k, "default")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
