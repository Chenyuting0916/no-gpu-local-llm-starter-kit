#!/usr/bin/env python3
"""Minimal /usr/bin/time -v substitute.

Runs a command and prints wall time plus peak RSS (kernel rusage ru_maxrss
via os.wait4) to stderr, in GNU-time wording. Used in No GPU Lab video 001
because GNU time was not installed on the test box.

Usage: rtime.py COMMAND [ARGS...]
"""
import os
import subprocess
import sys
import time

if len(sys.argv) < 2:
    sys.stderr.write("usage: rtime.py COMMAND [ARGS...]\n")
    sys.exit(2)

t0 = time.monotonic()
proc = subprocess.Popen(sys.argv[1:])
_, status, ru = os.wait4(proc.pid, 0)
wall = time.monotonic() - t0
cmd = " ".join(sys.argv[1:])
code = os.waitstatus_to_exitcode(status)
sys.stderr.write(
    f'\n\tCommand being timed: "{cmd}"\n'
    f"\tUser time (seconds): {ru.ru_utime:.2f}\n"
    f"\tSystem time (seconds): {ru.ru_stime:.2f}\n"
    f"\tElapsed (wall clock) time (seconds): {wall:.2f}\n"
    f"\tMaximum resident set size (kbytes): {ru.ru_maxrss}\n"
    f"\tExit status: {code}\n"
)
sys.exit(code)
