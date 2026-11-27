#!/usr/bin/env bash
# hwcheck.sh — print the facts that decide whether a CPU-only local LLM will run.
# No GPU Lab video 001 used this kind of check (ls /dev/dri /dev/nvidia0 + nvidia-smi,
# not lspci — lspci was not installed on the test box).
# Usage: ./hwcheck.sh
set -euo pipefail

echo "=== CPU ==="
if command -v lscpu >/dev/null 2>&1; then
  lscpu | awk -F: '
    /^(CPU\(s\)|Model name|Thread\(s\) per core|Core\(s\) per socket|Socket\(s\)|Hypervisor vendor|L2 cache|L3 cache|NUMA node\(s\)|Flags):/ {
      key=$1; sub(/^[ \t]+/, "", $2); printf "%-22s %s\n", key":", $2
    }'
  FLAGS=$(lscpu | awk -F: '/^Flags:/{print $2}')
  echo
  echo "SIMD / matrix flags present:"
  for f in avx2 avx_vnni avx512f avx512_vnni avx512_bf16 amx_tile amx_int8 amx_bf16 fma; do
    if printf '%s' "$FLAGS" | grep -qw "$f"; then
      printf "  %-16s yes\n" "$f"
    else
      printf "  %-16s no\n" "$f"
    fi
  done
else
  echo "lscpu not found. nproc=$(nproc 2>/dev/null || echo unknown)"
fi

echo
echo "=== RAM ==="
if [[ -r /proc/meminfo ]]; then
  awk '/MemTotal|MemAvailable|SwapTotal|SwapFree/{printf "%-16s %s\n", $1, $2 " " $3}' /proc/meminfo
else
  free -h
fi
if command -v free >/dev/null 2>&1; then
  echo
  free -h
fi

echo
echo "=== GPU (absence check) ==="
# Do not use lspci as the only evidence; it may not be installed.
for p in /dev/dri /dev/nvidia0 /dev/nvidiactl; do
  if [[ -e "$p" ]]; then
    echo "FOUND  $p"
  else
    echo "absent $p"
  fi
done
if command -v nvidia-smi >/dev/null 2>&1; then
  echo "nvidia-smi is installed:"
  nvidia-smi -L || true
else
  echo "nvidia-smi: not installed"
fi

echo
echo "=== OS ==="
uname -srm
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  echo "${PRETTY_NAME:-$NAME}"
fi

if [[ -n "${LLAMA_DIR:-}" && -d "$LLAMA_DIR" ]]; then
  echo
  echo "=== llama.cpp at LLAMA_DIR=$LLAMA_DIR ==="
  ls -1 "$LLAMA_DIR"/libggml-cpu-*.so 2>/dev/null || echo "(no libggml-cpu-*.so found)"
  if [[ -x "$LLAMA_DIR/llama-cli" ]]; then
    "$LLAMA_DIR/llama-cli" --version 2>&1 | head -20 || true
  elif [[ -x "$LLAMA_DIR/llama-bench" ]]; then
    "$LLAMA_DIR/llama-bench" --version 2>&1 | head -20 || true
  fi
fi
