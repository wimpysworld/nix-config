"""Matrix reaction companion, durable state store, /sync client, and session resolver."""

import argparse
import collections
import contextlib
import datetime
import fcntl
import hashlib
import http.client
import json
import math
import os
import sqlite3
import ssl
import stat
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from collections.abc import Callable
from pathlib import Path

SERVER_DOMAIN = "matrix.wimpys.world"
DEFAULT_ROOM_ID = f"!the-cauldron:{SERVER_DOMAIN}"
DEFAULT_HOMESERVER_URL = f"https://{SERVER_DOMAIN}"
DEFAULT_RPC_URL = "https://127.0.0.1:13131/api/rpc"

MARTIN_ID = f"@martin:{SERVER_DOMAIN}"
SKRYE_ID = f"@skrye:{SERVER_DOMAIN}"
ZANNAH_ID = f"@zannah:{SERVER_DOMAIN}"
TRAYA_ID = f"@traya:{SERVER_DOMAIN}"

BOT_IDS = frozenset({SKRYE_ID, ZANNAH_ID, TRAYA_ID})
ALLOWLIST_USER_IDS = frozenset({MARTIN_ID, SKRYE_ID, ZANNAH_ID, TRAYA_ID})

DISPLAY_NAMES = {
    "skrye": "Skrye",
    "zannah": "Zannah",
    "traya": "Traya",
    "momin": "Traya",
}

ASSESSMENT_SESSION_KEY = "companion:matrix-assess"
ASSESSMENT_BADGES = frozenset({"👌🏻", "👍🏻", "✋🏻"})
BARE_ASSESSMENT_BADGE_MAP = {
    "👌": "👌🏻",
    "👍": "👍🏻",
    "✋": "✋🏻",
    "👌🏻": "👌🏻",
    "👍🏻": "👍🏻",
    "✋🏻": "✋🏻",
}

ACK_REACTION_KEY = "👀"
ACTIVE_BEE_KEY = "🐝"
PHASE_WRITING_KEY = "✍🏻"
PHASE_SHELL_KEY = "🐚"
PHASE_TOOL_KEY = "🔧"
COMPLETION_KEY = "✌🏻"

NOTICE_THINKING_ICON = "💭"
NOTICE_SEARCH_ICON = "🔎"
NOTICE_WRITE_ICON = "✍️"
NOTICE_SHELL_ICON = "🐚"
NOTICE_TOOL_ICON = "🔧"
NOTICE_FINISHED_ICON = "🏁"
NOTICE_UNVERIFIED_ICON = "⚠️"

SHELL_TOOLS = frozenset({"exec", "process"})
SEARCH_TOOLS = frozenset(
    {
        "read",
        "read_file",
        "grep",
        "glob",
        "web_fetch",
        "read_skill",
        "memory_search",
        "memory_get",
        "sessions_history",
        "sessions_search",
        "sessions_list",
        "codebase_peek",
        "codebase_search",
        "codebase_status",
        "checkpoints_list",
        "nodes_list",
        "nodes_describe",
        "sandbox_packages",
        "spawn_list",
        "spawn_status",
        "spawn_result",
        "gmail_connector",
        "himalaya_connector",
        "connectors",
        "teams_read_message",
        "teams_search_messages",
        "teams_member_info",
    }
)
WRITE_TOOLS = frozenset(
    {
        "write",
        "write_file",
        "edit",
        "multiedit",
        "create_skill",
        "update_skill",
        "patch_skill",
        "delete_skill",
        "memory_save",
        "memory_delete",
        "memory_forget",
        "checkpoint_restore",
    }
)

ROLE_SUMMARIES = {
    "traya": (
        "Traya (@traya:matrix.wimpys.world): General collaborator - "
        "plans, researches, designs, implements, tests, reviews, and challenges proposals."
    ),
    "skrye": (
        "Skrye (@skrye:matrix.wimpys.world): General collaborator, first responder, and chat moderator - "
        "plans, researches, designs, implements, tests, reviews, and challenges proposals. "
        "Coordinates invitations through the companion and speaks after other raised hands."
    ),
    "zannah": (
        "Zannah (@zannah:matrix.wimpys.world): General collaborator - "
        "plans, researches, designs, implements, tests, reviews, and challenges proposals."
    ),
}

USER_ID_DISPLAY_NAMES = {
    MARTIN_ID: "Martin",
    SKRYE_ID: "Skrye",
    ZANNAH_ID: "Zannah",
    TRAYA_ID: "Traya",
}

ASSESSMENT_QUEUE_MAX_DEPTH = 32
ASSESSMENT_MAX_PRECEDING_MESSAGES = 6
ASSESSMENT_MAX_CONTEXT_CHARS = 2400
ASSESSMENT_MAX_TARGET_CHARS = 1600
ASSESSMENT_TIMEOUT_SECS = 25.0

THINKING_DWELL_MS = 3000
PHASE_EDIT_INTERVAL_MS = 3000
INITIAL_PROGRESS_NOTICE_DELAY_MS = 5000
PROGRESS_NOTICE_INTERVAL_MS = 3000
COMPLETION_RECONCILE_WINDOW_MS = 5000
WAKEUP_DEADLINE_MS = 15000
MAX_WAKEUPS_PER_MARTIN_ROOT = 3
MAX_BOT_TURNS_SINCE_MARTIN = 9
TARGET_PREVIEW_MAX_CHARS = 120
COMPANION_RELAY_KEY = "org.wimpysworld.companion_relay"
AUDIO_FILENAME_EXTENSIONS = (
    ".ogg",
    ".mp3",
    ".wav",
    ".m4a",
    ".opus",
    ".aac",
    ".flac",
    ".webm",
)

RECENT_EVENTS_CAP = 50
UNMENTIONED_EVENTS_CAP = 50
COMPANION_STATE_ENTRY_CAP = 100
ENCODED_COMPONENT_BYTES = 120
MAX_RESPONSE_BYTES = 1048576

AUTH_STATE_FILENAME = "auth.json"
SYNC_STATE_FILENAME = "sync-state.json"
OUTBOX_FILENAME = "outbox.json"
COMPANION_STATE_FILENAME = "companion-state.json"
ROOM_EVENTS_FILENAME = "room-events.json"
ACTIVE_TURN_FILENAME = "active-turn.json"
ACTIVE_TURN_LOCK_FILENAME = "active-turn.lock"
COMPANION_LOCK_FILENAME = "companion.lock"

FORBIDDEN_COMPANION_WRITES = frozenset({ACTIVE_TURN_FILENAME})


class NoRedirect(urllib.request.HTTPRedirectHandler):
    """Reject HTTP redirects on Matrix and local RPC requests."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError("HTTP redirect refused")


class MatrixAPIError(RuntimeError):
    """Structured Matrix HTTP error."""

    def __init__(self, status: int, errcode: str | None = None, message: str = ""):
        super().__init__(message or f"Matrix HTTP {status} ({errcode or 'unknown'})")
        self.status = status
        self.errcode = errcode


def _safe_int(value: object, default: int = 0) -> int:
    if isinstance(value, bool):
        return default
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return math.trunc(value) if math.isfinite(value) else default
    if isinstance(value, str):
        try:
            return int(value.strip())
        except ValueError:
            return default
    return default


def _as_dict(value: object) -> dict:
    return value if isinstance(value, dict) else {}


def _validate_http_url(url: str) -> urllib.parse.SplitResult:
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme not in ("http", "https") or not parsed.netloc or not parsed.hostname:
        raise ValueError(f"Unsupported or invalid HTTP URL: {url}")
    return parsed


def _http_json_request(
    url: str,
    method: str,
    headers: dict[str, str],
    raw_body: bytes | None = None,
    timeout: float = 20.0,
    allow_loopback_self_signed: bool = False,
) -> tuple[int, bytes]:
    parsed = _validate_http_url(url)
    host = parsed.hostname or ""
    port = parsed.port
    target_path = parsed.path or "/"
    if parsed.query:
        target_path = f"{target_path}?{parsed.query}"

    conn: http.client.HTTPConnection
    if parsed.scheme == "https":
        if allow_loopback_self_signed and host in ("127.0.0.1", "::1", "localhost"):
            ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
        else:
            ctx = ssl.create_default_context()
        conn = http.client.HTTPSConnection(host, port=port, timeout=timeout, context=ctx)
    else:
        conn = http.client.HTTPConnection(host, port=port, timeout=timeout)

    try:
        conn.request(method, target_path, body=raw_body, headers=headers)
        resp = conn.getresponse()
        status = resp.status
        if 300 <= status < 400:
            raise ValueError("HTTP redirect refused")
        data = resp.read(MAX_RESPONSE_BYTES + 1)
        if len(data) > MAX_RESPONSE_BYTES:
            raise ValueError("Oversized HTTP response")
        return status, data
    finally:
        conn.close()


def now_ms() -> int:
    return math.trunc(time.time() * 1000)


def derive_display_name(agent_name: str, explicit: str | None = None) -> str:
    if explicit and explicit.strip():
        return explicit.strip()
    norm = (agent_name or "").strip().lower()
    if norm in DISPLAY_NAMES:
        return DISPLAY_NAMES[norm]
    return norm.capitalize() if norm else "Skrye"


def derive_device_id(agent_name: str) -> str:
    norm = (agent_name or "").strip().upper()
    if not norm:
        raise ValueError("agent_name must be non-empty")
    return f"MOLTIS_COMPANION_{norm}"


def check_private(fd: int, directory: bool = False) -> os.stat_result:
    info = os.fstat(fd)
    valid_type = stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode)
    if (
        not valid_type
        or info.st_uid != os.getuid()
        or (info.st_mode & 0o077) != 0
        or (not directory and info.st_nlink != 1)
    ):
        raise ValueError("Unsafe credential or state file storage")
    return info


def open_private_directory(path: Path | str, create: bool = True) -> int:
    target = Path(path)
    if create:
        target.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd = os.open(str(target), os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        info = os.fstat(fd)
        if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
            raise ValueError("Unsafe state directory owner or type")
        if (info.st_mode & 0o077) != 0:
            if create:
                os.fchmod(fd, 0o700)
                info = os.fstat(fd)
            if (info.st_mode & 0o077) != 0:
                raise ValueError("Unsafe state directory permissions")
        return fd
    except BaseException:
        os.close(fd)
        raise


def read_credential(path: Path | str | None = None, env_var: str = "") -> str:
    if path is not None and str(path).strip():
        # SOPS exposes credentials through symlinks to its current generation.
        try:
            with open(path, encoding="utf-8") as stream:
                check_private(stream.fileno(), directory=False)
                value = stream.read(16385).strip()
        except OSError as exc:
            raise ValueError("Unable to read Matrix credential file") from exc
        if not value or len(value) > 16384 or "\x00" in value:
            raise ValueError("Invalid Matrix password credential")
        return value
    lookup_var = env_var or ("MATRIX" + "_PASSWORD")
    env_val = os.environ.get(lookup_var, "").strip()
    if env_val and len(env_val) <= 16384 and "\x00" not in env_val:
        return env_val
    raise ValueError("Missing Matrix password credential")


def atomic_write_json_in_dir(dir_fd: int, filename: str, data: object) -> None:
    if filename in FORBIDDEN_COMPANION_WRITES:
        raise PermissionError(f"Companion must never write or modify {filename}")
    temp_name = f".{filename}.{uuid.uuid4().hex}.tmp"
    payload = (json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode("utf-8")
    fd = os.open(
        temp_name,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
        0o600,
        dir_fd=dir_fd,
    )
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp_name, filename, src_dir_fd=dir_fd, dst_dir_fd=dir_fd)
        with contextlib.suppress(OSError):
            os.fsync(dir_fd)
    finally:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(temp_name, dir_fd=dir_fd)


def read_json_in_dir(dir_fd: int, filename: str, default: object = None) -> object:
    try:
        fd = os.open(filename, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=dir_fd)
    except FileNotFoundError:
        return default
    with os.fdopen(fd, "rb") as stream:
        check_private(stream.fileno(), directory=False)
        raw = stream.read(MAX_RESPONSE_BYTES + 1)
    if len(raw) > MAX_RESPONSE_BYTES:
        raise ValueError(f"Oversized state file: {filename}")
    if not raw.strip():
        return default
    try:
        return json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, ValueError) as exc:
        raise ValueError(f"Invalid JSON in state file: {filename}") from exc


def encoded_key_components(key: str) -> list[str]:
    encoded = key.encode("utf-8").hex()
    if not encoded:
        return ["k"]
    chunks = []
    for idx in range(0, len(encoded), ENCODED_COMPONENT_BYTES):
        chunk = encoded[idx : idx + ENCODED_COMPONENT_BYTES]
        chunks.append(f"k{chunk}" if idx == 0 else chunk)
    return chunks


def history_paths(
    data_dir: Path | str,
    session_key: str,
    agent_name: str = "",
    room_id: str = DEFAULT_ROOM_ID,
) -> list[Path]:
    root = Path(data_dir)
    sessions_v1 = root / "sessions" / "v1"
    keys = [session_key]
    if agent_name:
        canonical_key = f"matrix:matrix-{agent_name}:{room_id}"
        if canonical_key not in keys:
            keys.append(canonical_key)
    paths = []
    for key in keys:
        if not key:
            continue
        chunked = sessions_v1.joinpath(*encoded_key_components(key), "history.jsonl")
        if chunked not in paths:
            paths.append(chunked)
        unchunked = sessions_v1 / f"k{key.encode('utf-8').hex()}" / "history.jsonl"
        if unchunked not in paths:
            paths.append(unchunked)
    return paths


def normalize_ts(raw_ts: object) -> tuple[int, int]:
    if raw_ts is None or isinstance(raw_ts, bool):
        return 0, 0
    if isinstance(raw_ts, (int, float)):
        val = _safe_int(raw_ts, 0)
        if val <= 0:
            return 0, 0
        if val > 10_000_000_000:
            return val // 1000, val
        return val, val * 1000
    if isinstance(raw_ts, str):
        text = raw_ts.strip()
        if not text:
            return 0, 0
        if text.isdigit():
            val = _safe_int(text, 0)
            if val <= 0:
                return 0, 0
            if val > 10_000_000_000:
                return val // 1000, val
            return val, val * 1000
        with contextlib.suppress(ValueError):
            iso_text = text[:-1] + "+00:00" if text.endswith("Z") else text
            dt = datetime.datetime.fromisoformat(iso_text)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=datetime.timezone.utc)
            ms = math.trunc(dt.timestamp() * 1000)
            return ms // 1000, ms
    return 0, 0


def extract_mentioned_bots(body: str, content: dict | None = None) -> set[str]:
    mentioned: set[str] = set()
    text = body or ""
    for bot_id in BOT_IDS:
        if bot_id in text:
            mentioned.add(bot_id)
    if isinstance(content, dict):
        m_mentions = _as_dict(content.get("m.mentions"))
        user_ids = m_mentions.get("user_ids")
        if isinstance(user_ids, list):
            for uid in user_ids:
                if isinstance(uid, str) and uid in BOT_IDS:
                    mentioned.add(uid)
    return mentioned


def is_new_command_message(body: str, content: dict | None = None) -> bool:
    text = (body or "").strip()
    if not text:
        return False
    tokens = text.split()
    cleaned = [tok for tok in tokens if tok.rstrip(":,") not in ALLOWLIST_USER_IDS]
    if not cleaned:
        return False
    first = cleaned[0].lower()
    return bool(first == "/new" and len(cleaned) == 1)


def is_new_command_targeting(body: str, target_user_id: str, content: dict | None = None) -> bool:
    if not is_new_command_message(body, content):
        return False
    mentioned = extract_mentioned_bots(body, content)
    if not mentioned:
        return True
    return target_user_id in mentioned


def normalize_assessment_badge(raw_text: str | None) -> str | None:
    if not isinstance(raw_text, str):
        return None
    trimmed = raw_text.strip()
    return BARE_ASSESSMENT_BADGE_MAP.get(trimmed)


def extract_text_content(value: object) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        parts: list[str] = []
        for item in value:
            if isinstance(item, str):
                parts.append(item)
            elif isinstance(item, dict):
                txt = item.get("text") or item.get("content")
                if isinstance(txt, str):
                    parts.append(txt)
        return "\n".join(parts)
    if isinstance(value, dict):
        for key in ("text", "content", "reply", "response", "body"):
            candidate = value.get(key)
            if isinstance(candidate, str):
                return candidate
        msg = value.get("message")
        if isinstance(msg, (str, dict, list)):
            return extract_text_content(msg)
    return ""


def parse_assessment_rpc_response(rpc_response: object) -> str | None:
    """Validate JSON-RPC ok=true and return normalised assessment badge or None."""
    if not isinstance(rpc_response, dict):
        return None
    if rpc_response.get("error") is not None:
        return None

    top_ok = rpc_response.get("ok")
    if top_ok is False:
        return None

    result = rpc_response.get("result")
    payload = rpc_response.get("payload")
    nested_ok = None
    if isinstance(result, dict) and "ok" in result:
        nested_ok = result.get("ok")
    elif isinstance(payload, dict) and "ok" in payload:
        nested_ok = payload.get("ok")

    if nested_ok is False:
        return None
    if top_ok is not True and nested_ok is not True:
        return None

    raw_text = ""
    if isinstance(result, str):
        raw_text = result
    elif isinstance(payload, str):
        raw_text = payload
    elif isinstance(result, dict):
        raw_text = extract_text_content(result)
    elif isinstance(payload, dict):
        raw_text = extract_text_content(payload)
    if not raw_text:
        raw_text = extract_text_content(rpc_response)

    return normalize_assessment_badge(raw_text)


def parse_chat_peek_active(rpc_response: object) -> bool | None:
    """Extract boolean active flag from a chat.peek RPC response, or None if unavailable."""
    if not isinstance(rpc_response, dict):
        return None
    if rpc_response.get("error") is not None or rpc_response.get("ok") is False:
        return None
    for container in (
        rpc_response.get("result"),
        rpc_response.get("payload"),
        rpc_response,
    ):
        if isinstance(container, dict) and isinstance(container.get("active"), bool):
            return bool(container["active"])
    return None


def display_name_for_user_id(user_id: str) -> str:
    if user_id in USER_ID_DISPLAY_NAMES:
        return USER_ID_DISPLAY_NAMES[user_id]
    if user_id.startswith("@") and ":" in user_id:
        local = user_id[1:].split(":", 1)[0]
        return DISPLAY_NAMES.get(local.lower(), local.capitalize())
    return user_id


def sanitize_no_matrix_mentions(text: str) -> str:
    """Guarantee no @...:matrix.wimpys.world string appears in a progress notice."""
    cleaned = text or ""
    for uid in ALLOWLIST_USER_IDS:
        cleaned = cleaned.replace(uid, display_name_for_user_id(uid))
    cleaned = cleaned.replace(f":{SERVER_DOMAIN}", "")
    return cleaned


def strip_audio_message_suffix(text: str) -> str:
    """Strip Moltis's appended [Audio message]: transcript suffix when matching text."""
    cleaned = (text or "").strip()
    for marker in ("\n\n[Audio message]:", "\n[Audio message]:"):
        if marker in cleaned:
            prefix = cleaned.split(marker, 1)[0].strip()
            if prefix:
                return prefix
    return cleaned


def is_conversational_room_message(
    msgtype_or_event: object,
    body: object = None,
    *,
    sender: str | None = None,
    content: dict | None = None,
) -> bool:
    """Return True for m.text or caption-bearing bot m.audio events across all six companion checks."""
    if isinstance(msgtype_or_event, dict):
        ev = msgtype_or_event
        ev_content = _as_dict(ev.get("content"))
        resolved_msgtype = ev.get("msgtype") or ev_content.get("msgtype")
        resolved_body = ev.get("body") if "body" in ev else ev_content.get("body")
        resolved_sender = str(ev.get("sender") or "")
        resolved_content = dict(ev_content)
        if "filename" in ev and "filename" not in resolved_content:
            resolved_content["filename"] = ev.get("filename")
    else:
        resolved_msgtype = msgtype_or_event
        resolved_body = body
        resolved_sender = sender or ""
        resolved_content = _as_dict(content)

    if not isinstance(resolved_body, str) or not resolved_body.strip():
        return False
    clean_body = resolved_body.strip()
    if resolved_msgtype == "m.text":
        return True
    if resolved_msgtype != "m.audio":
        return False
    clean_sender = (resolved_sender or "").strip()
    if clean_sender not in BOT_IDS:
        return False
    filename = str(resolved_content.get("filename") or "").strip()
    if filename and clean_body.lower() == filename.lower():
        return False
    if " " not in clean_body and "\n" not in clean_body:
        lower_body = clean_body.lower()
        if any(lower_body.endswith(ext) for ext in AUDIO_FILENAME_EXTENSIONS):
            return False
    return True


