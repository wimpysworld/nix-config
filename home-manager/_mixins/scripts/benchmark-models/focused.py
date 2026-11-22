"""Compare packaged llama-server backends with the same local GGUF file."""

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
SEED = 42
DEVICES = {"vulkan": "Vulkan0", "rocm": "ROCm0", "cuda": "CUDA0"}


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
        payload = {"content": text, "add_special": add_special, "parse_special": True}
        with post(port, "/tokenize", payload) as response:
            return json.load(response)["tokens"]

    lines = [
        f"{i:04d} {('INFO', 'ERROR', 'WARNING', 'INFO', 'INVALID')[i % 5]} "
        f"worker={i % 17} job={i * 11} elapsed_ms={(i * 137) % 999}"
        for i in range(400)
    ]
    task = (
        "\nWrite a Python function named summarise_log(lines) that counts INFO, WARNING "
        "and ERROR entries, ignores malformed lines and returns a dictionary. "
        "Explain the parser and provide examples and tests."
    )
    messages = [{"role": "user", "content": "Application log:\n" + "\n".join(lines) + task}]
    with post(port, "/apply-template", {"messages": messages}) as response:
        rendered = json.load(response)["prompt"]
    prefix, found, suffix = rendered.rpartition(task)
    if not found:
        raise ValueError("chat template did not preserve the benchmark task")

    # Trim only the log data, leaving the task and assistant prompt intact.
    # llama.cpp leaves out the template BOS when the tokenizer adds it.
    log_tokens = tokenize(prefix, True)
    task_tokens = tokenize(task + suffix, False)
    log_budget = PROMPT_TOKENS - len(task_tokens)
    if log_budget <= 0:
        raise ValueError("chat template and benchmark task exceed the prompt budget")
    tokens = log_tokens[:log_budget] + task_tokens
    if len(tokens) != PROMPT_TOKENS:
        raise ValueError(f"expected {PROMPT_TOKENS} prompt tokens, got {len(tokens)}")
    return tokens


def completion(port, tokens, width, sampling):
    payload = {
        **sampling, "prompt": tokens, "n_predict": OUTPUT_TOKENS, "seed": SEED,
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


def run_case(output, model, model_path, backend, server, width, runs, profile):
    label = f"{model}-{backend}-" + (f"mtp{width}" if width else "off")
    microbatch = str(profile["microBatchSize"] or 512)
    command = [
        str(server), "--model", str(model_path), "--offline",
        "--host", "127.0.0.1", "--port", "0", "--device", DEVICES[backend],
        "--gpu-layers", "all", "--fit", "off", "--flash-attn", "on", "--load-mode", "none",
        "--cache-type-k", "q8_0", "--cache-type-v", "q8_0",
        "--ctx-size", "8192", "--parallel", "1", "--batch-size", "2048", "--ubatch-size", microbatch,
        "--jinja", "--no-warmup", "--no-mmproj", "--no-cache-prompt", "--cache-ram", "0",
        "--spec-type", "draft-mtp" if width else "none",
    ]
    if profile["reasoning"] is not None:
        command.extend(["--reasoning", profile["reasoning"]])
    if profile["reasoningEffort"] is not None:
        command.extend(["--reasoning-effort", profile["reasoningEffort"]])
    if width:
        command.extend(["--spec-draft-n-max", str(width)])
    sampling = profile["sampling"]
    print(f"{label}: starting", file=sys.stderr, flush=True)
    with (output / f"{label}.jsonl").open("x") as records, (output / f"{label}.log").open("xb") as log:
        def record(**fields):
            print(json.dumps({"case": label, **fields}), file=records, flush=True)

        record(kind="config", command=command, sampling=sampling, seed=SEED)
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
            record(kind="warmup", **completion(port, tokens, width, sampling))
            peaks = {}
            stop = Event()
            sampler = Thread(target=sample_gpu_memory, args=(stop, peaks))
            sampler.start()
            samples = []
            try:
                for number in range(1, runs + 1):
                    sample = completion(port, tokens, width, sampling)
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
    model = sys.argv[1]
    runs = int(sys.argv[2])
    widths = (0, 2, 3) if model == "qwen3.8-27b" else (0,)
    backends = os.environ.get("BENCHMARK_MODELS_BACKENDS", "").split()
    if not backends:
        print("Error: no GPU benchmark backend is configured for this host.", file=sys.stderr)
        return 1

    profile = json.loads(os.environ["BENCHMARK_MODELS_PROFILES"]).get(model, {})
    snapshot = profile.get("snapshot")
    if not snapshot:
        print(f"Error: {model} is not configured for this host's video memory tier.", file=sys.stderr)
        return 1

    root = Path(os.environ.get("BENCHMARK_MODELS_ROOT") or Path.home() / "Volatile/benchmark-models")
    try:
        model_path = cached_model_path(Path(snapshot), root, profile["projectorPath"])
    except ValueError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    if model_path is None:
        print(f"Error: no readable cached GGUF for {model}: {snapshot}", file=sys.stderr)
        return 1

    servers = {}
    for backend in backends:
        server = os.environ.get(f"BENCHMARK_MODELS_{backend.upper()}_SERVER")
        if not server or not Path(server).is_file() or not os.access(server, os.X_OK):
            print(f"Error: packaged {backend} llama-server is not executable: {server}", file=sys.stderr)
            return 1
        servers[backend] = server

    root.mkdir(parents=True, exist_ok=True)
    output = Path(mkdtemp(prefix=f"{model}-", dir=root))
    print(f"Results: {output}", file=sys.stderr)
    failed = False
    for width in widths:
        for backend, server in servers.items():
            try:
                run_case(output, model, model_path, backend, server, width, runs, profile)
            except (OSError, RuntimeError, ValueError, KeyError, http.client.HTTPException) as error:
                print(f"{model} {backend} width {width}: {error}", file=sys.stderr)
                failed = True
    return int(failed)


def cached_model_path(snapshot, root, projector):
    preseed_cache = os.environ["BENCHMARK_MODELS_PRESEED_CACHE"]
    user_cache = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    hf_home = Path(os.environ.get("HF_HOME") or user_cache / "huggingface")
    hf_hub = Path(os.environ.get("HF_HUB_CACHE") or os.environ.get("HUGGINGFACE_HUB_CACHE") or hf_home / "hub")
    pattern = snapshot.relative_to("hub")
    for cache in (Path(preseed_cache) / "hub", root / "huggingface/hub", hf_hub):
        matches = [
            path for path in cache.glob(str(pattern))
            if path.is_file() and os.access(path, os.R_OK)
            and (not projector or (path.parent / projector).is_file())
        ]
        if len(matches) > 1:
            raise ValueError(f"ambiguous cached model: {cache / pattern} matches {len(matches)} snapshots")
        if matches:
            return matches[0].absolute()
    return None


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, signal.default_int_handler)
    sys.exit(main())
