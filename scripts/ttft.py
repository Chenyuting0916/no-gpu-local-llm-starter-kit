#!/usr/bin/env python3
"""Time-to-first-token against a local llama-server (streaming chat).

Based on the No GPU Lab video 001 / 008 TTFT scripts, with box-specific
paths removed. Starts its own llama-server, does one warm-up request
(not counted), then REPS measured runs. Stops only the server it started.

Usage:
  export LLAMA_DIR=/path/to/llama-cpp-binaries
  ./ttft.py --model /path/to/model.gguf --prompt ../prompts/summary-article.txt --port 8082

Defaults match the 008 test shape where practical: -c 4096 -t 8 -np 1 --jinja,
temp 0, top_k 1, seed 42, thinking off, cache_prompt false, max 64 tokens.
Override with flags. Does not start if a server is already on --port.
"""
from __future__ import annotations

import argparse
import json
import os
import statistics
import subprocess
import sys
import time
import urllib.request


def wait_health(port: int, timeout: float = 240.0) -> None:
    t0 = time.time()
    url = f"http://127.0.0.1:{port}/health"
    while time.time() - t0 < timeout:
        try:
            with urllib.request.urlopen(url, timeout=2) as r:
                body = r.read()
                try:
                    data = json.loads(body.decode())
                    if data.get("status") in ("ok", None) or r.status == 200:
                        return
                except json.JSONDecodeError:
                    if r.status == 200:
                        return
        except Exception:
            time.sleep(0.25)
    raise SystemExit(f"llama-server did not become ready on port {port}")


def one_request(port: int, prompt: str, max_tokens: int) -> dict:
    body = {
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0,
        "top_k": 1,
        "seed": 42,
        "max_tokens": max_tokens,
        "stream": True,
        "cache_prompt": False,
        "chat_template_kwargs": {"enable_thinking": False},
        "stream_options": {"include_usage": True},
    }
    req = urllib.request.Request(
        f"http://127.0.0.1:{port}/v1/chat/completions",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
    )
    t0 = time.time()
    first = None
    text = ""
    timings = None
    with urllib.request.urlopen(req, timeout=600) as r:
        for raw in r:
            line = raw.decode().strip()
            if not line.startswith("data: ") or line == "data: [DONE]":
                continue
            d = json.loads(line[6:])
            if d.get("timings"):
                timings = d["timings"]
            for c in d.get("choices", []):
                delta = c.get("delta", {})
                piece = (delta.get("content") or "") + (delta.get("reasoning_content") or "")
                if piece and first is None:
                    first = time.time() - t0
                text += piece
    return {
        "ttft_s": round(first, 3) if first is not None else None,
        "total_s": round(time.time() - t0, 3),
        "text": text,
        "timings": timings,
        "load1": open("/proc/loadavg", encoding="utf-8").read().split()[0],
    }


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--model", required=True)
    p.add_argument("--prompt", required=True, help="path to a UTF-8 prompt file")
    p.add_argument("--port", type=int, default=8082)
    p.add_argument("--threads", type=int, default=8)
    p.add_argument("--ctx", type=int, default=4096)
    p.add_argument("--reps", type=int, default=3)
    p.add_argument("--max-tokens", type=int, default=64)
    p.add_argument("--out", default="", help="JSON output path (default: ttft-<model>-<ts>.json)")
    p.add_argument("--llama-dir", default=os.environ.get("LLAMA_DIR", ""))
    args = p.parse_args()

    if not os.path.isfile(args.model):
        sys.exit(f"model not found: {args.model}")
    prompt = open(args.prompt, encoding="utf-8").read()
    llama_dir = args.llama_dir
    if llama_dir:
        server = os.path.join(llama_dir, "llama-server")
        extra = (":" + os.environ["LD_LIBRARY_PATH"]) if os.environ.get("LD_LIBRARY_PATH") else ""
        env = {**os.environ, "LD_LIBRARY_PATH": llama_dir + extra}
    else:
        server = "llama-server"
        env = os.environ.copy()

    tag = os.path.splitext(os.path.basename(args.model))[0]
    ts = time.strftime("%Y%m%d-%H%M%S")
    outp = args.out or f"ttft-{tag}-{ts}.json"
    log_path = os.path.splitext(outp)[0] + ".server.log"
    log = open(log_path, "w", encoding="utf-8")
    cmd = [
        server, "-m", args.model, "-c", str(args.ctx), "-t", str(args.threads),
        "--jinja", "--host", "127.0.0.1", "--port", str(args.port), "-np", "1",
        "--no-webui",
    ]
    srv = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT, env=env)
    res = {"model": args.model, "prompt_file": args.prompt, "cmd": cmd, "runs": []}
    try:
        wait_health(args.port)
        print("warmup...", flush=True)
        res["warmup"] = one_request(args.port, prompt, args.max_tokens)
        for i in range(args.reps):
            run = one_request(args.port, prompt, args.max_tokens)
            res["runs"].append(run)
            print(f"rep {i+1}/{args.reps} ttft={run['ttft_s']}s total={run['total_s']}s", flush=True)
    finally:
        srv.terminate()
        try:
            srv.wait(30)
        except subprocess.TimeoutExpired:
            srv.kill()
        log.close()

    tt = [r["ttft_s"] for r in res["runs"] if r["ttft_s"] is not None]
    tot = [r["total_s"] for r in res["runs"]]
    res["median_ttft_s"] = statistics.median(tt) if tt else None
    res["median_total_s"] = statistics.median(tot) if tot else None
    res["prompt_n"] = (res["runs"][0]["timings"] or {}).get("prompt_n") if res["runs"] else None
    json.dump(res, open(outp, "w", encoding="utf-8"), indent=1)
    print(
        f"wrote {outp} prompt_n={res['prompt_n']} "
        f"ttft median={res['median_ttft_s']}s {tt} "
        f"total median={res['median_total_s']}s {tot}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