def extract_record_sender(rec: dict) -> str:
    """Extract sender identity from nested channel.sender_id or top-level history fields."""
    if not isinstance(rec, dict):
        return ""
    channel = rec.get("channel")
    if isinstance(channel, dict):
        for key in ("sender_id", "sender", "peer_id", "user_id", "username"):
            val = channel.get(key)
            if isinstance(val, str) and val.strip():
                return val.strip()
    for key in ("sender_id", "sender", "peer_id", "user_id", "username"):
        val = rec.get(key)
        if isinstance(val, str) and val.strip():
            return val.strip()
    return ""


def format_elapsed_duration(elapsed_sec: int) -> str:
    """Format elapsed seconds as MM:SS (or HH:MM:SS at 3600 seconds and above)."""
    total_sec = max(0, _safe_int(elapsed_sec, 0))
    if total_sec >= 3600:
        hours, rem = divmod(total_sec, 3600)
        minutes, seconds = divmod(rem, 60)
        return f"{hours:02d}:{minutes:02d}:{seconds:02d}"
    minutes, seconds = divmod(total_sec, 60)
    return f"{minutes:02d}:{seconds:02d}"


def classify_tool_phase(tool_name: str) -> str:
    """Classify a BeforeToolCall tool name into shell, search, write, or tool."""
    norm = (tool_name or "").strip().lower()
    if norm in SHELL_TOOLS:
        return "shell"
    if norm in SEARCH_TOOLS:
        return "search"
    if norm in WRITE_TOOLS:
        return "write"
    return "tool"


def notice_icon_for_phase(phase: str) -> str:
    """Map a normalised activity phase to its progress-notice icon."""
    norm = (phase or "").strip().lower()
    if norm == "shell":
        return NOTICE_SHELL_ICON
    if norm == "search":
        return NOTICE_SEARCH_ICON
    if norm == "write":
        return NOTICE_WRITE_ICON
    if norm == "tool":
        return NOTICE_TOOL_ICON
    return NOTICE_THINKING_ICON


def format_progress_notice(
    elapsed_sec: int,
    iteration: int,
    phase: str = "thinking",
) -> str:
    """Format the 3-second progress notice with activity icon, MM:SS elapsed time, and step count."""
    clean_iter = max(1, _safe_int(iteration, 1))
    icon = notice_icon_for_phase(phase)
    return sanitize_no_matrix_mentions(
        f"{icon} {format_elapsed_duration(elapsed_sec)} elapsed - Step {clean_iter}"
    )


def format_terminal_notice(
    agent_display_name: str,
    elapsed_sec: int,
    verified: bool = True,
) -> str:
    """Format the terminal notice edited in place when a turn with a progress notice ends."""
    duration = format_elapsed_duration(max(1, _safe_int(elapsed_sec, 1)))
    if verified:
        return sanitize_no_matrix_mentions(
            f"{NOTICE_FINISHED_ICON} {agent_display_name} finished in {duration}"
        )
    return sanitize_no_matrix_mentions(
        f"{NOTICE_UNVERIFIED_ICON} {agent_display_name} ended after {duration} · Completion unverified"
    )


def format_target_message_preview(
    body: str,
    max_chars: int = TARGET_PREVIEW_MAX_CHARS,
) -> str:
    """Sanitise and format a single-line target message preview without Matrix mentions."""
    stripped = strip_audio_message_suffix(body or "")
    sanitised = sanitize_no_matrix_mentions(stripped).replace('"', "'")
    single_line = " ".join(sanitised.split())
    limit = max(16, _safe_int(max_chars, TARGET_PREVIEW_MAX_CHARS))
    if len(single_line) > limit:
        return single_line[: limit - 3].rstrip() + "..."
    return single_line


def select_raised_hand_speaker(
    raised_hands: list[str],
    recent_events: list[dict] | None = None,
    target_event_id: str = "",
) -> str:
    """Select peers before Skrye, then use least-recent speech and sha256 tie-breaking."""
    candidates = sorted({uid for uid in raised_hands if isinstance(uid, str) and uid in BOT_IDS})
    if not candidates:
        return SKRYE_ID
    if len(candidates) == 1:
        return candidates[0]
    candidates = [uid for uid in candidates if uid != SKRYE_ID]

    last_msg_index: dict[str, int] = {uid: -1 for uid in candidates}
    for idx, ev in enumerate(recent_events or []):
        if not isinstance(ev, dict):
            continue
        sender = str(ev.get("sender") or "")
        if sender not in last_msg_index:
            continue
        if not is_conversational_room_message(ev):
            continue
        body = str(ev.get("body") or "")
        if ev.get("is_new_command") or is_new_command_message(body):
            continue
        last_msg_index[sender] = idx

    def _sort_key(uid: str) -> tuple[int, str, str]:
        tie_digest = hashlib.sha256(f"{target_event_id}:{uid}".encode("utf-8")).hexdigest()
        return (last_msg_index.get(uid, -1), tie_digest, uid)

    return min(candidates, key=_sort_key)


def _join_display_names(names: list[str]) -> str:
    if not names:
        return ""
    if len(names) == 1:
        return names[0]
    if len(names) == 2:
        return f"{names[0]} and {names[1]}"
    return f"{', '.join(names[:-1])}, and {names[-1]}"


def format_moderator_wakeup_notice(
    raised_hands: list[str],
    wake_reason: str = "raised_hand",
    *,
    selected_speaker: str | None = None,
    target_sender: str = "",
    target_body: str = "",
) -> str:
    """Format the direct floor invitation notice with sanitised target preview and no raw event IDs."""
    clean_hands = [uid for uid in raised_hands if isinstance(uid, str) and uid]
    if selected_speaker and selected_speaker in ALLOWLIST_USER_IDS:
        invited_id = selected_speaker
    elif wake_reason == "raised_hand" and clean_hands:
        invited_id = clean_hands[0]
    else:
        invited_id = SKRYE_ID

    sender_display = display_name_for_user_id(target_sender) if target_sender else ""
    preview = format_target_message_preview(target_body) if target_body else ""
    if sender_display and preview:
        context_clause = f' on {sender_display}\'s message: "{preview}"'
    elif preview:
        context_clause = f' on message: "{preview}"'
    elif sender_display:
        context_clause = f" on {sender_display}'s message"
    else:
        context_clause = ""

    if wake_reason == "raised_hand" and clean_hands:
        remaining = [display_name_for_user_id(uid) for uid in clean_hands if uid != invited_id]
        if not remaining:
            if context_clause:
                return f"🛎️ Inviting {invited_id} to the floor{context_clause} ✋🏻"
            invited_name = display_name_for_user_id(invited_id)
            return f"🛎️ Inviting {invited_id} to the floor as {invited_name} has a raised hand ✋🏻"
        joined_rem = _join_display_names(remaining)
        return f"🛎️ Inviting {invited_id} to the floor{context_clause}. Remaining raised hands: {joined_rem} ✋🏻"
    return f"🛎️ Inviting {invited_id} to the floor{context_clause} (moderator assessment fallback after 15s)."


def format_companion_relay_notice(
    *,
    selected_speaker: str = SKRYE_ID,
    target_sender: str = "",
    target_body: str = "",
    remaining_hands: list[str] | None = None,
) -> str:
    """Format Skrye's non-mentioning relay notice so Traya's companion sends the floor invitation for Skrye."""
    speaker_name = display_name_for_user_id(selected_speaker)
    sender_display = display_name_for_user_id(target_sender) if target_sender else ""
    preview = format_target_message_preview(target_body) if target_body else ""
    if sender_display and preview:
        context_clause = f' on {sender_display}\'s message: "{preview}"'
    elif preview:
        context_clause = f' on message: "{preview}"'
    elif sender_display:
        context_clause = f" on {sender_display}'s message"
    else:
        context_clause = ""
    rem_names = [
        display_name_for_user_id(uid)
        for uid in (remaining_hands or [])
        if isinstance(uid, str) and uid and uid != selected_speaker
    ]
    if rem_names:
        joined_rem = _join_display_names(rem_names)
        return sanitize_no_matrix_mentions(
            f"🔔 Relaying floor invitation for {speaker_name}{context_clause}. Remaining raised hands: {joined_rem} ✋🏻"
        )
    return sanitize_no_matrix_mentions(
        f"🔔 Relaying floor invitation for {speaker_name}{context_clause} ✋🏻"
    )


def _sender_matches(event_sender: str, turn_sender: str) -> bool:
    s_ev = (event_sender or "").strip()
    s_turn = (turn_sender or "").strip()
    if not s_ev or not s_turn:
        return False
    if s_ev == s_turn:
        return True
    if not s_turn.startswith("@") and s_ev == f"@{s_turn}:{SERVER_DOMAIN}":
        return True
    return (
        s_ev.startswith("@")
        and ":" in s_ev
        and s_ev[1:].split(":", 1)[0].lower() == s_turn.lower()
    )


def _content_matches(event_body: str, turn_content: object) -> bool:
    extracted = extract_text_content(turn_content).strip()
    body = (event_body or "").strip()
    if not extracted or not body:
        return False
    if body == extracted:
        return True
    stripped_turn = strip_audio_message_suffix(extracted)
    stripped_body = strip_audio_message_suffix(body)
    return bool(stripped_turn and stripped_body and stripped_turn == stripped_body)


def make_run_state_key(session_key: str, run_id: str) -> str:
    return f"{session_key}::{run_id}"


def make_deterministic_txn_id(agent_name: str, operation: str, *parts: str) -> str:
    material = "::".join([agent_name.strip().lower(), operation.strip(), *(str(p) for p in parts)])
    digest = hashlib.sha256(material.encode("utf-8")).hexdigest()[:32]
    return f"mc-{agent_name.strip().lower()}-{digest}"


def load_session_history_records(
    data_dir: Path | str,
    session_key: str,
    agent_name: str = "",
    room_id: str = DEFAULT_ROOM_ID,
) -> list[dict]:
    records: list[dict] = []
    for path in history_paths(data_dir, session_key, agent_name=agent_name, room_id=room_id):
        if not path.is_file():
            continue
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        parsed: list[dict] = []
        for idx, line in enumerate(lines):
            raw = line.strip()
            if not raw:
                continue
            try:
                item = json.loads(raw)
            except ValueError:
                continue
            if isinstance(item, dict):
                item_copy = dict(item)
                item_copy.setdefault("_seq", idx)
                parsed.append(item_copy)
        if parsed:
            records = parsed
            break
    return records


