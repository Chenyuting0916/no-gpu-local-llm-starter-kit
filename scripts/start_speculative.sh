#!/usr/bin/env bash
# start_speculative.sh — Gemma 4 E2B + MTP drafter flags from No GPU Lab video 009.
# That video is scheduled and not yet public; the measured numbers are in the paid guide.
#
# Exact flags used on the test box (llama.cpp 1.0.0-dev build 12359):
#   llama-server -m gemma-4-E2B-it-Q4_K_M.gguf \
#     -md mtp-gemma-4-E2B-it-Q8_0.gguf \
#     --spec-type draft-mtp --spec-draft-n-max N \
#     -fa off -t 8 -c 4096 -np 1 --jinja
#
# -md is also called --spec-draft-model or --model-draft.
# In this build, the older flags --draft / --draft-max / --draft-min were removed.
#
# What I would run, from that test (one model, one drafter, one CPU):
#   code / file edits / JSON  ->  --spec-draft-n-max 4
#   mostly chat or essays     ->  --spec-draft-n-max 2
#                               (n-max 4 was slightly slower than off on prose)
#
# Files used:
#   unsloth/gemma-4-E2B-it-GGUF / gemma-4-E2B-it-Q4_K_M.gguf
#   unsloth/gemma-4-E2B-it-GGUF / MTP/mtp-gemma-4-E2B-it-Q8_0.gguf
#
# Usage:
#   export LLAMA_DIR=/path/to/llama-cpp-binaries
#   ./start_speculative.sh --target /path/to/gemma-4-E2B-it-Q4_K_M.gguf \
#       --draft /path/to/mtp-gemma-4-E2B-it-Q8_0.gguf \
#       --n-max 4
set -euo pipefail

TARGET=""
DRAFT=""
NMAX=4
PORT=8080
THREADS=8
CTX=4096
HOST=127.0.0.1
LLAMA_DIR="${LLAMA_DIR:-}"

usage() {
  sed -n '2,28p' "$0" | sed 's/^# \?//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --draft) DRAFT="$2"; shift 2 ;;
    --n-max) NMAX="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --threads) THREADS="$2"; shift 2 ;;
    --ctx) CTX="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "unknown arg: $1" >&2; usage ;;
  esac
done

[[ -n "$TARGET" && -f "$TARGET" ]] || { echo "need --target MODEL.gguf" >&2; usage; }
[[ -n "$DRAFT" && -f "$DRAFT" ]] || { echo "need --draft MODEL.gguf" >&2; usage; }

if [[ -n "$LLAMA_DIR" ]]; then
  BIN="$LLAMA_DIR/llama-server"
  export LD_LIBRARY_PATH="${LLAMA_DIR}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
else
  BIN=$(command -v llama-server || true)
fi
[[ -n "$BIN" && -x "$BIN" ]] || { echo "set LLAMA_DIR or put llama-server on PATH" >&2; exit 2; }

CMD=("$BIN" -m "$TARGET" -md "$DRAFT" --spec-type draft-mtp --spec-draft-n-max "$NMAX"
     -fa off -t "$THREADS" -c "$CTX" -np 1 --jinja --host "$HOST" --port "$PORT" --no-webui)

echo "starting: ${CMD[*]}"
echo "If -md is rejected, run llama-server -h and look for --spec-draft-model / --model-draft."
exec "${CMD[@]}"
