#!/usr/bin/env python3
"""Local HTTP shim implementing the LibreChat Code Interpreter API."""

from __future__ import annotations

import base64
import contextlib
import grp
import hashlib
import json
import math
import os
import pwd
import re
import secrets
import shutil
import signal
import string
import subprocess
import threading
import time
from datetime import UTC, datetime
from email.parser import BytesParser
from email.policy import default as email_default_policy
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path, PurePosixPath
from urllib.parse import unquote, urlsplit

try:
    from cryptography.exceptions import InvalidSignature
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
    from cryptography.hazmat.primitives.serialization import load_pem_public_key
except ImportError:
    InvalidSignature = Exception  # type: ignore[assignment,misc]
    Ed25519PublicKey = None  # type: ignore[assignment,misc]
    load_pem_public_key = None  # type: ignore[assignment]

ALPHABET = string.ascii_letters + string.digits
VALID_ID_CHARS = {c: c for c in (ALPHABET + "_-")}
ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{21}$")
B64URL_PATTERN = re.compile(r"^[A-Za-z0-9_-]+$")
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
USERS_DIR = STATE_DIR / "users"
SESSIONS_DIR = STATE_DIR / "sessions"
EXPECTED_API_KEY = os.environ.get("LIBRECHAT_CODE_API_KEY", "").strip()
JWT_PUBLIC_KEY_PEM = os.environ.get("CODEAPI_JWT_PUBLIC_KEY", "").strip()
JWT_PUBLIC_KEY_FILE = os.environ.get("CODEAPI_JWT_PUBLIC_KEY_FILE", "").strip()
EXPECTED_JWT_ISSUER = os.environ.get("CODEAPI_JWT_ISSUER", "librechat").strip() or "librechat"
EXPECTED_JWT_AUDIENCE = os.environ.get("CODEAPI_JWT_AUDIENCE", "codeapi").strip() or "codeapi"
JWT_CLOCK_SKEW_SEC = 30.0
_JWT_KEY_LOCK = threading.Lock()
_JWT_KEY_CACHE_STAT: tuple[int, int, int] | None = None
_JWT_KEY_CACHE_VALUE: Ed25519PublicKey | None = None
_JWT_INLINE_CACHE_RAW: str = ""
_JWT_INLINE_CACHE_VALUE: Ed25519PublicKey | None = None
ALLOWED_INHERITED_ENV_VARS = (
    "PATH",
    "LANG",
    "LC_ALL",
    "TZ",
    "SSL_CERT_FILE",
    "REQUESTS_CA_BUNDLE",
    "FONTCONFIG_FILE",
    "FONTCONFIG_PATH",
)
USER_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
IGNORED_DIR_NAMES = frozenset(
    {
        ".cache",
        ".config",
        ".local",
        ".npm",
        ".git",
        "__pycache__",
        ".pytest_cache",
        ".ruff_cache",
        ".mypy_cache",
        ".venv",
        "node_modules",
        "target",
    }
)
SANDBOX_CACHE_MOUNT = "/var/cache/sandbox"
SANDBOX_TMPFS_SIZE_BYTES = "4294967296"
_RUNTIME_ETC_LOCK = threading.Lock()
FALLBACK_ETC_PATHS = (
    "/etc/hosts",
    "/etc/resolv.conf",
    "/etc/nsswitch.conf",
    "/etc/protocols",
    "/etc/services",
    "/etc/ssl",
    "/etc/localtime",
    "/etc/zoneinfo",
    "/etc/fonts",
)


def jwt_auth_configured() -> bool:
    return bool(JWT_PUBLIC_KEY_PEM or JWT_PUBLIC_KEY_FILE)


def _parse_ed25519_public_key(pem_bytes: bytes) -> Ed25519PublicKey | None:
    if load_pem_public_key is None or Ed25519PublicKey is None:
        return None
    try:
        key = load_pem_public_key(pem_bytes)
    except (ValueError, TypeError):
        return None
    return key if isinstance(key, Ed25519PublicKey) else None


