#!/usr/bin/env python3
"""Turn a run_bench.sh output folder into a markdown + CSV table.

Usage: summarize_bench.py [bench-out-folder]

Reads *-env.txt, *-bench.txt, *-bench.time.txt written by run_bench.sh.
"""
import csv
import glob
import os
import re
import sys


def g(pat, s):
    m = re.search(pat, s)
    return m.group(1) if m else ""


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else "."
    rows = []
    for env in sorted(glob.glob(os.path.join(folder, "*-env.txt"))):
        prefix = env[:-8]
        e = open(env, encoding="utf-8", errors="replace").read()
        try:
            b = open(prefix + "-bench.txt", encoding="utf-8", errors="replace").read()
            bt = open(prefix + "-bench.time.txt", encoding="utf-8", errors="replace").read()
        except FileNotFoundError:
            continue
        rss_kb = g(r"Maximum resident set size \(kbytes\): (\d+)", bt)
        rss_mb = str(round(int(rss_kb) / 1024)) if rss_kb else ""
        row = {
            "timestamp": g(r"timestamp: (.*)", e),
            "model": g(r"model: (\S+)", e),
            "threads": g(r"threads=(\d+)", e),
            "size": g(r"\|\s+([\d.]+ [MG]iB) \|", b),
            "pp": g(r"pp\d+\s+\|\s+([\d.]+ ± [\d.]+)", b) or g(r"pp\d+\s+\|\s+([\d.]+)", b),
            "tg": g(r"tg\d+\s+\|\s+([\d.]+ ± [\d.]+)", b) or g(r"tg\d+\s+\|\s+([\d.]+)", b),
            "peak_rss_mb": rss_mb,
            "wall_s": g(r"Elapsed \(wall clock\) time \(seconds\): ([\d.]+)", bt),
            "loadavg": g(r"load average: ([\d.]+)", e),
            "prefix": os.path.basename(prefix),
        }
        rows.append(row)

    if not rows:
        print("no bench rows found in", folder)
        return 1

    cols = ["timestamp", "model", "size", "threads", "pp", "tg", "peak_rss_mb", "wall_s", "loadavg", "prefix"]
    md_path = os.path.join(folder, "summary.md")
    csv_path = os.path.join(folder, "summary.csv")
    with open(md_path, "w", encoding="utf-8") as f:
        f.write("| " + " | ".join(cols) + " |\n")
        f.write("|" + "|".join(["---"] * len(cols)) + "|\n")
        for r in rows:
            f.write("| " + " | ".join(r[c] for c in cols) + " |\n")
    with open(csv_path, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(rows)
    print(open(md_path, encoding="utf-8").read())
    print(f"wrote {md_path} and {csv_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
