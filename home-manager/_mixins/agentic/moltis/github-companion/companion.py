"""GitHub notification, open pull-request, and mention wake daemon for Moltis agents."""

from __future__ import annotations

import argparse
import contextlib
import datetime
import fcntl
import hashlib
import http.client
import json
import math
import os
import random
import re
import ssl
import stat
import subprocess
import sys
import time
import urllib.parse
import urllib.request
import uuid
from collections.abc import Callable, Iterable
from pathlib import Path

SERVER_DOMAIN = "matrix.wimpys.world"
DEFAULT_ROOM_ID, DEFAULT_HOMESERVER_URL = f"!the-cauldron:{SERVER_DOMAIN}", f"https://{SERVER_DOMAIN}"
DEFAULT_RPC_URL, DEFAULT_TELEGRAM_API_URL = "https://127.0.0.1:13131/api/rpc", "https://api.telegram.org"
MARTIN_ID, SKRYE_ID, ZANNAH_ID, TRAYA_ID = f"@martin:{SERVER_DOMAIN}", f"@skrye:{SERVER_DOMAIN}", f"@zannah:{SERVER_DOMAIN}", f"@traya:{SERVER_DOMAIN}"
BOT_IDS = frozenset({SKRYE_ID, ZANNAH_ID, TRAYA_ID})
ALLOWLIST_USER_IDS = frozenset({MARTIN_ID, SKRYE_ID, ZANNAH_ID, TRAYA_ID})
DISPLAY_NAMES = {"skrye": "Skrye", "zannah": "Zannah", "traya": "Traya"}
USER_ID_DISPLAY_NAMES = {MARTIN_ID: "Martin", SKRYE_ID: "Skrye", ZANNAH_ID: "Zannah", TRAYA_ID: "Traya"}
AGENT_ORDER = ("skrye", "traya", "zannah")
AGENT_DEFAULT_SCHEDULES: dict[str, tuple[int, str]] = {"skrye": (1, "Monday"), "traya": (5, "Friday"), "zannah": (3, "Wednesday")}
BASE_POLL_INTERVAL_SECS, BASE_POLL_INTERVAL_MS = 300, 300_000
JITTER_MIN_SECS, JITTER_MAX_SECS, JITTER_MIN_MS, JITTER_MAX_MS = 5, 30, 5_000, 30_000
RECONCILE_SWEEP_INTERVAL_MS = 6 * 60 * 60 * 1000
SWEEP_RETRY_BASE_DELAY_MS = RECONCILE_SWEEP_RETRY_DELAY_MS = 15 * 60 * 1000
SWEEP_RETRY_MAX_DELAY_MS = RECONCILE_SWEEP_INTERVAL_MS
DEFAULT_RPC_TIMEOUT_SECS = DEFAULT_COMPLETION_WAIT_TIMEOUT_SECS = DEFAULT_RECOVERY_WAIT_TIMEOUT_SECS = 3600.0
DEFAULT_COMPLETION_TIMEOUT_MS = DEFAULT_RECOVERY_DEADLINE_MS = 3_600_000
DEFAULT_COMPLETION_POLL_INTERVAL_MS = 250
POLL_PR_OWNERS = ("wimpysworld", "linuxmatters", "quickemu-project", "noughtylinux", "oval-tutu", "flexiondotorg")
ALLOWED_NOTIFICATION_OWNERS = frozenset(POLL_PR_OWNERS)
TRUSTED_INSTRUCTION_ACTORS = frozenset({"flexiondotorg", "sith-skrye", "sith-traya", "sith-zannah"})
TRUSTED_BOT_ACTORS = frozenset({"dependabot[bot]", "app/dependabot", "github-actions[bot]", "app/github-actions", "cubic-dev-ai[bot]"})
TRUSTED_GITHUB_ACTORS = TRUSTED_INSTRUCTION_ACTORS | TRUSTED_BOT_ACTORS
GITHUB_AGENT_LOGINS: dict[str, str] = {"skrye": "sith-skrye", "traya": "sith-traya", "zannah": "sith-zannah"}
LOGIN_TO_AGENT_NAME: dict[str, str] = {"sith-skrye": "skrye", "skrye": "skrye", "sith-traya": "traya", "traya": "traya", "sith-zannah": "zannah", "zannah": "zannah"}
STATE_FILENAME, ACTIVE_DISPATCH_FILENAME, SECURITY_EVENTS_FILENAME = "state.json", "active-dispatch.json", "security-events.jsonl"
LEGACY_POLL_STATE_FILENAME, LEGACY_NOTIFICATIONS_STATE_FILENAME = "poll-state.json", "notifications-state.json"
LEGACY_WATERMARKS_FILENAME, LEGACY_SECURITY_OWNERSHIP_FILENAME = "watermarks.json", "security-ownership.json"
OUTBOX_FILENAME, AUTH_STATE_FILENAME = "outbox.json", "auth.json"
COORDINATOR_LOCK_FILENAME, STATE_LOCK_FILENAME = "coordinator.lock", "companion.lock"
ENCODED_COMPONENT_BYTES, MAX_RESPONSE_BYTES = 120, 4 * 1048576
DEFAULT_GH_SESSION_KEY, MAX_THREAD_FAILURE_RETRIES = "companion:github", 3


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
    if isinstance(value, (int, float)):
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


def _http_json_request(url: str, method: str, headers: dict[str, str], raw_body: bytes | None = None, timeout: float = 20.0, allow_loopback_self_signed: bool = False) -> tuple[int, bytes]:
    parsed = _validate_http_url(url)
    host = parsed.hostname or ""
    target_path = f"{parsed.path or '/'}?{parsed.query}" if parsed.query else (parsed.path or "/")
    conn: http.client.HTTPConnection
    if parsed.scheme == "https":
        if allow_loopback_self_signed and host in ("127.0.0.1", "::1", "localhost"):
            ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
        else:
            ctx = ssl.create_default_context()
        conn = http.client.HTTPSConnection(host, port=parsed.port, timeout=timeout, context=ctx)
    else:
        conn = http.client.HTTPConnection(host, port=parsed.port, timeout=timeout)
    try:
        conn.request(method, target_path, body=raw_body, headers=headers)
        resp = conn.getresponse()
        if 300 <= resp.status < 400:
            raise ValueError("HTTP redirect refused")
        data = resp.read(MAX_RESPONSE_BYTES + 1)
        if len(data) > MAX_RESPONSE_BYTES:
            raise ValueError("Oversized HTTP response")
        return resp.status, data
    finally:
        conn.close()


def now_ms() -> int:
    return math.trunc(time.time() * 1000)


def normalize_agent_name(agent_name: str) -> str:
    norm = (agent_name or "").strip().lower()
    if norm not in AGENT_ORDER:
        raise ValueError(f"Unsupported agent_name: {agent_name!r}")
    return norm


def derive_display_name(agent_name: str, explicit: str | None = None) -> str:
    if explicit and explicit.strip():
        return explicit.strip()
    norm = (agent_name or "").strip().lower()
    return DISPLAY_NAMES.get(norm, norm.capitalize() if norm else "Skrye")


def derive_device_id(agent_name: str) -> str:
    norm = (agent_name or "").strip().upper()
    if not norm:
        raise ValueError("agent_name must be non-empty")
    return f"MOLTIS_GH_COMPANION_{norm}"


def display_name_for_user_id(user_id: str) -> str:
    if user_id in USER_ID_DISPLAY_NAMES:
        return USER_ID_DISPLAY_NAMES[user_id]
    if user_id.startswith("@") and ":" in user_id:
        local = user_id[1:].split(":", 1)[0]
        return DISPLAY_NAMES.get(local.lower(), local.capitalize())
    return user_id


_MATRIX_USER_MENTION_RE = re.compile(r"@[A-Za-z0-9._=\-/]+:" + re.escape(SERVER_DOMAIN), re.IGNORECASE)
_HTML_COMMENT_RE = re.compile(r"<!--[\s\S]*?-->")
_UNCLOSED_HTML_COMMENT_RE = re.compile(r"<!--[\s\S]*$")


def sanitize_no_matrix_mentions(text: str) -> str:
    """Guarantee no @...:matrix.wimpys.world string appears in a notice."""
    cleaned = text or ""
    for uid in ALLOWLIST_USER_IDS:
        cleaned = cleaned.replace(uid, display_name_for_user_id(uid))
    cleaned = _MATRIX_USER_MENTION_RE.sub(lambda m: display_name_for_user_id(m.group(0)), cleaned)
    return cleaned.replace(f":{SERVER_DOMAIN}", "")


def strip_html_comments(text: str | None) -> str:
    """Strip all HTML comment blocks (<!-- ... --> and unclosed trailing <!--) from text."""
    return _UNCLOSED_HTML_COMMENT_RE.sub("", _HTML_COMMENT_RE.sub("", text)) if isinstance(text, str) and text else ""


def extract_actor_login(actor_obj: object) -> str:
    """Extract a normalised GitHub actor login from a user/actor/author object or string."""
    if isinstance(actor_obj, str):
        return actor_obj.strip()
    if isinstance(actor_obj, dict):
        is_bot = str(actor_obj.get("__typename") or actor_obj.get("type") or "").strip().lower() == "bot"
        for key in ("login", "name", "slug"):
            val = actor_obj.get(key)
            if isinstance(val, str) and val.strip():
                login = val.strip()
                if is_bot and not login.lower().endswith("[bot]") and not login.lower().startswith("app/"):
                    return f"{login}[bot]"
                return login
    return ""


def normalize_github_actor(actor: object) -> str:
    return extract_actor_login(actor).strip().lower()


def is_trusted_github_actor(actor: object) -> bool:
    return normalize_github_actor(actor) in TRUSTED_GITHUB_ACTORS


def is_trusted_instruction_actor(actor: object) -> bool:
    return normalize_github_actor(actor) in TRUSTED_INSTRUCTION_ACTORS


def is_trusted_bot_actor(actor: object) -> bool:
    return normalize_github_actor(actor) in TRUSTED_BOT_ACTORS


_AGENT_MENTION_PATTERNS: dict[str, re.Pattern[str]] = {
    "skrye": re.compile(r"(?<![A-Za-z0-9_.-])@(?:sith-skrye|skrye)(?::matrix\.wimpys\.world)?\b", re.IGNORECASE),
    "traya": re.compile(r"(?<![A-Za-z0-9_.-])@(?:sith-traya|traya)(?::matrix\.wimpys\.world)?\b", re.IGNORECASE),
    "zannah": re.compile(r"(?<![A-Za-z0-9_.-])@(?:sith-zannah|zannah)(?::matrix\.wimpys\.world)?\b", re.IGNORECASE),
}


def extract_mentioned_github_agents(text: str | None) -> set[str]:
    """Return canonical agent names ('skrye', 'traya', 'zannah') mentioned in text."""
    if not isinstance(text, str) or not text:
        return set()
    combined = f"{text}\n{strip_html_comments(text)}"
    return {name for name, pat in _AGENT_MENTION_PATTERNS.items() if pat.search(combined)}


_COERCION_RULES: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("html_comment_block", re.compile(r"<!--")),
    ("ignore_previous_instructions", re.compile(r"\b(?:ignore|disregard|forget|override|bypass)\s+(?:all\s+|any\s+|the\s+)?(?:previous|prior|above|earlier|system|developer|safety|security)\s+(?:instructions?|prompts?|rules?|constraints?|directives?|guardrails?)\b", re.IGNORECASE)),
    ("system_prompt_override", re.compile(r"(?:\[\s*(?:system|inst|admin|developer)\s*\]|<\|\s*(?:im_start|system|user|assistant)\s*\|>|^\s*(?:system\s+prompt|developer\s+message|new\s+system\s+instructions?)\s*:)", re.IGNORECASE | re.MULTILINE)),
    ("tool_invocation_directive", re.compile(r"\b(?:gh-bot-merge|gh-code-scanning-dismiss|gh-notification-dismiss|gh-review-resolve|gh-review-unresolve|gh-review-inline|gh-review-reply|moltis-telegram-voice|chat\.send_sync|exec_command|tool_call)\b", re.IGNORECASE)),
    ("unauthorized_merge_or_dismiss_command", re.compile(r"\b(?:gh\s+pr\s+merge|merge\s+this\s+(?:pr|pull\s+request)|approve\s+and\s+merge|dismiss\s+(?:this\s+|all\s+)?(?:alert|notification|review)s?|@dependabot\s+(?:merge|squash\s+and\s+merge|ignore|close))\b", re.IGNORECASE)),
    ("role_spoofing", re.compile(r"\b(?:i\s+am\s+flexiondotorg|speaking\s+as\s+flexiondotorg|on\s+behalf\s+of\s+flexiondotorg|acting\s+as\s+(?:flexiondotorg|sith-skrye|sith-traya|sith-zannah)|from\s+flexiondotorg\s*:|authorized\s+by\s+flexiondotorg)\b", re.IGNORECASE)),
)


def detect_coercion_patterns(raw_text: str | None) -> list[str]:
    """Return ordered list of coercion / prompt-injection rule names matched in raw_text."""
    if not isinstance(raw_text, str) or not raw_text:
        return []
    matched: list[str] = []
    stripped = strip_html_comments(raw_text)
    for rule_name, pattern in _COERCION_RULES:
        target = raw_text if rule_name == "html_comment_block" else f"{raw_text}\n{stripped}"
        if pattern.search(target) and rule_name not in matched:
            matched.append(rule_name)
    return matched


def format_security_alert_notice(*, event_kind: str, repo: str, subject_type: str, number: int | None, actor: str, rules_matched: list[str] | None = None, targeted_agents: set[str] | list[str] | None = None) -> str:
    """Format a sanitised notice with zero untrusted excerpts and zero @...:matrix.wimpys.world mentions."""
    clean_repo = re.sub(r"[^A-Za-z0-9_./-]", "", (repo or "unknown/unknown").strip()) or "unknown/unknown"
    clean_subject_type = re.sub(r"[^A-Za-z0-9_-]", "", (subject_type or "Thread").strip()) or "Thread"
    clean_actor = re.sub(r"[^A-Za-z0-9_.\[\]/-]", "", (actor or "unknown").strip()) or "unknown"
    num_suffix = f"#{number}" if isinstance(number, int) and number > 0 else ""
    clean_rules = [re.sub(r"[^A-Za-z0-9_.-]", "", str(r).strip()) for r in (rules_matched or []) if str(r).strip()]
    rule_text = ", ".join(clean_rules) if clean_rules else "untrusted_actor"
    targets = sorted({DISPLAY_NAMES.get(normalize_agent_name(a), a.capitalize()) for a in (targeted_agents or ()) if isinstance(a, str) and a.strip().lower() in DISPLAY_NAMES})
    target_clause = f" targeting {', '.join(targets)}" if targets else ""
    verb = "blocked coercion pattern" if event_kind in ("coercion_pattern", "command_injection") else "stripped untrusted actor activity"
    return sanitize_no_matrix_mentions(f"🛡️ GitHub security filter {verb} ({rule_text}) from actor {clean_actor} on {clean_repo}{num_suffix} ({clean_subject_type}){target_clause}.")


def format_start_of_work_notice(*, agent_display_name: str, kind: str, repo: str | None = None, number: int | None = None, subject_kind: str | None = None, trigger_reason: str | None = None, sweep_date: str | None = None, schedule_day_name: str | None = None) -> str:
    """Format a one-line Telegram start-of-work notice."""
    display = (agent_display_name or "Companion").strip()
    if kind == "targeted":
        target = f"{repo}#{number}" if repo and number else (repo or "GitHub thread")
        line = f"⚙️ {display} starting targeted {(subject_kind or 'PullRequest').strip()} turn on {target} ({(trigger_reason or 'notification').strip()})."
    elif kind == "weekly_sweep":
        line = f"⚙️ {display} starting weekly organisation sweep ({(sweep_date or schedule_day_name or 'scheduled').strip()})."
    else:
        line = f"⚙️ {display} starting 6-hour reconciliation sweep."
    return sanitize_no_matrix_mentions(" ".join(line.splitlines()).strip())


def extract_text_content(value: object) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return "\n".join(p for p in [item if isinstance(item, str) else str(item.get("text") or item.get("content") or "") for item in value if isinstance(item, (str, dict))] if p)
    if isinstance(value, dict):
        for key in ("text", "content", "reply", "response", "body"):
            if isinstance(value.get(key), str):
                return value[key]
        if isinstance(value.get("message"), (str, dict, list)):
            return extract_text_content(value["message"])
    return ""


def is_heartbeat_ok_reply(text: str | None) -> bool:
    """Return True when text is empty or consists solely of HEARTBEAT_OK tokens."""
    if not isinstance(text, str) or not text.strip():
        return True
    tokens = [tok.strip("`").strip() for tok in text.strip().split() if tok.strip("`").strip()]
    return not tokens or all(tok == "HEARTBEAT_OK" for tok in tokens)


TURN_FAILURE_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("explicit_error_token", re.compile(r"^\s*`?(?:(?:HEARTBEAT_ERROR|HEARTBEAT_FAILED|TURN_FAILED|COMPANION_RESULT:\s*(?:ERROR|FAILED))\b|(?:ERROR|FAILED)\s*:)", re.IGNORECASE)),
    ("tool_or_turn_failed", re.compile(r"^\s*(?:the\s+)?(?:github|gh|gh-api-safe|gh-bot-merge|gh-review-inline|gh-review-reply|gh-review-resolve|gh-review-unresolve|gh-notification-dismiss|git|exec|shell|rpc|model|provider|api|command|request|turn|dispatch|tool)\s+(?:tool\s+|command\s+|call\s+|request\s+|execution\s+|turn\s+|helper\s+)?(?:failed|errored|timed\s+out|aborted|crashed|was\s+blocked|is\s+unavailable)\b", re.IGNORECASE)),
    ("unable_to_complete", re.compile(r"^\s*(?:i\s+(?:was\s+|am\s+)?)?(?:failed|unable|could\s+not|cannot|can\s+not)\s+(?:to\s+)?(?:complete|finish|run|execute|fetch|query|read|inspect|review|merge|dismiss|post|reply|process|reach|connect|authenticate|proceed|continue)\b", re.IGNORECASE)),
)


