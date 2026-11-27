#!/usr/bin/env bash
# ram_gate.sh — wait until enough RAM is free, then exit 0; otherwise exit 1.
#
# Two ways to use it (both were used on the No GPU Lab box):
#   1) Floor in kB, from video 007: wait until MemAvailable >= 7.5 GiB
#        ./ram_gate.sh --min-kb 7864320
#   2) Model file + margin, from video 001: need file size + 1536 MB
#        ./ram_gate.sh --model /path/to/model.gguf --margin-mb 1536
#
# Optional: --tries 6 --sleep 60  (default). Prints load average on every try.
set -euo pipefail

MIN_KB=""
MODEL=""
MARGIN_MB=1536
TRIES=6
SLEEP=60

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \?//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --min-kb) MIN_KB="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --margin-mb) MARGIN_MB="$2"; shift 2 ;;
    --tries) TRIES="$2"; shift 2 ;;
    --sleep) SLEEP="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "unknown arg: $1" >&2; usage ;;
  esac
done

avail_kb() { awk '/MemAvailable/{print $2}' /proc/meminfo; }

if [[ -n "$MODEL" ]]; then
  [[ -f "$MODEL" ]] || { echo "model not found: $MODEL" >&2; exit 2; }
  SIZE_KB=$(( $(stat -c %s "$MODEL") / 1024 ))
  MIN_KB=$(( SIZE_KB + MARGIN_MB * 1024 ))
  echo "model=$(basename "$MODEL") size_kb=$SIZE_KB margin_mb=$MARGIN_MB need_kb=$MIN_KB"
elif [[ -z "$MIN_KB" ]]; then
  echo "set --min-kb or --model" >&2
  usage
fi

for i in $(seq 1 "$TRIES"); do
  A=$(avail_kb)
  LOAD=$(cut -d' ' -f1-3 /proc/loadavg)
  echo "gate try $i $(date '+%F %T %Z') MemAvailable_kB=$A need_kb=$MIN_KB load=$LOAD"
  if [[ "$A" -ge "$MIN_KB" ]]; then
    echo "GATE OK"
    exit 0
  fi
  if [[ "$i" -lt "$TRIES" ]]; then
    sleep "$SLEEP"
  fi
done
echo "GATE FAIL"
exit 1