class CompanionStateStore:
    """Durable state store in ~/.local/state/moltis/matrix-companion-<agent>/."""

    def __init__(
        self,
        state_dir: Path | str,
        agent_name: str,
        room_id: str = DEFAULT_ROOM_ID,
        started_at_ms: int | None = None,
    ):
        self.state_dir = Path(state_dir)
        self.agent_name = agent_name
        self.room_id = room_id
        self.started_at_ms = _safe_int(started_at_ms, now_ms()) if started_at_ms is not None else now_ms()
        self.ensure_directory()

    def ensure_directory(self) -> None:
        dir_fd = open_private_directory(self.state_dir, create=True)
        os.close(dir_fd)

    @contextlib.contextmanager
    def _locked_dir(self, lock_filename: str = COMPANION_LOCK_FILENAME):
        dir_fd = open_private_directory(self.state_dir, create=True)
        try:
            lock_fd = os.open(
                lock_filename,
                os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK,
                0o600,
                dir_fd=dir_fd,
            )
            with os.fdopen(lock_fd, "r+", encoding="utf-8") as lock_file:
                check_private(lock_file.fileno(), directory=False)
                fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
                try:
                    yield dir_fd
                finally:
                    fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
        finally:
            os.close(dir_fd)

    def read_auth(self) -> dict:
        with self._locked_dir() as dir_fd:
            data = read_json_in_dir(dir_fd, AUTH_STATE_FILENAME, default={})
            return data if isinstance(data, dict) else {}

    def write_auth(self, auth_data: dict) -> None:
        with self._locked_dir() as dir_fd:
            atomic_write_json_in_dir(dir_fd, AUTH_STATE_FILENAME, auth_data)

    def read_sync_state(self) -> dict:
        with self._locked_dir() as dir_fd:
            data = read_json_in_dir(dir_fd, SYNC_STATE_FILENAME, default={})
            return data if isinstance(data, dict) else {}

    def write_sync_state(self, sync_data: dict) -> None:
        with self._locked_dir() as dir_fd:
            atomic_write_json_in_dir(dir_fd, SYNC_STATE_FILENAME, sync_data)

    def get_next_batch(self) -> str | None:
        sync_state = self.read_sync_state()
        token = sync_state.get("next_batch")
        if isinstance(token, str) and token.strip():
            return token.strip()
        companion_state = self.read_companion_state()
        token = companion_state.get("next_batch")
        if isinstance(token, str) and token.strip():
            return token.strip()
        return None

    def advance_next_batch(self, next_batch: str) -> None:
        if not isinstance(next_batch, str) or not next_batch.strip():
            raise ValueError("next_batch must be a non-empty string")
        clean_batch = next_batch.strip()
        with self._locked_dir() as dir_fd:
            sync_data = read_json_in_dir(dir_fd, SYNC_STATE_FILENAME, default={})
            if not isinstance(sync_data, dict):
                sync_data = {}
            sync_data["next_batch"] = clean_batch
            sync_data["updated_at_ms"] = now_ms()
            atomic_write_json_in_dir(dir_fd, SYNC_STATE_FILENAME, sync_data)

            comp_data = self._read_companion_state_unlocked(dir_fd)
            comp_data["next_batch"] = clean_batch
            comp_data["updated_at_ms"] = sync_data["updated_at_ms"]
            atomic_write_json_in_dir(dir_fd, COMPANION_STATE_FILENAME, comp_data)

    def read_outbox(self) -> dict:
        with self._locked_dir() as dir_fd:
            data = read_json_in_dir(dir_fd, OUTBOX_FILENAME, default={"pending": {}})
            if not isinstance(data, dict) or not isinstance(data.get("pending"), dict):
                return {"pending": {}}
            return data

    def write_outbox(self, outbox_data: dict) -> None:
        with self._locked_dir() as dir_fd:
            atomic_write_json_in_dir(dir_fd, OUTBOX_FILENAME, outbox_data)

    def _default_companion_state(self) -> dict:
        return {
            "version": 1,
            "agent_name": self.agent_name,
            "room_id": self.room_id,
            "next_batch": None,
            "provisional_cutoff_ms": None,
            "active_session_key": None,
            "cutoff_ms": None,
            "is_provisional": False,
            "runs": {},
            "assessed_events": {},
            "wakeups": {
                "targets": {},
                "martin_roots": {},
            },
            "updated_at_ms": self.started_at_ms,
        }

    def _read_companion_state_unlocked(self, dir_fd: int) -> dict:
        default = self._default_companion_state()
        data = read_json_in_dir(dir_fd, COMPANION_STATE_FILENAME, default=None)
        if not isinstance(data, dict):
            return default
        merged = dict(default)
        merged.update(data)
        if not isinstance(merged.get("runs"), dict):
            merged["runs"] = {}
        if not isinstance(merged.get("assessed_events"), dict):
            merged["assessed_events"] = {}
        if not isinstance(merged.get("wakeups"), dict):
            merged["wakeups"] = {
                "targets": {},
                "martin_roots": {},
                "last_moderator_reset_ts_ms": 0,
            }
        else:
            merged["wakeups"].setdefault("targets", {})
            merged["wakeups"].setdefault("martin_roots", {})
            merged["wakeups"].setdefault("last_moderator_reset_ts_ms", 0)
        return merged

    def read_companion_state(self) -> dict:
        with self._locked_dir() as dir_fd:
            return self._read_companion_state_unlocked(dir_fd)

    def _prune_companion_state_unlocked(
        self,
        state: dict,
        cap: int = COMPANION_STATE_ENTRY_CAP,
    ) -> None:
        max_entries = max(1, _safe_int(cap, COMPANION_STATE_ENTRY_CAP))
        assessed = state.get("assessed_events")
        if isinstance(assessed, dict) and len(assessed) > max_entries:
            ordered_keys = sorted(
                assessed.keys(),
                key=lambda k: _safe_int(_as_dict(assessed.get(k)).get("assessed_at_ms"), 0),
            )
            for k in ordered_keys[: len(assessed) - max_entries]:
                assessed.pop(k, None)

        runs = state.get("runs")
        if isinstance(runs, dict) and len(runs) > max_entries:
            evictable_keys = sorted(
                runs.keys(),
                key=lambda k: (
                    0 if bool(_as_dict(runs.get(k)).get("cleaned_up")) else 1,
                    _safe_int(_as_dict(runs.get(k)).get("updated_at_ms"), 0),
                ),
            )
            excess = len(runs) - max_entries
            for k in evictable_keys[:excess]:
                runs.pop(k, None)

        wakeups = state.get("wakeups")
        if isinstance(wakeups, dict):
            targets = wakeups.get("targets")
            if isinstance(targets, dict) and len(targets) > max_entries:
                evictable_targets = sorted(
                    targets.keys(),
                    key=lambda k: (
                        0 if _as_dict(targets.get(k)).get("status") != "pending" else 1,
                        _safe_int(_as_dict(targets.get(k)).get("origin_server_ts"), 0),
                    ),
                )
                for k in evictable_targets[: len(targets) - max_entries]:
                    targets.pop(k, None)
            roots = wakeups.get("martin_roots")
            if isinstance(roots, dict) and len(roots) > max_entries:
                ordered_roots = sorted(
                    roots.keys(),
                    key=lambda k: _safe_int(_as_dict(roots.get(k)).get("updated_at_ms"), 0),
                )
                for k in ordered_roots[: len(roots) - max_entries]:
                    roots.pop(k, None)

    def write_companion_state(self, state_data: dict) -> None:
        with self._locked_dir() as dir_fd:
            current = self._read_companion_state_unlocked(dir_fd)
            current.update(state_data)
            self._prune_companion_state_unlocked(current)
            current["updated_at_ms"] = now_ms()
            atomic_write_json_in_dir(dir_fd, COMPANION_STATE_FILENAME, current)

    def update_run_state(self, session_key: str, run_id: str, **fields) -> dict:
        key = make_run_state_key(session_key, run_id)
        with self._locked_dir() as dir_fd:
            state = self._read_companion_state_unlocked(dir_fd)
            runs = state.setdefault("runs", {})
            entry = runs.get(key)
            if not isinstance(entry, dict):
                entry = {
                    "session_key": session_key,
                    "run_id": run_id,
                    "bound_event_id": None,
                    "active_reaction_event_id": None,
                    "active_reaction_key": None,
                    "progress_event_id": None,
                    "last_progress_at_ms": None,
                    "cleaned_up": False,
                    "completed_reaction_event_id": None,
                    "updated_at_ms": now_ms(),
                }
            entry.update(fields)
            entry["updated_at_ms"] = now_ms()
            runs[key] = entry
            self._prune_companion_state_unlocked(state)
            state["updated_at_ms"] = entry["updated_at_ms"]
            atomic_write_json_in_dir(dir_fd, COMPANION_STATE_FILENAME, state)
            return dict(entry)

    def get_run_state(self, session_key: str, run_id: str) -> dict | None:
        key = make_run_state_key(session_key, run_id)
        state = self.read_companion_state()
        entry = state.get("runs", {}).get(key)
        return dict(entry) if isinstance(entry, dict) else None

    def record_assessed_event(
        self,
        event_id: str,
        session_key: str,
        status: str,
        badge: str | None = None,
        reaction_event_id: str | None = None,
        assessed_at_ms: int | None = None,
    ) -> dict:
        ts_val = _safe_int(assessed_at_ms, now_ms()) if assessed_at_ms is not None else now_ms()
        record = {
            "event_id": event_id,
            "session_key": session_key,
            "status": status,
            "badge": badge,
            "reaction_event_id": reaction_event_id,
            "assessed_at_ms": ts_val,
        }
        with self._locked_dir() as dir_fd:
            state = self._read_companion_state_unlocked(dir_fd)
            assessed = state.setdefault("assessed_events", {})
            assessed[event_id] = record
            self._prune_companion_state_unlocked(state)
            state["updated_at_ms"] = ts_val
            atomic_write_json_in_dir(dir_fd, COMPANION_STATE_FILENAME, state)
        return record

    def get_assessed_event(self, event_id: str) -> dict | None:
        state = self.read_companion_state()
        rec = state.get("assessed_events", {}).get(event_id)
        return dict(rec) if isinstance(rec, dict) else None

    def record_local_reaction(
        self,
        target_event_id: str,
        reaction_event_id: str,
        sender: str,
        key: str,
        ts_ms: int | None = None,
    ) -> None:
        if not target_event_id or not reaction_event_id or not key:
            return
        stamp = _safe_int(ts_ms, now_ms()) if ts_ms is not None else now_ms()
        with self._locked_dir() as dir_fd:
            room_data = self._read_room_events_unlocked(dir_fd)
            recent_events: list[dict] = room_data["recent_events"]
            reaction_index: dict[str, str] = room_data["reaction_index"]
            for ev in recent_events:
                if isinstance(ev, dict) and ev.get("event_id") == target_event_id:
                    rxns = ev.setdefault("reactions", {})
                    rxns[reaction_event_id] = {
                        "sender": sender,
                        "key": key,
                        "ts_ms": stamp,
                    }
                    reaction_index[reaction_event_id] = target_event_id
                    room_data["updated_at_ms"] = stamp
                    atomic_write_json_in_dir(dir_fd, ROOM_EVENTS_FILENAME, room_data)
                    break

    def record_local_redaction(self, redacted_event_id: str, ts_ms: int | None = None) -> None:
        if not redacted_event_id:
            return
        stamp = _safe_int(ts_ms, now_ms()) if ts_ms is not None else now_ms()
        with self._locked_dir() as dir_fd:
            room_data = self._read_room_events_unlocked(dir_fd)
            recent_events: list[dict] = room_data["recent_events"]
            reaction_index: dict[str, str] = room_data["reaction_index"]
            target_id = reaction_index.pop(redacted_event_id, None)
            changed = target_id is not None
            for ev in recent_events:
                if not isinstance(ev, dict):
                    continue
                rxns = ev.get("reactions")
                if isinstance(rxns, dict) and redacted_event_id in rxns:
                    rxns.pop(redacted_event_id, None)
                    changed = True
            if any(isinstance(ev, dict) and ev.get("event_id") == redacted_event_id for ev in recent_events):
                recent_events[:] = [
                    ev for ev in recent_events if not (isinstance(ev, dict) and ev.get("event_id") == redacted_event_id)
                ]
                changed = True
            if changed:
                room_data["updated_at_ms"] = stamp
                atomic_write_json_in_dir(dir_fd, ROOM_EVENTS_FILENAME, room_data)

    def read_active_turn(self) -> dict | None:
        """Read active-turn.json under active-turn.lock without modifying it."""
        dir_fd = open_private_directory(self.state_dir, create=True)
        try:
            try:
                lock_fd = os.open(
                    ACTIVE_TURN_LOCK_FILENAME,
                    os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK,
                    dir_fd=dir_fd,
                )
            except FileNotFoundError:
                lock_fd = None
            if lock_fd is not None:
                with os.fdopen(lock_fd, "r", encoding="utf-8") as lock_file:
                    check_private(lock_file.fileno(), directory=False)
                    fcntl.flock(lock_file.fileno(), fcntl.LOCK_SH)
                    try:
                        data = read_json_in_dir(dir_fd, ACTIVE_TURN_FILENAME, default=None)
                    finally:
                        fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
            else:
                data = read_json_in_dir(dir_fd, ACTIVE_TURN_FILENAME, default=None)
            return data if isinstance(data, dict) else None
        finally:
            os.close(dir_fd)

    def _default_room_events(self) -> dict:
        return {
            "version": 1,
            "room_id": self.room_id,
            "recent_events": [],
            "reaction_index": {},
            "unmentioned_by_session": {},
            "updated_at_ms": self.started_at_ms,
        }

    def _read_room_events_unlocked(self, dir_fd: int) -> dict:
        default = self._default_room_events()
        data = read_json_in_dir(dir_fd, ROOM_EVENTS_FILENAME, default=None)
        if not isinstance(data, dict):
            return default
        merged = dict(default)
        merged.update(data)
        if not isinstance(merged.get("recent_events"), list):
            merged["recent_events"] = []
        if not isinstance(merged.get("reaction_index"), dict):
            merged["reaction_index"] = {}
        if not isinstance(merged.get("unmentioned_by_session"), dict):
            merged["unmentioned_by_session"] = {}
        return merged

    def read_room_events(self) -> dict:
        with self._locked_dir() as dir_fd:
            return self._read_room_events_unlocked(dir_fd)

    def write_room_events(self, room_events_data: dict) -> None:
        with self._locked_dir() as dir_fd:
            room_events_data["updated_at_ms"] = now_ms()
            atomic_write_json_in_dir(dir_fd, ROOM_EVENTS_FILENAME, room_events_data)

    def ensure_session_partition(self, active_session_key: str) -> dict:
        with self._locked_dir() as dir_fd:
            room_data = self._read_room_events_unlocked(dir_fd)
            partitions = room_data.setdefault("unmentioned_by_session", {})
            partition = partitions.get(active_session_key)
            if not isinstance(partition, dict):
                partition = {
                    "events": [],
                    "evicted_unmentioned_count": 0,
                }
                partitions[active_session_key] = partition
                room_data["updated_at_ms"] = now_ms()
                atomic_write_json_in_dir(dir_fd, ROOM_EVENTS_FILENAME, room_data)
            return dict(partition)

    def apply_timeline_events(
        self,
        events: list[dict],
        active_session_key: str,
        cutoff_ms: int,
        self_user_id: str,
        seed_only: bool = False,
        recent_cap: int = RECENT_EVENTS_CAP,
        unmentioned_cap: int = UNMENTIONED_EVENTS_CAP,
    ) -> list[dict]:
        """Apply Matrix room timeline events to room-events.json and return newly ingested records."""
        processed: list[dict] = []
        with self._locked_dir() as dir_fd:
            room_data = self._read_room_events_unlocked(dir_fd)
            recent_events: list[dict] = room_data["recent_events"]
            reaction_index: dict[str, str] = room_data["reaction_index"]
            partitions: dict[str, dict] = room_data["unmentioned_by_session"]

            partition = partitions.get(active_session_key)
            if not isinstance(partition, dict):
                partition = {"events": [], "evicted_unmentioned_count": 0}
                partitions[active_session_key] = partition
            if not isinstance(partition.get("events"), list):
                partition["events"] = []
            if not isinstance(partition.get("evicted_unmentioned_count"), int):
                partition["evicted_unmentioned_count"] = 0

            recent_by_id: dict[str, dict] = {
                ev["event_id"]: ev
                for ev in recent_events
                if isinstance(ev, dict) and isinstance(ev.get("event_id"), str)
            }

            for raw_ev in events:
                if not isinstance(raw_ev, dict):
                    continue
                ev_type = raw_ev.get("type")
                event_id = raw_ev.get("event_id")
                sender = raw_ev.get("sender")
                if not isinstance(event_id, str) or not event_id or not isinstance(sender, str):
                    continue
                _, ts_ms = normalize_ts(raw_ev.get("origin_server_ts"))
                content = _as_dict(raw_ev.get("content"))
                unsigned = _as_dict(raw_ev.get("unsigned"))

                if ev_type == "m.room.message":
                    relates = _as_dict(content.get("m.relates_to"))
                    rel_type = relates.get("rel_type")
                    if rel_type == "m.replace":
                        target_id = relates.get("event_id")
                        raw_new = content.get("m.new_content")
                        new_content = raw_new if isinstance(raw_new, dict) else content
                        new_body = new_content.get("body")
                        new_msgtype = new_content.get("msgtype")
                        if isinstance(target_id, str) and isinstance(new_body, str):
                            target_ev = recent_by_id.get(target_id)
                            if isinstance(target_ev, dict) and target_ev.get("sender") == sender:
                                target_ev["body"] = new_body
                                if isinstance(new_msgtype, str) and new_msgtype in (
                                    "m.text",
                                    "m.notice",
                                    "m.audio",
                                ):
                                    target_ev["msgtype"] = new_msgtype
                                target_ev["edited_at_ms"] = ts_ms
                                target_ev["mentioned_bots"] = sorted(
                                    extract_mentioned_bots(new_body, new_content)
                                )
                                target_ev["is_new_command"] = is_new_command_message(
                                    new_body, new_content
                                )
                            for part in partitions.values():
                                if not isinstance(part, dict):
                                    continue
                                for u_ev in part.get("events", []):
                                    if (
                                        isinstance(u_ev, dict)
                                        and u_ev.get("event_id") == target_id
                                        and u_ev.get("sender") == sender
                                    ):
                                        u_ev["body"] = new_body
                                        u_ev["edited_at_ms"] = ts_ms
                        continue

                    msgtype = content.get("msgtype")
                    body = content.get("body")
                    is_conv_msg = is_conversational_room_message(
                        msgtype,
                        body,
                        sender=sender,
                        content=content,
                    )
                    if (msgtype != "m.notice" and not is_conv_msg) or not isinstance(body, str):
                        continue

                    if event_id in recent_by_id:
                        continue

                    mentioned_bots = sorted(extract_mentioned_bots(body, content))
                    is_new_cmd = is_new_command_message(body, content)
                    mentions_self = self_user_id in mentioned_bots

                    record: dict[str, object] = {
                        "event_id": event_id,
                        "sender": sender,
                        "msgtype": msgtype,
                        "body": body,
                        "origin_server_ts": ts_ms,
                        "mentioned_bots": mentioned_bots,
                        "mentions_self": mentions_self,
                        "is_new_command": is_new_cmd,
                        "seed": bool(seed_only),
                        "reactions": {},
                    }
                    if msgtype == "m.audio" and isinstance(content.get("filename"), str):
                        record["filename"] = content["filename"]
                    relay_payload = content.get(COMPANION_RELAY_KEY)
                    if msgtype == "m.notice" and isinstance(relay_payload, dict):
                        record["companion_relay"] = dict(relay_payload)
                    recent_events.append(record)
                    recent_by_id[event_id] = record
                    processed.append(dict(record))

                    while len(recent_events) > recent_cap:
                        evicted = recent_events.pop(0)
                        evicted_id = evicted.get("event_id")
                        if isinstance(evicted_id, str):
                            recent_by_id.pop(evicted_id, None)
                            for rxn_id in list(_as_dict(evicted.get("reactions")).keys()):
                                reaction_index.pop(rxn_id, None)

                    is_eligible_unmentioned = (
                        is_conv_msg
                        and sender in ALLOWLIST_USER_IDS
                        and sender != self_user_id
                        and not mentions_self
                        and not is_new_cmd
                        and ts_ms >= cutoff_ms
                    )
                    if is_eligible_unmentioned:
                        u_events: list[dict] = partition["events"]
                        if not any(
                            isinstance(e, dict) and e.get("event_id") == event_id
                            for e in u_events
                        ):
                            u_record: dict[str, object] = {
                                "event_id": event_id,
                                "sender": sender,
                                "msgtype": msgtype,
                                "body": body,
                                "origin_server_ts": ts_ms,
                                "mentioned_bots": mentioned_bots,
                                "seed": bool(seed_only),
                            }
                            if msgtype == "m.audio" and isinstance(content.get("filename"), str):
                                u_record["filename"] = content["filename"]
                            u_events.append(u_record)
                            while len(u_events) > unmentioned_cap:
                                u_events.pop(0)
                                partition["evicted_unmentioned_count"] = (
                                    _safe_int(partition.get("evicted_unmentioned_count"), 0) + 1
                                )

                elif ev_type == "m.reaction":
                    relates = _as_dict(content.get("m.relates_to"))
                    if relates.get("rel_type") != "m.annotation":
                        continue
                    target_id = relates.get("event_id")
                    key = relates.get("key")
                    if not isinstance(target_id, str) or not target_id or not isinstance(key, str) or not key:
                        continue
                    target_ev = recent_by_id.get(target_id)
                    if isinstance(target_ev, dict):
                        reactions_map = target_ev.setdefault("reactions", {})
                        reactions_map[event_id] = {
                            "sender": sender,
                            "key": key,
                            "ts_ms": ts_ms,
                        }
                        reaction_index[event_id] = target_id
                    processed.append(
                        {
                            "type": "m.reaction",
                            "event_id": event_id,
                            "target_event_id": target_id,
                            "sender": sender,
                            "key": key,
                            "origin_server_ts": ts_ms,
                            "seed": bool(seed_only),
                        }
                    )

                elif ev_type == "m.room.redaction":
                    redacted_because = _as_dict(unsigned.get("redacted_because"))
                    redacts_id = (
                        raw_ev.get("redacts")
                        or content.get("redacts")
                        or redacted_because.get("redacts")
                    )
                    if not isinstance(redacts_id, str) or not redacts_id:
                        continue
                    target_msg_id = reaction_index.pop(redacts_id, None)
                    if isinstance(target_msg_id, str) and target_msg_id in recent_by_id:
                        target_msg = recent_by_id[target_msg_id]
                        rxns = target_msg.get("reactions")
                        if isinstance(rxns, dict):
                            rxns.pop(redacts_id, None)
                    else:
                        for msg in recent_events:
                            if isinstance(msg, dict):
                                rxns = msg.get("reactions")
                                if isinstance(rxns, dict) and redacts_id in rxns:
                                    rxns.pop(redacts_id, None)

                    if redacts_id in recent_by_id:
                        redacted_msg = recent_by_id.pop(redacts_id)
                        recent_events[:] = [
                            ev for ev in recent_events if ev.get("event_id") != redacts_id
                        ]
                        for rxn_id in list(_as_dict(redacted_msg.get("reactions")).keys()):
                            reaction_index.pop(rxn_id, None)

                    for part in partitions.values():
                        if isinstance(part, dict) and isinstance(part.get("events"), list):
                            part["events"] = [
                                ev
                                for ev in part["events"]
                                if isinstance(ev, dict) and ev.get("event_id") != redacts_id
                            ]

                    processed.append(
                        {
                            "type": "m.room.redaction",
                            "event_id": event_id,
                            "redacts": redacts_id,
                            "sender": sender,
                            "origin_server_ts": ts_ms,
                            "seed": bool(seed_only),
                        }
                    )

            room_data["updated_at_ms"] = now_ms()
            atomic_write_json_in_dir(dir_fd, ROOM_EVENTS_FILENAME, room_data)

        return processed


class SessionGenerationResolver:
    """Resolve (active_session_key, cutoff_ms, is_provisional) from moltis.db and durable companion state."""

    def __init__(
        self,
        data_dir: Path | str,
        state_store: CompanionStateStore,
        agent_name: str,
        room_id: str = DEFAULT_ROOM_ID,
    ):
        self.data_dir = Path(data_dir)
        self.state_store = state_store
        self.agent_name = agent_name
        self.room_id = room_id

    @property
    def default_session_key(self) -> str:
        return f"matrix:matrix-{self.agent_name}:{self.room_id}"

    @property
    def account_id(self) -> str:
        return f"matrix-{self.agent_name}"

    def _query_moltis_db(self) -> tuple[str | None, int | None]:
        db_path = self.data_dir / "moltis.db"
        if not db_path.is_file():
            return None, None
        override_key: str | None = None
        created_at_ms: int | None = None
        try:
            conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True, timeout=2.0)
            try:
                tables = {
                    row[0]
                    for row in conn.execute(
                        "SELECT name FROM sqlite_master WHERE type = 'table'"
                    ).fetchall()
                }
                if "channel_sessions" in tables:
                    cols = {
                        row[1]
                        for row in conn.execute("PRAGMA table_info(channel_sessions)").fetchall()
                    }
                    if {"channel_type", "account_id", "chat_id", "session_key"}.issubset(cols):
                        if "thread_id" in cols:
                            row = conn.execute(
                                "SELECT session_key FROM channel_sessions "
                                "WHERE channel_type = 'matrix' AND account_id = ? AND chat_id = ? "
                                "AND (thread_id = '' OR thread_id IS NULL) "
                                "LIMIT 1",
                                (self.account_id, self.room_id),
                            ).fetchone()
                        else:
                            row = conn.execute(
                                "SELECT session_key FROM channel_sessions "
                                "WHERE channel_type = 'matrix' AND account_id = ? AND chat_id = ? "
                                "LIMIT 1",
                                (self.account_id, self.room_id),
                            ).fetchone()
                        if row and isinstance(row[0], str) and row[0].strip():
                            override_key = row[0].strip()

                resolved_key = override_key or self.default_session_key
                if "sessions" in tables:
                    s_cols = {
                        row[1]
                        for row in conn.execute("PRAGMA table_info(sessions)").fetchall()
                    }
                    if "created_at" in s_cols:
                        if "key" in s_cols:
                            s_row = conn.execute(
                                "SELECT created_at FROM sessions WHERE key = ? LIMIT 1",
                                (resolved_key,),
                            ).fetchone()
                        elif "session_key" in s_cols:
                            s_row = conn.execute(
                                "SELECT created_at FROM sessions WHERE session_key = ? LIMIT 1",
                                (resolved_key,),
                            ).fetchone()
                        elif "id" in s_cols:
                            s_row = conn.execute(
                                "SELECT created_at FROM sessions WHERE id = ? LIMIT 1",
                                (resolved_key,),
                            ).fetchone()
                        else:
                            s_row = None
                        if s_row and s_row[0] is not None:
                            _, ts_ms = normalize_ts(s_row[0])
                            if ts_ms > 0:
                                created_at_ms = ts_ms
            finally:
                conn.close()
        except sqlite3.Error as exc:
            sys.stderr.write(f"moltis-matrix-companion sqlite warning: {exc}\n")
        return override_key, created_at_ms

    def resolve(self, now_override_ms: int | None = None) -> dict:
        override_key, session_created_at_ms = self._query_moltis_db()
        active_session_key = override_key or self.default_session_key
        is_new_key = active_session_key.startswith("session:")

        state = self.state_store.read_companion_state()
        provisional_cutoff_ms = state.get("provisional_cutoff_ms")
        if not isinstance(provisional_cutoff_ms, int) or provisional_cutoff_ms <= 0:
            provisional_cutoff_ms = (
                _safe_int(now_override_ms, self.state_store.started_at_ms)
                if now_override_ms is not None
                else self.state_store.started_at_ms
            )

        if is_new_key:
            # /new creates the sessions row immediately; cutoff_ms is sessions.created_at_ms.
            if session_created_at_ms is not None and session_created_at_ms > 0:
                cutoff_ms = session_created_at_ms
                is_provisional = False
            else:
                cutoff_ms = provisional_cutoff_ms
                is_provisional = True
        else:
            # Default session key (matrix:matrix-<agent>:!the-cauldron:matrix.wimpys.world)
            if session_created_at_ms is None or session_created_at_ms <= 0:
                cutoff_ms = provisional_cutoff_ms
                is_provisional = True
            else:
                cutoff_ms = min(provisional_cutoff_ms, session_created_at_ms)
                is_provisional = False

        previous_session_key = state.get("active_session_key")
        session_changed = (
            isinstance(previous_session_key, str)
            and bool(previous_session_key)
            and previous_session_key != active_session_key
        )

        if (
            state.get("provisional_cutoff_ms") != provisional_cutoff_ms
            or state.get("active_session_key") != active_session_key
            or state.get("cutoff_ms") != cutoff_ms
            or state.get("is_provisional") != is_provisional
        ):
            self.state_store.write_companion_state(
                {
                    "provisional_cutoff_ms": provisional_cutoff_ms,
                    "active_session_key": active_session_key,
                    "cutoff_ms": cutoff_ms,
                    "is_provisional": is_provisional,
                }
            )
        self.state_store.ensure_session_partition(active_session_key)

        return {
            "active_session_key": active_session_key,
            "cutoff_ms": cutoff_ms,
            "provisional_cutoff_ms": provisional_cutoff_ms,
            "session_created_at_ms": session_created_at_ms,
            "is_provisional": is_provisional,
            "session_changed": session_changed,
            "previous_session_key": previous_session_key,
        }


