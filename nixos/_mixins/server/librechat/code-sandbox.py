#!/usr/bin/env python3
"""Local HTTP shim implementing the LibreChat Code Interpreter API."""

from __future__ import annotations

import base64
import contextlib
import hashlib
import json
import os
import re
import secrets
import shutil
import signal
import string
import subprocess
import threading
from datetime import UTC, datetime
from email.parser import BytesParser
from email.policy import default as email_default_policy
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path, PurePosixPath
from urllib.parse import unquote, urlsplit

ALPHABET = string.ascii_letters + string.digits
VALID_ID_CHARS = {c: c for c in (ALPHABET + "_-")}
ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{21}$")
PAYLOAD_PATTERN = re.compile(r'^(payload\s*=\s*)"([A-Za-z0-9+/=]+)"\s*$', re.MULTILINE)
SESSION_LOCKS_GUARD = threading.Lock()
SESSION_LOCKS: dict[str, threading.Lock] = {}
ACTIVE_PROCESSES_LOCK = threading.Lock()
ACTIVE_PROCESSES: dict[str, subprocess.Popen[bytes]] = {}
MAX_OUTPUT_BYTES = 1024 * 1024
MAX_REQUEST_BODY_BYTES = 50 * 1024 * 1024

STATE_DIR = Path(os.environ.get("STATE_DIR", "/var/lib/librechat-code-sandbox"))
STORAGE_DIR = STATE_DIR / "storage"
WORKSPACES_DIR = STATE_DIR / "workspaces"
EXPECTED_API_KEY = os.environ.get("LIBRECHAT_CODE_API_KEY", "").strip()


def get_session_lock(session_id: str) -> threading.Lock:
    with SESSION_LOCKS_GUARD:
        lock = SESSION_LOCKS.get(session_id)
        if lock is None:
            lock = threading.Lock()
            SESSION_LOCKS[session_id] = lock
        return lock


def now_iso() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def to_nanoid(seed: str | None = None) -> str:
    if seed:
        if ID_PATTERN.fullmatch(seed):
            return "".join(VALID_ID_CHARS[c] for c in seed)
        digest = hashlib.sha256(seed.encode()).digest()
        return base64.urlsafe_b64encode(digest).decode("ascii").rstrip("=")[:21]
    return "".join(secrets.choice(ALPHABET) for _ in range(21))


def resolve_under(base_dir: Path, *parts: str) -> Path:
    base_resolved = base_dir.resolve()
    candidate = base_resolved.joinpath(*parts).resolve()
    if candidate != base_resolved and not candidate.is_relative_to(base_resolved):
        raise ValueError("Path escapes base directory")
    return candidate


def safe_rel_path(raw_name: str) -> str:
    cleaned = raw_name.replace("\\", "/").strip()
    if cleaned.startswith("/mnt/data/"):
        cleaned = cleaned[len("/mnt/data/") :]
    cleaned = cleaned.lstrip("/")
    parts = [
        part
        for part in PurePosixPath(cleaned).parts
        if part not in ("", ".", "..", "/")
    ]
    if not parts:
        return "file"
    return "/".join(parts)


def is_executable_path(rel_path: str) -> bool:
    return (
        rel_path.startswith("scripts/")
        or "/scripts/" in f"/{rel_path}"
        or rel_path.endswith((".sh", ".py"))
    )


def should_ignore_workspace_path(rel_path: str) -> bool:
    parts = rel_path.split("/")
    return (
        "__pycache__" in parts
        or rel_path.endswith(".pyc")
        or any(part.startswith(".lc-tmp-") for part in parts)
    )


def snapshot_workspace(workspace_dir: Path) -> dict[str, tuple[int, str]]:
    snap: dict[str, tuple[int, str]] = {}
    if not workspace_dir.exists():
        return snap
    for path in workspace_dir.rglob("*"):
        if not path.is_file() or path.is_symlink():
            continue
        rel_path = path.relative_to(workspace_dir).as_posix()
        if should_ignore_workspace_path(rel_path):
            continue
        try:
            data = path.read_bytes()
        except OSError:
            continue
        digest = hashlib.sha256(data).hexdigest()
        snap[rel_path] = (len(data), digest)
    return snap


