"""Compare packaged llama-server and Ollama backends with the same local GGUF file."""

from __future__ import annotations

import argparse
from contextlib import contextmanager
import hashlib
import http.client
import json
import os
from pathlib import Path
from queue import Empty, Queue
import re
import shutil
import signal
import socket
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
MTP_BACKENDS = {"vulkan", "rocm"}
UNSUPPORTED_OLLAMA_PATTERNS = (
    "unknown model architecture",
    "unsupported architecture",
    "not supported",
    "unsupported model",
    "failed to load model",
    "invalid gguf",
)


def build_benchmark_prompt_text() -> str:
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
    return "Application log:\n" + "\n".join(lines) + task


def follow_server(pipe, log, ready):
    for line in pipe:
        log.write(line)
        log.flush()
        match = re.search(rb"listening on http://127\.0\.0\.1:(\d+)", line)
        if match:
            ready.put(int(match[1]))
    ready.put(None)


def follow_process_log(pipe, log):
    for line in pipe:
        log.write(line)
        log.flush()


def find_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


@contextmanager
def post(port: int, path: str, payload: dict[str, object]):
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=600)
    try:
        connection.request("POST", path, json.dumps(payload), {"Content-Type": "application/json"})
        with connection.getresponse() as response:
            if response.status != 200:
                raise RuntimeError(f"{path}: HTTP {response.status}: {response.read(2048)!r}")
            yield response
    finally:
        connection.close()


def make_prompt(port: int):
    def tokenize(text: str, add_special: bool):
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


def completion(port: int, tokens: list[int], width: int, sampling: dict[str, object]):
    payload = {
        **sampling,
        "prompt": tokens,
        "n_predict": OUTPUT_TOKENS,
        "seed": SEED,
        "ignore_eos": True,
        "cache_prompt": False,
        "return_tokens": True,
        "stream": True,
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
        "ttft_ms": (first - started) * 1000,
        "total_ms": (received - started) * 1000,
        "prefill_tps": timing["prompt_per_second"],
        "decode_tps": timing["predicted_per_second"],
        "timings": timing,
    }


def ollama_generate(port: int, tag: str, prompt_text: str, profile: dict[str, object]):
    sampling = profile.get("sampling") or {}
    options: dict[str, object] = {
        "num_ctx": 8192,
        "num_predict": OUTPUT_TOKENS,
        "seed": SEED,
    }
    for key in ("temperature", "top_k", "top_p", "min_p", "repeat_penalty", "presence_penalty"):
        if key in sampling and sampling[key] is not None:
            options[key] = sampling[key]
    payload: dict[str, object] = {
        "model": tag,
        "prompt": prompt_text,
        "stream": True,
        "options": options,
    }
    if profile.get("reasoning") == "on":
        payload["think"] = True

    started = time.monotonic()
    first = None
    final_event = None
    with post(port, "/api/generate", payload) as response:
        for raw_line in response:
            line = raw_line.strip()
            if not line:
                continue
            event = json.loads(line)
            received = time.monotonic()
            if event.get("error"):
                raise RuntimeError(str(event["error"]))
            if first is None and (event.get("response") or event.get("thinking")):
                first = received
            if event.get("done"):
                final_event = event
                break
    if final_event is None or first is None:
        raise RuntimeError("ollama generate stream ended without final timings")

    prompt_eval_count = int(final_event.get("prompt_eval_count") or 0)
    prompt_eval_ns = int(final_event.get("prompt_eval_duration") or 0)
    eval_count = int(final_event.get("eval_count") or 0)
    eval_ns = int(final_event.get("eval_duration") or 0)
    if eval_count <= 0 or eval_ns <= 0 or prompt_eval_count <= 0 or prompt_eval_ns <= 0:
        raise RuntimeError(f"ollama returned incomplete timings: {final_event}")

    return {
        "ttft_ms": (first - started) * 1000,
        "total_ms": (received - started) * 1000,
        "prefill_tps": prompt_eval_count / (prompt_eval_ns / 1e9),
        "decode_tps": eval_count / (eval_ns / 1e9),
        "timings": {
            "prompt_n": prompt_eval_count,
            "predicted_n": eval_count,
            "prompt_eval_duration_ns": prompt_eval_ns,
            "eval_duration_ns": eval_ns,
        },
    }


