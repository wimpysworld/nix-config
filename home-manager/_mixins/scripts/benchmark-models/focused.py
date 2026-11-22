"""Compare Vulkan and ROCm llama-server builds with the same local GGUF files."""

import argparse
from contextlib import contextmanager
import hashlib
import http.client
import json
import os
from pathlib import Path
from queue import Empty, Queue
import re
import signal
from statistics import median
import subprocess
import sys
from tempfile import mkdtemp
from threading import Event, Thread
import time


PROMPT_TOKENS = 4096
OUTPUT_TOKENS = 512
MEASURED_RUNS = 3
DEVICES = {"vulkan": "Vulkan0", "rocm": "ROCm0"}
WIDTHS = {"inkling": (0,), "qwen": (0, 2, 3)}


def follow_server(pipe, log, ready):
    for line in pipe:
        log.write(line)
        log.flush()
        match = re.search(rb"listening on http://127\.0\.0\.1:(\d+)", line)
        if match:
            ready.put(int(match[1]))
    ready.put(None)


@contextmanager
def post(port, path, payload):
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=600)
    try:
        connection.request("POST", path, json.dumps(payload), {"Content-Type": "application/json"})
        with connection.getresponse() as response:
            if response.status != 200:
                raise RuntimeError(f"{path}: HTTP {response.status}: {response.read(2048)!r}")
            yield response
    finally:
        connection.close()


def make_prompt(port):
    def tokenize(text, add_special):
        with post(port, "/tokenize", {"content": text, "add_special": add_special}) as response:
            return json.load(response)["tokens"]

    lines = [
        f"{i:04d} {('INFO', 'ERROR', 'WARNING', 'INFO', 'INVALID')[i % 5]} "
        f"worker={i % 17} job={i * 11} elapsed_ms={(i * 137) % 999}"
        for i in range(400)
    ]
    logs = tokenize("Application log:\n" + "\n".join(lines), True)
    task = tokenize(
        "\nWrite a Python function named summarise_log(lines) that counts INFO, WARNING "
        "and ERROR entries, ignores malformed lines and returns a dictionary. "
        "Explain the parser and provide examples and tests.\n", False
    )
    tokens = logs[:PROMPT_TOKENS - len(task)] + task
    if len(tokens) != PROMPT_TOKENS:
        raise ValueError(f"expected {PROMPT_TOKENS} prompt tokens, got {len(tokens)}")
    return tokens


def completion(port, tokens, width):
    payload = {
        "prompt": tokens, "n_predict": OUTPUT_TOKENS, "temperature": 0, "seed": 42,
        "ignore_eos": True, "cache_prompt": False, "return_tokens": True, "stream": True,
    }
    started = time.monotonic()
    first = None
    with post(port, "/completion", payload) as response:
        for line in response:
            if not line.startswith(b"data:"):
                continue
            event = json.loads(line[5:])
            received = time.monotonic()
            if event.get("error"):
                raise RuntimeError(str(event["error"]))
            if event["stop"]:
                break
            if first is None and event["tokens"]:
                first = received
        else:
            raise RuntimeError("completion stream ended without final timings")

    timing = event["timings"]
    if first is None or timing["prompt_n"] != PROMPT_TOKENS or timing["predicted_n"] != OUTPUT_TOKENS:
        raise ValueError(f"missing streamed token or unexpected token counts: {timing}")
    drafts = timing.get("draft_n", 0)
    accepted = timing.get("draft_n_accepted", 0)
    if bool(width) != bool(drafts) or not 0 <= accepted <= drafts:
        raise ValueError(f"unexpected draft counters for width {width}: {timing}")
    return {
        "ttft_ms": (first - started) * 1000, "total_ms": (received - started) * 1000,
        "prefill_tps": timing["prompt_per_second"], "decode_tps": timing["predicted_per_second"],
        "timings": timing,
    }


def sample_gpu_memory(stop, peaks):
    counters = []
    for device in Path("/sys/class/drm").glob("card[0-9]*/device"):
        if device.parent.name[4:].isdigit() and (device / "driver").resolve().name == "amdgpu":
            counters.extend(device.glob("mem_info_*_used"))
    while True:
        for counter in counters:
            key = f"{counter.parent.parent.name}/{counter.name}"
            try:
                peaks[key] = max(peaks.get(key, 0), int(counter.read_text()))
            except (OSError, ValueError):
                continue
        if stop.wait(0.2):
            return


