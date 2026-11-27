#!/usr/bin/env bash
# run_bench.sh — llama-bench with a RAM gate, optional load gate, and peak-RSS log.
#
# What No GPU Lab actually ran in video 001:
#   llama-bench -m MODEL -p 512 -n 128 -t T -r 3 -o md
#   gate: MemAvailable > file size + 1536 MB
#   8-thread runs started only when 1-minute load average was under 1.0
#
# Usage:
#   export LLAMA_DIR=/path/to/llama-cpp-binaries
#   ./run_bench.sh /path/to/model.gguf
#   ./run_bench.sh /path/to/model.gguf --threads 2,4,6,7,8 --reps 3
#
# Writes one folder per run under $OUT_DIR (default ./bench-out).
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
RTIME="$HERE/rtime.py"
GATE="$HERE/ram_gate.sh"

MODEL=""
THREADS="2,4,6,7,8"
REPS=3
PP=512
TG=128
MARGIN_MB=1536
LOAD_MAX="1.0"
OUT_DIR="${OUT_DIR:-./bench-out}"
LLAMA_DIR="${LLAMA_DIR:-}"

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \?//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --threads) THREADS="$2"; shift 2 ;;
    --reps) REPS="$2"; shift 2 ;;
    --pp) PP="$2"; shift 2 ;;
    --tg) TG="$2"; shift 2 ;;
    --margin-mb) MARGIN_MB="$2"; shift 2 ;;
    --load-max) LOAD_MAX="$2"; shift 2 ;;
    --out) OUT_DIR="$2"; shift 2 ;;
    -h|--help) usage ;;
    *)
      if [[ -z "$MODEL" ]]; then MODEL="$1"; shift
      else echo "unknown arg: $1" >&2; usage
      fi
      ;;
  esac
done

[[ -n "$MODEL" && -f "$MODEL" ]] || { echo "need a model GGUF path" >&2; usage; }
if [[ -z "$LLAMA_DIR" ]]; then
  if command -v llama-bench >/dev/null 2>&1; then
    BENCH=$(command -v llama-bench)
  else
    echo "set LLAMA_DIR to the folder that contains llama-bench" >&2
    exit 2
  fi
else
  BENCH="$LLAMA_DIR/llama-bench"
  export LD_LIBRARY_PATH="${LLAMA_DIR}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
[[ -x "$BENCH" ]] || { echo "llama-bench not executable: $BENCH" >&2; exit 2; }

TAG=$(basename "$MODEL" .gguf)
TS=$(date '+%Y%m%d-%H%M%S')
DEST="$OUT_DIR/${TAG}-${TS}"
mkdir -p "$DEST"

echo "model=$MODEL threads=$THREADS reps=$REPS pp=$PP tg=$TG out=$DEST"

IFS=',' read -ra TLIST <<< "$THREADS"
for T in "${TLIST[@]}"; do
  T=${T// /}
  LOAD=$(awk '{print $1}' /proc/loadavg)
  if awk -v l="$LOAD" -v m="$LOAD_MAX" 'BEGIN{exit !(l >= m+0)}'; then
    echo "load=$LOAD is at or above --load-max $LOAD_MAX for -t $T; waiting up to 4 minutes"
    n=0
    while awk -v l="$(awk '{print $1}' /proc/loadavg)" -v m="$LOAD_MAX" 'BEGIN{exit !(l >= m+0)}' && [[ $n -lt 24 ]]; do
      sleep 10
      n=$((n + 1))
    done
    LOAD=$(awk '{print $1}' /proc/loadavg)
    if awk -v l="$LOAD" -v m="$LOAD_MAX" 'BEGIN{exit !(l >= m+0)}'; then
      echo "SKIP t$T load=$LOAD still high" | tee -a "$DEST/skipped.txt"
      continue
    fi
  fi

  if ! "$GATE" --model "$MODEL" --margin-mb "$MARGIN_MB" --tries 6 --sleep 60 | tee "$DEST/t${T}-gate.txt"; then
    echo "SKIP t$T RAM gate failed" | tee -a "$DEST/skipped.txt"
    continue
  fi

  P="$DEST/t${T}"
  {
    echo "timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "model: $MODEL threads=$T reps=$REPS"
    uptime
    free -m
    ps aux --sort=-%cpu | head -8
  } > "$P-env.txt"

  echo "run t$T load=$(awk '{print $1}' /proc/loadavg) $(date +%T)"
  python3 "$RTIME" "$BENCH" -m "$MODEL" -p "$PP" -n "$TG" -t "$T" -r "$REPS" -o md \
    > "$P-bench.txt" 2> "$P-bench.time.txt" || {
      echo "llama-bench failed t$T (exit $?)" | tee -a "$DEST/skipped.txt"
      continue
    }
  echo "wrote $P-bench.txt"
done

echo "DONE $DEST"
if [[ -f "$HERE/summarize_bench.py" ]]; then
  python3 "$HERE/summarize_bench.py" "$DEST" || true
fi