def classify_terminal_turn_outcome(reply_text: str | None, *, assistant_record: dict | None = None, rpc_response: object = None) -> tuple[bool, str | None]:
    """Separate execution termination from task success; return (task_succeeded, failure_reason)."""
    if isinstance(assistant_record, dict):
        if bool(assistant_record.get("error")) or assistant_record.get("is_error") is True:
            return False, f"assistant record error: {str(assistant_record.get('error') or 'is_error=true').strip()}"
        rec_status = str(assistant_record.get("status") or "").strip().lower()
        if rec_status in ("error", "failed", "aborted", "cancelled", "canceled"):
            return False, f"assistant record status={rec_status}"
        stop_reason = str(assistant_record.get("stop_reason") or "").strip().lower()
        if stop_reason in ("error", "failed", "aborted", "cancelled", "canceled", "tool_error"):
            return False, f"assistant record stop_reason={stop_reason}"

    clean_text = (reply_text or "").strip()
    if not clean_text:
        if isinstance(rpc_response, dict) and (rpc_response.get("error") is not None or rpc_response.get("ok") is False):
            return False, "empty terminal assistant reply after RPC error"
        return True, None
    if is_heartbeat_ok_reply(clean_text):
        return True, None
    for rule_name, pattern in TURN_FAILURE_PATTERNS:
        if pattern.search(clean_text):
            return False, f"terminal reply indicates task failure ({rule_name})"
    return True, None


def extract_rpc_reply_text(rpc_response: object) -> str:
    """Extract assistant reply text from a chat.send_sync RPC response envelope."""
    if not isinstance(rpc_response, dict) or rpc_response.get("error") is not None or rpc_response.get("ok") is False:
        return ""
    for container in (rpc_response.get("result"), rpc_response.get("payload"), rpc_response):
        if txt := extract_text_content(container).strip():
            return txt
    return ""


def extract_terminal_reply_text(rpc_response: object = None, assistant_record: dict | None = None) -> str:
    """Extract terminal assistant reply text from history.jsonl assistant record or chat.send_sync response."""
    history_text = extract_text_content(assistant_record.get("content") if "content" in assistant_record else assistant_record).strip() if isinstance(assistant_record, dict) else ""
    rpc_text = extract_rpc_reply_text(rpc_response)
    if (history_text and is_heartbeat_ok_reply(history_text)) or (rpc_text and is_heartbeat_ok_reply(rpc_text)):
        return "HEARTBEAT_OK"
    return history_text if (history_text and history_text.lower() != "done") else (rpc_text or history_text)


def parse_chat_peek_active(rpc_response: object) -> bool | None:
    """Extract boolean active flag from a chat.peek RPC response, or None if unavailable."""
    if not isinstance(rpc_response, dict) or rpc_response.get("error") is not None or rpc_response.get("ok") is False:
        return None
    for container in (rpc_response.get("result"), rpc_response.get("payload"), rpc_response):
        if isinstance(container, dict) and isinstance(container.get("active"), bool):
            return bool(container["active"])
    return None


def verify_history_dispatch_completion(records: list[dict], dispatch_id: str) -> tuple[bool, bool, dict | None]:
    """Return (has_user_record, has_terminal_assistant_record, assistant_record) for dispatch_id."""
    clean_id = (dispatch_id or "").strip()
    if not clean_id or not isinstance(records, list):
        return False, False, None
    user_idx: int | None = None
    for idx, rec in enumerate(records):
        if isinstance(rec, dict) and str(rec.get("role") or "").strip().lower() == "user":
            rec_dispatch_id = str(rec.get("dispatch_id") or _as_dict(rec.get("metadata")).get("dispatch_id") or "").strip()
            if rec_dispatch_id == clean_id or clean_id in extract_text_content(rec.get("content") if "content" in rec else rec):
                user_idx = idx
    if user_idx is None:
        return False, False, None
    subsequent = [rec for rec in records[user_idx + 1 :] if isinstance(rec, dict) and str(rec.get("role") or "").strip().lower() == "assistant"]
    if not subsequent or subsequent[-1].get("tool_calls"):
        return True, False, None
    for candidate in reversed(subsequent):
        if not candidate.get("tool_calls") and (extract_text_content(candidate.get("content") if "content" in candidate else candidate).strip() or candidate.get("completed") is True or candidate.get("stop_reason") in ("end_turn", "stop")):
            return True, True, candidate
    return True, False, None


def check_private(fd: int, directory: bool = False) -> os.stat_result:
    info = os.fstat(fd)
    valid_type = stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode)
    if not valid_type or info.st_uid != os.getuid() or (info.st_mode & 0o077) != 0 or (not directory and info.st_nlink != 1):
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


def read_telegram_bot_token(path: Path | str | None = None) -> str:
    if path is not None and str(path).strip():
        target = Path(str(path).strip())
        if target.is_file():
            raw = target.read_text(encoding="utf-8", errors="replace").strip()
            if raw and len(raw) <= 16384 and "\x00" not in raw:
                return raw.splitlines()[0].strip()
    lookup_var = "TELEGRAM_BOT_" + "TOKEN"
    env_val = os.environ.get(lookup_var, "").strip()
    if env_val and len(env_val) <= 16384 and "\x00" not in env_val:
        return env_val.splitlines()[0].strip()
    raise ValueError("Missing Telegram bot token")


def read_telegram_allowed_chat_id(path: Path | str | None = None) -> str:
    raw = ""
    if path is not None and str(path).strip():
        target = Path(str(path).strip())
        if target.is_file():
            raw = target.read_text(encoding="utf-8", errors="replace").strip()
    if not raw:
        raw = os.environ.get("TELEGRAM_ALLOWED_USERS", "").strip()
    if raw and len(raw) <= 16384 and "\x00" not in raw:
        for candidate in re.split(r"[\s,]+", raw):
            if candidate.strip():
                return candidate.strip()
    raise ValueError("Missing Telegram allowed chat ID")


