#!/usr/bin/env python3
"""Run a command, write stdout/stderr to files, print peak RSS (MiB) and wall time.

Usage: rss_run.py OUT ERR cmd [args...]

Peak RSS comes from resource.getrusage(RUSAGE_CHILDREN). Used in
No GPU Lab video 008 RAM measurements.
"""
import resource
import subprocess
import sys
import time

if len(sys.argv) < 4:
    sys.stderr.write("usage: rss_run.py OUT ERR cmd [args...]\n")
    sys.exit(2)

out, err, cmd = sys.argv[1], sys.argv[2], sys.argv[3:]
t = time.time()
with open(out, "w") as o, open(err, "w") as e:
    rc = subprocess.call(cmd, stdout=o, stderr=e)
dt = time.time() - t
r = resource.getrusage(resource.RUSAGE_CHILDREN)
print(f"rc={rc} wall={dt:.1f}s peak_rss={r.ru_maxrss / 1024:.0f} MiB")
sys.exit(rc)