def save_storage_object(
    session_id: str,
    file_id: str,
    filename: str,
    data: bytes,
    *,
    read_only: bool = False,
    kind: str = "user",
    resource_id: str = "",
    version: int | None = None,
) -> dict[str, object]:
    session_dir = resolve_under(STORAGE_DIR, session_id)
    session_dir.mkdir(parents=True, exist_ok=True)
    blob_path = resolve_under(session_dir, file_id)
    meta_path = resolve_under(session_dir, f"{file_id}.json")
    blob_path.write_bytes(data)
    meta: dict[str, object] = {
        "fileId": file_id,
        "originalFilename": filename,
        "lastModified": now_iso(),
        "bytes": len(data),
        "readOnly": read_only,
        "kind": kind,
        "resourceId": resource_id,
    }
    if version is not None:
        meta["version"] = version
    meta_path.write_text(json.dumps(meta), encoding="utf-8")
    return meta


def load_storage_meta(session_id: str, file_id: str) -> dict[str, object] | None:
    if not ID_PATTERN.fullmatch(session_id) or not ID_PATTERN.fullmatch(file_id):
        return None
    meta_path = resolve_under(STORAGE_DIR, session_id, f"{file_id}.json")
    blob_path = resolve_under(STORAGE_DIR, session_id, file_id)
    if not meta_path.is_file() or not blob_path.is_file():
        return None
    try:
        return json.loads(meta_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def rewrite_mnt_data_in_code(code: str, workspace_dir: Path) -> str:
    ws_str = str(workspace_dir)

    def replace_payload(match: re.Match[str]) -> str:
        prefix, b64_str = match.group(1), match.group(2)
        try:
            decoded = json.loads(base64.b64decode(b64_str).decode("utf-8"))
        except (ValueError, TypeError):
            return match.group(0)
        if isinstance(decoded, dict) and isinstance(decoded.get("file_path"), str):
            fp = decoded["file_path"]
            if fp == "/mnt/data":
                decoded["file_path"] = ws_str
            elif fp.startswith("/mnt/data/"):
                decoded["file_path"] = f"{ws_str}/{fp[len('/mnt/data/'):]}"
            new_b64 = base64.b64encode(json.dumps(decoded).encode()).decode("ascii")
            return f'{prefix}"{new_b64}"'
        return match.group(0)

    updated = PAYLOAD_PATTERN.sub(replace_payload, code)
    updated = updated.replace("/mnt/data/", f"{ws_str}/")
    return re.sub(r"/mnt/data(?![A-Za-z0-9_.-])", ws_str, updated)


def build_bwrap_cmd(cmd: list[str]) -> list[str] | None:
    bwrap = shutil.which("bwrap")
    if not bwrap:
        return None
    return [
        bwrap,
        "--unshare-all",
        "--die-with-parent",
        "--ro-bind",
        "/nix/store",
        "/nix/store",
        "--ro-bind-try",
        "/bin",
        "/bin",
        "--ro-bind-try",
        "/usr",
        "/usr",
        "--ro-bind-try",
        "/etc",
        "/etc",
        "--ro-bind-try",
        "/run/current-system",
        "/run/current-system",
        "--dev",
        "/dev",
        "--proc",
        "/proc",
        "--tmpfs",
        "/tmp",  # noqa: S108
        "--bind",
        ".",
        "/mnt/data",
        "--chdir",
        "/mnt/data",
        "--",
        *cmd,
    ]


def _terminate_process_group(proc: subprocess.Popen[bytes]) -> None:
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except OSError:
        with contextlib.suppress(OSError):
            proc.kill()


def _run_process_bounded(
    cmd: list[str],
    workspace_dir: Path,
    env: dict[str, str],
    timeout_sec: float,
    tracking_keys: tuple[str, ...] = (),
) -> tuple[subprocess.CompletedProcess[str], bool]:
    stdout_chunks: list[bytes] = []
    stderr_chunks: list[bytes] = []
    stdout_bytes = 0
    stderr_bytes = 0
    overflow = False

    def drain_stream(stream: object, chunks: list[bytes], *, is_stdout: bool) -> None:
        nonlocal stdout_bytes, stderr_bytes, overflow
        if stream is None:
            return
        read_fn = getattr(stream, "read", None)
        if read_fn is None:
            return
        while True:
            chunk = read_fn(65536)
            if not chunk:
                break
            current = stdout_bytes if is_stdout else stderr_bytes
            remaining = MAX_OUTPUT_BYTES - current
            if remaining > 0:
                if len(chunk) <= remaining:
                    chunks.append(chunk)
                    current += len(chunk)
                else:
                    chunks.append(chunk[:remaining])
                    current += remaining
                    overflow = True
                if is_stdout:
                    stdout_bytes = current
                else:
                    stderr_bytes = current
            else:
                overflow = True

    proc = subprocess.Popen(  # codeql[py/command-line-injection] # lgtm[py/command-line-injection]
        cmd,
        cwd=str(workspace_dir),
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        start_new_session=True,
    )
    if tracking_keys:
        with ACTIVE_PROCESSES_LOCK:
            for key in tracking_keys:
                if key:
                    ACTIVE_PROCESSES[key] = proc
    t_out = threading.Thread(
        target=drain_stream, args=(proc.stdout, stdout_chunks), kwargs={"is_stdout": True}, daemon=True
    )
    t_err = threading.Thread(
        target=drain_stream, args=(proc.stderr, stderr_chunks), kwargs={"is_stdout": False}, daemon=True
    )
    t_out.start()
    t_err.start()
    try:
        returncode = proc.wait(timeout=timeout_sec)
    except subprocess.TimeoutExpired:
        _terminate_process_group(proc)
        with contextlib.suppress(Exception):
            proc.wait(timeout=5)
        t_out.join(timeout=2)
        t_err.join(timeout=2)
        raise subprocess.TimeoutExpired(
            cmd=cmd,
            timeout=timeout_sec,
            output=b"".join(stdout_chunks).decode("utf-8", errors="replace"),
            stderr=b"".join(stderr_chunks).decode("utf-8", errors="replace"),
        ) from None
    finally:
        if tracking_keys:
            with ACTIVE_PROCESSES_LOCK:
                for key in tracking_keys:
                    if ACTIVE_PROCESSES.get(key) is proc:
                        ACTIVE_PROCESSES.pop(key, None)
        t_out.join(timeout=2)
        t_err.join(timeout=2)
        if proc.stdout is not None:
            with contextlib.suppress(OSError):
                proc.stdout.close()
        if proc.stderr is not None:
            with contextlib.suppress(OSError):
                proc.stderr.close()

    completed = subprocess.CompletedProcess(
        args=cmd,
        returncode=returncode,
        stdout=b"".join(stdout_chunks).decode("utf-8", errors="replace"),
        stderr=b"".join(stderr_chunks).decode("utf-8", errors="replace"),
    )
    return completed, overflow


def run_sandboxed(
    cmd: list[str],
    workspace_dir: Path,
    env: dict[str, str],
    timeout_sec: float,
    tracking_keys: tuple[str, ...] = (),
    on_fallback: object = None,
) -> tuple[subprocess.CompletedProcess[str], bool]:
    bwrap_cmd = build_bwrap_cmd(cmd)
    if bwrap_cmd is not None:
        bwrap_env = env.copy()
        bwrap_env["HOME"] = "/mnt/data"
        bwrap_env["LIBRECHAT_CODE_DATA_DIR"] = "/mnt/data"
        proc, overflow = _run_process_bounded(
            bwrap_cmd, workspace_dir, bwrap_env, timeout_sec, tracking_keys
        )
        if not (proc.returncode != 0 and "bwrap:" in proc.stderr):
            return proc, overflow
        if callable(on_fallback):
            on_fallback()
    return _run_process_bounded(
        cmd, workspace_dir, env, timeout_sec, tracking_keys
    )


def execute_code_request(
    body: dict[str, object],
    *,
    programmatic: bool = False,
    request_id: str | None = None,
) -> dict[str, object]:
    raw_lang = str(body.get("lang") or ("bash" if programmatic else "py")).lower().strip()
    code = str(body.get("code") or "")
    raw_args = body.get("args")
    args = [str(a) for a in raw_args] if isinstance(raw_args, list) else []
    raw_session = body.get("session_id") or body.get("runtime_session_hint")
    raw_session_str = str(raw_session).strip() if raw_session else ""
    session_id = to_nanoid(raw_session_str if raw_session_str else None)
    effective_request_id = (
        request_id or str(body.get("request_id") or "").strip() or None
    )
    tracking_keys = tuple(
        dict.fromkeys(
            key
            for key in (effective_request_id, raw_session_str, session_id)
            if key
        )
    )

    raw_timeout = body.get("timeout")
    timeout_sec = 120.0
    if isinstance(raw_timeout, (int, float)) and raw_timeout > 0:
        try:
            parsed_timeout = float(raw_timeout)
            timeout_sec = (
                parsed_timeout / 1000.0 if parsed_timeout > 300 else parsed_timeout
            )
            timeout_sec = min(max(timeout_sec, 1.0), 300.0)
        except (ValueError, TypeError):
            timeout_sec = 120.0

    workspace_dir = resolve_under(WORKSPACES_DIR, session_id)
    with get_session_lock(session_id):
        workspace_dir.mkdir(parents=True, exist_ok=True)
        resolve_under(STORAGE_DIR, session_id).mkdir(parents=True, exist_ok=True)

        readonly_paths: set[str] = set()
        injected_files = body.get("files")
        if isinstance(injected_files, list):
            for entry in injected_files:
                if not isinstance(entry, dict):
                    continue
                raw_id = entry.get("id")
                raw_name = entry.get("name")
                if not isinstance(raw_id, str) or not isinstance(raw_name, str):
                    continue
                raw_storage_sid = entry.get("storage_session_id")
                storage_sid = to_nanoid(
                    str(raw_storage_sid)
                    if isinstance(raw_storage_sid, str) and raw_storage_sid
                    else session_id
                )
                file_id = to_nanoid(raw_id)
                src_blob = resolve_under(STORAGE_DIR, storage_sid, file_id)
                if not src_blob.is_file():
                    continue
                rel_path = safe_rel_path(raw_name)
                try:
                    dest_path = resolve_under(workspace_dir, rel_path)
                except ValueError:
                    continue
                dest_path.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(src_blob, dest_path)
                if is_executable_path(rel_path):
                    with contextlib.suppress(OSError):
                        dest_path.chmod(0o755)
                meta = load_storage_meta(storage_sid, file_id)
                if (
                    entry.get("kind") == "skill"
                    or (meta is not None and bool(meta.get("readOnly")))
                    or rel_path.startswith("skills/")
                ):
                    readonly_paths.add(rel_path)

        before_snap = snapshot_workspace(workspace_dir)
        rewritten_code = rewrite_mnt_data_in_code(code, workspace_dir)
        rewritten_args = [
            rewrite_mnt_data_in_code(a, workspace_dir) for a in args
        ]
        use_bwrap = shutil.which("bwrap") is not None
        effective_code = code if use_bwrap else rewritten_code
        effective_args = args if use_bwrap else rewritten_args

        if raw_lang in ("bash", "sh"):
            cmd = [
                "bash",
                "-c",
                'eval "set -- $(python3 -c \'import json, shlex; print(" ".join(shlex.quote(a) for a in json.load(open(".lc-tmp-args.json"))))\')" && source ./.lc-tmp-script',
            ]
        elif raw_lang in ("py", "python"):
            cmd = [
                "python3",
                "-c",
                'import json, sys; sys.argv = ["-c", *json.load(open(".lc-tmp-args.json"))]; exec(compile(open(".lc-tmp-script", "rb").read(), "<string>", "exec"), {"__name__": "__main__"})',
            ]
        elif raw_lang in ("js", "javascript", "ts", "typescript"):
            cmd = [
                "node",
                "-e",
                'const fs = require("fs"); process.argv = [process.execPath, ...JSON.parse(fs.readFileSync(".lc-tmp-args.json", "utf8"))]; eval(fs.readFileSync(".lc-tmp-script", "utf8"));',
            ]
        else:
            cmd = None

        env = os.environ.copy()
        env["HOME"] = str(workspace_dir)
        env["LIBRECHAT_CODE_DATA_DIR"] = str(workspace_dir)
        env["PYTHONDONTWRITEBYTECODE"] = "1"

        stdout = ""
        stderr = ""
        returncode = 0
        overflow = False
        if cmd is None:
            stderr = f"Unsupported language runtime: {raw_lang}\n"
            returncode = 1
        else:
            script_path = resolve_under(workspace_dir, ".lc-tmp-script")
            args_path = resolve_under(workspace_dir, ".lc-tmp-args.json")

            def write_fallback_inputs() -> None:
                script_path.write_text(rewritten_code, encoding="utf-8")
                args_path.write_text(
                    json.dumps(rewritten_args), encoding="utf-8"
                )

            try:
                script_path.write_text(effective_code, encoding="utf-8")
                args_path.write_text(
                    json.dumps(effective_args), encoding="utf-8"
                )
                proc, overflow = run_sandboxed(
                    cmd,
                    workspace_dir,
                    env,
                    timeout_sec,
                    tracking_keys,
                    on_fallback=write_fallback_inputs,
                )
                stdout = proc.stdout
                stderr = proc.stderr
                returncode = proc.returncode
            except subprocess.TimeoutExpired as exc:
                raw_out = exc.stdout
                raw_err = exc.stderr
                stdout = (
                    raw_out.decode("utf-8", errors="replace")
                    if isinstance(raw_out, bytes)
                    else (raw_out or "")
                )
                err_prefix = (
                    raw_err.decode("utf-8", errors="replace")
                    if isinstance(raw_err, bytes)
                    else (raw_err or "")
                )
                stderr = f"{err_prefix}\nExecution timed out.\n"
                returncode = 124
            except OSError as exc:
                stderr = f"Execution failed: {exc}\n"
                returncode = 1
            finally:
                with contextlib.suppress(OSError):
                    script_path.unlink(missing_ok=True)
                with contextlib.suppress(OSError):
                    args_path.unlink(missing_ok=True)

        after_snap = snapshot_workspace(workspace_dir)

        deleted_files: list[str] = []
        for rel_path in sorted(before_snap.keys() - after_snap.keys()):
            if rel_path in readonly_paths:
                continue
            deleted_files.append(rel_path)
            file_id = to_nanoid(f"{session_id}:{rel_path}")
            for candidate in (
                resolve_under(STORAGE_DIR, session_id, file_id),
                resolve_under(STORAGE_DIR, session_id, f"{file_id}.json"),
            ):
                with contextlib.suppress(OSError):
                    candidate.unlink(missing_ok=True)

        out_files: list[dict[str, object]] = []
        if returncode == 0:
            for rel_path, after_state in sorted(after_snap.items()):
                if rel_path in readonly_paths:
                    continue
                before_state = before_snap.get(rel_path)
                if before_state == after_state:
                    continue
                file_path = resolve_under(workspace_dir, rel_path)
                try:
                    data = file_path.read_bytes()
                except OSError:
                    continue
                file_id = to_nanoid(f"{session_id}:{rel_path}")
                save_storage_object(
                    session_id,
                    file_id,
                    rel_path,
                    data,
                    read_only=False,
                    kind="user",
                )
                out_files.append(
                    {
                        "id": file_id,
                        "name": rel_path,
                        "storage_session_id": session_id,
                    }
                )

    response: dict[str, object] = {
        "stdout": stdout,
        "stderr": stderr,
        "session_id": session_id,
        "runtime_session_id": session_id,
        "runtime_status": "active",
        "files": out_files,
        "deleted_files": deleted_files,
    }
    if programmatic:
        response["status"] = "completed"
    elif overflow:
        response["status"] = "OL"
    return response


class SandboxHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format: str, *args: object) -> None:  # noqa: A002
        return

    def check_auth(self) -> bool:
        if not EXPECTED_API_KEY:
            return True
        provided = (
            self.headers.get("X-Api-Key") or self.headers.get("x-api-key") or ""
        ).strip()
        if not provided:
            auth_header = (self.headers.get("Authorization") or "").strip()
            if auth_header.lower().startswith("bearer "):
                provided = auth_header[7:].strip()
        if provided and secrets.compare_digest(provided, EXPECTED_API_KEY):
            return True
        self.send_json(401, {"error": "Unauthorized"})
        return False

    def read_request_body(self) -> bytes:
        transfer_encoding = (self.headers.get("Transfer-Encoding") or "").lower()
        if "chunked" in transfer_encoding:
            chunks: list[bytes] = []
            total = 0
            while True:
                line = self.rfile.readline(65536)
                if not line:
                    break
                size_str = line.split(b";", 1)[0].strip()
                if not size_str:
                    continue
                try:
                    size = int(size_str, 16)
                except ValueError:
                    break
                if size < 0:
                    break
                if size == 0:
                    while True:
                        trailer = self.rfile.readline(65536)
                        if not trailer or trailer in (b"\r\n", b"\n"):
                            break
                    break
                if total + size > MAX_REQUEST_BODY_BYTES:
                    raise ValueError("Request body exceeds maximum size")
                data = self.rfile.read(size)
                total += len(data)
                chunks.append(data)
                self.rfile.readline(65536)
            return b"".join(chunks)
        raw_len = self.headers.get("Content-Length") or "0"
        try:
            length = int(raw_len)
        except ValueError:
            length = 0
        if length > MAX_REQUEST_BODY_BYTES:
            raise ValueError("Request body exceeds maximum size")
        return self.rfile.read(length) if length > 0 else b""

    def send_json(self, status: int, payload: object) -> None:
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)
        self.close_connection = True

    def send_bytes(
        self, status: int, data: bytes, filename: str | None = None
    ) -> None:
        self.send_response(status)
        self.send_header("Content-Type", "application/octet-stream")
        if filename:
            safe_name = (
                re.sub(r"[^A-Za-z0-9._-]", "_", os.path.basename(filename))
                .replace("\r", "")
                .replace("\n", "")
            )
            self.send_header(
                "Content-Disposition", f'attachment; filename="{safe_name}"'
            )
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(data)
        self.close_connection = True

    def handle_upload(self, *, batch: bool) -> None:
        content_type = self.headers.get("Content-Type") or ""
        if "multipart/form-data" not in content_type:
            self.send_json(
                400, {"message": "error", "error": "Expected multipart/form-data"}
            )
            return
        try:
            raw_body = self.read_request_body()
        except ValueError as exc:
            self.send_json(413, {"message": "error", "error": str(exc)})
            return
        raw_msg = (
            f"Content-Type: {content_type}\r\nMIME-Version: 1.0\r\n\r\n".encode()
            + raw_body
        )
        msg = BytesParser(policy=email_default_policy).parsebytes(raw_msg)

        fields: dict[str, str] = {}
        uploaded_parts: list[tuple[str, bytes]] = []
        for part in msg.iter_parts():
            field_name = part.get_param("name", header="content-disposition")
            filename = part.get_filename()
            payload = part.get_payload(decode=True)
            if not isinstance(payload, bytes):
                continue
            if filename is not None or field_name == "file":
                clean_name = safe_rel_path(filename or "file")
                uploaded_parts.append((clean_name, payload))
            elif isinstance(field_name, str):
                fields[field_name] = payload.decode(
                    "utf-8", errors="replace"
                ).strip()

        user_id = (self.headers.get("User-Id") or "default").strip()
        kind = fields.get("kind") or "user"
        resource_id = fields.get("id") or user_id
        version_raw = fields.get("version")
        version: int | None = None
        if version_raw:
            try:
                version = int(version_raw)
            except ValueError:
                version = None
        read_only = fields.get("read_only", "").lower() == "true" or kind == "skill"

        if kind in ("skill", "agent") or fields.get("id"):
            seed = f"{user_id}:{kind}:{resource_id}:{version if version is not None else ''}"
            storage_session_id = to_nanoid(seed)
        else:
            storage_session_id = to_nanoid()

        saved_files: list[dict[str, str]] = []
        for filename, data in uploaded_parts:
            file_id = to_nanoid(f"{storage_session_id}:{filename}")
            save_storage_object(
                storage_session_id,
                file_id,
                filename,
                data,
                read_only=read_only,
                kind=kind,
                resource_id=resource_id,
                version=version,
            )
            saved_files.append({"fileId": file_id, "filename": filename})

        if batch:
            self.send_json(
                200,
                {
                    "message": "success",
                    "storage_session_id": storage_session_id,
                    "succeeded": len(saved_files),
                    "failed": 0,
                    "files": [
                        {
                            "status": "success",
                            "fileId": item["fileId"],
                            "filename": item["filename"],
                        }
                        for item in saved_files
                    ],
                },
            )
        else:
            self.send_json(
                200,
                {
                    "message": "success",
                    "storage_session_id": storage_session_id,
                    "files": saved_files,
                },
            )

    def do_GET(self) -> None:
        parsed = urlsplit(self.path)
        segments = [unquote(seg) for seg in parsed.path.strip("/").split("/") if seg]

        if segments == ["health"]:
            self.send_json(200, {"status": "ok"})
            return

        if not self.check_auth():
            return

        if len(segments) == 2 and segments[0] == "files":
            session_id = to_nanoid(segments[1])
            session_dir = resolve_under(STORAGE_DIR, session_id)
            items: list[dict[str, object]] = []
            if session_dir.is_dir():
                for meta_file in sorted(session_dir.glob("*.json")):
                    try:
                        meta = json.loads(meta_file.read_text(encoding="utf-8"))
                    except (OSError, json.JSONDecodeError):
                        continue
                    file_id = str(meta.get("fileId") or meta_file.stem)
                    orig_name = str(meta.get("originalFilename") or file_id)
                    items.append(
                        {
                            "fileId": file_id,
                            "id": file_id,
                            "name": orig_name,
                            "storage_session_id": session_id,
                            "metadata": {"original-filename": orig_name},
                            "lastModified": meta.get("lastModified") or now_iso(),
                        }
                    )
            self.send_json(200, items)
            return

        if (
            len(segments) == 4
            and segments[0] == "sessions"
            and segments[2] == "objects"
        ):
            session_id = to_nanoid(segments[1])
            file_id = to_nanoid(segments[3])
            meta = load_storage_meta(session_id, file_id)
            if meta is None:
                self.send_json(404, {"error": "Not found"})
                return
            self.send_json(
                200,
                {
                    "lastModified": meta.get("lastModified") or now_iso(),
                    "originalFilename": meta.get("originalFilename") or file_id,
                },
            )
            return

        if len(segments) == 3 and segments[0] == "download":
            session_id = to_nanoid(segments[1])
            file_id = to_nanoid(segments[2])
            meta = load_storage_meta(session_id, file_id)
            blob_path = resolve_under(STORAGE_DIR, session_id, file_id)
            if meta is None or not blob_path.is_file():
                self.send_json(404, {"error": "Not found"})
                return
            self.send_bytes(
                200,
                blob_path.read_bytes(),
                str(meta.get("originalFilename") or file_id),
            )
            return

        self.send_json(404, {"error": "Not found"})

    def do_POST(self) -> None:
        if not self.check_auth():
            return
        parsed = urlsplit(self.path)
        path = parsed.path.rstrip("/") or "/"

        if path in ("/exec", "/exec/programmatic"):
            try:
                raw_body = self.read_request_body()
            except ValueError as exc:
                self.send_json(413, {"error": str(exc)})
                return
            try:
                body = json.loads(raw_body.decode("utf-8")) if raw_body else {}
            except json.JSONDecodeError:
                self.send_json(400, {"error": "Invalid JSON"})
                return
            if not isinstance(body, dict):
                self.send_json(400, {"error": "Expected JSON object"})
                return
            req_id = (
                self.headers.get("X-LibreChat-Code-Request-ID")
                or self.headers.get("x-librechat-code-request-id")
                or ""
            ).strip() or None
            self.send_json(
                200,
                execute_code_request(
                    body,
                    programmatic=(path == "/exec/programmatic"),
                    request_id=req_id,
                ),
            )
            return

        if path == "/exec/programmatic/cancel":
            try:
                raw_body = self.read_request_body()
            except ValueError as exc:
                self.send_json(413, {"error": str(exc)})
                return
            body: dict[str, object] = {}
            if raw_body:
                try:
                    parsed_body = json.loads(raw_body.decode("utf-8"))
                except (json.JSONDecodeError, UnicodeDecodeError):
                    parsed_body = None
                if isinstance(parsed_body, dict):
                    body = parsed_body
            header_req_id = (
                self.headers.get("X-LibreChat-Code-Request-ID")
                or self.headers.get("x-librechat-code-request-id")
                or ""
            ).strip()
            body_req_id = str(body.get("request_id") or "").strip()
            raw_session = str(
                body.get("session_id") or body.get("runtime_session_hint") or ""
            ).strip()
            lookup_keys = [
                key
                for key in (
                    header_req_id,
                    body_req_id,
                    raw_session,
                    to_nanoid(raw_session) if raw_session else "",
                )
                if key
            ]
            targets: list[subprocess.Popen[bytes]] = []
            with ACTIVE_PROCESSES_LOCK:
                if lookup_keys:
                    seen_ids: set[int] = set()
                    for key in lookup_keys:
                        proc = ACTIVE_PROCESSES.get(key)
                        if proc is not None and id(proc) not in seen_ids:
                            seen_ids.add(id(proc))
                            targets.append(proc)
            for proc in targets:
                _terminate_process_group(proc)
            self.send_json(200, {"status": "cancelled"})
            return

        if path == "/upload":
            self.handle_upload(batch=False)
            return

        if path == "/upload/batch":
            self.handle_upload(batch=True)
            return

        self.send_json(404, {"error": "Not found"})

    def do_DELETE(self) -> None:
        if not self.check_auth():
            return
        parsed = urlsplit(self.path)
        segments = [unquote(seg) for seg in parsed.path.strip("/").split("/") if seg]

        if (len(segments) == 3 and segments[0] == "files") or (
            len(segments) == 4
            and segments[0] == "sessions"
            and segments[2] == "objects"
        ):
            session_id = to_nanoid(segments[1])
            file_id = to_nanoid(segments[-1])
            for candidate in (
                resolve_under(STORAGE_DIR, session_id, file_id),
                resolve_under(STORAGE_DIR, session_id, f"{file_id}.json"),
            ):
                with contextlib.suppress(OSError):
                    candidate.unlink(missing_ok=True)
            self.send_json(200, {"message": "deleted"})
            return

        self.send_json(404, {"error": "Not found"})


def main() -> None:
    STORAGE_DIR.mkdir(parents=True, exist_ok=True)
    WORKSPACES_DIR.mkdir(parents=True, exist_ok=True)
    host = os.environ.get("HOST", "127.0.0.1")
    raw_port = os.environ.get("PORT", "3082")
    try:
        port = int(raw_port)
    except ValueError:
        port = 3082
    server = ThreadingHTTPServer((host, port), SandboxHandler)
    server.serve_forever()


if __name__ == "__main__":
    main()
