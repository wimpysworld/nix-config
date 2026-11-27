"""Compare packaged llama-server and Ollama backends with the same local GGUF file."""

from __future__ import annotations

import argparse
import ast
from contextlib import contextmanager
import hashlib
import http.client
import json
import os
from pathlib import Path
from queue import Empty, Queue
import re
import secrets
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
CTX_SIZE = 8192
OLLAMA_CALIBRATION_LINES = 150
OLLAMA_PROMPT_TOLERANCE = 32
OLLAMA_PROMPT_MAX_DRIFT = 256
SEED = 42
DEVICES = {"vulkan": "Vulkan0", "rocm": "ROCm0", "cuda": "CUDA0"}
MTP_WIDTHS_BY_BACKEND: dict[str, tuple[int, ...]] = {
    "vulkan": (2, 3, 4),
    "cuda": (2, 3, 4),
    "rocm": (2, 3),
}
MTP_BACKENDS = set(MTP_WIDTHS_BY_BACKEND)
UNSUPPORTED_OLLAMA_PATTERNS = (
    "unknown model architecture",
    "unsupported architecture",
    "unsupported model",
    "not supported",
    "invalid gguf",
    "failed to load model",
)
OLLAMA_ERROR_PREFIX_RE = re.compile(
    r"^(?:"
    r"(?:/api/[a-zA-Z0-9/_-]+:\s*)?HTTP\s+\d+:\s*"
    r"|llama-server process has terminated:\s*exit status\s+\d+:\s*"
    r"|llama_model_load(?:_from_file_impl)?:\s*"
    r"|error loading model:\s*"
    r"|Error:\s*"
    r")+",
    re.IGNORECASE,
)


def build_benchmark_prompt_text(line_count: int = 400, nonce: str | None = None) -> str:
    lines = [
        f"{i:04d} {('INFO', 'ERROR', 'WARNING', 'INFO', 'INVALID')[i % 5]} "
        f"worker={i % 17} job={i * 11} elapsed_ms={(i * 137) % 999}"
        for i in range(line_count)
    ]
    task = (
        "\nWrite a Python function named summarise_log(lines) that counts INFO, WARNING "
        "and ERROR entries, ignores malformed lines and returns a dictionary. "
        "Explain the parser and provide examples and tests."
    )
    prefix = f"{nonce}\nApplication log:\n" if nonce else "Application log:\n"
    return prefix + "\n".join(lines) + task


def make_ollama_nonce(run_salt: str, step: int) -> str:
    # Vary the leading token of every request so Ollama's slot prefix KV cache
    # cannot reuse prefill state across probes, warmup, or timed samples.
    return f"{step:02d}-{run_salt}"


def mtp_widths_for_backend(
    backend: str,
    draft_tokens: int | None,
    supports_mtp: bool = False,
) -> tuple[int, ...]:
    if not (draft_tokens or supports_mtp) or backend not in MTP_WIDTHS_BY_BACKEND:
        return (0,)
    widths = set(MTP_WIDTHS_BY_BACKEND[backend])
    if draft_tokens and backend in ("vulkan", "cuda"):
        widths.add(int(draft_tokens))
    return (0, *sorted(widths))


def llama_case_matrix(
    backends: list[str],
    draft_tokens: int | None,
    supports_mtp: bool = False,
) -> list[tuple[str, int]]:
    by_backend = {
        backend: mtp_widths_for_backend(backend, draft_tokens, supports_mtp=supports_mtp)
        for backend in backends
    }
    all_widths = sorted({width for widths in by_backend.values() for width in widths})
    cases: list[tuple[str, int]] = []
    for width in all_widths:
        for backend in backends:
            if width in by_backend[backend]:
                cases.append((backend, width))
    return cases


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


def format_http_error(path: str, status: int, body: bytes) -> str:
    text = body.decode("utf-8", errors="replace").strip()
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        parsed = None
    if isinstance(parsed, dict) and isinstance(parsed.get("error"), str) and parsed["error"].strip():
        return f"{path}: HTTP {status}: {parsed['error'].strip()}"
    return f"{path}: HTTP {status}: {text}"


@contextmanager
def post(port: int, path: str, payload: dict[str, object]):
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=600)
    try:
        connection.request("POST", path, json.dumps(payload), {"Content-Type": "application/json"})
        with connection.getresponse() as response:
            if response.status != 200:
                raise RuntimeError(format_http_error(path, response.status, response.read(2048)))
            yield response
    finally:
        connection.close()


