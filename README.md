# No GPU Lab — no-GPU local LLM scripts

Small scripts for running [llama.cpp](https://github.com/ggml-org/llama.cpp) on a Linux CPU, with no GPU. They are the same MIT scripts that ship in the No GPU Lab starter kit.

They exist because a 16 GB box on [No GPU Lab](https://www.youtube.com/@NoGPULab) did two things with stock defaults:

- `llama-server` started with only `-m` chose a 262,144-token context and four slots, and memory reached 12.77 GB.
- Ollama, with no GPU, defaulted to a 4,096-token context, returned HTTP 200 on a 14,995-token prompt, and read only about 2,818 tokens.

Those measurements, and the rest of the speed / RAM tables, are in the longer paid guide (Gumroad listing, link to be added when it is live) and in the videos.

## Quick start

```bash
export LLAMA_DIR=/path/to/your/llama.cpp-cpu-binaries
chmod +x scripts/*.sh scripts/*.py
./scripts/hwcheck.sh
./scripts/start_llama_server.sh /path/to/model.gguf          # -t 7 -c 16384 -np 1
./scripts/run_bench.sh /path/to/model.gguf --threads 2,4,6,7,8
```

| Script | Purpose |
|---|---|
| `scripts/hwcheck.sh` | CPU, SIMD flags, RAM, GPU-absence check (`/dev/dri`, `nvidia-smi` — not `lspci` alone) |
| `scripts/ram_gate.sh` | Wait until MemAvailable ≥ file size + margin, or a fixed floor |
| `scripts/rtime.py` / `rss_run.py` | Peak RSS + wall time |
| `scripts/run_bench.sh` | `llama-bench -p 512 -n 128 -r 3` with the RAM / load gates |
| `scripts/summarize_bench.py` | Markdown + CSV summary of a bench folder |
| `scripts/ttft.py` | Streaming time-to-first-token against a local llama-server |
| `scripts/start_llama_server.sh` | Recommended server flags |
| `scripts/start_speculative.sh` | Gemma 4 E2B + MTP drafter flags (`-md`, `--spec-type draft-mtp`) |

`configs/Modelfile.qwen35-4b` sets Ollama `num_ctx 16384`. `configs/opencode.json` points OpenCode at `http://127.0.0.1:8080/v1` with a 16,384 context limit.

These scripts do not download models and do not contain model files.

## Test machine (so you know what not to assume)

8 vCPU Intel Xeon in a KVM guest, ~16 GB RAM, no swap, no GPU, official llama.cpp `ubuntu-x64` CPU builds (b12430 and v1.0.0 / b12359). The box is shared, so free RAM moves around. Numbers from that box live in the videos, starting with [video 001](https://youtu.be/F6dgQaKb7MA).

## License

MIT. See `LICENSE`.

If you run Llama 3.2: Built with Llama. Llama 3.2 is licensed under the Llama 3.2 Community License, Copyright © Meta Platforms, Inc. All Rights Reserved.

Channel: https://www.youtube.com/@NoGPULab