def classify_ollama_error(message: str) -> tuple[str, str]:
    lowered = message.lower()
    for pattern in UNSUPPORTED_OLLAMA_PATTERNS:
        if pattern in lowered:
            first_line = next((ln.strip() for ln in message.splitlines() if ln.strip()), message.strip())
            return "unsupported", first_line[:80]
    first_line = next((ln.strip() for ln in message.splitlines() if ln.strip()), message.strip())
    return "failed", first_line[:80]


def sample_gpu_memory(stop: Event, peaks: dict[str, int]):
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


def peak_vram_bytes(peaks: dict[str, int] | None) -> int | None:
    if not peaks:
        return None
    vram_keys = [v for k, v in peaks.items() if "vram_used" in k]
    if vram_keys:
        return max(vram_keys)
    return max(peaks.values())


def run_llama_case(output: Path, model: str, model_path: Path, backend: str, server: str, width: int, runs: int, profile: dict[str, object], emit_json: bool) -> dict[str, object]:
    mode = f"mtp{width}" if width else "off"
    label = f"{model}-llama-{backend}-{mode}"
    microbatch = str(profile.get("microBatchSize") or 512)
    command = [
        str(server),
        "--model", str(model_path),
        "--offline",
        "--host", "127.0.0.1",
        "--port", "0",
        "--device", DEVICES[backend],
        "--gpu-layers", "all",
        "--fit", "off",
        "--flash-attn", "on",
        "--load-mode", "none",
        "--cache-type-k", "q8_0",
        "--cache-type-v", "q8_0",
        "--ctx-size", "8192",
        "--parallel", "1",
        "--batch-size", "2048",
        "--ubatch-size", microbatch,
        "--jinja",
        "--no-warmup",
        "--no-mmproj",
        "--no-cache-prompt",
        "--cache-ram", "0",
        "--spec-type", "draft-mtp" if width else "none",
    ]
    if profile.get("reasoning") is not None:
        command.extend(["--reasoning", str(profile["reasoning"])])
    if profile.get("reasoningEffort") is not None:
        command.extend(["--reasoning-effort", str(profile["reasoningEffort"])])
    if width:
        command.extend(["--spec-draft-n-max", str(width)])
    sampling = profile["sampling"]
    print(f"{label}: starting", file=sys.stderr, flush=True)
    with (output / f"{label}.jsonl").open("x") as records, (output / f"{label}.log").open("xb") as log:
        def record(**fields):
            print(json.dumps({"case": label, **fields}), file=records, flush=True)

        record(kind="config", runner="llama.cpp", model=model, backend=backend, mode=mode, command=command, sampling=sampling, seed=SEED)
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        ready: Queue[int | None] = Queue()
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
            peaks: dict[str, int] = {}
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
            summary = {
                "case": label,
                "model": model,
                "runner": "llama.cpp",
                "backend": backend,
                "mode": mode,
                "status": "ok",
                "medians": rates,
                "device_peak_bytes": peaks or None,
                "draft_n": drafted,
                "draft_n_accepted": accepted,
            }
            record(kind="summary", **{k: v for k, v in summary.items() if k != "case"})
            if emit_json:
                print(json.dumps(summary), flush=True)
            return summary
        finally:
            if process.poll() is None:
                process.terminate()
            try:
                process.wait(timeout=20)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            reader.join()
            if process.stdout is not None:
                process.stdout.close()


def wait_for_ollama(port: int, process: subprocess.Popen[bytes], timeout: float = 30.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f"ollama serve exited early with code {process.returncode}")
        try:
            conn = http.client.HTTPConnection("127.0.0.1", port, timeout=2)
            try:
                conn.request("GET", "/api/tags")
                resp = conn.getresponse()
                resp.read()
                if resp.status == 200:
                    return
            finally:
                conn.close()
        except OSError:
            pass
        time.sleep(0.5)
    raise RuntimeError("timed out waiting for temporary ollama serve")