class MatrixClient:
    """Matrix Client-Server v3 HTTP client with durable token and deterministic txnId outbox."""

    def __init__(
        self,
        homeserver_url: str,
        self_user_id: str,
        agent_name: str,
        room_id: str,
        password_path: Path | str | None,
        state_store: CompanionStateStore,
        timeout: float = 35.0,
    ):
        self.homeserver_url = homeserver_url.rstrip("/")
        _validate_http_url(self.homeserver_url)
        self.self_user_id = self_user_id
        self.agent_name = agent_name
        self.room_id = room_id
        self.password_path = password_path
        self.state_store = state_store
        self.timeout = timeout
        self.device_id = derive_device_id(agent_name)

    def _password_identity_hash(self, password: str) -> str:
        payload = json.dumps(
            [self.homeserver_url, self.self_user_id, self.device_id, password],
            ensure_ascii=True,
        ).encode("utf-8")
        return hashlib.sha256(payload).hexdigest()

    def _request(
        self,
        method: str,
        path: str,
        query: dict | None = None,
        body: dict | None = None,
        token: str | None = None,
        timeout: float | None = None,
    ) -> dict:
        url = f"{self.homeserver_url}{path}"
        if query:
            clean_q = {k: str(v) for k, v in query.items() if v is not None}
            if clean_q:
                url = f"{url}?{urllib.parse.urlencode(clean_q)}"
        headers = {
            "Accept": "application/json",
            "Content-Type": "application/json",
        }
        if token:
            headers["Authorization"] = f"Bearer {token}"
        raw_body = json.dumps(body, ensure_ascii=False).encode("utf-8") if body is not None else None
        status, raw = _http_json_request(
            url=url,
            method=method,
            headers=headers,
            raw_body=raw_body,
            timeout=timeout or self.timeout,
            allow_loopback_self_signed=False,
        )
        if status >= 400:
            errcode = None
            err_msg = ""
            try:
                err_payload = json.loads(raw.decode("utf-8", errors="replace"))
            except (UnicodeDecodeError, ValueError):
                err_payload = None
            if isinstance(err_payload, dict):
                errcode = err_payload.get("errcode")
                err_msg = str(err_payload.get("error") or "")
            raise MatrixAPIError(status, errcode, err_msg)
        if not raw.strip():
            return {}
        try:
            data = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, ValueError) as exc:
            raise ValueError("Invalid JSON in Matrix API response") from exc
        return data if isinstance(data, dict) else {}

    def login(self, force: bool = False) -> str:
        password = read_credential(self.password_path)
        identity_hash = self._password_identity_hash(password)
        if not force:
            cached = self.state_store.read_auth()
            token = cached.get("access_token")
            if (
                isinstance(token, str)
                and token.strip()
                and cached.get("identity") == identity_hash
                and cached.get("device_id") == self.device_id
                and cached.get("user_id") == self.self_user_id
            ):
                if not isinstance(cached.get("token_generation_id"), str) or not cached.get("token_generation_id"):
                    cached = dict(cached)
                    cached["token_generation_id"] = f"tgen-{uuid.uuid4().hex}"
                    self.state_store.write_auth(cached)
                return token.strip()

        login_body = {
            "type": "m.login.password",
            "identifier": {
                "type": "m.id.user",
                "user": self.self_user_id,
            },
            "password": password,
            "device_id": self.device_id,
        }
        resp = self._request("POST", "/_matrix/client/v3/login", body=login_body, timeout=20.0)
        token = resp.get("access_token")
        if not isinstance(token, str) or not token.strip():
            raise ValueError("Matrix login response missing access_token")
        auth_record = {
            "access_token": token.strip(),
            "token_generation_id": f"tgen-{uuid.uuid4().hex}",
            "device_id": resp.get("device_id") or self.device_id,
            "user_id": resp.get("user_id") or self.self_user_id,
            "identity": identity_hash,
            "updated_at_ms": now_ms(),
        }
        self.state_store.write_auth(auth_record)
        return auth_record["access_token"]

    def get_token_generation_id(self) -> str:
        """Return the current opaque token_generation_id from auth.json without exposing access_token."""
        self.login(force=False)
        cached = self.state_store.read_auth()
        tgen = cached.get("token_generation_id")
        if isinstance(tgen, str) and tgen.strip():
            return tgen.strip()
        new_tgen = f"tgen-{uuid.uuid4().hex}"
        cached = dict(cached)
        cached["token_generation_id"] = new_tgen
        self.state_store.write_auth(cached)
        return new_tgen

    def _authenticated_request(
        self,
        method: str,
        path: str,
        query: dict | None = None,
        body: dict | None = None,
        timeout: float | None = None,
        allow_relogin_retry: bool = True,
    ) -> dict:
        token = self.login(force=False)
        try:
            return self._request(method, path, query=query, body=body, token=token, timeout=timeout)
        except MatrixAPIError as exc:
            if (exc.status == 401 or exc.errcode == "M_UNKNOWN_TOKEN") and allow_relogin_retry:
                token = self.login(force=True)
                return self._request(method, path, query=query, body=body, token=token, timeout=timeout)
            raise

    def sync(self, since: str | None = None, timeout_ms: int = 25000) -> dict:
        query: dict[str, object] = {"timeout": timeout_ms if since else 0}
        if since:
            query["since"] = since
        http_timeout = max(10.0, (timeout_ms / 1000.0) + 10.0)
        return self._authenticated_request(
            "GET",
            "/_matrix/client/v3/sync",
            query=query,
            timeout=http_timeout,
        )

    def _enqueue_outbox(self, txn_id: str, item: dict) -> None:
        outbox = self.state_store.read_outbox()
        pending = outbox.setdefault("pending", {})
        if txn_id not in pending:
            pending[txn_id] = item
            self.state_store.write_outbox(outbox)

    def _complete_outbox(self, txn_id: str) -> None:
        outbox = self.state_store.read_outbox()
        pending = outbox.get("pending", {})
        if txn_id in pending:
            pending.pop(txn_id, None)
            self.state_store.write_outbox(outbox)

    def flush_outbox(self) -> list[dict]:
        """Flush pending outbox transactions using their saved deterministic txnIds."""
        outbox = self.state_store.read_outbox()
        pending = outbox.get("pending", {})
        results: list[dict] = []
        for txn_id, item in list(pending.items()):
            if not isinstance(item, dict):
                self._complete_outbox(txn_id)
                continue
            if item.get("kind") in ("wakeup_notice", "relay_notice"):
                # Wakeup and relay notices are reconciled by ModeratorWakeupCoordinator after /sync
                # so token rotation with incomplete timeline evidence holds uncertain sends safely.
                continue
            method = item.get("method", "PUT")
            path = item.get("path")
            body = item.get("body")
            if not isinstance(path, str) or not isinstance(body, dict):
                self._complete_outbox(txn_id)
                continue
            resp = self._authenticated_request(method, path, body=body, timeout=20.0)
            self._complete_outbox(txn_id)
            results.append({"txn_id": txn_id, "event_id": resp.get("event_id")})
        return results

    def send_event_with_txn(
        self,
        path: str,
        body: dict,
        txn_id: str,
        kind: str,
        metadata: dict | None = None,
        allow_relogin_retry: bool = True,
    ) -> str | None:
        item = {
            "txn_id": txn_id,
            "kind": kind,
            "method": "PUT",
            "path": path,
            "body": body,
            "metadata": metadata or {},
            "created_at_ms": now_ms(),
        }
        self._enqueue_outbox(txn_id, item)
        resp = self._authenticated_request(
            "PUT",
            path,
            body=body,
            timeout=20.0,
            allow_relogin_retry=allow_relogin_retry,
        )
        self._complete_outbox(txn_id)
        event_id = resp.get("event_id")
        return event_id if isinstance(event_id, str) else None

    def send_reaction(
        self,
        target_event_id: str,
        key: str,
        scope_id: str = "",
    ) -> str | None:
        txn_id = make_deterministic_txn_id(
            self.agent_name,
            "reaction",
            self.room_id,
            target_event_id,
            key,
            scope_id or "default",
        )
        room_q = urllib.parse.quote(self.room_id, safe="")
        txn_q = urllib.parse.quote(txn_id, safe="")
        path = f"/_matrix/client/v3/rooms/{room_q}/send/m.reaction/{txn_q}"
        body = {
            "m.relates_to": {
                "rel_type": "m.annotation",
                "event_id": target_event_id,
                "key": key,
            }
        }
        return self.send_event_with_txn(
            path,
            body,
            txn_id,
            kind="reaction",
            metadata={"target_event_id": target_event_id, "key": key},
        )

    def redact_event(
        self,
        target_event_id: str,
        reason: str | None = None,
        scope_id: str = "",
    ) -> str | None:
        txn_id = make_deterministic_txn_id(
            self.agent_name,
            "redact",
            self.room_id,
            target_event_id,
            scope_id or "default",
        )
        room_q = urllib.parse.quote(self.room_id, safe="")
        event_q = urllib.parse.quote(target_event_id, safe="")
        txn_q = urllib.parse.quote(txn_id, safe="")
        path = f"/_matrix/client/v3/rooms/{room_q}/redact/{event_q}/{txn_q}"
        body = {"reason": reason} if reason else {}
        return self.send_event_with_txn(
            path,
            body,
            txn_id,
            kind="redact",
            metadata={"target_event_id": target_event_id},
        )

    def send_notice(
        self,
        body_text: str,
        scope_id: str,
        mentions_user_ids: list[str] | None = None,
        extra_content: dict | None = None,
        kind: str = "notice",
        metadata: dict | None = None,
        allow_relogin_retry: bool = True,
    ) -> str | None:
        txn_id = make_deterministic_txn_id(
            self.agent_name,
            "notice",
            self.room_id,
            scope_id,
        )
        room_q = urllib.parse.quote(self.room_id, safe="")
        txn_q = urllib.parse.quote(txn_id, safe="")
        path = f"/_matrix/client/v3/rooms/{room_q}/send/m.room.message/{txn_q}"
        mentions_obj: dict[str, object] = (
            {"user_ids": list(mentions_user_ids)} if mentions_user_ids else {}
        )
        body: dict[str, object] = {
            "msgtype": "m.notice",
            "body": body_text,
            "m.mentions": mentions_obj,
        }
        if isinstance(extra_content, dict):
            for k, v in extra_content.items():
                if k not in ("msgtype", "body", "m.mentions"):
                    body[k] = v
        merged_meta = {"scope_id": scope_id}
        if isinstance(metadata, dict):
            merged_meta.update(metadata)
        return self.send_event_with_txn(
            path,
            body,
            txn_id,
            kind=kind,
            metadata=merged_meta,
            allow_relogin_retry=allow_relogin_retry,
        )

    def edit_notice(
        self,
        target_event_id: str,
        body_text: str,
        scope_id: str,
    ) -> str | None:
        txn_id = make_deterministic_txn_id(
            self.agent_name,
            "edit-notice",
            self.room_id,
            target_event_id,
            scope_id,
        )
        room_q = urllib.parse.quote(self.room_id, safe="")
        txn_q = urllib.parse.quote(txn_id, safe="")
        path = f"/_matrix/client/v3/rooms/{room_q}/send/m.room.message/{txn_q}"
        body = {
            "msgtype": "m.notice",
            "body": f"* {body_text}",
            "m.mentions": {},
            "m.new_content": {
                "msgtype": "m.notice",
                "body": body_text,
                "m.mentions": {},
            },
            "m.relates_to": {
                "rel_type": "m.replace",
                "event_id": target_event_id,
            },
        }
        return self.send_event_with_txn(
            path,
            body,
            txn_id,
            kind="edit_notice",
            metadata={"target_event_id": target_event_id, "scope_id": scope_id},
        )


class MoltisRpcClient:
    """Loopback JSON-RPC client for Moltis POST /api/rpc (chat.send_sync and chat.peek)."""

    def __init__(self, rpc_url: str = DEFAULT_RPC_URL, timeout: float = 30.0):
        self.rpc_url = rpc_url
        _validate_http_url(self.rpc_url)
        self.timeout = timeout

    def call(self, method: str, params: dict, timeout: float | None = None) -> dict:
        req_id = f"rpc-{uuid.uuid4().hex}"
        payload = {
            "jsonrpc": "2.0",
            "id": req_id,
            "method": method,
            "params": params,
        }
        status, raw = _http_json_request(
            url=self.rpc_url,
            method="POST",
            headers={
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
            raw_body=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
            timeout=timeout or self.timeout,
            allow_loopback_self_signed=True,
        )
        if status >= 400:
            raise RuntimeError(f"Moltis RPC HTTP {status}")
        try:
            data = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, ValueError) as exc:
            raise ValueError("Invalid JSON in Moltis RPC response") from exc
        return data if isinstance(data, dict) else {}

    def chat_peek(self, session_key: str, timeout: float = 5.0) -> dict:
        return self.call("chat.peek", {"sessionKey": session_key}, timeout=timeout)

    def chat_send_sync(
        self,
        model: str,
        message: str,
        session_key: str = ASSESSMENT_SESSION_KEY,
        ephemeral: bool = True,
        active_tools: list[str] | None = None,
        timeout: float = 25.0,
    ) -> dict:
        params = {
            "model": model,
            "message": message,
            "_session_key": session_key,
            "_ephemeral": bool(ephemeral),
            "active_tools": list(active_tools) if active_tools is not None else [],
        }
        return self.call("chat.send_sync", params, timeout=timeout)


class AssessmentWorker:
    """Bounded single-worker queue for unmentioned message assessment via mainModel."""

    def __init__(
        self,
        state_store: CompanionStateStore,
        resolver: SessionGenerationResolver,
        matrix_client: MatrixClient,
        rpc_client: MoltisRpcClient | None,
        agent_name: str,
        main_model: str,
        self_user_id: str,
        room_id: str = DEFAULT_ROOM_ID,
        max_queue_size: int = ASSESSMENT_QUEUE_MAX_DEPTH,
        max_preceding_messages: int = ASSESSMENT_MAX_PRECEDING_MESSAGES,
        max_context_chars: int = ASSESSMENT_MAX_CONTEXT_CHARS,
        timeout: float = ASSESSMENT_TIMEOUT_SECS,
        clock: Callable[[], int] = now_ms,
        on_assessment_complete: Callable[[dict], None] | None = None,
    ):
        self.state_store = state_store
        self.resolver = resolver
        self.matrix_client = matrix_client
        self.rpc_client = rpc_client
        self.agent_name = (agent_name or "").strip().lower()
        if self.agent_name == "momin":
            self.agent_name = "traya"
        self.main_model = (main_model or "").strip()
        self.self_user_id = self_user_id
        self.room_id = room_id
        self.max_queue_size = max(1, _safe_int(max_queue_size, ASSESSMENT_QUEUE_MAX_DEPTH))
        self.max_preceding_messages = max(0, _safe_int(max_preceding_messages, ASSESSMENT_MAX_PRECEDING_MESSAGES))
        self.max_context_chars = max(200, _safe_int(max_context_chars, ASSESSMENT_MAX_CONTEXT_CHARS))
        self.timeout = timeout
        self.clock = clock
        self.on_assessment_complete = on_assessment_complete

        self._lock = threading.Lock()
        self._cond = threading.Condition(self._lock)
        self._queue: collections.deque[dict] = collections.deque()
        self._running = False
        self._thread: threading.Thread | None = None

    @property
    def role_summary(self) -> str:
        return ROLE_SUMMARIES.get(self.agent_name, ROLE_SUMMARIES["skrye"])

    def queue_depth(self) -> int:
        with self._lock:
            return len(self._queue)

    def pending_jobs(self) -> list[dict]:
        with self._lock:
            return [dict(job) for job in self._queue]

    def cancel_stale(self, active_session_key: str, cutoff_ms: int) -> int:
        """Drop queued jobs that belong to an older session or fall before cutoff_ms."""
        removed = 0
        with self._lock:
            kept: collections.deque[dict] = collections.deque()
            while self._queue:
                job = self._queue.popleft()
                if (
                    job.get("active_session_key") == active_session_key
                    and _safe_int(job.get("origin_server_ts"), 0) >= cutoff_ms
                ):
                    kept.append(job)
                else:
                    removed += 1
            self._queue = kept
        return removed

    def is_eligible_event(
        self,
        event: dict,
        active_session_key: str,
        cutoff_ms: int,
    ) -> bool:
        if not isinstance(event, dict) or event.get("seed"):
            return False
        if not is_conversational_room_message(event):
            return False
        event_id = event.get("event_id")
        sender = event.get("sender")
        body = event.get("body")
        if not isinstance(event_id, str) or not event_id:
            return False
        if not isinstance(sender, str) or sender not in ALLOWLIST_USER_IDS or sender == self.self_user_id:
            return False
        if not isinstance(body, str) or not body.strip():
            return False
        if event.get("is_new_command") or is_new_command_message(body):
            return False
        mentioned_bots = event.get("mentioned_bots")
        if isinstance(mentioned_bots, list):
            mentions_self = self.self_user_id in mentioned_bots
        else:
            mentions_self = self.self_user_id in extract_mentioned_bots(body)
        if event.get("mentions_self") or mentions_self:
            return False
        ts_ms = _safe_int(event.get("origin_server_ts"), 0)
        if ts_ms < cutoff_ms:
            return False

        prior = self.state_store.get_assessed_event(event_id)
        return not (isinstance(prior, dict) and prior.get("session_key") == active_session_key)

    def enqueue(
        self,
        event: dict,
        active_session_key: str,
        cutoff_ms: int,
        now_override_ms: int | None = None,
    ) -> bool:
        if not self.is_eligible_event(event, active_session_key, cutoff_ms):
            return False
        event_id = str(event["event_id"])
        stamp_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        job = {
            "active_session_key": active_session_key,
            "cutoff_ms": cutoff_ms,
            "event_id": event_id,
            "sender": str(event["sender"]),
            "body": str(event["body"]),
            "origin_server_ts": _safe_int(event.get("origin_server_ts"), 0),
            "enqueued_at_ms": stamp_ms,
        }
        with self._cond:
            if any(j.get("event_id") == event_id for j in self._queue):
                return False
            while len(self._queue) >= self.max_queue_size:
                self._queue.popleft()
            self._queue.append(job)
            self._cond.notify()
        return True

    def enqueue_eligible_events(
        self,
        events: list[dict],
        active_session_key: str,
        cutoff_ms: int,
        now_override_ms: int | None = None,
    ) -> int:
        count = 0
        for ev in events:
            if self.enqueue(ev, active_session_key, cutoff_ms, now_override_ms=now_override_ms):
                count += 1
        return count

    def build_preceding_context(self, target_event_id: str, cutoff_ms: int) -> list[dict]:
        room_data = self.state_store.read_room_events()
        recent_events = room_data.get("recent_events", [])
        if not isinstance(recent_events, list):
            return []

        candidates: list[dict] = []
        for ev in recent_events:
            if not isinstance(ev, dict):
                continue
            ev_id = ev.get("event_id")
            if ev_id == target_event_id:
                break
            if ev.get("msgtype") != "m.text":
                continue
            body = ev.get("body")
            if not isinstance(body, str) or not body.strip():
                continue
            if ev.get("is_new_command") or is_new_command_message(body):
                continue
            ts_ms = _safe_int(ev.get("origin_server_ts"), 0)
            if ts_ms < cutoff_ms:
                continue
            candidates.append(ev)

        sliced = candidates[-self.max_preceding_messages :] if self.max_preceding_messages > 0 else []
        bounded_rev: list[dict] = []
        used_chars = 0
        for ev in reversed(sliced):
            sender = str(ev.get("sender") or "")
            body = str(ev.get("body") or "").strip()
            line_len = len(sender) + len(body) + 8
            if used_chars + line_len > self.max_context_chars:
                remaining = self.max_context_chars - used_chars - len(sender) - 8
                if remaining > 40 and not bounded_rev:
                    ev_copy = dict(ev)
                    ev_copy["body"] = body[:remaining]
                    bounded_rev.append(ev_copy)
                break
            bounded_rev.append(dict(ev))
            used_chars += line_len
        bounded_rev.reverse()
        return bounded_rev

    def build_assessment_prompt(self, job: dict, cutoff_ms: int) -> str:
        preceding = self.build_preceding_context(job["event_id"], cutoff_ms)
        context_lines: list[str] = []
        for ev in preceding:
            sender = ev.get("sender", "unknown")
            body_json = json.dumps(str(ev.get("body") or "").strip(), ensure_ascii=False)
            context_lines.append(f"- {sender}: {body_json}")
        preceding_block = "\n".join(context_lines) if context_lines else "- (none)"

        target_body = str(job.get("body") or "").strip()[:ASSESSMENT_MAX_TARGET_CHARS]
        target_sender = str(job.get("sender") or "unknown")
        target_json = json.dumps(target_body, ensure_ascii=False)

        return (
            f"You are assessing an unmentioned message in the Matrix council room ({self.room_id}).\n"
            f"Your council role: {self.role_summary}\n\n"
            "Preceding room context (post-/new messages only, for reference):\n"
            f"<preceding_messages>\n{preceding_block}\n</preceding_messages>\n\n"
            "Target message to assess (included once):\n"
            f"<target_message sender={json.dumps(target_sender)} event_id={json.dumps(job['event_id'])}>\n"
            f"{target_json}\n"
            "</target_message>\n\n"
            "Choose exactly one assessment reaction badge:\n"
            "- 👌🏻 : Acknowledged; no contribution requested (does not indicate agreement).\n"
            "- 👍🏻 : Agreement; no contribution requested.\n"
            "- ✋🏻 : A response, question, objection, or moderator action is needed "
            "(required when an untagged request needs an answer or action).\n\n"
            "Reply with ONLY the single badge (👌🏻, 👍🏻, or ✋🏻) and no other text."
        )

    def _target_exists_in_room_events(self, event_id: str) -> bool:
        room_data = self.state_store.read_room_events()
        for ev in room_data.get("recent_events", []):
            if isinstance(ev, dict) and ev.get("event_id") == event_id:
                return True
        return False

    def process_one(self, now_override_ms: int | None = None) -> dict | None:
        with self._lock:
            if not self._queue:
                return None
            job = self._queue.popleft()

        stamp_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        event_id = job["event_id"]
        job_session_key = job["active_session_key"]
        job_ts_ms = _safe_int(job.get("origin_server_ts"), 0)

        # Recheck 1: BEFORE calling chat.send_sync
        gen_before = self.resolver.resolve(now_override_ms=stamp_ms)
        if (
            gen_before["active_session_key"] != job_session_key
            or job_ts_ms < _safe_int(gen_before["cutoff_ms"], 0)
            or not self._target_exists_in_room_events(event_id)
        ):
            self.cancel_stale(gen_before["active_session_key"], _safe_int(gen_before["cutoff_ms"], 0))
            return {
                "event_id": event_id,
                "status": "stale_before_rpc",
                "badge": None,
                "reaction_event_id": None,
            }

        if self.rpc_client is None or not self.main_model:
            return {
                "event_id": event_id,
                "status": "skipped_no_rpc",
                "badge": None,
                "reaction_event_id": None,
            }

        prompt = self.build_assessment_prompt(job, _safe_int(gen_before["cutoff_ms"], 0))
        try:
            rpc_resp = self.rpc_client.chat_send_sync(
                model=self.main_model,
                message=prompt,
                session_key=ASSESSMENT_SESSION_KEY,
                ephemeral=True,
                active_tools=[],
                timeout=self.timeout,
            )
        except Exception as exc:
            sys.stderr.write(f"moltis-matrix-companion assessment RPC error ({event_id}): {exc}\n")
            self.state_store.record_assessed_event(
                event_id=event_id,
                session_key=job_session_key,
                status="rpc_error",
                badge=None,
                assessed_at_ms=stamp_ms,
            )
            return {
                "event_id": event_id,
                "status": "rpc_error",
                "badge": None,
                "reaction_event_id": None,
            }

        badge = parse_assessment_rpc_response(rpc_resp)
        if badge not in ASSESSMENT_BADGES:
            self.state_store.record_assessed_event(
                event_id=event_id,
                session_key=job_session_key,
                status="rejected_output",
                badge=None,
                assessed_at_ms=stamp_ms,
            )
            return {
                "event_id": event_id,
                "status": "rejected_output",
                "badge": None,
                "reaction_event_id": None,
            }

        # Recheck 2: AGAIN before posting m.reaction
        after_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        gen_after = self.resolver.resolve(now_override_ms=after_ms)
        if (
            gen_after["active_session_key"] != job_session_key
            or job_ts_ms < _safe_int(gen_after["cutoff_ms"], 0)
            or not self._target_exists_in_room_events(event_id)
        ):
            self.cancel_stale(gen_after["active_session_key"], _safe_int(gen_after["cutoff_ms"], 0))
            return {
                "event_id": event_id,
                "status": "stale_before_reaction",
                "badge": None,
                "reaction_event_id": None,
            }

        rxn_event_id = self.matrix_client.send_reaction(
            target_event_id=event_id,
            key=badge,
            scope_id=f"assess:{job_session_key}:{event_id}",
        )
        if isinstance(rxn_event_id, str) and rxn_event_id:
            self.state_store.record_local_reaction(
                target_event_id=event_id,
                reaction_event_id=rxn_event_id,
                sender=self.self_user_id,
                key=badge,
                ts_ms=after_ms,
            )
        rec = self.state_store.record_assessed_event(
            event_id=event_id,
            session_key=job_session_key,
            status="posted",
            badge=badge,
            reaction_event_id=rxn_event_id,
            assessed_at_ms=after_ms,
        )
        if self.on_assessment_complete is not None:
            with contextlib.suppress(Exception):
                self.on_assessment_complete(rec)
        return rec

    def drain(self, now_override_ms: int | None = None) -> list[dict]:
        results: list[dict] = []
        while True:
            res = self.process_one(now_override_ms=now_override_ms)
            if res is None:
                break
            results.append(res)
        return results

    def start(self) -> None:
        with self._cond:
            if self._running:
                return
            self._running = True
            self._thread = threading.Thread(
                target=self._worker_loop,
                name=f"matrix-assess-{self.agent_name}",
                daemon=True,
            )
            self._thread.start()

    def stop(self, timeout: float = 2.0) -> None:
        with self._cond:
            self._running = False
            self._cond.notify_all()
            thread = self._thread
            self._thread = None
        if thread is not None and thread.is_alive():
            thread.join(timeout=timeout)

    def _worker_loop(self) -> None:
        while True:
            with self._cond:
                while self._running and not self._queue:
                    self._cond.wait(timeout=1.0)
                if not self._running:
                    return
            try:
                self.process_one()
            except Exception as exc:
                sys.stderr.write(f"moltis-matrix-companion assessment worker error: {exc}\n")