def load_jwt_public_key() -> Ed25519PublicKey | None:
    global _JWT_KEY_CACHE_STAT, _JWT_KEY_CACHE_VALUE
    global _JWT_INLINE_CACHE_RAW, _JWT_INLINE_CACHE_VALUE

    if JWT_PUBLIC_KEY_PEM:
        with _JWT_KEY_LOCK:
            if JWT_PUBLIC_KEY_PEM == _JWT_INLINE_CACHE_RAW and _JWT_INLINE_CACHE_VALUE is not None:
                return _JWT_INLINE_CACHE_VALUE
            normalised = JWT_PUBLIC_KEY_PEM.replace("\\n", "\n").strip().encode("utf-8")
            parsed = _parse_ed25519_public_key(normalised)
            _JWT_INLINE_CACHE_RAW = JWT_PUBLIC_KEY_PEM
            _JWT_INLINE_CACHE_VALUE = parsed
            return parsed

    if not JWT_PUBLIC_KEY_FILE:
        return None

    key_path = Path(JWT_PUBLIC_KEY_FILE)
    with _JWT_KEY_LOCK:
        try:
            st = key_path.stat()
        except OSError:
            _JWT_KEY_CACHE_STAT = None
            _JWT_KEY_CACHE_VALUE = None
            return None
        stat_key = (st.st_ino, st.st_mtime_ns, st.st_size)
        if _JWT_KEY_CACHE_STAT == stat_key and _JWT_KEY_CACHE_VALUE is not None:
            return _JWT_KEY_CACHE_VALUE
        try:
            pem_bytes = key_path.read_bytes()
        except OSError:
            _JWT_KEY_CACHE_STAT = None
            _JWT_KEY_CACHE_VALUE = None
            return None
        parsed = _parse_ed25519_public_key(pem_bytes)
        if parsed is None:
            _JWT_KEY_CACHE_STAT = None
            _JWT_KEY_CACHE_VALUE = None
            return None
        _JWT_KEY_CACHE_STAT = stat_key
        _JWT_KEY_CACHE_VALUE = parsed
        return parsed


def _b64url_decode(segment: str) -> bytes | None:
    if not segment or not B64URL_PATTERN.fullmatch(segment):
        return None
    padding = "=" * (-len(segment) % 4)
    try:
        return base64.urlsafe_b64decode(segment + padding)
    except (ValueError, TypeError):
        return None