def run_ollama_case(output: Path, model: str, model_path: Path, backend: str, ollama_bin: str, runs: int, profile: dict[str, object], emit_json: bool) -> dict[str, object]:
    label = f"{model}-ollama-{backend}-off"
    port = find_free_port()
    tmp_ollama = Path(mkdtemp(prefix=f"ollama-{backend}-", dir=output))
    models_dir = tmp_ollama / "models"
    home_dir = tmp_ollama / "home"
    models_dir.mkdir(parents=True, exist_ok=True)
    home_dir.mkdir(parents=True, exist_ok=True)
    modelfile = tmp_ollama / "Modelfile"
    modelfile.write_text(f"FROM {model_path}\nPARAMETER num_ctx 8192\n", encoding="utf-8")
    tag = f"benchmark-{re.sub(r'[^a-zA-Z0-9._-]', '-', model)}"

    env = os.environ.copy()
    env.update(
        {
            "HOME": str(home_dir),
            "OLLAMA_HOST": f"127.0.0.1:{port}",
            "OLLAMA_MODELS": str(models_dir),
            "OLLAMA_FLASH_ATTENTION": "1",
            "OLLAMA_KV_CACHE_TYPE": "q8_0",
            "OLLAMA_NOHISTORY": "1",
        }
    )

    print(f"{label}: starting", file=sys.stderr, flush=True)
    prompt_text = build_benchmark_prompt_text()
    with (output / f"{label}.jsonl").open("x") as records, (output / f"{label}.log").open("xb") as log:
        def record(**fields):
            print(json.dumps({"case": label, **fields}), file=records, flush=True)

        record(kind="config", runner="ollama", model=model, backend=backend, mode="off", ollama=ollama_bin, model_path=str(model_path), seed=SEED)
        process = subprocess.Popen([ollama_bin, "serve"], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        reader = Thread(target=follow_process_log, args=(process.stdout, log))
        reader.start()
        try:
            wait_for_ollama(port, process)
            create = subprocess.run(
                [ollama_bin, "create", tag, "-f", str(modelfile)],
                env=env,
                capture_output=True,
                text=True,
                timeout=600,
                check=False,
            )
            if create.returncode != 0:
                detail = (create.stderr or create.stdout or "ollama create failed").strip()
                log.write((detail + "\n").encode("utf-8", errors="replace"))
                log.flush()
                status, reason = classify_ollama_error(detail)
                summary = {
                    "case": label,
                    "model": model,
                    "runner": "ollama",
                    "backend": backend,
                    "mode": "off",
                    "status": status,
                    "error": reason,
                }
                record(kind="summary", **{k: v for k, v in summary.items() if k != "case"})
                if emit_json:
                    print(json.dumps(summary), flush=True)
                return summary

            try:
                record(kind="warmup", **ollama_generate(port, tag, prompt_text, profile))
            except (RuntimeError, ValueError, OSError, http.client.HTTPException) as exc:
                status, reason = classify_ollama_error(str(exc))
                summary = {
                    "case": label,
                    "model": model,
                    "runner": "ollama",
                    "backend": backend,
                    "mode": "off",
                    "status": status,
                    "error": reason,
                }
                record(kind="summary", **{k: v for k, v in summary.items() if k != "case"})
                if emit_json:
                    print(json.dumps(summary), flush=True)
                return summary

            peaks: dict[str, int] = {}
            stop = Event()
            sampler = Thread(target=sample_gpu_memory, args=(stop, peaks))
            sampler.start()
            samples = []
            try:
                for number in range(1, runs + 1):
                    sample = ollama_generate(port, tag, prompt_text, profile)
                    record(kind="sample", number=number, **sample)
                    samples.append(sample)
            finally:
                stop.set()
                sampler.join()

            rates = {key: median(s[key] for s in samples) for key in ("ttft_ms", "total_ms", "prefill_tps", "decode_tps")}
            summary = {
                "case": label,
                "model": model,
                "runner": "ollama",
                "backend": backend,
                "mode": "off",
                "status": "ok",
                "medians": rates,
                "device_peak_bytes": peaks or None,
            }
            record(kind="summary", **{k: v for k, v in summary.items() if k != "case"})
            if emit_json:
                print(json.dumps(summary), flush=True)
            return summary
        finally:
            if process.poll() is None:
                with subprocess.Popen([ollama_bin, "rm", tag], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) as rm_proc:
                    try:
                        rm_proc.wait(timeout=15)
                    except subprocess.TimeoutExpired:
                        rm_proc.kill()
                process.terminate()
            try:
                process.wait(timeout=20)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            reader.join()
            if process.stdout is not None:
                process.stdout.close()
            shutil.rmtree(tmp_ollama, ignore_errors=True)


def cached_model_path(snapshot: Path, root: Path, projector: str | None) -> Path | None:
    preseed_cache = os.environ["BENCHMARK_MODELS_PRESEED_CACHE"]
    user_cache = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    hf_home = Path(os.environ.get("HF_HOME") or user_cache / "huggingface")
    hf_hub = Path(os.environ.get("HF_HUB_CACHE") or os.environ.get("HUGGINGFACE_HUB_CACHE") or hf_home / "hub")
    pattern = snapshot.relative_to("hub")
    repo, snapshots, revision, *primary_parts = pattern.parts
    primary_path = Path(*primary_parts)
    for cache in (Path(preseed_cache) / "hub", root / "huggingface/hub", hf_hub):
        repo_cache = cache / repo
        matches = {}
        for snapshot_dir in (repo_cache / snapshots).glob(revision):
            path = snapshot_dir / primary_path
            if (
                path.is_file()
                and os.access(path, os.R_OK)
                and (not projector or (snapshot_dir / projector).is_file())
            ):
                matches[snapshot_dir.name] = path
        if len(matches) > 1:
            try:
                main_revision = (repo_cache / "refs/main").read_text().rstrip("\n")
            except (OSError, UnicodeError):
                main_revision = ""
            if main_revision in matches:
                return matches[main_revision].absolute()
            raise ValueError(f"ambiguous cached model: {cache / pattern} matches {len(matches)} snapshots")
        if matches:
            return next(iter(matches.values())).absolute()
    return None


def ensure_model_path(model: str, profile: dict[str, object], root: Path) -> Path:
    snapshot = profile.get("snapshot")
    if not snapshot:
        raise RuntimeError(f"{model} is not configured for this host's video memory tier.")
    projector = profile.get("projectorPath")
    path = cached_model_path(Path(str(snapshot)), root, str(projector) if projector else None)
    if path is not None:
        return path

    hf_repo = profile.get("hfRepo")
    download_paths = profile.get("downloadPaths")
    if not hf_repo or not isinstance(download_paths, list) or not download_paths:
        raise RuntimeError(f"no readable cached GGUF for {model}: {snapshot}")

    hf_bin = shutil.which("hf")
    if not hf_bin:
        raise RuntimeError(f"no readable cached GGUF for {model} and hf CLI is unavailable")

    hf_root = root / "huggingface"
    hf_hub = hf_root / "hub"
    hf_hub.mkdir(parents=True, exist_ok=True)
    cmd = [hf_bin, "download", str(hf_repo), *[str(p) for p in download_paths]]
    if profile.get("revision"):
        cmd.extend(["--revision", str(profile["revision"])])
    env = os.environ.copy()
    env.update(
        {
            "HF_HOME": str(hf_root),
            "HF_HUB_CACHE": str(hf_hub),
            "HUGGINGFACE_HUB_CACHE": str(hf_hub),
        }
    )
    print(f"{model}: downloading into {hf_hub} (not in preseed cache)", file=sys.stderr, flush=True)
    result = subprocess.run(cmd, env=env, check=False)
    if result.returncode != 0:
        raise RuntimeError(f"hf download failed for {model} (exit {result.returncode})")

    path = cached_model_path(Path(str(snapshot)), root, str(projector) if projector else None)
    if path is None:
        raise RuntimeError(f"downloaded {model} but GGUF was not found at {snapshot}")
    return path


def format_vram(peak_bytes: int | None) -> str:
    if peak_bytes is None or peak_bytes <= 0:
        return "-"
    return f"{peak_bytes / (1024 ** 3):.1f} GiB"


def format_summary_table(results: list[dict[str, object]], runs: int) -> str:
    headers = [
        "Model",
        "Runner",
        "Backend",
        "Mode",
        "Prefill tok/s",
        "Decode tok/s",
        "TTFT ms",
        "Peak VRAM",
        "Status",
    ]
    rows: list[list[str]] = []
    for entry in results:
        status = str(entry.get("status") or "ok")
        medians = entry.get("medians") if isinstance(entry.get("medians"), dict) else None
        if status == "ok" and medians:
            prefill = f"{medians['prefill_tps']:.1f}"
            decode = f"{medians['decode_tps']:.1f}"
            ttft = f"{medians['ttft_ms']:.0f}"
            vram = format_vram(peak_vram_bytes(entry.get("device_peak_bytes")))
            status_text = "ok"
        else:
            prefill = "-"
            decode = "-"
            ttft = "-"
            vram = "-"
            err = str(entry.get("error") or "").strip()
            status_text = f"{status}: {err}" if err else status
        rows.append(
            [
                str(entry.get("model", "")),
                str(entry.get("runner", "")),
                str(entry.get("backend", "")),
                str(entry.get("mode", "off")),
                prefill,
                decode,
                ttft,
                vram,
                status_text,
            ]
        )

    widths = [len(h) for h in headers]
    for row in rows:
        for idx, cell in enumerate(row):
            widths[idx] = max(widths[idx], len(cell))

    right_align = {4, 5, 6, 7}

    def render_row(cells: list[str]) -> str:
        parts = [
            cell.rjust(widths[i]) if i in right_align else cell.ljust(widths[i])
            for i, cell in enumerate(cells)
        ]
        return "  ".join(parts).rstrip()

    lines = [
        f"Benchmark Summary (prompt={PROMPT_TOKENS} tok, output={OUTPUT_TOKENS} tok, runs={runs})",
        render_row(headers),
        render_row(["-" * w for w in widths]),
        *[render_row(row) for row in rows],
    ]

    # Build llama.cpp vs ollama deltas per (model, backend) using baseline mode=off.
    by_key: dict[tuple[str, str, str], dict[str, object]] = {}
    for entry in results:
        if entry.get("status") == "ok" and entry.get("mode") == "off":
            by_key[(str(entry["model"]), str(entry["backend"]), str(entry["runner"]))] = entry

    delta_lines: list[str] = []
    seen_pairs: set[tuple[str, str]] = set()
    for entry in results:
        pair = (str(entry["model"]), str(entry["backend"]))
        if pair in seen_pairs:
            continue
        seen_pairs.add(pair)
        llama = by_key.get((*pair, "llama.cpp"))
        ollama = by_key.get((*pair, "ollama"))
        if not llama or not ollama:
            continue
        lm = llama["medians"]
        om = ollama["medians"]
        assert isinstance(lm, dict) and isinstance(om, dict)
        dec_pct = ((lm["decode_tps"] - om["decode_tps"]) / om["decode_tps"]) * 100.0
        pre_pct = ((lm["prefill_tps"] - om["prefill_tps"]) / om["prefill_tps"]) * 100.0
        delta_lines.append(
            f"  {pair[0]} ({pair[1]}): llama.cpp vs ollama decode {dec_pct:+.1f}%, prefill {pre_pct:+.1f}%"
        )

    if delta_lines:
        lines.append("")
        lines.append("Deltas (llama.cpp vs ollama):")
        lines.extend(delta_lines)

    return "\n".join(lines)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="focused.py",
        description="Benchmark local GGUF models across llama.cpp and Ollama backends.",
    )
    parser.add_argument("items", nargs="+", help="Model name(s), optionally followed by a run count.")
    parser.add_argument("--runs", type=int, default=None, help="Measured runs per case (default: 3).")
    parser.add_argument("--llama-only", action="store_true", help="Run only llama-server cases.")
    parser.add_argument("--ollama-only", action="store_true", help="Run only Ollama cases.")
    parser.add_argument("--json", action="store_true", dest="emit_json", help="Print JSON summary lines to stdout.")
    parsed = parser.parse_args(argv)
    if parsed.llama_only and parsed.ollama_only:
        parser.error("--llama-only and --ollama-only cannot be combined")

    models = list(parsed.items)
    runs = parsed.runs
    if runs is None and len(models) >= 2 and re.fullmatch(r"0*[1-9][0-9]*", models[-1]):
        runs = int(models.pop())
    if runs is None:
        runs = 3
    if runs < 1:
        parser.error("runs must be a positive integer")
    parsed.models = models
    parsed.runs = runs
    return parsed


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    backends = os.environ.get("BENCHMARK_MODELS_BACKENDS", "").split()
    if not backends:
        print("Error: no GPU benchmark backend is configured for this host.", file=sys.stderr)
        return 1

    profiles = json.loads(os.environ["BENCHMARK_MODELS_PROFILES"])
    servers: dict[str, str] = {}
    ollamas: dict[str, str] = {}
    for backend in backends:
        if not args.ollama_only:
            server = os.environ.get(f"BENCHMARK_MODELS_{backend.upper()}_SERVER")
            if not server or not Path(server).is_file() or not os.access(server, os.X_OK):
                print(f"Error: packaged {backend} llama-server is not executable: {server}", file=sys.stderr)
                return 1
            servers[backend] = server
        if not args.llama_only:
            ollama = os.environ.get(f"BENCHMARK_MODELS_{backend.upper()}_OLLAMA")
            if ollama and Path(ollama).is_file() and os.access(ollama, os.X_OK):
                ollamas[backend] = ollama

    root = Path(os.environ.get("BENCHMARK_MODELS_ROOT") or Path.home() / "Volatile/benchmark-models")
    root.mkdir(parents=True, exist_ok=True)
    prefix = f"{args.models[0]}-" if len(args.models) == 1 else "suite-"
    output = Path(mkdtemp(prefix=prefix, dir=root))
    print(f"Results: {output}", file=sys.stderr)

    results: list[dict[str, object]] = []
    failed = False
    for model in args.models:
        profile = profiles.get(model, {})
        try:
            model_path = ensure_model_path(model, profile, root)
        except (RuntimeError, ValueError, OSError) as error:
            print(f"Error: {error}", file=sys.stderr)
            results.append(
                {
                    "model": model,
                    "runner": "all",
                    "backend": "-",
                    "mode": "-",
                    "status": "failed",
                    "error": str(error)[:80],
                }
            )
            failed = True
            continue

        draft_tokens = profile.get("mtpDraftTokens")
        widths = (0, draft_tokens, draft_tokens + 1) if draft_tokens else (0,)
        if not args.ollama_only:
            for width in widths:
                for backend, server in servers.items():
                    if width and backend not in MTP_BACKENDS:
                        continue
                    try:
                        results.append(
                            run_llama_case(output, model, model_path, backend, server, width, args.runs, profile, args.emit_json)
                        )
                    except (OSError, RuntimeError, ValueError, KeyError, http.client.HTTPException) as error:
                        print(f"{model} llama.cpp {backend} width {width}: {error}", file=sys.stderr)
                        results.append(
                            {
                                "model": model,
                                "runner": "llama.cpp",
                                "backend": backend,
                                "mode": f"mtp{width}" if width else "off",
                                "status": "failed",
                                "error": str(error).splitlines()[0][:80],
                            }
                        )
                        failed = True

        if not args.llama_only:
            for backend, ollama_bin in ollamas.items():
                try:
                    entry = run_ollama_case(output, model, model_path, backend, ollama_bin, args.runs, profile, args.emit_json)
                    results.append(entry)
                    if entry.get("status") == "failed":
                        failed = True
                except (OSError, RuntimeError, ValueError, KeyError, http.client.HTTPException) as error:
                    print(f"{model} ollama {backend}: {error}", file=sys.stderr)
                    results.append(
                        {
                            "model": model,
                            "runner": "ollama",
                            "backend": backend,
                            "mode": "off",
                            "status": "failed",
                            "error": str(error).splitlines()[0][:80],
                        }
                    )
                    failed = True

    (output / "summary.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    if not args.emit_json:
        print()
        print(format_summary_table(results, args.runs))
        print(f"\nSaved logs and JSON: {output}")
    return int(failed)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, signal.default_int_handler)
    sys.exit(main())