class TurnStatusReconciler:
    """Option 1A event-to-turn binding, static 🐝 reaction, dynamic progress notices, and chat.peek reconciliation."""

    def __init__(
        self,
        state_store: CompanionStateStore,
        matrix_client: MatrixClient,
        rpc_client: MoltisRpcClient | None,
        data_dir: Path | str,
        agent_name: str,
        agent_display_name: str,
        self_user_id: str,
        room_id: str = DEFAULT_ROOM_ID,
        thinking_dwell_ms: int = THINKING_DWELL_MS,
        phase_edit_interval_ms: int = PHASE_EDIT_INTERVAL_MS,
        initial_progress_delay_ms: int = INITIAL_PROGRESS_NOTICE_DELAY_MS,
        progress_interval_ms: int = PROGRESS_NOTICE_INTERVAL_MS,
        completion_window_ms: int = COMPLETION_RECONCILE_WINDOW_MS,
        clock: Callable[[], int] = now_ms,
    ):
        self.state_store = state_store
        self.matrix_client = matrix_client
        self.rpc_client = rpc_client
        self.data_dir = Path(data_dir)
        self.agent_name = (agent_name or "").strip().lower()
        if self.agent_name == "momin":
            self.agent_name = "traya"
        self.agent_display_name = derive_display_name(self.agent_name, agent_display_name)
        self.self_user_id = self_user_id
        self.room_id = room_id
        self.thinking_dwell_ms = max(0, _safe_int(thinking_dwell_ms, THINKING_DWELL_MS))
        self.phase_edit_interval_ms = max(0, _safe_int(phase_edit_interval_ms, PHASE_EDIT_INTERVAL_MS))
        self.initial_progress_delay_ms = max(
            1000, _safe_int(initial_progress_delay_ms, INITIAL_PROGRESS_NOTICE_DELAY_MS)
        )
        self.progress_interval_ms = max(1000, _safe_int(progress_interval_ms, PROGRESS_NOTICE_INTERVAL_MS))
        self.completion_window_ms = max(0, _safe_int(completion_window_ms, COMPLETION_RECONCILE_WINDOW_MS))
        self.clock = clock

    def _cleanup_run_artifacts(
        self,
        session_key: str,
        run_id: str,
        run_entry: dict,
        verified_completion: bool = False,
        reply_event_id: str | None = None,
        current_ms: int | None = None,
    ) -> dict:
        stamp_ms = _safe_int(current_ms, self.clock()) if current_ms is not None else self.clock()
        progress_id = run_entry.get("progress_event_id")
        terminal_notice_id: str | None = None
        terminal_notice_text: str | None = None
        if isinstance(progress_id, str) and progress_id:
            started_at_ms = _safe_int(run_entry.get("started_at_ms"), stamp_ms)
            inactive_ms = run_entry.get("inactive_since_ms")
            end_ms = (
                _safe_int(inactive_ms, stamp_ms)
                if isinstance(inactive_ms, int) and inactive_ms > 0
                else stamp_ms
            )
            elapsed_sec = max(1, (end_ms - started_at_ms) // 1000)
            terminal_notice_text = format_terminal_notice(
                agent_display_name=self.agent_display_name,
                elapsed_sec=elapsed_sec,
                verified=verified_completion,
            )
            terminal_notice_id = progress_id
            try:
                self.matrix_client.edit_notice(
                    target_event_id=progress_id,
                    body_text=terminal_notice_text,
                    scope_id=f"progress-terminal:{session_key}:{run_id}:{progress_id}",
                )
            except MatrixAPIError as exc:
                if exc.status != 429 and exc.errcode != "M_LIMIT_EXCEEDED":
                    raise
                sys.stderr.write(f"moltis-matrix-companion rate limit on terminal notice edit: {exc}\n")

        active_rxn_id = run_entry.get("active_reaction_event_id")
        if isinstance(active_rxn_id, str) and active_rxn_id:
            try:
                self.matrix_client.redact_event(
                    active_rxn_id,
                    scope_id=f"phase-cleanup:{session_key}:{run_id}:{active_rxn_id}",
                )
                self.state_store.record_local_redaction(active_rxn_id, ts_ms=stamp_ms)
            except MatrixAPIError as exc:
                if exc.status != 429 and exc.errcode != "M_LIMIT_EXCEEDED":
                    raise
                sys.stderr.write(f"moltis-matrix-companion rate limit on reaction redact: {exc}\n")

        return self.state_store.update_run_state(
            session_key,
            run_id,
            active_reaction_event_id=None,
            active_reaction_key=None,
            progress_event_id=None,
            terminal_notice_event_id=terminal_notice_id,
            terminal_notice_text=terminal_notice_text,
            cleaned_up=True,
            cleaned_up_at_ms=stamp_ms,
            reply_event_id=reply_event_id,
            completed_reaction_event_id=None,
        )

    def _resolve_user_record_for_run(
        self,
        session_key: str,
        run_id: str,
        active_turn: dict,
    ) -> tuple[str, str, int, bool]:
        """Resolve (sender_id, user_content, created_at_ms, is_conflict) from active-turn.json and history.jsonl."""
        turn_sender = str(active_turn.get("user_sender_id") or "").strip()
        turn_content = extract_text_content(active_turn.get("user_content")).strip()
        turn_ts_ms = _safe_int(active_turn.get("user_created_at_ms"), 0)

        records = load_session_history_records(
            self.data_dir,
            session_key,
            agent_name=self.agent_name,
            room_id=self.room_id,
        )
        user_records_for_run = [
            r
            for r in records
            if isinstance(r, dict)
            and r.get("role") == "user"
            and str(r.get("run_id") or "").strip() == run_id
        ]
        if len(user_records_for_run) > 1:
            contents = {
                strip_audio_message_suffix(extract_text_content(r.get("content")).strip())
                for r in user_records_for_run
            }
            if len(contents) > 1:
                return turn_sender, turn_content, turn_ts_ms, True

        if len(user_records_for_run) == 1:
            hist_rec = user_records_for_run[0]
            hist_content = extract_text_content(hist_rec.get("content")).strip()
            hist_sender = extract_record_sender(hist_rec)
            _, hist_ts_ms = normalize_ts(hist_rec.get("created_at"))
            if turn_content and hist_content and not _content_matches(turn_content, hist_content):
                return turn_sender, turn_content, turn_ts_ms, True
            if turn_sender and hist_sender and not _sender_matches(hist_sender, turn_sender) and not _sender_matches(turn_sender, hist_sender):
                return turn_sender, turn_content, turn_ts_ms, True
            if not turn_content:
                turn_content = hist_content
            if not turn_sender:
                turn_sender = hist_sender
            if turn_ts_ms <= 0 and hist_ts_ms > 0:
                turn_ts_ms = hist_ts_ms

        return turn_sender, turn_content, turn_ts_ms, False

    def _try_bind_event(
        self,
        session_key: str,
        run_id: str,
        active_turn: dict,
        cutoff_ms: int,
    ) -> tuple[str | None, bool]:
        """Bind status reactions via self_user_id's 👀 reaction and unique unbound (sender, body)."""
        sender_id, user_content, _, is_conflict = self._resolve_user_record_for_run(
            session_key, run_id, active_turn
        )
        if is_conflict:
            return None, True
        if not user_content or not sender_id:
            return None, False

        comp_state = self.state_store.read_companion_state()
        current_key = make_run_state_key(session_key, run_id)
        already_bound_ids = {
            entry.get("bound_event_id")
            for k, entry in _as_dict(comp_state.get("runs")).items()
            if k != current_key and isinstance(entry, dict) and isinstance(entry.get("bound_event_id"), str)
        }

        room_data = self.state_store.read_room_events()
        recent_events = room_data.get("recent_events", [])
        candidates: list[dict] = []
        for ev in recent_events:
            if not isinstance(ev, dict):
                continue
            ev_id = ev.get("event_id")
            if not isinstance(ev_id, str) or not ev_id or ev_id in already_bound_ids:
                continue
            if not is_conversational_room_message(ev):
                continue
            if _safe_int(ev.get("origin_server_ts"), 0) < cutoff_ms:
                continue
            rxns = _as_dict(ev.get("reactions"))
            has_self_ack = any(
                isinstance(r, dict)
                and r.get("sender") == self.self_user_id
                and r.get("key") == ACK_REACTION_KEY
                for r in rxns.values()
            )
            if not has_self_ack:
                continue
            if not _sender_matches(str(ev.get("sender") or ""), sender_id):
                continue
            if not _content_matches(str(ev.get("body") or ""), user_content):
                continue
            candidates.append(ev)

        if len(candidates) == 1:
            return str(candidates[0]["event_id"]), False
        if len(candidates) > 1:
            return None, True
        return None, False

    def _desired_activity_phase(
        self,
        active_turn: dict,
        current_ms: int,
    ) -> tuple[str, int]:
        raw_phase = str(active_turn.get("phase") or "").strip().lower()
        tool_name = str(active_turn.get("tool_name") or "").strip().lower()
        iteration = max(1, _safe_int(active_turn.get("iteration"), 1))
        phase_updated_at_ms = _safe_int(active_turn.get("phase_updated_at_ms"), current_ms)

        if tool_name:
            return classify_tool_phase(tool_name), iteration
        if raw_phase in ("shell", "search", "write", "tool"):
            return raw_phase, iteration
        if raw_phase in ("before_tool_call", "beforetoolcall"):
            return "tool", iteration
        if raw_phase in ("thinking", "before_llm_call", "beforellmcall", "llm", ""):
            if iteration == 1 or current_ms - phase_updated_at_ms >= self.thinking_dwell_ms:
                return "thinking", iteration
            last_tool_phase = str(active_turn.get("last_tool_phase") or "").strip().lower()
            if last_tool_phase in ("shell", "search", "write", "tool"):
                return last_tool_phase, iteration
            return "thinking", iteration
        return "thinking", iteration

    def _find_committed_final_assistant_reply(
        self,
        session_key: str,
        run_id: str,
    ) -> tuple[str | None, bool]:
        """Return (final_content, ambiguous) for run_id from history.jsonl."""
        records = load_session_history_records(
            self.data_dir,
            session_key,
            agent_name=self.agent_name,
            room_id=self.room_id,
        )
        run_assistant_records = [
            r
            for r in records
            if isinstance(r, dict)
            and r.get("role") == "assistant"
            and str(r.get("run_id") or "").strip() == run_id
        ]
        if not run_assistant_records:
            return None, False

        # The final assistant record for the run must have empty tool_calls and non-empty content.
        last_rec = run_assistant_records[-1]
        if last_rec.get("tool_calls"):
            return None, False

        final_candidates = [
            extract_text_content(r.get("content")).strip()
            for r in run_assistant_records
            if not r.get("tool_calls") and extract_text_content(r.get("content")).strip()
        ]
        if not final_candidates:
            return None, False
        unique_contents = set(final_candidates)
        if len(unique_contents) > 1:
            return None, True
        return final_candidates[-1], False

    def _find_matching_self_room_message(
        self,
        session_key: str,
        run_id: str,
        final_content: str,
        cutoff_ms: int,
        bound_event_id: str | None,
    ) -> tuple[str | None, bool]:
        """Return (reply_event_id, ambiguous) for self_user_id's m.text matching final_content."""
        comp_state = self.state_store.read_companion_state()
        current_key = make_run_state_key(session_key, run_id)
        claimed_reply_ids = {
            entry.get("reply_event_id")
            for k, entry in _as_dict(comp_state.get("runs")).items()
            if k != current_key and isinstance(entry, dict) and isinstance(entry.get("reply_event_id"), str)
        }

        room_data = self.state_store.read_room_events()
        recent_events = room_data.get("recent_events", [])
        bound_ts_ms = 0
        if bound_event_id:
            for ev in recent_events:
                if isinstance(ev, dict) and ev.get("event_id") == bound_event_id:
                    bound_ts_ms = _safe_int(ev.get("origin_server_ts"), 0)
                    break

        matches: list[str] = []
        norm_final = strip_audio_message_suffix(final_content).strip()
        for ev in recent_events:
            if not isinstance(ev, dict):
                continue
            ev_id = ev.get("event_id")
            if not isinstance(ev_id, str) or not ev_id or ev_id in claimed_reply_ids:
                continue
            if ev.get("sender") != self.self_user_id or not is_conversational_room_message(ev):
                continue
            ts_ms = _safe_int(ev.get("origin_server_ts"), 0)
            if ts_ms < cutoff_ms or (bound_ts_ms > 0 and ts_ms < bound_ts_ms):
                continue
            ev_body = str(ev.get("body") or "").strip()
            if ev_body == final_content.strip() or (
                norm_final and strip_audio_message_suffix(ev_body).strip() == norm_final
            ):
                matches.append(ev_id)

        if len(matches) == 1:
            return matches[0], False
        if len(matches) > 1:
            return None, True
        return None, False

    def reconcile(
        self,
        generation: dict,
        now_override_ms: int | None = None,
    ) -> dict:
        current_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        active_session_key = str(generation["active_session_key"])
        cutoff_ms = _safe_int(generation["cutoff_ms"], 0)

        # Clean up any dangling uncleaned runs belonging to a superseded session_key.
        comp_state = self.state_store.read_companion_state()
        for entry in list(_as_dict(comp_state.get("runs")).values()):
            if not isinstance(entry, dict) or entry.get("cleaned_up"):
                continue
            r_sess = str(entry.get("session_key") or "")
            r_id = str(entry.get("run_id") or "")
            if r_sess and r_id and r_sess != active_session_key:
                self._cleanup_run_artifacts(
                    session_key=r_sess,
                    run_id=r_id,
                    run_entry=entry,
                    verified_completion=False,
                    current_ms=current_ms,
                )

        active_turn = self.state_store.read_active_turn()
        if not isinstance(active_turn, dict):
            return {"status": "idle"}

        turn_session_key = str(active_turn.get("session_key") or "").strip()
        run_id = str(active_turn.get("run_id") or "").strip()
        if not turn_session_key or not run_id or turn_session_key != active_session_key:
            return {"status": "inactive_session"}

        # Clean up any prior uncleaned run_id in the same session that was superseded by a new run_id.
        comp_state = self.state_store.read_companion_state()
        for entry in list(_as_dict(comp_state.get("runs")).values()):
            if not isinstance(entry, dict) or entry.get("cleaned_up"):
                continue
            r_sess = str(entry.get("session_key") or "")
            r_id = str(entry.get("run_id") or "")
            if r_sess == active_session_key and r_id and r_id != run_id:
                self._cleanup_run_artifacts(
                    session_key=r_sess,
                    run_id=r_id,
                    run_entry=entry,
                    verified_completion=False,
                    current_ms=current_ms,
                )

        run_entry = self.state_store.get_run_state(active_session_key, run_id)
        if run_entry is None:
            user_created_ms = _safe_int(active_turn.get("user_created_at_ms"), 0)
            started_ms = user_created_ms if 0 < user_created_ms <= current_ms else current_ms
            run_entry = self.state_store.update_run_state(
                active_session_key,
                run_id,
                started_at_ms=started_ms,
                binding_ambiguous=False,
                inactive_since_ms=None,
                progress_edit_count=0,
            )

        if run_entry.get("cleaned_up"):
            return {"status": "already_cleaned_up", "run_id": run_id}

        # Step 1: Attempt Option 1A event-to-turn binding if not yet bound and not ambiguous.
        bound_event_id = run_entry.get("bound_event_id")
        binding_ambiguous = bool(run_entry.get("binding_ambiguous", False))
        if not bound_event_id and not binding_ambiguous:
            candidate_id, is_ambiguous = self._try_bind_event(
                active_session_key,
                run_id,
                active_turn,
                cutoff_ms,
            )
            if is_ambiguous:
                binding_ambiguous = True
                run_entry = self.state_store.update_run_state(
                    active_session_key,
                    run_id,
                    binding_ambiguous=True,
                )
            elif candidate_id:
                bound_event_id = candidate_id
                run_entry = self.state_store.update_run_state(
                    active_session_key,
                    run_id,
                    bound_event_id=bound_event_id,
                )

        # Step 2: Poll chat.peek if rpc_client is configured.
        peek_active: bool | None = True
        if self.rpc_client is not None:
            try:
                peek_resp = self.rpc_client.chat_peek(active_session_key)
                peek_active = parse_chat_peek_active(peek_resp)
            except Exception as exc:
                sys.stderr.write(f"moltis-matrix-companion chat.peek warning: {exc}\n")
                peek_active = None

        if peek_active is False:
            inactive_since_ms = run_entry.get("inactive_since_ms")
            if not isinstance(inactive_since_ms, int) or inactive_since_ms <= 0:
                inactive_since_ms = current_ms
                run_entry = self.state_store.update_run_state(
                    active_session_key,
                    run_id,
                    inactive_since_ms=inactive_since_ms,
                )

            final_content, hist_ambiguous = self._find_committed_final_assistant_reply(
                active_session_key,
                run_id,
            )
            reply_event_id: str | None = None
            reply_ambiguous = False
            if final_content and not hist_ambiguous:
                reply_event_id, reply_ambiguous = self._find_matching_self_room_message(
                    session_key=active_session_key,
                    run_id=run_id,
                    final_content=final_content,
                    cutoff_ms=cutoff_ms,
                    bound_event_id=bound_event_id if isinstance(bound_event_id, str) else None,
                )

            room_data = self.state_store.read_room_events()
            bound_still_present = bool(
                isinstance(bound_event_id, str)
                and bound_event_id
                and any(
                    isinstance(ev, dict) and ev.get("event_id") == bound_event_id
                    for ev in room_data.get("recent_events", [])
                )
            )

            unambiguous_complete = (
                bool(final_content)
                and not hist_ambiguous
                and bool(reply_event_id)
                and not reply_ambiguous
                and bound_still_present
                and not binding_ambiguous
            )
            window_expired = (current_ms - inactive_since_ms) >= self.completion_window_ms

            if unambiguous_complete or window_expired:
                updated = self._cleanup_run_artifacts(
                    session_key=active_session_key,
                    run_id=run_id,
                    run_entry=run_entry,
                    verified_completion=unambiguous_complete,
                    reply_event_id=reply_event_id if unambiguous_complete else None,
                    current_ms=current_ms,
                )
                return {
                    "status": "completed" if unambiguous_complete else "cleaned_up_incomplete",
                    "run_id": run_id,
                    "bound_event_id": bound_event_id,
                    "completed_reaction_event_id": updated.get("completed_reaction_event_id"),
                    "terminal_notice_event_id": updated.get("terminal_notice_event_id"),
                }

            return {
                "status": "reconciling_completion",
                "run_id": run_id,
                "bound_event_id": bound_event_id,
                "inactive_since_ms": inactive_since_ms,
            }

        # Turn is active (peek_active is True or unknown): clear any transient inactive_since_ms.
        if run_entry.get("inactive_since_ms") is not None:
            run_entry = self.state_store.update_run_state(
                active_session_key,
                run_id,
                inactive_since_ms=None,
            )

        norm_phase, iteration = self._desired_activity_phase(active_turn, current_ms)
        if (
            isinstance(bound_event_id, str)
            and bound_event_id
            and not binding_ambiguous
            and run_entry.get("active_reaction_key") != ACTIVE_BEE_KEY
        ):
            new_rxn_id = self.matrix_client.send_reaction(
                target_event_id=bound_event_id,
                key=ACTIVE_BEE_KEY,
                scope_id=f"bee:{active_session_key}:{run_id}:{bound_event_id}",
            )
            if isinstance(new_rxn_id, str) and new_rxn_id:
                self.state_store.record_local_reaction(
                    target_event_id=bound_event_id,
                    reaction_event_id=new_rxn_id,
                    sender=self.self_user_id,
                    key=ACTIVE_BEE_KEY,
                    ts_ms=current_ms,
                )
            run_entry = self.state_store.update_run_state(
                active_session_key,
                run_id,
                active_reaction_event_id=new_rxn_id,
                active_reaction_key=ACTIVE_BEE_KEY,
            )

        # Progress notice after 5s while active == True, edited every 3s with wall-clock MM:SS - Step X.
        if peek_active is True:
            started_at_ms = _safe_int(run_entry.get("started_at_ms"), current_ms)
            elapsed_ms = current_ms - started_at_ms
            if elapsed_ms >= self.initial_progress_delay_ms:
                elapsed_sec = max(self.initial_progress_delay_ms // 1000, elapsed_ms // 1000)
                notice_text = format_progress_notice(
                    elapsed_sec=elapsed_sec,
                    iteration=iteration,
                    phase=norm_phase,
                )
                progress_id = run_entry.get("progress_event_id")
                if not isinstance(progress_id, str) or not progress_id:
                    new_prog_id = self.matrix_client.send_notice(
                        body_text=notice_text,
                        scope_id=f"progress:{active_session_key}:{run_id}",
                        mentions_user_ids=[],
                    )
                    run_entry = self.state_store.update_run_state(
                        active_session_key,
                        run_id,
                        progress_event_id=new_prog_id,
                        last_progress_at_ms=current_ms,
                        last_progress_phase=norm_phase,
                        progress_edit_count=0,
                    )
                else:
                    last_prog_ms = _safe_int(run_entry.get("last_progress_at_ms"), started_at_ms)
                    last_prog_phase = str(run_entry.get("last_progress_phase") or "thinking")
                    phase_changed = norm_phase != last_prog_phase
                    due_by_phase = (
                        phase_changed
                        and (current_ms - last_prog_ms) >= self.phase_edit_interval_ms
                    )
                    due_by_timer = (current_ms - last_prog_ms) >= self.progress_interval_ms
                    if due_by_phase or due_by_timer:
                        edit_count = _safe_int(run_entry.get("progress_edit_count"), 0) + 1
                        try:
                            self.matrix_client.edit_notice(
                                target_event_id=progress_id,
                                body_text=notice_text,
                                scope_id=f"progress-edit:{active_session_key}:{run_id}:{edit_count}",
                            )
                            run_entry = self.state_store.update_run_state(
                                active_session_key,
                                run_id,
                                last_progress_at_ms=current_ms,
                                last_progress_phase=norm_phase,
                                progress_edit_count=edit_count,
                            )
                        except MatrixAPIError as exc:
                            if exc.status != 429 and exc.errcode != "M_LIMIT_EXCEEDED":
                                raise
                            sys.stderr.write(
                                f"moltis-matrix-companion rate limit on progress notice edit: {exc}\n"
                            )

        return {
            "status": "active",
            "run_id": run_id,
            "bound_event_id": run_entry.get("bound_event_id"),
            "active_reaction_key": run_entry.get("active_reaction_key"),
            "activity_phase": norm_phase,
            "progress_event_id": run_entry.get("progress_event_id"),
        }


class ModeratorWakeupCoordinator:
    """Single-selector floor invitation coordinator on Skrye with Traya relay, pending_hands queue, and crash recovery."""

    def __init__(
        self,
        state_store: CompanionStateStore,
        resolver: SessionGenerationResolver,
        matrix_client: MatrixClient,
        agent_name: str,
        room_id: str = DEFAULT_ROOM_ID,
        deadline_ms: int = WAKEUP_DEADLINE_MS,
        max_wakeups_per_martin_root: int = MAX_WAKEUPS_PER_MARTIN_ROOT,
        max_bot_turns_since_martin: int = MAX_BOT_TURNS_SINCE_MARTIN,
        clock: Callable[[], int] = now_ms,
    ):
        self.state_store = state_store
        self.resolver = resolver
        self.matrix_client = matrix_client
        self.agent_name = (agent_name or "").strip().lower()
        if self.agent_name == "momin":
            self.agent_name = "traya"
        self.room_id = room_id
        self.deadline_ms = max(1000, _safe_int(deadline_ms, WAKEUP_DEADLINE_MS))
        self.max_wakeups_per_martin_root = max(
            1, _safe_int(max_wakeups_per_martin_root, MAX_WAKEUPS_PER_MARTIN_ROOT)
        )
        self.max_bot_turns_since_martin = max(
            1, _safe_int(max_bot_turns_since_martin, MAX_BOT_TURNS_SINCE_MARTIN)
        )
        self.clock = clock

    @property
    def is_designated_sender(self) -> bool:
        return self.agent_name == "skrye"

    @property
    def is_relay_sender(self) -> bool:
        return self.agent_name == "traya"

    def _compute_timeline_discussion_state(
        self,
        recent_events: list[dict],
        active_session_key: str,
        cutoff_ms: int,
        last_moderator_reset_ts_ms: int,
    ) -> tuple[str, int, dict[str, str]]:
        """Compute (current_martin_root_id, bot_turns_since_martin, event_to_martin_root_map)."""
        current_root = f"root:{active_session_key}"
        bot_turns = 0
        event_root_map: dict[str, str] = {}

        for ev in recent_events:
            if not isinstance(ev, dict):
                continue
            ev_id = ev.get("event_id")
            if not isinstance(ev_id, str) or not ev_id:
                continue
            if not is_conversational_room_message(ev):
                continue
            sender = ev.get("sender")
            if sender not in ALLOWLIST_USER_IDS:
                continue
            body = str(ev.get("body") or "")
            if ev.get("is_new_command") or is_new_command_message(body):
                continue
            ts_ms = _safe_int(ev.get("origin_server_ts"), 0)
            if ts_ms < cutoff_ms or (last_moderator_reset_ts_ms > 0 and ts_ms <= last_moderator_reset_ts_ms):
                continue

            if sender == MARTIN_ID:
                current_root = ev_id
                bot_turns = 0
            elif sender in BOT_IDS:
                bot_turns += 1
            event_root_map[ev_id] = current_root

        return current_root, bot_turns, event_root_map

    def _active_badges_for_target(
        self,
        target_ev: dict,
        expected_assessors: list[str],
    ) -> dict[str, str]:
        expected_set = set(expected_assessors)
        reactions = _as_dict(target_ev.get("reactions"))
        by_sender: dict[str, tuple[int, str]] = {}
        for rxn in reactions.values():
            if not isinstance(rxn, dict):
                continue
            sender = rxn.get("sender")
            if not isinstance(sender, str) or sender not in expected_set:
                continue
            badge = normalize_assessment_badge(rxn.get("key"))
            if badge not in ASSESSMENT_BADGES:
                continue
            ts_ms = _safe_int(rxn.get("ts_ms"), 0)
            prev = by_sender.get(sender)
            if prev is None or badge == "✋🏻" or (prev[1] != "✋🏻" and ts_ms >= prev[0]):
                by_sender[sender] = (ts_ms, badge)
        return {sender: item[1] for sender, item in by_sender.items()}

    def _has_newer_allowlisted_message(
        self,
        recent_events: list[dict],
        target_event_id: str,
        target_ts_ms: int,
    ) -> str | None:
        seen_target = False
        for ev in recent_events:
            if not isinstance(ev, dict):
                continue
            ev_id = ev.get("event_id")
            if ev_id == target_event_id:
                seen_target = True
                continue
            if not seen_target:
                continue
            if not is_conversational_room_message(ev):
                continue
            sender = ev.get("sender")
            if sender not in ALLOWLIST_USER_IDS:
                continue
            body = str(ev.get("body") or "")
            if ev.get("is_new_command") or is_new_command_message(body):
                continue
            if _safe_int(ev.get("origin_server_ts"), 0) >= target_ts_ms and isinstance(ev_id, str):
                return ev_id
        return None

    def _timeline_has_delivery_or_speaker_activity(
        self,
        recent_events: list[dict],
        *,
        after_event_id: str = "",
        after_ts_ms: int = 0,
        sending_account: str,
        notice_body: str,
        selection_id: str,
        selected_speaker: str,
    ) -> str | None:
        """Return the matching notice or selected speaker reply event_id from recent_events."""
        seen_anchor = not bool(after_event_id)
        for ev in recent_events:
            if not isinstance(ev, dict):
                continue
            ev_id = str(ev.get("event_id") or "")
            if not seen_anchor:
                if ev_id == after_event_id:
                    seen_anchor = True
                continue
            ev_ts = _safe_int(ev.get("origin_server_ts"), 0)
            if after_ts_ms > 0 and ev_ts < after_ts_ms:
                continue
            sender = str(ev.get("sender") or "")
            msgtype = ev.get("msgtype")
            body = str(ev.get("body") or "")
            relay_meta = _as_dict(ev.get("companion_relay"))
            if msgtype == "m.notice" and sender == sending_account:
                if relay_meta.get("selection_id") == selection_id or (notice_body and body == notice_body):
                    return ev_id or "matched_notice"
            if sender == selected_speaker and is_conversational_room_message(ev):
                if not ev.get("is_new_command") and not is_new_command_message(body):
                    return ev_id or "speaker_replied"
        return None

    def _reconcile_sending_record(
        self,
        record: dict,
        recent_events: list[dict],
        current_ms: int,
    ) -> tuple[str, str | None]:
        """Reconcile an interrupted status=='sending' selection or relay record against timeline and token_generation_id."""
        selection_id = str(record.get("selection_id") or "")
        sending_account = str(record.get("sending_account") or self.matrix_client.self_user_id)
        selected_speaker = str(record.get("selected_speaker") or TRAYA_ID)
        payload = _as_dict(record.get("payload"))
        notice_body = str(payload.get("body") or "")
        after_ev_id = str(record.get("after_event_id") or record.get("target_event_id") or "")
        after_ts_ms = _safe_int(record.get("created_at_ms"), 0)
        txn_id = str(record.get("txn_id") or "")

        matched_ev_id = self._timeline_has_delivery_or_speaker_activity(
            recent_events,
            after_event_id=after_ev_id,
            after_ts_ms=after_ts_ms,
            sending_account=sending_account,
            notice_body=notice_body,
            selection_id=selection_id,
            selected_speaker=selected_speaker,
        )
        if matched_ev_id:
            if txn_id:
                self.matrix_client._complete_outbox(txn_id)
            record["status"] = "sent"
            record["wakeup_event_id"] = matched_ev_id
            record["reconciled_at_ms"] = current_ms
            return "sent", matched_ev_id

        current_tgen = self.matrix_client.get_token_generation_id()
        saved_tgen = str(record.get("token_generation_id") or "")
        if saved_tgen and current_tgen != saved_tgen:
            if txn_id:
                self.matrix_client._complete_outbox(txn_id)
            record["status"] = "uncertain_blocked"
            record["blocked_reason"] = "token_rotated_without_timeline_evidence"
            record["blocked_at_ms"] = current_ms
            return "uncertain_blocked", None

        outbox = self.state_store.read_outbox()
        pending_item = _as_dict(outbox.get("pending", {})).get(txn_id) if txn_id else None
        path = str(
            (pending_item.get("path") if isinstance(pending_item, dict) else None)
            or record.get("path")
            or ""
        )
        if not path and txn_id:
            room_q = urllib.parse.quote(self.room_id, safe="")
            txn_q = urllib.parse.quote(txn_id, safe="")
            path = f"/_matrix/client/v3/rooms/{room_q}/send/m.room.message/{txn_q}"
        try:
            resp = self.matrix_client._authenticated_request(
                "PUT",
                path,
                body=payload,
                timeout=20.0,
                allow_relogin_retry=False,
            )
        except MatrixAPIError as exc:
            if exc.status == 401 or exc.errcode == "M_UNKNOWN_TOKEN":
                self.matrix_client.login(force=True)
                if txn_id:
                    self.matrix_client._complete_outbox(txn_id)
                record["status"] = "uncertain_blocked"
                record["blocked_reason"] = "token_expired_during_recovery_put"
                record["blocked_at_ms"] = current_ms
                return "uncertain_blocked", None
            raise

        if txn_id:
            self.matrix_client._complete_outbox(txn_id)
        ev_id = resp.get("event_id") if isinstance(resp, dict) else None
        resolved_ev_id = ev_id if isinstance(ev_id, str) else None
        record["status"] = "sent"
        record["wakeup_event_id"] = resolved_ev_id
        record["reconciled_at_ms"] = current_ms
        return "sent", resolved_ev_id

    def _cancel_stale_sending_record(
        self,
        record: dict,
        cutoff_ms: int,
        last_moderator_reset_ts_ms: int,
        current_ms: int,
        active_session_key: str,
        target_record: dict | None = None,
    ) -> bool:
        target = target_record if isinstance(target_record, dict) else {}
        created_at_ms = _safe_int(record.get("created_at_ms"), 0)
        target_ts_ms = _safe_int(
            target.get("origin_server_ts", record.get("target_origin_server_ts")),
            0,
        )
        target_session_key = str(target.get("session_key") or record.get("session_key") or "")
        target_status = str(target.get("status") or "")
        record_is_current = created_at_ms >= cutoff_ms and (
            last_moderator_reset_ts_ms <= 0 or created_at_ms > last_moderator_reset_ts_ms
        )
        target_is_current = (
            target_status != "cancelled"
            and target_session_key == active_session_key
            and target_ts_ms >= cutoff_ms
            and (last_moderator_reset_ts_ms <= 0 or target_ts_ms > last_moderator_reset_ts_ms)
        )
        if record_is_current and target_is_current:
            return False
        txn_id = str(record.get("txn_id") or "")
        if txn_id:
            self.matrix_client._complete_outbox(txn_id)
        record["status"] = "cancelled"
        record["cancel_reason"] = "reset_boundary"
        record["cancelled_at_ms"] = current_ms
        return True

    def _dispatch_selection_or_relay_notice(
        self,
        *,
        selections_map: dict[str, dict],
        selection_id: str,
        target_event_id: str,
        selection_seq: int,
        selected_speaker: str,
        wake_reason: str,
        raised_hands: list[str],
        target_sender: str,
        target_body: str,
        root_id: str,
        current_ms: int,
        session_key: str,
        target_origin_server_ts: int,
        is_relay_hop: bool = False,
        after_event_id: str = "",
    ) -> tuple[str, str | None, dict]:
        """Persist pre-send selection metadata (without raw token) and send direct or relay notice."""
        if not is_relay_hop and selected_speaker == SKRYE_ID and self.is_designated_sender:
            scope_id = f"relay-request:{selection_id}"
            kind = "relay_notice"
            remaining = [uid for uid in raised_hands if uid != SKRYE_ID]
            notice_body = format_companion_relay_notice(
                selected_speaker=SKRYE_ID,
                target_sender=target_sender,
                target_body=target_body,
                remaining_hands=remaining,
            )
            mentions_ids: list[str] = []
            relay_meta = {
                "selection_id": selection_id,
                "target_event_id": target_event_id,
                "selection_seq": selection_seq,
                "selected_speaker": SKRYE_ID,
                "wake_reason": wake_reason,
                "target_sender": target_sender,
                "target_body": format_target_message_preview(target_body),
                "remaining_hands": remaining,
                "martin_root_id": root_id,
                "session_key": session_key,
                "target_origin_server_ts": target_origin_server_ts,
            }
            extra_content: dict | None = {COMPANION_RELAY_KEY: relay_meta}
        else:
            scope_id = f"relay-wakeup:{selection_id}" if is_relay_hop else (
                f"wakeup:{target_event_id}" if selection_seq == 1 else f"wakeup:{selection_id}"
            )
            kind = "wakeup_notice"
            notice_body = format_moderator_wakeup_notice(
                raised_hands=raised_hands,
                wake_reason=wake_reason,
                selected_speaker=selected_speaker,
                target_sender=target_sender,
                target_body=target_body,
            )
            mentions_ids = [selected_speaker]
            extra_content = None

        txn_id = make_deterministic_txn_id(
            self.agent_name,
            "notice",
            self.room_id,
            scope_id,
        )
        room_q = urllib.parse.quote(self.room_id, safe="")
        txn_q = urllib.parse.quote(txn_id, safe="")
        path = f"/_matrix/client/v3/rooms/{room_q}/send/m.room.message/{txn_q}"
        payload_body: dict[str, object] = {
            "msgtype": "m.notice",
            "body": notice_body,
            "m.mentions": {"user_ids": list(mentions_ids)} if mentions_ids else {},
        }
        if extra_content:
            payload_body.update(extra_content)

        token_gen_id = self.matrix_client.get_token_generation_id()
        send_record: dict[str, object] = {
            "selection_id": selection_id,
            "target_event_id": target_event_id,
            "after_event_id": after_event_id or target_event_id,
            "selection_seq": selection_seq,
            "selected_speaker": selected_speaker,
            "wake_reason": wake_reason,
            "martin_root_id": root_id,
            "session_key": session_key,
            "target_origin_server_ts": target_origin_server_ts,
            "sending_account": self.matrix_client.self_user_id,
            "token_generation_id": token_gen_id,
            "scope_id": scope_id,
            "txn_id": txn_id,
            "path": path,
            "payload": payload_body,
            "kind": kind,
            "created_at_ms": current_ms,
            "status": "sending",
            "wakeup_event_id": None,
        }
        selections_map[selection_id] = send_record
        comp_state = self.state_store.read_companion_state()
        wakeups = dict(_as_dict(comp_state.get("wakeups")))
        map_key = "relayed_selections" if is_relay_hop else "selections"
        wakeups[map_key] = selections_map
        self.state_store.write_companion_state({"wakeups": wakeups})

        try:
            ev_id = self.matrix_client.send_notice(
                body_text=notice_body,
                scope_id=scope_id,
                mentions_user_ids=mentions_ids,
                extra_content=extra_content,
                kind=kind,
                metadata={"selection_id": selection_id, "token_generation_id": token_gen_id},
                allow_relogin_retry=False,
            )
        except MatrixAPIError as exc:
            if exc.status == 401 or exc.errcode == "M_UNKNOWN_TOKEN":
                self.matrix_client.login(force=True)
                self.matrix_client._complete_outbox(txn_id)
                send_record["status"] = "uncertain_blocked"
                send_record["blocked_reason"] = "token_expired_during_send"
                send_record["blocked_at_ms"] = current_ms
                return "uncertain_blocked", None, send_record
            raise

        send_record["status"] = "sent"
        send_record["sent_at_ms"] = current_ms
        send_record["wakeup_event_id"] = ev_id
        return "sent", ev_id, send_record

    def _ingest_and_reconcile_relay(
        self,
        actionable_events: list[dict] | None,
        generation: dict | None,
        current_ms: int,
    ) -> dict:
        """Traya-only relay for explicit Skrye speaker selections emitted by Skrye's companion."""
        gen = generation if isinstance(generation, dict) else self.resolver.resolve(now_override_ms=current_ms)
        active_session_key = str(gen["active_session_key"])
        cutoff_ms = _safe_int(gen["cutoff_ms"], 0)

        comp_state = self.state_store.read_companion_state()
        wakeups = _as_dict(comp_state.get("wakeups"))
        relayed_selections: dict[str, dict] = dict(_as_dict(wakeups.get("relayed_selections")))
        last_mod_reset_ts = _safe_int(wakeups.get("last_moderator_reset_ts_ms"), 0)

        for ev in actionable_events or []:
            if not isinstance(ev, dict) or ev.get("seed"):
                continue
            if is_conversational_room_message(ev) and ev.get("sender") in ALLOWLIST_USER_IDS:
                body = str(ev.get("body") or "")
                if is_new_command_targeting(body, TRAYA_ID) or is_new_command_targeting(body, SKRYE_ID):
                    ev_ts = _safe_int(ev.get("origin_server_ts"), current_ms)
                    last_mod_reset_ts = max(last_mod_reset_ts, ev_ts)

        room_data = self.state_store.read_room_events()
        recent_events: list[dict] = room_data.get("recent_events", [])
        recent_by_id = {
            str(ev.get("event_id")): ev
            for ev in recent_events
            if isinstance(ev, dict) and isinstance(ev.get("event_id"), str)
        }
        _, live_bot_turns, _ = self._compute_timeline_discussion_state(
            recent_events=recent_events,
            active_session_key=active_session_key,
            cutoff_ms=cutoff_ms,
            last_moderator_reset_ts_ms=last_mod_reset_ts,
        )

        sent_wakeups: list[dict] = []

        # 1. Cancel stale relay records before retrying interrupted sends.
        for sel_id, r_entry in list(relayed_selections.items()):
            if not isinstance(r_entry, dict) or r_entry.get("status") != "sending":
                continue
            if self._cancel_stale_sending_record(
                r_entry,
                cutoff_ms,
                last_mod_reset_ts,
                current_ms,
                active_session_key,
                recent_by_id.get(str(r_entry.get("target_event_id") or "")),
            ):
                continue
            status_out, ev_id = self._reconcile_sending_record(r_entry, recent_events, current_ms)
            if status_out == "sent":
                sent_wakeups.append(
                    {
                        "selection_id": sel_id,
                        "target_event_id": r_entry.get("target_event_id"),
                        "wakeup_event_id": ev_id,
                        "selected_speaker": SKRYE_ID,
                        "relayed": True,
                    }
                )

        # 2. Scan recent_events for non-seed relay notices from SKRYE_ID targeting SKRYE_ID.
        for idx, ev in enumerate(recent_events):
            if not isinstance(ev, dict) or ev.get("seed"):
                continue
            if ev.get("msgtype") != "m.notice" or ev.get("sender") != SKRYE_ID:
                continue
            relay_meta = ev.get("companion_relay")
            if not isinstance(relay_meta, dict):
                continue
            if relay_meta.get("selected_speaker") != SKRYE_ID:
                continue
            sel_id = str(relay_meta.get("selection_id") or "").strip()
            target_ev_id = str(relay_meta.get("target_event_id") or "").strip()
            if not sel_id or not target_ev_id:
                continue
            existing_rel = relayed_selections.get(sel_id)
            if isinstance(existing_rel, dict) and existing_rel.get("status") in (
                "sent",
                "uncertain_blocked",
                "suppressed",
                "cancelled",
            ):
                continue

            relay_ts_ms = _safe_int(ev.get("origin_server_ts"), 0)
            relay_ev_id = str(ev.get("event_id") or "")
            target_ev = recent_by_id.get(target_ev_id, {})
            target_ts_ms = _safe_int(
                relay_meta.get("target_origin_server_ts"),
                _safe_int(target_ev.get("origin_server_ts"), 0),
            )
            target_session_key = active_session_key
            if (
                relay_ts_ms < cutoff_ms
                or (last_mod_reset_ts > 0 and relay_ts_ms <= last_mod_reset_ts)
                or target_ts_ms < cutoff_ms
                or (last_mod_reset_ts > 0 and target_ts_ms <= last_mod_reset_ts)
            ):
                relayed_selections[sel_id] = {
                    "selection_id": sel_id,
                    "target_event_id": target_ev_id,
                    "status": "cancelled",
                    "cancel_reason": "reset_boundary",
                }
                continue

            if live_bot_turns >= self.max_bot_turns_since_martin:
                relayed_selections[sel_id] = {
                    "selection_id": sel_id,
                    "target_event_id": target_ev_id,
                    "status": "budget_exhausted",
                }
                continue

            # Check no newer conversational message, /new reset, or Skrye 👀/🐝 reaction arrived after the relay notice.
            superseded = False
            for later_ev in recent_events[idx + 1 :]:
                if not isinstance(later_ev, dict):
                    continue
                l_sender = str(later_ev.get("sender") or "")
                l_body = str(later_ev.get("body") or "")
                if is_conversational_room_message(later_ev) and l_sender in ALLOWLIST_USER_IDS:
                    superseded = True
                    break
                if later_ev.get("msgtype") == "m.notice" and l_sender == TRAYA_ID:
                    if SKRYE_ID in (later_ev.get("mentioned_bots") or []):
                        superseded = True
                        break
                if later_ev.get("is_new_command") or is_new_command_message(l_body):
                    superseded = True
                    break
            if not superseded:
                for msg_ev in recent_events:
                    if not isinstance(msg_ev, dict):
                        continue
                    for rxn in _as_dict(msg_ev.get("reactions")).values():
                        if (
                            isinstance(rxn, dict)
                            and rxn.get("sender") == SKRYE_ID
                            and rxn.get("key") in (ACK_REACTION_KEY, ACTIVE_BEE_KEY)
                            and _safe_int(rxn.get("ts_ms"), 0) >= relay_ts_ms
                        ):
                            superseded = True
                            break
                    if superseded:
                        break

            if superseded:
                relayed_selections[sel_id] = {
                    "selection_id": sel_id,
                    "target_event_id": target_ev_id,
                    "status": "suppressed",
                }
                continue

            rem_hands = [
                str(u) for u in (relay_meta.get("remaining_hands") or []) if isinstance(u, str)
            ]
            all_hands = [SKRYE_ID, *[u for u in rem_hands if u != SKRYE_ID]]
            status_out, wakeup_ev_id, _ = self._dispatch_selection_or_relay_notice(
                selections_map=relayed_selections,
                selection_id=sel_id,
                target_event_id=target_ev_id,
                selection_seq=_safe_int(relay_meta.get("selection_seq"), 1),
                selected_speaker=SKRYE_ID,
                wake_reason=str(relay_meta.get("wake_reason") or "raised_hand"),
                raised_hands=all_hands,
                target_sender=str(relay_meta.get("target_sender") or ""),
                target_body=str(relay_meta.get("target_body") or ""),
                root_id=str(relay_meta.get("martin_root_id") or ""),
                current_ms=current_ms,
                session_key=target_session_key,
                target_origin_server_ts=target_ts_ms,
                is_relay_hop=True,
                after_event_id=relay_ev_id,
            )
            if status_out == "sent":
                sent_wakeups.append(
                    {
                        "selection_id": sel_id,
                        "target_event_id": target_ev_id,
                        "wakeup_event_id": wakeup_ev_id,
                        "selected_speaker": SKRYE_ID,
                        "relayed": True,
                    }
                )

        self.state_store.write_companion_state(
            {
                "wakeups": {
                    **wakeups,
                    "relayed_selections": relayed_selections,
                    "last_moderator_reset_ts_ms": last_mod_reset_ts,
                }
            }
        )
        return {
            "status": "ok",
            "sent_wakeups": sent_wakeups,
            "relayed_selections": relayed_selections,
        }

    def ingest_and_reconcile(
        self,
        actionable_events: list[dict] | None = None,
        generation: dict | None = None,
        now_override_ms: int | None = None,
    ) -> dict:
        current_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        if self.is_relay_sender:
            return self._ingest_and_reconcile_relay(actionable_events, generation, current_ms)
        if not self.is_designated_sender:
            return {"status": "disabled_non_skrye", "sent_wakeups": []}

        gen = generation if isinstance(generation, dict) else self.resolver.resolve(now_override_ms=current_ms)
        active_session_key = str(gen["active_session_key"])
        cutoff_ms = _safe_int(gen["cutoff_ms"], 0)

        comp_state = self.state_store.read_companion_state()
        wakeups = _as_dict(comp_state.get("wakeups"))
        targets: dict[str, dict] = dict(_as_dict(wakeups.get("targets")))
        martin_roots: dict[str, dict] = dict(_as_dict(wakeups.get("martin_roots")))
        selections: dict[str, dict] = dict(_as_dict(wakeups.get("selections")))
        last_mod_reset_ts = _safe_int(wakeups.get("last_moderator_reset_ts_ms"), 0)

        # 1. Inspect actionable events for moderator /new resets (targeting @traya or untagged /new).
        for ev in actionable_events or []:
            if not isinstance(ev, dict) or ev.get("seed"):
                continue
            if is_conversational_room_message(ev) and ev.get("sender") in ALLOWLIST_USER_IDS:
                body = str(ev.get("body") or "")
                if is_new_command_targeting(body, SKRYE_ID) or is_new_command_targeting(body, TRAYA_ID):
                    ev_ts = _safe_int(ev.get("origin_server_ts"), current_ms)
                    last_mod_reset_ts = max(last_mod_reset_ts, ev_ts)
                    for t_entry in targets.values():
                        if (
                            isinstance(t_entry, dict)
                            and not t_entry.get("notified")
                            and _safe_int(t_entry.get("origin_server_ts"), 0) <= ev_ts
                        ):
                            t_entry["status"] = "cancelled"
                            t_entry["cancel_reason"] = "moderator_reset"
                    for r_entry in martin_roots.values():
                        if isinstance(r_entry, dict):
                            r_entry["pending_hands"] = []
                            r_entry["active_speaker"] = None

        room_data = self.state_store.read_room_events()
        recent_events: list[dict] = room_data.get("recent_events", [])
        recent_by_id = {
            ev["event_id"]: ev
            for ev in recent_events
            if isinstance(ev, dict) and isinstance(ev.get("event_id"), str)
        }

        current_root_id, live_bot_turns_initial, event_root_map = self._compute_timeline_discussion_state(
            recent_events=recent_events,
            active_session_key=active_session_key,
            cutoff_ms=cutoff_ms,
            last_moderator_reset_ts_ms=last_mod_reset_ts,
        )

        # Clear pending_hands on any superseded martin_root_id when Martin posts a new message.
        for r_key, r_entry in list(martin_roots.items()):
            if isinstance(r_entry, dict) and r_key != current_root_id and r_entry.get("pending_hands"):
                r_entry["pending_hands"] = []
                r_entry["active_speaker"] = None

        sent_wakeups: list[dict] = []

        # 1B. Cancel stale selection records before retrying interrupted sends.
        for sel_id, sel_entry in list(selections.items()):
            if not isinstance(sel_entry, dict) or sel_entry.get("status") != "sending":
                continue
            tid_ref = str(sel_entry.get("target_event_id") or "")
            t_ref = targets.get(tid_ref)
            if self._cancel_stale_sending_record(
                sel_entry,
                cutoff_ms,
                last_mod_reset_ts,
                current_ms,
                active_session_key,
                t_ref,
            ):
                if isinstance(t_ref, dict):
                    t_ref["status"] = "cancelled"
                    t_ref["cancel_reason"] = "reset_boundary"
                continue
            status_out, ev_id = self._reconcile_sending_record(sel_entry, recent_events, current_ms)
            if status_out == "sent":
                if isinstance(t_ref, dict):
                    t_ref["notified"] = True
                    t_ref["status"] = "notified"
                    t_ref["wakeup_event_id"] = ev_id
                sent_wakeups.append(
                    {
                        "selection_id": sel_id,
                        "target_event_id": tid_ref,
                        "wakeup_event_id": ev_id,
                        "reason": sel_entry.get("wake_reason", "raised_hand"),
                        "selected_speaker": sel_entry.get("selected_speaker"),
                        "martin_root_id": sel_entry.get("martin_root_id"),
                    }
                )
            elif status_out == "uncertain_blocked" and isinstance(t_ref, dict):
                t_ref["status"] = "uncertain_blocked"

        # 1C. Reconcile companion-managed pending_hands queue for current_root_id.
        handled_by_queue_event_ids: set[str] = set()
        active_root_entry = dict(_as_dict(martin_roots.get(current_root_id)))
        pending_hands = [
            str(u)
            for u in (active_root_entry.get("pending_hands") or [])
            if isinstance(u, str) and u in BOT_IDS
        ]
        source_tid = str(active_root_entry.get("source_target_event_id") or "")
        if pending_hands and source_tid:
            source_ev = recent_by_id.get(source_tid)
            invited_at_ms = _safe_int(active_root_entry.get("invited_at_ms"), 0)
            active_speaker = str(active_root_entry.get("active_speaker") or "")
            root_count = _safe_int(active_root_entry.get("count"), 0)

            # Check if any hand-raiser withdrew ✋🏻 or replaced it with 👌🏻/👍🏻 on source_ev.
            if isinstance(source_ev, dict):
                source_target = _as_dict(targets.get(source_tid))
                expected_for_source = [
                    str(x)
                    for x in (source_target.get("expected_assessors") or sorted(BOT_IDS))
                    if isinstance(x, str)
                ]
                current_badges = self._active_badges_for_target(source_ev, expected_for_source)
                pending_hands = [uid for uid in pending_hands if current_badges.get(uid) == "✋🏻"]
            else:
                pending_hands = []

            # Inspect messages after source_tid in recent_events.
            seen_source = False
            speaker_finished_untagged_ev: dict | None = None
            peer_tagged_or_martin_spoke = False
            for ev in recent_events:
                if not isinstance(ev, dict):
                    continue
                ev_id = str(ev.get("event_id") or "")
                if not seen_source:
                    if ev_id == source_tid:
                        seen_source = True
                    continue
                if not is_conversational_room_message(ev):
                    continue
                sender = str(ev.get("sender") or "")
                body = str(ev.get("body") or "")
                ev_ts = _safe_int(ev.get("origin_server_ts"), 0)
                if ev.get("is_new_command") or is_new_command_message(body) or sender == MARTIN_ID:
                    peer_tagged_or_martin_spoke = True
                    break
                if sender in pending_hands:
                    pending_hands = [u for u in pending_hands if u != sender]
                mentioned = ev.get("mentioned_bots")
                has_bot_mention = (
                    len(mentioned) > 0
                    if isinstance(mentioned, list)
                    else len(extract_mentioned_bots(body)) > 0
                )
                if ev_ts >= invited_at_ms and sender in BOT_IDS:
                    if has_bot_mention:
                        peer_tagged_or_martin_spoke = True
                        break
                    if sender == active_speaker:
                        speaker_finished_untagged_ev = ev

            if (
                peer_tagged_or_martin_spoke
                or live_bot_turns_initial >= self.max_bot_turns_since_martin
                or root_count >= self.max_wakeups_per_martin_root
            ):
                pending_hands = []
                active_root_entry["pending_hands"] = []
                active_root_entry["active_speaker"] = None
                martin_roots[current_root_id] = active_root_entry
            elif speaker_finished_untagged_ev is not None and pending_hands:
                finished_ev_id = str(speaker_finished_untagged_ev.get("event_id") or "")
                if finished_ev_id:
                    handled_by_queue_event_ids.add(finished_ev_id)
                next_speaker = select_raised_hand_speaker(pending_hands, recent_events, source_tid)
                remaining_after = [u for u in pending_hands if u != next_speaker]
                seq_num = _safe_int(active_root_entry.get("selection_seq"), 1) + 1
                sel_id = f"{source_tid}:seq{seq_num}"
                target_sender_str = str(
                    active_root_entry.get("target_sender")
                    or (source_ev.get("sender") if isinstance(source_ev, dict) else "")
                    or ""
                )
                target_body_str = str(
                    active_root_entry.get("target_body")
                    or (source_ev.get("body") if isinstance(source_ev, dict) else "")
                    or ""
                )
                status_out, notice_ev_id, _ = self._dispatch_selection_or_relay_notice(
                    selections_map=selections,
                    selection_id=sel_id,
                    target_event_id=source_tid,
                    selection_seq=seq_num,
                    selected_speaker=next_speaker,
                    wake_reason="raised_hand",
                    raised_hands=[next_speaker, *remaining_after],
                    target_sender=target_sender_str,
                    target_body=target_body_str,
                    root_id=current_root_id,
                    current_ms=current_ms,
                    session_key=str(source_target.get("session_key") or active_session_key),
                    target_origin_server_ts=_safe_int(
                        source_target.get("origin_server_ts"),
                        _safe_int(source_ev.get("origin_server_ts"), 0) if isinstance(source_ev, dict) else 0,
                    ),
                    is_relay_hop=False,
                    after_event_id=finished_ev_id or source_tid,
                )
                active_root_entry["count"] = root_count + 1
                active_root_entry["selection_seq"] = seq_num
                active_root_entry["pending_hands"] = remaining_after if status_out == "sent" else pending_hands
                active_root_entry["active_speaker"] = next_speaker if status_out == "sent" else active_speaker
                active_root_entry["invited_at_ms"] = current_ms
                active_root_entry["updated_at_ms"] = current_ms
                martin_roots[current_root_id] = active_root_entry
                if status_out == "sent":
                    sent_wakeups.append(
                        {
                            "selection_id": sel_id,
                            "target_event_id": source_tid,
                            "wakeup_event_id": notice_ev_id,
                            "reason": "raised_hand",
                            "selected_speaker": next_speaker,
                            "martin_root_id": current_root_id,
                            "queued_hand_advance": True,
                        }
                    )
            else:
                active_root_entry["pending_hands"] = pending_hands
                martin_roots[current_root_id] = active_root_entry

        # 2. Register new eligible untagged conversational messages from actionable_events.
        for ev in actionable_events or []:
            if not isinstance(ev, dict) or ev.get("seed"):
                continue
            if ev.get("type") in ("m.reaction", "m.room.redaction"):
                continue
            ev_id = ev.get("event_id")
            sender = ev.get("sender")
            body = str(ev.get("body") or "")
            ts_ms = _safe_int(ev.get("origin_server_ts"), 0)
            if (
                not isinstance(ev_id, str)
                or not ev_id
                or ev_id in handled_by_queue_event_ids
                or not is_conversational_room_message(ev)
                or sender not in ALLOWLIST_USER_IDS
                or ev.get("is_new_command")
                or is_new_command_message(body)
                or ts_ms < cutoff_ms
                or (last_mod_reset_ts > 0 and ts_ms <= last_mod_reset_ts)
            ):
                continue
            mentioned = ev.get("mentioned_bots")
            if isinstance(mentioned, list):
                has_bot_mention = len(mentioned) > 0
            else:
                has_bot_mention = len(extract_mentioned_bots(body)) > 0
            if has_bot_mention:
                continue

            if ev_id not in targets:
                expected = sorted(BOT_IDS - {sender})
                root_id = event_root_map.get(ev_id) or (ev_id if sender == MARTIN_ID else current_root_id)
                targets[ev_id] = {
                    "event_id": ev_id,
                    "sender": sender,
                    "origin_server_ts": ts_ms,
                    "session_key": active_session_key,
                    "cutoff_ms": cutoff_ms,
                    "martin_root_id": root_id,
                    "expected_assessors": expected,
                    "created_at_ms": current_ms,
                    "deadline_ms": current_ms + self.deadline_ms,
                    "status": "pending",
                    "notified": False,
                    "wakeup_event_id": None,
                }

        # 3. Evaluate all targets in chronological order.
        sorted_target_ids = sorted(
            targets.keys(),
            key=lambda tid: _safe_int(_as_dict(targets.get(tid)).get("origin_server_ts"), 0),
        )

        for tid in sorted_target_ids:
            target = targets.get(tid)
            if not isinstance(target, dict):
                continue
            if target.get("notified") or target.get("status") in (
                "notified",
                "cancelled",
                "suppressed",
                "budget_exhausted",
                "uncertain_blocked",
            ):
                continue

            t_ts_ms = _safe_int(target.get("origin_server_ts"), 0)
            if (
                target.get("session_key") != active_session_key
                or t_ts_ms < cutoff_ms
                or (last_mod_reset_ts > 0 and t_ts_ms <= last_mod_reset_ts)
            ):
                target["status"] = "cancelled"
                target["cancel_reason"] = "reset_boundary"
                continue

            target_ev = recent_by_id.get(tid)
            if not isinstance(target_ev, dict):
                target["status"] = "cancelled"
                target["cancel_reason"] = "redacted_or_evicted"
                continue

            superseded_by = self._has_newer_allowlisted_message(recent_events, tid, t_ts_ms)
            if superseded_by is not None:
                target["status"] = "suppressed"
                target["suppressed_by"] = superseded_by
                continue

            expected = [
                str(x) for x in (target.get("expected_assessors") or []) if isinstance(x, str)
            ]
            badges_by_assessor = self._active_badges_for_target(target_ev, expected)
            reacted_set = set(badges_by_assessor.keys())
            raised_hands = sorted(
                uid for uid, b in badges_by_assessor.items() if b == "✋🏻"
            )
            all_reacted = (reacted_set == set(expected)) and len(expected) > 0
            moderator_reacted = SKRYE_ID in reacted_set

            target["active_badges"] = badges_by_assessor

            if target.get("status") == "closed_silent":
                if raised_hands:
                    # A late ✋🏻 arrived on a silently closed event: reopen raised-hand timer.
                    target["status"] = "pending"
                    target["deadline_ms"] = current_ms + self.deadline_ms
                    target["reopened_at_ms"] = current_ms
                else:
                    continue

            if target.get("status") != "pending":
                continue

            deadline_val = _safe_int(target.get("deadline_ms"), current_ms + self.deadline_ms)
            deadline_expired = current_ms >= deadline_val

            should_wake = False
            wake_reason = ""
            if raised_hands:
                if all_reacted or deadline_expired:
                    should_wake = True
                    wake_reason = "raised_hand"
            else:
                if all_reacted:
                    # Option A silent closure: all expected assessors returned 👌🏻 or 👍🏻 (zero ✋🏻).
                    target["status"] = "closed_silent"
                    target["closed_at_ms"] = current_ms
                    continue
                if deadline_expired:
                    if target.get("sender") == MARTIN_ID and not moderator_reacted:
                        should_wake = True
                        wake_reason = "moderator_fallback"
                    else:
                        # Skrye returned 👌🏻 or 👍🏻 (or non-Martin target) and a peer is missing with zero ✋🏻.
                        target["status"] = "closed_silent"
                        target["closed_at_ms"] = current_ms
                        continue

            if should_wake:
                # Recheck session/cutoff and budgets immediately before sending.
                recheck_gen = self.resolver.resolve(now_override_ms=current_ms)
                recheck_session = str(recheck_gen["active_session_key"])
                recheck_cutoff = _safe_int(recheck_gen["cutoff_ms"], 0)
                if recheck_session != active_session_key or t_ts_ms < recheck_cutoff:
                    target["status"] = "cancelled"
                    target["cancel_reason"] = "reset_before_send"
                    continue

                latest_room = self.state_store.read_room_events()
                latest_recent = latest_room.get("recent_events", [])
                if not any(isinstance(e, dict) and e.get("event_id") == tid for e in latest_recent):
                    target["status"] = "cancelled"
                    target["cancel_reason"] = "redacted_before_send"
                    continue
                if self._has_newer_allowlisted_message(latest_recent, tid, t_ts_ms) is not None:
                    target["status"] = "suppressed"
                    continue

                _, live_bot_turns, live_root_map = self._compute_timeline_discussion_state(
                    recent_events=latest_recent,
                    active_session_key=recheck_session,
                    cutoff_ms=recheck_cutoff,
                    last_moderator_reset_ts_ms=last_mod_reset_ts,
                )
                root_id = (
                    live_root_map.get(tid)
                    or str(target.get("martin_root_id") or "")
                    or (tid if target.get("sender") == MARTIN_ID else f"root:{recheck_session}")
                )
                root_entry = _as_dict(martin_roots.get(root_id))
                root_count = _safe_int(root_entry.get("count"), 0)

                if (
                    root_count >= self.max_wakeups_per_martin_root
                    or live_bot_turns >= self.max_bot_turns_since_martin
                ):
                    target["status"] = "budget_exhausted"
                    target["budget_exhausted_at_ms"] = current_ms
                    continue

                selected_speaker = (
                    select_raised_hand_speaker(raised_hands, latest_recent, tid)
                    if wake_reason == "raised_hand" and raised_hands
                    else SKRYE_ID
                )
                remaining_hands = [uid for uid in raised_hands if uid != selected_speaker]
                target_sender_str = str(target.get("sender") or "")
                target_body_str = str(target_ev.get("body") or "")
                selection_id = f"{tid}:seq1"

                # Abort before sending if an invitation or reply for this selection already exists in latest_recent.
                already_present = self._timeline_has_delivery_or_speaker_activity(
                    latest_recent,
                    after_event_id=tid,
                    after_ts_ms=t_ts_ms,
                    sending_account=self.matrix_client.self_user_id,
                    notice_body="",
                    selection_id=selection_id,
                    selected_speaker=selected_speaker,
                )
                if already_present:
                    target["notified"] = True
                    target["status"] = "notified"
                    target["wake_reason"] = wake_reason
                    target["selected_speaker"] = selected_speaker
                    target["wakeup_event_id"] = already_present
                    continue

                status_out, notice_event_id, _ = self._dispatch_selection_or_relay_notice(
                    selections_map=selections,
                    selection_id=selection_id,
                    target_event_id=tid,
                    selection_seq=1,
                    selected_speaker=selected_speaker,
                    wake_reason=wake_reason,
                    raised_hands=raised_hands,
                    target_sender=target_sender_str,
                    target_body=target_body_str,
                    root_id=root_id,
                    current_ms=current_ms,
                    session_key=active_session_key,
                    target_origin_server_ts=t_ts_ms,
                    is_relay_hop=False,
                    after_event_id=tid,
                )
                if status_out == "uncertain_blocked":
                    target["status"] = "uncertain_blocked"
                    continue

                target["notified"] = True
                target["status"] = "notified"
                target["wake_reason"] = wake_reason
                target["selected_speaker"] = selected_speaker
                target["remaining_hands"] = remaining_hands
                target["notified_at_ms"] = current_ms
                target["wakeup_event_id"] = notice_event_id

                events_list = list(root_entry.get("events") or [])
                if tid not in events_list:
                    events_list.append(tid)
                martin_roots[root_id] = {
                    "count": root_count + 1,
                    "events": events_list,
                    "pending_hands": remaining_hands,
                    "source_target_event_id": tid,
                    "target_sender": target_sender_str,
                    "target_body": target_body_str,
                    "active_speaker": selected_speaker,
                    "selection_seq": 1,
                    "invited_at_ms": current_ms,
                    "updated_at_ms": current_ms,
                }
                sent_wakeups.append(
                    {
                        "selection_id": selection_id,
                        "target_event_id": tid,
                        "wakeup_event_id": notice_event_id,
                        "reason": wake_reason,
                        "selected_speaker": selected_speaker,
                        "remaining_hands": remaining_hands,
                        "relayed_via_traya": selected_speaker == SKRYE_ID,
                        "martin_root_id": root_id,
                    }
                )

        self.state_store.write_companion_state(
            {
                "wakeups": {
                    **wakeups,
                    "targets": targets,
                    "martin_roots": martin_roots,
                    "selections": selections,
                    "last_moderator_reset_ts_ms": last_mod_reset_ts,
                }
            }
        )
        return {
            "status": "ok",
            "sent_wakeups": sent_wakeups,
            "targets": targets,
            "martin_roots": martin_roots,
            "selections": selections,
        }


class MatrixSyncEngine:
    """Coordinate /sync ingestion, assessments, turn status reactions, and moderator wake-ups."""

    def __init__(
        self,
        state_store: CompanionStateStore,
        resolver: SessionGenerationResolver,
        matrix_client: MatrixClient,
        self_user_id: str,
        room_id: str = DEFAULT_ROOM_ID,
        rpc_client: MoltisRpcClient | None = None,
        main_model: str = "",
        agent_name: str = "",
        agent_display_name: str = "",
        data_dir: Path | str | None = None,
        clock: Callable[[], int] = now_ms,
        async_assessments: bool = False,
    ):
        self.state_store = state_store
        self.resolver = resolver
        self.matrix_client = matrix_client
        self.self_user_id = self_user_id
        self.room_id = room_id
        self.rpc_client = rpc_client
        self.main_model = (main_model or "").strip()
        self.agent_name = (agent_name or state_store.agent_name or "").strip().lower()
        if self.agent_name == "momin":
            self.agent_name = "traya"
        self.agent_display_name = derive_display_name(self.agent_name, agent_display_name)
        self.data_dir = Path(data_dir) if data_dir is not None else resolver.data_dir
        self.clock = clock
        self.async_assessments = bool(async_assessments)

        self.wakeup_coordinator = ModeratorWakeupCoordinator(
            state_store=self.state_store,
            resolver=self.resolver,
            matrix_client=self.matrix_client,
            agent_name=self.agent_name,
            room_id=self.room_id,
            clock=self.clock,
        )
        self.assessment_worker = AssessmentWorker(
            state_store=self.state_store,
            resolver=self.resolver,
            matrix_client=self.matrix_client,
            rpc_client=self.rpc_client,
            agent_name=self.agent_name,
            main_model=self.main_model,
            self_user_id=self.self_user_id,
            room_id=self.room_id,
            clock=self.clock,
            on_assessment_complete=self._on_local_assessment_complete,
        )
        self.turn_reconciler = TurnStatusReconciler(
            state_store=self.state_store,
            matrix_client=self.matrix_client,
            rpc_client=self.rpc_client,
            data_dir=self.data_dir,
            agent_name=self.agent_name,
            agent_display_name=self.agent_display_name,
            self_user_id=self.self_user_id,
            room_id=self.room_id,
            clock=self.clock,
        )

    def _on_local_assessment_complete(self, _assessment_record: dict) -> None:
        if self.wakeup_coordinator.is_designated_sender:
            self.wakeup_coordinator.ingest_and_reconcile(actionable_events=[])

    def start_background_workers(self) -> None:
        if self.async_assessments:
            self.assessment_worker.start()

    def stop_background_workers(self) -> None:
        self.assessment_worker.stop()

    def extract_room_timeline(self, sync_response: dict) -> tuple[list[dict], bool]:
        rooms = sync_response.get("rooms")
        if not isinstance(rooms, dict):
            return [], False
        join = rooms.get("join")
        if not isinstance(join, dict):
            return [], False
        room_obj = join.get(self.room_id)
        if not isinstance(room_obj, dict):
            return [], False
        timeline = room_obj.get("timeline")
        if not isinstance(timeline, dict):
            return [], False
        events = timeline.get("events")
        limited = bool(timeline.get("limited", False))
        return (events if isinstance(events, list) else []), limited

    def process_sync_batch(
        self,
        sync_response: dict,
        prior_next_batch: str | None = None,
        now_override_ms: int | None = None,
    ) -> dict:
        """Ingest one /sync response, flush durable state first, advance next_batch, and coordinate reactions."""
        stamp_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        gen = self.resolver.resolve(now_override_ms=stamp_ms)
        active_session_key = gen["active_session_key"]
        cutoff_ms = gen["cutoff_ms"]

        if gen.get("session_changed"):
            self.assessment_worker.cancel_stale(active_session_key, cutoff_ms)

        saved_batch = prior_next_batch if prior_next_batch is not None else self.state_store.get_next_batch()
        events, limited = self.extract_room_timeline(sync_response)
        seed_only = (saved_batch is None) or limited

        processed = self.state_store.apply_timeline_events(
            events=events,
            active_session_key=active_session_key,
            cutoff_ms=cutoff_ms,
            self_user_id=self.self_user_id,
            seed_only=seed_only,
        )

        next_batch = sync_response.get("next_batch")
        if isinstance(next_batch, str) and next_batch.strip():
            # Durable state in room-events.json and companion-state.json is already flushed on disk.
            self.state_store.advance_next_batch(next_batch)

        actionable_events = [] if seed_only else processed

        enqueued_count = 0
        assessment_results: list[dict] = []
        if actionable_events:
            enqueued_count = self.assessment_worker.enqueue_eligible_events(
                actionable_events,
                active_session_key=active_session_key,
                cutoff_ms=cutoff_ms,
                now_override_ms=stamp_ms,
            )
            if not self.async_assessments and self.rpc_client is not None and self.main_model:
                assessment_results = self.assessment_worker.drain(now_override_ms=stamp_ms)

        turn_result = self.turn_reconciler.reconcile(gen, now_override_ms=stamp_ms)
        wakeup_result = self.wakeup_coordinator.ingest_and_reconcile(
            actionable_events=actionable_events,
            generation=gen,
            now_override_ms=stamp_ms,
        )

        return {
            "generation": gen,
            "seed_only": seed_only,
            "limited": limited,
            "processed_events": processed,
            "actionable_events": actionable_events,
            "next_batch": next_batch,
            "enqueued_assessments": enqueued_count,
            "assessment_results": assessment_results,
            "turn_status": turn_result,
            "wakeup_status": wakeup_result,
        }

    def tick(self, now_override_ms: int | None = None) -> dict:
        """Run timer/peek/queue reconciliation without requiring a new /sync batch."""
        stamp_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        gen = self.resolver.resolve(now_override_ms=stamp_ms)
        if gen.get("session_changed"):
            self.assessment_worker.cancel_stale(gen["active_session_key"], gen["cutoff_ms"])

        assessment_results: list[dict] = []
        if not self.async_assessments and self.rpc_client is not None and self.main_model:
            assessment_results = self.assessment_worker.drain(now_override_ms=stamp_ms)

        turn_result = self.turn_reconciler.reconcile(gen, now_override_ms=stamp_ms)
        wakeup_result = self.wakeup_coordinator.ingest_and_reconcile(
            actionable_events=[],
            generation=gen,
            now_override_ms=stamp_ms,
        )
        return {
            "generation": gen,
            "assessment_results": assessment_results,
            "turn_status": turn_result,
            "wakeup_status": wakeup_result,
        }

    def step(self, timeout_ms: int = 25000) -> dict:
        self.matrix_client.flush_outbox()
        since = self.state_store.get_next_batch()
        sync_resp = self.matrix_client.sync(since=since, timeout_ms=timeout_ms if since else 0)
        return self.process_sync_batch(sync_resp, prior_next_batch=since)


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Moltis Matrix council companion")
    parser.add_argument(
        "--agent-name",
        default=os.environ.get("MOLTIS_COMPANION_AGENT_NAME", ""),
        help="Agent name (skrye, zannah, or traya)",
    )
    parser.add_argument(
        "--agent-display-name",
        default=os.environ.get("MOLTIS_COMPANION_AGENT_DISPLAY_NAME", ""),
        help="Agent display name (Skrye, Zannah, or Traya)",
    )
    parser.add_argument(
        "--main-model",
        default=os.environ.get("MOLTIS_COMPANION_MAIN_MODEL", ""),
        help="Nix-configured mainModel (provider::model)",
    )
    parser.add_argument(
        "--self-user-id",
        default=os.environ.get("MOLTIS_COMPANION_SELF_USER_ID", ""),
        help="Matrix user ID for this agent",
    )
    parser.add_argument(
        "--room-id",
        default=os.environ.get("MOLTIS_COMPANION_ROOM_ID", DEFAULT_ROOM_ID),
        help="Matrix room ID",
    )
    parser.add_argument(
        "--homeserver-url",
        default=os.environ.get("MOLTIS_COMPANION_HOMESERVER_URL", DEFAULT_HOMESERVER_URL),
        help="Matrix homeserver base URL",
    )
    pwd_env_key = "MOLTIS_COMPANION_" + "PASSWORD_PATH"
    parser.add_argument(
        "--password-path",
        default=os.environ.get(pwd_env_key, ""),
        help="Path to Matrix password secret file",
    )
    parser.add_argument(
        "--data-dir",
        default=os.environ.get("MOLTIS_COMPANION_DATA_DIR")
        or os.environ.get("MOLTIS_DATA_DIR")
        or os.path.expanduser("~/.moltis"),
        help="Moltis data directory containing moltis.db and sessions/v1",
    )
    parser.add_argument(
        "--state-dir",
        default=os.environ.get("MOLTIS_COMPANION_STATE_DIR", ""),
        help="Durable companion state directory (~/.local/state/moltis/matrix-companion-<agent>/)",
    )
    parser.add_argument(
        "--rpc-url",
        default=os.environ.get("MOLTIS_COMPANION_RPC_URL", DEFAULT_RPC_URL),
        help="Local Moltis JSON-RPC URL",
    )
    parser.add_argument(
        "--once",
        action="store_true",
        help="Run a single sync cycle and exit",
    )
    return parser


def resolve_runtime_config(args: argparse.Namespace) -> dict:
    agent_name = (args.agent_name or "").strip().lower()
    if agent_name == "momin":
        agent_name = "traya"
    if not agent_name:
        raise ValueError("agentName is required")
    agent_display_name = derive_display_name(agent_name, args.agent_display_name)
    main_model = (args.main_model or "").strip()
    if not main_model:
        raise ValueError("mainModel is required")
    self_user_id = (args.self_user_id or f"@{agent_name}:{SERVER_DOMAIN}").strip()
    room_id = (args.room_id or DEFAULT_ROOM_ID).strip()
    homeserver_url = (args.homeserver_url or DEFAULT_HOMESERVER_URL).strip()
    password_path = (args.password_path or "").strip() or None
    data_dir = Path(args.data_dir).expanduser()
    state_dir_raw = (args.state_dir or "").strip()
    if state_dir_raw:
        state_dir = Path(state_dir_raw).expanduser()
    else:
        xdg_state = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
        state_dir = Path(xdg_state) / "moltis" / f"matrix-companion-{agent_name}"
    rpc_url = (args.rpc_url or DEFAULT_RPC_URL).strip()
    return {
        "agent_name": agent_name,
        "agent_display_name": agent_display_name,
        "main_model": main_model,
        "self_user_id": self_user_id,
        "room_id": room_id,
        "homeserver_url": homeserver_url,
        "password_path": password_path,
        "data_dir": data_dir,
        "state_dir": state_dir,
        "rpc_url": rpc_url,
        "once": bool(getattr(args, "once", False)),
    }


def main(argv: list[str] | None = None) -> int:
    parser = build_arg_parser()
    args = parser.parse_args(argv)
    cfg = resolve_runtime_config(args)

    store = CompanionStateStore(
        state_dir=cfg["state_dir"],
        agent_name=cfg["agent_name"],
        room_id=cfg["room_id"],
    )
    resolver = SessionGenerationResolver(
        data_dir=cfg["data_dir"],
        state_store=store,
        agent_name=cfg["agent_name"],
        room_id=cfg["room_id"],
    )
    matrix_client = MatrixClient(
        homeserver_url=cfg["homeserver_url"],
        self_user_id=cfg["self_user_id"],
        agent_name=cfg["agent_name"],
        room_id=cfg["room_id"],
        password_path=cfg["password_path"],
        state_store=store,
    )
    rpc_client = MoltisRpcClient(rpc_url=cfg["rpc_url"])
    engine = MatrixSyncEngine(
        state_store=store,
        resolver=resolver,
        matrix_client=matrix_client,
        self_user_id=cfg["self_user_id"],
        room_id=cfg["room_id"],
        rpc_client=rpc_client,
        main_model=cfg["main_model"],
        agent_name=cfg["agent_name"],
        agent_display_name=cfg["agent_display_name"],
        data_dir=cfg["data_dir"],
        async_assessments=not cfg["once"],
    )

    resolver.resolve()
    if cfg["once"]:
        engine.step(timeout_ms=0)
        return 0

    engine.start_background_workers()
    backoff = 1.0
    try:
        while True:
            try:
                # Use a short /sync long-poll timeout so 3s dwell, 5s completion, and 15s wake-up timers stay responsive.
                engine.step(timeout_ms=2000)
                backoff = 1.0
            except KeyboardInterrupt:
                return 0
            except Exception as exc:
                sys.stderr.write(f"moltis-matrix-companion loop warning ({cfg['agent_name']}): {exc}\n")
                time.sleep(backoff)
                backoff = min(backoff * 2.0, 30.0)
    finally:
        engine.stop_background_workers()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        print("Moltis: Matrix companion failed.", file=sys.stderr)
        sys.exit(1)
