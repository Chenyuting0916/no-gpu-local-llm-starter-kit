#!/usr/bin/env bash
# start_llama_server.sh — recommended llama-server flags from No GPU Lab video 007
# (and the -lm none RAM option from video 008).
#
# What went wrong with defaults on a 16 GB box, video 007, Qwen3.5-4B Q4_K_M:
#   llama-server with only -m chose n_ctx_slot 262144 and 4 slots;
#   RSS climbed to 12.77 GB and the run had to be stopped.
#   Fix: -c 16384 -np 1, and on an 8-core box that is not idle, -t 7.
#
# Video 008, Qwen3-4B Q4_K_M, 4096-token context, single runs:
#   peak RSS 5,432 MiB with default memory-mapping
#   peak RSS 3,378 MiB with -lm none
# Pass --no-mmap to add -lm none.
#
# Usage:
#   export LLAMA_DIR=/path/to/llama-cpp-binaries
#   ./start_llama_server.sh /path/to/Qwen3.5-4B-Q4_K_M.gguf
#   ./start_llama_server.sh MODEL.gguf --port 8080 --threads 7 --ctx 16384 --no-mmap
set -euo pipefail

MODEL=""
PORT=8080
THREADS=7
CTX=16384
SLOTS=1
HOST=127.0.0.1
NO_MMAP=0
EXTRA=()
LLAMA_DIR="${LLAMA_DIR:-}"

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \?//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) PORT="$2"; shift 2 ;;
    --threads) THREADS="$2"; shift 2 ;;
    --ctx) CTX="$2"; shift 2 ;;
    --slots) SLOTS="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --no-mmap) NO_MMAP=1; shift ;;
    -h|--help) usage ;;
    --) shift; EXTRA+=("$@"); break ;;
    *)
      if [[ -z "$MODEL" ]]; then MODEL="$1"; shift
      else EXTRA+=("$1"); shift
      fi
      ;;
  esac
done

[[ -n "$MODEL" && -f "$MODEL" ]] || { echo "need a model GGUF path" >&2; usage; }

if [[ -n "$LLAMA_DIR" ]]; then
  BIN="$LLAMA_DIR/llama-server"
  export LD_LIBRARY_PATH="${LLAMA_DIR}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
else
  BIN=$(command -v llama-server || true)
fi
[[ -n "$BIN" && -x "$BIN" ]] || { echo "set LLAMA_DIR or put llama-server on PATH" >&2; exit 2; }

CMD=("$BIN" -m "$MODEL" -t "$THREADS" -c "$CTX" -np "$SLOTS" --jinja --host "$HOST" --port "$PORT" --no-webui)
if [[ "$NO_MMAP" -eq 1 ]]; then
  CMD+=(-lm none)
fi
CMD+=("${EXTRA[@]}")

echo "starting: ${CMD[*]}"
echo "chat:  http://$HOST:$PORT/v1/chat/completions"
echo "For Qwen3 / Qwen3.5, send chat_template_kwargs.enable_thinking=false unless you want a think block."
exec "${CMD[@]}"