def atomic_write_json_in_dir(dir_fd: int, filename: str, data: object) -> None:
    if not filename or "/" in filename or filename in (".", ".."):
        raise ValueError(f"Invalid state filename: {filename!r}")
    temp_name = f".{filename}.{uuid.uuid4().hex}.tmp"
    payload = (json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode("utf-8")
    fd = os.open(temp_name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=dir_fd)
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
    if not filename or "/" in filename or filename in (".", ".."):
        raise ValueError(f"Invalid state filename: {filename!r}")
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


def append_jsonl_in_dir(dir_fd: int, filename: str, record: dict) -> None:
    if not filename or "/" in filename or filename in (".", ".."):
        raise ValueError(f"Invalid state filename: {filename!r}")
    line = (json.dumps(record, sort_keys=True, ensure_ascii=False) + "\n").encode("utf-8")
    fd = os.open(filename, os.O_WRONLY | os.O_CREAT | os.O_APPEND | os.O_NOFOLLOW, 0o600, dir_fd=dir_fd)
    with os.fdopen(fd, "wb") as stream:
        check_private(stream.fileno(), directory=False)
        stream.write(line)
        stream.flush()
        os.fsync(stream.fileno())


def read_jsonl_in_dir(dir_fd: int, filename: str) -> list[dict]:
    if not filename or "/" in filename or filename in (".", ".."):
        raise ValueError(f"Invalid state filename: {filename!r}")
    try:
        fd = os.open(filename, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=dir_fd)
    except FileNotFoundError:
        return []
    with os.fdopen(fd, "rb") as stream:
        check_private(stream.fileno(), directory=False)
        raw = stream.read(MAX_RESPONSE_BYTES + 1)
    if len(raw) > MAX_RESPONSE_BYTES:
        raise ValueError(f"Oversized JSONL file: {filename}")
    records: list[dict] = []
    for line in raw.decode("utf-8", errors="replace").splitlines():
        if not line.strip():
            continue
        try:
            parsed = json.loads(line.strip())
        except ValueError:
            continue
        if isinstance(parsed, dict):
            records.append(parsed)
    return records


def normalize_ts(raw_ts: object) -> tuple[int, int]:
    if raw_ts is None or isinstance(raw_ts, bool):
        return 0, 0
    if isinstance(raw_ts, (int, float)):
        val = _safe_int(raw_ts, 0)
        return (0, 0) if val <= 0 else ((val // 1000, val) if val > 10_000_000_000 else (val, val * 1000))
    if isinstance(raw_ts, str):
        text = raw_ts.strip()
        if not text:
            return 0, 0
        if text.isdigit():
            return normalize_ts(int(text))
        with contextlib.suppress(ValueError):
            iso_text = text[:-1] + "+00:00" if text.endswith("Z") else text
            dt = datetime.datetime.fromisoformat(iso_text)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=datetime.timezone.utc)
            ms = math.trunc(dt.timestamp() * 1000)
            return ms // 1000, ms
    return 0, 0


def is_timestamp_newer(candidate: str | None, baseline: str | None) -> bool:
    cand, base = (candidate or "").strip(), (baseline or "").strip()
    if not cand:
        return False
    if not base:
        return True
    _, cand_ms = normalize_ts(cand)
    _, base_ms = normalize_ts(base)
    return (cand_ms > base_ms) if (cand_ms > 0 and base_ms > 0) else (cand > base)


def encoded_key_components(key: str) -> list[str]:
    encoded = key.encode("utf-8").hex()
    return [(f"k{encoded[idx : idx + ENCODED_COMPONENT_BYTES]}" if idx == 0 else encoded[idx : idx + ENCODED_COMPONENT_BYTES]) for idx in range(0, len(encoded), ENCODED_COMPONENT_BYTES)] if encoded else ["k"]


def history_paths(data_dir: Path | str, session_key: str, agent_name: str = "", room_id: str = DEFAULT_ROOM_ID) -> list[Path]:
    sessions_v1 = Path(data_dir) / "sessions" / "v1"
    keys = [session_key, *([f"matrix:matrix-{agent_name}:{room_id}"] if agent_name and f"matrix:matrix-{agent_name}:{room_id}" != session_key else [])]
    paths: list[Path] = []
    for key in [k for k in keys if k]:
        for candidate in (sessions_v1.joinpath(*encoded_key_components(key), "history.jsonl"), sessions_v1 / f"k{key.encode('utf-8').hex()}" / "history.jsonl"):
            if candidate not in paths:
                paths.append(candidate)
    return paths


def load_session_history_records(data_dir: Path | str, session_key: str, agent_name: str = "", room_id: str = DEFAULT_ROOM_ID) -> list[dict]:
    for path in history_paths(data_dir, session_key, agent_name=agent_name, room_id=room_id):
        if not path.is_file():
            continue
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        parsed: list[dict] = []
        for idx, line in enumerate(lines):
            if not line.strip():
                continue
            try:
                item = json.loads(line.strip())
            except ValueError:
                continue
            if isinstance(item, dict):
                parsed.append({"_seq": idx, **item})
        if parsed:
            return parsed
    return []


def make_deterministic_txn_id(agent_name: str, operation: str, *parts: str) -> str:
    material = "::".join([agent_name.strip().lower(), operation.strip(), *(str(p) for p in parts)])
    return f"ghc-{agent_name.strip().lower()}-{hashlib.sha256(material.encode('utf-8')).hexdigest()[:32]}"


def compute_jitter_ms(rng: Callable[[int, int], int] | None = None) -> int:
    picker = rng if rng is not None else random.randint
    return max(JITTER_MIN_MS, min(JITTER_MAX_MS, _safe_int(picker(JITTER_MIN_MS, JITTER_MAX_MS), JITTER_MIN_MS)))


def compute_sweep_retry_delay_ms(failure_count: int) -> int:
    count = max(1, _safe_int(failure_count, 1))
    return min(SWEEP_RETRY_MAX_DELAY_MS, SWEEP_RETRY_BASE_DELAY_MS * (2 ** max(0, count - 1)))


def parse_retry_after_seconds(raw_value: str | int | None, now_sec: int) -> int:
    if raw_value is None:
        return 0
    if isinstance(raw_value, int):
        return max(0, raw_value)
    text = str(raw_value).strip()
    if not text:
        return 0
    if text.isdigit():
        return max(0, int(text))
    with contextlib.suppress(Exception):
        import email.utils

        dt = email.utils.parsedate_to_datetime(text)
        if dt is not None:
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=datetime.timezone.utc)
            return max(0, math.ceil(dt.timestamp() - now_sec))
    return 0


def compute_backoff_wait_ms(headers: dict[str, str] | None, now_ms_val: int, rng: Callable[[int, int], int] | None = None, status: int | None = None) -> tuple[int, int, int]:
    """Return (total_wait_ms, base_wait_secs, jitter_ms) from GitHub response headers."""
    lower_headers = {k.strip().lower(): str(v).strip() for k, v in (headers or {}).items() if isinstance(k, str) and v is not None}
    now_sec = max(0, now_ms_val // 1000)
    poll_interval_sec = max(0, _safe_int(lower_headers.get("x-poll-interval"), 0))
    retry_after_sec = parse_retry_after_seconds(lower_headers.get("retry-after"), now_sec)
    remaining_raw = lower_headers.get("x-ratelimit-remaining")
    remaining_exhausted = remaining_raw is not None and remaining_raw != "" and _safe_int(remaining_raw, 1) <= 0
    is_rate_limited = status in (403, 429) or remaining_exhausted or retry_after_sec > 0
    reset_epoch = _safe_int(lower_headers.get("x-ratelimit-reset"), 0) if is_rate_limited else 0
    rate_reset_wait_sec = max(0, reset_epoch - now_sec) if reset_epoch > 0 else 0
    base_wait_sec = max(BASE_POLL_INTERVAL_SECS, poll_interval_sec, retry_after_sec, rate_reset_wait_sec)
    jitter_ms = compute_jitter_ms(rng)
    return (base_wait_sec * 1000) + jitter_ms, base_wait_sec, jitter_ms


_SUBJECT_NUM_RE = re.compile(r"/(?:pulls|issues)/(\d+)(?:$|[/?#])")
_COMMENT_ID_RE = re.compile(r"/(?:comments|reviews)/(\d+)(?:$|[/?#])")


def extract_subject_number(subject_url: str | None) -> int | None:
    if not isinstance(subject_url, str) or not subject_url.strip():
        return None
    if m := _SUBJECT_NUM_RE.search(subject_url.strip()):
        return _safe_int(m.group(1), 0) or None
    tail = subject_url.rstrip("/").rsplit("/", 1)[-1]
    return int(tail) if tail.isdigit() else None


def extract_comment_id(latest_comment_url: str | None) -> int | None:
    if not isinstance(latest_comment_url, str) or not latest_comment_url.strip():
        return None
    if m := _COMMENT_ID_RE.search(latest_comment_url.strip()):
        return _safe_int(m.group(1), 0) or None
    tail = latest_comment_url.rstrip("/").rsplit("/", 1)[-1]
    return int(tail) if tail.isdigit() else None


def parse_revision_token(revision: str | None) -> tuple[str, int]:
    if not isinstance(revision, str) or not revision.strip():
        return "", 0
    if "::" in revision:
        u_part, c_part = revision.rsplit("::", 1)
        return u_part.strip(), _safe_int(c_part, 0)
    return revision.strip(), 0


def is_allowed_notification_repo(repo_full_name: str | None, owner_login: str | None = None) -> bool:
    owner = (owner_login or "").strip().lower()
    if not owner and isinstance(repo_full_name, str) and "/" in repo_full_name:
        owner = repo_full_name.split("/", 1)[0].strip().lower()
    return owner in ALLOWED_NOTIFICATION_OWNERS


def make_pr_key(repo: str, number: int | str) -> str:
    return f"{repo.strip().lower()}#{int(number)}"


def _is_archived_record(*items: object) -> bool:
    for raw in items:
        d = _as_dict(raw)
        if not d:
            continue
        if bool(d.get("archived") or d.get("isArchived")):
            return True
        for sub in (_as_dict(d.get("repository")), _as_dict(_as_dict(d.get("base")).get("repo"))):
            if bool(sub.get("archived") or sub.get("isArchived")):
                return True
    return False


def normalize_notification_record(raw: dict) -> dict | None:
    if not isinstance(raw, dict):
        return None
    thread_id = str(raw.get("id") or raw.get("thread_id") or "").strip()
    if not thread_id:
        return None
    repo_obj, owner_obj = _as_dict(raw.get("repository")), _as_dict(_as_dict(raw.get("repository")).get("owner"))
    repo_full_name = str(repo_obj.get("full_name") or raw.get("repo") or "").strip()
    owner_login = str(owner_obj.get("login") or raw.get("owner") or "").strip()
    if not repo_full_name and owner_login and repo_obj.get("name"):
        repo_full_name = f"{owner_login}/{repo_obj.get('name')}"
    if not is_allowed_notification_repo(repo_full_name, owner_login):
        return None
    subject = _as_dict(raw.get("subject"))
    subject_url = str(subject.get("url") or raw.get("subject_url") or "").strip() or None
    latest_comment_url = str(subject.get("latest_comment_url") or raw.get("latest_comment_url") or "").strip() or None
    return {
        "thread_id": thread_id, "repo": repo_full_name, "owner": (owner_login or repo_full_name.split("/", 1)[0]).lower(),
        "subject_type": str(subject.get("type") or raw.get("subject_type") or "").strip(),
        "subject_title": str(subject.get("title") or raw.get("subject_title") or "").strip(),
        "subject_url": subject_url, "latest_comment_url": latest_comment_url,
        "number": _safe_int(raw.get("number"), 0) or extract_subject_number(subject_url),
        "comment_id": _safe_int(raw.get("comment_id"), 0) or extract_comment_id(latest_comment_url),
        "updated_at": str(raw.get("updated_at") or "").strip(), "reason": str(raw.get("reason") or "").strip(),
        "unread": bool(raw.get("unread", True)), "archived": _is_archived_record(raw),
    }


def normalize_ci_state(rollup: object) -> str:
    """Normalise GitHub statusCheckRollup into 'SUCCESS', 'PENDING', 'FAILURE', or 'NONE'."""
    if rollup is None:
        return "NONE"
    if isinstance(rollup, str):
        val = rollup.strip().upper()
        if val in ("SUCCESS", "GREEN", "PASSED", "PASS", "NEUTRAL", "SKIPPED"):
            return "SUCCESS"
        if val in ("PENDING", "IN_PROGRESS", "QUEUED", "EXPECTED", "WAITING"):
            return "PENDING"
        return "FAILURE" if val in ("FAILURE", "FAILED", "ERROR", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED") else (val or "NONE")
    if isinstance(rollup, dict):
        contexts = rollup.get("contexts")
        nodes = contexts.get("nodes") if isinstance(contexts, dict) and isinstance(contexts.get("nodes"), list) else (contexts if isinstance(contexts, list) else rollup.get("nodes"))
        if isinstance(nodes, list) and nodes and (node_state := normalize_ci_state(nodes)) != "NONE":
            return node_state
        top = str(rollup.get("state") or rollup.get("status") or rollup.get("conclusion") or "").strip().upper()
        return normalize_ci_state(top) if top else "NONE"
    if isinstance(rollup, list):
        nodes = [n for n in rollup if isinstance(n, dict)]
        has_pending = has_success = False
        for node in nodes:
            status, conclusion, state = str(node.get("status") or "").strip().upper(), str(node.get("conclusion") or "").strip().upper(), str(node.get("state") or "").strip().upper()
            if conclusion in ("FAILURE", "ERROR", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED") or state in ("FAILURE", "ERROR"):
                return "FAILURE"
            if status in ("IN_PROGRESS", "QUEUED", "PENDING", "WAITING", "REQUESTED") or state in ("PENDING", "EXPECTED") or (status and status != "COMPLETED" and not conclusion):
                has_pending = True
            elif conclusion in ("SUCCESS", "NEUTRAL", "SKIPPED") or state == "SUCCESS":
                has_success = True
        return "PENDING" if has_pending else ("SUCCESS" if has_success else "NONE")
    return "NONE"


def extract_review_request_logins(raw_requests: object) -> list[str]:
    nodes = raw_requests["nodes"] if isinstance(raw_requests, dict) and isinstance(raw_requests.get("nodes"), list) else (raw_requests if isinstance(raw_requests, list) else [])
    logins: list[str] = []
    for item in nodes:
        if (norm := normalize_github_actor(item.get("requestedReviewer") if isinstance(item, dict) and "requestedReviewer" in item else item)) and norm not in logins:
            logins.append(norm)
    return logins


def count_unresolved_review_threads(raw_threads: object) -> int:
    review_threads_obj = _as_dict(raw_threads)
    nodes = review_threads_obj["nodes"] if isinstance(review_threads_obj.get("nodes"), list) else (raw_threads if isinstance(raw_threads, list) else [])
    count = sum(1 for item in nodes if isinstance(item, dict) and item.get("isResolved") is not True)
    if _as_dict(review_threads_obj.get("pageInfo")).get("hasNextPage") is True:
        count += 1
    return count


def normalize_open_pull_request_record(raw: dict) -> dict | None:
    if not isinstance(raw, dict) or "subject" in raw or _is_archived_record(raw) or not any(k in raw for k in ("headRefOid", "head", "head_sha", "reviewDecision", "statusCheckRollup", "reviewRequests", "reviewThreads", "isDraft")):
        return None
    number = _safe_int(raw.get("number"), 0)
    if number <= 0:
        return None
    repo_val = raw.get("repository")
    repo_full_name = str(repo_val.get("nameWithOwner") or repo_val.get("full_name") or "").strip() if isinstance(repo_val, dict) else (repo_val.strip() if isinstance(repo_val, str) else str(raw.get("repo") or "").strip())
    if not repo_full_name and (m := re.search(r"github\.com/([^/]+/[^/]+)/pull/", str(raw.get("url") or raw.get("html_url") or ""), re.IGNORECASE)):
        repo_full_name = m.group(1)
    if not is_allowed_notification_repo(repo_full_name):
        return None
    head_sha = str(raw.get("headRefOid") or _as_dict(raw.get("head")).get("sha") or raw.get("head_sha") or "").strip()
    review_decision = str(raw.get("reviewDecision") or raw.get("review_decision") or "").strip().upper()
    ci_raw = raw.get("statusCheckRollup") if "statusCheckRollup" in raw else raw.get("ci_state")
    updated_at = str(raw.get("updatedAt") or raw.get("updated_at") or "").strip()
    review_requests = extract_review_request_logins(raw.get("reviewRequests") if "reviewRequests" in raw else raw.get("requested_reviewers"))
    review_threads = raw.get("reviewThreads") if "reviewThreads" in raw else raw.get("review_threads")
    unresolved_thread_count = max(0, _safe_int(raw.get("unresolved_thread_count"), 0)) if "unresolved_thread_count" in raw else count_unresolved_review_threads(review_threads)
    return {"pr_key": make_pr_key(repo_full_name, number), "repo": repo_full_name, "owner": repo_full_name.split("/", 1)[0].lower(), "number": number, "author": extract_actor_login(raw.get("author") or raw.get("user")), "head_sha": head_sha, "headRefOid": head_sha, "review_decision": review_decision, "reviewDecision": review_decision, "ci_state": normalize_ci_state(ci_raw), "statusCheckRollup": ci_raw, "updated_at": updated_at, "updatedAt": updated_at, "review_requests": review_requests, "reviewRequests": review_requests, "review_threads": review_threads, "reviewThreads": review_threads, "unresolved_thread_count": unresolved_thread_count, "is_draft": bool(raw.get("isDraft") or raw.get("draft", False)), "state": str(raw.get("state") or "OPEN").strip().upper(), "title": str(raw.get("title") or "").strip(), "body": str(raw.get("body") or "").strip(), "url": str(raw.get("url") or raw.get("html_url") or "").strip()}


_HTTP_STATUS_RE = re.compile(r"^HTTP/\d+(?:\.\d+)?\s+(\d{3})(?:\s+(.*))?$", re.IGNORECASE)


def parse_gh_api_paginated_http_output(raw_output: str) -> tuple[int, dict[str, str], list[dict]]:
    """Parse `gh-api-safe ... --paginate -i` output containing one or more HTTP responses."""
    if not isinstance(raw_output, str) or not raw_output.strip():
        return 200, {}, []
    lines = raw_output.replace("\r\n", "\n").split("\n")
    idx, nlines, final_status = 0, len(lines), 200
    merged_headers: dict[str, str] = {}
    body_chunks: list[str] = []
    while idx < nlines:
        while idx < nlines and not lines[idx].strip():
            idx += 1
        if idx >= nlines:
            break
        m = _HTTP_STATUS_RE.match(lines[idx].strip())
        if m:
            status_code = int(m.group(1))
            idx += 1
            page_headers: dict[str, str] = {}
            while idx < nlines and lines[idx].strip() != "":
                if ":" in lines[idx]:
                    hk, hv = lines[idx].split(":", 1)
                    page_headers[hk.strip().lower()] = hv.strip()
                idx += 1
            if idx < nlines and lines[idx].strip() == "":
                idx += 1
            if status_code == 100:
                continue
            final_status = status_code
            for hk, hv in page_headers.items():
                if not (hk == "last-modified" and "last-modified" in merged_headers):
                    merged_headers[hk] = hv
            body_lines: list[str] = []
            while idx < nlines and not _HTTP_STATUS_RE.match(lines[idx].strip()):
                body_lines.append(lines[idx])
                idx += 1
            if "\n".join(body_lines).strip():
                body_chunks.append("\n".join(body_lines).strip())
        else:
            rest = "\n".join(lines[idx:]).strip()
            if rest:
                body_chunks.append(rest)
            break
    if final_status == 304:
        return 304, merged_headers, []
    items: list[dict] = []
    decoder = json.JSONDecoder()
    for chunk in body_chunks:
        pos, clen = 0, len(chunk)
        while pos < clen:
            while pos < clen and chunk[pos].isspace():
                pos += 1
            if pos >= clen:
                break
            parsed, pos = decoder.raw_decode(chunk, pos)
            if isinstance(parsed, list):
                items.extend(entry for entry in parsed if isinstance(entry, dict))
            elif isinstance(parsed, dict):
                items.append(parsed)
    return final_status, merged_headers, items


class CompanionStateStore:
    """Durable 0600 unified state store (state.json) in ~/.local/state/moltis/github-companion-<agent>/."""

    def __init__(self, state_dir: Path | str, agent_name: str, room_id: str = DEFAULT_ROOM_ID, started_at_ms: int | None = None):
        self.state_dir = Path(state_dir)
        self.agent_name = normalize_agent_name(agent_name)
        self.room_id = room_id
        self.started_at_ms = _safe_int(started_at_ms, now_ms()) if started_at_ms is not None else now_ms()
        self.ensure_directory()

    def _default_thread_entry(self, *, handled_updated_at: str | None = None, handled_head_sha: str | None = None, handled_ci_state: str | None = None, retry_count: int = 0) -> dict:
        return {"handled_updated_at": handled_updated_at, "handled_head_sha": handled_head_sha, "handled_ci_state": handled_ci_state, "retry_count": max(0, _safe_int(retry_count, 0))}

    def _default_state(self) -> dict:
        return {"version": 2, "agent_name": self.agent_name, "next_poll_at_ms": None, "last_poll_started_at_ms": None, "last_poll_completed_at_ms": None, "last_status": None, "last_modified": None, "poll_interval_secs": BASE_POLL_INTERVAL_SECS, "retry_after_secs": 0, "last_poll_rate_limited": False, "ratelimit_reset_epoch": None, "last_jitter_ms": None, "last_open_prs_poll_error": None, "last_reconcile_sweep_at_ms": None, "last_reconcile_sweep_attempt_at_ms": None, "reconcile_sweep_retry_after_ms": None, "reconcile_sweep_failure_count": 0, "last_reconcile_sweep_failure_reason": None, "last_weekly_sweep_date": None, "last_weekly_sweep_attempt_at_ms": None, "weekly_sweep_retry_after_ms": None, "weekly_sweep_failure_count": 0, "last_weekly_sweep_failure_reason": None, "threads": {}, "updated_at_ms": self.started_at_ms}

    def _default_active_dispatch(self) -> dict:
        return {"version": 1, "agent_name": self.agent_name, "active": None, "updated_at_ms": self.started_at_ms}

    @staticmethod
    def _try_read_json(dir_fd: int, filename: str) -> dict | None:
        with contextlib.suppress(Exception):
            data = read_json_in_dir(dir_fd, filename, default=None)
            return data if isinstance(data, dict) else None
        return None

    def _migrate_legacy_state_unlocked(self, dir_fd: int) -> dict:
        state = self._default_state()
        legacy_poll = self._try_read_json(dir_fd, LEGACY_POLL_STATE_FILENAME)
        if legacy_poll:
            for key in ("next_poll_at_ms", "last_poll_started_at_ms", "last_poll_completed_at_ms", "last_status", "last_modified", "poll_interval_secs", "retry_after_secs", "last_poll_rate_limited", "ratelimit_reset_epoch", "last_jitter_ms", "last_reconcile_sweep_at_ms", "last_reconcile_sweep_attempt_at_ms", "reconcile_sweep_retry_after_ms", "reconcile_sweep_failure_count", "last_reconcile_sweep_failure_reason", "last_weekly_sweep_date", "last_weekly_sweep_attempt_at_ms", "weekly_sweep_retry_after_ms", "weekly_sweep_failure_count", "last_weekly_sweep_failure_reason"):
                if key in legacy_poll:
                    state[key] = legacy_poll[key]

        notif_threads = _as_dict(_as_dict(self._try_read_json(dir_fd, LEGACY_NOTIFICATIONS_STATE_FILENAME)).get("threads"))
        wm_threads = _as_dict(_as_dict(self._try_read_json(dir_fd, LEGACY_WATERMARKS_FILENAME)).get("threads"))
        threads: dict[str, dict] = {}
        for tid, raw_entry in {**notif_threads, **wm_threads}.items():
            if not isinstance(raw_entry, dict):
                continue
            wm_item, nf_item = _as_dict(wm_threads.get(tid)), _as_dict(notif_threads.get(tid))
            handled_rev = str(wm_item.get("handled_revision") or "").strip()
            parsed_hu, _ = parse_revision_token(handled_rev) if handled_rev else ("", 0)
            repo = str(wm_item.get("repo") or nf_item.get("repo") or "").strip()
            number = _safe_int(wm_item.get("number") or nf_item.get("number"), 0) or None
            migrated = {"thread_id": str(tid), "repo": repo, "number": number, "subject_type": str(wm_item.get("subject_type") or nf_item.get("subject_type") or "").strip(), "updated_at": str(wm_item.get("updated_at") or nf_item.get("updated_at") or "").strip() or None, "handled_updated_at": str(wm_item.get("handled_updated_at") or parsed_hu or "").strip() or None, "handled_head_sha": str(wm_item.get("handled_head_sha") or "").strip() or None, "handled_ci_state": str(wm_item.get("handled_ci_state") or "").strip() or None, "retry_count": max(0, _safe_int(wm_item.get("retry_count", wm_item.get("failure_count", 0)), 0)), "updated_at_ms": self.started_at_ms}
            threads[str(tid)] = migrated
            if repo and number:
                threads[make_pr_key(repo, number)] = dict(migrated)

        state["threads"] = threads
        for legacy_fname in (LEGACY_POLL_STATE_FILENAME, LEGACY_NOTIFICATIONS_STATE_FILENAME, LEGACY_WATERMARKS_FILENAME, LEGACY_SECURITY_OWNERSHIP_FILENAME):
            try:
                os.unlink(legacy_fname, dir_fd=dir_fd)
            except OSError as exc:
                if exc.errno is None:
                    raise
        return state

    def ensure_directory(self) -> None:
        dir_fd = open_private_directory(self.state_dir, create=True)
        try:
            existing_state = self._try_read_json(dir_fd, STATE_FILENAME)
            if not existing_state or not isinstance(existing_state.get("threads"), dict):
                atomic_write_json_in_dir(dir_fd, STATE_FILENAME, self._migrate_legacy_state_unlocked(dir_fd))
            if not self._try_read_json(dir_fd, ACTIVE_DISPATCH_FILENAME):
                atomic_write_json_in_dir(dir_fd, ACTIVE_DISPATCH_FILENAME, self._default_active_dispatch())
            for fname, flags in ((SECURITY_EVENTS_FILENAME, os.O_WRONLY | os.O_CREAT | os.O_APPEND | os.O_NOFOLLOW), (COORDINATOR_LOCK_FILENAME, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK)):
                f_fd = os.open(fname, flags, 0o600, dir_fd=dir_fd)
                try:
                    check_private(f_fd, directory=False)
                finally:
                    os.close(f_fd)
        finally:
            os.close(dir_fd)

    @contextlib.contextmanager
    def _locked_dir(self, lock_filename: str = STATE_LOCK_FILENAME, blocking: bool = True):
        dir_fd = open_private_directory(self.state_dir, create=True)
        try:
            lock_fd = os.open(lock_filename, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600, dir_fd=dir_fd)
            with os.fdopen(lock_fd, "r+", encoding="utf-8") as lock_file:
                check_private(lock_file.fileno(), directory=False)
                fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX if blocking else (fcntl.LOCK_EX | fcntl.LOCK_NB))
                try:
                    yield dir_fd
                finally:
                    fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
        finally:
            os.close(dir_fd)

    @contextlib.contextmanager
    def coordinator_lock(self, blocking: bool = True):
        """Acquire exclusive fcntl.flock on coordinator.lock inside the 0700 state directory."""
        with self._locked_dir(COORDINATOR_LOCK_FILENAME, blocking=blocking) as dir_fd:
            yield dir_fd

    @staticmethod
    def _normalize_sweep_fields(state: dict) -> None:
        for ts_key in ("last_reconcile_sweep_at_ms", "last_reconcile_sweep_attempt_at_ms", "reconcile_sweep_retry_after_ms", "last_weekly_sweep_attempt_at_ms", "weekly_sweep_retry_after_ms"):
            val = _safe_int(state.get(ts_key), 0)
            state[ts_key] = val if val > 0 else None
        for count_key in ("reconcile_sweep_failure_count", "weekly_sweep_failure_count"):
            state[count_key] = max(0, _safe_int(state.get(count_key), 0))
        for str_key in ("last_weekly_sweep_date", "last_reconcile_sweep_failure_reason", "last_weekly_sweep_failure_reason", "last_open_prs_poll_error"):
            raw = state.get(str_key)
            state[str_key] = raw.strip() if isinstance(raw, str) and raw.strip() else None

    def _read_state_unlocked(self, dir_fd: int) -> dict:
        default = self._default_state()
        data = self._try_read_json(dir_fd, STATE_FILENAME)
        if not data:
            return default
        merged = {**default, **{k: v for k, v in data.items() if k not in ("poll_offset_secs", "initial_offset_applied")}, "agent_name": self.agent_name}
        self._normalize_sweep_fields(merged)
        raw_threads = merged.get("threads")
        norm_threads: dict[str, dict] = {}
        if isinstance(raw_threads, dict):
            for k, v in raw_threads.items():
                if isinstance(v, dict):
                    entry = {**self._default_thread_entry(), **v}
                    entry["retry_count"] = max(0, _safe_int(entry.get("retry_count"), 0))
                    norm_threads[str(k)] = entry
        merged["threads"] = norm_threads
        return merged

    def read_state(self) -> dict:
        with self._locked_dir() as dir_fd:
            return self._read_state_unlocked(dir_fd)

    def write_state(self, updates: dict, now_override_ms: int | None = None) -> dict:
        stamp_ms = _safe_int(now_override_ms, now_ms()) if now_override_ms is not None else now_ms()
        with self._locked_dir() as dir_fd:
            state = self._read_state_unlocked(dir_fd)
            if "threads" in updates and isinstance(updates["threads"], dict):
                merged_threads = dict(state.get("threads") or {})
                for k, v in updates["threads"].items():
                    if isinstance(v, dict):
                        entry = {**self._default_thread_entry(), **_as_dict(merged_threads.get(str(k))), **v}
                        entry["retry_count"] = max(0, _safe_int(entry.get("retry_count"), 0))
                        merged_threads[str(k)] = entry
                state.update({k: v for k, v in updates.items() if k != "threads"})
                state["threads"] = merged_threads
            else:
                state.update(updates)
            self._normalize_sweep_fields(state)
            state.update({"agent_name": self.agent_name, "updated_at_ms": stamp_ms})
            atomic_write_json_in_dir(dir_fd, STATE_FILENAME, state)
            return dict(state)

    def record_sweep_attempt(self, kind: str, *, now_override_ms: int | None = None) -> dict:
        stamp_ms = _safe_int(now_override_ms, now_ms()) if now_override_ms is not None else now_ms()
        if kind == "reconcile_sweep":
            return self.write_state({"last_reconcile_sweep_attempt_at_ms": stamp_ms}, now_override_ms=stamp_ms)
        if kind == "weekly_sweep":
            return self.write_state({"last_weekly_sweep_attempt_at_ms": stamp_ms}, now_override_ms=stamp_ms)
        return self.read_state()

    def complete_sweep(self, kind: str, *, sweep_date: str | None = None, now_override_ms: int | None = None) -> dict:
        stamp_ms = _safe_int(now_override_ms, now_ms()) if now_override_ms is not None else now_ms()
        if kind == "reconcile_sweep":
            return self.write_state({"last_reconcile_sweep_at_ms": stamp_ms, "reconcile_sweep_retry_after_ms": None, "reconcile_sweep_failure_count": 0, "last_reconcile_sweep_failure_reason": None}, now_override_ms=stamp_ms)
        if kind == "weekly_sweep":
            updates: dict[str, object] = {"last_reconcile_sweep_at_ms": stamp_ms, "reconcile_sweep_retry_after_ms": None, "reconcile_sweep_failure_count": 0, "last_reconcile_sweep_failure_reason": None, "weekly_sweep_retry_after_ms": None, "weekly_sweep_failure_count": 0, "last_weekly_sweep_failure_reason": None}
            if sweep_date and str(sweep_date).strip():
                updates["last_weekly_sweep_date"] = str(sweep_date).strip()
            return self.write_state(updates, now_override_ms=stamp_ms)
        return self.read_state()

    def fail_sweep(self, kind: str, *, failure_reason: str | None = None, attempt_at_ms: int | None = None, now_override_ms: int | None = None) -> dict:
        stamp_ms = _safe_int(now_override_ms, now_ms()) if now_override_ms is not None else now_ms()
        clean_reason = (failure_reason or "turn_failed").strip() or "turn_failed"
        with self._locked_dir() as dir_fd:
            state = self._read_state_unlocked(dir_fd)
            eff_attempt_ms = _safe_int(attempt_at_ms, 0)
            if kind == "reconcile_sweep":
                failure_count = max(0, _safe_int(state.get("reconcile_sweep_failure_count"), 0)) + 1
                retry_after_ms = stamp_ms + compute_sweep_retry_delay_ms(failure_count)
                prior_attempt = _safe_int(state.get("last_reconcile_sweep_attempt_at_ms"), 0)
                state.update({"last_reconcile_sweep_attempt_at_ms": eff_attempt_ms or prior_attempt or stamp_ms, "reconcile_sweep_failure_count": failure_count, "reconcile_sweep_retry_after_ms": retry_after_ms, "last_reconcile_sweep_failure_reason": clean_reason})
            elif kind == "weekly_sweep":
                failure_count = max(0, _safe_int(state.get("weekly_sweep_failure_count"), 0)) + 1
                retry_after_ms = stamp_ms + compute_sweep_retry_delay_ms(failure_count)
                prior_attempt = _safe_int(state.get("last_weekly_sweep_attempt_at_ms"), 0)
                prior_reconcile_retry = _safe_int(state.get("reconcile_sweep_retry_after_ms"), 0)
                state.update({"last_weekly_sweep_attempt_at_ms": eff_attempt_ms or prior_attempt or stamp_ms, "weekly_sweep_failure_count": failure_count, "weekly_sweep_retry_after_ms": retry_after_ms, "last_weekly_sweep_failure_reason": clean_reason, "reconcile_sweep_retry_after_ms": max(prior_reconcile_retry, retry_after_ms)})
            else:
                return dict(state)
            self._normalize_sweep_fields(state)
            state.update({"agent_name": self.agent_name, "updated_at_ms": stamp_ms})
            atomic_write_json_in_dir(dir_fd, STATE_FILENAME, state)
            return dict(state)

    read_poll_state = read_watermarks = read_notifications_state = read_state
    write_poll_state = write_watermarks = write_notifications_state = write_state

    @staticmethod
    def _matching_keys(threads: dict[str, dict], key: str, repo: str = "", number: int | None = None) -> list[str]:
        keys: list[str] = []
        clean_key = (key or "").strip()
        if clean_key:
            keys.append(clean_key)
            if "#" in clean_key and clean_key.lower() not in keys:
                keys.append(clean_key.lower())
        entry = _as_dict(threads.get(clean_key) or threads.get(clean_key.lower()))
        eff_repo, eff_num, eff_tid = (repo or str(entry.get("repo") or "")).strip(), number or _safe_int(entry.get("number"), 0) or None, str(entry.get("thread_id") or "").strip()
        if eff_tid and eff_tid not in keys:
            keys.append(eff_tid)
        if eff_repo and eff_num:
            pk = make_pr_key(eff_repo, eff_num)
            if pk not in keys:
                keys.append(pk)
        for existing_k, existing_v in threads.items():
            if isinstance(existing_v, dict) and eff_repo and eff_num and str(existing_v.get("repo") or "").strip().lower() == eff_repo.lower() and _safe_int(existing_v.get("number"), 0) == eff_num and existing_k not in keys:
                keys.append(existing_k)
        return keys

    def _load_entry_unlocked(self, threads: dict[str, dict], key: str, repo: str = "", number: int | None = None) -> tuple[list[str], dict]:
        target_keys = self._matching_keys(threads, key, repo=repo, number=number)
        entry = dict(self._default_thread_entry())
        for tk in target_keys:
            if isinstance(threads.get(tk), dict):
                entry.update(threads[tk])
        return target_keys, entry

    def _mutate_thread(self, key: str, mutator: Callable[[dict, int], None], repo: str = "", number: int | None = None, now_override_ms: int | None = None) -> dict:
        stamp_ms = _safe_int(now_override_ms, now_ms()) if now_override_ms is not None else now_ms()
        with self._locked_dir() as dir_fd:
            state = self._read_state_unlocked(dir_fd)
            threads = state["threads"]
            target_keys, entry = self._load_entry_unlocked(threads, key, repo=repo, number=number)
            mutator(entry, stamp_ms)
            entry["retry_count"] = max(0, _safe_int(entry.get("retry_count"), 0))
            entry["updated_at_ms"] = stamp_ms
            for tk in target_keys:
                threads[tk] = dict(entry)
            state["updated_at_ms"] = stamp_ms
            atomic_write_json_in_dir(dir_fd, STATE_FILENAME, state)
            return dict(entry)

    def get_thread_state(self, key: str) -> dict | None:
        threads = _as_dict(self.read_state().get("threads"))
        for candidate in (key, key.lower() if isinstance(key, str) else ""):
            if candidate in threads and isinstance(threads[candidate], dict):
                return dict(threads[candidate])
        return None

    get_thread_watermark = get_thread_state

    def update_thread_state(self, key: str, updates: dict, now_override_ms: int | None = None) -> dict:
        return self._mutate_thread(key, lambda e, _: e.update(updates), repo=str(updates.get("repo") or ""), number=_safe_int(updates.get("number"), 0) or None, now_override_ms=now_override_ms)

    def record_polled_notifications(self, records: list[dict], now_override_ms: int | None = None) -> dict:
        """Persist retrieved notification records into state.json before advancing Last-Modified."""
        stamp_ms = _safe_int(now_override_ms, now_ms()) if now_override_ms is not None else now_ms()
        actionable_threads, queued_followups, auto_dismiss_threads = [], [], []
        with self._locked_dir() as dir_fd:
            state = self._read_state_unlocked(dir_fd)
            threads: dict[str, dict] = state["threads"]
            for item in records:
                norm = normalize_notification_record(item) if (isinstance(item, dict) and "thread_id" not in item) else (dict(item) if isinstance(item, dict) else None)
                if not isinstance(norm, dict):
                    continue
                thread_id = str(norm.get("thread_id") or "").strip()
                if not thread_id or not is_allowed_notification_repo(norm.get("repo"), norm.get("owner")):
                    continue
                repo, subject_type, subject_url = str(norm.get("repo") or "").strip(), str(norm.get("subject_type") or "").strip(), norm.get("subject_url")
                number, comment_id, updated_at = _safe_int(norm.get("number"), 0) or None, _safe_int(norm.get("comment_id"), 0) or None, str(norm.get("updated_at") or "").strip()
                target_keys, existing = self._load_entry_unlocked(threads, thread_id, repo=repo, number=number)
                handled_u, handled_sha, handled_ci = existing.get("handled_updated_at"), existing.get("handled_head_sha"), existing.get("handled_ci_state")
                prior_u = str(existing.get("updated_at") or "").strip()
                newer = is_timestamp_newer(updated_at, prior_u) or (updated_at == prior_u and comment_id is not None and comment_id > _safe_int(existing.get("comment_id"), 0))
                retry_count = 0 if newer else _safe_int(existing.get("retry_count"), 0)

                if norm.get("archived") or _is_archived_record(item, norm) or (subject_type.lower() in ("checksuite", "workflowrun") and not subject_url):
                    entry = {**existing, **norm, "archived": bool(norm.get("archived") or _is_archived_record(item, norm)), "handled_updated_at": updated_at or handled_u, "handled_head_sha": handled_sha, "handled_ci_state": handled_ci, "retry_count": 0, "in_flight": False, "pending_followup": False, "last_polled_at_ms": stamp_ms, "updated_at_ms": stamp_ms}
                    for tk in target_keys:
                        threads[tk] = dict(entry)
                    auto_dismiss_threads.append(thread_id)
                    continue

                unhandled = is_timestamp_newer(updated_at, handled_u) or (not handled_u and bool(updated_at)) or (updated_at == (handled_u or "") and comment_id is not None and comment_id > _safe_int(existing.get("handled_comment_id"), 0))
                in_flight, pending_followup = bool(existing.get("in_flight", False)), bool(existing.get("pending_followup", False))
                if in_flight and unhandled and newer:
                    pending_followup = True
                    queued_followups.append(thread_id)
                elif not in_flight and unhandled and retry_count < MAX_THREAD_FAILURE_RETRIES:
                    actionable_threads.append(thread_id)
                entry = {**existing, **norm, "handled_updated_at": handled_u, "handled_head_sha": handled_sha, "handled_ci_state": handled_ci, "retry_count": retry_count, "in_flight": in_flight, "pending_followup": pending_followup, "last_polled_at_ms": stamp_ms, "updated_at_ms": stamp_ms}
                for tk in target_keys:
                    threads[tk] = dict(entry)
            state["updated_at_ms"] = stamp_ms
            atomic_write_json_in_dir(dir_fd, STATE_FILENAME, state)
        return {"actionable_threads": actionable_threads, "queued_followups": queued_followups, "auto_dismiss_threads": auto_dismiss_threads}

    def record_polled_pull_requests(self, pull_requests: list[dict], self_github_login: str = "", now_override_ms: int | None = None) -> dict:
        """Evaluate and persist open pull requests in state.json for 60-second wake detection."""
        stamp_ms = _safe_int(now_override_ms, now_ms()) if now_override_ms is not None else now_ms()
        self_login_norm = (self_github_login or GITHUB_AGENT_LOGINS[self.agent_name]).strip().lower()
        actionable_prs, queued_followups = [], []
        with self._locked_dir() as dir_fd:
            state = self._read_state_unlocked(dir_fd)
            threads: dict[str, dict] = state["threads"]
            for raw_pr in pull_requests:
                norm_pr = normalize_open_pull_request_record(raw_pr) if "pr_key" not in _as_dict(raw_pr) else dict(raw_pr)
                if not isinstance(norm_pr, dict) or _is_archived_record(raw_pr, norm_pr) or norm_pr.get("is_draft") or str(norm_pr.get("state") or "OPEN").upper() != "OPEN":
                    continue
                repo, number = str(norm_pr.get("repo") or "").strip(), _safe_int(norm_pr.get("number"), 0)
                if not repo or number <= 0:
                    continue
                pr_key, author = make_pr_key(repo, number), str(norm_pr.get("author") or "").strip()
                author_norm = normalize_github_actor(author)
                head_sha = str(norm_pr.get("head_sha") or norm_pr.get("headRefOid") or "").strip()
                review_decision = str(norm_pr.get("review_decision") or norm_pr.get("reviewDecision") or "").strip().upper()
                ci_state = normalize_ci_state(norm_pr.get("ci_state") or norm_pr.get("statusCheckRollup"))
                updated_at = str(norm_pr.get("updated_at") or norm_pr.get("updatedAt") or "").strip()
                review_requests = list(norm_pr.get("review_requests") or norm_pr.get("reviewRequests") or [])
                unresolved_thread_count = (
                    max(0, _safe_int(norm_pr.get("unresolved_thread_count"), 0))
                    if "unresolved_thread_count" in norm_pr
                    else count_unresolved_review_threads(norm_pr.get("reviewThreads") if "reviewThreads" in norm_pr else norm_pr.get("review_threads"))
                )
                target_keys, existing = self._load_entry_unlocked(threads, pr_key, repo=repo, number=number)
                handled_u, handled_sha, handled_ci = existing.get("handled_updated_at"), existing.get("handled_head_sha"), existing.get("handled_ci_state")
                in_flight, pending_followup = bool(existing.get("in_flight", False)), bool(existing.get("pending_followup", False))
                changed = (
                    (head_sha and head_sha != existing.get("head_sha"))
                    or (ci_state and ci_state != existing.get("ci_state"))
                    or ("unresolved_thread_count" in existing and unresolved_thread_count != _safe_int(existing.get("unresolved_thread_count"), 0))
                )
                retry_count = 0 if changed else _safe_int(existing.get("retry_count"), 0)
                is_trusted = is_trusted_github_actor(author_norm)
                is_self = bool(author_norm == self_login_norm or LOGIN_TO_AGENT_NAME.get(author_norm) == self.agent_name)
                trigger_reason: str | None = None
                if is_trusted:
                    if review_decision == "APPROVED" and ci_state in ("SUCCESS", "NONE") and unresolved_thread_count == 0 and (handled_ci != ci_state or (head_sha and handled_sha != head_sha)):
                        trigger_reason = "ci_green_after_approval"
                    elif not is_self and handled_sha and head_sha and head_sha != handled_sha:
                        trigger_reason = "head_push"
                    elif not is_self and not handled_sha and not handled_u:
                        trigger_reason = "review_requested" if self_login_norm in review_requests else "unrequested_pr"
                if trigger_reason is None:
                    if is_self or not is_trusted:
                        handled_u, handled_sha = updated_at or handled_u, head_sha or handled_sha
                        if not is_trusted or ci_state not in ("SUCCESS", "NONE"):
                            handled_ci = ci_state or handled_ci
                    elif ci_state not in ("SUCCESS", "NONE") and ci_state:
                        handled_ci = ci_state
                elif in_flight:
                    pending_followup = True
                    queued_followups.append(pr_key)
                elif retry_count < MAX_THREAD_FAILURE_RETRIES:
                    actionable_prs.append({"key": pr_key, "thread_id": existing.get("thread_id"), "repo": repo, "number": number, "kind": "PullRequest", "head_sha": head_sha, "ci_state": ci_state, "updated_at": updated_at, "trigger_reason": trigger_reason})
                entry = {**existing, "pr_key": pr_key, "repo": repo, "number": number, "subject_type": "PullRequest", "author": author, "head_sha": head_sha, "ci_state": ci_state, "review_decision": review_decision, "review_requests": review_requests, "unresolved_thread_count": unresolved_thread_count, "updated_at": updated_at or existing.get("updated_at"), "handled_updated_at": handled_u, "handled_head_sha": handled_sha, "handled_ci_state": handled_ci, "retry_count": retry_count, "trigger_reason": trigger_reason or existing.get("trigger_reason"), "in_flight": in_flight, "pending_followup": pending_followup, "last_polled_at_ms": stamp_ms, "updated_at_ms": stamp_ms}
                for tk in target_keys:
                    threads[tk] = dict(entry)
            state["updated_at_ms"] = stamp_ms
            atomic_write_json_in_dir(dir_fd, STATE_FILENAME, state)
        return {"actionable_prs": actionable_prs, "queued_followups": queued_followups}

    def mark_thread_in_flight(self, key: str, *, updated_at: str | None = None, head_sha: str | None = None, ci_state: str | None = None, now_override_ms: int | None = None) -> dict:
        def _mark(entry: dict, _: int) -> None:
            entry.update({"in_flight": True, "pending_followup": False, "in_flight_updated_at": updated_at or entry.get("updated_at"), "in_flight_head_sha": head_sha or entry.get("head_sha"), "in_flight_ci_state": ci_state or entry.get("ci_state")})

        return self._mutate_thread(key, _mark, now_override_ms=now_override_ms)

    def complete_thread_review(self, key: str, *, handled_updated_at: str | None = None, handled_head_sha: str | None = None, handled_ci_state: str | None = None, completed_revision: str | None = None, now_override_ms: int | None = None) -> dict:
        rev_u, rev_cid = parse_revision_token(completed_revision)

        def _complete(entry: dict, _: int) -> None:
            fin_u = handled_updated_at or rev_u or entry.get("in_flight_updated_at") or entry.get("updated_at") or entry.get("handled_updated_at")
            fin_sha = handled_head_sha or entry.get("in_flight_head_sha") or entry.get("head_sha") or entry.get("handled_head_sha")
            fin_ci = handled_ci_state or entry.get("in_flight_ci_state") or entry.get("ci_state") or entry.get("handled_ci_state")
            seen_u, seen_sha = str(entry.get("updated_at") or "").strip(), str(entry.get("head_sha") or "").strip()
            has_newer = bool((entry.get("in_flight") and entry.get("pending_followup")) or (seen_u and fin_u and is_timestamp_newer(seen_u, fin_u)) or (seen_sha and fin_sha and seen_sha != fin_sha))
            entry.update({"handled_updated_at": fin_u, "handled_head_sha": fin_sha, "handled_ci_state": fin_ci, "retry_count": 0, "in_flight": False, "pending_followup": has_newer, "dismiss_ready": not has_newer})
            if rev_cid > 0 or entry.get("comment_id"):
                entry["handled_comment_id"] = rev_cid or entry.get("comment_id")

        return self._mutate_thread(key, _complete, now_override_ms=now_override_ms)

    def fail_thread_review(self, key: str, *, failure_reason: str | None = None, max_retries: int = MAX_THREAD_FAILURE_RETRIES, now_override_ms: int | None = None) -> dict:
        retry_limit = max(1, _safe_int(max_retries, MAX_THREAD_FAILURE_RETRIES))

        def _fail(entry: dict, _: int) -> None:
            retry_count = min(retry_limit, _safe_int(entry.get("retry_count"), 0) + 1)
            retry_exhausted = retry_count >= retry_limit
            entry.update({"in_flight": False, "retry_count": retry_count, "retry_exhausted": retry_exhausted, "last_failure_reason": (failure_reason or "turn_failed").strip(), "pending_followup": not retry_exhausted, "dismiss_ready": False})

        return self._mutate_thread(key, _fail, now_override_ms=now_override_ms)

    def read_active_dispatch(self) -> dict:
        with self._locked_dir() as dir_fd:
            return {**self._default_active_dispatch(), **(self._try_read_json(dir_fd, ACTIVE_DISPATCH_FILENAME) or {})}

    def write_active_dispatch(self, active: dict | None, now_override_ms: int | None = None) -> dict:
        stamp_ms = _safe_int(now_override_ms, now_ms()) if now_override_ms is not None else now_ms()
        with self._locked_dir() as dir_fd:
            payload = {"version": 1, "agent_name": self.agent_name, "active": dict(active) if isinstance(active, dict) else None, "updated_at_ms": stamp_ms}
            atomic_write_json_in_dir(dir_fd, ACTIVE_DISPATCH_FILENAME, payload)
            return payload

    def append_security_event(self, event: dict, now_override_ms: int | None = None) -> dict:
        stamp_ms = _safe_int(now_override_ms, now_ms()) if now_override_ms is not None else now_ms()
        record = {"agent_name": self.agent_name, "timestamp_ms": stamp_ms, **event}
        with self._locked_dir() as dir_fd:
            append_jsonl_in_dir(dir_fd, SECURITY_EVENTS_FILENAME, record)
        return record

    def read_security_events(self) -> list[dict]:
        with self._locked_dir() as dir_fd:
            return read_jsonl_in_dir(dir_fd, SECURITY_EVENTS_FILENAME)

    def read_auth(self) -> dict:
        with self._locked_dir() as dir_fd:
            return self._try_read_json(dir_fd, AUTH_STATE_FILENAME) or {}

    def write_auth(self, auth_data: dict) -> None:
        with self._locked_dir() as dir_fd:
            atomic_write_json_in_dir(dir_fd, AUTH_STATE_FILENAME, auth_data)

    def read_outbox(self) -> dict:
        with self._locked_dir() as dir_fd:
            data = self._try_read_json(dir_fd, OUTBOX_FILENAME)
            return data if data and isinstance(data.get("pending"), dict) else {"pending": {}}

    def write_outbox(self, outbox_data: dict) -> None:
        with self._locked_dir() as dir_fd:
            atomic_write_json_in_dir(dir_fd, OUTBOX_FILENAME, outbox_data)


class MatrixClient:
    """Matrix Client-Server v3 HTTP client with durable token and deterministic txnId outbox."""

    def __init__(self, homeserver_url: str, self_user_id: str, agent_name: str, room_id: str, password_path: Path | str | None, state_store: CompanionStateStore, timeout: float = 35.0):
        self.homeserver_url = homeserver_url.rstrip("/")
        _validate_http_url(self.homeserver_url)
        self.self_user_id = self_user_id
        self.agent_name = normalize_agent_name(agent_name)
        self.room_id = room_id
        self.password_path = password_path
        self.state_store = state_store
        self.timeout = timeout
        self.device_id = derive_device_id(self.agent_name)

    def _password_identity_hash(self, password: str) -> str:
        payload = json.dumps([self.homeserver_url, self.self_user_id, self.device_id, password], ensure_ascii=True).encode("utf-8")
        return hashlib.sha256(payload).hexdigest()

    def _request(self, method: str, path: str, query: dict | None = None, body: dict | None = None, token: str | None = None, timeout: float | None = None) -> dict:
        url = f"{self.homeserver_url}{path}"
        if query and (clean_q := {k: str(v) for k, v in query.items() if v is not None}):
            url = f"{url}?{urllib.parse.urlencode(clean_q)}"
        headers = {"Accept": "application/json", "Content-Type": "application/json", **({"Authorization": f"Bearer {token}"} if token else {})}
        raw_body = json.dumps(body, ensure_ascii=False).encode("utf-8") if body is not None else None
        status, raw = _http_json_request(url=url, method=method, headers=headers, raw_body=raw_body, timeout=timeout or self.timeout, allow_loopback_self_signed=False)
        if status >= 400:
            try:
                err_payload = json.loads(raw.decode("utf-8", errors="replace"))
            except (UnicodeDecodeError, ValueError):
                err_payload = None
            raise MatrixAPIError(status, err_payload.get("errcode") if isinstance(err_payload, dict) else None, str(err_payload.get("error") or "") if isinstance(err_payload, dict) else "")
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
            if isinstance(token, str) and token.strip() and cached.get("identity") == identity_hash and cached.get("device_id") == self.device_id and cached.get("user_id") == self.self_user_id:
                return token.strip()
        resp = self._request("POST", "/_matrix/client/v3/login", body={"type": "m.login.password", "identifier": {"type": "m.id.user", "user": self.self_user_id}, "password": password, "device_id": self.device_id}, timeout=20.0)
        token = resp.get("access_token")
        if not isinstance(token, str) or not token.strip():
            raise ValueError("Matrix login response missing access_token")
        auth_record = {"access_token": token.strip(), "device_id": resp.get("device_id") or self.device_id, "user_id": resp.get("user_id") or self.self_user_id, "identity": identity_hash, "updated_at_ms": now_ms()}
        self.state_store.write_auth(auth_record)
        return auth_record["access_token"]

    def _authenticated_request(self, method: str, path: str, query: dict | None = None, body: dict | None = None, timeout: float | None = None) -> dict:
        token = self.login(force=False)
        try:
            return self._request(method, path, query=query, body=body, token=token, timeout=timeout)
        except MatrixAPIError as exc:
            if exc.status == 401 or exc.errcode == "M_UNKNOWN_TOKEN":
                return self._request(method, path, query=query, body=body, token=self.login(force=True), timeout=timeout)
            raise

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
        outbox = self.state_store.read_outbox()
        results: list[dict] = []
        for txn_id, item in list(outbox.get("pending", {}).items()):
            if not isinstance(item, dict) or not isinstance(item.get("path"), str) or not isinstance(item.get("body"), dict):
                self._complete_outbox(txn_id)
                continue
            resp = self._authenticated_request(item.get("method", "PUT"), item["path"], body=item["body"], timeout=20.0)
            self._complete_outbox(txn_id)
            results.append({"txn_id": txn_id, "event_id": resp.get("event_id")})
        return results

    def send_event_with_txn(self, path: str, body: dict, txn_id: str, kind: str, metadata: dict | None = None) -> str | None:
        self._enqueue_outbox(txn_id, {"txn_id": txn_id, "kind": kind, "method": "PUT", "path": path, "body": body, "metadata": metadata or {}, "created_at_ms": now_ms()})
        resp = self._authenticated_request("PUT", path, body=body, timeout=20.0)
        self._complete_outbox(txn_id)
        event_id = resp.get("event_id")
        return event_id if isinstance(event_id, str) else None

    def send_notice(self, body_text: str, scope_id: str, mentions_user_ids: list[str] | None = None) -> str | None:
        clean_text = sanitize_no_matrix_mentions(body_text)
        txn_id = make_deterministic_txn_id(self.agent_name, "notice", self.room_id, scope_id)
        path = f"/_matrix/client/v3/rooms/{urllib.parse.quote(self.room_id, safe='')}/send/m.room.message/{urllib.parse.quote(txn_id, safe='')}"
        body: dict[str, object] = {"msgtype": "m.notice", "body": clean_text, "m.mentions": {"user_ids": list(mentions_user_ids)} if mentions_user_ids else {}}
        return self.send_event_with_txn(path, body, txn_id, kind="notice", metadata={"scope_id": scope_id})


class TelegramClient:
    """Telegram Bot API HTTP client for start-of-work notices, alerts, and terminal replies."""

    def __init__(self, bot_token_path: Path | str | None = None, allowed_users_path: Path | str | None = None, api_url: str = DEFAULT_TELEGRAM_API_URL, timeout: float = 20.0):
        self.bot_token_path = bot_token_path
        self.allowed_users_path = allowed_users_path
        self.api_url = (api_url or DEFAULT_TELEGRAM_API_URL).strip().rstrip("/")
        _validate_http_url(self.api_url)
        self.timeout = timeout

    def send_message(self, text: str) -> dict:
        clean_text = (text or "").strip()
        if not clean_text or is_heartbeat_ok_reply(clean_text):
            return {"ok": True, "skipped": True}
        bot_cred, chat_id = read_telegram_bot_token(self.bot_token_path), read_telegram_allowed_chat_id(self.allowed_users_path)
        status, raw = _http_json_request(url=f"{self.api_url}/bot{bot_cred}/sendMessage", method="POST", headers={"Content-Type": "application/json", "Accept": "application/json"}, raw_body=json.dumps({"chat_id": chat_id, "text": clean_text}, ensure_ascii=False).encode("utf-8"), timeout=self.timeout, allow_loopback_self_signed=False)
        if status >= 400:
            raise RuntimeError(f"Telegram sendMessage HTTP {status}")
        if not raw.strip():
            return {"ok": True}
        try:
            data = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, ValueError) as exc:
            raise ValueError("Invalid JSON in Telegram API response") from exc
        if isinstance(data, dict) and data.get("ok") is False:
            raise RuntimeError(str(data.get("description") or f"Telegram API error {data.get('error_code') or ''}").strip() or "Telegram sendMessage returned ok=false")
        return data if isinstance(data, dict) else {"ok": True}


class MoltisRpcClient:
    """Loopback JSON-RPC client for Moltis POST /api/rpc (chat.send_sync and chat.peek)."""

    def __init__(self, rpc_url: str = DEFAULT_RPC_URL, timeout: float = DEFAULT_RPC_TIMEOUT_SECS, send_sync_timeout: float = DEFAULT_RPC_TIMEOUT_SECS):
        self.rpc_url = rpc_url
        _validate_http_url(self.rpc_url)
        self.timeout = timeout
        self.send_sync_timeout = send_sync_timeout

    def call(self, method: str, params: dict, timeout: float | None = None) -> dict:
        payload = {"jsonrpc": "2.0", "id": f"rpc-{uuid.uuid4().hex}", "method": method, "params": params}
        status, raw = _http_json_request(url=self.rpc_url, method="POST", headers={"Content-Type": "application/json", "Accept": "application/json"}, raw_body=json.dumps(payload, ensure_ascii=False).encode("utf-8"), timeout=timeout or self.timeout, allow_loopback_self_signed=True)
        if status >= 400:
            raise RuntimeError(f"Moltis RPC HTTP {status}")
        try:
            data = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, ValueError) as exc:
            raise ValueError("Invalid JSON in Moltis RPC response") from exc
        return data if isinstance(data, dict) else {}

    def chat_peek(self, session_key: str, timeout: float = 5.0) -> dict:
        return self.call("chat.peek", {"sessionKey": session_key}, timeout=timeout)

    def chat_send_sync(self, model: str, message: str, session_key: str = DEFAULT_GH_SESSION_KEY, ephemeral: bool = False, active_tools: list[str] | None = None, timeout: float | None = None) -> dict:
        params: dict[str, object] = {"model": model, "message": message, "_session_key": session_key, "_ephemeral": bool(ephemeral)}
        if active_tools is not None:
            params["active_tools"] = list(active_tools)
        return self.call("chat.send_sync", params, timeout=self.send_sync_timeout if timeout is None else timeout)


OPEN_PRS_GRAPHQL_QUERY_TEMPLATE = "query($endCursor: String) { search(query: %s, type: ISSUE, first: 100, after: $endCursor) { pageInfo { hasNextPage endCursor } nodes { ... on PullRequest { number title url state isDraft updatedAt headRefOid reviewDecision repository { nameWithOwner isArchived } author { __typename login } reviewRequests(first: 20) { nodes { requestedReviewer { ... on User { login } } } } reviewThreads(first: 100) { pageInfo { hasNextPage } nodes { isResolved } } statusCheckRollup { state contexts(first: 100) { nodes { __typename ... on CheckRun { status conclusion } ... on StatusContext { state } } } } } } } }"


def build_open_prs_graphql_query(owners: Iterable[str] = POLL_PR_OWNERS) -> str:
    owner_clauses = " ".join(f"user:{o.strip()}" for o in owners if str(o).strip())
    return OPEN_PRS_GRAPHQL_QUERY_TEMPLATE % json.dumps(f"is:pr is:open draft:false archived:false {owner_clauses}".strip())


class GhApiSafeClient:
    """Subprocess wrapper around `gh-api-safe` and `gh-notification-dismiss`."""

    def __init__(self, gh_api_safe_bin: str = "gh-api-safe", gh_notification_dismiss_bin: str = "gh-notification-dismiss", runner: Callable[..., subprocess.CompletedProcess] | None = None, timeout: float = 45.0):
        self.gh_api_safe_bin = gh_api_safe_bin
        self.gh_notification_dismiss_bin = gh_notification_dismiss_bin
        self.runner = runner or subprocess.run
        self.timeout = timeout

    def invoke(self, args: list[str], timeout: float | None = None) -> subprocess.CompletedProcess:
        return self.runner([self.gh_api_safe_bin, *args], capture_output=True, text=True, timeout=timeout or self.timeout, check=False)

    def dismiss_notification(self, thread_id: str, *, read_only: bool = False, timeout: float | None = None) -> subprocess.CompletedProcess:
        """Invoke `gh-notification-dismiss [--read] <thread-id>` for positive decimal thread IDs."""
        clean_tid = (thread_id or "").strip()
        if not clean_tid or not clean_tid.isdigit() or _safe_int(clean_tid, 0) <= 0:
            raise ValueError(f"Invalid notification thread_id for dismissal: {thread_id!r}")
        cmd = [self.gh_notification_dismiss_bin, *(["--read"] if read_only else []), clean_tid]
        proc = self.runner(cmd, capture_output=True, text=True, timeout=timeout or self.timeout, check=False)
        if proc.returncode != 0:
            raise RuntimeError(f"gh-notification-dismiss {clean_tid} exited {proc.returncode}: {(proc.stderr or proc.stdout or '').strip()}")
        return proc

    def fetch_json_items(self, endpoint: str, *, paginate: bool = False, timeout: float | None = None) -> list[dict]:
        """Invoke `gh-api-safe <endpoint> [--paginate]` and return parsed dict items."""
        clean_endpoint = (endpoint or "").strip().removeprefix("https://api.github.com/").lstrip("/")
        if not clean_endpoint:
            raise ValueError("GitHub API endpoint must be non-empty")
        proc = self.invoke([clean_endpoint, *(["--paginate"] if paginate else [])], timeout=timeout)
        if proc.returncode != 0:
            raise RuntimeError(f"gh-api-safe {clean_endpoint} exited {proc.returncode}: {(proc.stderr or proc.stdout or '').strip()}")
        return parse_gh_api_paginated_http_output(proc.stdout or "")[2]

    def fetch_json_object(self, endpoint: str, *, paginate: bool = False, timeout: float | None = None) -> dict:
        items = self.fetch_json_items(endpoint, paginate=paginate, timeout=timeout)
        return items[0] if items and isinstance(items[0], dict) else {}

    def poll_notifications(self, last_modified: str | None = None, timeout: float | None = None) -> tuple[int, dict[str, str], list[dict]]:
        cmd_args = ["notifications", "--paginate", "-i", *(["-H", f"If-Modified-Since: {last_modified.strip()}"] if isinstance(last_modified, str) and last_modified.strip() else [])]
        proc = self.invoke(cmd_args, timeout=timeout)
        stdout, stderr = proc.stdout or "", proc.stderr or ""
        if stdout.strip().startswith("HTTP/"):
            status, headers, items = parse_gh_api_paginated_http_output(stdout)
            if status in (304, 403, 429):
                return status, headers, []
            if proc.returncode != 0 and status >= 400:
                raise RuntimeError(f"gh-api-safe notifications failed with HTTP {status}: {stderr.strip() or stdout.strip()}")
            return status, headers, items
        if proc.returncode != 0:
            if "304" in stderr and "Not Modified" in stderr:
                return 304, {}, []
            raise RuntimeError(f"gh-api-safe notifications exited {proc.returncode}: {stderr.strip()}")
        return parse_gh_api_paginated_http_output(stdout)

    def poll_open_pull_requests(self, owners: Iterable[str] = POLL_PR_OWNERS, timeout: float | None = None) -> list[dict]:
        """Query open pull requests across the configured owners via a single GraphQL search query."""
        proc = self.invoke(["graphql", "--paginate", "-f", f"query={build_open_prs_graphql_query(owners)}"], timeout=timeout)
        stdout, stderr = (proc.stdout or "").strip(), (proc.stderr or "").strip()
        if proc.returncode != 0:
            raise RuntimeError(f"gh-api-safe graphql open pull requests exited {proc.returncode}: {stderr or stdout}")
        if not stdout:
            return []
        raw_nodes: list[dict] = []
        last_has_next_page = False
        for item in parse_gh_api_paginated_http_output(stdout)[2]:
            if not isinstance(item, dict):
                continue
            if item.get("errors"):
                raise RuntimeError("Incomplete or failed GraphQL open pull-request pagination")
            search_obj = _as_dict(_as_dict(item.get("data")).get("search") or item.get("search"))
            if search_obj:
                last_has_next_page = bool(_as_dict(search_obj.get("pageInfo")).get("hasNextPage"))
            nodes = next((cand for cand in (search_obj.get("nodes"), item.get("nodes"), item.get("items")) if isinstance(cand, list)), None)
            raw_nodes.extend([n for n in nodes if isinstance(n, dict)] if isinstance(nodes, list) else [item])
        if last_has_next_page:
            raise RuntimeError("Incomplete or failed GraphQL open pull-request pagination")
        return [norm for node in raw_nodes if (norm := normalize_open_pull_request_record(node)) is not None]


class TrustFilterAndSnapshotBuilder:
    """Thin actor-trust and trigger evaluator passing inline trigger metadata to agent turns."""

    def __init__(self, state_store: CompanionStateStore, gh_client: GhApiSafeClient, matrix_client: MatrixClient | None = None, telegram_client: TelegramClient | None = None, agent_name: str | None = None, clock: Callable[[], int] = now_ms):
        self.state_store = state_store
        self.gh_client = gh_client
        self.matrix_client = matrix_client
        self.telegram_client = telegram_client
        self.agent_name = normalize_agent_name(agent_name or state_store.agent_name)
        self.agent_github_login = self.self_github_login = GITHUB_AGENT_LOGINS[self.agent_name]
        self.clock = clock

    def _is_self_actor(self, actor_norm: str) -> bool:
        return bool(actor_norm and (actor_norm == self.self_github_login or LOGIN_TO_AGENT_NAME.get(actor_norm) == self.agent_name))

    @staticmethod
    def _is_peer_agent_actor(actor_norm: str, self_agent: str) -> bool:
        mapped = LOGIN_TO_AGENT_NAME.get(actor_norm)
        return bool(mapped and mapped in AGENT_ORDER and mapped != self_agent)

    @staticmethod
    def _extract_item_actor(item: dict) -> str:
        if not isinstance(item, dict):
            return ""
        for key in ("user", "author", "actor", "sender", "creator"):
            if login := extract_actor_login(item.get(key)):
                return login
        return ""

    def _record_security_event_and_alert(self, *, repo: str, subject_type: str, number: int | None, thread_id: str, item_kind: str, item_id: str | int | None, actor: str, raw_texts: list[str], stamp_ms: int) -> dict:
        combined_raw = "\n".join(t for t in raw_texts if isinstance(t, str) and t)
        coercion_rules = detect_coercion_patterns(combined_raw)
        targeted_agents = sorted(extract_mentioned_github_agents(combined_raw))
        is_coercive_or_injection = bool(coercion_rules or targeted_agents)
        if coercion_rules:
            event_kind, rule_matched, rules_list = "coercion_pattern", coercion_rules[0], coercion_rules
        elif targeted_agents:
            event_kind, rule_matched, rules_list = "command_injection", "sith_mention_injection", ["sith_mention_injection"]
        else:
            event_kind, rule_matched, rules_list = "untrusted_actor", "untrusted_actor", ["untrusted_actor"]

        norm_number = _safe_int(number, 0) or None
        str_item_id = str(item_id) if item_id is not None else None
        for existing in self.state_store.read_security_events():
            if isinstance(existing, dict) and existing.get("repo") == repo and (_safe_int(existing.get("number"), 0) or None) == norm_number and existing.get("item_kind") == item_kind and existing.get("item_id") == str_item_id:
                return {"event": existing, "notice_sent": False, "notice_event_id": None, "notice_body": None, "telegram_sent": False, "deduplicated": True}

        subject_label = f"{repo}#{norm_number}" if isinstance(norm_number, int) and norm_number > 0 else f"{repo}:{subject_type}"
        event_record = self.state_store.append_security_event({"timestamp_ms": stamp_ms, "agent": self.agent_name, "agent_name": self.agent_name, "repo": repo, "subject": subject_label, "subject_type": subject_type, "number": norm_number, "thread_id": thread_id, "item_kind": item_kind, "item_id": str_item_id, "actor": actor or "unknown", "event_kind": event_kind, "rule_matched": rule_matched, "rules_matched": rules_list, "targeted_agents": targeted_agents}, now_override_ms=stamp_ms)
        notice_sent, notice_event_id, notice_body, telegram_sent = False, None, None, False
        if is_coercive_or_injection and self.agent_name == "skrye":
            notice_body = format_security_alert_notice(event_kind=event_kind, repo=repo, subject_type=subject_type, number=norm_number, actor=actor or "unknown", rules_matched=rules_list, targeted_agents=targeted_agents)
            if self.matrix_client is not None:
                notice_event_id = self.matrix_client.send_notice(body_text=notice_body, scope_id=f"sec:{repo}:{norm_number or 0}:{item_kind}:{str_item_id or stamp_ms}:{event_kind}:{rule_matched}", mentions_user_ids=None)
                notice_sent = True
            if self.telegram_client is not None:
                with contextlib.suppress(Exception):
                    self.telegram_client.send_message(notice_body)
                    telegram_sent = True
        return {"event": event_record, "notice_sent": notice_sent, "notice_event_id": notice_event_id, "notice_body": notice_body, "telegram_sent": telegram_sent, "deduplicated": False}

    def inspect_item(self, *, repo: str, subject_type: str, number: int | None, thread_id: str, item_kind: str, item: dict, stamp_ms: int | None = None) -> dict:
        """Inspect one comment, review, issue, or pull request item for actor trust, coercion, and filtering."""
        now_val = _safe_int(stamp_ms, self.clock()) if stamp_ms is not None else self.clock()
        actor = self._extract_item_actor(item)
        actor_norm = normalize_github_actor(actor)
        item_id = item.get("id") or number
        raw_texts = [t for t in (str(item.get("title") or ""), str(item.get("body") or "")) if t]
        security_events: list[dict] = []
        notices: list[dict] = []

        def _out(trusted: bool, inst: bool, bot: bool, trigger: bool, skip: str | None) -> dict:
            return {"trusted": trusted, "instruction_trusted": inst, "bot_trusted": bot, "should_trigger": trigger, "skip_reason": skip, "actor": actor, "item_id": item_id, "security_events": security_events, "notices": notices}

        if not is_trusted_github_actor(actor_norm):
            res = self._record_security_event_and_alert(repo=repo, subject_type=subject_type, number=number, thread_id=thread_id, item_kind=item_kind, item_id=item_id, actor=actor or "unknown", raw_texts=raw_texts, stamp_ms=now_val)
            if not res.get("deduplicated"):
                security_events.append(res["event"])
                if res["notice_body"]:
                    notices.append(res)
            return _out(False, False, False, False, "untrusted_actor")

        is_instruction, is_bot = is_trusted_instruction_actor(actor_norm), is_trusted_bot_actor(actor_norm)
        if not is_instruction and [r for r in detect_coercion_patterns("\n".join(raw_texts)) if r != "html_comment_block"]:
            res = self._record_security_event_and_alert(repo=repo, subject_type=subject_type, number=number, thread_id=thread_id, item_kind=item_kind, item_id=item_id, actor=actor, raw_texts=raw_texts, stamp_ms=now_val)
            if not res.get("deduplicated"):
                security_events.append(res["event"])
                if res["notice_body"]:
                    notices.append(res)
            return _out(True, False, is_bot, False, "coercion_pattern")

        if self._is_self_actor(actor_norm):
            return _out(True, is_instruction, is_bot, False, "self_activity")

        clean_text = strip_html_comments("\n".join(raw_texts)).strip()
        mentioned_agents = sorted(extract_mentioned_github_agents(clean_text))
        if item_kind == "pull_request_review" and str(item.get("state") or "").strip().upper() == "APPROVED" and self._is_peer_agent_actor(actor_norm, self.agent_name) and self.agent_name not in mentioned_agents:
            return _out(True, is_instruction, is_bot, False, "unmentioned_peer_approval")

        is_pr = subject_type.lower() in ("pullrequest", "pull_request", "pr")
        if not ((self.agent_name in mentioned_agents or not mentioned_agents) if is_pr else (is_instruction and self.agent_name in mentioned_agents)):
            return _out(True, is_instruction, is_bot, False, "no_verified_trusted_trigger")
        return {**_out(True, is_instruction, is_bot, True, None), "mentioned_agents": mentioned_agents}

    def evaluate_notification(self, notification: dict, *, latest_item: dict | None = None, subject_item: dict | None = None, now_override_ms: int | None = None) -> dict:
        """Evaluate a notification with at most the latest triggering item and subject metadata."""
        stamp_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        thread_id = str(notification.get("thread_id") or notification.get("id") or "thread").strip()
        repo = str(notification.get("repo") or "").strip()
        subject_type = str(notification.get("subject_type") or "Issue").strip()
        number = _safe_int(notification.get("number"), 0) or None
        reason = str(notification.get("reason") or "notification").strip()
        is_pr = subject_type.lower() in ("pullrequest", "pull_request", "pr")
        kind_label = "PullRequest" if is_pr else "Issue"
        security_events: list[dict] = []
        notices: list[dict] = []
        head_sha = str(notification.get("head_sha") or "").strip() or None

        def _eval_res(dispatch: bool, skip: str | None, trig: str | None = None, cid: object = None, rid: object = None, tid: object = None) -> dict:
            return {"should_dispatch": dispatch, "skip_reason": skip, "repo": repo, "number": number, "kind": kind_label, "head_sha": head_sha, "trigger_reason": trig or reason, "comment_id": cid, "review_id": rid, "trusted_item_id": tid, "security_events": security_events, "notices": notices}

        if isinstance(subject_item, dict) and subject_item and is_pr:
            head_sha = str(subject_item.get("headRefOid") or _as_dict(subject_item.get("head")).get("sha") or head_sha or "").strip() or None
        if _is_archived_record(notification, subject_item, latest_item):
            return _eval_res(False, "archived_repo")
        if isinstance(subject_item, dict) and subject_item and is_pr:
            pr_state = str(subject_item.get("state") or "open").strip().lower()
            pr_draft = bool(subject_item.get("draft") or subject_item.get("isDraft", False))
            pr_merged = bool(subject_item.get("merged", False)) or bool(subject_item.get("merged_at"))
            if pr_state != "open" or pr_draft or pr_merged:
                return _eval_res(False, "closed_or_draft_pr")

        if isinstance(latest_item, dict) and latest_item:
            latest_url = str(notification.get("latest_comment_url") or "")
            item_kind = "pull_request_review" if ("/reviews/" in latest_url or "submitted_at" in latest_item) else ("pull_request_review_comment" if ("/pulls/comments/" in latest_url or "pull_request_review_id" in latest_item) else "issue_comment")
            insp = self.inspect_item(repo=repo, subject_type=kind_label, number=number, thread_id=thread_id, item_kind=item_kind, item=latest_item, stamp_ms=stamp_ms)
            security_events.extend(insp["security_events"])
            notices.extend(insp["notices"])
            if not insp["should_trigger"]:
                return _eval_res(False, insp["skip_reason"])
            item_id, is_rev = insp["item_id"], item_kind == "pull_request_review"
            return _eval_res(True, None, reason or ("trusted_review" if is_rev else "trusted_comment"), None if is_rev else item_id, item_id if is_rev else None, item_id)

        if isinstance(subject_item, dict) and subject_item:
            insp = self.inspect_item(repo=repo, subject_type=kind_label, number=number, thread_id=thread_id, item_kind="pull_request" if is_pr else "issue", item=subject_item, stamp_ms=stamp_ms)
            security_events.extend(insp["security_events"])
            notices.extend(insp["notices"])
            if not insp["should_trigger"]:
                return _eval_res(False, insp["skip_reason"])
            return _eval_res(True, None, reason or ("review_requested" if is_pr else "mention"), None, None, insp["item_id"])

        return _eval_res(False, "no_verified_trusted_trigger")

    def evaluate_thread_bundle(self, notification: dict, bundle: dict, now_override_ms: int | None = None, **_ignored: object) -> dict:
        """Evaluate a pre-fetched thread bundle without writing snapshots/ files."""
        subject_item = _as_dict(bundle.get("pull") or bundle.get("issue"))
        latest_item = None
        for seq_key in ("review_comments", "reviews", "issue_comments"):
            seq = bundle.get(seq_key)
            if isinstance(seq, list) and seq and isinstance(seq[-1], dict):
                latest_item = seq[-1]
        return self.evaluate_notification(notification, latest_item=latest_item, subject_item=subject_item, now_override_ms=now_override_ms)

    def fetch_and_prepare_notification(self, notification: dict, now_override_ms: int | None = None, **_ignored: object) -> dict:
        """Fetch only the triggering item / subject metadata needed to evaluate trust and trigger reason."""
        repo, subject_type = str(notification.get("repo") or "").strip(), str(notification.get("subject_type") or "Issue").strip()
        subject_url, latest_comment_url = notification.get("subject_url"), notification.get("latest_comment_url")
        number = _safe_int(notification.get("number"), 0)
        if not repo or number <= 0:
            return {"should_dispatch": False, "skip_reason": "invalid_target", "repo": repo, "number": number or None, "kind": subject_type, "head_sha": None, "trigger_reason": None, "comment_id": None, "review_id": None, "trusted_item_id": None, "security_events": [], "notices": []}
        is_pr = subject_type.lower() in ("pullrequest", "pull_request", "pr")
        subject_item: dict = {}
        latest_item: dict | None = None
        subj_endpoint = subject_url if isinstance(subject_url, str) and subject_url.strip() else f"repos/{repo}/{'pulls' if is_pr else 'issues'}/{number}"
        with contextlib.suppress(Exception):
            subject_item = self.gh_client.fetch_json_object(subj_endpoint, paginate=False)
        cached = self.state_store.get_thread_state(make_pr_key(repo, number))
        if _is_archived_record(notification, cached, subject_item):
            subject_item = {**subject_item, "archived": True}
        if not subject_item:
            return {"should_dispatch": False, "skip_reason": "subject_fetch_failed", "repo": repo, "number": number, "kind": "PullRequest" if is_pr else "Issue", "head_sha": str(notification.get("head_sha") or "").strip() or None, "trigger_reason": str(notification.get("reason") or "notification").strip(), "comment_id": None, "review_id": None, "trusted_item_id": None, "security_events": [], "notices": []}
        if isinstance(latest_comment_url, str) and latest_comment_url.strip() and latest_comment_url.strip() != (subject_url or "").strip():
            with contextlib.suppress(Exception):
                fetched = self.gh_client.fetch_json_object(latest_comment_url, paginate=False)
                if fetched:
                    latest_item = fetched
        res = self.evaluate_notification(notification, latest_item=latest_item, subject_item=subject_item, now_override_ms=now_override_ms)
        if res.get("skip_reason") == "archived_repo" and not (isinstance(cached, dict) and cached.get("archived") is True):
            self.state_store.update_thread_state(make_pr_key(repo, number), {"repo": repo, "number": number, "archived": True, **({"head_sha": res["head_sha"]} if res.get("head_sha") else {})}, now_override_ms=now_override_ms)
        return res


class NotificationPoller:
    """Manage provisional next_poll_at_ms crash recovery, /notifications, and 6-owner open PR polling."""

    def __init__(self, state_store: CompanionStateStore, gh_client: GhApiSafeClient, read_only_trial: bool = False, clock: Callable[[], int] = now_ms, sleeper: Callable[[float], None] = time.sleep, jitter_rng: Callable[[int, int], int] | None = None, on_actionable_threads: Callable[[list[str]], None] | None = None):
        self.state_store = state_store
        self.gh_client = gh_client
        self.read_only_trial = bool(read_only_trial)
        self.clock = clock
        self.sleeper = sleeper
        self.jitter_rng = jitter_rng
        self.on_actionable_threads = on_actionable_threads

    @staticmethod
    def _effective_next_poll_at_ms(poll_state: dict) -> int | None:
        next_poll_at_ms = poll_state.get("next_poll_at_ms")
        if not isinstance(next_poll_at_ms, int):
            return None
        last_status, last_completed_ms = poll_state.get("last_status"), poll_state.get("last_poll_completed_at_ms")
        if last_status in (200, 304) and not bool(poll_state.get("last_poll_rate_limited", False)) and _safe_int(poll_state.get("retry_after_secs"), 0) <= 0 and isinstance(last_completed_ms, int):
            poll_interval_secs = max(BASE_POLL_INTERVAL_SECS, _safe_int(poll_state.get("poll_interval_secs"), BASE_POLL_INTERVAL_SECS))
            jitter_ms = max(JITTER_MIN_MS, min(JITTER_MAX_MS, _safe_int(poll_state.get("last_jitter_ms"), JITTER_MAX_MS)))
            return min(next_poll_at_ms, last_completed_ms + (poll_interval_secs * 1000) + jitter_ms)
        return next_poll_at_ms

    def wait_until_due(self, now_override_ms: int | None = None) -> int:
        """Sleep until persisted next_poll_at_ms when in the future, or return 0 immediately on first boot."""
        current_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        next_poll_at_ms = self._effective_next_poll_at_ms(self.state_store.read_state())
        if isinstance(next_poll_at_ms, int) and next_poll_at_ms > current_ms:
            sleep_ms = next_poll_at_ms - current_ms
            self.sleeper(sleep_ms / 1000.0)
            return sleep_ms
        return 0

    wait_for_startup_slot = wait_until_next_poll = wait_until_due

    def _persist_provisional_next_poll(self, current_ms: int) -> tuple[int, int]:
        jitter_ms = compute_jitter_ms(self.jitter_rng)
        provisional_next_ms = current_ms + BASE_POLL_INTERVAL_MS + jitter_ms
        self.state_store.write_state({"last_poll_started_at_ms": current_ms, "next_poll_at_ms": provisional_next_ms, "last_jitter_ms": jitter_ms}, now_override_ms=current_ms)
        return provisional_next_ms, jitter_ms

    def poll_once(self, now_override_ms: int | None = None, poll_open_prs: bool = True) -> dict:
        """Execute one conditional /notifications poll plus the 6-owner open PR poll."""
        start_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        prior_last_modified = self.state_store.read_state().get("last_modified")
        provisional_next_ms, provisional_jitter_ms = self._persist_provisional_next_poll(start_ms)
        status, headers, raw_items = self.gh_client.poll_notifications(last_modified=prior_last_modified if isinstance(prior_last_modified, str) else None)
        finish_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        wait_ms, base_wait_sec, post_jitter_ms = compute_backoff_wait_ms(headers=headers, now_ms_val=finish_ms, rng=self.jitter_rng, status=status)
        computed_next_poll_ms = finish_ms + wait_ms

        filtered_records, actionable_threads, queued_followups, dismissed_threads, actionable_prs, open_pull_requests = [], [], [], [], [], []
        if 200 <= status < 300:
            filtered_records = [norm for item in raw_items if (norm := normalize_notification_record(item)) is not None]
            ingest_result = self.state_store.record_polled_notifications(filtered_records, now_override_ms=finish_ms)
            actionable_threads, queued_followups = list(ingest_result["actionable_threads"]), list(ingest_result["queued_followups"])
            if not self.read_only_trial:
                for tid in ingest_result.get("auto_dismiss_threads") or []:
                    with contextlib.suppress(Exception):
                        self.gh_client.dismiss_notification(tid)
                        dismissed_threads.append(tid)

        poll_interval_hdr = _safe_int(headers.get("x-poll-interval"), BASE_POLL_INTERVAL_SECS)
        retry_after_hdr = parse_retry_after_seconds(headers.get("retry-after"), finish_ms // 1000)
        remaining_hdr = headers.get("x-ratelimit-remaining")
        remaining_exhausted = remaining_hdr is not None and str(remaining_hdr).strip() != "" and _safe_int(remaining_hdr, 1) <= 0
        is_rate_limited = bool(status in (403, 429) or remaining_exhausted or retry_after_hdr > 0)

        open_prs_poll_error: str | None = None
        if poll_open_prs and not is_rate_limited:
            try:
                open_pull_requests = self.gh_client.poll_open_pull_requests()
            except Exception as exc:
                open_prs_poll_error = str(exc) or exc.__class__.__name__
            if open_pull_requests:
                pr_ingest = self.state_store.record_polled_pull_requests(open_pull_requests, self_github_login=GITHUB_AGENT_LOGINS[self.state_store.agent_name], now_override_ms=finish_ms)
                actionable_prs = list(pr_ingest["actionable_prs"])
                for qf in pr_ingest["queued_followups"]:
                    if qf not in queued_followups:
                        queued_followups.append(qf)

        new_last_modified = headers["last-modified"].strip() if (200 <= status < 300 and isinstance(headers.get("last-modified"), str) and headers["last-modified"].strip()) else prior_last_modified
        ratelimit_reset_hdr = (_safe_int(headers.get("x-ratelimit-reset"), 0) or None) if is_rate_limited else None
        self.state_store.write_state({"last_poll_completed_at_ms": finish_ms, "last_status": status, "last_modified": new_last_modified, "next_poll_at_ms": computed_next_poll_ms, "poll_interval_secs": max(BASE_POLL_INTERVAL_SECS, poll_interval_hdr), "retry_after_secs": retry_after_hdr, "last_poll_rate_limited": is_rate_limited, "ratelimit_reset_epoch": ratelimit_reset_hdr, "last_jitter_ms": post_jitter_ms, "last_open_prs_poll_error": open_prs_poll_error}, now_override_ms=finish_ms)

        dispatched_threads: list[str] = []
        if not self.read_only_trial and actionable_threads and self.on_actionable_threads is not None:
            self.on_actionable_threads(actionable_threads)
            dispatched_threads = list(actionable_threads)

        return {"status": status, "provisional_next_poll_at_ms": provisional_next_ms, "provisional_jitter_ms": provisional_jitter_ms, "next_poll_at_ms": computed_next_poll_ms, "base_wait_secs": base_wait_sec, "jitter_ms": post_jitter_ms, "last_modified": new_last_modified, "filtered_notifications": filtered_records, "open_pull_requests": open_pull_requests, "open_prs_poll_error": open_prs_poll_error, "actionable_threads": actionable_threads, "actionable_prs": actionable_prs, "dismissed_threads": dismissed_threads, "queued_followups": queued_followups, "dispatched_threads": dispatched_threads, "read_only_trial": self.read_only_trial}


class LocalExecutionCoordinator:
    """Serialise all targeted turns, 6-hour reconciliation sweeps, and weekly sweeps under coordinator.lock and active-dispatch.json."""

    def __init__(self, state_store: CompanionStateStore, rpc_client: MoltisRpcClient, data_dir: Path | str, agent_name: str, agent_display_name: str = "", main_model: str = "", matrix_client: MatrixClient | None = None, telegram_client: TelegramClient | None = None, telegram_bot_token_path: Path | str | None = None, telegram_allowed_users_path: Path | str | None = None, telegram_api_url: str = DEFAULT_TELEGRAM_API_URL, session_key: str = DEFAULT_GH_SESSION_KEY, room_id: str = DEFAULT_ROOM_ID, schedule_dow: int | None = None, schedule_day_name: str = "", completion_timeout_ms: int | None = None, recovery_deadline_ms: int | None = None, completion_wait_timeout_secs: float | None = None, recovery_wait_timeout_secs: float | None = None, rpc_timeout_secs: float = DEFAULT_RPC_TIMEOUT_SECS, poll_interval_ms: int = DEFAULT_COMPLETION_POLL_INTERVAL_MS, clock: Callable[[], int] = now_ms, sleeper: Callable[[float], None] = time.sleep):
        self.state_store = state_store
        self.rpc_client = rpc_client
        self.data_dir = Path(data_dir)
        self.agent_name = normalize_agent_name(agent_name)
        self.agent_display_name = derive_display_name(self.agent_name, agent_display_name)
        self.main_model = (main_model or "").strip()
        self.matrix_client = matrix_client
        self.telegram_client = telegram_client or (TelegramClient(bot_token_path=telegram_bot_token_path, allowed_users_path=telegram_allowed_users_path, api_url=telegram_api_url) if (telegram_bot_token_path or telegram_allowed_users_path) else None)
        self.session_key = (session_key or DEFAULT_GH_SESSION_KEY).strip()
        self.room_id = room_id
        default_dow, default_day_name = AGENT_DEFAULT_SCHEDULES[self.agent_name]
        self.schedule_dow = _safe_int(schedule_dow, default_dow) if schedule_dow is not None else default_dow
        self.schedule_day_name = (schedule_day_name or default_day_name).strip()
        resolved_completion_ms = _safe_int(completion_timeout_ms, DEFAULT_COMPLETION_TIMEOUT_MS) if completion_timeout_ms is not None else (_safe_int(completion_wait_timeout_secs * 1000, DEFAULT_COMPLETION_TIMEOUT_MS) if isinstance(completion_wait_timeout_secs, (int, float)) else DEFAULT_COMPLETION_TIMEOUT_MS)
        resolved_recovery_ms = _safe_int(recovery_deadline_ms, DEFAULT_RECOVERY_DEADLINE_MS) if recovery_deadline_ms is not None else (_safe_int(recovery_wait_timeout_secs * 1000, DEFAULT_RECOVERY_DEADLINE_MS) if isinstance(recovery_wait_timeout_secs, (int, float)) else DEFAULT_RECOVERY_DEADLINE_MS)
        self.completion_timeout_ms = max(0, resolved_completion_ms)
        self.recovery_deadline_ms = max(0, resolved_recovery_ms)
        self.rpc_timeout_secs = max(0.1, rpc_timeout_secs * 1.0) if isinstance(rpc_timeout_secs, (int, float)) else DEFAULT_RPC_TIMEOUT_SECS
        self.poll_interval_ms = max(10, _safe_int(poll_interval_ms, DEFAULT_COMPLETION_POLL_INTERVAL_MS))
        self.clock = clock
        self.sleeper = sleeper

    def build_dispatch_prompt(self, *, dispatch_id: str, kind: str, thread_id: str | None = None, repo: str | None = None, number: int | None = None, subject_kind: str | None = None, head_sha: str | None = None, trigger_reason: str | None = None, comment_id: int | str | None = None, review_id: int | str | None = None, trusted_item_id: int | str | None = None, extra_instructions: str = "") -> str:
        header = f"# {self.agent_display_name} Scheduled Maintenance Heartbeat"
        meta_lines = [f"dispatch_id: {dispatch_id}", f"dispatch_kind: {kind}", f"agent_name: {self.agent_name}", f"schedule_day_name: {self.schedule_day_name}", f"schedule_dow: {self.schedule_dow}"]
        if thread_id:
            meta_lines.append(f"thread_id: {thread_id}")
        if kind == "targeted" or repo or number:
            eff_item_id = trusted_item_id if trusted_item_id is not None else (comment_id or review_id)
            meta_lines.extend([f"repo: {repo or ''}", f"number: {number if number is not None else ''}", f"kind: {subject_kind or 'PullRequest'}", f"head_sha: {head_sha or ''}", f"trigger_reason: {trigger_reason or 'notification'}"])
            if comment_id is not None and str(comment_id).strip():
                meta_lines.append(f"comment_id: {comment_id}")
            if review_id is not None and str(review_id).strip():
                meta_lines.append(f"review_id: {review_id}")
            if eff_item_id is not None and str(eff_item_id).strip():
                meta_lines.append(f"trusted_item_id: {eff_item_id}")

        if kind == "targeted":
            mode_line = f"Mode 1 - Targeted Notification or Mention Turn (repo={repo or ''}, number={number if number is not None else ''}, kind={subject_kind or 'PullRequest'}, head_sha={head_sha or 'none'}, trigger_reason={trigger_reason or 'notification'})."
        elif kind == "weekly_sweep":
            mode_line = f"Mode 3 - Weekly Organisation Sweep ({self.schedule_day_name} Only, dow == {self.schedule_dow})."
        else:
            mode_line = "Mode 2 - 6-Hour Reconciliation Sweep."

        blocks = [header, "\n".join(meta_lines), mode_line, *([extra_instructions.strip()] if extra_instructions.strip() else [])]
        heartbeat_md = ""
        heartbeat_path = self.data_dir / "HEARTBEAT.md"
        if heartbeat_path.is_file():
            with contextlib.suppress(OSError):
                heartbeat_md = heartbeat_path.read_text(encoding="utf-8", errors="replace").strip()
        blocks.append(f"Follow the `HEARTBEAT.md` procedure appended below for the active mode.\n\n{heartbeat_md}" if heartbeat_md else "Read and follow `~/.moltis/HEARTBEAT.md` for the active mode procedure.")
        return "\n\n".join(blocks) + "\n"

    def _check_completion_once(self, session_key: str, dispatch_id: str) -> dict:
        peek_active, peek_error = None, None
        try:
            peek_active = parse_chat_peek_active(self.rpc_client.chat_peek(session_key))
        except Exception as exc:
            peek_error = str(exc)
        records = load_session_history_records(self.data_dir, session_key, agent_name=self.agent_name, room_id=self.room_id)
        has_user, has_terminal_assistant, assistant_rec = verify_history_dispatch_completion(records, dispatch_id)
        completed = (peek_active is False) and has_user and has_terminal_assistant
        task_succeeded, failure_reason = classify_terminal_turn_outcome(extract_terminal_reply_text(assistant_record=assistant_rec), assistant_record=assistant_rec) if completed else (False, None)
        return {"completed": completed, "execution_terminated": completed, "task_succeeded": task_succeeded, "failure_reason": failure_reason, "peek_active": peek_active, "peek_error": peek_error, "has_user_record": has_user, "has_terminal_assistant_record": has_terminal_assistant, "assistant_record": assistant_rec}

    def _poll_until_completed(self, session_key: str, dispatch_id: str, deadline_ms: int) -> dict:
        inactive_checks = 0
        while True:
            check = self._check_completion_once(session_key, dispatch_id)
            if check["completed"]:
                return check
            inactive_checks = (inactive_checks + 1) if check.get("peek_active") is False else 0
            if inactive_checks >= 2:
                return check
            current_ms = self.clock()
            if current_ms >= deadline_ms:
                return check
            self.sleeper(min(self.poll_interval_ms, max(1, deadline_ms - current_ms)) / 1000.0)

    _wait_for_turn_completion = _poll_until_completed

    def _send_telegram_safe(self, text: str) -> tuple[bool, str | None]:
        clean_text = (text or "").strip()
        if not clean_text or is_heartbeat_ok_reply(clean_text) or self.telegram_client is None:
            return False, None
        try:
            self.telegram_client.send_message(clean_text)
            return True, None
        except Exception as exc:
            err_msg = str(exc)
            sys.stderr.write(f"moltis-github-companion telegram delivery warning ({self.agent_name}): {err_msg}\n")
            return False, err_msg

    _forward_terminal_reply_to_telegram = _send_telegram_safe

    def _finalize_completed_dispatch(self, active_record: dict, now_override_ms: int | None = None) -> dict:
        stamp_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        kind = str(active_record.get("kind") or "")
        state_key = str(active_record.get("state_key") or active_record.get("thread_id") or "").strip()
        watermark_result = self.state_store.complete_thread_review(state_key, handled_updated_at=active_record.get("updated_at"), handled_head_sha=active_record.get("head_sha"), handled_ci_state=active_record.get("ci_state"), completed_revision=active_record.get("revision"), now_override_ms=stamp_ms) if state_key else None
        if kind in ("reconcile_sweep", "weekly_sweep"):
            self.state_store.complete_sweep(kind, sweep_date=str(active_record["sweep_date"]).strip() if active_record.get("sweep_date") else None, now_override_ms=stamp_ms)
        self.state_store.write_active_dispatch(None, now_override_ms=stamp_ms)
        return {"watermark": watermark_result, "queued_followup": bool(_as_dict(watermark_result).get("pending_followup"))}

    def _finalize_failed_dispatch(self, active_record: dict, failure_reason: str | None = None, now_override_ms: int | None = None) -> dict:
        """Clear active-dispatch.json after a failed or interrupted turn and increment retry_count up to 3."""
        stamp_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        kind = str(active_record.get("kind") or "")
        state_key = str(active_record.get("state_key") or active_record.get("thread_id") or "").strip()
        watermark_result = self.state_store.fail_thread_review(state_key, failure_reason=failure_reason, now_override_ms=stamp_ms) if state_key else None
        if kind in ("reconcile_sweep", "weekly_sweep"):
            self.state_store.fail_sweep(kind, failure_reason=failure_reason, attempt_at_ms=_safe_int(active_record.get("started_at_ms"), 0) or None, now_override_ms=stamp_ms)
        self.state_store.write_active_dispatch(None, now_override_ms=stamp_ms)
        return {"watermark": watermark_result, "queued_followup": bool(_as_dict(watermark_result).get("pending_followup"))}

    def _resolve_turn_outcome(self, active_record: dict, check: dict, *, rpc_response: dict | None = None, rpc_error: Exception | None = None, recovery: dict | None = None, start_notice: tuple[bool, str, str | None] | None = None, is_recovery: bool = False, now_override_ms: int | None = None) -> dict:
        stamp_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        dispatch_id = str(active_record.get("dispatch_id") or "")
        session_key = str(active_record.get("session_key") or self.session_key)
        reply_text = ""
        task_succeeded, failure_reason, tg_ok, tg_err = False, None, False, None
        if check["completed"]:
            reply_text = extract_terminal_reply_text(rpc_response=rpc_response, assistant_record=check.get("assistant_record"))
            task_succeeded, failure_reason = classify_terminal_turn_outcome(reply_text, assistant_record=check.get("assistant_record"), rpc_response=rpc_response)
            if task_succeeded:
                tg_ok, tg_err = self._send_telegram_safe(reply_text)
                fin = self._finalize_completed_dispatch(active_record, now_override_ms=stamp_ms)
            else:
                fin = self._finalize_failed_dispatch(active_record, failure_reason=failure_reason, now_override_ms=stamp_ms)
        else:
            default_timeout = "turn_recovery_timeout" if is_recovery else (f"rpc_error: {rpc_error}" if rpc_error is not None else "turn_completion_timeout")
            failure_reason = "interrupted_turn_without_terminal_reply" if check.get("peek_active") is False else default_timeout
            fin = self._finalize_failed_dispatch(active_record, failure_reason=failure_reason, now_override_ms=stamp_ms)

        status = ("recovered_completed" if task_succeeded else "recovered_failed") if is_recovery else ("completed" if task_succeeded else "failed")
        res: dict[str, object] = {"status": status, "execution_terminated": bool(check.get("completed") or check.get("peek_active") is False), "task_succeeded": task_succeeded, "failure_reason": failure_reason, "dispatch_id": dispatch_id, "session_key": session_key, "kind": active_record.get("kind"), "thread_id": active_record.get("thread_id"), "state_key": active_record.get("state_key"), "reply_text": reply_text, "telegram_forwarded": tg_ok, "telegram_error": tg_err, "queued_followup": fin["queued_followup"], "watermark": fin["watermark"]}
        if is_recovery:
            res["can_dispatch"] = True
        else:
            sn_sent, sn_text, sn_err = start_notice or (False, "", None)
            res.update({"dispatched": True, "start_notice_sent": sn_sent, "start_notice_text": sn_text, "start_notice_error": sn_err, "rpc_response": rpc_response, "rpc_error": str(rpc_error) if rpc_error is not None else None, "recovery": recovery})
        return res

    def _recover_unlocked(self, now_override_ms: int | None = None) -> dict:
        stamp_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        active = self.state_store.read_active_dispatch().get("active")
        if not isinstance(active, dict) or not active.get("dispatch_id"):
            return {"status": "idle", "can_dispatch": True}
        check = self._poll_until_completed(str(active.get("session_key") or self.session_key), str(active.get("dispatch_id") or ""), deadline_ms=stamp_ms + self.recovery_deadline_ms)
        finish_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        return self._resolve_turn_outcome(active, check, is_recovery=True, now_override_ms=finish_ms)

    def recover_active_dispatch(self, now_override_ms: int | None = None) -> dict:
        """Acquire coordinator.lock and recover any in-flight or interrupted active-dispatch.json."""
        with self.state_store.coordinator_lock():
            return self._recover_unlocked(now_override_ms=now_override_ms)

    def execute_dispatch(self, *, kind: str, model: str | None = None, session_key: str | None = None, thread_id: str | None = None, state_key: str | None = None, repo: str | None = None, number: int | None = None, subject_kind: str | None = None, head_sha: str | None = None, ci_state: str | None = None, updated_at: str | None = None, trigger_reason: str | None = None, comment_id: int | str | None = None, review_id: int | str | None = None, trusted_item_id: int | str | None = None, revision: str | None = None, sweep_date: str | None = None, extra_instructions: str = "", dispatch_id: str | None = None, now_override_ms: int | None = None, **_ignored: object) -> dict:
        """Serialise a model turn under coordinator.lock while allowing state.json updates under companion.lock."""
        with self.state_store.coordinator_lock():
            recovery = self._recover_unlocked(now_override_ms=now_override_ms)
            start_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
            resolved_session_key = (session_key or self.session_key or DEFAULT_GH_SESSION_KEY).strip()
            resolved_model = (model or self.main_model).strip()
            resolved_dispatch_id = (dispatch_id or f"ghd-{self.agent_name}-{uuid.uuid4().hex}").strip()
            eff_state_key = (state_key or thread_id or (make_pr_key(repo, number) if repo and number else "")).strip()

            if eff_state_key:
                wm_entry = self.state_store.mark_thread_in_flight(eff_state_key, updated_at=updated_at, head_sha=head_sha, ci_state=ci_state, now_override_ms=start_ms)
                updated_at, head_sha, ci_state = updated_at or wm_entry.get("in_flight_updated_at"), head_sha or wm_entry.get("in_flight_head_sha"), ci_state or wm_entry.get("in_flight_ci_state")
            if kind in ("reconcile_sweep", "weekly_sweep"):
                self.state_store.record_sweep_attempt(kind, now_override_ms=start_ms)

            active_record: dict[str, object] = {"dispatch_id": resolved_dispatch_id, "session_key": resolved_session_key, "kind": kind, "started_at_ms": start_ms, "status": "in_flight"}
            for k, v in (("thread_id", thread_id), ("state_key", eff_state_key), ("repo", repo), ("number", number), ("subject_kind", subject_kind), ("head_sha", head_sha), ("ci_state", ci_state), ("updated_at", updated_at), ("trigger_reason", trigger_reason), ("revision", revision), ("sweep_date", sweep_date)):
                if v is not None and v != "":
                    active_record[k] = v
            self.state_store.write_active_dispatch(active_record, now_override_ms=start_ms)

            start_notice_text = format_start_of_work_notice(agent_display_name=self.agent_display_name, kind=kind, repo=repo, number=number, subject_kind=subject_kind, trigger_reason=trigger_reason, sweep_date=sweep_date, schedule_day_name=self.schedule_day_name)
            start_notice_sent, start_notice_error = self._send_telegram_safe(start_notice_text)
            prompt_message = self.build_dispatch_prompt(dispatch_id=resolved_dispatch_id, kind=kind, thread_id=thread_id, repo=repo, number=number, subject_kind=subject_kind, head_sha=head_sha, trigger_reason=trigger_reason, comment_id=comment_id, review_id=review_id, trusted_item_id=trusted_item_id, extra_instructions=extra_instructions)

            rpc_error: Exception | None = None
            rpc_response: dict | None = None
            try:
                rpc_response = self.rpc_client.chat_send_sync(model=resolved_model, message=prompt_message, session_key=resolved_session_key, ephemeral=False, timeout=self.rpc_timeout_secs)
            except Exception as exc:
                rpc_error = exc

            poll_base_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
            deadline_ms = poll_base_ms + (self.recovery_deadline_ms if rpc_error is not None else self.completion_timeout_ms)
            check = self._poll_until_completed(resolved_session_key, resolved_dispatch_id, deadline_ms=deadline_ms)
            finish_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
            return self._resolve_turn_outcome(active_record, check, rpc_response=rpc_response, rpc_error=rpc_error, recovery=recovery, start_notice=(start_notice_sent, start_notice_text, start_notice_error), is_recovery=False, now_override_ms=finish_ms)


class GithubCompanionRunner:
    """Orchestrate 300s notification and open-PR polling, inline trigger evaluation, and serialised turns."""

    def __init__(self, state_store: CompanionStateStore, gh_client: GhApiSafeClient, poller: NotificationPoller, trust_filter: TrustFilterAndSnapshotBuilder, execution_coordinator: LocalExecutionCoordinator, matrix_client: MatrixClient | None = None, read_only_trial: bool = False, reconcile_interval_ms: int = RECONCILE_SWEEP_INTERVAL_MS, clock: Callable[[], int] = now_ms):
        self.state_store = state_store
        self.gh_client = gh_client
        self.poller = poller
        self.trust_filter = trust_filter
        self.execution_coordinator = execution_coordinator
        if self.trust_filter.telegram_client is None and self.execution_coordinator.telegram_client is not None:
            self.trust_filter.telegram_client = self.execution_coordinator.telegram_client
        self.matrix_client = matrix_client
        self.read_only_trial = bool(read_only_trial)
        self.reconcile_interval_ms = max(60_000, _safe_int(reconcile_interval_ms, RECONCILE_SWEEP_INTERVAL_MS))
        self.clock = clock

    def is_reconcile_sweep_due(self, now_override_ms: int | None = None) -> bool:
        current_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        state = self.state_store.read_state()
        reconcile_retry_ms = _safe_int(state.get("reconcile_sweep_retry_after_ms"), 0)
        weekly_retry_ms = _safe_int(state.get("weekly_sweep_retry_after_ms"), 0)
        if (reconcile_retry_ms > 0 and current_ms < reconcile_retry_ms) or (weekly_retry_ms > 0 and current_ms < weekly_retry_ms):
            return False
        last_sweep = state.get("last_reconcile_sweep_at_ms")
        return not isinstance(last_sweep, int) or last_sweep <= 0 or (current_ms - last_sweep) >= self.reconcile_interval_ms

    def is_weekly_sweep_due(self, now_override_ms: int | None = None) -> tuple[bool, str]:
        current_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        try:
            import zoneinfo

            tz = zoneinfo.ZoneInfo("Europe/London")
        except Exception:
            tz = datetime.timezone.utc
        dt = datetime.datetime.fromtimestamp(current_ms / 1000.0, tz=tz)
        today_str = dt.strftime("%Y-%m-%d")
        state = self.state_store.read_state()
        weekly_retry_ms = _safe_int(state.get("weekly_sweep_retry_after_ms"), 0)
        if weekly_retry_ms > 0 and current_ms < weekly_retry_ms:
            return False, today_str
        if dt.isoweekday() != self.execution_coordinator.schedule_dow or dt.hour < 9 or state.get("last_weekly_sweep_date") == today_str:
            return False, today_str
        last_maint_file = self.execution_coordinator.data_dir / "state" / "last-maintenance-date"
        if last_maint_file.is_file():
            with contextlib.suppress(OSError):
                if last_maint_file.read_text(encoding="utf-8", errors="replace").strip() == today_str:
                    return False, today_str
        return True, today_str

    def _is_coordinator_busy(self) -> bool:
        try:
            with self.state_store.coordinator_lock(blocking=False):
                return False
        except BlockingIOError:
            return True

    def run_cycle(self, *, run_sweeps_if_due: bool = True, now_override_ms: int | None = None) -> dict:
        if self.matrix_client is not None:
            with contextlib.suppress(Exception):
                self.matrix_client.flush_outbox()

        poll_result = self.poller.poll_once(now_override_ms=now_override_ms)
        dismissed_threads: list[str] = list(poll_result.get("dismissed_threads") or [])
        if self.read_only_trial:
            return {"status": "ok", "recovery": {"status": "read_only_trial", "can_dispatch": False}, "poll_result": poll_result, "targeted_dispatches": [], "dismissed_threads": dismissed_threads, "sweep_dispatch": None}
        if self._is_coordinator_busy():
            return {"status": "turn_in_progress", "recovery": {"status": "busy", "can_dispatch": False}, "poll_result": poll_result, "targeted_dispatches": [], "dismissed_threads": dismissed_threads, "sweep_dispatch": None}

        recovery = self.execution_coordinator.recover_active_dispatch(now_override_ms=now_override_ms)
        targeted_dispatches: list[dict] = []
        dispatched_targets: set[str] = set()
        threads = _as_dict(self.state_store.read_state().get("threads"))

        def _complete_skipped(key_val: str, tid_val: str | None, prep_res: dict, entry_val: dict) -> None:
            if prep_res.get("skip_reason") == "subject_fetch_failed":
                self.state_store.update_thread_state(key_val, {"pending_followup": True}, now_override_ms=now_override_ms)
                return
            if prep_res.get("skip_reason") in ("closed_or_draft_pr", "archived_repo") and tid_val and tid_val.isdigit():
                try:
                    self.gh_client.dismiss_notification(tid_val)
                    if tid_val not in dismissed_threads:
                        dismissed_threads.append(tid_val)
                except Exception as exc:
                    sys.stderr.write(f"moltis-github-companion dismiss warning ({self.execution_coordinator.agent_name} thread {tid_val}): {exc}\n")
                    return
            self.state_store.complete_thread_review(key_val, handled_updated_at=entry_val.get("updated_at"), handled_head_sha=prep_res.get("head_sha") or entry_val.get("head_sha"), handled_ci_state=entry_val.get("ci_state"), now_override_ms=now_override_ms)

        candidate_thread_ids: list[str] = list(poll_result.get("actionable_threads") or [])
        for tid, entry in threads.items():
            if isinstance(entry, dict) and "#" not in tid and tid not in candidate_thread_ids and _safe_int(entry.get("retry_count"), 0) < MAX_THREAD_FAILURE_RETRIES and (entry.get("pending_followup") or is_timestamp_newer(entry.get("updated_at"), entry.get("handled_updated_at"))):
                candidate_thread_ids.append(tid)

        for tid in candidate_thread_ids:
            entry = _as_dict(threads.get(tid))
            if not entry or _safe_int(entry.get("retry_count"), 0) >= MAX_THREAD_FAILURE_RETRIES:
                continue
            repo, number = str(entry.get("repo") or "").strip(), _safe_int(entry.get("number"), 0) or None
            dedup_key = make_pr_key(repo, number) if (repo and number) else tid
            if dedup_key in dispatched_targets:
                continue
            prep = self.trust_filter.fetch_and_prepare_notification(entry, now_override_ms=now_override_ms)
            if not prep.get("should_dispatch"):
                _complete_skipped(tid, tid, prep, entry)
                continue
            dispatched_targets.add(dedup_key)
            targeted_dispatches.append(self.execution_coordinator.execute_dispatch(kind="targeted", thread_id=tid, state_key=tid, repo=prep.get("repo") or repo, number=prep.get("number") or number, subject_kind=prep.get("kind") or entry.get("subject_type"), head_sha=prep.get("head_sha") or entry.get("head_sha"), ci_state=entry.get("ci_state"), updated_at=entry.get("updated_at"), trigger_reason=prep.get("trigger_reason") or entry.get("reason"), comment_id=prep.get("comment_id"), review_id=prep.get("review_id"), trusted_item_id=prep.get("trusted_item_id"), now_override_ms=now_override_ms))

        for pr_item in poll_result.get("actionable_prs") or []:
            if not isinstance(pr_item, dict):
                continue
            pr_key = str(pr_item.get("key") or "").strip()
            if not pr_key or pr_key in dispatched_targets or _safe_int(_as_dict(self.state_store.get_thread_state(pr_key)).get("retry_count"), 0) >= MAX_THREAD_FAILURE_RETRIES:
                continue
            dispatched_targets.add(pr_key)
            targeted_dispatches.append(self.execution_coordinator.execute_dispatch(kind="targeted", thread_id=str(pr_item.get("thread_id") or "").strip() or None, state_key=pr_key, repo=str(pr_item.get("repo") or ""), number=_safe_int(pr_item.get("number"), 0) or None, subject_kind="PullRequest", head_sha=str(pr_item.get("head_sha") or "") or None, ci_state=str(pr_item.get("ci_state") or "") or None, updated_at=str(pr_item.get("updated_at") or "") or None, trigger_reason=str(pr_item.get("trigger_reason") or "open_pr_poll"), now_override_ms=now_override_ms))

        sweep_dispatch: dict | None = None
        if run_sweeps_if_due:
            weekly_due, today_str = self.is_weekly_sweep_due(now_override_ms=now_override_ms)
            if weekly_due or self.is_reconcile_sweep_due(now_override_ms=now_override_ms):
                sweep_dispatch = self.execution_coordinator.execute_dispatch(kind="weekly_sweep" if weekly_due else "reconcile_sweep", sweep_date=today_str if weekly_due else None, now_override_ms=now_override_ms)

        return {"status": "ok", "recovery": recovery, "poll_result": poll_result, "targeted_dispatches": targeted_dispatches, "dismissed_threads": dismissed_threads, "sweep_dispatch": sweep_dispatch}


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Moltis GitHub notification and pull-request companion")
    parser.add_argument("--agent-name", default=os.environ.get("MOLTIS_GITHUB_COMPANION_AGENT_NAME") or os.environ.get("MOLTIS_COMPANION_AGENT_NAME", ""))
    parser.add_argument("--agent-display-name", default=os.environ.get("MOLTIS_GITHUB_COMPANION_AGENT_DISPLAY_NAME") or os.environ.get("MOLTIS_COMPANION_AGENT_DISPLAY_NAME", ""))
    parser.add_argument("--main-model", default=os.environ.get("MOLTIS_GITHUB_COMPANION_MAIN_MODEL") or os.environ.get("MOLTIS_COMPANION_MAIN_MODEL", ""))
    parser.add_argument("--self-user-id", default=os.environ.get("MOLTIS_GITHUB_COMPANION_MATRIX_SELF_USER_ID") or os.environ.get("MOLTIS_COMPANION_SELF_USER_ID", ""))
    parser.add_argument("--room-id", default=os.environ.get("MOLTIS_GITHUB_COMPANION_MATRIX_ROOM_ID") or os.environ.get("MOLTIS_COMPANION_ROOM_ID", DEFAULT_ROOM_ID))
    parser.add_argument("--homeserver-url", default=os.environ.get("MOLTIS_GITHUB_COMPANION_MATRIX_HOMESERVER_URL") or os.environ.get("MOLTIS_COMPANION_HOMESERVER_URL", DEFAULT_HOMESERVER_URL))
    pwd_env_key, legacy_pwd_env_key = "MOLTIS_GITHUB_COMPANION_MATRIX_" + "PASSWORD_PATH", "MOLTIS_COMPANION_" + "PASSWORD_PATH"
    parser.add_argument("--password-path", default=os.environ.get(pwd_env_key) or os.environ.get(legacy_pwd_env_key, ""))
    parser.add_argument("--telegram-bot-token-path", default=os.environ.get("MOLTIS_GITHUB_COMPANION_TELEGRAM_BOT_TOKEN_PATH", ""))
    parser.add_argument("--telegram-allowed-users-path", default=os.environ.get("MOLTIS_GITHUB_COMPANION_TELEGRAM_ALLOWED_USERS_PATH", ""))
    parser.add_argument("--telegram-api-url", default=os.environ.get("MOLTIS_GITHUB_COMPANION_TELEGRAM_API_URL", DEFAULT_TELEGRAM_API_URL))
    parser.add_argument("--data-dir", default=os.environ.get("MOLTIS_GITHUB_COMPANION_DATA_DIR") or os.environ.get("MOLTIS_COMPANION_DATA_DIR") or os.environ.get("MOLTIS_DATA_DIR") or os.path.expanduser("~/.moltis"))
    parser.add_argument("--state-dir", default=os.environ.get("MOLTIS_GITHUB_COMPANION_STATE_DIR", ""))
    parser.add_argument("--rpc-url", default=os.environ.get("MOLTIS_GITHUB_COMPANION_RPC_URL") or os.environ.get("MOLTIS_COMPANION_RPC_URL", DEFAULT_RPC_URL))
    parser.add_argument("--gh-api-safe-bin", default=os.environ.get("MOLTIS_GITHUB_COMPANION_GH_API_SAFE_BIN", "gh-api-safe"))
    parser.add_argument("--schedule-dow", type=int, default=None)
    parser.add_argument("--schedule-day-name", default=os.environ.get("MOLTIS_GITHUB_COMPANION_SCHEDULE_DAY_NAME", ""))
    parser.add_argument("--read-only-trial", action="store_true", default=os.environ.get("MOLTIS_GITHUB_COMPANION_READ_ONLY_TRIAL", "").strip() in ("1", "true", "yes"))
    parser.add_argument("--once", action="store_true")
    return parser


def resolve_runtime_config(args: argparse.Namespace) -> dict:
    agent_name = normalize_agent_name(args.agent_name)
    default_dow, default_day_name = AGENT_DEFAULT_SCHEDULES[agent_name]
    env_dow = os.environ.get("MOLTIS_GITHUB_COMPANION_SCHEDULE_DOW", "").strip()
    explicit_dow = getattr(args, "schedule_dow", None)
    if explicit_dow is None and env_dow:
        explicit_dow = _safe_int(env_dow, default_dow)
    state_dir_raw = (args.state_dir or "").strip()
    xdg_state = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    return {
        "agent_name": agent_name, "agent_display_name": derive_display_name(agent_name, args.agent_display_name),
        "main_model": (args.main_model or "").strip(),
        "schedule_dow": _safe_int(explicit_dow, default_dow) if explicit_dow is not None else default_dow,
        "schedule_day_name": (getattr(args, "schedule_day_name", "") or os.environ.get("MOLTIS_GITHUB_COMPANION_SCHEDULE_DAY_NAME", "") or default_day_name).strip(),
        "self_user_id": (args.self_user_id or f"@{agent_name}:{SERVER_DOMAIN}").strip(), "room_id": (args.room_id or DEFAULT_ROOM_ID).strip(),
        "homeserver_url": (args.homeserver_url or DEFAULT_HOMESERVER_URL).strip(), "password_path": (args.password_path or "").strip() or None,
        "telegram_bot_token_path": (getattr(args, "telegram_bot_token_path", "") or os.environ.get("MOLTIS_GITHUB_COMPANION_TELEGRAM_BOT_TOKEN_PATH", "")).strip() or None,
        "telegram_allowed_users_path": (getattr(args, "telegram_allowed_users_path", "") or os.environ.get("MOLTIS_GITHUB_COMPANION_TELEGRAM_ALLOWED_USERS_PATH", "")).strip() or None,
        "telegram_api_url": (getattr(args, "telegram_api_url", "") or os.environ.get("MOLTIS_GITHUB_COMPANION_TELEGRAM_API_URL", "") or DEFAULT_TELEGRAM_API_URL).strip(),
        "data_dir": Path(args.data_dir).expanduser(), "state_dir": Path(state_dir_raw).expanduser() if state_dir_raw else (Path(xdg_state) / "moltis" / f"github-companion-{agent_name}"),
        "rpc_url": (args.rpc_url or DEFAULT_RPC_URL).strip(), "gh_api_safe_bin": (args.gh_api_safe_bin or "gh-api-safe").strip(),
        "read_only_trial": bool(getattr(args, "read_only_trial", False)), "once": bool(getattr(args, "once", False)),
    }


def main(argv: list[str] | None = None) -> int:
    cfg = resolve_runtime_config(build_arg_parser().parse_args(argv))
    store = CompanionStateStore(state_dir=cfg["state_dir"], agent_name=cfg["agent_name"], room_id=cfg["room_id"])
    gh_client = GhApiSafeClient(gh_api_safe_bin=cfg["gh_api_safe_bin"])
    has_matrix_creds = bool(cfg["password_path"] or os.environ.get("MATRIX" + "_PASSWORD", "").strip())
    matrix_client = MatrixClient(homeserver_url=cfg["homeserver_url"], self_user_id=cfg["self_user_id"], agent_name=cfg["agent_name"], room_id=cfg["room_id"], password_path=cfg["password_path"], state_store=store) if has_matrix_creds else None
    tok_env_key = "TELEGRAM_BOT_" + "TOKEN"
    has_telegram_creds = bool(cfg["telegram_bot_token_path"] or cfg["telegram_allowed_users_path"] or os.environ.get(tok_env_key, "").strip() or os.environ.get("TELEGRAM_ALLOWED_USERS", "").strip())
    telegram_client = TelegramClient(bot_token_path=cfg["telegram_bot_token_path"], allowed_users_path=cfg["telegram_allowed_users_path"], api_url=cfg["telegram_api_url"]) if has_telegram_creds else None
    rpc_client = MoltisRpcClient(rpc_url=cfg["rpc_url"])
    poller = NotificationPoller(state_store=store, gh_client=gh_client, read_only_trial=cfg["read_only_trial"])
    trust_filter = TrustFilterAndSnapshotBuilder(state_store=store, gh_client=gh_client, matrix_client=matrix_client, telegram_client=telegram_client, agent_name=cfg["agent_name"])
    execution_coordinator = LocalExecutionCoordinator(state_store=store, rpc_client=rpc_client, data_dir=cfg["data_dir"], agent_name=cfg["agent_name"], agent_display_name=cfg["agent_display_name"], main_model=cfg["main_model"], matrix_client=matrix_client, telegram_client=telegram_client, room_id=cfg["room_id"], schedule_dow=cfg["schedule_dow"], schedule_day_name=cfg["schedule_day_name"])
    runner = GithubCompanionRunner(state_store=store, gh_client=gh_client, poller=poller, trust_filter=trust_filter, execution_coordinator=execution_coordinator, matrix_client=matrix_client, read_only_trial=cfg["read_only_trial"])
    if cfg["once"]:
        poller.wait_until_due()
        runner.run_cycle()
        return 0
    backoff = 5.0
    while True:
        try:
            poller.wait_until_due()
            runner.run_cycle()
            backoff = 5.0
        except KeyboardInterrupt:
            return 0
        except Exception as exc:
            sys.stderr.write(f"moltis-github-companion loop warning ({cfg['agent_name']}): {exc}\n")
            time.sleep(backoff)
            backoff = min(backoff * 2.0, 60.0)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        print("Moltis: GitHub companion failed.", file=sys.stderr)
        sys.exit(1)
