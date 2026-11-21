"""Summarize PresentMon CSVs: frame-time percentiles, stalls, and a timeline.

Usage: python tools/perf/summarize_presentmon.py <csv> [<csv> ...] [--timeline]
"""
import argparse
import csv


def pct(sorted_vals, p):
    if not sorted_vals:
        return 0.0
    k = min(len(sorted_vals) - 1, max(0, int(round(p / 100.0 * (len(sorted_vals) - 1)))))
    return sorted_vals[k]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("csvs", nargs="+")
    ap.add_argument("--timeline", action="store_true",
                    help="print frames over 50 ms with their time offset")
    args = ap.parse_args()
    print("| capture | frames | avg ms | p50 | p95 | p99 | max | >50 ms | >100 ms | sum >50 ms |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    timelines = []
    for path in args.csvs:
        with open(path, newline="") as f:
            rows = list(csv.DictReader(f))
        key = "MsBetweenPresents" if rows and "MsBetweenPresents" in rows[0] else "FrameTime"
        # PresentMon 1.x/2.5 write TimeInSeconds; 2.6 writes TimeInMs.
        tkey, tscale = None, 1.0
        if rows and "TimeInSeconds" in rows[0]:
            tkey = "TimeInSeconds"
        elif rows and "TimeInMs" in rows[0]:
            tkey, tscale = "TimeInMs", 0.001
        vals = []
        events = []
        for r in rows:
            try:
                v = float(r[key])
            except (ValueError, KeyError):
                continue
            vals.append(v)
            if v > 50 and tkey:
                events.append((float(r[tkey]) * tscale, v))
        s = sorted(vals)
        big = [v for v in vals if v > 50]
        name = path.replace("\\", "/").split("/")[-1]
        print(f"| {name} | {len(vals)} | {sum(vals) / max(1, len(vals)):.2f} | {pct(s, 50):.2f} | "
              f"{pct(s, 95):.2f} | {pct(s, 99):.2f} | {max(vals) if vals else 0:.1f} | "
              f"{len(big)} | {sum(1 for v in vals if v > 100)} | {sum(big):.0f} |")
        if events:
            t0 = float(rows[0][tkey]) * tscale
            timelines.append((name, [(t - t0, v) for t, v in events]))
    if args.timeline:
        for name, ev in timelines:
            print(f"\n{name}:")
            print("  " + ", ".join(f"{t:.2f}s:{v:.0f}" for t, v in ev))


if __name__ == "__main__":
    main()