def run_case(args, model, backend, width):
    label = f"{model}-{backend}-" + (f"mtp{width}" if width else "off")
    command = [
        str(getattr(args, backend)), "--model", str(getattr(args, model)), "--offline",
        "--host", "127.0.0.1", "--port", "0", "--device", DEVICES[backend],
        "--gpu-layers", "all", "--fit", "off", "--flash-attn", "on", "--load-mode", "none",
        "--cache-type-k", "q8_0", "--cache-type-v", "q8_0",
        "--ctx-size", "8192", "--parallel", "1", "--batch-size", "2048", "--ubatch-size", "512",
        "--no-warmup", "--no-mmproj", "--no-cache-prompt", "--cache-ram", "0",
        "--spec-type", "draft-mtp" if width else "none",
    ]
    if width:
        command.extend(["--spec-draft-n-max", str(width)])
    print(f"{label}: starting", file=sys.stderr, flush=True)
    with (args.output / f"{label}.jsonl").open("x") as records, (args.output / f"{label}.log").open("xb") as log:
        def record(**fields):
            print(json.dumps({"case": label, **fields}), file=records, flush=True)

        record(kind="config", command=command)
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        ready = Queue()
        reader = Thread(target=follow_server, args=(process.stdout, log, ready))
        reader.start()
        try:
            try:
                port = ready.get(timeout=600)
            except Empty:
                raise RuntimeError("server did not announce a port within 600 s") from None
            if not port:
                raise RuntimeError(f"server exited before becoming ready, see {label}.log")
            tokens = make_prompt(port)
            record(kind="prompt", tokens=len(tokens), sha256=hashlib.sha256(json.dumps(tokens).encode()).hexdigest())
            record(kind="warmup", **completion(port, tokens, width))
            peaks = {}
            stop = Event()
            sampler = Thread(target=sample_gpu_memory, args=(stop, peaks))
            sampler.start()
            samples = []
            try:
                for number in range(1, MEASURED_RUNS + 1):
                    sample = completion(port, tokens, width)
                    record(kind="sample", number=number, **sample)
                    samples.append(sample)
            finally:
                stop.set()
                sampler.join()
            rates = {key: median(s[key] for s in samples) for key in ("ttft_ms", "total_ms", "prefill_tps", "decode_tps")}
            drafted = sum(s["timings"].get("draft_n", 0) for s in samples)
            accepted = sum(s["timings"].get("draft_n_accepted", 0) for s in samples)
            summary = dict(medians=rates, device_peak_bytes=peaks, draft_n=drafted, draft_n_accepted=accepted)
            record(kind="summary", **summary)
            print(json.dumps({"case": label, **summary}), flush=True)
        finally:
            if process.poll() is None:
                process.terminate()
            try:
                process.wait(timeout=20)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            reader.join()
            process.stdout.close()


def main():
    root = Path(os.environ.get("BENCHMARK_MODELS_ROOT") or Path.home() / "Volatile/benchmark-models")
    parser = argparse.ArgumentParser(
        prog="benchmark-models --focused",
        description="Compare Vulkan and ROCm on Strix Halo with local Inkling 2 Mini and Qwen3.8-27B models.",
        epilog=(
            "The Strix Halo package supplies llama-server b12628 for both backends. "
            "It uses the pinned Q4 models from the production or benchmark cache when available. "
            "When running from source, pass the paths to both executables. "
            "Use --backend to run only one. The benchmark does not download models."
        ),
    )
    parser.add_argument("--only", choices=WIDTHS, help="run one model (default: both)")
    parser.add_argument("--backend", choices=DEVICES, help="run one backend (default: both)")
    for backend in DEVICES:
        variable = f"BENCHMARK_MODELS_{backend.upper()}_SERVER"
        parser.add_argument(
            f"--{backend}", type=Path, metavar="SERVER", default=os.environ.get(variable) or None,
            help=f"path to the {backend} llama-server (or set {variable})",
        )
    for model in WIDTHS:
        variable = f"BENCHMARK_MODELS_{model.upper()}_GGUF"
        parser.add_argument(
            f"--{model}", type=Path, metavar="GGUF", default=default_model_path(model, root),
            help=f"path to the local {model} GGUF (or set {variable})",
        )
    parser.add_argument(
        "--output", type=Path, help="directory for logs and JSONL results (default: a new directory under BENCHMARK_MODELS_ROOT)",
    )
    args = parser.parse_args()
    models = [args.only] if args.only else list(WIDTHS)
    backends = [args.backend] if args.backend else list(DEVICES)
    for name in models + backends:
        path = getattr(args, name)
        mode = os.X_OK if name in backends else os.R_OK
        if not path or not path.is_file() or not os.access(path, mode):
            missing = f": {path}" if path else ""
            parser.error(f"--{name} requires an existing {'executable' if name in backends else 'readable GGUF'} file{missing}")
        setattr(args, name, path.absolute())
    if args.output is None:
        root.mkdir(parents=True, exist_ok=True)
        args.output = Path(mkdtemp(prefix="focused-", dir=root))
    else:
        args.output.mkdir(parents=True, exist_ok=True)
    print(f"Results: {args.output}", file=sys.stderr)
    failed = False
    for model in models:
        for width in WIDTHS[model]:
            for backend in backends:
                try:
                    run_case(args, model, backend, width)
                except (OSError, RuntimeError, ValueError, KeyError, http.client.HTTPException) as error:
                    print(f"{model} {backend} width {width}: {error}", file=sys.stderr)
                    failed = True
    return int(failed)


def default_model_path(model, root):
    override = os.environ.get(f"BENCHMARK_MODELS_{model.upper()}_GGUF")
    if override:
        return Path(override)
    snapshot = os.environ.get(f"BENCHMARK_FOCUSED_{model.upper()}_SNAPSHOT")
    cache = os.environ.get("BENCHMARK_FOCUSED_CACHE")
    if not snapshot or not cache:
        return None
    production_path = Path(cache) / snapshot
    if production_path.is_file() and os.access(production_path, os.R_OK):
        return production_path
    user_path = root / "huggingface" / snapshot
    if user_path.is_file() and os.access(user_path, os.R_OK):
        return user_path
    return production_path


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, signal.default_int_handler)
    sys.exit(main())