def make_prompt_with_line_estimate(port: int) -> tuple[list[int], int]:
    def tokenize(text: str, add_special: bool):
        payload = {"content": text, "add_special": add_special, "parse_special": True}
        with post(port, "/tokenize", payload) as response:
            return json.load(response)["tokens"]

    source_lines = 400
    lines = [
        f"{i:04d} {('INFO', 'ERROR', 'WARNING', 'INFO', 'INVALID')[i % 5]} "
        f"worker={i % 17} job={i * 11} elapsed_ms={(i * 137) % 999}"
        for i in range(source_lines)
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
    estimated_lines = max(1, round(source_lines * log_budget / len(log_tokens)))
    return tokens, estimated_lines


def make_prompt(port: int) -> list[int]:
    tokens, _ = make_prompt_with_line_estimate(port)
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


def ollama_batch_size(profile: dict[str, object]) -> int:
    # Ollama maps num_batch to both -b and -ub in its bundled llama-server, so
    # align with llama.cpp's physical --ubatch-size (default 512) rather than
    # its logical --batch-size 2048.
    return int(profile.get("microBatchSize") or 512)


def build_ollama_payload(
    tag: str,
    prompt_text: str,
    profile: dict[str, object],
    num_predict: int = OUTPUT_TOKENS,
) -> dict[str, object]:
    sampling = profile.get("sampling") or {}
    # Align with llama.cpp where Ollama's /api/generate supports the parameter.
    # Parameters Ollama cannot match directly:
    # - ignore_eos: not exposed by /api/generate, so runs may stop on EOS.
    # - reasoning_effort: no portable GGUF control across Ollama templates.
    # - cache_prompt=false: defeated via a unique per-call prompt prefix instead.
    options: dict[str, object] = {
        "num_ctx": CTX_SIZE,
        "num_batch": ollama_batch_size(profile),
        "num_predict": num_predict,
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
    elif profile.get("reasoning") == "off":
        payload["think"] = False
    return payload


def estimate_prompt_lines(
    target_tokens: int,
    base_tokens: int,
    probe_lines: int,
    probe_tokens: int,
) -> int:
    if probe_lines <= 0:
        raise ValueError("probe_lines must be positive")
    line_tokens = probe_tokens - base_tokens
    if line_tokens <= 0:
        raise ValueError(
            f"prompt calibration failed: {probe_lines} lines produced {probe_tokens} tokens "
            f"(base {base_tokens})"
        )
    desired_line_tokens = max(1, target_tokens - base_tokens)
    return max(1, round(probe_lines * desired_line_tokens / line_tokens))


def ollama_generate(
    port: int,
    tag: str,
    prompt_text: str,
    profile: dict[str, object],
    num_predict: int = OUTPUT_TOKENS,
    require_eval: bool = True,
):
    payload = build_ollama_payload(tag, prompt_text, profile, num_predict=num_predict)

    started = time.monotonic()
    first = None
    final_event = None
    received = started
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
    if final_event is None or (require_eval and first is None):
        raise RuntimeError("ollama generate stream ended without final timings")

    prompt_eval_count = int(final_event.get("prompt_eval_count") or 0)
    prompt_eval_ns = int(final_event.get("prompt_eval_duration") or 0)
    eval_count = int(final_event.get("eval_count") or 0)
    eval_ns = int(final_event.get("eval_duration") or 0)
    if prompt_eval_count <= 0 or prompt_eval_ns <= 0:
        raise RuntimeError(f"ollama returned incomplete prompt timings: {final_event}")
    if require_eval and (eval_count <= 0 or eval_ns <= 0):
        raise RuntimeError(f"ollama returned incomplete eval timings: {final_event}")

    first_ts = first if first is not None else received
    return {
        "ttft_ms": (first_ts - started) * 1000,
        "total_ms": (received - started) * 1000,
        "prefill_tps": prompt_eval_count / (prompt_eval_ns / 1e9),
        "decode_tps": (eval_count / (eval_ns / 1e9)) if (eval_count > 0 and eval_ns > 0) else 0.0,
        "timings": {
            "prompt_n": prompt_eval_count,
            "predicted_n": eval_count,
            "prompt_eval_duration_ns": prompt_eval_ns,
            "eval_duration_ns": eval_ns,
        },
    }


def unwrap_ollama_error_message(message: str) -> str:
    text = message.strip()
    bytes_match = re.search(r"b(['\"])(.*)\1\s*$", text, re.DOTALL)
    if bytes_match:
        try:
            decoded = ast.literal_eval(bytes_match.group(0))
            if isinstance(decoded, bytes):
                text = decoded.decode("utf-8", errors="replace").strip()
        except (SyntaxError, ValueError):
            pass

    json_start = text.find("{")
    if json_start != -1:
        try:
            parsed = json.loads(text[json_start:], strict=False)
        except json.JSONDecodeError:
            parsed = None
        if isinstance(parsed, dict) and isinstance(parsed.get("error"), str) and parsed["error"].strip():
            return parsed["error"].strip()
        # Handle HTTP error bodies truncated mid-JSON before the closing quote/brace.
        error_match = re.search(r'"error"\s*:\s*"((?:[^"\\]|\\.)*)', text[json_start:], re.DOTALL)
        if error_match and error_match.group(1).strip():
            return error_match.group(1).replace("\\n", "\n").replace('\\"', '"').strip()
    return text


def clean_ollama_error_line(line: str) -> str:
    text = line.strip()
    slog_match = re.search(r'\berror="((?:[^"\\]|\\.)*)"', text)
    if slog_match:
        text = slog_match.group(1).replace('\\"', '"')
    text = text.split("\\n", 1)[0].strip()
    text = OLLAMA_ERROR_PREFIX_RE.sub("", text).strip()
    return text


def classify_ollama_error(message: str, server_log: str = "") -> tuple[str, str]:
    unwrapped = unwrap_ollama_error_message(message)
    candidate_lines = [ln.strip() for ln in unwrapped.splitlines() if ln.strip()]
    log_lines = [ln.strip() for ln in server_log.splitlines() if ln.strip()]
    all_lines = candidate_lines + list(reversed(log_lines))

    for pattern in UNSUPPORTED_OLLAMA_PATTERNS:
        for line in all_lines:
            lowered = line.lower()
            idx = lowered.find(pattern)
            if idx != -1:
                cleaned = clean_ollama_error_line(line)
                if pattern not in cleaned.lower():
                    cleaned = line[idx:].split("\\n", 1)[0].rstrip('"').strip()
                return "unsupported", cleaned[:120]

    primary = clean_ollama_error_line(candidate_lines[0]) if candidate_lines else ""
    if not primary or primary.lower().startswith("llama-server process has terminated"):
        for line in reversed(log_lines):
            if "level=ERROR" in line or "error" in line.lower() or "failed" in line.lower():
                cleaned = clean_ollama_error_line(line)
                if cleaned and not cleaned.lower().startswith("llama-server process has terminated"):
                    primary = cleaned
                    break
    if not primary:
        primary = candidate_lines[0] if candidate_lines else "ollama failed"
    return "failed", primary[:120]


def amdgpu_memory_counters() -> list[Path]:
    counters: list[Path] = []
    for device in Path("/sys/class/drm").glob("card[0-9]*/device"):
        if device.parent.name[4:].isdigit() and (device / "driver").resolve().name == "amdgpu":
            counters.extend(device.glob("mem_info_*_used"))
    return counters


def nvidia_gpu_memory(nvidia_smi: str | None = None) -> dict[str, int]:
    binary = shutil.which("nvidia-smi") if nvidia_smi is None else nvidia_smi
    if not binary:
        return {}
    try:
        result = subprocess.run(
            [binary, "--query-gpu=index,memory.used", "--format=csv,noheader,nounits"],
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return {}
    if result.returncode != 0:
        return {}
    values: dict[str, int] = {}
    for raw_line in result.stdout.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        parts = [part.strip() for part in line.split(",")]
        if len(parts) != 2:
            continue
        index, used_mib = parts
        if not index.isdigit():
            continue
        try:
            mib = int(used_mib)
        except ValueError:
            continue
        if mib < 0:
            continue
        values[f"nvidia{index}/vram_used"] = mib * 1024 * 1024
    return values


def snapshot_gpu_memory(counters: list[Path] | None = None) -> dict[str, int]:
    active_counters = amdgpu_memory_counters() if counters is None else counters
    if not active_counters:
        return nvidia_gpu_memory() if counters is None else {}
    values: dict[str, int] = {}
    for counter in active_counters:
        key = f"{counter.parent.parent.name}/{counter.name}"
        try:
            values[key] = int(counter.read_text())
        except (OSError, ValueError):
            continue
    return values


def sample_gpu_memory(stop: Event, peaks: dict[str, int]):
    counters = amdgpu_memory_counters()
    nvidia_smi = None if counters else shutil.which("nvidia-smi")
    if not counters and not nvidia_smi:
        return
    while True:
        snapshot = snapshot_gpu_memory(counters) if counters else nvidia_gpu_memory(nvidia_smi)
        for key, value in snapshot.items():
            peaks[key] = max(peaks.get(key, 0), value)
        if stop.wait(0.2):
            return


def peak_vram_bytes(peaks: dict[str, int] | None) -> int | None:
    if not peaks:
        return None
    per_card: dict[str, dict[str, int]] = {}
    for key, value in peaks.items():
        card, _, metric = key.rpartition("/")
        if metric in ("mem_info_vram_used", "vram_used"):
            per_card.setdefault(card, {})["vram"] = value
        elif metric in ("mem_info_gtt_used", "gtt_used"):
            per_card.setdefault(card, {})["gtt"] = value
    if per_card:
        return max(metrics.get("vram", 0) + metrics.get("gtt", 0) for metrics in per_card.values())
    return max(peaks.values())


def delta_gpu_bytes(peak_bytes: int | None, baseline_bytes: int | None) -> int | None:
    if peak_bytes is None or baseline_bytes is None:
        return None
    return max(0, peak_bytes - baseline_bytes)


def run_llama_case(
    output: Path,
    model: str,
    model_path: Path,
    backend: str,
    server: str,
    width: int,
    runs: int,
    profile: dict[str, object],
    emit_json: bool,
    prompt_hints: dict[str, int] | None = None,
) -> dict[str, object]:
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
        "--ctx-size", str(CTX_SIZE),
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
        baseline_gpu_bytes = peak_vram_bytes(snapshot_gpu_memory())
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
            tokens, estimated_lines = make_prompt_with_line_estimate(port)
            if prompt_hints is not None:
                prompt_hints[model] = estimated_lines
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
            peak_bytes = peak_vram_bytes(peaks)
            summary = {
                "case": label,
                "model": model,
                "runner": "llama.cpp",
                "backend": backend,
                "mode": mode,
                "status": "ok",
                "medians": rates,
                "device_peak_bytes": peaks or None,
                "baseline_gpu_bytes": baseline_gpu_bytes,
                "peak_gpu_bytes": peak_bytes,
                "delta_gpu_bytes": delta_gpu_bytes(peak_bytes, baseline_gpu_bytes),
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


def build_ollama_env(
    backend: str,
    port: int,
    home_dir: Path,
    models_dir: Path,
    base_env: dict[str, str] | None = None,
) -> dict[str, str]:
    env = dict(os.environ if base_env is None else base_env)
    env.update(
        {
            "HOME": str(home_dir),
            "OLLAMA_HOST": f"127.0.0.1:{port}",
            "OLLAMA_MODELS": str(models_dir),
            "OLLAMA_FLASH_ATTENTION": "1",
            "OLLAMA_KV_CACHE_TYPE": "q8_0",
            "OLLAMA_NOHISTORY": "1",
            "OLLAMA_NUM_PARALLEL": "1",
            "OLLAMA_NO_CLOUD": "1",
        }
    )
    if backend == "vulkan":
        # Ollama drops integrated GPUs on Vulkan unless OLLAMA_IGPU_ENABLE=1 is set.
        env["OLLAMA_VULKAN"] = "1"
        env["OLLAMA_IGPU_ENABLE"] = "1"
    return env


def read_log_tail(log_path: Path, max_bytes: int = 16384) -> str:
    try:
        data = log_path.read_bytes()
    except OSError:
        return ""
    if len(data) > max_bytes:
        data = data[-max_bytes:]
    return data.decode("utf-8", errors="replace")


def calibrate_ollama_prompt_lines(
    port: int,
    tag: str,
    profile: dict[str, object],
    run_salt: str,
    step_counter: list[int],
    initial_lines: int | None = None,
) -> tuple[int, int]:
    def next_nonce() -> str:
        step = step_counter[0]
        step_counter[0] += 1
        return make_ollama_nonce(run_salt, step)

    base_sample = ollama_generate(
        port,
        tag,
        build_benchmark_prompt_text(0, nonce=next_nonce()),
        profile,
        num_predict=1,
        require_eval=False,
    )
    base_tokens = int(base_sample["timings"]["prompt_n"])

    probe_lines = initial_lines if initial_lines and 1 <= initial_lines <= 400 else OLLAMA_CALIBRATION_LINES
    max_safe_prompt = CTX_SIZE - OUTPUT_TOKENS
    probe_tokens = 0
    for _ in range(3):
        probe_sample = ollama_generate(
            port,
            tag,
            build_benchmark_prompt_text(probe_lines, nonce=next_nonce()),
            profile,
            num_predict=1,
            require_eval=False,
        )
        probe_tokens = int(probe_sample["timings"]["prompt_n"])
        if base_tokens < probe_tokens < max_safe_prompt:
            break
        probe_lines = max(1, probe_lines // 2)
    else:
        raise RuntimeError(
            f"ollama prompt calibration exceeded safe context limit ({probe_tokens} tokens for {probe_lines} lines)"
        )

    if abs(probe_tokens - PROMPT_TOKENS) <= OLLAMA_PROMPT_TOLERANCE:
        return probe_lines, base_tokens
    target_lines = estimate_prompt_lines(PROMPT_TOKENS, base_tokens, probe_lines, probe_tokens)
    return target_lines, base_tokens


def run_ollama_case(
    output: Path,
    model: str,
    model_path: Path,
    backend: str,
    ollama_bin: str,
    runs: int,
    profile: dict[str, object],
    emit_json: bool,
    prompt_line_hint: int | None = None,
) -> dict[str, object]:
    label = f"{model}-ollama-{backend}-off"
    port = find_free_port()
    tmp_ollama = Path(mkdtemp(prefix=f"ollama-{backend}-", dir=output))
    models_dir = tmp_ollama / "models"
    home_dir = tmp_ollama / "home"
    models_dir.mkdir(parents=True, exist_ok=True)
    home_dir.mkdir(parents=True, exist_ok=True)
    modelfile = tmp_ollama / "Modelfile"
    num_batch = ollama_batch_size(profile)
    modelfile.write_text(
        f"FROM {model_path}\nPARAMETER num_ctx {CTX_SIZE}\nPARAMETER num_batch {num_batch}\n",
        encoding="utf-8",
    )
    tag = f"benchmark-{re.sub(r'[^a-zA-Z0-9._-]', '-', model)}"
    env = build_ollama_env(backend, port, home_dir, models_dir)

    print(f"{label}: starting", file=sys.stderr, flush=True)
    log_path = output / f"{label}.log"
    run_salt = secrets.token_hex(4)
    step_counter = [0]

    def next_prompt(line_count: int) -> str:
        step = step_counter[0]
        step_counter[0] += 1
        return build_benchmark_prompt_text(line_count, nonce=make_ollama_nonce(run_salt, step))

    with (output / f"{label}.jsonl").open("x") as records, log_path.open("xb") as log:
        def record(**fields):
            print(json.dumps({"case": label, **fields}), file=records, flush=True)

        def fail_summary(detail: str) -> dict[str, object]:
            log.flush()
            status, reason = classify_ollama_error(detail, server_log=read_log_tail(log_path))
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

        record(
            kind="config",
            runner="ollama",
            model=model,
            backend=backend,
            mode="off",
            ollama=ollama_bin,
            model_path=str(model_path),
            num_ctx=CTX_SIZE,
            num_batch=num_batch,
            igpu_enable=env.get("OLLAMA_IGPU_ENABLE"),
            seed=SEED,
        )
        baseline_gpu_bytes = peak_vram_bytes(snapshot_gpu_memory())
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
                return fail_summary(detail)

            try:
                target_lines, base_tokens = calibrate_ollama_prompt_lines(
                    port,
                    tag,
                    profile,
                    run_salt,
                    step_counter,
                    initial_lines=prompt_line_hint,
                )
                warmup = ollama_generate(port, tag, next_prompt(target_lines), profile)
                record(kind="warmup", **warmup)
                warmup_prompt_n = int(warmup["timings"]["prompt_n"])
                max_safe_prompt = CTX_SIZE - OUTPUT_TOKENS
                if (
                    abs(warmup_prompt_n - PROMPT_TOKENS) > OLLAMA_PROMPT_TOLERANCE
                    and base_tokens < warmup_prompt_n < max_safe_prompt
                ):
                    target_lines = estimate_prompt_lines(PROMPT_TOKENS, base_tokens, target_lines, warmup_prompt_n)
                record(
                    kind="prompt",
                    line_count=target_lines,
                    target_tokens=PROMPT_TOKENS,
                    base_tokens=base_tokens,
                    warmup_tokens=warmup_prompt_n,
                )
            except (RuntimeError, ValueError, OSError, http.client.HTTPException) as exc:
                return fail_summary(str(exc))

            peaks: dict[str, int] = {}
            stop = Event()
            sampler = Thread(target=sample_gpu_memory, args=(stop, peaks))
            sampler.start()
            samples = []
            try:
                for number in range(1, runs + 1):
                    sample = ollama_generate(port, tag, next_prompt(target_lines), profile)
                    prompt_n = int(sample["timings"]["prompt_n"])
                    if prompt_n >= CTX_SIZE - OUTPUT_TOKENS or abs(prompt_n - PROMPT_TOKENS) > OLLAMA_PROMPT_MAX_DRIFT:
                        raise RuntimeError(
                            f"ollama prompt token count {prompt_n} drifted from target {PROMPT_TOKENS} "
                            f"(num_ctx {CTX_SIZE})"
                        )
                    record(kind="sample", number=number, **sample)
                    samples.append(sample)
            except (RuntimeError, ValueError, OSError, http.client.HTTPException) as exc:
                return fail_summary(str(exc))
            finally:
                stop.set()
                sampler.join()

            rates = {key: median(s[key] for s in samples) for key in ("ttft_ms", "total_ms", "prefill_tps", "decode_tps")}
            peak_bytes = peak_vram_bytes(peaks)
            summary = {
                "case": label,
                "model": model,
                "runner": "ollama",
                "backend": backend,
                "mode": "off",
                "status": "ok",
                "medians": rates,
                "device_peak_bytes": peaks or None,
                "baseline_gpu_bytes": baseline_gpu_bytes,
                "peak_gpu_bytes": peak_bytes,
                "delta_gpu_bytes": delta_gpu_bytes(peak_bytes, baseline_gpu_bytes),
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


def format_vram(peak_bytes: int | None, *, allow_zero: bool = False) -> str:
    if peak_bytes is None or (peak_bytes < 0 if allow_zero else peak_bytes <= 0):
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
        "Peak GPU Mem",
        "Delta GPU Mem",
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
            peak_bytes = entry.get("peak_gpu_bytes")
            if peak_bytes is None:
                peak_bytes = peak_vram_bytes(entry.get("device_peak_bytes"))
            delta_bytes = entry.get("delta_gpu_bytes")
            if delta_bytes is None and entry.get("baseline_gpu_bytes") is not None:
                delta_bytes = delta_gpu_bytes(peak_bytes, entry.get("baseline_gpu_bytes"))
            vram = format_vram(peak_bytes)
            delta_vram = format_vram(delta_bytes, allow_zero=True)
            status_text = "ok"
        else:
            prefill = "-"
            decode = "-"
            ttft = "-"
            vram = "-"
            delta_vram = "-"
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
                delta_vram,
                status_text,
            ]
        )

    widths = [len(h) for h in headers]
    for row in rows:
        for idx, cell in enumerate(row):
            widths[idx] = max(widths[idx], len(cell))

    right_align = {4, 5, 6, 7, 8}

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
        supports_mtp = bool(profile.get("supportsMtp"))
        prompt_hints: dict[str, int] = {}
        if not args.ollama_only:
            for backend, width in llama_case_matrix(list(servers), draft_tokens, supports_mtp=supports_mtp):
                server = servers[backend]
                try:
                    results.append(
                        run_llama_case(
                            output,
                            model,
                            model_path,
                            backend,
                            server,
                            width,
                            args.runs,
                            profile,
                            args.emit_json,
                            prompt_hints=prompt_hints,
                        )
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
                    entry = run_ollama_case(
                        output,
                        model,
                        model_path,
                        backend,
                        ollama_bin,
                        args.runs,
                        profile,
                        args.emit_json,
                        prompt_line_hint=prompt_hints.get(model),
                    )
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