def _is_finite_number(value: object) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def verify_jwt_token(token: str, now_ts: float | None = None) -> tuple[str, str] | None:
    parts = token.split(".")
    if len(parts) != 3:
        return None
    header_b64, payload_b64, sig_b64 = parts
    header_bytes = _b64url_decode(header_b64)
    payload_bytes = _b64url_decode(payload_b64)
    sig_bytes = _b64url_decode(sig_b64)
    if header_bytes is None or payload_bytes is None or sig_bytes is None:
        return None

    try:
        header = json.loads(header_bytes.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return None
    if not isinstance(header, dict) or header.get("alg") != "EdDSA":
        return None
    typ = header.get("typ")
    if typ is not None and (not isinstance(typ, str) or typ.upper() != "JWT"):
        return None

    public_key = load_jwt_public_key()
    if public_key is None:
        return None

    signing_input = f"{header_b64}.{payload_b64}".encode("ascii")
    try:
        public_key.verify(sig_bytes, signing_input)
    except (InvalidSignature, ValueError, TypeError):
        return None

    try:
        claims = json.loads(payload_bytes.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return None
    if not isinstance(claims, dict):
        return None

    if claims.get("iss") != EXPECTED_JWT_ISSUER:
        return None

    aud = claims.get("aud")
    if isinstance(aud, str):
        aud_ok = aud == EXPECTED_JWT_AUDIENCE
    elif isinstance(aud, list):
        aud_ok = any(isinstance(item, str) and item == EXPECTED_JWT_AUDIENCE for item in aud)
    else:
        aud_ok = False
    if not aud_ok:
        return None

    now = time.time() if now_ts is None else now_ts
    exp = claims.get("exp")
    if not _is_finite_number(exp) or now >= float(exp) + JWT_CLOCK_SKEW_SEC:
        return None

    nbf = claims.get("nbf")
    if nbf is not None:
        if not _is_finite_number(nbf) or float(nbf) > now + JWT_CLOCK_SKEW_SEC:
            return None

    iat = claims.get("iat")
    if iat is not None and not _is_finite_number(iat):
        return None

    sub = claims.get("sub")
    if not isinstance(sub, str) or not sub.strip():
        return None
    raw_role = claims.get("role")
    role = raw_role.strip() if isinstance(raw_role, str) and raw_role.strip() else "USER"
    return sub.strip(), role


def load_gh_token() -> str:
    token_file = os.environ.get("SANDBOX_GH_TOKEN_FILE", "").strip()
    if not token_file:
        cred_dir = os.environ.get("CREDENTIALS_DIRECTORY", "").strip()
        if cred_dir:
            token_file = os.path.join(cred_dir, "GH_TOKEN")
    if not token_file:
        return ""
    try:
        return Path(token_file).read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def _parse_float_env(name: str, default: float) -> float:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return default
    try:
        value = float(raw)
    except ValueError:
        return default
    return value if value > 0 else default


WORKSPACE_TTL_DAYS = _parse_float_env("SANDBOX_WORKSPACE_TTL_DAYS", 7.0)
STORAGE_TTL_DAYS = _parse_float_env("SANDBOX_STORAGE_TTL_DAYS", 30.0)
CACHE_TTL_DAYS = _parse_float_env("SANDBOX_CACHE_TTL_DAYS", 14.0)
CACHE_MAX_BYTES = int(
    _parse_float_env("SANDBOX_CACHE_MAX_BYTES", float(2 * 1024 * 1024 * 1024))
)
CLEANUP_INTERVAL_SEC = _parse_float_env("SANDBOX_CLEANUP_INTERVAL_SEC", 21600.0)


def sanitize_user_id(raw: str | None) -> str:
    if not raw:
        return ""
    cleaned = raw.strip()
    if not cleaned or cleaned == "default":
        return ""
    if USER_ID_PATTERN.fullmatch(cleaned):
        return cleaned
    digest = hashlib.sha256(cleaned.encode("utf-8")).hexdigest()[:16]
    return f"u_{digest}"


def get_session_owner(session_id: str) -> str:
    if not ID_PATTERN.fullmatch(session_id):
        return ""
    owner_file = resolve_under(SESSIONS_DIR, f"{session_id}.json")
    if not owner_file.is_file():
        return ""
    try:
        data = json.loads(owner_file.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return ""
    owner = data.get("owner")
    return sanitize_user_id(owner) if isinstance(owner, str) else ""


def set_session_owner(session_id: str, owner: str) -> None:
    if not owner or not ID_PATTERN.fullmatch(session_id):
        return
    SESSIONS_DIR.mkdir(parents=True, exist_ok=True)
    owner_file = resolve_under(SESSIONS_DIR, f"{session_id}.json")
    if owner_file.exists():
        return
    owner_file.write_text(
        json.dumps({"owner": owner, "createdAt": now_iso()}),
        encoding="utf-8",
    )


def load_session_tombstones(session_id: str) -> dict[str, str]:
    if not ID_PATTERN.fullmatch(session_id):
        return {}
    tombstones_file = resolve_under(SESSIONS_DIR, f"{session_id}.tombstones.json")
    if not tombstones_file.is_file():
        return {}
    try:
        data = json.loads(tombstones_file.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    if not isinstance(data, dict):
        return {}
    return {
        key: value
        for key, value in data.items()
        if isinstance(key, str) and isinstance(value, str)
    }


def save_session_tombstones(session_id: str, tombstones: dict[str, str]) -> None:
    if not ID_PATTERN.fullmatch(session_id):
        return
    tombstones_file = resolve_under(SESSIONS_DIR, f"{session_id}.tombstones.json")
    if not tombstones:
        with contextlib.suppress(OSError):
            tombstones_file.unlink(missing_ok=True)
        return
    SESSIONS_DIR.mkdir(parents=True, exist_ok=True)
    tombstones_file.write_text(json.dumps(tombstones), encoding="utf-8")


def user_cache_dir_for(user_slug: str) -> Path | None:
    if not user_slug:
        return None
    cache_dir = resolve_under(USERS_DIR, user_slug, "cache")
    cache_dir.mkdir(parents=True, exist_ok=True)
    with contextlib.suppress(OSError):
        cache_dir.chmod(0o700)
    return cache_dir


def check_session_access(session_id: str, caller_user: str) -> bool:
    if not caller_user:
        return True
    owner = get_session_owner(session_id)
    if not owner:
        return True
    return owner == caller_user


def workspace_dir_for(session_id: str, user_slug: str = "") -> Path:
    legacy = resolve_under(WORKSPACES_DIR, session_id)
    if legacy.exists():
        return legacy
    owner = get_session_owner(session_id) or user_slug
    if owner:
        return resolve_under(USERS_DIR, owner, "workspaces", session_id)
    return legacy


def storage_dir_for(
    session_id: str,
    user_slug: str = "",
    *,
    shared: bool = False,
) -> Path:
    legacy = resolve_under(STORAGE_DIR, session_id)
    if shared or legacy.exists():
        return legacy
    owner = get_session_owner(session_id) or user_slug
    if owner:
        return resolve_under(USERS_DIR, owner, "storage", session_id)
    return legacy


def _latest_mtime(path: Path) -> float:
    try:
        latest = path.stat().st_mtime
    except OSError:
        return 0.0
    if not path.is_dir():
        return latest
    for root, dirs, files in os.walk(path):
        root_path = Path(root)
        for name in (*dirs, *files):
            try:
                mtime = (root_path / name).stat(follow_symlinks=False).st_mtime
            except OSError:
                continue
            if mtime > latest:
                latest = mtime
    return latest


def _iter_workspace_roots() -> list[Path]:
    roots: list[Path] = []
    if WORKSPACES_DIR.is_dir():
        roots.append(WORKSPACES_DIR)
    if USERS_DIR.is_dir():
        for user_dir in USERS_DIR.iterdir():
            ws_root = user_dir / "workspaces"
            if ws_root.is_dir():
                roots.append(ws_root)
    return roots


def _iter_storage_roots() -> list[Path]:
    roots: list[Path] = []
    if STORAGE_DIR.is_dir():
        roots.append(STORAGE_DIR)
    if USERS_DIR.is_dir():
        for user_dir in USERS_DIR.iterdir():
            st_root = user_dir / "storage"
            if st_root.is_dir():
                roots.append(st_root)
    return roots


def _prune_cache_dir(cache_dir: Path, cutoff_ts: float, max_bytes: int) -> int:
    removed = 0
    surviving: list[tuple[float, int, Path]] = []
    for root, _dirs, files in os.walk(cache_dir, followlinks=False):
        root_path = Path(root)
        for name in files:
            path = root_path / name
            try:
                st = path.stat(follow_symlinks=False)
            except OSError:
                continue
            if st.st_mtime < cutoff_ts:
                try:
                    path.unlink(missing_ok=True)
                    removed += 1
                except OSError:
                    pass
                continue
            surviving.append((st.st_mtime, st.st_size, path))

    total_bytes = sum(size for _mtime, size, _path in surviving)
    if total_bytes > max_bytes:
        surviving.sort(key=lambda item: item[0])
        for _mtime, size, path in surviving:
            if total_bytes <= max_bytes:
                break
            try:
                path.unlink(missing_ok=True)
                total_bytes -= size
                removed += 1
            except OSError:
                continue

    for root, dirs, _files in os.walk(cache_dir, topdown=False, followlinks=False):
        root_path = Path(root)
        for name in dirs:
            subdir = root_path / name
            with contextlib.suppress(OSError):
                subdir.rmdir()

    return removed


def cleanup_expired_state(now_ts: float | None = None) -> dict[str, int]:
    current_ts = time.time() if now_ts is None else now_ts
    ws_cutoff = current_ts - (WORKSPACE_TTL_DAYS * 86400.0)
    st_cutoff = current_ts - (STORAGE_TTL_DAYS * 86400.0)
    cache_cutoff = current_ts - (CACHE_TTL_DAYS * 86400.0)
    removed_workspaces = 0
    removed_storage_objects = 0
    removed_storage_sessions = 0
    removed_cache_files = 0
    active_sessions: set[str] = set()

    for ws_root in _iter_workspace_roots():
        for ws_dir in list(ws_root.iterdir()):
            if not ws_dir.is_dir():
                continue
            sid = ws_dir.name
            lock = get_session_lock(sid)
            if not lock.acquire(blocking=False):
                active_sessions.add(sid)
                continue
            try:
                if _latest_mtime(ws_dir) < ws_cutoff:
                    shutil.rmtree(ws_dir, ignore_errors=True)
                    removed_workspaces += 1
                else:
                    active_sessions.add(sid)
            finally:
                lock.release()

    for st_root in _iter_storage_roots():
        for st_dir in list(st_root.iterdir()):
            if not st_dir.is_dir():
                continue
            sid = st_dir.name
            lock = get_session_lock(sid)
            if not lock.acquire(blocking=False):
                active_sessions.add(sid)
                continue
            try:
                remaining = False
                for meta_file in list(st_dir.glob("*.json")):
                    try:
                        meta = json.loads(meta_file.read_text(encoding="utf-8"))
                    except (OSError, json.JSONDecodeError):
                        meta = {}
                    if bool(meta.get("readOnly")) or meta.get("kind") == "skill":
                        remaining = True
                        continue
                    blob_file = st_dir / meta_file.stem
                    obj_mtime = max(
                        _latest_mtime(meta_file),
                        _latest_mtime(blob_file) if blob_file.exists() else 0.0,
                    )
                    if obj_mtime < st_cutoff:
                        with contextlib.suppress(OSError):
                            meta_file.unlink(missing_ok=True)
                        with contextlib.suppress(OSError):
                            blob_file.unlink(missing_ok=True)
                        removed_storage_objects += 1
                    else:
                        remaining = True
                if not remaining and not any(st_dir.iterdir()):
                    with contextlib.suppress(OSError):
                        st_dir.rmdir()
                    removed_storage_sessions += 1
                else:
                    active_sessions.add(sid)
            finally:
                lock.release()

    if USERS_DIR.is_dir():
        for user_dir in list(USERS_DIR.iterdir()):
            cache_dir = user_dir / "cache"
            if cache_dir.is_dir():
                removed_cache_files += _prune_cache_dir(
                    cache_dir, cache_cutoff, CACHE_MAX_BYTES
                )

    if SESSIONS_DIR.is_dir():
        for session_file in list(SESSIONS_DIR.glob("*.json")):
            if session_file.name.endswith(".tombstones.json"):
                sid = session_file.name[: -len(".tombstones.json")]
            else:
                sid = session_file.stem
            if sid not in active_sessions:
                with contextlib.suppress(OSError):
                    session_file.unlink(missing_ok=True)

    return {
        "removed_workspaces": removed_workspaces,
        "removed_storage_objects": removed_storage_objects,
        "removed_storage_sessions": removed_storage_sessions,
        "removed_cache_files": removed_cache_files,
    }


def _janitor_loop() -> None:
    while True:
        time.sleep(CLEANUP_INTERVAL_SEC)
        with contextlib.suppress(Exception):
            cleanup_expired_state()


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
        rel_path.endswith(".pyc")
        or any(part.startswith(".lc-tmp-") for part in parts)
        or any(part in IGNORED_DIR_NAMES for part in parts[:-1])
    )


def snapshot_workspace(workspace_dir: Path) -> dict[str, tuple[int, str]]:
    snap: dict[str, tuple[int, str]] = {}
    if not workspace_dir.exists():
        return snap
    for root, dirnames, filenames in os.walk(workspace_dir, followlinks=False):
        dirnames[:] = [
            d
            for d in dirnames
            if d not in IGNORED_DIR_NAMES and not d.startswith(".lc-tmp-")
        ]
        root_path = Path(root)
        for filename in filenames:
            path = root_path / filename
            if path.is_symlink() or not path.is_file():
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
    user_slug: str = "",
) -> dict[str, object]:
    is_shared = read_only or kind == "skill"
    if not is_shared and user_slug:
        set_session_owner(session_id, user_slug)
    session_dir = storage_dir_for(session_id, user_slug, shared=is_shared)
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


def load_storage_meta(
    session_id: str, file_id: str, user_slug: str = ""
) -> dict[str, object] | None:
    if not ID_PATTERN.fullmatch(session_id) or not ID_PATTERN.fullmatch(file_id):
        return None
    session_dir = storage_dir_for(session_id, user_slug)
    meta_path = resolve_under(session_dir, f"{file_id}.json")
    blob_path = resolve_under(session_dir, file_id)
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


def ensure_runtime_identity_files() -> tuple[Path, Path]:
    uid = os.getuid()
    gid = os.getgid()
    try:
        username = pwd.getpwuid(uid).pw_name
    except KeyError:
        username = "sandbox"
    try:
        groupname = grp.getgrgid(gid).gr_name
    except KeyError:
        groupname = "sandbox"

    passwd_lines = ["root:x:0:0:root:/root:/bin/sh\n"]
    if uid != 0:
        passwd_lines.append(f"{username}:x:{uid}:{gid}:sandbox:/mnt/data:/bin/sh\n")
    passwd_content = "".join(passwd_lines)

    group_lines = ["root:x:0:\n"]
    if gid != 0:
        group_lines.append(f"{groupname}:x:{gid}:\n")
    group_content = "".join(group_lines)

    etc_dir = STATE_DIR / "etc"
    passwd_path = etc_dir / "passwd"
    group_path = etc_dir / "group"

    with _RUNTIME_ETC_LOCK:
        etc_dir.mkdir(parents=True, exist_ok=True)
        for target, content in (
            (passwd_path, passwd_content),
            (group_path, group_content),
        ):
            existing = None
            if target.is_file():
                with contextlib.suppress(OSError):
                    existing = target.read_text(encoding="utf-8")
            if existing != content:
                tmp_path = target.with_name(f".{target.name}.{os.getpid()}.tmp")
                tmp_path.write_text(content, encoding="utf-8")
                with contextlib.suppress(OSError):
                    tmp_path.chmod(0o644)
                os.replace(tmp_path, target)

    return passwd_path, group_path


def build_bwrap_cmd(
    cmd: list[str], *, cache_dir: Path | None = None
) -> list[str] | None:
    if os.environ.get("SANDBOX_DISABLE_BWRAP") == "1":
        return None
    bwrap = shutil.which("bwrap")
    if not bwrap:
        return None
    passwd_path, group_path = ensure_runtime_identity_files()
    sandbox_etc_dir = os.environ.get("SANDBOX_ETC_DIR", "").strip()
    args = [
        bwrap,
        "--unshare-all",
        "--share-net",
        "--hostname",
        "sandbox",
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
    ]
    if sandbox_etc_dir and Path(sandbox_etc_dir).is_dir():
        args.extend(
            [
                "--ro-bind",
                sandbox_etc_dir,
                "/etc",
                "--ro-bind",
                str(passwd_path),
                "/etc/passwd",
                "--ro-bind",
                str(group_path),
                "/etc/group",
            ]
        )
        if not (Path(sandbox_etc_dir) / "fonts").exists() and os.path.exists("/etc/fonts"):
            resolved_fonts = os.path.realpath("/etc/fonts")
            if os.path.isdir(resolved_fonts):
                args.extend(["--ro-bind", resolved_fonts, "/etc/fonts"])
    else:
        args.extend(
            [
                "--ro-bind",
                str(passwd_path),
                "/etc/passwd",
                "--ro-bind",
                str(group_path),
                "/etc/group",
            ]
        )
        for etc_path in FALLBACK_ETC_PATHS:
            if os.path.exists(etc_path):
                resolved = os.path.realpath(etc_path)
                if os.path.exists(resolved):
                    args.extend(["--ro-bind", resolved, etc_path])
    args.extend(
        [
            "--ro-bind-try",
            "/run/current-system",
            "/run/current-system",
            "--dev",
            "/dev",
            "--proc",
            "/proc",
            "--size",
            SANDBOX_TMPFS_SIZE_BYTES,
            "--tmpfs",
            "/tmp",  # noqa: S108
        ]
    )
    if cache_dir is not None:
        args.extend(["--bind", str(cache_dir), SANDBOX_CACHE_MOUNT])
    args.extend(
        [
            "--bind",
            ".",
            "/mnt/data",
            "--chdir",
            "/mnt/data",
            "--",
            *cmd,
        ]
    )
    return args


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


def build_sandbox_env(
    env: dict[str, str],
    workspace_dir: Path,
    *,
    use_bwrap: bool,
    caller_role: str = "USER",
    cache_mounted: bool = False,
) -> dict[str, str]:
    child_env = {
        key: env[key]
        for key in ALLOWED_INHERITED_ENV_VARS
        if key in env
    }
    child_env["TERM"] = "dumb"
    child_env["GOMAXPROCS"] = "4"
    child_env["CARGO_BUILD_JOBS"] = "4"
    child_env["CARGO_INCREMENTAL"] = "0"
    child_env["PYTHONDONTWRITEBYTECODE"] = "1"
    if use_bwrap:
        cache_root = SANDBOX_CACHE_MOUNT if cache_mounted else "/tmp"  # noqa: S108
        child_env["HOME"] = "/mnt/data"
        child_env["LIBRECHAT_CODE_DATA_DIR"] = "/mnt/data"
        child_env["TMPDIR"] = "/tmp"  # noqa: S108
        child_env["XDG_CACHE_HOME"] = f"{cache_root}/cache"
        child_env["XDG_DATA_HOME"] = f"{cache_root}/xdg-data"
        child_env["NIX_STATE_DIR"] = f"{cache_root}/nix-state"
        child_env["UV_CACHE_DIR"] = f"{cache_root}/uv-cache"
        child_env["UV_TOOL_DIR"] = f"{cache_root}/uv-tools"
        child_env["PIP_CACHE_DIR"] = f"{cache_root}/pip-cache"
        child_env["NPM_CONFIG_CACHE"] = f"{cache_root}/npm-cache"
        child_env["MPLCONFIGDIR"] = f"{cache_root}/matplotlib"
        child_env["GOCACHE"] = f"{cache_root}/go-cache"
        child_env["GOMODCACHE"] = f"{cache_root}/go-mod"
        child_env["GOPATH"] = f"{cache_root}/go"
        child_env["CARGO_HOME"] = f"{cache_root}/cargo"
        child_env["GOTMPDIR"] = "/tmp"  # noqa: S108
    else:
        child_env["HOME"] = str(workspace_dir)
        child_env["LIBRECHAT_CODE_DATA_DIR"] = str(workspace_dir)
        if "TMPDIR" in env:
            child_env["TMPDIR"] = env["TMPDIR"]
    if caller_role == "ADMIN":
        gh_token = load_gh_token()
        if gh_token:
            child_env["GH_TOKEN"] = gh_token
        admin_git_config = (
            env.get("SANDBOX_ADMIN_GIT_CONFIG")
            or os.environ.get("SANDBOX_ADMIN_GIT_CONFIG", "")
        ).strip()
        if admin_git_config and Path(admin_git_config).is_file():
            child_env["GIT_CONFIG_SYSTEM"] = admin_git_config
    return child_env


def run_sandboxed(
    cmd: list[str],
    workspace_dir: Path,
    env: dict[str, str],
    timeout_sec: float,
    tracking_keys: tuple[str, ...] = (),
    *,
    caller_role: str = "USER",
    cache_dir: Path | None = None,
) -> tuple[subprocess.CompletedProcess[str], bool]:
    bwrap_cmd = build_bwrap_cmd(cmd, cache_dir=cache_dir)
    child_env = build_sandbox_env(
        env,
        workspace_dir,
        use_bwrap=bwrap_cmd is not None,
        caller_role=caller_role,
        cache_mounted=(bwrap_cmd is not None and cache_dir is not None),
    )
    if bwrap_cmd is not None:
        return _run_process_bounded(
            bwrap_cmd, workspace_dir, child_env, timeout_sec, tracking_keys
        )
    return _run_process_bounded(
        cmd, workspace_dir, child_env, timeout_sec, tracking_keys
    )


def execute_code_request(
    body: dict[str, object],
    *,
    programmatic: bool = False,
    request_id: str | None = None,
    user_id: str = "",
    ignore_body_user: bool = False,
    caller_role: str = "USER",
) -> dict[str, object]:
    raw_lang = str(body.get("lang") or ("bash" if programmatic else "py")).lower().strip()
    code = str(body.get("code") or "")
    raw_args = body.get("args")
    args = [str(a) for a in raw_args] if isinstance(raw_args, list) else []
    raw_session = body.get("session_id") or body.get("runtime_session_hint")
    raw_session_str = str(raw_session).strip() if raw_session else ""
    session_id = to_nanoid(raw_session_str if raw_session_str else None)
    body_user = body.get("user_id")
    if ignore_body_user:
        caller_user = sanitize_user_id(user_id)
    else:
        caller_user = sanitize_user_id(
            user_id or (body_user if isinstance(body_user, str) else "")
        )
    if not check_session_access(session_id, caller_user):
        raise PermissionError("Session belongs to another user")
    if caller_user:
        set_session_owner(session_id, caller_user)
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

    workspace_dir = workspace_dir_for(session_id, caller_user)
    session_storage_dir = storage_dir_for(session_id, caller_user)
    cache_dir = user_cache_dir_for(caller_user) if caller_user else None
    with get_session_lock(session_id):
        workspace_dir.mkdir(parents=True, exist_ok=True)
        session_storage_dir.mkdir(parents=True, exist_ok=True)

        tombstones = load_session_tombstones(session_id)
        tombstones_dirty = False
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
                raw_storage_sid = entry.get("storage_session_id") or entry.get("session_id")
                storage_sid = to_nanoid(
                    str(raw_storage_sid)
                    if isinstance(raw_storage_sid, str) and raw_storage_sid
                    else session_id
                )
                file_id = to_nanoid(raw_id)
                is_skill_entry = entry.get("kind") == "skill"
                if not is_skill_entry and not check_session_access(storage_sid, caller_user):
                    continue
                src_storage_dir = storage_dir_for(
                    storage_sid, caller_user, shared=is_skill_entry
                )
                src_blob = resolve_under(src_storage_dir, file_id)
                if not src_blob.is_file():
                    continue
                rel_path = safe_rel_path(raw_name)
                try:
                    dest_path = resolve_under(workspace_dir, rel_path)
                except ValueError:
                    continue
                tombstone_digest = tombstones.get(rel_path)
                if tombstone_digest is not None:
                    try:
                        blob_digest = hashlib.sha256(src_blob.read_bytes()).hexdigest()
                    except OSError:
                        continue
                    if blob_digest == tombstone_digest:
                        continue
                    tombstones.pop(rel_path, None)
                    tombstones_dirty = True
                dest_path.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(src_blob, dest_path)
                if is_executable_path(rel_path):
                    with contextlib.suppress(OSError):
                        dest_path.chmod(0o755)
                meta = load_storage_meta(storage_sid, file_id, caller_user)
                if (
                    is_skill_entry
                    or (meta is not None and bool(meta.get("readOnly")))
                    or rel_path.startswith("skills/")
                ):
                    readonly_paths.add(rel_path)

        before_snap = snapshot_workspace(workspace_dir)
        use_bwrap = (
            os.environ.get("SANDBOX_DISABLE_BWRAP") != "1"
            and shutil.which("bwrap") is not None
        )
        effective_code = (
            code
            if use_bwrap
            else rewrite_mnt_data_in_code(code, workspace_dir)
        )
        effective_args = (
            args
            if use_bwrap
            else [rewrite_mnt_data_in_code(a, workspace_dir) for a in args]
        )

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
                    caller_role=caller_role,
                    cache_dir=cache_dir,
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
            _before_size, before_digest = before_snap[rel_path]
            tombstones[rel_path] = before_digest
            tombstones_dirty = True
            file_id = to_nanoid(f"{session_id}:{rel_path}")
            for candidate in (
                resolve_under(session_storage_dir, file_id),
                resolve_under(session_storage_dir, f"{file_id}.json"),
            ):
                with contextlib.suppress(OSError):
                    candidate.unlink(missing_ok=True)

        for rel_path in after_snap:
            if rel_path in tombstones:
                tombstones.pop(rel_path, None)
                tombstones_dirty = True

        if tombstones_dirty:
            save_session_tombstones(session_id, tombstones)

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
                    user_slug=caller_user,
                )
                out_files.append(
                    {
                        "id": file_id,
                        "name": rel_path,
                        "storage_session_id": session_id,
                    }
                )
        with contextlib.suppress(OSError):
            os.utime(workspace_dir, None)

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
    authenticated_user_id: str = ""
    authenticated_user_role: str = "USER"

    def log_message(self, format: str, *args: object) -> None:  # noqa: A002
        return

    def caller_user_slug(self) -> str:
        if self.authenticated_user_id:
            return sanitize_user_id(self.authenticated_user_id)
        return sanitize_user_id(
            self.headers.get("User-Id") or self.headers.get("X-User-Id")
        )

    def check_auth(self) -> bool:
        self.authenticated_user_id = ""
        self.authenticated_user_role = "USER"
        auth_header = (self.headers.get("Authorization") or "").strip()
        bearer = auth_header[7:].strip() if auth_header.lower().startswith("bearer ") else ""

        if jwt_auth_configured():
            if bearer:
                verified = verify_jwt_token(bearer)
                if verified is not None:
                    self.authenticated_user_id, self.authenticated_user_role = verified
                    return True
            if not EXPECTED_API_KEY:
                self.send_json(401, {"error": "Unauthorized"})
                return False

        if EXPECTED_API_KEY:
            provided = (
                self.headers.get("X-Api-Key") or self.headers.get("x-api-key") or ""
            ).strip()
            if not provided:
                provided = bearer
            if provided and secrets.compare_digest(provided, EXPECTED_API_KEY):
                self.authenticated_user_role = "USER"
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

        raw_user_id = (
            self.authenticated_user_id
            or self.headers.get("User-Id")
            or self.headers.get("X-User-Id")
            or "default"
        ).strip()
        user_slug = self.caller_user_slug()
        kind = fields.get("kind") or "user"
        resource_id = raw_user_id if kind == "user" else (fields.get("id") or raw_user_id)
        version_raw = fields.get("version")
        version: int | None = None
        if version_raw:
            try:
                version = int(version_raw)
            except ValueError:
                version = None
        read_only = fields.get("read_only", "").lower() == "true" or kind == "skill"

        explicit_session = fields.get("session_id") or fields.get("storage_session_id") or ""
        if explicit_session:
            storage_session_id = to_nanoid(explicit_session)
        elif kind in ("skill", "agent") or fields.get("id"):
            seed = f"{raw_user_id}:{kind}:{resource_id}:{version if version is not None else ''}"
            storage_session_id = to_nanoid(seed)
        else:
            storage_session_id = to_nanoid()

        if not read_only and kind != "skill" and not check_session_access(storage_session_id, user_slug):
            self.send_json(403, {"error": "Forbidden"})
            return

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
                user_slug=user_slug,
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

        caller_user = self.caller_user_slug()

        if len(segments) == 2 and segments[0] == "files":
            session_id = to_nanoid(segments[1])
            if not check_session_access(session_id, caller_user):
                self.send_json(403, {"error": "Forbidden"})
                return
            session_dir = storage_dir_for(session_id, caller_user)
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
            if not check_session_access(session_id, caller_user):
                self.send_json(403, {"error": "Forbidden"})
                return
            file_id = to_nanoid(segments[3])
            meta = load_storage_meta(session_id, file_id, caller_user)
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
            if not check_session_access(session_id, caller_user):
                self.send_json(403, {"error": "Forbidden"})
                return
            file_id = to_nanoid(segments[2])
            meta = load_storage_meta(session_id, file_id, caller_user)
            blob_path = resolve_under(storage_dir_for(session_id, caller_user), file_id)
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
            try:
                result = execute_code_request(
                    body,
                    programmatic=(path == "/exec/programmatic"),
                    request_id=req_id,
                    user_id=self.caller_user_slug(),
                    ignore_body_user=bool(self.authenticated_user_id),
                    caller_role=self.authenticated_user_role,
                )
            except PermissionError:
                self.send_json(403, {"error": "Forbidden"})
                return
            self.send_json(200, result)
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
            if raw_session and not check_session_access(
                to_nanoid(raw_session), self.caller_user_slug()
            ):
                self.send_json(403, {"error": "Forbidden"})
                return
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

        caller_user = self.caller_user_slug()
        if (len(segments) == 3 and segments[0] == "files") or (
            len(segments) == 4
            and segments[0] == "sessions"
            and segments[2] == "objects"
        ):
            session_id = to_nanoid(segments[1])
            if not check_session_access(session_id, caller_user):
                self.send_json(403, {"error": "Forbidden"})
                return
            file_id = to_nanoid(segments[-1])
            session_dir = storage_dir_for(session_id, caller_user)
            for candidate in (
                resolve_under(session_dir, file_id),
                resolve_under(session_dir, f"{file_id}.json"),
            ):
                with contextlib.suppress(OSError):
                    candidate.unlink(missing_ok=True)
            self.send_json(200, {"message": "deleted"})
            return

        self.send_json(404, {"error": "Not found"})


def main() -> None:
    STORAGE_DIR.mkdir(parents=True, exist_ok=True)
    WORKSPACES_DIR.mkdir(parents=True, exist_ok=True)
    USERS_DIR.mkdir(parents=True, exist_ok=True)
    SESSIONS_DIR.mkdir(parents=True, exist_ok=True)
    with contextlib.suppress(Exception):
        cleanup_expired_state()
    janitor = threading.Thread(target=_janitor_loop, name="sandbox-janitor", daemon=True)
    janitor.start()
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
