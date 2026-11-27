"""GitHub notification, open pull-request, and mention wake daemon for Moltis agents."""

from __future__ import annotations

import argparse
import base64
import contextlib
import datetime
import fcntl
import fnmatch
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
from collections.abc import Callable, Iterable, Iterator
from pathlib import Path

_SCRIPT_DIR = str(Path(__file__).resolve().parent)
if _SCRIPT_DIR not in sys.path:
    sys.path.insert(0, _SCRIPT_DIR)

import linear_sync
import shadow_eval
import shadow_report

SERVER_DOMAIN = "matrix.wimpys.world"
DEFAULT_ROOM_ID, DEFAULT_HOMESERVER_URL = f"!the-cauldron:{SERVER_DOMAIN}", f"https://{SERVER_DOMAIN}"
DEFAULT_RPC_URL, DEFAULT_TELEGRAM_API_URL = "https://127.0.0.1:13131/api/rpc", "https://api.telegram.org"
MARTIN_ID, SKRYE_ID, ZANNAH_ID, TRAYA_ID = f"@martin:{SERVER_DOMAIN}", f"@skrye:{SERVER_DOMAIN}", f"@zannah:{SERVER_DOMAIN}", f"@traya:{SERVER_DOMAIN}"
BOT_IDS = frozenset({SKRYE_ID, ZANNAH_ID, TRAYA_ID})
ALLOWLIST_USER_IDS = frozenset({MARTIN_ID, SKRYE_ID, ZANNAH_ID, TRAYA_ID})
DISPLAY_NAMES = {"skrye": "Skrye", "zannah": "Zannah", "traya": "Traya"}
USER_ID_DISPLAY_NAMES = {MARTIN_ID: "Martin", SKRYE_ID: "Skrye", ZANNAH_ID: "Zannah", TRAYA_ID: "Traya"}
AGENT_ORDER = ("skrye", "traya", "zannah")
SWEEP_AGENT_ORDER = SWEEP_OWNERS = ("skrye", "zannah")
AGENT_DEFAULT_SCHEDULES: dict[str, tuple[int, str]] = {"skrye": (2, "Tuesday"), "traya": (0, "disabled"), "zannah": (4, "Thursday")}
AGENT_POLL_MINUTE_SLOTS: dict[str, tuple[int, int]] = {"skrye": (0, 30), "traya": (10, 40), "zannah": (20, 50)}
POLL_SLOT_INTERVAL_SECS = BASE_POLL_INTERVAL_SECS = 1800
POLL_SLOT_INTERVAL_MS = BASE_POLL_INTERVAL_MS = 1_800_000
JITTER_MIN_SECS, JITTER_MAX_SECS, JITTER_MIN_MS, JITTER_MAX_MS = 5, 30, 5_000, 30_000
PR_REVIEW_COOLDOWN_SECS, PR_REVIEW_COOLDOWN_MS = 900, 15 * 60 * 1000
RECONCILE_SWEEP_INTERVAL_MS = 6 * 60 * 60 * 1000
RECONCILE_SWEEP_INITIAL_OFFSET_MS: dict[str, int] = {"skrye": 0, "zannah": 3 * 60 * 60 * 1000, "traya": 0}
SWEEP_RETRY_BASE_DELAY_MS = RECONCILE_SWEEP_RETRY_DELAY_MS = 15 * 60 * 1000
SWEEP_RETRY_MAX_DELAY_MS = RECONCILE_SWEEP_INTERVAL_MS
DEFAULT_RPC_TIMEOUT_SECS = DEFAULT_COMPLETION_WAIT_TIMEOUT_SECS = DEFAULT_RECOVERY_WAIT_TIMEOUT_SECS = 3600.0
DEFAULT_COMPLETION_TIMEOUT_MS = DEFAULT_RECOVERY_DEADLINE_MS = 3_600_000
DEFAULT_COMPLETION_POLL_INTERVAL_MS = 250
POLL_PR_OWNERS = POLL_ISSUE_OWNERS = ("wimpysworld", "linuxmatters", "quickemu-project", "noughtylinux", "oval-tutu", "flexiondotorg")
ALLOWED_NOTIFICATION_OWNERS = frozenset(POLL_PR_OWNERS)
TRUSTED_INSTRUCTION_ACTORS = frozenset({"flexiondotorg", "sith-skrye", "sith-traya", "sith-zannah"})
TRUSTED_BOT_ACTORS = frozenset({"dependabot[bot]", "app/dependabot", "github-actions[bot]", "app/github-actions", "cubic-dev-ai[bot]"})
TRUSTED_GITHUB_ACTORS = TRUSTED_INSTRUCTION_ACTORS | TRUSTED_BOT_ACTORS
GITHUB_AGENT_LOGINS: dict[str, str] = {"skrye": "sith-skrye", "traya": "sith-traya", "zannah": "sith-zannah"}
LOGIN_TO_AGENT_NAME: dict[str, str] = {"sith-skrye": "skrye", "skrye": "skrye", "sith-traya": "traya", "traya": "traya", "sith-zannah": "zannah", "zannah": "zannah"}
STATE_SCHEMA_VERSION = 3
DEFAULT_POLL_INTERVAL_MINUTES = 30
DEFAULT_MAX_TASKS_PER_SLOT = 2
DEFAULT_MAX_TASKS_PER_SLOT_BY_AGENT: dict[str, int] = {"skrye": 2, "zannah": 2, "traya": 3}
DEFAULT_MAX_TASKS_PER_DAY = 48
DEFAULT_SLOT_TRIAGE_STUBS_CAP = 10
DEFAULT_SLOT_TRIAGE_RESEARCH_CAP = 2
DEFAULT_SLOT_COMMUNITY_PR_REVIEWS_CAP = 2
DEFAULT_SLOT_TODO_IMPLEMENTATIONS_CAP = 1
DEFAULT_DAILY_IMPLEMENTATIONS_CAP = 8
DEFAULT_DAILY_IMPLEMENTATIONS_CAP_BY_AGENT: dict[str, int] = {"skrye": 8, "zannah": 8, "traya": 0}
DEFAULT_THROTTLE_LIMITS: dict[str, int] = {
    "max_tasks_per_slot": DEFAULT_MAX_TASKS_PER_SLOT,
    "max_tasks_per_day": DEFAULT_MAX_TASKS_PER_DAY,
    "tasks": DEFAULT_MAX_TASKS_PER_SLOT,
    "triage_stubs": DEFAULT_SLOT_TRIAGE_STUBS_CAP,
    "triage_research": DEFAULT_MAX_TASKS_PER_SLOT,
    "community_pr_reviews": DEFAULT_MAX_TASKS_PER_SLOT,
    "todo_implementations": DEFAULT_MAX_TASKS_PER_SLOT,
    "daily_implementations": DEFAULT_DAILY_IMPLEMENTATIONS_CAP,
}
_THROTTLE_BUCKET_TO_STATE_KEY: dict[str, str] = {
    "tasks": "slot_tasks",
    "triage_stubs": "slot_triage_stubs",
    "triage_research": "slot_triage_research",
    "community_pr_reviews": "slot_community_pr_reviews",
    "todo_implementations": "slot_todo_implementations",
}
_LLM_THROTTLE_BUCKETS: frozenset[str] = frozenset({
    "tasks",
    "triage_research",
    "community_pr_reviews",
    "todo_implementations",
})
STATE_FILENAME, ACTIVE_DISPATCH_FILENAME, SECURITY_EVENTS_FILENAME = "state.json", "active-dispatch.json", "security-events.jsonl"
LEGACY_POLL_STATE_FILENAME, LEGACY_NOTIFICATIONS_STATE_FILENAME = "poll-state.json", "notifications-state.json"
LEGACY_WATERMARKS_FILENAME, LEGACY_SECURITY_OWNERSHIP_FILENAME = "watermarks.json", "security-ownership.json"
OUTBOX_FILENAME, AUTH_STATE_FILENAME = "outbox.json", "auth.json"
COORDINATOR_LOCK_FILENAME, STATE_LOCK_FILENAME = "coordinator.lock", "companion.lock"
ENCODED_COMPONENT_BYTES, MAX_RESPONSE_BYTES = 120, 4 * 1048576
DEFAULT_GH_SESSION_KEY, MAX_THREAD_FAILURE_RETRIES = "companion:github", 3
MAX_LINEAR_TODO_RECOVERY_ATTEMPTS = MAX_THREAD_FAILURE_RETRIES
TEAM_LABELS = ("team:implement", "team:merge", "team:review")
PR_TEAM_LABELS = ("team:merge", "team:review", "team:implement")
ISSUE_TEAM_LABELS = ("team:implement", "team:review")
DO_NOT_MERGE_LABEL = "team:do-not-merge"
MERGE_CONFLICTS_LABEL = "merge-conflicts"
ALLOW_MERGE_LINEAR_LABEL = "allow-merge"
APPROVED_LINEAR_LABEL = "approved"
CI_FAILING_LINEAR_LABEL = "ci-failing"
CHANGES_REQUESTED_LINEAR_LABEL = "changes-requested"
IN_REVIEW_BLOCKER_LABELS = (
    MERGE_CONFLICTS_LABEL,
    CI_FAILING_LINEAR_LABEL,
    CHANGES_REQUESTED_LINEAR_LABEL,
)
IN_REVIEW_APPROVED_CLEAR_LABELS = (
    "ready-to-implement",
    "sign-off-required",
    "needs-decision",
    MERGE_CONFLICTS_LABEL,
    CI_FAILING_LINEAR_LABEL,
    CHANGES_REQUESTED_LINEAR_LABEL,
)
TEAM_LABEL_TRIGGER_REASONS: dict[str, str] = {
    "team:implement": "team_implement",
    "team:merge": "team_merge",
    "team:review": "team_review",
}
MODEL_FAMILY_BY_AGENT: dict[str, str] = {"skrye": "gemini", "zannah": "gemini", "traya": "gpt"}
LINEAR_ISSUE_DISPATCH_KINDS = frozenset({"linear_triage_research", "linear_todo_implement", "linear_operator_comment"})
LINEAR_PR_DISPATCH_KINDS = frozenset({"community_pr_blind_review", "community_pr_lane_a_merge", "community_pr_lane_b_review"})
SWEEP_DISPATCH_KINDS = frozenset({"reconcile_sweep", "weekly_sweep"})
MODE_1B_DISPATCH_KINDS = frozenset({"community_triage", "community_auto_review", *TEAM_LABELS, *LINEAR_ISSUE_DISPATCH_KINDS, *LINEAR_PR_DISPATCH_KINDS})
SILENT_TELEGRAM_DISPATCH_KINDS = frozenset({"linear_triage_research", "community_pr_blind_review", "community_pr_lane_b_review"})
MAX_LINEAR_OPERATOR_COMMENTS_PER_POLL = 3
MAX_HANDLED_LINEAR_COMMENT_IDS = 50
DEFAULT_COMMUNITY_AUTO_MERGE_ENABLED = True
DEFAULT_COMMUNITY_AUTO_MERGE_MAX_LINES = 150
DEFAULT_COMMUNITY_AUTO_MERGE_MAX_FILES = 5
DEFAULT_COMMUNITY_AUTO_MERGE_EXCLUDED_REPOS = ("wimpysworld/nix-config",)
HEALTH_POLL_FAILURE_THRESHOLD = 3
HEALTH_ALERT_COOLDOWN_MS = 12 * 60 * 60 * 1000
OPERATOR_DIGEST_AGENT = "skrye"
OPERATOR_DIGEST_HOUR_LONDON = 8
OPERATOR_DIGEST_MINUTE_LONDON = 30
DEFAULT_OPERATOR_DIGEST_ENABLED = True
DEFAULT_SECURITY_PATCH_RELEASE_REPOS: tuple[str, ...] = ()
DEFAULT_HABERDASHER_CONFIG_REPO = "wimpysworld/Haberdasher"
DEFAULT_HABERDASHER_CONFIG_PATH = "haberdasher.yaml"
HABERDASHER_SOURCES_CACHE_TTL_MS = 6 * 60 * 60 * 1000
DEFAULT_SECURITY_PATCH_RELEASE_COOLDOWN_SECS = 2 * 60 * 60
SECURITY_RELEASE_CHECK_INTERVAL_MS = 60 * 60 * 1000
SENSITIVE_COMMUNITY_PR_FILENAMES = frozenset({
    "flake.nix", "flake.lock",
    "cargo.toml", "cargo.lock",
    "go.mod", "go.sum", "go.work", "go.work.sum",
    "package.json", "package-lock.json", "npm-shrinkwrap.json", "pnpm-lock.yaml", "pnpm-workspace.yaml",
    "yarn.lock", "bun.lock", "bun.lockb", "deno.json", "deno.jsonc", "deno.lock",
    "pyproject.toml", "poetry.lock", "uv.lock", "pipfile", "pipfile.lock", "pdm.lock", "setup.py", "setup.cfg",
    "composer.json", "composer.lock",
    "pom.xml", "build.gradle", "build.gradle.kts", "gradle.lockfile", "settings.gradle", "settings.gradle.kts", "libs.versions.toml",
    "mix.exs", "mix.lock", "pubspec.yaml", "pubspec.lock", "packages.lock.json", "package.resolved",
    "dependabot.yml", "dependabot.yaml", "renovate.json", "renovate.json5", ".renovaterc", ".renovaterc.json",
    ".goreleaser.yml", ".goreleaser.yaml", ".envrc",
    "codeowners", "security.md",
})


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


def _london_datetime(ts_ms: int) -> datetime.datetime:
    safe_ms = _safe_int(ts_ms, 0)
    try:
        import zoneinfo

        tz: datetime.tzinfo = zoneinfo.ZoneInfo("Europe/London")
    except Exception:
        tz = datetime.timezone.utc
    return datetime.datetime.fromtimestamp(safe_ms / 1000.0, tz=tz)


def london_date_str(ts_ms: int) -> str:
    """Return the Europe/London YYYY-MM-DD calendar date for a millisecond epoch timestamp."""
    return _london_datetime(ts_ms).strftime("%Y-%m-%d")


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


def compute_pr_owner(repo: str, number: int) -> str:
    owner_repo = (repo or "").strip().lower()
    digest = hashlib.sha256(f"v1:{owner_repo}:pr:{_safe_int(number, 0)}".encode()).digest()
    return SWEEP_AGENT_ORDER[int.from_bytes(digest, "big") % 2]


compute_automated_pr_owner = compute_pr_owner


def compute_issue_owner(repo: str, number: int) -> str:
    owner_repo = (repo or "").strip().lower()
    digest = hashlib.sha256(f"v1:{owner_repo}:issue:{_safe_int(number, 0)}".encode()).digest()
    return SWEEP_AGENT_ORDER[int.from_bytes(digest, "big") % 2]


def compute_repo_owner(repo: str) -> str:
    owner_repo = (repo or "").strip().lower()
    digest = hashlib.sha256(f"v1:{owner_repo}:repo".encode()).digest()
    return SWEEP_AGENT_ORDER[int.from_bytes(digest, "big") % 2]


def _parse_bool_flag(value: object, default: bool = False) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        return value != 0
    if isinstance(value, str):
        norm = value.strip().lower()
        if norm in ("1", "true", "yes", "on"):
            return True
        if norm in ("0", "false", "no", "off"):
            return False
    return default


def parse_repo_list(raw: object, default: Iterable[str] = DEFAULT_COMMUNITY_AUTO_MERGE_EXCLUDED_REPOS) -> tuple[str, ...]:
    items: Iterable[object]
    if raw is None:
        items = default
    elif isinstance(raw, str):
        stripped = raw.strip()
        if not stripped:
            return ()
        if stripped.startswith("["):
            try:
                parsed = json.loads(stripped)
                items = parsed if isinstance(parsed, list) else [stripped]
            except ValueError:
                items = re.split(r"[\s,]+", stripped)
        else:
            items = re.split(r"[\s,]+", stripped)
    elif isinstance(raw, Iterable):
        items = raw
    else:
        items = default
    seen: list[str] = []
    for entry in items:
        norm = str(entry or "").strip().lower()
        if norm and norm not in seen:
            seen.append(norm)
    return tuple(seen)


def extract_label_names(raw_labels: object) -> list[str]:
    nodes = raw_labels["nodes"] if isinstance(raw_labels, dict) and isinstance(raw_labels.get("nodes"), list) else (raw_labels if isinstance(raw_labels, list) else [])
    names: list[str] = []
    for item in nodes:
        raw_name = item.get("name") if isinstance(item, dict) else item
        if isinstance(raw_name, str) and raw_name.strip():
            clean = raw_name.strip()
            if clean not in names:
                names.append(clean)
    return names


def extract_team_labels(raw_labels: object, allowed: Iterable[str] = TEAM_LABELS) -> list[str]:
    present = {lbl.strip().lower() for lbl in extract_label_names(raw_labels) if lbl.strip()}
    return [cand for cand in (str(a).strip().lower() for a in allowed) if cand in present]


def has_do_not_merge_label(raw_labels: object) -> bool:
    return any(lbl.strip().lower() == DO_NOT_MERGE_LABEL for lbl in extract_label_names(raw_labels))


def parse_github_item_url(url: str) -> tuple[str, str, int, str] | None:
    """Parse a GitHub issue or pull request URL into (repo, item_label, number, normalized_url)."""
    if not isinstance(url, str) or not url.strip():
        return None
    try:
        normalized_url = linear_sync.normalize_github_url(url)
    except ValueError:
        return None
    parsed = urllib.parse.urlsplit(normalized_url)
    segments = [seg for seg in parsed.path.split("/") if seg]
    if len(segments) >= 4 and segments[2] in ("pull", "issues") and segments[3].isdigit():
        repo = f"{segments[0].lower()}/{segments[1].lower()}"
        item_label = "PR" if segments[2] == "pull" else "Issue"
        number = int(segments[3])
        if number > 0:
            return repo, item_label, number, normalized_url
    return None


def _is_linear_issue_not_found_error(exc: Exception | None) -> bool:
    """Return True when a Linear error permanently indicates that an issue does not exist."""
    if not isinstance(exc, linear_sync.LinearAPIError):
        return False
    if getattr(exc, "status", None) == 404:
        return True
    return "not found" in str(exc).lower()


def _fetch_linear_issue_state_with_retry(
    linear_client: linear_sync.LinearSyncClient | None,
    linear_id: str,
) -> tuple[str | None, Exception | None]:
    """Fetch a Linear issue's lowercased workflow state name with one retry on transient failure."""
    if linear_client is None:
        return None, None
    last_exc: Exception | None = None
    for attempt in range(2):
        try:
            refreshed = linear_client.get_issue(linear_id)
            post_state = _as_dict(_as_dict(refreshed).get("state"))
            return str(post_state.get("name") or "").strip().lower(), None
        except Exception as exc:
            last_exc = exc
            if _is_linear_issue_not_found_error(exc):
                break
            if attempt == 0:
                continue
    return None, last_exc


def extract_linear_issue_labels(linear_issue: dict) -> set[str]:
    """Return lowercased label names from a Linear issue dict (`labels.nodes` or list `labels`)."""
    if not isinstance(linear_issue, dict):
        return set()
    return {name.lower() for name in extract_label_names(linear_issue.get("labels")) if name}


def extract_linear_github_target(linear_issue: dict, *, expected_kind: str | None = None) -> tuple[str, str, int, str] | None:
    """Extract a GitHub (repo, item_label, number, normalized_url) target from a Linear issue's attachments."""
    if not isinstance(linear_issue, dict):
        return None
    target_kind: str | None = None
    if expected_kind is not None:
        raw_kind = str(expected_kind).strip().lower()
        if raw_kind in ("issue", "issues"):
            target_kind = "Issue"
        elif raw_kind in ("pr", "pull", "pulls", "pullrequest", "pull_request"):
            target_kind = "PR"
        else:
            return None
    raw_attachments = linear_issue.get("attachments")
    if isinstance(raw_attachments, dict) and isinstance(raw_attachments.get("nodes"), list):
        nodes = raw_attachments["nodes"]
    elif isinstance(raw_attachments, list):
        nodes = raw_attachments
    else:
        return None
    for item in nodes:
        raw_url = item.get("url") if isinstance(item, dict) else item
        if not isinstance(raw_url, str) or not raw_url.strip():
            continue
        parsed = parse_github_item_url(raw_url)
        if parsed is None:
            continue
        if target_kind is not None and parsed[1] != target_kind:
            continue
        return parsed
    return None


def _resolve_linear_operator_guidance(
    linear_issue: dict | None,
    *,
    comments: Iterable[dict] | None = None,
) -> list[dict[str, str]]:
    """Return verified Linear workspace admin comments from `comments` or `linear_issue['comments']`."""
    raw_comments: object = (
        comments
        if comments is not None
        else (linear_issue.get("comments") if isinstance(linear_issue, dict) else None)
    )
    return linear_sync.extract_verified_operator_comments(raw_comments)


def verify_team_label_from_events(events: Iterable[dict], label_name: str) -> dict | None:
    """Verify via issue events that the latest `labeled`/`unlabeled` event for `label_name` is `labeled` from `TRUSTED_INSTRUCTION_ACTORS`."""
    target = (label_name or "").strip().lower()
    if not target:
        return None
    best_event: dict | None = None
    best_sort_key: tuple[int, int] = (-1, -1)
    for idx, ev in enumerate(events or ()):
        if not isinstance(ev, dict):
            continue
        ev_type = str(ev.get("event") or "").strip().lower()
        if ev_type not in ("labeled", "unlabeled"):
            continue
        lbl_obj = ev.get("label")
        ev_lbl = str(lbl_obj.get("name") if isinstance(lbl_obj, dict) else (lbl_obj or "")).strip().lower()
        if ev_lbl != target:
            continue
        _, ts_ms = normalize_ts(ev.get("created_at"))
        sort_key = (ts_ms, idx)
        if best_event is None or sort_key >= best_sort_key:
            best_event = ev
            best_sort_key = sort_key
    if best_event is None or str(best_event.get("event") or "").strip().lower() != "labeled":
        return None
    actor_norm = normalize_github_actor(best_event.get("actor") or best_event.get("user"))
    if not is_trusted_instruction_actor(actor_norm):
        return None
    ev_id = best_event.get("id")
    created_at = str(best_event.get("created_at") or "").strip()
    event_key = f"{target}:{ev_id if ev_id is not None else (created_at or 'verified')}"
    return {"label": target, "actor": actor_norm, "event_id": ev_id, "created_at": created_at, "event_key": event_key}


def verify_team_merge_timeline(timeline_events: Iterable[dict], head_sha: str | None) -> dict | None:
    """Verify via issue timeline events that `team:merge` is active, trusted, preceded by `head_sha`, and followed by zero commits."""
    clean_head_sha = str(head_sha or "").strip()
    if not clean_head_sha:
        return None
    events_list = [ev for ev in (timeline_events or ()) if isinstance(ev, dict)]
    last_label_idx: int | None = None
    last_label_ev: dict | None = None
    for idx, ev in enumerate(events_list):
        ev_type = str(ev.get("event") or "").strip().lower()
        if ev_type not in ("labeled", "unlabeled"):
            continue
        lbl_obj = ev.get("label")
        ev_lbl = str(lbl_obj.get("name") if isinstance(lbl_obj, dict) else (lbl_obj or "")).strip().lower()
        if ev_lbl != "team:merge":
            continue
        last_label_idx = idx
        last_label_ev = ev
    if last_label_ev is None or last_label_idx is None:
        return None
    if str(last_label_ev.get("event") or "").strip().lower() != "labeled":
        return None
    actor_norm = normalize_github_actor(last_label_ev.get("actor") or last_label_ev.get("user"))
    if not is_trusted_instruction_actor(actor_norm):
        return None
    post_pushes = [
        ev
        for ev in events_list[last_label_idx + 1 :]
        if str(ev.get("event") or "").strip().lower() in ("committed", "head_ref_force_pushed")
    ]
    if post_pushes:
        return None
    pre_pushes = [
        ev
        for ev in events_list[:last_label_idx]
        if str(ev.get("event") or "").strip().lower() in ("committed", "head_ref_force_pushed")
    ]
    if not pre_pushes:
        return None
    last_pre = pre_pushes[-1]
    last_pre_sha = str(last_pre.get("sha") or last_pre.get("commit_id") or "").strip()
    if not last_pre_sha or last_pre_sha != clean_head_sha:
        return None
    ev_id = last_label_ev.get("id")
    created_at = str(last_label_ev.get("created_at") or "").strip()
    event_key = f"team:merge:{ev_id if ev_id is not None else (created_at or 'verified')}"
    return {
        "label": "team:merge",
        "actor": actor_norm,
        "event_id": ev_id,
        "created_at": created_at,
        "event_key": event_key,
        "head_sha": clean_head_sha,
    }


def extract_pr_file_paths(raw_files: object) -> tuple[list[str] | None, bool]:
    if raw_files is None:
        return None, False
    has_next = False
    nodes: list[object]
    if isinstance(raw_files, dict):
        has_next = bool(_as_dict(raw_files.get("pageInfo")).get("hasNextPage"))
        raw_nodes = raw_files.get("nodes")
        nodes = raw_nodes if isinstance(raw_nodes, list) else []
    elif isinstance(raw_files, list):
        nodes = raw_files
    else:
        return None, False
    paths: list[str] = []
    for item in nodes:
        if isinstance(item, str) and item.strip():
            paths.append(item.strip())
        elif isinstance(item, dict):
            for key in ("path", "filename", "previous_filename"):
                val = item.get(key)
                if isinstance(val, str) and val.strip() and val.strip() not in paths:
                    paths.append(val.strip())
    return paths, has_next


def is_sensitive_community_pr_path(file_path: str) -> bool:
    clean = (file_path or "").strip().replace("\\", "/").lstrip("/")
    while clean.startswith("./"):
        clean = clean[2:]
    if not clean:
        return False
    lower_path = clean.lower()
    if (
        lower_path in (".github/workflows", ".github/actions")
        or lower_path.startswith((".github/workflows/", ".github/actions/"))
        or lower_path.endswith(("npins/sources.json", "niv/sources.json"))
    ):
        return True
    basename = lower_path.rsplit("/", 1)[-1]
    if basename in SENSITIVE_COMMUNITY_PR_FILENAMES:
        return True
    return (
        fnmatch.fnmatchcase(basename, "requirements*.txt")
        or fnmatch.fnmatchcase(basename, "constraints*.txt")
        or fnmatch.fnmatchcase(basename, "gemfile*")
        or fnmatch.fnmatchcase(basename, "*.gemspec")
    )


def resolve_model_tiers(
    *,
    update_model: str = "",
    sweep_model: str = "",
    code_model: str = "",
) -> tuple[str, str, str]:
    raw_update = (update_model or "").strip()
    raw_sweep = (sweep_model or "").strip()
    raw_code = (code_model or "").strip()
    resolved_code = raw_code or raw_sweep or raw_update
    resolved_sweep = raw_sweep or resolved_code
    resolved_update = raw_update or resolved_sweep
    return (resolved_update, resolved_sweep, resolved_code)


def resolve_community_auto_merge_config(
    *,
    enabled: bool | str | None = None,
    max_lines: int | str | None = None,
    max_files: int | str | None = None,
    excluded_repos: Iterable[str] | str | None = None,
) -> dict[str, object]:
    raw_enabled = os.environ.get("MOLTIS_GITHUB_COMPANION_COMMUNITY_AUTO_MERGE_ENABLED") if enabled is None else enabled
    raw_max_lines = os.environ.get("MOLTIS_GITHUB_COMPANION_COMMUNITY_AUTO_MERGE_MAX_LINES") if max_lines is None else max_lines
    raw_max_files = os.environ.get("MOLTIS_GITHUB_COMPANION_COMMUNITY_AUTO_MERGE_MAX_FILES") if max_files is None else max_files
    raw_excluded = os.environ.get("MOLTIS_GITHUB_COMPANION_COMMUNITY_AUTO_MERGE_EXCLUDED_REPOS") if excluded_repos is None else excluded_repos
    return {
        "enabled": _parse_bool_flag(raw_enabled, default=DEFAULT_COMMUNITY_AUTO_MERGE_ENABLED),
        "max_lines": max(0, _safe_int(raw_max_lines, DEFAULT_COMMUNITY_AUTO_MERGE_MAX_LINES)) if raw_max_lines is not None and str(raw_max_lines).strip() != "" else DEFAULT_COMMUNITY_AUTO_MERGE_MAX_LINES,
        "max_files": max(0, _safe_int(raw_max_files, DEFAULT_COMMUNITY_AUTO_MERGE_MAX_FILES)) if raw_max_files is not None and str(raw_max_files).strip() != "" else DEFAULT_COMMUNITY_AUTO_MERGE_MAX_FILES,
        "excluded_repos": parse_repo_list(raw_excluded, default=DEFAULT_COMMUNITY_AUTO_MERGE_EXCLUDED_REPOS),
    }


def resolve_poll_interval_minutes(raw: int | str | None = None) -> int:
    value = os.environ.get("MOLTIS_GITHUB_COMPANION_POLL_INTERVAL_MINUTES") if raw is None else raw
    if value is None or isinstance(value, bool):
        return DEFAULT_POLL_INTERVAL_MINUTES
    if isinstance(value, str) and not value.strip():
        return DEFAULT_POLL_INTERVAL_MINUTES
    parsed = _safe_int(value, 0)
    return parsed if parsed > 0 else DEFAULT_POLL_INTERVAL_MINUTES


def resolve_max_tasks_per_slot(raw: int | str | None = None, *, agent_name: str | None = None) -> int:
    norm_agent = (agent_name or "").strip().lower()
    default_val = DEFAULT_MAX_TASKS_PER_SLOT_BY_AGENT.get(norm_agent, DEFAULT_MAX_TASKS_PER_SLOT)
    value = os.environ.get("MOLTIS_GITHUB_COMPANION_MAX_TASKS_PER_SLOT") if raw is None else raw
    if value is None or isinstance(value, bool):
        return default_val
    if isinstance(value, str) and not value.strip():
        return default_val
    parsed = _safe_int(value, 0)
    return parsed if parsed > 0 else default_val


def resolve_max_tasks_per_day(raw: int | str | None = None) -> int:
    value = os.environ.get("MOLTIS_GITHUB_COMPANION_MAX_TASKS_PER_DAY") if raw is None else raw
    if value is None or isinstance(value, bool):
        return DEFAULT_MAX_TASKS_PER_DAY
    if isinstance(value, str) and not value.strip():
        return DEFAULT_MAX_TASKS_PER_DAY
    parsed = _safe_int(value, 0)
    return parsed if parsed > 0 else DEFAULT_MAX_TASKS_PER_DAY


def resolve_daily_implementations_cap(raw: int | str | None = None, *, agent_name: str | None = None) -> int:
    norm_agent = (agent_name or "").strip().lower()
    default_val = DEFAULT_DAILY_IMPLEMENTATIONS_CAP_BY_AGENT.get(norm_agent, DEFAULT_DAILY_IMPLEMENTATIONS_CAP)
    value = os.environ.get("MOLTIS_GITHUB_COMPANION_DAILY_IMPLEMENTATIONS_CAP") if raw is None else raw
    if value is None or isinstance(value, bool):
        return default_val
    if isinstance(value, str) and not value.strip():
        return default_val
    parsed = _safe_int(value, -1)
    return parsed if parsed >= 0 else default_val


def resolve_operator_digest_enabled(enabled: bool | str | None = None) -> bool:
    raw = os.environ.get("MOLTIS_GITHUB_COMPANION_DIGEST_ENABLED") if enabled is None else enabled
    return _parse_bool_flag(raw, default=DEFAULT_OPERATOR_DIGEST_ENABLED)


_HABERDASHER_REPO_SLUG_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*$")


def _normalize_valid_haberdasher_repo(raw: object) -> str | None:
    if not isinstance(raw, str):
        return None
    clean = raw.strip()
    if (
        not clean
        or not _HABERDASHER_REPO_SLUG_RE.fullmatch(clean)
        or any(part in (".", "..") for part in clean.split("/"))
    ):
        return None
    norm = clean.lower()
    if not is_allowed_notification_repo(norm):
        return None
    return norm


def _strip_yaml_comment(line: str) -> str:
    in_single = False
    in_double = False
    idx = 0
    length = len(line)
    while idx < length:
        ch = line[idx]
        if in_double:
            if ch == "\\" and idx + 1 < length:
                idx += 2
                continue
            if ch == '"':
                in_double = False
        elif in_single:
            if ch == "'":
                if idx + 1 < length and line[idx + 1] == "'":
                    idx += 2
                    continue
                in_single = False
        else:
            if ch == '"':
                in_double = True
            elif ch == "'":
                in_single = True
            elif ch == "#" and (idx == 0 or line[idx - 1].isspace()):
                return line[:idx]
        idx += 1
    return line


def _find_unquoted_char(text: str, target: str) -> int:
    in_single = False
    in_double = False
    idx = 0
    length = len(text)
    while idx < length:
        ch = text[idx]
        if in_double:
            if ch == "\\" and idx + 1 < length:
                idx += 2
                continue
            if ch == '"':
                in_double = False
        elif in_single:
            if ch == "'":
                if idx + 1 < length and text[idx + 1] == "'":
                    idx += 2
                    continue
                in_single = False
        else:
            if ch == '"':
                in_double = True
            elif ch == "'":
                in_single = True
            elif ch == target:
                return idx
        idx += 1
    return -1


def _split_yaml_inline_list(inner: str) -> list[str]:
    items: list[str] = []
    buf: list[str] = []
    in_single = False
    in_double = False
    idx = 0
    length = len(inner)
    while idx < length:
        ch = inner[idx]
        if in_double:
            buf.append(ch)
            if ch == "\\" and idx + 1 < length:
                buf.append(inner[idx + 1])
                idx += 2
                continue
            if ch == '"':
                in_double = False
        elif in_single:
            buf.append(ch)
            if ch == "'":
                if idx + 1 < length and inner[idx + 1] == "'":
                    buf.append(inner[idx + 1])
                    idx += 2
                    continue
                in_single = False
        else:
            if ch == '"':
                in_double = True
                buf.append(ch)
            elif ch == "'":
                in_single = True
                buf.append(ch)
            elif ch == ",":
                items.append("".join(buf))
                buf = []
            else:
                buf.append(ch)
        idx += 1
    if buf:
        items.append("".join(buf))
    return items


def _unquote_yaml_scalar(raw: str) -> str:
    s = raw.strip()
    if len(s) >= 2 and s[0] == '"' and s[-1] == '"':
        return re.sub(r'\\(["\\])', r"\1", s[1:-1]).strip()
    if len(s) >= 2 and s[0] == "'" and s[-1] == "'":
        return s[1:-1].replace("''", "'").strip()
    return s


def parse_haberdasher_sources_yaml(raw_yaml: str) -> tuple[str, ...]:
    """Parse top-level `sources` repository slugs from `haberdasher.yaml` (inline or block list)."""
    if not isinstance(raw_yaml, str) or not raw_yaml.strip():
        return ()
    lines = raw_yaml.lstrip("\ufeff").splitlines()
    raw_entries: list[str] = []

    line_idx = 0
    total_lines = len(lines)
    while line_idx < total_lines:
        raw_line = lines[line_idx]
        line_idx += 1
        if not raw_line or raw_line[0].isspace():
            continue
        uncommented = _strip_yaml_comment(raw_line).rstrip()
        match = re.match(r"^sources\s*:(.*)$", uncommented)
        if not match:
            continue
        rest = match.group(1).strip()
        if rest.startswith("["):
            flow_parts = [rest[1:]]
            close_pos = _find_unquoted_char(flow_parts[0], "]")
            if close_pos >= 0:
                inner = flow_parts[0][:close_pos]
            else:
                inner = ""
                while line_idx < total_lines:
                    next_clean = _strip_yaml_comment(lines[line_idx]).strip()
                    line_idx += 1
                    close_pos = _find_unquoted_char(next_clean, "]")
                    if close_pos >= 0:
                        flow_parts.append(next_clean[:close_pos])
                        inner = " ".join(flow_parts)
                        break
                    flow_parts.append(next_clean)
            for token in _split_yaml_inline_list(inner):
                scalar = _unquote_yaml_scalar(token)
                if scalar:
                    raw_entries.append(scalar)
        elif not rest:
            seq_indent: int | None = None
            while line_idx < total_lines:
                sub_clean = _strip_yaml_comment(lines[line_idx]).rstrip()
                if not sub_clean.strip():
                    line_idx += 1
                    continue
                indent = len(sub_clean) - len(sub_clean.lstrip(" \t"))
                item_match = re.match(r"^[ \t]*-(?:\s+(.*))?$", sub_clean)
                if item_match:
                    if seq_indent is None:
                        seq_indent = indent
                    elif indent < seq_indent:
                        break
                    if indent == seq_indent:
                        val = _unquote_yaml_scalar(item_match.group(1) or "")
                        if val:
                            raw_entries.append(val)
                    line_idx += 1
                    continue
                if seq_indent is None or indent <= seq_indent:
                    break
                line_idx += 1
        break

    seen: list[str] = []
    for entry in raw_entries:
        norm = _normalize_valid_haberdasher_repo(entry)
        if norm and norm not in seen:
            seen.append(norm)
    return tuple(seen)


def resolve_security_release_config(
    *,
    extra_repos: Iterable[str] | str | None = None,
    repos: Iterable[str] | str | None = None,
    cooldown_secs: int | str | None = None,
) -> dict[str, object]:
    if extra_repos is not None:
        raw_repos: object = extra_repos
    elif repos is not None:
        raw_repos = repos
    else:
        raw_extra = os.environ.get("MOLTIS_GITHUB_COMPANION_SECURITY_RELEASE_EXTRA_REPOS")
        if raw_extra is not None and raw_extra.strip() != "":
            raw_repos = raw_extra
        else:
            raw_repos = os.environ.get("MOLTIS_GITHUB_COMPANION_SECURITY_RELEASE_REPOS")
    resolved_extra = parse_repo_list(raw_repos, default=DEFAULT_SECURITY_PATCH_RELEASE_REPOS)
    raw_cooldown = os.environ.get("MOLTIS_GITHUB_COMPANION_SECURITY_RELEASE_COOLDOWN_SECS") if cooldown_secs is None else cooldown_secs
    return {
        "extra_repos": resolved_extra,
        "repos": resolved_extra,
        "cooldown_secs": (
            max(0, _safe_int(raw_cooldown, DEFAULT_SECURITY_PATCH_RELEASE_COOLDOWN_SECS))
            if raw_cooldown is not None and str(raw_cooldown).strip() != ""
            else DEFAULT_SECURITY_PATCH_RELEASE_COOLDOWN_SECS
        ),
    }


_HEALTH_SECRET_REDACT_RE = re.compile(
    r"(?:gh[pousr]_[A-Za-z0-9_]+|github_pat_[A-Za-z0-9_]+|lin_api_[A-Za-z0-9_]+|bot\d+:[A-Za-z0-9_-]+|Bearer\s+[A-Za-z0-9._~+/=-]+)",
    re.IGNORECASE,
)


def _sanitize_health_reason(raw: object, *, max_len: int = 120) -> str:
    text = " ".join(str(raw or "").splitlines()).strip()
    if not text:
        return ""
    text = _HEALTH_SECRET_REDACT_RE.sub("[redacted]", text)
    text = re.sub(r"[\x00-\x1f\x7f]+", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    if len(text) > max_len:
        return text[: max(1, max_len - 3)].rstrip() + "..."
    return text


_ESTIMATE_SIZE_LABELS: dict[int, str] = {1: "XS", 2: "S", 3: "M", 5: "L", 8: "XL"}


def _estimate_size_label(estimate: object) -> str:
    if isinstance(estimate, int) and not isinstance(estimate, bool):
        return _ESTIMATE_SIZE_LABELS.get(estimate, "?")
    return "?"


def _estimate_sort_key(item: dict) -> tuple[int, str, str]:
    est = item.get("estimate")
    est_rank = est if isinstance(est, int) and not isinstance(est, bool) and est in _ESTIMATE_SIZE_LABELS else 999
    ident = str(item.get("identifier") or item.get("id") or "").strip()
    title = str(item.get("title") or "").strip()
    return (est_rank, ident, title)


def format_operator_digest(
    *,
    date_str: str,
    approved: list[dict] | None = None,
    ready_to_merge: list[dict],
    needs_decision: list[dict],
    first_time_prs: list[dict],
    signoff_issues: list[dict],
    security_releases: list[dict],
    dead_letter_keys: list[str],
    is_monday: bool = False,
) -> str:
    """Format the daily weekday 'Waiting on Martin' Telegram digest in plain British English."""
    clean_date = str(date_str or "").strip() or "unknown"
    app = [item for item in (approved or []) if isinstance(item, dict)]
    rtm = [item for item in (ready_to_merge or []) if isinstance(item, dict)]
    nd = [item for item in (needs_decision or []) if isinstance(item, dict)]
    ftp = [item for item in (first_time_prs or []) if isinstance(item, dict)]
    soi = [item for item in (signoff_issues or []) if isinstance(item, dict)]
    sec = [item for item in (security_releases or []) if isinstance(item, dict)]
    dlk = [str(k).strip() for k in (dead_letter_keys or []) if str(k or "").strip()]

    if not (app or rtm or nd or ftp or soi or sec or dlk):
        if not is_monday:
            return ""
        return f"📋 Community Contributions digest ({clean_date})\nAll clear. No items waiting for action."

    lines = [f"📋 Community Contributions digest ({clean_date})"]

    def _append_linear_section(heading: str, items: list[dict]) -> None:
        if not items:
            return
        ordered = sorted(items, key=_estimate_sort_key)
        lines.append("")
        lines.append(f"{heading} ({len(ordered)}):")
        for item in ordered[:10]:
            size = _estimate_size_label(item.get("estimate"))
            ident = str(item.get("identifier") or item.get("id") or "").strip()
            title = " ".join(str(item.get("title") or "").splitlines()).strip() or ident or "Untitled"
            url = str(item.get("url") or "").strip()
            label = f"[{size}] {ident}: {title}" if ident else f"[{size}] {title}"
            lines.append(f"- {label} ({url})" if url else f"- {label}")
        if len(ordered) > 10:
            lines.append(f"- +{len(ordered) - 10} more")

    _append_linear_section("Approved (sign-off ready)", app)
    _append_linear_section("Ready to merge", rtm)
    _append_linear_section("Needs decision", nd)
    _append_linear_section("First-time contributor PRs", ftp)
    _append_linear_section("Sign-off required", soi)

    if sec:
        lines.append("")
        lines.append(f"Security patch releases ({len(sec)}):")
        for item in sec[:10]:
            repo = str(item.get("repo") or "").strip()
            next_tag = str(item.get("next_tag") or "").strip()
            title = " ".join(str(item.get("title") or "").splitlines()).strip()
            url = str(item.get("linear_url") or item.get("url") or "").strip()
            warn = " [unreleased feat/breaking commits]" if item.get("has_non_patch_commits") else ""
            label = f"{repo} {next_tag}".strip() if (repo or next_tag) else (title or "Security patch release")
            lines.append(f"- {label}{warn} ({url})" if url else f"- {label}{warn}")
        if len(sec) > 10:
            lines.append(f"- +{len(sec) - 10} more")

    if dlk:
        lines.append("")
        lines.append(f"Dead-lettered items ({len(dlk)}):")
        for key in dlk[:10]:
            lines.append(f"- {key}")
        if len(dlk) > 10:
            lines.append(f"- +{len(dlk) - 10} more")

    return "\n".join(lines)


_FENCED_CODE_BLOCK_RE = re.compile(r"```[\s\S]*?```")
_INLINE_CODE_RE = re.compile(r"`[^`\n]*`")
_PR_CLOSING_KEYWORD_RE = re.compile(
    r"\b(?:closes|closed|close|fixes|fixed|fix|resolves|resolved|resolve)\s*:?\s*"
    r"(?:https?://(?:www\.)?github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)/issues/(\d+)"
    r"|([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)#(\d+)"
    r"|#(\d+))(?![0-9A-Za-z_])",
    re.IGNORECASE,
)


def extract_pr_closing_issues(raw_pr: dict, *, default_repo: str) -> list[dict[str, object]]:
    """Extract deduplicated allowlisted closing issue references from GraphQL nodes and PR body keywords."""
    if not isinstance(raw_pr, dict):
        return []
    clean_default_repo = str(default_repo or "").strip().lower()
    results: list[dict[str, object]] = []
    seen_keys: set[str] = set()

    def _add_ref(repo_raw: str, num_raw: object, url_raw: str = "") -> None:
        clean_repo = str(repo_raw or "").strip().lower()
        num = _safe_int(num_raw, 0)
        if not clean_repo or "/" not in clean_repo or num <= 0:
            return
        if not is_allowed_notification_repo(clean_repo):
            return
        issue_key = make_pr_key(clean_repo, num)
        if issue_key in seen_keys:
            return
        seen_keys.add(issue_key)
        canonical_url = f"https://github.com/{clean_repo}/issues/{num}"
        if url_raw:
            with contextlib.suppress(ValueError):
                canonical_url = linear_sync.normalize_github_url(url_raw)
        results.append({
            "repo": clean_repo,
            "number": num,
            "issue_key": issue_key,
            "url": canonical_url,
        })

    # Pre-normalised list if already present
    existing_list = raw_pr.get("closing_issues")
    if isinstance(existing_list, list):
        for item in existing_list:
            if isinstance(item, dict):
                _add_ref(str(item.get("repo") or clean_default_repo), item.get("number"), str(item.get("url") or ""))

    # GraphQL closingIssuesReferences.nodes
    raw_refs = raw_pr.get("closingIssuesReferences")
    nodes = (
        raw_refs.get("nodes")
        if isinstance(raw_refs, dict) and isinstance(raw_refs.get("nodes"), list)
        else (raw_refs if isinstance(raw_refs, list) else [])
    )
    for node in nodes:
        if not isinstance(node, dict):
            continue
        repo_obj = node.get("repository")
        node_repo = (
            str(repo_obj.get("nameWithOwner") or repo_obj.get("full_name") or "").strip()
            if isinstance(repo_obj, dict)
            else str(node.get("repo") or "").strip()
        )
        node_url = str(node.get("url") or "").strip()
        if not node_repo and node_url:
            parsed = parse_github_item_url(node_url)
            if parsed is not None:
                node_repo = parsed[0]
        _add_ref(node_repo or clean_default_repo, node.get("number"), node_url)

    # Body fallback using standard GitHub closing keywords (ignoring code blocks)
    body = str(raw_pr.get("body") or "")
    if body:
        stripped = _FENCED_CODE_BLOCK_RE.sub(" ", body)
        stripped = _INLINE_CODE_RE.sub(" ", stripped)
        for match in _PR_CLOSING_KEYWORD_RE.finditer(stripped):
            if match.group(1) and match.group(2):
                _add_ref(match.group(1), int(match.group(2)))
            elif match.group(3) and match.group(4):
                _add_ref(match.group(3), int(match.group(4)))
            elif match.group(5) and clean_default_repo:
                _add_ref(clean_default_repo, int(match.group(5)))

    return results


_SEMVER_TAG_RE = re.compile(r"^(v?)(\d+)\.(\d+)\.(\d+)$")
_BREAKING_COMMIT_RE = re.compile(r"^[a-z]+(?:\([^)]+\))?!:", re.IGNORECASE)
_FEATURE_COMMIT_RE = re.compile(r"^feat(?:\([^)]+\))?:", re.IGNORECASE)
_NON_PATCH_COMMIT_RE = re.compile(r"^(?:feat(?:\([^)]+\))?!?|[a-z]+(?:\([^)]+\))?!):", re.IGNORECASE)
_SECURITY_INDICATOR_RE = re.compile(r"(?:\bsecurity\b|\bcve-\d{4}-\d+\b|\bghsa-[a-z0-9-]+\b)", re.IGNORECASE)


def parse_semver_tag(tag: str) -> tuple[str, int, int, int] | None:
    """Parse a strict stable semver tag (`v?MAJOR.MINOR.PATCH`), rejecting prereleases and aliases."""
    if not isinstance(tag, str):
        return None
    match = _SEMVER_TAG_RE.fullmatch(tag.strip())
    if match is None:
        return None
    return match.group(1), int(match.group(2)), int(match.group(3)), int(match.group(4))


def bump_semver_patch(tag: str) -> str | None:
    """Increment the patch component of a strict stable semver tag."""
    parsed = parse_semver_tag(tag)
    if parsed is None:
        return None
    prefix, major, minor, patch = parsed
    return f"{prefix}{major}.{minor}.{patch + 1}"


def bump_semver_minor(tag: str) -> str | None:
    """Increment the minor component of a strict stable semver tag and reset patch to 0."""
    parsed = parse_semver_tag(tag)
    if parsed is None:
        return None
    prefix, major, minor, _patch = parsed
    return f"{prefix}{major}.{minor + 1}.0"


def classify_unreleased_commits(commit_subjects: Iterable[str]) -> dict[str, list[str]]:
    """Classify unreleased commit subjects into `breaking`, `features`, `patch_safe`, and `non_patch`."""
    breaking: list[str] = []
    features: list[str] = []
    patch_safe: list[str] = []
    for raw in commit_subjects or ():
        subject = " ".join(str(raw or "").splitlines()).strip()
        if not subject:
            continue
        lower = subject.lower()
        if _BREAKING_COMMIT_RE.match(subject) or "breaking change" in lower or "breaking-change" in lower:
            breaking.append(subject)
        elif _FEATURE_COMMIT_RE.match(subject):
            features.append(subject)
        else:
            patch_safe.append(subject)
    return {
        "breaking": breaking,
        "features": features,
        "patch_safe": patch_safe,
        "non_patch": [*breaking, *features],
    }


def is_security_merged_pr(pr: dict) -> bool:
    """Return True when a pull request represents a security fix (branch, Dependabot security, or CVE/GHSA/security indicator)."""
    if not isinstance(pr, dict):
        return False
    head_ref = str(pr.get("headRefName") or pr.get("head_ref") or _as_dict(pr.get("head")).get("ref") or "").strip().lower()
    if head_ref.startswith("security/"):
        return True
    labels = [lbl.strip().lower() for lbl in extract_label_names(pr.get("labels"))]
    title = str(pr.get("title") or "").strip()
    has_security_label = any("security" in lbl or "cve-" in lbl or "ghsa-" in lbl for lbl in labels)
    has_security_title = bool(_SECURITY_INDICATOR_RE.search(title))
    author_norm = normalize_github_actor(pr.get("author") or pr.get("user"))
    if author_norm in ("dependabot[bot]", "app/dependabot", "dependabot") and (has_security_label or has_security_title):
        return True
    return has_security_label or has_security_title


FIRST_TIME_AUTHOR_ASSOCIATIONS = frozenset({"FIRST_TIMER", "FIRST_TIME_CONTRIBUTOR", "NONE"})
IGNORED_LINEAR_STATE_NAMES = frozenset({"canceled", "cancelled", "duplicate", "done", "deferred"})
IGNORED_LINEAR_STATE_TYPES = frozenset({"canceled", "completed", "duplicate"})
CONFLICT_CLOSE_AFTER_MS = 30 * 24 * 60 * 60 * 1000
DRAFT_CONFLICT_CLOSE_AFTER_MS = 90 * 24 * 60 * 60 * 1000
MAX_CONFLICT_CLOSURES_PER_POLL = 3
CONFLICT_NOTICE_MARKER_PHRASE = "currently has merge conflicts with the base branch"

PR_SIZE_ESTIMATE_POINTS: dict[str, int] = {"XS": 1, "S": 2, "M": 3, "L": 5, "XL": 8}

STALE_ISSUE_INACTIVE_AFTER_MS = 365 * 24 * 60 * 60 * 1000
STALE_ISSUE_CLOSE_AFTER_MS = 30 * 24 * 60 * 60 * 1000
MAX_STALE_ISSUE_ACTIONS_PER_POLL = 3
STALE_ISSUE_EXCLUDED_ORGS = frozenset({"oval-tutu"})
STALE_ISSUE_EXCLUDED_REPOS = frozenset({"quicktest", "quickgui", "flexiondotorg.github.io"})
STALE_ISSUE_EXCLUDED_AUTHORS = frozenset({"flexiondotorg", "popey", "lj3954", "lukewh"})
STALE_ISSUE_EXCLUDED_AUTHOR_ASSOCIATIONS = frozenset({"OWNER", "MEMBER", "COLLABORATOR"})
STALE_ISSUE_EXCLUDED_LABELS = frozenset({"bug", "security", "pinned", "help wanted", "keep-open", "team:implement"})
STALE_ISSUE_QUALIFYING_GITHUB_LABELS = frozenset({"enhancement", "new package", "feature", "feature request", "app request", "documentation"})
STALE_ISSUE_QUALIFYING_LINEAR_LABELS = frozenset({"feature", "improvement"})
STALE_ISSUE_CHECKIN_MARKER_PHRASE = "had no community activity or pull request for over a year"
STALE_ISSUE_EXCLUDED_LINEAR_STATES = frozenset({"in progress", "in_progress", "in review", "in_review"})
_STALE_ISSUE_BOT_LOGINS = frozenset({"github-actions", "dependabot", "renovate", "app/github-actions", "app/dependabot", "app/renovate"})


def compute_pr_size_estimate(
    *,
    additions: int | None,
    deletions: int | None,
    changed_files: int | None,
    file_paths: Iterable[str] | None = None,
    files_has_next_page: bool = False,
) -> int | None:
    """Compute a Linear point estimate on the WW T-shirt scale from pull request diff stats."""
    _ = files_has_next_page
    if additions is None or deletions is None or isinstance(additions, bool) or isinstance(deletions, bool):
        return None
    add_val = _safe_int(additions, -1)
    del_val = _safe_int(deletions, -1)
    if add_val < 0 or del_val < 0:
        return None
    paths_list = [str(p).strip() for p in (file_paths or ()) if isinstance(p, str) and str(p).strip()]
    raw_files = _safe_int(changed_files, -1) if (changed_files is not None and not isinstance(changed_files, bool)) else -1
    eff_files = raw_files if raw_files > 0 else len(paths_list)
    if eff_files <= 0:
        return None
    total_lines = add_val + del_val
    if total_lines <= 25 and eff_files == 1:
        points = PR_SIZE_ESTIMATE_POINTS["XS"]
    elif total_lines <= 150 and eff_files <= 5:
        points = PR_SIZE_ESTIMATE_POINTS["S"]
    elif total_lines <= 400 and eff_files <= 12:
        points = PR_SIZE_ESTIMATE_POINTS["M"]
    elif total_lines <= 1000 and eff_files <= 25:
        points = PR_SIZE_ESTIMATE_POINTS["L"]
    else:
        points = PR_SIZE_ESTIMATE_POINTS["XL"]
    if any(is_sensitive_community_pr_path(p) for p in paths_list):
        points = max(points, PR_SIZE_ESTIMATE_POINTS["M"])
    return points


def is_first_time_contributor_association(author_association: object) -> bool:
    norm = str(author_association or "").strip().upper()
    return norm in FIRST_TIME_AUTHOR_ASSOCIATIONS


def is_ignored_linear_issue_state(linear_issue: object) -> bool:
    if not isinstance(linear_issue, dict):
        return False
    if linear_issue.get("archivedAt"):
        return True
    state_obj = _as_dict(linear_issue.get("state"))
    state_name = str(state_obj.get("name") or "").strip().lower()
    state_type = str(state_obj.get("type") or "").strip().lower()
    return state_name in IGNORED_LINEAR_STATE_NAMES or state_type in IGNORED_LINEAR_STATE_TYPES


def normalize_mergeable_state(mergeable: object, merge_state_status: object = None) -> str:
    """Normalise GitHub pull-request mergeable/mergeStateStatus into 'CONFLICTING', 'MERGEABLE', or 'UNKNOWN'."""
    m_val = str(mergeable or "").strip().upper()
    ms_val = str(merge_state_status or "").strip().upper()
    if m_val == "CONFLICTING" or ms_val == "DIRTY":
        return "CONFLICTING"
    if m_val == "MERGEABLE":
        return "MERGEABLE"
    return "UNKNOWN"


def is_merge_conflicting(mergeable: object, merge_state_status: object = None) -> bool:
    return normalize_mergeable_state(mergeable, merge_state_status) == "CONFLICTING"


def _safe_github_mention(author: str | None) -> str:
    clean = re.sub(r"[^A-Za-z0-9_-]", "", str(author or "").strip().lstrip("@"))
    return f"@{clean}" if clean else "there"


def format_pr_merge_conflict_github_comment(author: str | None) -> str:
    mention = _safe_github_mention(author)
    return (
        f"Hi {mention}, thanks for this pull request. It currently has merge conflicts with the base branch, "
        "so we cannot merge it as it stands. Please rebase or merge the latest changes and resolve the conflicts. "
        "If the conflicts remain unresolved after 30 days with no further updates, we will close this pull request, "
        "though you are always welcome to reopen it or submit a new one later."
    )


def format_pr_merge_conflict_close_github_comment(author: str | None) -> str:
    mention = _safe_github_mention(author)
    return (
        f"Hi {mention}, we are closing this pull request because the merge conflicts remained unresolved for 30 days "
        "with no further activity. If you still want to pursue this change, please resolve the conflicts and reopen it, "
        "or open a new pull request against the latest branch."
    )


def format_draft_merge_conflict_close_github_comment(author: str | None) -> str:
    mention = _safe_github_mention(author)
    return (
        f"Hi {mention}, we are closing this draft pull request because it has had no updates for over three months "
        "and now has merge conflicts with the base branch. If this change is still relevant, you are welcome to open "
        "a fresh pull request against the latest branch when you are ready."
    )


def format_linear_conflict_notice_comment(*, author: str | None, pr_url: str, head_sha: str) -> str:
    mention = _safe_github_mention(author)
    short_sha = (head_sha or "").strip()[:12] or "unknown"
    return (
        f"Posted merge-conflict request to {mention} on {pr_url} (`{short_sha}`). "
        "Will close on GitHub after 30 days if conflicts remain unresolved with no author activity."
    )


def format_linear_conflict_resolved_comment(*, pr_url: str, head_sha: str) -> str:
    short_sha = (head_sha or "").strip()[:12] or "unknown"
    return f"Merge conflicts resolved on {pr_url} (`{short_sha}`); removed `merge-conflicts`."


def format_linear_conflict_closed_comment(*, pr_url: str, is_draft: bool) -> str:
    if is_draft:
        return f"Closed draft pull request {pr_url} on GitHub after 90 days of inactivity with unresolved merge conflicts."
    return f"Closed pull request {pr_url} on GitHub after 30 days with unresolved merge conflicts and no author activity."


def format_stale_issue_checkin_github_comment() -> str:
    return (
        "This issue had no community activity or pull request for over a year. "
        "If someone still wants to work on it, leave a comment within 30 days. "
        "Otherwise we will close it as not planned."
    )


def format_stale_issue_close_github_comment() -> str:
    return (
        "We close issues that receive no community interest or pull request for over a year, "
        "so this one closes as not planned. "
        "If you want to pick this up later, open a pull request or leave a comment and we will reopen it."
    )


def format_linear_stale_issue_checkin_comment(*, issue_url: str) -> str:
    return (
        f"Posted a 30-day stale check-in comment on {issue_url}. "
        "We will close this issue as not planned after 30 days if no human replies."
    )


def format_linear_stale_issue_closed_comment(*, issue_url: str) -> str:
    return (
        f"Closed stale issue {issue_url} on GitHub as not planned "
        "after 30 days with no reply to the stale check-in comment."
    )


def _is_stale_issue_bot_actor(actor_obj: object) -> bool:
    if isinstance(actor_obj, dict):
        typename = str(actor_obj.get("__typename") or actor_obj.get("type") or "").strip().lower()
        if typename == "bot":
            return True
    login_norm = normalize_github_actor(actor_obj)
    if not login_norm:
        return False
    if login_norm.endswith("[bot]") or login_norm.startswith("app/"):
        return True
    return login_norm in _STALE_ISSUE_BOT_LOGINS


def is_stale_issue_excluded_repo(repo: str) -> bool:
    norm = (repo or "").strip().lower()
    if not norm or "/" not in norm:
        return True
    org, basename = norm.split("/", 1)
    return (
        org in STALE_ISSUE_EXCLUDED_ORGS
        or norm in STALE_ISSUE_EXCLUDED_REPOS
        or basename in STALE_ISSUE_EXCLUDED_REPOS
    )


def is_stale_issue_excluded_author(author_obj: object, author_association: object = None) -> bool:
    if _is_stale_issue_bot_actor(author_obj):
        return True
    login_norm = normalize_github_actor(author_obj)
    if login_norm and (
        login_norm in STALE_ISSUE_EXCLUDED_AUTHORS
        or login_norm in TRUSTED_INSTRUCTION_ACTORS
        or login_norm.startswith("sith-")
    ):
        return True
    assoc = str(author_association or "").strip().upper()
    return assoc in STALE_ISSUE_EXCLUDED_AUTHOR_ASSOCIATIONS


def _has_stale_issue_excluded_label(labels: Iterable[str]) -> bool:
    return any(str(lbl or "").strip().lower() in STALE_ISSUE_EXCLUDED_LABELS for lbl in (labels or ()))


def _stale_issue_has_linked_pr(timeline_items: object) -> bool:
    if isinstance(timeline_items, dict):
        raw_nodes = timeline_items.get("nodes")
        nodes = raw_nodes if isinstance(raw_nodes, list) else []
    elif isinstance(timeline_items, list):
        nodes = timeline_items
    else:
        return False
    for node in nodes:
        if not isinstance(node, dict):
            continue
        for key in ("source", "subject"):
            ref = _as_dict(node.get(key))
            if str(ref.get("__typename") or "").strip().lower() == "pullrequest":
                return True
    return False


def _stale_issue_comment_nodes(raw_comments: object) -> list[dict]:
    if isinstance(raw_comments, dict):
        nodes = raw_comments.get("nodes")
        return [n for n in nodes if isinstance(n, dict)] if isinstance(nodes, list) else []
    if isinstance(raw_comments, list):
        return [n for n in raw_comments if isinstance(n, dict)]
    return []


def _stale_issue_has_community_commenter(comments: object, *, issue_author_norm: str) -> bool:
    for cm in _stale_issue_comment_nodes(comments):
        cm_author = cm.get("author") or cm.get("user")
        if _is_stale_issue_bot_actor(cm_author):
            continue
        cm_assoc = str(cm.get("authorAssociation") or cm.get("author_association") or "").strip().upper()
        if cm_assoc in STALE_ISSUE_EXCLUDED_AUTHOR_ASSOCIATIONS:
            continue
        cm_login_norm = normalize_github_actor(cm_author)
        if not cm_login_norm:
            continue
        if (
            cm_login_norm == issue_author_norm
            or cm_login_norm in TRUSTED_INSTRUCTION_ACTORS
            or cm_login_norm in STALE_ISSUE_EXCLUDED_AUTHORS
            or cm_login_norm.startswith("sith-")
        ):
            continue
        return True
    return False


def is_stale_issue_protected_linear_issue(linear_issue: object) -> bool:
    if not isinstance(linear_issue, dict):
        return False
    if is_ignored_linear_issue_state(linear_issue):
        return True
    state_name = str(_as_dict(linear_issue.get("state")).get("name") or "").strip().lower()
    if state_name in STALE_ISSUE_EXCLUDED_LINEAR_STATES:
        return True
    return "bug" in extract_linear_issue_labels(linear_issue)


def _find_stale_issue_checkin_ts(comment_nodes: list[dict], *, after_ms: int = 0) -> int:
    latest_ms = 0
    for cm in comment_nodes:
        cm_author = cm.get("author") or cm.get("user")
        cm_login_norm = normalize_github_actor(cm_author)
        if cm_login_norm not in TRUSTED_INSTRUCTION_ACTORS:
            continue
        cm_body_lower = str(cm.get("body") or "").lower()
        if STALE_ISSUE_CHECKIN_MARKER_PHRASE not in cm_body_lower:
            continue
        _, cm_ms = normalize_ts(cm.get("createdAt") or cm.get("created_at"))
        if cm_ms > after_ms and cm_ms > latest_ms:
            latest_ms = cm_ms
    return latest_ms


def _has_human_comment_after(comment_nodes: list[dict], checkin_ts_ms: int) -> bool:
    for cm in comment_nodes:
        cm_author = cm.get("author") or cm.get("user")
        if _is_stale_issue_bot_actor(cm_author):
            continue
        cm_login_norm = normalize_github_actor(cm_author)
        cm_body_lower = str(cm.get("body") or "").lower()
        if cm_login_norm in TRUSTED_INSTRUCTION_ACTORS and STALE_ISSUE_CHECKIN_MARKER_PHRASE in cm_body_lower:
            continue
        _, cm_ms = normalize_ts(cm.get("createdAt") or cm.get("created_at"))
        if cm_ms > checkin_ts_ms:
            return True
    return False


def compute_community_auto_merge_eligible(
    *,
    repo: str,
    additions: int | None,
    deletions: int | None,
    changed_files: int | None,
    file_paths: Iterable[str] | None,
    files_has_next_page: bool = False,
    author_association: str | None = None,
    mergeable: str | None = None,
    merge_state_status: str | None = None,
    has_operator_guidance: bool = False,
    enabled: bool = DEFAULT_COMMUNITY_AUTO_MERGE_ENABLED,
    max_lines: int = DEFAULT_COMMUNITY_AUTO_MERGE_MAX_LINES,
    max_files: int = DEFAULT_COMMUNITY_AUTO_MERGE_MAX_FILES,
    excluded_repos: Iterable[str] = DEFAULT_COMMUNITY_AUTO_MERGE_EXCLUDED_REPOS,
) -> bool:
    if not enabled:
        return False
    if has_operator_guidance:
        return False
    if is_first_time_contributor_association(author_association):
        return False
    if is_merge_conflicting(mergeable, merge_state_status):
        return False
    norm_repo = (repo or "").strip().lower()
    excluded = set(parse_repo_list(excluded_repos, default=()))
    if not norm_repo or norm_repo in excluded:
        return False
    if additions is None or deletions is None or isinstance(additions, bool) or isinstance(deletions, bool):
        return False
    add_val, del_val = _safe_int(additions, -1), _safe_int(deletions, -1)
    if add_val < 0 or del_val < 0 or (add_val + del_val) > max(0, _safe_int(max_lines, DEFAULT_COMMUNITY_AUTO_MERGE_MAX_LINES)):
        return False
    if file_paths is None or files_has_next_page:
        return False
    paths_list = [str(p).strip() for p in file_paths if isinstance(p, str) and str(p).strip()]
    eff_changed = _safe_int(changed_files, -1) if (changed_files is not None and not isinstance(changed_files, bool)) else len(paths_list)
    max_f = max(0, _safe_int(max_files, DEFAULT_COMMUNITY_AUTO_MERGE_MAX_FILES))
    if eff_changed <= 0 or eff_changed > max_f or not paths_list or len(paths_list) < eff_changed:
        return False
    return not any(is_sensitive_community_pr_path(p) for p in paths_list)


def extract_latest_opinionated_reviews(raw_reviews: object) -> list[dict[str, str]]:
    """Normalise GraphQL `latestOpinionatedReviews` into `[{'state', 'author', 'commit_oid'}]`."""
    nodes = (
        raw_reviews["nodes"]
        if isinstance(raw_reviews, dict) and isinstance(raw_reviews.get("nodes"), list)
        else (raw_reviews if isinstance(raw_reviews, list) else [])
    )
    reviews: list[dict[str, str]] = []
    for item in nodes:
        if not isinstance(item, dict):
            continue
        state = str(item.get("state") or "").strip().upper()
        author = normalize_github_actor(item.get("author"))
        commit_obj = item.get("commit")
        commit_oid = str(
            (commit_obj.get("oid") if isinstance(commit_obj, dict) else None)
            or item.get("commit_oid")
            or item.get("commit_id")
            or ""
        ).strip()
        if state or author or commit_oid:
            reviews.append({
                "state": state,
                "author": author,
                "commit_oid": commit_oid,
            })
    return reviews


def _apply_pull_request_mergeability_entry(pr: dict, entry: object) -> None:
    """Attach hydrated mergeability and opinionated reviews from `fetch_pull_request_mergeability` onto `pr`."""
    if isinstance(entry, dict):
        ms_state = str(entry.get("merge_state_status") or entry.get("mergeStateStatus") or "").strip().upper()
        m_state = normalize_mergeable_state(entry.get("mergeable"), ms_state)
        raw_reviews = (
            entry.get("latest_opinionated_reviews")
            if "latest_opinionated_reviews" in entry
            else entry.get("latestOpinionatedReviews")
        )
        reviews = extract_latest_opinionated_reviews(raw_reviews) if raw_reviews is not None else []
    elif isinstance(entry, (tuple, list)) and len(entry) >= 2:
        ms_state = str(entry[1] or "").strip().upper()
        m_state = normalize_mergeable_state(entry[0], ms_state)
        reviews = extract_latest_opinionated_reviews(entry[2]) if len(entry) >= 3 else None
    else:
        return
    pr["mergeable"] = m_state
    pr["merge_state_status"] = ms_state
    pr["mergeStateStatus"] = ms_state
    pr["has_merge_conflicts"] = m_state == "CONFLICTING"
    if reviews is not None:
        pr["latest_opinionated_reviews"] = reviews


def is_small_agent_pr_auto_merge_eligible(
    pr: dict,
    *,
    max_lines: int = DEFAULT_COMMUNITY_AUTO_MERGE_MAX_LINES,
    max_files: int = DEFAULT_COMMUNITY_AUTO_MERGE_MAX_FILES,
    excluded_repos: Iterable[str] = DEFAULT_COMMUNITY_AUTO_MERGE_EXCLUDED_REPOS,
    has_operator_guidance: bool = False,
) -> bool:
    """Return True when an agent-authored XS/S pull request qualifies for dual-family auto-merge hold-lifting."""
    if not isinstance(pr, dict):
        return False
    author = normalize_github_actor(pr.get("author") or pr.get("user"))
    if author not in ("sith-skrye", "sith-zannah"):
        return False
    if pr.get("is_draft") or pr.get("isDraft") or pr.get("draft"):
        return False
    if has_operator_guidance:
        return False
    repo_val = pr.get("repo")
    if not isinstance(repo_val, str) or not repo_val.strip():
        raw_repo = pr.get("repository")
        repo_val = (
            raw_repo.get("nameWithOwner") or raw_repo.get("full_name")
            if isinstance(raw_repo, dict)
            else (raw_repo if isinstance(raw_repo, str) else "")
        )
    norm_repo = str(repo_val or "").strip().lower()
    excluded = set(parse_repo_list(excluded_repos, default=()))
    if not norm_repo or norm_repo in excluded:
        return False
    raw_add = pr.get("additions")
    raw_del = pr.get("deletions")
    if raw_add is None or raw_del is None or isinstance(raw_add, bool) or isinstance(raw_del, bool):
        return False
    add_val = _safe_int(raw_add, -1)
    del_val = _safe_int(raw_del, -1)
    max_l = max(0, _safe_int(max_lines, DEFAULT_COMMUNITY_AUTO_MERGE_MAX_LINES))
    if add_val < 0 or del_val < 0 or (add_val + del_val) > max_l:
        return False
    if "file_paths" in pr:
        raw_files = pr.get("file_paths")
    elif "files" in pr:
        raw_files = pr.get("files")
    else:
        return False
    if isinstance(raw_files, tuple):
        raw_files = list(raw_files)
    paths_list, extracted_has_next = extract_pr_file_paths(raw_files)
    files_has_next_page = bool(pr.get("files_has_next_page", extracted_has_next))
    if paths_list is None or files_has_next_page:
        return False
    raw_chg = pr.get("changed_files") if "changed_files" in pr else pr.get("changedFiles")
    if isinstance(raw_chg, bool):
        return False
    eff_changed = _safe_int(raw_chg, -1) if raw_chg is not None else len(paths_list)
    max_f = max(0, _safe_int(max_files, DEFAULT_COMMUNITY_AUTO_MERGE_MAX_FILES))
    if eff_changed <= 0 or eff_changed > max_f or not paths_list or len(paths_list) < eff_changed:
        return False
    estimate = compute_pr_size_estimate(
        additions=add_val,
        deletions=del_val,
        changed_files=eff_changed,
        file_paths=paths_list,
        files_has_next_page=files_has_next_page,
    )
    return estimate in (1, 2)


def has_dual_family_head_approvals(pr: dict) -> bool:
    """Return True when both the peer Gemini agent and `sith-traya` approved `pr` on its exact `head_sha` with no trusted changes requested."""
    if not isinstance(pr, dict):
        return False
    author = normalize_github_actor(pr.get("author") or pr.get("user"))
    head_sha = str(pr.get("head_sha") or pr.get("headRefOid") or "").strip()
    if author not in ("sith-skrye", "sith-zannah") or not head_sha:
        return False
    other_gemini = "sith-zannah" if author == "sith-skrye" else "sith-skrye"
    raw_reviews = (
        pr.get("latest_opinionated_reviews")
        if "latest_opinionated_reviews" in pr
        else pr.get("latestOpinionatedReviews")
    )
    reviews = extract_latest_opinionated_reviews(raw_reviews)
    head_sha_norm = head_sha.lower()
    approved_head_actors: set[str] = set()
    for review in reviews:
        reviewer = review["author"]
        state = review["state"]
        if reviewer in TRUSTED_INSTRUCTION_ACTORS and state == "CHANGES_REQUESTED":
            return False
        if state == "APPROVED" and review["commit_oid"].lower() == head_sha_norm:
            approved_head_actors.add(reviewer)
    return other_gemini in approved_head_actors and "sith-traya" in approved_head_actors


def compute_lane_a_bypass_reasons(
    *,
    repo: str,
    additions: int | None,
    deletions: int | None,
    changed_files: int | None,
    file_paths: Iterable[str] | None,
    files_has_next_page: bool = False,
    ci_state: str | None = None,
    author_association: str | None = None,
    mergeable: str | None = None,
    merge_state_status: str | None = None,
    has_operator_guidance: bool = False,
    enabled: bool = DEFAULT_COMMUNITY_AUTO_MERGE_ENABLED,
    max_lines: int = DEFAULT_COMMUNITY_AUTO_MERGE_MAX_LINES,
    max_files: int = DEFAULT_COMMUNITY_AUTO_MERGE_MAX_FILES,
    excluded_repos: Iterable[str] = DEFAULT_COMMUNITY_AUTO_MERGE_EXCLUDED_REPOS,
) -> list[str]:
    """Return ordered Lane A bypass reason tokens for a community pull request."""
    reasons: list[str] = []
    if not enabled:
        reasons.append("disabled")
    if has_operator_guidance:
        reasons.append("operator_guidance")
    if is_first_time_contributor_association(author_association):
        reasons.append("first_time_contributor")
    if is_merge_conflicting(mergeable, merge_state_status):
        reasons.append("merge_conflicts")
    norm_repo = (repo or "").strip().lower()
    excluded = set(parse_repo_list(excluded_repos, default=()))
    if not norm_repo or norm_repo in excluded:
        reasons.append("excluded_repo")
    max_l = max(0, _safe_int(max_lines, DEFAULT_COMMUNITY_AUTO_MERGE_MAX_LINES))
    if additions is None or deletions is None or isinstance(additions, bool) or isinstance(deletions, bool):
        reasons.append("lines_exceeded")
    else:
        add_val, del_val = _safe_int(additions, -1), _safe_int(deletions, -1)
        if add_val < 0 or del_val < 0 or (add_val + del_val) > max_l:
            reasons.append("lines_exceeded")
    max_f = max(0, _safe_int(max_files, DEFAULT_COMMUNITY_AUTO_MERGE_MAX_FILES))
    paths_list = [str(p).strip() for p in file_paths if isinstance(p, str) and str(p).strip()] if file_paths is not None else []
    eff_changed = _safe_int(changed_files, -1) if (changed_files is not None and not isinstance(changed_files, bool)) else len(paths_list)
    if eff_changed > max_f:
        reasons.append("files_exceeded")
    if file_paths is None or files_has_next_page or eff_changed <= 0 or not paths_list or len(paths_list) < eff_changed:
        reasons.append("incomplete_files")
    if any(is_sensitive_community_pr_path(p) for p in paths_list):
        reasons.append("sensitive_path")
    if ci_state is not None and normalize_ci_state(ci_state) not in ("SUCCESS", "NONE"):
        reasons.append("ci_not_green")
    return reasons


_BLIND_REVIEW_VERDICT_RE = re.compile(
    r"^\s*(?:[-*]\s+)?(?:\*\*|`)?BLIND_REVIEW_VERDICT(?:\*\*|`)?\s*:\s*(?:\*\*|`)?(PASS|FAIL)(?:\*\*|`)?\s*$",
    re.IGNORECASE,
)
_BLIND_REVIEW_VERDICT_PREFIX_RE = re.compile(
    r"^\s*(?:[-*]\s+)?(?:\*\*|`)?BLIND_REVIEW_VERDICT(?:\*\*|`)?\s*:",
    re.IGNORECASE,
)
_BLIND_FINDINGS_RE = re.compile(
    r"^\s*(?:[-*]\s+)?(?:\*\*|`)?FINDINGS(?:\*\*|`)?\s*:\s*(.*)$",
    re.IGNORECASE,
)
_BLIND_POLISH_RE = re.compile(
    r"^\s*(?:[-*]\s+)?(?:\*\*|`)?POLISH(?:\*\*|`)?\s*:\s*(.*)$",
    re.IGNORECASE,
)
_LANE_B_VERDICT_RE = re.compile(
    r"^\s*(?:[-*]\s+)?(?:\*\*|`)?LANE_B_VERDICT(?:\*\*|`)?\s*:\s*(?:\*\*|`)?(ready-to-merge|needs-decision)(?:\*\*|`)?\s*$",
    re.IGNORECASE,
)
_LANE_B_VERDICT_PREFIX_RE = re.compile(
    r"^\s*(?:[-*]\s+)?(?:\*\*|`)?LANE_B_VERDICT(?:\*\*|`)?\s*:",
    re.IGNORECASE,
)
_LANE_B_SUMMARY_RE = re.compile(
    r"^\s*(?:[-*]\s+)?(?:\*\*|`)?(?:SUMMARY|REASON)(?:\*\*|`)?\s*:\s*(.*)$",
    re.IGNORECASE,
)
_EMPTY_POLISH_VALUES = frozenset({"", "none", "n/a", "na", "nil", "-"})


def _normalize_optional_polish(text: str) -> str:
    clean = " ".join(str(text or "").splitlines()).strip()
    return "" if clean.lower() in _EMPTY_POLISH_VALUES else clean


def parse_blind_review_reply(reply_text: str) -> tuple[str, str, str]:
    """Parse `BLIND_REVIEW_VERDICT: PASS|FAIL` plus optional `FINDINGS:` and `POLISH:`; fail-closed to FAIL."""
    if not isinstance(reply_text, str) or not reply_text.strip():
        return "FAIL", "Unparseable or empty blind review reply", ""
    verdicts_seen: list[str] = []
    findings_lines: list[str] = []
    polish_lines: list[str] = []
    active_section: str | None = None
    saw_invalid_verdict_line = False
    for line in reply_text.replace("\r\n", "\n").splitlines():
        if m := _BLIND_REVIEW_VERDICT_RE.match(line):
            verdicts_seen.append(m.group(1).upper())
            active_section = None
            continue
        if _BLIND_REVIEW_VERDICT_PREFIX_RE.match(line):
            saw_invalid_verdict_line = True
            active_section = None
            continue
        if m := _BLIND_FINDINGS_RE.match(line):
            active_section = "findings"
            if val := m.group(1).strip():
                findings_lines.append(val)
            continue
        if m := _BLIND_POLISH_RE.match(line):
            active_section = "polish"
            if val := m.group(1).strip():
                polish_lines.append(val)
            continue
        if active_section == "findings" and line.strip():
            findings_lines.append(line.strip())
        elif active_section == "polish" and line.strip():
            polish_lines.append(line.strip())
    findings = "\n".join(findings_lines).strip()
    polish = "\n".join(polish_lines).strip()
    distinct = set(verdicts_seen)
    if saw_invalid_verdict_line or not distinct or len(distinct) > 1:
        excerpt = " ".join(reply_text.strip().splitlines())[:240]
        reason = f"Unparseable blind review reply: {excerpt}" if excerpt else "Unparseable blind review reply"
        return "FAIL", findings or reason, ""
    return next(iter(distinct)), findings, polish


def parse_lane_b_reply(reply_text: str) -> tuple[str, str]:
    """Parse `LANE_B_VERDICT: ready-to-merge|needs-decision`; fail-closed to needs-decision."""
    if not isinstance(reply_text, str) or not reply_text.strip():
        return "needs-decision", "Unparseable or empty Lane B review reply"
    verdicts_seen: list[str] = []
    summary_lines: list[str] = []
    other_lines: list[str] = []
    in_summary = False
    saw_invalid_verdict_line = False
    for line in reply_text.replace("\r\n", "\n").splitlines():
        if m := _LANE_B_VERDICT_RE.match(line):
            verdicts_seen.append(m.group(1).lower())
            in_summary = False
            continue
        if _LANE_B_VERDICT_PREFIX_RE.match(line):
            saw_invalid_verdict_line = True
            in_summary = False
            continue
        if m := _LANE_B_SUMMARY_RE.match(line):
            in_summary = True
            if val := m.group(1).strip():
                summary_lines.append(val)
            continue
        if line.strip():
            if in_summary:
                summary_lines.append(line.strip())
            else:
                other_lines.append(line.strip())
    summary = "\n".join(summary_lines).strip() or "\n".join(other_lines).strip()
    distinct = set(verdicts_seen)
    if saw_invalid_verdict_line or not distinct or len(distinct) > 1:
        excerpt = " ".join(reply_text.strip().splitlines())[:240]
        reason = f"Unparseable Lane B review reply: {excerpt}" if excerpt else "Unparseable Lane B review reply"
        return "needs-decision", reason
    return next(iter(distinct)), summary


_LINEAR_ISSUE_KEY_RE = re.compile(r"^/[^/]+/issue/([A-Za-z0-9_-]+)(?:/|$)", re.IGNORECASE)


def _extract_linear_issue_key(url: str | None) -> str:
    if not isinstance(url, str) or not url.strip():
        return ""
    parsed = urllib.parse.urlsplit(url.strip())
    if (parsed.hostname or "").lower() != "linear.app":
        return ""
    if match := _LINEAR_ISSUE_KEY_RE.match(parsed.path or ""):
        return match.group(1).lower()
    return ""


def _parse_merge_reply(
    reply_text: str | None,
    *,
    repo: str,
    number: int,
    linear_url: str | None = None,
    allow_blocked: bool = False,
) -> tuple[str, str]:
    clean = normalize_terminal_reply_text(reply_text)
    if not clean or is_heartbeat_ok_reply(clean):
        return "unconfirmed", "empty_or_heartbeat_ok"
    _, code_spans = _find_code_spans(clean)
    expected_repo = (repo or "").strip().lower()
    expected_number = _safe_int(number, 0)
    expected_linear_key = _extract_linear_issue_key(linear_url)
    merged_line = ""
    decision_line = ""
    blocked_line = ""
    has_blocked_entry = False

    def _matches_pr_or_linear(url: str) -> bool:
        parsed_gh = parse_github_item_url(url)
        if parsed_gh is not None:
            return bool(
                expected_repo
                and expected_number > 0
                and parsed_gh[0] == expected_repo
                and parsed_gh[1] == "PR"
                and parsed_gh[2] == expected_number
            )
        entry_linear_key = _extract_linear_issue_key(url)
        return bool(entry_linear_key and (not expected_linear_key or entry_linear_key == expected_linear_key))

    for match in _STEP5_ENTRY_RE.finditer(clean):
        if _offset_in_spans(match.start(), code_spans):
            continue
        emoji = _canonicalize_step5_emoji(match.group("emoji"))
        url = match.group("url").strip()
        title = match.group("title").strip()
        entry_line = f"{emoji} {url} - {title}"
        if emoji == "🧑‍⚖️":
            if _matches_pr_or_linear(url):
                decision_line = decision_line or entry_line
        elif emoji == "✋🏻":
            has_blocked_entry = True
            if allow_blocked and _matches_pr_or_linear(url):
                blocked_line = blocked_line or entry_line
        elif emoji == "🏁":
            parsed_gh = parse_github_item_url(url)
            if (
                parsed_gh is not None
                and expected_repo
                and expected_number > 0
                and parsed_gh[0] == expected_repo
                and parsed_gh[1] == "PR"
                and parsed_gh[2] == expected_number
            ):
                merged_line = merged_line or entry_line

    if decision_line and merged_line:
        return "unconfirmed", "conflicting_merge_and_decision_entries"
    if allow_blocked and blocked_line and (merged_line or decision_line):
        return "unconfirmed", "conflicting_merge_and_blocked_entries"
    if decision_line and not (allow_blocked and has_blocked_entry):
        return "needs_decision", decision_line
    if allow_blocked and blocked_line:
        return "blocked", blocked_line
    if merged_line and not has_blocked_entry:
        return "merged", merged_line
    if has_blocked_entry:
        return "unconfirmed", "blocked_without_merge"
    return "unconfirmed", "missing_merge_confirmation"


def parse_lane_a_merge_reply(
    reply_text: str | None,
    *,
    repo: str,
    number: int,
    linear_url: str | None = None,
) -> tuple[str, str]:
    """Classify a `community_pr_lane_a_merge` reply as `merged`, `needs_decision`, or `unconfirmed`."""
    return _parse_merge_reply(reply_text, repo=repo, number=number, linear_url=linear_url, allow_blocked=False)


def parse_linear_todo_merge_reply(
    reply_text: str | None,
    *,
    repo: str,
    number: int,
    linear_url: str | None = None,
) -> tuple[str, str]:
    """Classify a `linear_todo_merge` reply as `merged`, `blocked`, `needs_decision`, or `unconfirmed`."""
    return _parse_merge_reply(reply_text, repo=repo, number=number, linear_url=linear_url, allow_blocked=True)


def _extract_polish_from_comment_body(comment_body: str) -> str:
    if not isinstance(comment_body, str) or not comment_body.strip():
        return ""
    polish_lines: list[str] = []
    in_polish = False
    for line in comment_body.replace("\r\n", "\n").splitlines():
        if _BLIND_FINDINGS_RE.match(line) or _BLIND_REVIEW_VERDICT_PREFIX_RE.match(line):
            in_polish = False
            continue
        if m := _BLIND_POLISH_RE.match(line):
            in_polish = True
            if val := m.group(1).strip():
                polish_lines.append(val)
            continue
        if in_polish and line.strip():
            polish_lines.append(line.strip())
    return _normalize_optional_polish("\n".join(polish_lines))


def is_automated_update_pr(author_norm: str, repo: str = "", head_ref: str = "", labels: list[str] | None = None, title: str = "") -> bool:
    norm_author = normalize_github_actor(author_norm)
    if norm_author in TRUSTED_BOT_ACTORS and norm_author != "cubic-dev-ai[bot]":
        return True
    if (repo or "").strip().lower() == "wimpysworld/nix-config" and norm_author == "flexiondotorg":
        clean_title = (title or "").strip().lower()
        clean_ref = (head_ref or "").strip().lower()
        norm_labels = {str(lbl).strip().lower() for lbl in (labels or []) if str(lbl).strip()}
        if "freshener" in clean_ref or "freshener" in norm_labels or (clean_title.startswith("chore(") and "update to" in clean_title):
            return True
    return False


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
    ("ignore_previous_instructions", re.compile(r"\b(?:ignore|disregard|forget|override|bypass)\s+(?:all\s+|any\s+|the\s+)?(?:previous|prior|above|earlier|system|developer|safety|security)\s+(?:instructions?|prompts?|rules?|constraints?|directives?|guardrails?)\b", re.IGNORECASE)),
    ("system_prompt_override", re.compile(r"(?:\[\s*(?:system|inst|admin|developer)\s*\]|<\|\s*(?:im_start|system|user|assistant)\s*\|>|^\s*(?:system\s+prompt|developer\s+message|new\s+system\s+instructions?)\s*:)", re.IGNORECASE | re.MULTILINE)),
    ("tool_invocation_directive", re.compile(r"\b(?:gh-bot-merge|gh-code-scanning-dismiss|gh-notification-dismiss|gh-workflow-approve|gh-review-resolve|gh-review-unresolve|gh-review-inline|gh-review-reply|moltis-telegram-voice|chat\.send_sync|exec_command|tool_call)\b", re.IGNORECASE)),
    ("unauthorized_merge_or_dismiss_command", re.compile(r"\b(?:gh\s+pr\s+merge|merge\s+this\s+(?:pr|pull\s+request)|approve\s+and\s+merge|dismiss\s+(?:this\s+|all\s+)?(?:alert|notification|review)s?|@dependabot\s+(?:merge|squash\s+and\s+merge|ignore|close))\b", re.IGNORECASE)),
    ("role_spoofing", re.compile(r"\b(?:i\s+am\s+flexiondotorg|speaking\s+as\s+flexiondotorg|on\s+behalf\s+of\s+flexiondotorg|acting\s+as\s+(?:flexiondotorg|sith-skrye|sith-traya|sith-zannah)|from\s+flexiondotorg\s*:|authorized\s+by\s+flexiondotorg)\b", re.IGNORECASE)),
)


def detect_coercion_patterns(raw_text: str | None) -> list[str]:
    """Return ordered list of coercion / prompt-injection rule names matched in raw_text."""
    if not isinstance(raw_text, str) or not raw_text:
        return []
    matched: list[str] = []
    target = f"{raw_text}\n{strip_html_comments(raw_text)}"
    for rule_name, pattern in _COERCION_RULES:
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
    if kind == "targeted" or kind in MODE_1B_DISPATCH_KINDS:
        target = f"{repo}#{number}" if repo and number else (repo or "GitHub thread")
        label = "targeted" if kind == "targeted" else kind
        line = f"⚙️ {display} starting {label} {(subject_kind or 'PullRequest').strip()} turn on {target} ({(trigger_reason or 'notification').strip()})."
    elif kind == "weekly_sweep":
        line = f"⚙️ {display} starting weekly organisation sweep ({(sweep_date or schedule_day_name or 'scheduled').strip()})."
    else:
        line = f"⚙️ {display} starting 6-hour reconciliation sweep."
    return sanitize_no_matrix_mentions(" ".join(line.splitlines()).strip())


def _is_thought_block(item: dict) -> bool:
    if item.get("thought") is True:
        return True
    return str(item.get("type") or "").strip().lower() in ("thought", "thinking", "reasoning")


def extract_text_content(value: object) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        parts: list[str] = []
        for item in value:
            if isinstance(item, str):
                if item:
                    parts.append(item)
            elif isinstance(item, dict) and not _is_thought_block(item):
                if extracted := extract_text_content(item):
                    parts.append(extracted)
        return "\n".join(parts)
    if isinstance(value, dict):
        if _is_thought_block(value):
            return ""
        for key in ("text", "content", "reply", "response", "body"):
            candidate = value.get(key)
            if isinstance(candidate, str):
                if candidate:
                    return candidate
            elif isinstance(candidate, (list, dict)):
                if extracted := extract_text_content(candidate):
                    return extracted
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
    ("tool_or_turn_failed", re.compile(r"^\s*(?:the\s+)?(?:github|gh|gh-api-safe|gh-bot-merge|gh-review-inline|gh-review-reply|gh-review-resolve|gh-review-unresolve|gh-notification-dismiss|gh-workflow-approve|git|exec|shell|rpc|model|provider|api|command|request|turn|dispatch|tool)\s+(?:tool\s+|command\s+|call\s+|request\s+|execution\s+|turn\s+|helper\s+)?(?:failed|errored|timed\s+out|aborted|crashed|was\s+blocked|is\s+unavailable)\b", re.IGNORECASE)),
    ("unable_to_complete", re.compile(r"^\s*(?:i\s+(?:was\s+|am\s+)?)?(?:failed|unable|could\s+not|cannot|can\s+not)\s+(?:to\s+)?(?:complete|finish|run|execute|fetch|query|read|inspect|review|merge|dismiss|post|reply|process|reach|connect|authenticate|proceed|continue)\b", re.IGNORECASE)),
)

_SKIN_TONE_OR_VS16 = r"[\ufe0f\U0001f3fb-\U0001f3ff]{0,2}"
_STEP5_EMOJI_SPECS: tuple[tuple[str, str], ...] = (
    ("🧼", r"\U0001f9fc\ufe0f?"),
    ("🧑‍⚖️", r"[\U0001f9d1\U0001f468\U0001f469][\U0001f3fb-\U0001f3ff]?\u200d?\u2696\ufe0f?"),
    ("🏁", r"\U0001f3c1\ufe0f?"),
    ("🚦", r"\U0001f6a6\ufe0f?"),
    ("👍🏻", rf"\U0001f44d{_SKIN_TONE_OR_VS16}"),
    ("👎🏻", rf"\U0001f44e{_SKIN_TONE_OR_VS16}"),
    ("👆🏻", rf"\U0001f446{_SKIN_TONE_OR_VS16}"),
    ("🤲🏻", rf"\U0001f932{_SKIN_TONE_OR_VS16}"),
    ("🤞🏻", rf"\U0001f91e{_SKIN_TONE_OR_VS16}"),
    ("✍🏻", rf"\u270d{_SKIN_TONE_OR_VS16}"),
    ("✋🏻", rf"\u270b{_SKIN_TONE_OR_VS16}"),
)
_STEP5_EMOJI_BY_LEAD_CHAR: dict[str, str] = {
    "\U0001f9fc": "🧼",
    "\U0001f9d1": "🧑‍⚖️",
    "\U0001f468": "🧑‍⚖️",
    "\U0001f469": "🧑‍⚖️",
    "\U0001f3c1": "🏁",
    "\U0001f6a6": "🚦",
    "\U0001f44d": "👍🏻",
    "\U0001f44e": "👎🏻",
    "\U0001f446": "👆🏻",
    "\U0001f932": "🤲🏻",
    "\U0001f91e": "🤞🏻",
    "\u270d": "✍🏻",
    "\u270b": "✋🏻",
}
_STEP5_EMOJI_ALTERNATION = "|".join(pattern for _, pattern in _STEP5_EMOJI_SPECS)
_STEP5_URL_PATTERN = (
    r"https?://(?:"
    r"github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:/[^\s<>`\"'()]+)?"
    r"|linear\.app/[A-Za-z0-9_.-]+/issue/[A-Za-z0-9_-]+(?:/[^\s<>`\"'()]+)?"
    r")"
)
_STEP5_ENTRY_RE = re.compile(
    rf"(?P<emoji>{_STEP5_EMOJI_ALTERNATION})"
    r"[ \t]+"
    rf"(?P<url>{_STEP5_URL_PATTERN})"
    r"[ \t]+[-\u2013\u2014][ \t]+"
    rf"(?P<title>[^\r\n]+?)(?=[ \t]*(?:\r|\n|$|(?:{_STEP5_EMOJI_ALTERNATION})[ \t]+{_STEP5_URL_PATTERN}))",
)
_FENCE_OPEN_RE = re.compile(r"^[ \t]*(`{3,}|~{3,})(.*)$")
_THOUGHT_PREAMBLE_RE = re.compile(r"^\s*thought[ \t]*\r?\n")
_THOUGHT_MONOLOGUE_PARAGRAPH_RE = re.compile(
    r"^(?:thought\b|let(?:'s| us| me)\b|now\s+let(?:'s| us| me)\b|i(?:'ll| will| should| need to)\b|confirmed[!.:]|report\s+|output\s+|reply\s+)",
    re.IGNORECASE,
)
_EMBEDDED_EXPLICIT_ERROR_RE = re.compile(
    r"(?:^|\r?\n|[.!?:`'\"\)\]]\s*)(?P<err>`?(?:HEARTBEAT_ERROR|HEARTBEAT_FAILED|TURN_FAILED|COMPANION_RESULT:\s*(?:ERROR|FAILED))\b[^\r\n]*)",
    re.IGNORECASE,
)
_TRAILING_HEARTBEAT_OK_LINE_RE = re.compile(r"(?:\A|\r?\n)[ \t]*`?(?P<tok>HEARTBEAT_OK)`?[ \t]*\Z")
_TRAILING_HEARTBEAT_OK_CONCAT_RE = re.compile(r"(?:[.!?:`'\"\)\]])[ \t]*`?(?P<tok>HEARTBEAT_OK)`?[ \t]*\Z")
_TRAILING_HEARTBEAT_OK_WORD_RE = re.compile(r"(?:\A|\s)`?(?P<tok>HEARTBEAT_OK)`?[ \t]*\Z")


def _canonicalize_step5_emoji(raw_emoji: str) -> str:
    return _STEP5_EMOJI_BY_LEAD_CHAR.get(raw_emoji[0], raw_emoji) if raw_emoji else ""


def _find_code_spans(text: str) -> tuple[list[tuple[int, int]], list[tuple[int, int]]]:
    """Return (fenced_spans, all_code_spans) for fenced code blocks and inline backtick spans."""
    fenced_spans: list[tuple[int, int]] = []
    offset = 0
    fence_char = ""
    fence_len = 0
    fence_start = -1
    for line in text.splitlines(keepends=True):
        stripped_line = line.rstrip("\r\n")
        if fence_start < 0:
            if m := _FENCE_OPEN_RE.match(stripped_line):
                marker, rest = m.group(1), m.group(2)
                if marker[0] == "~" or "`" not in rest:
                    fence_char = marker[0]
                    fence_len = len(marker)
                    fence_start = offset
        else:
            close_stripped = stripped_line.strip()
            if close_stripped and len(close_stripped) >= fence_len and set(close_stripped) == {fence_char}:
                fenced_spans.append((fence_start, offset + len(line)))
                fence_start = -1
        offset += len(line)
    if fence_start >= 0:
        fenced_spans.append((fence_start, len(text)))

    all_spans: list[tuple[int, int]] = list(fenced_spans)
    non_fenced: list[tuple[int, int]] = []
    cursor = 0
    for f_start, f_end in fenced_spans:
        if cursor < f_start:
            non_fenced.append((cursor, f_start))
        cursor = max(cursor, f_end)
    if cursor < len(text):
        non_fenced.append((cursor, len(text)))

    for slice_start, slice_end in non_fenced:
        segment = text[slice_start:slice_end]
        pos = 0
        seg_len = len(segment)
        while pos < seg_len:
            tick_idx = segment.find("`", pos)
            if tick_idx < 0:
                break
            tick_end = tick_idx
            while tick_end < seg_len and segment[tick_end] == "`":
                tick_end += 1
            tick_len = tick_end - tick_idx
            blank_match = re.search(r"\r?\n[ \t]*\r?\n", segment[tick_end:])
            search_limit = (tick_end + blank_match.start()) if blank_match else seg_len
            scan = tick_end
            matched_end = -1
            while scan < search_limit:
                next_tick = segment.find("`", scan, search_limit)
                if next_tick < 0:
                    break
                run_end = next_tick
                while run_end < search_limit and segment[run_end] == "`":
                    run_end += 1
                if (run_end - next_tick) == tick_len:
                    matched_end = run_end
                    break
                scan = run_end
            if matched_end > 0:
                all_spans.append((slice_start + tick_idx, slice_start + matched_end))
                pos = matched_end
            else:
                pos = tick_end

    all_spans.sort()
    return fenced_spans, all_spans


def _offset_in_spans(offset: int, spans: list[tuple[int, int]]) -> bool:
    return any(start <= offset < end for start, end in spans)


def _has_trailing_heartbeat_ok(text: str, fenced_spans: list[tuple[int, int]], code_spans: list[tuple[int, int]]) -> bool:
    if m := _TRAILING_HEARTBEAT_OK_LINE_RE.search(text):
        if not _offset_in_spans(m.start("tok"), fenced_spans):
            return True
    if m := _TRAILING_HEARTBEAT_OK_CONCAT_RE.search(text):
        if not _offset_in_spans(m.start("tok"), code_spans):
            return True
    if _THOUGHT_PREAMBLE_RE.match(text):
        if m := _TRAILING_HEARTBEAT_OK_WORD_RE.search(text):
            if not _offset_in_spans(m.start("tok"), fenced_spans):
                return True
    return False


def _strip_thought_preamble(text: str) -> str:
    paragraphs = [p.strip() for p in re.split(r"\r?\n[ \t]*\r?\n+", text.strip()) if p.strip()]
    if len(paragraphs) <= 1:
        return ""
    remaining = paragraphs[1:]
    while remaining and _THOUGHT_MONOLOGUE_PARAGRAPH_RE.match(remaining[0]):
        remaining.pop(0)
    return "\n\n".join(remaining).strip()


def normalize_terminal_reply_text(text: str | None) -> str:
    """Normalise terminal replies to clean Step 5 status entries or HEARTBEAT_OK without leaked reasoning."""
    if not isinstance(text, str):
        return ""
    clean = text.strip()
    if not clean:
        return ""
    if is_heartbeat_ok_reply(clean):
        return "HEARTBEAT_OK"

    fenced_spans, code_spans = _find_code_spans(clean)
    dedup: dict[tuple[str, str], str] = {}
    for match in _STEP5_ENTRY_RE.finditer(clean):
        if _offset_in_spans(match.start(), code_spans):
            continue
        canonical_emoji = _canonicalize_step5_emoji(match.group("emoji"))
        url = match.group("url").strip()
        title = match.group("title").strip()
        if canonical_emoji and url and title:
            dedup[(canonical_emoji, url)] = f"{canonical_emoji} {url} - {title}"
    if dedup:
        return "\n\n".join(dedup.values())

    if any(pattern.search(clean) for _, pattern in TURN_FAILURE_PATTERNS):
        return clean
    if _THOUGHT_PREAMBLE_RE.match(clean):
        if err_match := _EMBEDDED_EXPLICIT_ERROR_RE.search(clean):
            if not _offset_in_spans(err_match.start("err"), code_spans):
                return clean[err_match.start("err"):].strip()

    if _has_trailing_heartbeat_ok(clean, fenced_spans, code_spans):
        return "HEARTBEAT_OK"

    if _THOUGHT_PREAMBLE_RE.match(clean):
        return _strip_thought_preamble(clean)

    return clean


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
    """Extract and normalise terminal assistant reply text from history.jsonl or chat.send_sync response."""
    raw_history = extract_text_content(assistant_record.get("content") if "content" in assistant_record else assistant_record).strip() if isinstance(assistant_record, dict) else ""
    raw_rpc = extract_rpc_reply_text(rpc_response)
    history_text = normalize_terminal_reply_text(raw_history)
    rpc_text = normalize_terminal_reply_text(raw_rpc)
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


def _poll_stagger_offset_minutes(agent_name: str, interval_minutes: int) -> int:
    norm_agent = normalize_agent_name(agent_name) if (agent_name or "").strip().lower() in AGENT_ORDER else "skrye"
    if norm_agent == "traya":
        return interval_minutes // 3
    if norm_agent == "zannah":
        return (2 * interval_minutes) // 3
    return 0


def compute_next_poll_slot_ms(now_ms_val: int, agent_name: str = "skrye", poll_interval_minutes: int | None = None) -> int:
    norm_agent = normalize_agent_name(agent_name) if (agent_name or "").strip().lower() in AGENT_ORDER else "skrye"
    interval_min = resolve_poll_interval_minutes(poll_interval_minutes)
    interval_ms = interval_min * 60 * 1000
    offset_ms = _poll_stagger_offset_minutes(norm_agent, interval_min) * 60 * 1000
    safe_now = max(0, _safe_int(now_ms_val, 0))
    dt = datetime.datetime.fromtimestamp(safe_now / 1000.0, tz=datetime.timezone.utc)
    midnight_dt = dt.replace(hour=0, minute=0, second=0, microsecond=0)
    midnight_ms = math.trunc(midnight_dt.timestamp() * 1000)
    next_midnight_ms = midnight_ms + (24 * 60 * 60 * 1000)
    elapsed_ms = safe_now - midnight_ms
    slot_index = ((elapsed_ms - offset_ms) // interval_ms) + 1
    cand_ms = midnight_ms + (slot_index * interval_ms) + offset_ms
    if cand_ms >= next_midnight_ms:
        return next_midnight_ms + offset_ms
    return cand_ms


def compute_throttle_slot_id(now_ms_val: int, agent_name: str = "skrye", poll_interval_minutes: int | None = None) -> str:
    """Return a deterministic throttle slot identifier aligned to the agent's poll slot."""
    norm_agent = normalize_agent_name(agent_name) if (agent_name or "").strip().lower() in AGENT_ORDER else "skrye"
    return f"{norm_agent}:{compute_next_poll_slot_ms(now_ms_val, norm_agent, poll_interval_minutes=poll_interval_minutes)}"


def compute_backoff_wait_ms(headers: dict[str, str] | None, now_ms_val: int, rng: Callable[[int, int], int] | None = None, status: int | None = None, agent_name: str = "skrye", poll_interval_minutes: int | None = None) -> tuple[int, int, int]:
    """Return (total_wait_ms, base_wait_secs, jitter_ms) aligned to the agent's wall-clock poll slot."""
    _ = rng
    lower_headers = {k.strip().lower(): str(v).strip() for k, v in (headers or {}).items() if isinstance(k, str) and v is not None}
    now_sec = max(0, now_ms_val // 1000)
    poll_interval_sec = max(0, _safe_int(lower_headers.get("x-poll-interval"), 0))
    retry_after_sec = parse_retry_after_seconds(lower_headers.get("retry-after"), now_sec)
    remaining_raw = lower_headers.get("x-ratelimit-remaining")
    remaining_exhausted = remaining_raw is not None and remaining_raw != "" and _safe_int(remaining_raw, 1) <= 0
    is_rate_limited = status in (403, 429) or remaining_exhausted or retry_after_sec > 0
    reset_epoch = _safe_int(lower_headers.get("x-ratelimit-reset"), 0) if is_rate_limited else 0
    rate_reset_wait_sec = max(0, reset_epoch - now_sec) if reset_epoch > 0 else 0
    slot_wait_ms = max(1_000, compute_next_poll_slot_ms(now_ms_val, agent_name, poll_interval_minutes=poll_interval_minutes) - now_ms_val)
    header_wait_ms = max(poll_interval_sec, retry_after_sec, rate_reset_wait_sec) * 1000
    total_wait_ms = max(slot_wait_ms, header_wait_ms)
    return total_wait_ms, total_wait_ms // 1000, 0


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


def has_action_required_ci(rollup: object) -> bool:
    """Return True when statusCheckRollup reports an ACTION_REQUIRED check waiting for workflow approval."""
    if rollup is None:
        return False
    if isinstance(rollup, str):
        return rollup.strip().upper() == "ACTION_REQUIRED"
    if isinstance(rollup, dict):
        contexts = rollup.get("contexts")
        nodes = contexts.get("nodes") if isinstance(contexts, dict) and isinstance(contexts.get("nodes"), list) else (contexts if isinstance(contexts, list) else rollup.get("nodes"))
        if isinstance(nodes, list) and any(has_action_required_ci(node) for node in nodes):
            return True
        for key in ("state", "status", "conclusion"):
            if str(rollup.get(key) or "").strip().upper() == "ACTION_REQUIRED":
                return True
        return False
    if isinstance(rollup, list):
        return any(has_action_required_ci(item) for item in rollup)
    return False


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
    if (
        not isinstance(raw, dict)
        or "subject" in raw
        or _is_archived_record(raw)
        or str(raw.get("__typename") or "").strip().lower() == "issue"
        or not any(k in raw for k in ("headRefOid", "head", "head_sha", "reviewDecision", "statusCheckRollup", "reviewRequests", "reviewThreads", "isDraft"))
    ):
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
    head_ref = str(raw.get("headRefName") or _as_dict(raw.get("head")).get("ref") or raw.get("head_ref") or "").strip()
    author_association = str(raw.get("authorAssociation") or raw.get("author_association") or "").strip().upper()
    mergeable_raw = raw.get("mergeable")
    merge_state_status = str(raw.get("mergeStateStatus") or raw.get("merge_state_status") or "").strip().upper()
    mergeable = normalize_mergeable_state(mergeable_raw, merge_state_status)
    review_decision = str(raw.get("reviewDecision") or raw.get("review_decision") or "").strip().upper()
    ci_raw = raw.get("statusCheckRollup") if "statusCheckRollup" in raw else raw.get("ci_state")
    updated_at = str(raw.get("updatedAt") or raw.get("updated_at") or "").strip()
    review_requests = extract_review_request_logins(raw.get("reviewRequests") if "reviewRequests" in raw else raw.get("requested_reviewers"))
    review_threads = raw.get("reviewThreads") if "reviewThreads" in raw else raw.get("review_threads")
    unresolved_thread_count = max(0, _safe_int(raw.get("unresolved_thread_count"), 0)) if "unresolved_thread_count" in raw else count_unresolved_review_threads(review_threads)
    labels = extract_label_names(raw.get("labels"))
    team_labels = extract_team_labels(raw.get("team_labels") if "team_labels" in raw else labels, PR_TEAM_LABELS)
    raw_add = raw.get("additions")
    raw_del = raw.get("deletions")
    raw_chg = raw.get("changedFiles") if "changedFiles" in raw else raw.get("changed_files")
    additions = _safe_int(raw_add, -1) if raw_add is not None and not isinstance(raw_add, bool) else None
    deletions = _safe_int(raw_del, -1) if raw_del is not None and not isinstance(raw_del, bool) else None
    changed_files = _safe_int(raw_chg, -1) if raw_chg is not None and not isinstance(raw_chg, bool) else None
    file_paths, files_has_next_page = extract_pr_file_paths(raw.get("files") if "files" in raw else raw.get("file_paths"))
    if "files_has_next_page" in raw:
        files_has_next_page = bool(raw.get("files_has_next_page"))
    closing_issues = extract_pr_closing_issues(raw, default_repo=repo_full_name)
    return {
        "pr_key": make_pr_key(repo_full_name, number),
        "id": raw.get("databaseId") or raw.get("id") or number,
        "node_id": str(raw.get("node_id") or (raw.get("id") if isinstance(raw.get("id"), str) else "")).strip(),
        "repo": repo_full_name,
        "owner": repo_full_name.split("/", 1)[0].lower(),
        "number": number,
        "author": extract_actor_login(raw.get("author") or raw.get("user")),
        "author_association": author_association,
        "authorAssociation": author_association,
        "mergeable": mergeable,
        "merge_state_status": merge_state_status,
        "mergeStateStatus": merge_state_status,
        "has_merge_conflicts": mergeable == "CONFLICTING",
        "head_sha": head_sha,
        "headRefOid": head_sha,
        "head_ref": head_ref,
        "review_decision": review_decision,
        "reviewDecision": review_decision,
        "ci_state": normalize_ci_state(ci_raw),
        "statusCheckRollup": ci_raw,
        "updated_at": updated_at,
        "updatedAt": updated_at,
        "review_requests": review_requests,
        "reviewRequests": review_requests,
        "review_threads": review_threads,
        "reviewThreads": review_threads,
        "unresolved_thread_count": unresolved_thread_count,
        "labels": labels,
        "team_labels": team_labels,
        "additions": additions,
        "deletions": deletions,
        "changed_files": changed_files,
        "file_paths": file_paths,
        "files_has_next_page": files_has_next_page,
        "closing_issues": closing_issues,
        "is_draft": bool(raw.get("isDraft") or raw.get("draft", False)),
        "state": str(raw.get("state") or "OPEN").strip().upper(),
        "title": str(raw.get("title") or "").strip(),
        "body": str(raw.get("body") or "").strip(),
        "url": str(raw.get("url") or raw.get("html_url") or "").strip(),
    }


def normalize_open_issue_record(raw: dict) -> dict | None:
    if (
        not isinstance(raw, dict)
        or "subject" in raw
        or _is_archived_record(raw)
        or str(raw.get("__typename") or "").strip().lower() == "pullrequest"
        or "pull_request" in raw
        or any(k in raw for k in ("headRefOid", "head", "head_sha", "reviewDecision", "statusCheckRollup", "reviewRequests", "reviewThreads", "isDraft", "draft"))
    ):
        return None
    url_text = str(raw.get("url") or raw.get("html_url") or "").strip()
    if "/pull/" in url_text.lower():
        return None
    number = _safe_int(raw.get("number"), 0)
    if number <= 0:
        return None
    repo_val = raw.get("repository")
    repo_full_name = str(repo_val.get("nameWithOwner") or repo_val.get("full_name") or "").strip() if isinstance(repo_val, dict) else (repo_val.strip() if isinstance(repo_val, str) else str(raw.get("repo") or "").strip())
    if not repo_full_name and (m := re.search(r"github\.com/([^/]+/[^/]+)/issues/", url_text, re.IGNORECASE)):
        repo_full_name = m.group(1)
    if not is_allowed_notification_repo(repo_full_name):
        return None
    updated_at = str(raw.get("updatedAt") or raw.get("updated_at") or "").strip()
    labels = extract_label_names(raw.get("labels"))
    team_labels = extract_team_labels(raw.get("team_labels") if "team_labels" in raw else labels, ISSUE_TEAM_LABELS)
    latest_comment: dict | None = None
    raw_comments = raw.get("comments")
    if isinstance(raw_comments, dict):
        c_nodes = raw_comments.get("nodes")
        if isinstance(c_nodes, list) and c_nodes and isinstance(c_nodes[-1], dict):
            latest_comment = dict(c_nodes[-1])
    elif isinstance(raw_comments, list) and raw_comments and isinstance(raw_comments[-1], dict):
        latest_comment = dict(raw_comments[-1])
    elif isinstance(raw.get("latest_comment"), dict):
        latest_comment = dict(_as_dict(raw.get("latest_comment")))
    return {
        "issue_key": make_pr_key(repo_full_name, number),
        "id": raw.get("databaseId") or raw.get("id") or number,
        "repo": repo_full_name,
        "owner": repo_full_name.split("/", 1)[0].lower(),
        "number": number,
        "author": extract_actor_login(raw.get("author") or raw.get("user")),
        "updated_at": updated_at,
        "updatedAt": updated_at,
        "labels": labels,
        "team_labels": team_labels,
        "latest_comment": latest_comment,
        "state": str(raw.get("state") or "OPEN").strip().upper(),
        "title": str(raw.get("title") or "").strip(),
        "body": str(raw.get("body") or "").strip(),
        "url": url_text,
    }


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


def _extract_thread_repo_number(key: str, entry: dict) -> tuple[str, int] | None:
    repo = str(entry.get("repo") or "").strip().lower()
    number = _safe_int(entry.get("number"), 0)
    if (not repo or number <= 0) and "#" in key:
        head, tail = key.rsplit("#", 1)
        if not repo and "/" in head:
            repo = head.strip().lower()
        if number <= 0:
            number = _safe_int(tail, 0)
    return (repo, number) if (repo and number > 0) else None


def _reset_community_entries_in_state(state: dict, stamp_ms: int) -> int:
    """Reset watermarks and tracking fields only on community or coercion-blocked threads (and paired keys)."""
    threads = state.get("threads")
    if not isinstance(threads, dict):
        return 0
    target_keys: set[str] = set()
    target_pairs: set[tuple[str, int]] = set()
    target_thread_ids: set[str] = set()
    for key, entry in threads.items():
        if not isinstance(entry, dict):
            continue
        if bool(entry.get("is_community")) or bool(entry.get("coercion_blocked")):
            target_keys.add(key)
            if pair := _extract_thread_repo_number(key, entry):
                target_pairs.add(pair)
            if tid := str(entry.get("thread_id") or "").strip():
                target_thread_ids.add(tid)
    if not target_keys:
        return 0
    for key, entry in threads.items():
        if not isinstance(entry, dict) or key in target_keys:
            continue
        pair = _extract_thread_repo_number(key, entry)
        tid = str(entry.get("thread_id") or "").strip()
        if (pair is not None and pair in target_pairs) or key in target_thread_ids or (tid and tid in target_thread_ids):
            target_keys.add(key)
    reset_count = 0
    for key in target_keys:
        entry = threads.get(key)
        if not isinstance(entry, dict):
            continue
        entry.update({
            "handled_updated_at": None,
            "handled_head_sha": None,
            "triaged_head_sha": None,
            "coercion_blocked": False,
            "in_flight": False,
            "pending_followup": False,
            "retry_count": 0,
            "linear_issue_id": None,
            "linear_issue_url": None,
            "decision_notified_sha": None,
            "ready_for_signoff_notified_sha": None,
            "updated_at_ms": stamp_ms,
        })
        reset_count += 1
    return reset_count


class CompanionStateStore:
    """Durable 0600 unified state store (state.json) in ~/.local/state/moltis/github-companion-<agent>/."""

    def __init__(
        self,
        state_dir: Path | str,
        agent_name: str,
        room_id: str = DEFAULT_ROOM_ID,
        started_at_ms: int | None = None,
        followup_cooldown_ms: int = PR_REVIEW_COOLDOWN_MS,
        community_auto_merge_enabled: bool | str | None = None,
        community_auto_merge_max_lines: int | str | None = None,
        community_auto_merge_max_files: int | str | None = None,
        community_auto_merge_excluded_repos: Iterable[str] | str | None = None,
        max_tasks_per_slot: int | str | None = None,
        max_tasks_per_day: int | str | None = None,
        daily_implementations_cap: int | str | None = None,
    ):
        self.state_dir = Path(state_dir)
        self.agent_name = normalize_agent_name(agent_name)
        self.room_id = room_id
        self.started_at_ms = _safe_int(started_at_ms, now_ms()) if started_at_ms is not None else now_ms()
        self.followup_cooldown_ms = max(0, _safe_int(followup_cooldown_ms, PR_REVIEW_COOLDOWN_MS))
        self._max_tasks_per_slot = max_tasks_per_slot
        self._max_tasks_per_day = max_tasks_per_day
        self._daily_implementations_cap = daily_implementations_cap
        cam_cfg = resolve_community_auto_merge_config(
            enabled=community_auto_merge_enabled,
            max_lines=community_auto_merge_max_lines,
            max_files=community_auto_merge_max_files,
            excluded_repos=community_auto_merge_excluded_repos,
        )
        self.community_auto_merge_enabled = bool(cam_cfg["enabled"])
        self.community_auto_merge_max_lines = _safe_int(cam_cfg["max_lines"], DEFAULT_COMMUNITY_AUTO_MERGE_MAX_LINES)
        self.community_auto_merge_max_files = _safe_int(cam_cfg["max_files"], DEFAULT_COMMUNITY_AUTO_MERGE_MAX_FILES)
        self.community_auto_merge_excluded_repos = parse_repo_list(cam_cfg["excluded_repos"], default=())
        self.ensure_directory()

    def _default_thread_entry(self, *, handled_updated_at: str | None = None, handled_head_sha: str | None = None, handled_ci_state: str | None = None, retry_count: int = 0) -> dict:
        return {
            "handled_updated_at": handled_updated_at,
            "handled_head_sha": handled_head_sha,
            "handled_ci_state": handled_ci_state,
            "retry_count": max(0, _safe_int(retry_count, 0)),
            "linear_issue_id": None,
            "linear_issue_url": None,
            "decision_notified_sha": None,
            "ready_for_signoff_notified_sha": None,
            "traya_review_requested_sha": None,
            "handled_linear_comment_ids": [],
            "linked_linear_issue_ids": [],
            "paused_by_open_pr_url": None,
        }

    @staticmethod
    def _normalize_handled_linear_comment_ids(raw: object) -> list[str]:
        if not isinstance(raw, list):
            return []
        deduped: list[str] = []
        seen: set[str] = set()
        for item in raw:
            clean = str(item or "").strip()
            if clean and clean not in seen:
                seen.add(clean)
                deduped.append(clean)
        if len(deduped) > MAX_HANDLED_LINEAR_COMMENT_IDS:
            return deduped[-MAX_HANDLED_LINEAR_COMMENT_IDS:]
        return deduped

    @staticmethod
    def _default_throttles() -> dict:
        return {
            "daily_date": None,
            "daily_tasks": 0,
            "daily_implementations": 0,
            "slot_id": None,
            "slot_tasks": 0,
            "slot_triage_stubs": 0,
            "slot_triage_research": 0,
            "slot_community_pr_reviews": 0,
            "slot_todo_implementations": 0,
        }

    @classmethod
    def _normalize_throttles(cls, raw: object) -> dict:
        data = _as_dict(raw)
        daily_date_raw = data.get("daily_date")
        slot_id_raw = data.get("slot_id")
        return {
            "daily_date": daily_date_raw.strip() if isinstance(daily_date_raw, str) and daily_date_raw.strip() else None,
            "daily_tasks": max(0, _safe_int(data.get("daily_tasks"), 0)),
            "daily_implementations": max(0, _safe_int(data.get("daily_implementations"), 0)),
            "slot_id": slot_id_raw.strip() if isinstance(slot_id_raw, str) and slot_id_raw.strip() else None,
            "slot_tasks": max(0, _safe_int(data.get("slot_tasks"), 0)),
            "slot_triage_stubs": max(0, _safe_int(data.get("slot_triage_stubs"), 0)),
            "slot_triage_research": max(0, _safe_int(data.get("slot_triage_research"), 0)),
            "slot_community_pr_reviews": max(0, _safe_int(data.get("slot_community_pr_reviews"), 0)),
            "slot_todo_implementations": max(0, _safe_int(data.get("slot_todo_implementations"), 0)),
        }

    @classmethod
    def _rollover_throttles(cls, raw_throttles: object, *, stamp_ms: int, slot_id: str | None = None) -> dict:
        throttles = cls._normalize_throttles(raw_throttles)
        today_london = london_date_str(stamp_ms)
        if throttles["daily_date"] != today_london:
            throttles["daily_date"] = today_london
            throttles["daily_tasks"] = 0
            throttles["daily_implementations"] = 0
        clean_slot_id = slot_id.strip() if isinstance(slot_id, str) and slot_id.strip() else None
        if clean_slot_id is not None and throttles["slot_id"] != clean_slot_id:
            throttles["slot_id"] = clean_slot_id
            throttles["slot_tasks"] = 0
            throttles["slot_triage_stubs"] = 0
            throttles["slot_triage_research"] = 0
            throttles["slot_community_pr_reviews"] = 0
            throttles["slot_todo_implementations"] = 0
        return throttles

    @staticmethod
    def _validate_throttle_bucket(bucket: str) -> tuple[str, str]:
        clean = bucket.strip() if isinstance(bucket, str) else ""
        if clean not in _THROTTLE_BUCKET_TO_STATE_KEY:
            raise ValueError(f"Unsupported throttle bucket: {bucket!r}")
        return clean, _THROTTLE_BUCKET_TO_STATE_KEY[clean]

    @staticmethod
    def _resolve_throttle_limits(
        limits: dict | None = None,
        *,
        agent_name: str | None = None,
        max_tasks_per_slot: int | str | None = None,
        max_tasks_per_day: int | str | None = None,
        daily_implementations_cap: int | str | None = None,
    ) -> dict[str, int]:
        eff_slot = resolve_max_tasks_per_slot(max_tasks_per_slot, agent_name=agent_name)
        eff_day = resolve_max_tasks_per_day(max_tasks_per_day)
        eff_daily_impl = resolve_daily_implementations_cap(daily_implementations_cap, agent_name=agent_name)
        resolved: dict[str, int] = {
            "max_tasks_per_slot": eff_slot,
            "max_tasks_per_day": eff_day,
            "tasks": eff_slot,
            "triage_stubs": DEFAULT_SLOT_TRIAGE_STUBS_CAP,
            "triage_research": eff_slot,
            "community_pr_reviews": eff_slot,
            "todo_implementations": eff_slot,
            "daily_implementations": eff_daily_impl,
        }
        if isinstance(limits, dict):
            for key in (
                "max_tasks_per_slot",
                "max_tasks_per_day",
                "daily_implementations",
                "triage_stubs",
                "tasks",
                "triage_research",
                "community_pr_reviews",
                "todo_implementations",
            ):
                if key in limits and limits[key] is not None and not isinstance(limits[key], bool):
                    resolved[key] = max(0, _safe_int(limits[key], resolved[key]))
            if "max_tasks_per_slot" in limits and limits["max_tasks_per_slot"] is not None and not isinstance(limits["max_tasks_per_slot"], bool):
                for cat_key in ("tasks", "triage_research", "community_pr_reviews", "todo_implementations"):
                    if cat_key not in limits or limits[cat_key] is None or isinstance(limits[cat_key], bool):
                        resolved[cat_key] = resolved["max_tasks_per_slot"]
        return resolved

    @staticmethod
    def _normalize_pending_linear_todo_reconciliations(raw: object) -> dict[str, dict[str, object]]:
        normalized: dict[str, dict[str, object]] = {}
        if not isinstance(raw, dict):
            return normalized
        for raw_key, raw_entry in raw.items():
            clean_id = str(raw_key or "").strip()
            if not clean_id or not isinstance(raw_entry, dict):
                continue
            thread_key = str(raw_entry.get("thread_key") or raw_entry.get("state_key") or "").strip() or None
            dispatch_id = str(raw_entry.get("dispatch_id") or "").strip() or None
            reason = str(raw_entry.get("reason") or "").strip() or None
            enqueued_at_ms = _safe_int(raw_entry.get("enqueued_at_ms"), 0) or None
            updated_at_ms = _safe_int(raw_entry.get("updated_at_ms"), 0) or None
            normalized[clean_id] = {
                "linear_issue_id": clean_id,
                "thread_key": thread_key,
                "dispatch_id": dispatch_id,
                "reason": reason,
                "enqueued_at_ms": enqueued_at_ms,
                "updated_at_ms": updated_at_ms,
            }
        return normalized

    @staticmethod
    def _default_health() -> dict:
        return {
            "consecutive_poll_failures": 0,
            "last_health_alerts": {},
            "notified_dead_letter_keys": {},
        }

    @classmethod
    def _normalize_health(cls, raw: object) -> dict:
        data = _as_dict(raw)
        raw_alerts = _as_dict(data.get("last_health_alerts"))
        last_alerts: dict[str, int] = {}
        for k, v in raw_alerts.items():
            clean_k = str(k or "").strip()
            ts_ms = _safe_int(v, 0)
            if clean_k and ts_ms > 0:
                last_alerts[clean_k] = ts_ms
        raw_dl = _as_dict(data.get("notified_dead_letter_keys"))
        notified_dl: dict[str, str] = {}
        for k, v in raw_dl.items():
            clean_k = str(k or "").strip()
            clean_v = str(v or "").strip()
            if clean_k and clean_v:
                notified_dl[clean_k] = clean_v
        return {
            "consecutive_poll_failures": max(0, _safe_int(data.get("consecutive_poll_failures"), 0)),
            "last_health_alerts": last_alerts,
            "notified_dead_letter_keys": notified_dl,
        }

    @staticmethod
    def _default_digest() -> dict:
        return {"last_digest_date": None}

    @classmethod
    def _normalize_digest(cls, raw: object) -> dict:
        data = _as_dict(raw)
        raw_date = data.get("last_digest_date")
        return {
            "last_digest_date": raw_date.strip() if isinstance(raw_date, str) and raw_date.strip() else None,
        }

    @staticmethod
    def _default_security_releases() -> dict:
        return {
            "last_checked_at_ms": {},
            "notified_releases": {},
            "pending_releases": {},
            "completed_releases": {},
            "haberdasher_sources": [],
            "haberdasher_sources_fetched_at_ms": 0,
        }

    @classmethod
    def _normalize_security_releases(cls, raw: object) -> dict:
        data = _as_dict(raw)
        raw_checked = _as_dict(data.get("last_checked_at_ms"))
        last_checked: dict[str, int] = {}
        for k, v in raw_checked.items():
            clean_k = str(k or "").strip().lower()
            ts_ms = _safe_int(v, 0)
            if clean_k and ts_ms > 0:
                last_checked[clean_k] = ts_ms
        raw_notified = _as_dict(data.get("notified_releases"))
        notified: dict[str, dict[str, object]] = {}
        for k, v in raw_notified.items():
            clean_k = str(k or "").strip().lower()
            if clean_k and isinstance(v, dict):
                notified[clean_k] = dict(v)
        raw_pending = _as_dict(data.get("pending_releases"))
        pending_releases: dict[str, dict[str, object]] = {}
        for k, v in raw_pending.items():
            clean_k = str(k or "").strip().lower()
            if clean_k and isinstance(v, dict):
                pending_releases[clean_k] = dict(v)
        raw_completed = _as_dict(data.get("completed_releases"))
        completed_releases: dict[str, str] = {}
        for k, v in raw_completed.items():
            clean_k = str(k or "").strip().lower()
            clean_v = str(v or "").strip()
            if clean_k and clean_v:
                completed_releases[clean_k] = clean_v
        raw_sources = data.get("haberdasher_sources")
        haberdasher_sources: list[str] = []
        if isinstance(raw_sources, list):
            for entry in raw_sources:
                norm = _normalize_valid_haberdasher_repo(entry)
                if norm and norm not in haberdasher_sources:
                    haberdasher_sources.append(norm)
        fetched_at_ms = max(0, _safe_int(data.get("haberdasher_sources_fetched_at_ms"), 0))
        return {
            "last_checked_at_ms": last_checked,
            "notified_releases": notified,
            "pending_releases": pending_releases,
            "completed_releases": completed_releases,
            "haberdasher_sources": haberdasher_sources,
            "haberdasher_sources_fetched_at_ms": fetched_at_ms,
        }

    def _default_state(self) -> dict:
        return {"version": STATE_SCHEMA_VERSION, "agent_name": self.agent_name, "next_poll_at_ms": None, "last_poll_started_at_ms": None, "last_poll_completed_at_ms": None, "last_status": None, "last_modified": None, "poll_interval_secs": 0, "retry_after_secs": 0, "last_poll_rate_limited": False, "ratelimit_reset_epoch": None, "last_jitter_ms": None, "last_open_prs_poll_error": None, "last_open_issues_poll_error": None, "last_reconcile_sweep_at_ms": None, "last_reconcile_sweep_attempt_at_ms": None, "reconcile_sweep_retry_after_ms": None, "reconcile_sweep_failure_count": 0, "last_reconcile_sweep_failure_reason": None, "last_weekly_sweep_date": None, "last_weekly_sweep_attempt_at_ms": None, "weekly_sweep_retry_after_ms": None, "weekly_sweep_failure_count": 0, "last_weekly_sweep_failure_reason": None, "throttles": self._default_throttles(), "health": self._default_health(), "digest": self._default_digest(), "security_releases": self._default_security_releases(), "pending_linear_todo_reconciliations": {}, "threads": {}, "updated_at_ms": self.started_at_ms}

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
            elif _safe_int(existing_state.get("version"), 1) < STATE_SCHEMA_VERSION:
                migrated = self._read_state_unlocked(dir_fd)
                _reset_community_entries_in_state(migrated, self.started_at_ms)
                migrated["version"] = STATE_SCHEMA_VERSION
                migrated["throttles"] = self._normalize_throttles(migrated.get("throttles"))
                migrated["updated_at_ms"] = self.started_at_ms
                atomic_write_json_in_dir(dir_fd, STATE_FILENAME, migrated)
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
        for str_key in ("last_weekly_sweep_date", "last_reconcile_sweep_failure_reason", "last_weekly_sweep_failure_reason", "last_open_prs_poll_error", "last_open_issues_poll_error"):
            raw = state.get(str_key)
            state[str_key] = raw.strip() if isinstance(raw, str) and raw.strip() else None

    def _read_state_unlocked(self, dir_fd: int) -> dict:
        default = self._default_state()
        data = self._try_read_json(dir_fd, STATE_FILENAME)
        if not data:
            return default
        merged = {**default, **{k: v for k, v in data.items() if k not in ("poll_offset_secs", "initial_offset_applied")}, "agent_name": self.agent_name}
        self._normalize_sweep_fields(merged)
        merged["throttles"] = self._normalize_throttles(merged.get("throttles"))
        merged["health"] = self._normalize_health(merged.get("health"))
        merged["digest"] = self._normalize_digest(merged.get("digest"))
        merged["security_releases"] = self._normalize_security_releases(merged.get("security_releases"))
        merged["pending_linear_todo_reconciliations"] = self._normalize_pending_linear_todo_reconciliations(
            merged.get("pending_linear_todo_reconciliations")
        )
        raw_threads = merged.get("threads")
        norm_threads: dict[str, dict] = {}
        if isinstance(raw_threads, dict):
            for k, v in raw_threads.items():
                if isinstance(v, dict):
                    entry = {**self._default_thread_entry(), **v}
                    entry["retry_count"] = max(0, _safe_int(entry.get("retry_count"), 0))
                    entry["handled_linear_comment_ids"] = self._normalize_handled_linear_comment_ids(entry.get("handled_linear_comment_ids"))
                    norm_threads[str(k)] = entry
        merged["threads"] = norm_threads
        return merged

    def read_state(self) -> dict:
        with self._locked_dir() as dir_fd:
            return self._read_state_unlocked(dir_fd)

    def write_state(self, updates: dict, now_override_ms: int | None = None) -> dict:
        stamp_ms = _safe_int(now_override_ms, now_ms()) if now_override_ms is not None else now_ms()
        nested_keys = ("threads", "throttles", "health", "digest", "security_releases")
        with self._locked_dir() as dir_fd:
            state = self._read_state_unlocked(dir_fd)
            if "threads" in updates and isinstance(updates["threads"], dict):
                merged_threads = dict(state.get("threads") or {})
                for k, v in updates["threads"].items():
                    if isinstance(v, dict):
                        entry = {**self._default_thread_entry(), **_as_dict(merged_threads.get(str(k))), **v}
                        entry["retry_count"] = max(0, _safe_int(entry.get("retry_count"), 0))
                        entry["handled_linear_comment_ids"] = self._normalize_handled_linear_comment_ids(entry.get("handled_linear_comment_ids"))
                        merged_threads[str(k)] = entry
                state.update({k: v for k, v in updates.items() if k not in nested_keys})
                state["threads"] = merged_threads
            else:
                state.update({k: v for k, v in updates.items() if k not in nested_keys})
            if "throttles" in updates and isinstance(updates["throttles"], dict):
                state["throttles"] = self._normalize_throttles({**self._normalize_throttles(state.get("throttles")), **updates["throttles"]})
            else:
                state["throttles"] = self._normalize_throttles(state.get("throttles"))
            if "health" in updates and isinstance(updates["health"], dict):
                state["health"] = self._normalize_health({**self._normalize_health(state.get("health")), **updates["health"]})
            else:
                state["health"] = self._normalize_health(state.get("health"))
            if "digest" in updates and isinstance(updates["digest"], dict):
                state["digest"] = self._normalize_digest({**self._normalize_digest(state.get("digest")), **updates["digest"]})
            else:
                state["digest"] = self._normalize_digest(state.get("digest"))
            if "security_releases" in updates and isinstance(updates["security_releases"], dict):
                state["security_releases"] = self._normalize_security_releases(
                    {**self._normalize_security_releases(state.get("security_releases")), **updates["security_releases"]}
                )
            else:
                state["security_releases"] = self._normalize_security_releases(state.get("security_releases"))
            state["pending_linear_todo_reconciliations"] = self._normalize_pending_linear_todo_reconciliations(
                state.get("pending_linear_todo_reconciliations")
            )
            self._normalize_sweep_fields(state)
            state.update({"agent_name": self.agent_name, "updated_at_ms": stamp_ms})
            atomic_write_json_in_dir(dir_fd, STATE_FILENAME, state)
            return dict(state)

    def enqueue_linear_todo_reconciliation(
        self,
        linear_id: str,
        thread_key: str | None = None,
        *,
        dispatch_id: str | None = None,
        reason: str | None = None,
        now_override_ms: int | None = None,
    ) -> dict[str, object] | None:
        """Persist a stranded Linear Todo claim in state.json for non-blocking reconciliation."""
        clean_id = str(linear_id or "").strip()
        if not clean_id:
            return None
        stamp_ms = _safe_int(now_override_ms, now_ms()) if now_override_ms is not None else now_ms()
        with self._locked_dir() as dir_fd:
            state = self._read_state_unlocked(dir_fd)
            pending = dict(state.get("pending_linear_todo_reconciliations") or {})
            existing = _as_dict(pending.get(clean_id))
            entry: dict[str, object] = {
                "linear_issue_id": clean_id,
                "thread_key": str(thread_key or existing.get("thread_key") or "").strip() or None,
                "dispatch_id": str(dispatch_id or existing.get("dispatch_id") or "").strip() or None,
                "reason": str(reason or existing.get("reason") or "").strip() or None,
                "enqueued_at_ms": _safe_int(existing.get("enqueued_at_ms"), 0) or stamp_ms,
                "updated_at_ms": stamp_ms,
            }
            pending[clean_id] = entry
            state["pending_linear_todo_reconciliations"] = pending
            state["agent_name"] = self.agent_name
            state["updated_at_ms"] = stamp_ms
            atomic_write_json_in_dir(dir_fd, STATE_FILENAME, state)
            return dict(entry)

    def list_linear_todo_reconciliations(self) -> dict[str, dict[str, object]]:
        """Return a copy of all pending Linear Todo reconciliations keyed by linear_id."""
        pending = self.read_state().get("pending_linear_todo_reconciliations")
        if not isinstance(pending, dict):
            return {}
        return {str(k): dict(v) for k, v in pending.items() if isinstance(v, dict)}

    def remove_linear_todo_reconciliation(self, linear_id: str, *, now_override_ms: int | None = None) -> bool:
        """Atomically remove a reconciled Linear Todo claim from state.json."""
        clean_id = str(linear_id or "").strip()
        if not clean_id:
            return False
        stamp_ms = _safe_int(now_override_ms, now_ms()) if now_override_ms is not None else now_ms()
        with self._locked_dir() as dir_fd:
            state = self._read_state_unlocked(dir_fd)
            pending = dict(state.get("pending_linear_todo_reconciliations") or {})
            if clean_id not in pending:
                return False
            pending.pop(clean_id, None)
            state["pending_linear_todo_reconciliations"] = pending
            state["agent_name"] = self.agent_name
            state["updated_at_ms"] = stamp_ms
            atomic_write_json_in_dir(dir_fd, STATE_FILENAME, state)
            return True

    def reprocess_community_entries(self, now_override_ms: int | None = None) -> int:
        stamp_ms = _safe_int(now_override_ms, now_ms()) if now_override_ms is not None else now_ms()
        with self._locked_dir() as dir_fd:
            state = self._read_state_unlocked(dir_fd)
            reset_count = _reset_community_entries_in_state(state, stamp_ms)
            state["version"] = max(_safe_int(state.get("version"), STATE_SCHEMA_VERSION), STATE_SCHEMA_VERSION)
            state["throttles"] = self._normalize_throttles(state.get("throttles"))
            state["agent_name"] = self.agent_name
            state["updated_at_ms"] = stamp_ms
            atomic_write_json_in_dir(dir_fd, STATE_FILENAME, state)
            return reset_count

    def get_throttle_state(self, *, slot_id: str | None = None, now_override_ms: int | None = None) -> dict:
        stamp_ms = _safe_int(now_override_ms, now_ms()) if now_override_ms is not None else now_ms()
        with self._locked_dir() as dir_fd:
            state = self._read_state_unlocked(dir_fd)
            return self._rollover_throttles(state.get("throttles"), stamp_ms=stamp_ms, slot_id=slot_id)

    def _can_consume_throttle_locked(self, throttles: dict, clean_bucket: str, state_key: str, *, step: int, eff_limits: dict[str, int], explicit_limits: dict | None) -> bool:
        if clean_bucket in _LLM_THROTTLE_BUCKETS:
            if throttles["slot_tasks"] + step > eff_limits["max_tasks_per_slot"]:
                return False
            if throttles["daily_tasks"] + step > eff_limits["max_tasks_per_day"]:
                return False
            if (
                isinstance(explicit_limits, dict)
                and clean_bucket in explicit_limits
                and explicit_limits[clean_bucket] is not None
                and not isinstance(explicit_limits[clean_bucket], bool)
                and throttles[state_key] + step > eff_limits[clean_bucket]
            ):
                return False
            if clean_bucket == "todo_implementations" and throttles["daily_implementations"] + step > eff_limits["daily_implementations"]:
                return False
            return True
        return throttles[state_key] + step <= eff_limits[clean_bucket]

    def can_consume_throttle(self, bucket: str, *, slot_id: str | None = None, limits: dict | None = None, now_override_ms: int | None = None) -> bool:
        clean_bucket, state_key = self._validate_throttle_bucket(bucket)
        eff_limits = self._resolve_throttle_limits(
            limits,
            agent_name=self.agent_name,
            max_tasks_per_slot=self._max_tasks_per_slot,
            max_tasks_per_day=self._max_tasks_per_day,
            daily_implementations_cap=self._daily_implementations_cap,
        )
        throttles = self.get_throttle_state(slot_id=slot_id, now_override_ms=now_override_ms)
        return self._can_consume_throttle_locked(
            throttles,
            clean_bucket,
            state_key,
            step=1,
            eff_limits=eff_limits,
            explicit_limits=limits,
        )

    def consume_throttle(self, bucket: str, *, count: int = 1, slot_id: str | None = None, limits: dict | None = None, now_override_ms: int | None = None) -> tuple[bool, dict]:
        clean_bucket, state_key = self._validate_throttle_bucket(bucket)
        if isinstance(count, bool) or _safe_int(count, 0) <= 0:
            raise ValueError(f"Throttle consume count must be positive: {count!r}")
        step = _safe_int(count, 1)
        eff_limits = self._resolve_throttle_limits(
            limits,
            agent_name=self.agent_name,
            max_tasks_per_slot=self._max_tasks_per_slot,
            max_tasks_per_day=self._max_tasks_per_day,
            daily_implementations_cap=self._daily_implementations_cap,
        )
        stamp_ms = _safe_int(now_override_ms, now_ms()) if now_override_ms is not None else now_ms()
        with self._locked_dir() as dir_fd:
            state = self._read_state_unlocked(dir_fd)
            throttles = self._rollover_throttles(state.get("throttles"), stamp_ms=stamp_ms, slot_id=slot_id)
            if not self._can_consume_throttle_locked(
                throttles,
                clean_bucket,
                state_key,
                step=step,
                eff_limits=eff_limits,
                explicit_limits=limits,
            ):
                return False, dict(throttles)
            if clean_bucket in _LLM_THROTTLE_BUCKETS:
                throttles["slot_tasks"] += step
                throttles["daily_tasks"] += step
                if state_key != "slot_tasks":
                    throttles[state_key] += step
                if clean_bucket == "todo_implementations":
                    throttles["daily_implementations"] += step
            else:
                throttles[state_key] += step
            state["throttles"] = throttles
            state["agent_name"] = self.agent_name
            state["updated_at_ms"] = stamp_ms
            atomic_write_json_in_dir(dir_fd, STATE_FILENAME, state)
            return True, dict(throttles)

    def record_operator_task(self, *, count: int = 1, slot_id: str | None = None, now_override_ms: int | None = None) -> dict:
        """Record a direct operator mention LLM task without blocking on slot or daily task limits."""
        if isinstance(count, bool) or _safe_int(count, 0) <= 0:
            raise ValueError(f"Operator task count must be positive: {count!r}")
        step = _safe_int(count, 1)
        stamp_ms = _safe_int(now_override_ms, now_ms()) if now_override_ms is not None else now_ms()
        with self._locked_dir() as dir_fd:
            state = self._read_state_unlocked(dir_fd)
            throttles = self._rollover_throttles(state.get("throttles"), stamp_ms=stamp_ms, slot_id=slot_id)
            throttles["slot_tasks"] += step
            throttles["daily_tasks"] += step
            state["throttles"] = throttles
            state["agent_name"] = self.agent_name
            state["updated_at_ms"] = stamp_ms
            atomic_write_json_in_dir(dir_fd, STATE_FILENAME, state)
            return dict(throttles)

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
            entry["handled_linear_comment_ids"] = self._normalize_handled_linear_comment_ids(entry.get("handled_linear_comment_ids"))
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
        actionable_threads, queued_followups, auto_dismiss_threads, cooled_down_threads = [], [], [], []
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
                cooldown_until_ms = _safe_int(existing.get("followup_cooldown_until_ms"), 0)
                is_pr_cooldown = subject_type.lower() in ("pullrequest", "pull_request", "pr") and cooldown_until_ms > stamp_ms
                if in_flight and unhandled and newer:
                    pending_followup = True
                    queued_followups.append(thread_id)
                elif not in_flight and unhandled and retry_count < MAX_THREAD_FAILURE_RETRIES:
                    if is_pr_cooldown:
                        pending_followup = True
                        queued_followups.append(thread_id)
                        cooled_down_threads.append(thread_id)
                    else:
                        actionable_threads.append(thread_id)
                entry = {**existing, **norm, "handled_updated_at": handled_u, "handled_head_sha": handled_sha, "handled_ci_state": handled_ci, "retry_count": retry_count, "in_flight": in_flight, "pending_followup": pending_followup, "last_polled_at_ms": stamp_ms, "updated_at_ms": stamp_ms}
                for tk in target_keys:
                    threads[tk] = dict(entry)
            state["updated_at_ms"] = stamp_ms
            atomic_write_json_in_dir(dir_fd, STATE_FILENAME, state)
        return {"actionable_threads": actionable_threads, "queued_followups": queued_followups, "auto_dismiss_threads": auto_dismiss_threads, "cooled_down_threads": cooled_down_threads}

    def record_polled_pull_requests(self, pull_requests: list[dict], self_github_login: str = "", now_override_ms: int | None = None) -> dict:
        """Evaluate and persist open pull requests in state.json for wake, community triage, and team-label detection."""
        stamp_ms = _safe_int(now_override_ms, now_ms()) if now_override_ms is not None else now_ms()
        self_login_norm = (self_github_login or GITHUB_AGENT_LOGINS[self.agent_name]).strip().lower()
        actionable_prs, queued_followups, cooled_down_prs, team_label_candidates, coercive_items, signoff_ready_prs = [], [], [], [], [], []
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
                author_association = str(norm_pr.get("author_association") or norm_pr.get("authorAssociation") or "").strip().upper()
                head_sha = str(norm_pr.get("head_sha") or norm_pr.get("headRefOid") or "").strip()
                review_decision = str(norm_pr.get("review_decision") or norm_pr.get("reviewDecision") or "").strip().upper()
                ci_state = normalize_ci_state(norm_pr.get("ci_state") or norm_pr.get("statusCheckRollup"))
                updated_at = str(norm_pr.get("updated_at") or norm_pr.get("updatedAt") or "").strip()
                title, body = str(norm_pr.get("title") or ""), str(norm_pr.get("body") or "")
                pr_url = str(norm_pr.get("url") or norm_pr.get("html_url") or "").strip()
                labels = extract_label_names(norm_pr.get("labels"))
                team_labels = extract_team_labels(norm_pr.get("team_labels") if "team_labels" in norm_pr else labels, PR_TEAM_LABELS)
                has_do_not_merge = has_do_not_merge_label(labels)
                review_requests = list(norm_pr.get("review_requests") or norm_pr.get("reviewRequests") or [])
                unresolved_thread_count = (
                    max(0, _safe_int(norm_pr.get("unresolved_thread_count"), 0))
                    if "unresolved_thread_count" in norm_pr
                    else count_unresolved_review_threads(norm_pr.get("reviewThreads") if "reviewThreads" in norm_pr else norm_pr.get("review_threads"))
                )
                target_keys, existing = self._load_entry_unlocked(threads, pr_key, repo=repo, number=number)
                resolved_pr_url = pr_url or str(existing.get("url") or "").strip() or f"https://github.com/{repo}/pull/{number}"
                handled_u, handled_sha, handled_ci = existing.get("handled_updated_at"), existing.get("handled_head_sha"), existing.get("handled_ci_state")
                in_flight, pending_followup = bool(existing.get("in_flight", False)), bool(existing.get("pending_followup", False))
                cooldown_until_ms = _safe_int(existing.get("followup_cooldown_until_ms"), 0)
                changed = (
                    (head_sha and head_sha != existing.get("head_sha"))
                    or (ci_state and ci_state != existing.get("ci_state"))
                    or ("unresolved_thread_count" in existing and unresolved_thread_count != _safe_int(existing.get("unresolved_thread_count"), 0))
                )
                retry_count = 0 if changed else _safe_int(existing.get("retry_count"), 0)
                is_trusted = is_trusted_github_actor(author_norm)
                is_instruction = is_trusted_instruction_actor(author_norm)
                is_self = bool(author_norm == self_login_norm or LOGIN_TO_AGENT_NAME.get(author_norm) == self.agent_name)
                is_community = not is_trusted
                is_auto_update = is_automated_update_pr(
                    author_norm,
                    repo=repo,
                    head_ref=str(norm_pr.get("head_ref") or _as_dict(norm_pr.get("head")).get("ref") or ""),
                    labels=labels,
                    title=title,
                )
                pr_owner = compute_pr_owner(repo, number)
                owns_mod2_pr = bool(self.agent_name in SWEEP_AGENT_ORDER and pr_owner == self.agent_name)
                unowned_auto_update = bool(is_auto_update and not owns_mod2_pr)

                raw_texts = [t for t in (title, body) if t]
                if is_instruction:
                    matched_coercion = []
                else:
                    matched_coercion = detect_coercion_patterns("\n".join(raw_texts))
                    if not is_trusted and extract_mentioned_github_agents("\n".join(raw_texts)):
                        matched_coercion = [*matched_coercion, "targeted_agent_mention"]
                if matched_coercion:
                    coercive_items.append({
                        "repo": repo,
                        "subject_type": "PullRequest",
                        "number": number,
                        "thread_id": str(existing.get("thread_id") or pr_key),
                        "item_kind": "pull_request",
                        "item_id": norm_pr.get("id") or number,
                        "actor": author or "unknown",
                        "raw_texts": raw_texts,
                    })
                    handled_u, handled_sha, handled_ci = updated_at or handled_u, head_sha or handled_sha, ci_state or handled_ci
                    entry = {**existing, "pr_key": pr_key, "repo": repo, "number": number, "subject_type": "PullRequest", "author": author, "title": title or existing.get("title") or "", "url": resolved_pr_url, "head_sha": head_sha, "ci_state": ci_state, "review_decision": review_decision, "review_requests": review_requests, "unresolved_thread_count": unresolved_thread_count, "labels": labels, "updated_at": updated_at or existing.get("updated_at"), "handled_updated_at": handled_u, "handled_head_sha": handled_sha, "handled_ci_state": handled_ci, "retry_count": 0, "is_automated_pr": is_auto_update, "is_community": is_community, "coercion_blocked": True, "in_flight": in_flight, "pending_followup": False, "last_polled_at_ms": stamp_ms, "updated_at_ms": stamp_ms}
                    for tk in target_keys:
                        threads[tk] = dict(entry)
                    continue

                if (
                    has_do_not_merge
                    and owns_mod2_pr
                    and review_decision == "APPROVED"
                    and ci_state in ("SUCCESS", "NONE")
                    and unresolved_thread_count == 0
                    and head_sha
                    and existing.get("ready_for_signoff_notified_sha") != head_sha
                ):
                    signoff_ready_prs.append({
                        "key": pr_key,
                        "repo": repo,
                        "number": number,
                        "head_sha": head_sha,
                        "title": title,
                        "url": pr_url or f"https://github.com/{repo}/pull/{number}",
                    })

                mergeable = normalize_mergeable_state(
                    norm_pr.get("mergeable"),
                    norm_pr.get("merge_state_status") or norm_pr.get("mergeStateStatus"),
                )
                merge_state_status = str(norm_pr.get("merge_state_status") or norm_pr.get("mergeStateStatus") or "").strip().upper()
                auto_merge_eligible = (
                    compute_community_auto_merge_eligible(
                        repo=repo,
                        additions=norm_pr.get("additions"),
                        deletions=norm_pr.get("deletions"),
                        changed_files=norm_pr.get("changed_files"),
                        file_paths=norm_pr.get("file_paths"),
                        files_has_next_page=bool(norm_pr.get("files_has_next_page", False)),
                        author_association=author_association,
                        mergeable=mergeable,
                        merge_state_status=merge_state_status,
                        enabled=self.community_auto_merge_enabled,
                        max_lines=self.community_auto_merge_max_lines,
                        max_files=self.community_auto_merge_max_files,
                        excluded_repos=self.community_auto_merge_excluded_repos,
                    )
                    if is_community
                    else None
                )

                if owns_mod2_pr and team_labels:
                    if in_flight:
                        pending_followup = True
                        if pr_key not in queued_followups:
                            queued_followups.append(pr_key)
                    elif retry_count < MAX_THREAD_FAILURE_RETRIES:
                        team_label_candidates.append({
                            "key": pr_key,
                            "thread_id": existing.get("thread_id"),
                            "repo": repo,
                            "number": number,
                            "kind": "PullRequest",
                            "head_sha": head_sha,
                            "ci_state": ci_state,
                            "updated_at": updated_at,
                            "team_labels": list(team_labels),
                            "is_automated_pr": is_auto_update,
                            "is_community": is_community,
                            "community_auto_merge_eligible": auto_merge_eligible,
                            "handled_head_sha": handled_sha,
                            "triaged_head_sha": existing.get("triaged_head_sha"),
                            "handled_team_labels": dict(_as_dict(existing.get("handled_team_labels"))),
                        })

                dispatch_kind = "targeted"
                trigger_reason: str | None = None
                if is_trusted and not unowned_auto_update:
                    if not has_do_not_merge and review_decision == "APPROVED" and ci_state in ("SUCCESS", "NONE") and unresolved_thread_count == 0 and (handled_ci != ci_state or (head_sha and handled_sha != head_sha)):
                        trigger_reason = "ci_green_after_approval"
                    elif not is_self and handled_sha and head_sha and head_sha != handled_sha:
                        trigger_reason = "head_push"
                    elif not is_self and not handled_sha and not handled_u:
                        trigger_reason = "review_requested" if self_login_norm in review_requests else "unrequested_pr"
                elif is_community and owns_mod2_pr:
                    if not handled_sha and not handled_u:
                        if auto_merge_eligible and ci_state == "PENDING":
                            pass
                        else:
                            dispatch_kind = "community_auto_review" if auto_merge_eligible else "community_triage"
                            trigger_reason = dispatch_kind
                    elif (
                        not has_do_not_merge
                        and handled_sha
                        and head_sha
                        and head_sha == handled_sha
                        and auto_merge_eligible
                        and review_decision == "APPROVED"
                        and ci_state in ("SUCCESS", "NONE")
                        and unresolved_thread_count == 0
                        and handled_ci != ci_state
                    ):
                        dispatch_kind = "community_auto_review"
                        trigger_reason = "ci_green_after_approval"

                if trigger_reason is None:
                    if is_self or unowned_auto_update or (is_community and not owns_mod2_pr):
                        handled_u, handled_sha = updated_at or handled_u, head_sha or handled_sha
                        if unowned_auto_update or (is_community and not owns_mod2_pr) or ci_state not in ("SUCCESS", "NONE"):
                            handled_ci = ci_state or handled_ci
                    elif ci_state not in ("SUCCESS", "NONE") and ci_state:
                        handled_ci = ci_state
                elif in_flight:
                    pending_followup = True
                    if pr_key not in queued_followups:
                        queued_followups.append(pr_key)
                elif retry_count < MAX_THREAD_FAILURE_RETRIES:
                    if trigger_reason != "ci_green_after_approval" and cooldown_until_ms > stamp_ms:
                        pending_followup = True
                        if pr_key not in queued_followups:
                            queued_followups.append(pr_key)
                        cooled_down_prs.append(pr_key)
                    else:
                        actionable_prs.append({
                            "key": pr_key,
                            "thread_id": existing.get("thread_id"),
                            "repo": repo,
                            "number": number,
                            "kind": "PullRequest",
                            "dispatch_kind": dispatch_kind,
                            "head_sha": head_sha,
                            "ci_state": ci_state,
                            "statusCheckRollup": norm_pr.get("statusCheckRollup"),
                            "updated_at": updated_at,
                            "trigger_reason": trigger_reason,
                            "author_association": author_association,
                            "mergeable": mergeable,
                            "merge_state_status": merge_state_status,
                            "has_merge_conflicts": mergeable == "CONFLICTING",
                            "is_automated_pr": is_auto_update,
                            "is_community": is_community,
                            "community_auto_merge_eligible": auto_merge_eligible,
                            "additions": norm_pr.get("additions"),
                            "deletions": norm_pr.get("deletions"),
                            "changed_files": norm_pr.get("changed_files"),
                            "file_paths": norm_pr.get("file_paths"),
                            "files_has_next_page": bool(norm_pr.get("files_has_next_page", False)),
                        })
                entry = {**existing, "pr_key": pr_key, "repo": repo, "number": number, "subject_type": "PullRequest", "author": author, "author_association": author_association or existing.get("author_association") or "", "mergeable": mergeable, "merge_state_status": merge_state_status, "title": title or existing.get("title") or "", "url": resolved_pr_url, "head_sha": head_sha, "ci_state": ci_state, "review_decision": review_decision, "review_requests": review_requests, "unresolved_thread_count": unresolved_thread_count, "labels": labels, "updated_at": updated_at or existing.get("updated_at"), "handled_updated_at": handled_u, "handled_head_sha": handled_sha, "handled_ci_state": handled_ci, "retry_count": retry_count, "trigger_reason": trigger_reason or existing.get("trigger_reason"), "is_automated_pr": is_auto_update, "is_community": is_community, "community_auto_merge_eligible": auto_merge_eligible, "coercion_blocked": False, "in_flight": in_flight, "pending_followup": pending_followup, "last_polled_at_ms": stamp_ms, "updated_at_ms": stamp_ms}
                for tk in target_keys:
                    threads[tk] = dict(entry)
            state["updated_at_ms"] = stamp_ms
            atomic_write_json_in_dir(dir_fd, STATE_FILENAME, state)
        return {"actionable_prs": actionable_prs, "queued_followups": queued_followups, "cooled_down_prs": cooled_down_prs, "team_label_candidates": team_label_candidates, "coercive_items": coercive_items, "signoff_ready_prs": signoff_ready_prs}

    def record_polled_issues(self, issues: list[dict], now_override_ms: int | None = None) -> dict:
        """Evaluate and persist open issues in state.json for community triage and team-label detection."""
        stamp_ms = _safe_int(now_override_ms, now_ms()) if now_override_ms is not None else now_ms()
        actionable_issues, queued_followups, team_label_candidates, coercive_items = [], [], [], []
        with self._locked_dir() as dir_fd:
            state = self._read_state_unlocked(dir_fd)
            threads: dict[str, dict] = state["threads"]
            for raw_issue in issues:
                norm_issue = normalize_open_issue_record(raw_issue) if "issue_key" not in _as_dict(raw_issue) else dict(raw_issue)
                if not isinstance(norm_issue, dict) or _is_archived_record(raw_issue, norm_issue) or str(norm_issue.get("state") or "OPEN").upper() != "OPEN":
                    continue
                repo, number = str(norm_issue.get("repo") or "").strip(), _safe_int(norm_issue.get("number"), 0)
                if not repo or number <= 0:
                    continue
                issue_key, author = make_pr_key(repo, number), str(norm_issue.get("author") or "").strip()
                author_norm = normalize_github_actor(author)
                updated_at = str(norm_issue.get("updated_at") or norm_issue.get("updatedAt") or "").strip()
                title, body = str(norm_issue.get("title") or ""), str(norm_issue.get("body") or "")
                raw_issue_url = str(norm_issue.get("url") or norm_issue.get("html_url") or "").strip()
                labels = extract_label_names(norm_issue.get("labels"))
                team_labels = extract_team_labels(norm_issue.get("team_labels") if "team_labels" in norm_issue else labels, ISSUE_TEAM_LABELS)
                latest_comment = _as_dict(norm_issue.get("latest_comment"))
                latest_comment_actor = extract_actor_login(latest_comment.get("author") or latest_comment.get("user")) if latest_comment else ""
                latest_comment_actor_norm = normalize_github_actor(latest_comment_actor)
                latest_comment_body = str(latest_comment.get("body") or "") if latest_comment else ""

                target_keys, existing = self._load_entry_unlocked(threads, issue_key, repo=repo, number=number)
                issue_url = raw_issue_url or str(existing.get("url") or "").strip() or f"https://github.com/{repo}/issues/{number}"
                handled_u = existing.get("handled_updated_at")
                in_flight, pending_followup = bool(existing.get("in_flight", False)), bool(existing.get("pending_followup", False))
                prior_u = str(existing.get("updated_at") or "").strip()
                newer = is_timestamp_newer(updated_at, prior_u)
                retry_count = 0 if newer else _safe_int(existing.get("retry_count"), 0)
                is_trusted = is_trusted_github_actor(author_norm)
                is_instruction = is_trusted_instruction_actor(author_norm)
                is_community = not is_trusted
                issue_owner = compute_issue_owner(repo, number)
                owns_mod2_issue = bool(self.agent_name in SWEEP_AGENT_ORDER and issue_owner == self.agent_name)

                subj_texts = [t for t in (title, body) if t]
                if is_instruction:
                    subj_coercion = []
                else:
                    subj_coercion = detect_coercion_patterns("\n".join(subj_texts))
                    if not is_trusted and extract_mentioned_github_agents("\n".join(subj_texts)):
                        subj_coercion = [*subj_coercion, "targeted_agent_mention"]
                comment_coercion = (
                    detect_coercion_patterns(latest_comment_body)
                    if (latest_comment_body and not is_trusted_github_actor(latest_comment_actor_norm))
                    else []
                )
                if latest_comment_body and not is_trusted_github_actor(latest_comment_actor_norm) and extract_mentioned_github_agents(latest_comment_body):
                    comment_coercion = [*comment_coercion, "targeted_agent_mention"]
                if subj_coercion or comment_coercion:
                    if subj_coercion:
                        coercive_items.append({
                            "repo": repo,
                            "subject_type": "Issue",
                            "number": number,
                            "thread_id": str(existing.get("thread_id") or issue_key),
                            "item_kind": "issue",
                            "item_id": norm_issue.get("id") or number,
                            "actor": author or "unknown",
                            "raw_texts": subj_texts,
                        })
                    else:
                        coercive_items.append({
                            "repo": repo,
                            "subject_type": "Issue",
                            "number": number,
                            "thread_id": str(existing.get("thread_id") or issue_key),
                            "item_kind": "issue_comment",
                            "item_id": latest_comment.get("id") or latest_comment.get("databaseId") or f"{number}:{updated_at}",
                            "actor": latest_comment_actor or "unknown",
                            "raw_texts": [latest_comment_body],
                        })
                    handled_u = updated_at or handled_u
                    entry = {**existing, "issue_key": issue_key, "repo": repo, "number": number, "subject_type": "Issue", "author": author, "title": title or existing.get("title") or "", "url": issue_url, "labels": labels, "updated_at": updated_at or existing.get("updated_at"), "handled_updated_at": handled_u, "retry_count": 0, "is_community": is_community, "coercion_blocked": True, "in_flight": in_flight, "pending_followup": False, "last_polled_at_ms": stamp_ms, "updated_at_ms": stamp_ms}
                    for tk in target_keys:
                        threads[tk] = dict(entry)
                    continue

                if owns_mod2_issue and team_labels:
                    if in_flight:
                        pending_followup = True
                        if issue_key not in queued_followups:
                            queued_followups.append(issue_key)
                    elif retry_count < MAX_THREAD_FAILURE_RETRIES:
                        team_label_candidates.append({
                            "key": issue_key,
                            "thread_id": existing.get("thread_id"),
                            "repo": repo,
                            "number": number,
                            "kind": "Issue",
                            "url": issue_url,
                            "title": title,
                            "body": body,
                            "author": author,
                            "labels": list(labels),
                            "linear_issue_id": existing.get("linear_issue_id"),
                            "updated_at": updated_at,
                            "team_labels": list(team_labels),
                            "is_community": is_community,
                            "handled_team_labels": dict(_as_dict(existing.get("handled_team_labels"))),
                        })

                dispatch_kind = "linear_triage_intake"
                trigger_reason: str | None = None
                if not owns_mod2_issue or is_trusted:
                    handled_u = updated_at or handled_u
                elif not handled_u and not existing.get("linear_issue_id") and bool(updated_at):
                    trigger_reason = "linear_triage_intake"
                elif handled_u and is_timestamp_newer(updated_at, handled_u):
                    handled_u = updated_at or handled_u

                if trigger_reason is not None:
                    if in_flight:
                        pending_followup = True
                        if issue_key not in queued_followups:
                            queued_followups.append(issue_key)
                    elif retry_count < MAX_THREAD_FAILURE_RETRIES:
                        actionable_issues.append({
                            "key": issue_key,
                            "thread_id": existing.get("thread_id"),
                            "repo": repo,
                            "number": number,
                            "kind": "Issue",
                            "url": issue_url,
                            "title": title,
                            "body": body,
                            "author": author,
                            "labels": list(labels),
                            "linear_issue_id": existing.get("linear_issue_id"),
                            "dispatch_kind": dispatch_kind,
                            "trigger_reason": trigger_reason,
                            "updated_at": updated_at,
                            "is_community": True,
                        })

                entry = {**existing, "issue_key": issue_key, "repo": repo, "number": number, "subject_type": "Issue", "author": author, "title": title or existing.get("title") or "", "url": issue_url, "labels": labels, "updated_at": updated_at or existing.get("updated_at"), "handled_updated_at": handled_u, "retry_count": retry_count, "trigger_reason": trigger_reason or existing.get("trigger_reason"), "is_community": is_community, "coercion_blocked": False, "in_flight": in_flight, "pending_followup": pending_followup, "last_polled_at_ms": stamp_ms, "updated_at_ms": stamp_ms}
                for tk in target_keys:
                    threads[tk] = dict(entry)
            state["updated_at_ms"] = stamp_ms
            atomic_write_json_in_dir(dir_fd, STATE_FILENAME, state)
        return {"actionable_issues": actionable_issues, "queued_followups": queued_followups, "team_label_candidates": team_label_candidates, "coercive_items": coercive_items}

    def mark_thread_in_flight(self, key: str, *, updated_at: str | None = None, head_sha: str | None = None, ci_state: str | None = None, now_override_ms: int | None = None) -> dict:
        def _mark(entry: dict, _: int) -> None:
            entry.update({"in_flight": True, "pending_followup": False, "in_flight_updated_at": updated_at or entry.get("updated_at"), "in_flight_head_sha": head_sha or entry.get("head_sha"), "in_flight_ci_state": ci_state or entry.get("ci_state")})

        return self._mutate_thread(key, _mark, now_override_ms=now_override_ms)

    def clear_thread_in_flight(self, key: str, *, now_override_ms: int | None = None) -> dict:
        """Clear in_flight without advancing handled watermarks or retry_count."""
        def _clear(entry: dict, _: int) -> None:
            entry["in_flight"] = False

        return self._mutate_thread(key, _clear, now_override_ms=now_override_ms)

    def complete_thread_review(
        self,
        key: str,
        *,
        handled_updated_at: str | None = None,
        handled_head_sha: str | None = None,
        handled_ci_state: str | None = None,
        completed_revision: str | None = None,
        team_label: str | None = None,
        team_label_event_key: str | None = None,
        preserve_handled_head_sha: bool = False,
        record_triaged_head_sha: bool = False,
        apply_cooldown: bool | None = None,
        preserve_pending_followup: bool = False,
        now_override_ms: int | None = None,
    ) -> dict:
        rev_u, rev_cid = parse_revision_token(completed_revision)

        def _complete(entry: dict, stamp_ms: int) -> None:
            was_in_flight = bool(entry.get("in_flight"))
            should_cooldown = was_in_flight if apply_cooldown is None else bool(apply_cooldown)
            fin_u = handled_updated_at or rev_u or entry.get("in_flight_updated_at") or entry.get("updated_at") or entry.get("handled_updated_at")
            fin_sha = (
                entry.get("handled_head_sha")
                if preserve_handled_head_sha
                else (handled_head_sha or entry.get("in_flight_head_sha") or entry.get("head_sha") or entry.get("handled_head_sha"))
            )
            fin_ci = handled_ci_state or entry.get("in_flight_ci_state") or entry.get("ci_state") or entry.get("handled_ci_state")
            seen_u, seen_sha = str(entry.get("updated_at") or "").strip(), str(entry.get("head_sha") or "").strip()
            sha_newer = bool(not preserve_handled_head_sha and seen_sha and fin_sha and seen_sha != fin_sha)
            has_newer = bool(((was_in_flight or preserve_pending_followup) and entry.get("pending_followup")) or (seen_u and fin_u and is_timestamp_newer(seen_u, fin_u)) or sha_newer)
            entry.update({"handled_updated_at": fin_u, "handled_head_sha": fin_sha, "handled_ci_state": fin_ci, "retry_count": 0, "in_flight": False, "pending_followup": has_newer, "dismiss_ready": not has_newer})
            if record_triaged_head_sha and not preserve_handled_head_sha and fin_sha:
                entry["triaged_head_sha"] = fin_sha
            if team_label and team_label_event_key:
                handled_lbls = dict(_as_dict(entry.get("handled_team_labels")))
                handled_lbls[team_label.strip().lower()] = team_label_event_key.strip()
                entry["handled_team_labels"] = handled_lbls
            if should_cooldown and self.followup_cooldown_ms > 0:
                entry["last_review_completed_at_ms"] = stamp_ms
                entry["followup_cooldown_until_ms"] = stamp_ms + self.followup_cooldown_ms
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


TELEGRAM_MAX_MESSAGE_CHARS = 4000


def split_telegram_message(text: str, max_chars: int = TELEGRAM_MAX_MESSAGE_CHARS) -> list[str]:
    """Split a Telegram message on newline boundaries under Telegram's 4,096-character limit."""
    clean_text = (text or "").strip()
    if not clean_text:
        return []
    limit = max(1, int(max_chars))
    if len(clean_text) <= limit:
        return [clean_text]

    chunks: list[str] = []
    current_lines: list[str] = []
    current_len = 0

    def _flush() -> None:
        nonlocal current_lines, current_len
        if current_lines:
            chunk = "\n".join(current_lines).strip()
            if chunk:
                chunks.append(chunk)
            current_lines = []
            current_len = 0

    for line in clean_text.split("\n"):
        if len(line) > limit:
            _flush()
            for start in range(0, len(line), limit):
                part = line[start : start + limit]
                if part.strip():
                    chunks.append(part)
            continue
        if not current_lines:
            if not line.strip():
                continue
            current_lines = [line]
            current_len = len(line)
        elif current_len + 1 + len(line) <= limit:
            current_lines.append(line)
            current_len += 1 + len(line)
        else:
            _flush()
            if line.strip():
                current_lines = [line]
                current_len = len(line)

    _flush()
    return chunks


def _extract_telegram_error_description(raw: bytes) -> str:
    if not raw or not raw.strip():
        return ""
    with contextlib.suppress(UnicodeDecodeError, ValueError):
        data = json.loads(raw.decode("utf-8"))
        if isinstance(data, dict):
            return str(data.get("description") or "").strip()
    return ""


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
        chunks = split_telegram_message(clean_text)
        if not chunks:
            return {"ok": True, "skipped": True}
        bot_cred, chat_id = read_telegram_bot_token(self.bot_token_path), read_telegram_allowed_chat_id(self.allowed_users_path)
        last_result: dict = {"ok": True}
        for chunk in chunks:
            status, raw = _http_json_request(url=f"{self.api_url}/bot{bot_cred}/sendMessage", method="POST", headers={"Content-Type": "application/json", "Accept": "application/json"}, raw_body=json.dumps({"chat_id": chat_id, "text": chunk, "link_preview_options": {"is_disabled": True}}, ensure_ascii=False).encode("utf-8"), timeout=self.timeout, allow_loopback_self_signed=False)
            if status >= 400:
                description = _extract_telegram_error_description(raw)
                detail = f": {description}" if description else ""
                raise RuntimeError(f"Telegram sendMessage HTTP {status}{detail}")
            if not raw.strip():
                last_result = {"ok": True}
                continue
            try:
                data = json.loads(raw.decode("utf-8"))
            except (UnicodeDecodeError, ValueError) as exc:
                raise ValueError("Invalid JSON in Telegram API response") from exc
            if isinstance(data, dict) and data.get("ok") is False:
                raise RuntimeError(str(data.get("description") or f"Telegram API error {data.get('error_code') or ''}").strip() or "Telegram sendMessage returned ok=false")
            last_result = data if isinstance(data, dict) else {"ok": True}
        return last_result


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


OPEN_PRS_GRAPHQL_QUERY_TEMPLATE = (
    "query($endCursor: String) { "
    "search(query: %s, type: ISSUE, first: 100, after: $endCursor) { "
    "pageInfo { hasNextPage endCursor } "
    "nodes { "
    "__typename "
    "... on PullRequest { "
    "id number title body url state isDraft updatedAt headRefName headRefOid authorAssociation reviewDecision additions deletions changedFiles "
    "repository { nameWithOwner isArchived } "
    "author { __typename login } "
    "labels(first: 20) { nodes { name } } "
    "files(first: 25) { pageInfo { hasNextPage } nodes { path } } "
    "closingIssuesReferences(first: 10) { nodes { number url repository { nameWithOwner } } } "
    "reviewRequests(first: 20) { nodes { requestedReviewer { ... on User { login } } } } "
    "reviewThreads(first: 100) { pageInfo { hasNextPage } nodes { isResolved } } "
    "statusCheckRollup { state contexts(first: 100) { nodes { __typename ... on CheckRun { status conclusion } ... on StatusContext { state } } } } "
    "} "
    "... on Issue { "
    "id number title body url state updatedAt "
    "repository { nameWithOwner isArchived } "
    "author { __typename login } "
    "labels(first: 20) { nodes { name } } "
    "comments(last: 1) { nodes { id author { __typename login } body updatedAt } } "
    "} "
    "} } }"
)
OPEN_ISSUES_GRAPHQL_QUERY_TEMPLATE = (
    "query($endCursor: String) { "
    "search(query: %s, type: ISSUE, first: 100, after: $endCursor) { "
    "pageInfo { hasNextPage endCursor } "
    "nodes { ... on Issue { "
    "id number title body url state updatedAt "
    "repository { nameWithOwner isArchived } "
    "author { __typename login } "
    "labels(first: 20) { nodes { name } } "
    "comments(last: 1) { nodes { id author { __typename login } body updatedAt } } "
    "} } } }"
)


def build_open_prs_graphql_query(owners: Iterable[str] = POLL_PR_OWNERS) -> str:
    owner_clauses = " ".join(f"user:{o.strip()}" for o in owners if str(o).strip())
    return OPEN_PRS_GRAPHQL_QUERY_TEMPLATE % json.dumps(f"is:open archived:false {owner_clauses}".strip())


def build_open_issues_graphql_query(owners: Iterable[str] = POLL_ISSUE_OWNERS) -> str:
    owner_clauses = " ".join(f"user:{o.strip()}" for o in owners if str(o).strip())
    return OPEN_ISSUES_GRAPHQL_QUERY_TEMPLATE % json.dumps(f"is:issue is:open archived:false {owner_clauses}".strip())


class GhApiSafeClient:
    """Subprocess wrapper around `gh-api-safe`, `gh-notification-dismiss`, `gh-workflow-approve`, `gh-security-release-tag`, and scoped `gh` PR label edits."""

    def __init__(self, gh_api_safe_bin: str = "gh-api-safe", gh_notification_dismiss_bin: str = "gh-notification-dismiss", gh_workflow_approve_bin: str = "gh-workflow-approve", gh_security_release_tag_bin: str = "gh-security-release-tag", gh_bin: str = "gh", runner: Callable[..., subprocess.CompletedProcess] | None = None, timeout: float = 45.0):
        self.gh_api_safe_bin = gh_api_safe_bin
        self.gh_notification_dismiss_bin = gh_notification_dismiss_bin
        self.gh_workflow_approve_bin = gh_workflow_approve_bin
        self.gh_security_release_tag_bin = gh_security_release_tag_bin
        self.gh_bin = gh_bin
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

    def approve_pending_pr_workflow_runs(self, repo: str, head_sha: str, *, timeout: float | None = None) -> list[int]:
        """Approve pending `action_required` `pull_request` workflow runs for `head_sha` via `gh-workflow-approve`."""
        clean_repo = (repo or "").strip()
        if (
            not clean_repo
            or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*", clean_repo)
            or any(part in (".", "..") for part in clean_repo.split("/"))
            or not is_allowed_notification_repo(clean_repo)
        ):
            raise ValueError(f"Unsupported repository for workflow approval: {repo!r}")
        clean_sha = (head_sha or "").strip()
        if not re.fullmatch(r"[0-9a-fA-F]{7,40}", clean_sha):
            raise ValueError(f"Invalid head_sha for workflow approval: {head_sha!r}")
        data = self.fetch_json_object(
            f"repos/{clean_repo}/actions/runs?head_sha={clean_sha}&event=pull_request&status=action_required&per_page=100",
            paginate=False,
            timeout=timeout,
        )
        runs = data.get("workflow_runs") if isinstance(data, dict) else None
        if not isinstance(runs, list):
            return []
        approved: list[int] = []
        for run in runs:
            if not isinstance(run, dict):
                continue
            run_id = _safe_int(run.get("id"), 0)
            if run_id <= 0:
                continue
            run_event = str(run.get("event") or "").strip().lower()
            run_status = str(run.get("status") or "").strip().lower()
            run_conclusion = str(run.get("conclusion") or "").strip().lower()
            if run_event != "pull_request" or (run_status != "action_required" and run_conclusion != "action_required"):
                continue
            cmd = [self.gh_workflow_approve_bin, clean_repo, str(run_id)]
            proc = self.runner(cmd, capture_output=True, text=True, timeout=timeout or self.timeout, check=False)
            if proc.returncode != 0:
                raise RuntimeError(f"gh-workflow-approve {clean_repo} {run_id} exited {proc.returncode}: {(proc.stderr or proc.stdout or '').strip()}")
            approved.append(run_id)
        return approved

    def create_security_release_tag(
        self,
        repo: str,
        tag: str,
        commit_sha: str,
        *,
        dry_run: bool = False,
        timeout: float | None = None,
    ) -> subprocess.CompletedProcess:
        """Create and push an annotated semver release tag via `gh-security-release-tag`."""
        clean_repo = (repo or "").strip()
        if (
            not clean_repo
            or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*", clean_repo)
            or any(part in (".", "..") for part in clean_repo.split("/"))
            or not is_allowed_notification_repo(clean_repo)
        ):
            raise ValueError(f"Unsupported repository for security release tag: {repo!r}")
        clean_tag = (tag or "").strip()
        if not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+", clean_tag):
            raise ValueError(f"Invalid semver tag for security release: {tag!r}")
        clean_sha = (commit_sha or "").strip()
        if not re.fullmatch(r"[0-9a-f]{40}", clean_sha):
            raise ValueError(f"Invalid commit_sha for security release tag: {commit_sha!r}")
        cmd = [
            self.gh_security_release_tag_bin,
            *(["--dry-run"] if dry_run else []),
            clean_repo,
            clean_tag,
            clean_sha,
        ]
        proc = self.runner(cmd, capture_output=True, text=True, timeout=timeout or self.timeout, check=False)
        if proc.returncode != 0:
            err_text = (proc.stderr or proc.stdout or "").strip()
            raise RuntimeError(
                f"gh-security-release-tag {clean_repo} {clean_tag} {clean_sha} exited {proc.returncode}: {err_text}"
            )
        return proc

    def fetch_tag_release_progress(
        self,
        repo: str,
        tag: str,
        *,
        timeout: float | None = None,
    ) -> dict | None:
        """Read-only check via `gh-api-safe` for a pushed tag's GitHub Release and tag-push workflow runs."""
        clean_repo = (repo or "").strip()
        if (
            not clean_repo
            or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*", clean_repo)
            or any(part in (".", "..") for part in clean_repo.split("/"))
            or not is_allowed_notification_repo(clean_repo)
        ):
            raise ValueError(f"Unsupported repository for tag release progress: {repo!r}")
        clean_tag = (tag or "").strip()
        if not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+", clean_tag):
            raise ValueError(f"Invalid semver tag for tag release progress: {tag!r}")

        release_published = False
        release_url: str | None = None
        release_endpoint = f"repos/{clean_repo}/releases/tags/{clean_tag}"
        try:
            rel_proc = self.invoke([release_endpoint], timeout=timeout)
        except Exception as exc:
            sys.stderr.write(f"moltis-github-companion tag-release-progress warning ({clean_repo} {clean_tag}): {exc}\n")
            return None

        rel_stdout = (rel_proc.stdout or "").strip()
        rel_stderr = (rel_proc.stderr or "").strip()
        if rel_proc.returncode != 0:
            combined_err = f"{rel_stderr}\n{rel_stdout}".lower()
            if "404" in combined_err or "not found" in combined_err:
                release_published = False
                release_url = None
            else:
                sys.stderr.write(
                    f"moltis-github-companion tag-release-progress warning ({clean_repo} {clean_tag}): "
                    f"release lookup exit {rel_proc.returncode}: {rel_stderr or rel_stdout}\n"
                )
                return None
        elif rel_stdout:
            try:
                rel_status, _, rel_items = parse_gh_api_paginated_http_output(rel_stdout)
            except Exception as exc:
                sys.stderr.write(
                    f"moltis-github-companion tag-release-progress warning ({clean_repo} {clean_tag}): "
                    f"invalid release JSON: {exc}\n"
                )
                return None
            if rel_status == 404:
                release_published = False
                release_url = None
            elif rel_status >= 400:
                sys.stderr.write(
                    f"moltis-github-companion tag-release-progress warning ({clean_repo} {clean_tag}): "
                    f"release lookup HTTP {rel_status}\n"
                )
                return None
            else:
                rel_obj = rel_items[0] if rel_items and isinstance(rel_items[0], dict) else {}
                msg_lower = str(rel_obj.get("message") or "").strip().lower()
                is_not_found_body = (
                    (str(rel_obj.get("status") or "").strip() == "404" or "not found" in msg_lower)
                    and not rel_obj.get("html_url")
                    and not rel_obj.get("tag_name")
                    and not rel_obj.get("id")
                )
                if not is_not_found_body and rel_obj:
                    is_draft = bool(rel_obj.get("draft"))
                    is_prerelease = bool(rel_obj.get("prerelease"))
                    published_at = str(rel_obj.get("published_at") or "").strip()
                    candidate_url = str(rel_obj.get("html_url") or "").strip() or None
                    if (
                        not is_draft
                        and not is_prerelease
                        and (published_at or candidate_url or rel_obj.get("id") or rel_obj.get("tag_name"))
                    ):
                        release_published = True
                        release_url = candidate_url

        runs_endpoint = (
            f"repos/{clean_repo}/actions/runs?branch={urllib.parse.quote(clean_tag, safe='')}&event=push&per_page=10"
        )
        try:
            runs_proc = self.invoke([runs_endpoint], timeout=timeout)
        except Exception as exc:
            sys.stderr.write(f"moltis-github-companion tag-release-progress warning ({clean_repo} {clean_tag}): {exc}\n")
            return None

        runs_stdout = (runs_proc.stdout or "").strip()
        runs_stderr = (runs_proc.stderr or "").strip()
        if runs_proc.returncode != 0:
            sys.stderr.write(
                f"moltis-github-companion tag-release-progress warning ({clean_repo} {clean_tag}): "
                f"workflow runs exit {runs_proc.returncode}: {runs_stderr or runs_stdout}\n"
            )
            return None
        try:
            runs_status, _, runs_items = parse_gh_api_paginated_http_output(runs_stdout)
        except Exception as exc:
            sys.stderr.write(
                f"moltis-github-companion tag-release-progress warning ({clean_repo} {clean_tag}): "
                f"invalid workflow runs JSON: {exc}\n"
            )
            return None
        if runs_status >= 400:
            sys.stderr.write(
                f"moltis-github-companion tag-release-progress warning ({clean_repo} {clean_tag}): "
                f"workflow runs HTTP {runs_status}\n"
            )
            return None

        runs_payload = runs_items[0] if runs_items and isinstance(runs_items[0], dict) else {}
        raw_runs = runs_payload.get("workflow_runs")
        workflow_runs = [r for r in raw_runs if isinstance(r, dict)] if isinstance(raw_runs, list) else []
        total_runs = len(workflow_runs)
        any_in_progress = False
        any_failed = False
        failed_run_url: str | None = None
        latest_run_url: str | None = None
        for run in workflow_runs:
            run_url = str(run.get("html_url") or "").strip() or None
            if latest_run_url is None and run_url:
                latest_run_url = run_url
            run_status = str(run.get("status") or "").strip().lower()
            run_conclusion = str(run.get("conclusion") or "").strip().lower()
            if run_status != "completed":
                any_in_progress = True
            elif run_conclusion not in ("success", "neutral", "skipped"):
                any_failed = True
                if failed_run_url is None and run_url:
                    failed_run_url = run_url

        all_succeeded = total_runs > 0 and not any_in_progress and not any_failed
        return {
            "release_published": release_published,
            "release_url": release_url,
            "total_runs": total_runs,
            "any_in_progress": any_in_progress,
            "any_failed": any_failed,
            "all_succeeded": all_succeeded,
            "failed_run_url": failed_run_url,
            "latest_run_url": latest_run_url,
        }

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

    def _query_graphql_search_nodes(self, query: str, timeout: float | None = None) -> list[dict]:
        proc = self.invoke(["graphql", "--paginate", "-f", f"query={query}"], timeout=timeout)
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
        return raw_nodes

    def poll_open_items(self, owners: Iterable[str] = POLL_PR_OWNERS, timeout: float | None = None) -> tuple[list[dict], list[dict]]:
        """Query open pull requests and open issues across the configured owners via a single GraphQL search query."""
        raw_nodes = self._query_graphql_search_nodes(build_open_prs_graphql_query(owners), timeout=timeout)
        prs = [norm for node in raw_nodes if (norm := normalize_open_pull_request_record(node)) is not None]
        issues = [norm for node in raw_nodes if (norm := normalize_open_issue_record(node)) is not None]
        return prs, issues

    def poll_open_pull_requests(self, owners: Iterable[str] = POLL_PR_OWNERS, timeout: float | None = None) -> list[dict]:
        """Query open pull requests across the configured owners via a single GraphQL search query."""
        return self.poll_open_items(owners, timeout=timeout)[0]

    def poll_open_issues(self, owners: Iterable[str] = POLL_ISSUE_OWNERS, timeout: float | None = None) -> list[dict]:
        """Query open issues across the configured owners via a GraphQL search query."""
        raw_nodes = self._query_graphql_search_nodes(build_open_issues_graphql_query(owners), timeout=timeout)
        return [norm for node in raw_nodes if (norm := normalize_open_issue_record(node)) is not None]

    def fetch_pull_request_mergeability(
        self,
        node_ids: Iterable[str],
        *,
        batch_size: int = 20,
        timeout: float | None = None,
    ) -> dict[str, dict[str, object]]:
        """Fetch mergeability and latest opinionated reviews in small GraphQL `nodes(ids: ...)` batches."""
        clean_ids: list[str] = []
        seen: set[str] = set()
        for raw_id in node_ids or ():
            nid = str(raw_id or "").strip()
            if nid and nid not in seen and re.fullmatch(r"[A-Za-z0-9_=-]{4,128}", nid):
                seen.add(nid)
                clean_ids.append(nid)
        if not clean_ids:
            return {}
        chunk = max(1, _safe_int(batch_size, 20))
        results: dict[str, dict[str, object]] = {}
        for idx in range(0, len(clean_ids), chunk):
            batch = clean_ids[idx : idx + chunk]
            query = (
                f"query {{ nodes(ids: {json.dumps(batch)}) {{ "
                "... on PullRequest { id mergeable mergeStateStatus "
                "latestOpinionatedReviews(first: 20) { nodes { state author { __typename login } commit { oid } } } "
                "} } }"
            )
            try:
                proc = self.invoke(["graphql", "-f", f"query={query}"], timeout=timeout)
                stdout = (proc.stdout or "").strip()
                if proc.returncode != 0 or not stdout:
                    stderr = (proc.stderr or "").strip()
                    sys.stderr.write(
                        f"moltis-github-companion pr-mergeability-batch warning ({len(batch)} ids): "
                        f"exit {proc.returncode}: {stderr or stdout}\n"
                    )
                    continue
                for payload in parse_gh_api_paginated_http_output(stdout)[2]:
                    if not isinstance(payload, dict) or payload.get("errors"):
                        continue
                    nodes = _as_dict(payload.get("data")).get("nodes")
                    if not isinstance(nodes, list):
                        continue
                    for node in nodes:
                        if not isinstance(node, dict):
                            continue
                        nid = str(node.get("id") or "").strip()
                        if not nid:
                            continue
                        ms = str(node.get("mergeStateStatus") or "").strip().upper()
                        m = normalize_mergeable_state(node.get("mergeable"), ms)
                        reviews = extract_latest_opinionated_reviews(node.get("latestOpinionatedReviews"))
                        results[nid] = {
                            "mergeable": m,
                            "merge_state_status": ms,
                            "latest_opinionated_reviews": reviews,
                        }
            except Exception as exc:
                sys.stderr.write(f"moltis-github-companion pr-mergeability-batch warning ({len(batch)} ids): {exc}\n")
                continue
        return results

    def fetch_issue_stale_details(
        self,
        issues: Iterable[tuple[str, int]],
        *,
        batch_size: int = 20,
        timeout: float | None = None,
    ) -> dict[str, dict]:
        """Fetch stale-issue guard fields in small inline GraphQL batches compatible with `gh-api-safe`."""
        clean_targets: list[tuple[str, int, str]] = []
        seen: set[str] = set()
        for raw_pair in issues or ():
            if not isinstance(raw_pair, (tuple, list)) or len(raw_pair) != 2:
                continue
            try:
                clean_repo, clean_num, _ = self._validate_issue_target(str(raw_pair[0]), _safe_int(raw_pair[1], 0))
            except ValueError:
                continue
            issue_key = make_pr_key(clean_repo, clean_num)
            if issue_key not in seen:
                seen.add(issue_key)
                clean_targets.append((clean_repo, clean_num, issue_key))
        if not clean_targets:
            return {}
        chunk = max(1, _safe_int(batch_size, 20))
        results: dict[str, dict] = {}
        for idx in range(0, len(clean_targets), chunk):
            batch = clean_targets[idx : idx + chunk]
            alias_map: dict[str, str] = {}
            parts: list[str] = []
            for item_idx, (clean_repo, clean_num, issue_key) in enumerate(batch):
                alias = f"i{item_idx}"
                alias_map[alias] = issue_key
                owner, name = clean_repo.split("/", 1)
                parts.append(
                    f"{alias}: repository(owner: {json.dumps(owner)}, name: {json.dumps(name)}) {{ "
                    f"issue(number: {clean_num}) {{ "
                    "state updatedAt "
                    "author { __typename login } "
                    "authorAssociation "
                    "labels(first: 20) { nodes { name } } "
                    "reactions { totalCount } "
                    "comments(last: 30) { totalCount nodes { author { __typename login } authorAssociation createdAt body } } "
                    "timelineItems(first: 20, itemTypes: [CROSS_REFERENCED_EVENT, CONNECTED_EVENT]) { "
                    "nodes { __typename "
                    "... on CrossReferencedEvent { source { __typename ... on PullRequest { number state } } } "
                    "... on ConnectedEvent { subject { __typename ... on PullRequest { number state } } } "
                    "} } "
                    "} }"
                )
            query = f"query {{ {' '.join(parts)} }}"
            try:
                proc = self.invoke(["graphql", "-f", f"query={query}"], timeout=timeout)
                stdout = (proc.stdout or "").strip()
                if proc.returncode != 0 or not stdout:
                    stderr = (proc.stderr or "").strip()
                    sys.stderr.write(
                        f"moltis-github-companion issue-stale-details-batch warning ({len(batch)} issues): "
                        f"exit {proc.returncode}: {stderr or stdout}\n"
                    )
                    continue
                for payload in parse_gh_api_paginated_http_output(stdout)[2]:
                    if not isinstance(payload, dict):
                        continue
                    if payload.get("errors"):
                        sys.stderr.write(
                            f"moltis-github-companion issue-stale-details-batch warning ({len(batch)} issues): "
                            "GraphQL returned partial errors\n"
                        )
                    data_obj = _as_dict(payload.get("data"))
                    if not data_obj:
                        continue
                    for alias, issue_key in alias_map.items():
                        issue_obj = _as_dict(_as_dict(data_obj.get(alias)).get("issue"))
                        if issue_obj:
                            results[issue_key] = issue_obj
            except Exception as exc:
                sys.stderr.write(
                    f"moltis-github-companion issue-stale-details-batch warning ({len(batch)} issues): {exc}\n"
                )
                continue
        return results

    def fetch_haberdasher_sources(
        self,
        *,
        repo: str = DEFAULT_HABERDASHER_CONFIG_REPO,
        path: str = DEFAULT_HABERDASHER_CONFIG_PATH,
        timeout: float | None = None,
    ) -> tuple[str, ...] | None:
        """Fetch and parse `sources` from `haberdasher.yaml` via `gh-api-safe`."""
        clean_repo = (repo or "").strip()
        clean_path = (path or "").strip().lstrip("/")
        endpoint = f"repos/{clean_repo}/contents/{clean_path}"
        try:
            proc = self.invoke([endpoint], timeout=timeout)
        except Exception as exc:
            sys.stderr.write(f"moltis-github-companion haberdasher-sources warning ({clean_repo}/{clean_path}): {exc}\n")
            return None
        stdout = (proc.stdout or "").strip()
        if proc.returncode != 0 or not stdout:
            stderr = (proc.stderr or "").strip()
            sys.stderr.write(
                f"moltis-github-companion haberdasher-sources warning ({clean_repo}/{clean_path}): "
                f"exit {proc.returncode}: {stderr or stdout}\n"
            )
            return None
        try:
            payload = json.loads(stdout)
        except ValueError as exc:
            sys.stderr.write(
                f"moltis-github-companion haberdasher-sources warning ({clean_repo}/{clean_path}): "
                f"invalid JSON: {exc}\n"
            )
            return None
        if not isinstance(payload, dict):
            sys.stderr.write(
                f"moltis-github-companion haberdasher-sources warning ({clean_repo}/{clean_path}): "
                "unexpected non-object contents payload\n"
            )
            return None
        encoding = str(payload.get("encoding") or "").strip().lower()
        raw_content = payload.get("content")
        if not isinstance(raw_content, str):
            sys.stderr.write(
                f"moltis-github-companion haberdasher-sources warning ({clean_repo}/{clean_path}): "
                "missing content in contents payload\n"
            )
            return None
        if encoding == "base64":
            try:
                compact = re.sub(r"\s+", "", raw_content)
                decoded_yaml = base64.b64decode(compact, validate=True).decode("utf-8")
            except Exception as exc:
                sys.stderr.write(
                    f"moltis-github-companion haberdasher-sources warning ({clean_repo}/{clean_path}): "
                    f"base64 decode failed: {exc}\n"
                )
                return None
        elif encoding in ("", "utf-8", "utf8", "none"):
            decoded_yaml = raw_content
        else:
            sys.stderr.write(
                f"moltis-github-companion haberdasher-sources warning ({clean_repo}/{clean_path}): "
                f"unsupported content encoding {encoding!r}\n"
            )
            return None
        return parse_haberdasher_sources_yaml(decoded_yaml)

    def fetch_repo_security_release_status(self, repo: str, *, timeout: float | None = None) -> dict | None:
        """Read-only GraphQL query via `gh-api-safe` for security-patch release gate evaluation."""
        clean_repo = (repo or "").strip().lower()
        if (
            not clean_repo
            or not re.fullmatch(r"[a-z0-9][a-z0-9._-]*/[a-z0-9][a-z0-9._-]*", clean_repo)
            or any(part in (".", "..") for part in clean_repo.split("/"))
            or not is_allowed_notification_repo(clean_repo)
        ):
            raise ValueError(f"Unsupported repository for security release status: {repo!r}")
        owner, name = clean_repo.split("/", 1)
        query = (
            f"query {{ repository(owner: {json.dumps(owner)}, name: {json.dumps(name)}) {{ "
            "isArchived "
            "defaultBranchRef { name target { ... on Commit { oid statusCheckRollup { state } "
            "history(first: 50) { nodes { oid messageHeadline committedDate } } } } } "
            "latestRelease { tagName publishedAt isDraft isPrerelease tagCommit { oid } } "
            "pullRequests(states: MERGED, first: 20, orderBy: { field: UPDATED_AT, direction: DESC }) { "
            "nodes { number title url mergedAt headRefName author { __typename login } labels(first: 10) { nodes { name } } } "
            "} } }"
        )
        try:
            proc = self.invoke(["graphql", "-f", f"query={query}"], timeout=timeout)
            stdout = (proc.stdout or "").strip()
            if proc.returncode != 0 or not stdout:
                stderr = (proc.stderr or "").strip()
                sys.stderr.write(
                    f"moltis-github-companion security-release-status warning ({clean_repo}): "
                    f"exit {proc.returncode}: {stderr or stdout}\n"
                )
                return None
            repo_obj: dict | None = None
            for payload in parse_gh_api_paginated_http_output(stdout)[2]:
                if not isinstance(payload, dict) or payload.get("errors"):
                    continue
                candidate = _as_dict(payload.get("data")).get("repository")
                if isinstance(candidate, dict) and candidate:
                    repo_obj = candidate
                    break
            if repo_obj is None:
                return None
        except Exception as exc:
            sys.stderr.write(f"moltis-github-companion security-release-status warning ({clean_repo}): {exc}\n")
            return None

        is_archived = bool(repo_obj.get("isArchived"))
        default_branch_ref = _as_dict(repo_obj.get("defaultBranchRef"))
        default_branch = str(default_branch_ref.get("name") or "").strip()
        target = _as_dict(default_branch_ref.get("target"))
        head_oid = str(target.get("oid") or "").strip()
        ci_state = normalize_ci_state(target.get("statusCheckRollup"))

        latest_release = _as_dict(repo_obj.get("latestRelease"))
        latest_tag = str(latest_release.get("tagName") or "").strip()
        latest_published_at = str(latest_release.get("publishedAt") or "").strip()
        latest_is_draft = bool(latest_release.get("isDraft"))
        latest_is_prerelease = bool(latest_release.get("isPrerelease"))
        latest_tag_oid = str(_as_dict(latest_release.get("tagCommit")).get("oid") or "").strip()
        _, latest_published_ms = normalize_ts(latest_published_at)

        raw_history_nodes = _as_dict(target.get("history")).get("nodes")
        history_nodes = [n for n in raw_history_nodes if isinstance(n, dict)] if isinstance(raw_history_nodes, list) else []
        tag_oid_in_history = bool(latest_tag_oid and any(str(n.get("oid") or "").strip() == latest_tag_oid for n in history_nodes))
        commits_since_tag: list[dict] = []
        for node in history_nodes:
            node_oid = str(node.get("oid") or "").strip()
            committed_date = str(node.get("committedDate") or "").strip()
            _, committed_ms = normalize_ts(committed_date)
            if latest_tag_oid and node_oid == latest_tag_oid:
                break
            if not tag_oid_in_history and latest_published_ms > 0 and committed_ms > 0 and committed_ms <= latest_published_ms:
                break
            commits_since_tag.append({
                "oid": node_oid,
                "messageHeadline": str(node.get("messageHeadline") or "").strip(),
                "committedDate": committed_date,
            })

        raw_pr_nodes = _as_dict(repo_obj.get("pullRequests")).get("nodes")
        pr_nodes = [n for n in raw_pr_nodes if isinstance(n, dict)] if isinstance(raw_pr_nodes, list) else []
        merged_prs_since_tag: list[dict] = []
        for pr_node in pr_nodes:
            merged_at = str(pr_node.get("mergedAt") or "").strip()
            _, merged_ms = normalize_ts(merged_at)
            if latest_published_ms > 0 and (merged_ms <= 0 or merged_ms <= latest_published_ms):
                continue
            pr_num = _safe_int(pr_node.get("number"), 0)
            merged_prs_since_tag.append({
                "number": pr_num,
                "title": str(pr_node.get("title") or "").strip(),
                "url": str(pr_node.get("url") or "").strip() or (f"https://github.com/{clean_repo}/pull/{pr_num}" if pr_num > 0 else ""),
                "mergedAt": merged_at,
                "merged_at": merged_at,
                "merged_at_ms": merged_ms,
                "headRefName": str(pr_node.get("headRefName") or "").strip(),
                "head_ref": str(pr_node.get("headRefName") or "").strip(),
                "author": extract_actor_login(pr_node.get("author")),
                "labels": extract_label_names(pr_node.get("labels")),
            })

        return {
            "repo": clean_repo,
            "is_archived": is_archived,
            "default_branch": default_branch,
            "head_oid": head_oid,
            "ci_state": ci_state,
            "latest_tag": latest_tag,
            "latest_tag_oid": latest_tag_oid,
            "latest_published_at": latest_published_at,
            "latest_is_draft": latest_is_draft,
            "latest_is_prerelease": latest_is_prerelease,
            "commits_since_tag": commits_since_tag,
            "merged_prs_since_tag": merged_prs_since_tag,
        }

    def fetch_issue_events(self, repo: str, number: int, timeout: float | None = None) -> list[dict]:
        """Fetch issue or pull request events for label-actor verification."""
        return self.fetch_json_items(f"repos/{repo}/issues/{number}/events?per_page=100", paginate=True, timeout=timeout)

    def fetch_issue_timeline(self, repo: str, number: int, timeout: float | None = None) -> list[dict]:
        """Fetch paginated issue or pull request timeline events for commit-to-label freshness verification."""
        return self.fetch_json_items(f"repos/{repo}/issues/{number}/timeline?per_page=100", paginate=True, timeout=timeout)

    def fetch_issue_comments(self, repo: str, number: int, timeout: float | None = None) -> list[dict]:
        """Fetch paginated issue or pull request comments via `gh-api-safe`."""
        clean_repo, _ = self._validate_pr_target(repo, number)
        return self.fetch_json_items(f"repos/{clean_repo}/issues/{_safe_int(number, 0)}/comments?per_page=100", paginate=True, timeout=timeout)

    def is_pull_request_merged(self, repo: str, number: int, timeout: float | None = None) -> bool:
        """Return True only when GitHub `repos/{repo}/pulls/{number}` confirms `merged is True`; fail closed otherwise."""
        clean_repo = (repo or "").strip()
        clean_num = _safe_int(number, 0)
        if not clean_repo or clean_num <= 0:
            return False
        try:
            pr_obj = self.fetch_json_object(f"repos/{clean_repo}/pulls/{clean_num}", paginate=False, timeout=timeout)
        except Exception as exc:
            sys.stderr.write(f"moltis-github-companion pr-merge-check warning ({clean_repo}#{clean_num}): {exc}\n")
            return False
        return isinstance(pr_obj, dict) and pr_obj.get("merged") is True

    @staticmethod
    def _validate_pr_target(repo: str, number: int) -> tuple[str, str]:
        clean_repo = (repo or "").strip()
        if (
            not clean_repo
            or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*", clean_repo)
            or any(part in (".", "..") for part in clean_repo.split("/"))
            or not is_allowed_notification_repo(clean_repo)
        ):
            raise ValueError(f"Unsupported repository for pull request action: {repo!r}")
        clean_num = _safe_int(number, 0)
        if clean_num <= 0:
            raise ValueError(f"Invalid pull request number for action: {number!r}")
        return clean_repo, f"https://github.com/{clean_repo}/pull/{clean_num}"

    @staticmethod
    def _validate_pr_label_target(
        repo: str,
        number: int,
        label: str,
        *,
        allowed_labels: Iterable[str] = TEAM_LABELS,
    ) -> tuple[str, str, str]:
        clean_repo, pr_url = GhApiSafeClient._validate_pr_target(repo, number)
        clean_label = (label or "").strip()
        if clean_label not in tuple(allowed_labels):
            raise ValueError(f"Unsupported pull request team label: {label!r}")
        return clean_repo, pr_url, clean_label

    @staticmethod
    def _validate_issue_target(repo: str, number: int) -> tuple[str, int, str]:
        clean_repo = (repo or "").strip()
        if (
            not clean_repo
            or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*", clean_repo)
            or any(part in (".", "..") for part in clean_repo.split("/"))
            or not is_allowed_notification_repo(clean_repo)
        ):
            raise ValueError(f"Unsupported repository for issue action: {repo!r}")
        clean_num = _safe_int(number, 0)
        if clean_num <= 0:
            raise ValueError(f"Invalid issue number for action: {number!r}")
        return clean_repo, clean_num, f"https://github.com/{clean_repo}/issues/{clean_num}"

    def comment_on_issue(self, repo: str, number: int, body: str, *, timeout: float | None = None) -> subprocess.CompletedProcess:
        """Post a comment on an allowlisted issue via `gh issue comment`."""
        clean_repo, clean_num, issue_url = self._validate_issue_target(repo, number)
        clean_body = str(body or "").strip()
        if not clean_body:
            raise ValueError("Issue comment body must be non-empty")
        cmd = [self.gh_bin, "issue", "comment", str(clean_num), "--repo", clean_repo, "--body", clean_body]
        proc = self.runner(cmd, capture_output=True, text=True, timeout=timeout or self.timeout, check=False)
        if proc.returncode != 0:
            err_text = (proc.stderr or proc.stdout or "").strip()
            raise RuntimeError(f"gh issue comment {issue_url} exited {proc.returncode}: {err_text}")
        return proc

    def close_issue(
        self,
        repo: str,
        number: int,
        *,
        comment: str,
        reason: str = "not planned",
        timeout: float | None = None,
    ) -> subprocess.CompletedProcess:
        """Close an allowlisted issue with a reason and explanation comment via `gh issue close`."""
        clean_repo, clean_num, issue_url = self._validate_issue_target(repo, number)
        clean_comment = str(comment or "").strip()
        if not clean_comment:
            raise ValueError("Issue close comment must be non-empty")
        clean_reason = str(reason or "").strip()
        if clean_reason not in ("not planned", "completed"):
            raise ValueError(f"Unsupported issue close reason: {reason!r}")
        cmd = [
            self.gh_bin,
            "issue",
            "close",
            str(clean_num),
            "--repo",
            clean_repo,
            "--reason",
            clean_reason,
            "--comment",
            clean_comment,
        ]
        proc = self.runner(cmd, capture_output=True, text=True, timeout=timeout or self.timeout, check=False)
        if proc.returncode != 0:
            err_text = (proc.stderr or proc.stdout or "").strip()
            raise RuntimeError(f"gh issue close {issue_url} exited {proc.returncode}: {err_text}")
        return proc

    def post_pull_request_comment(self, repo: str, number: int, body: str, *, timeout: float | None = None) -> subprocess.CompletedProcess:
        """Post a comment on an allowlisted pull request via `gh pr comment`."""
        _, pr_url = self._validate_pr_target(repo, number)
        clean_body = str(body or "").strip()
        if not clean_body:
            raise ValueError("Pull request comment body must be non-empty")
        cmd = [self.gh_bin, "pr", "comment", pr_url, "--body", clean_body]
        proc = self.runner(cmd, capture_output=True, text=True, timeout=timeout or self.timeout, check=False)
        if proc.returncode != 0:
            err_text = (proc.stderr or proc.stdout or "").strip()
            raise RuntimeError(f"gh pr comment {pr_url} exited {proc.returncode}: {err_text}")
        return proc

    def close_pull_request(self, repo: str, number: int, comment: str, *, timeout: float | None = None) -> subprocess.CompletedProcess:
        """Close an allowlisted pull request with an explanation comment via `gh pr close`."""
        _, pr_url = self._validate_pr_target(repo, number)
        clean_comment = str(comment or "").strip()
        if not clean_comment:
            raise ValueError("Pull request close comment must be non-empty")
        cmd = [self.gh_bin, "pr", "close", pr_url, "--comment", clean_comment]
        proc = self.runner(cmd, capture_output=True, text=True, timeout=timeout or self.timeout, check=False)
        if proc.returncode != 0:
            err_text = (proc.stderr or proc.stdout or "").strip()
            raise RuntimeError(f"gh pr close {pr_url} exited {proc.returncode}: {err_text}")
        return proc

    def add_pull_request_label(self, repo: str, number: int, label: str, *, timeout: float | None = None) -> subprocess.CompletedProcess:
        """Apply an allowlisted `team:` label to a pull request via `gh pr edit --add-label`."""
        clean_repo, pr_url, clean_label = self._validate_pr_label_target(repo, number, label)
        cmd = [self.gh_bin, "pr", "edit", pr_url, "--add-label", clean_label]
        proc = self.runner(cmd, capture_output=True, text=True, timeout=timeout or self.timeout, check=False)
        if proc.returncode != 0:
            err_text = (proc.stderr or proc.stdout or "").strip()
            if "not found" in err_text.lower():
                create_cmd = [
                    self.gh_bin,
                    "label",
                    "create",
                    clean_label,
                    "--repo",
                    clean_repo,
                    "--color",
                    "0E8A16",
                    "--description",
                    "Authorise bot merge for verified pull request",
                ]
                create_proc = self.runner(create_cmd, capture_output=True, text=True, timeout=timeout or self.timeout, check=False)
                create_err = (create_proc.stderr or create_proc.stdout or "").strip()
                if create_proc.returncode == 0 or "already exists" in create_err.lower():
                    proc = self.runner(cmd, capture_output=True, text=True, timeout=timeout or self.timeout, check=False)
                    if proc.returncode == 0:
                        return proc
                    err_text = (proc.stderr or proc.stdout or "").strip()
            raise RuntimeError(f"gh pr edit {pr_url} --add-label {clean_label} exited {proc.returncode}: {err_text}")
        return proc

    def remove_pull_request_label(self, repo: str, number: int, label: str, *, timeout: float | None = None) -> subprocess.CompletedProcess:
        """Remove an allowlisted `team:` label (including `team:do-not-merge`) from a pull request via `gh pr edit --remove-label`."""
        _, pr_url, clean_label = self._validate_pr_label_target(
            repo,
            number,
            label,
            allowed_labels=(*TEAM_LABELS, DO_NOT_MERGE_LABEL),
        )
        cmd = [self.gh_bin, "pr", "edit", pr_url, "--remove-label", clean_label]
        proc = self.runner(cmd, capture_output=True, text=True, timeout=timeout or self.timeout, check=False)
        if proc.returncode != 0:
            err_text = (proc.stderr or proc.stdout or "").strip()
            raise RuntimeError(f"gh pr edit {pr_url} --remove-label {clean_label} exited {proc.returncode}: {err_text}")
        return proc

    def add_pull_request_reviewer(
        self,
        repo: str,
        number: int,
        reviewer: str,
        *,
        timeout: float | None = None,
    ) -> subprocess.CompletedProcess:
        """Request a peer agent review on an allowlisted pull request via `gh pr edit --add-reviewer`."""
        _, pr_url = self._validate_pr_target(repo, number)
        clean_reviewer = str(reviewer or "").strip().lower()
        if clean_reviewer not in ("sith-skrye", "sith-zannah", "sith-traya"):
            raise ValueError(f"Unsupported pull request reviewer: {reviewer!r}")
        cmd = [self.gh_bin, "pr", "edit", pr_url, "--add-reviewer", clean_reviewer]
        proc = self.runner(cmd, capture_output=True, text=True, timeout=timeout or self.timeout, check=False)
        if proc.returncode != 0:
            err_text = (proc.stderr or proc.stdout or "").strip()
            raise RuntimeError(f"gh pr edit {pr_url} --add-reviewer {clean_reviewer} exited {proc.returncode}: {err_text}")
        return proc


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
        if not is_instruction and detect_coercion_patterns("\n".join(raw_texts)):
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
        is_auto_pr = False

        def _eval_res(dispatch: bool, skip: str | None, trig: str | None = None, cid: object = None, rid: object = None, tid: object = None) -> dict:
            return {"should_dispatch": dispatch, "skip_reason": skip, "repo": repo, "number": number, "kind": kind_label, "head_sha": head_sha, "trigger_reason": trig or reason, "comment_id": cid, "review_id": rid, "trusted_item_id": tid, "is_automated_pr": is_auto_pr, "security_events": security_events, "notices": notices}

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

        pr_author_norm = normalize_github_actor(self._extract_item_actor(subject_item)) if isinstance(subject_item, dict) and subject_item else ""
        pr_title = str((subject_item or {}).get("title") or notification.get("subject_title") or "")
        pr_head_ref = str(_as_dict((subject_item or {}).get("head")).get("ref") or (subject_item or {}).get("headRefName") or "")
        pr_labels: list[str] = []
        if isinstance(subject_item, dict):
            raw_lbls = subject_item.get("labels")
            if isinstance(raw_lbls, list):
                pr_labels = [str(lbl.get("name") if isinstance(lbl, dict) else lbl).strip() for lbl in raw_lbls if str(lbl.get("name") if isinstance(lbl, dict) else lbl).strip()]
        is_auto_pr = bool(is_pr and is_automated_update_pr(pr_author_norm, repo=repo, head_ref=pr_head_ref, labels=pr_labels, title=pr_title))
        subj_mentions = extract_mentioned_github_agents(strip_html_comments("\n".join(str((subject_item or {}).get(k) or "") for k in ("title", "body")))) if isinstance(subject_item, dict) else set()

        def _check_auto_pr_skip(item_mentions: Iterable[str], fallback_actor: str = "") -> str | None:
            nonlocal is_auto_pr
            if not is_pr:
                return None
            eff_author = pr_author_norm or normalize_github_actor(fallback_actor)
            if is_automated_update_pr(eff_author, repo=repo, head_ref=pr_head_ref, labels=pr_labels, title=pr_title):
                is_auto_pr = True
            all_mentions = (set(item_mentions) if is_trusted_instruction_actor(fallback_actor) else set()) | (subj_mentions if is_trusted_instruction_actor(pr_author_norm) else set())
            if self.agent_name in all_mentions:
                return None
            if not is_auto_pr:
                return None
            if self.agent_name == "traya":
                return "bot_update_ignored_for_traya"
            if self.agent_name in SWEEP_AGENT_ORDER and repo and number and compute_automated_pr_owner(repo, number) != self.agent_name:
                return "unowned_automated_pr"
            return None

        if isinstance(latest_item, dict) and latest_item:
            latest_url = str(notification.get("latest_comment_url") or "")
            item_kind = "pull_request_review" if ("/reviews/" in latest_url or "submitted_at" in latest_item) else ("pull_request_review_comment" if ("/pulls/comments/" in latest_url or "pull_request_review_id" in latest_item) else "issue_comment")
            insp = self.inspect_item(repo=repo, subject_type=kind_label, number=number, thread_id=thread_id, item_kind=item_kind, item=latest_item, stamp_ms=stamp_ms)
            security_events.extend(insp["security_events"])
            notices.extend(insp["notices"])
            if not insp["should_trigger"]:
                return _eval_res(False, insp["skip_reason"])
            mentioned_agents = insp.get("mentioned_agents") or []
            if auto_skip := _check_auto_pr_skip(mentioned_agents, str(insp.get("actor") or "")):
                return _eval_res(False, auto_skip)
            if is_pr and item_kind in ("pull_request_review", "pull_request_review_comment", "issue_comment"):
                cached_entry = _as_dict(self.state_store.get_thread_state(make_pr_key(repo, number)) if (repo and number) else None) or _as_dict(self.state_store.get_thread_state(thread_id))
                handled_sha = str(notification.get("handled_head_sha") or cached_entry.get("handled_head_sha") or "").strip() or None
                actor_norm = normalize_github_actor(insp.get("actor"))
                if handled_sha and head_sha and handled_sha == head_sha and self.agent_name not in mentioned_agents and (self._is_peer_agent_actor(actor_norm, self.agent_name) or bool(insp.get("bot_trusted"))):
                    return _eval_res(False, "unmentioned_peer_or_bot_comment_on_handled_sha")
            item_id, is_rev = insp["item_id"], item_kind == "pull_request_review"
            return _eval_res(True, None, reason or ("trusted_review" if is_rev else "trusted_comment"), None if is_rev else item_id, item_id if is_rev else None, item_id)

        if isinstance(subject_item, dict) and subject_item:
            insp = self.inspect_item(repo=repo, subject_type=kind_label, number=number, thread_id=thread_id, item_kind="pull_request" if is_pr else "issue", item=subject_item, stamp_ms=stamp_ms)
            security_events.extend(insp["security_events"])
            notices.extend(insp["notices"])
            if not insp["should_trigger"]:
                return _eval_res(False, insp["skip_reason"])
            if auto_skip := _check_auto_pr_skip(insp.get("mentioned_agents") or [], str(insp.get("actor") or "")):
                return _eval_res(False, auto_skip)
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

    def __init__(self, state_store: CompanionStateStore, gh_client: GhApiSafeClient, read_only_trial: bool = False, clock: Callable[[], int] = now_ms, sleeper: Callable[[float], None] = time.sleep, jitter_rng: Callable[[int, int], int] | None = None, on_actionable_threads: Callable[[list[str]], None] | None = None, poll_interval_minutes: int | None = None):
        self.state_store = state_store
        self.gh_client = gh_client
        self.read_only_trial = bool(read_only_trial)
        self.clock = clock
        self.sleeper = sleeper
        self.jitter_rng = jitter_rng
        self.on_actionable_threads = on_actionable_threads
        self.poll_interval_minutes = resolve_poll_interval_minutes(poll_interval_minutes) if poll_interval_minutes is not None else None

    @staticmethod
    def _effective_next_poll_at_ms(poll_state: dict, poll_interval_minutes: int | None = None) -> int | None:
        next_poll_at_ms = poll_state.get("next_poll_at_ms")
        if not isinstance(next_poll_at_ms, int):
            return None
        last_status, last_completed_ms = poll_state.get("last_status"), poll_state.get("last_poll_completed_at_ms")
        if last_status in (200, 304) and not bool(poll_state.get("last_poll_rate_limited", False)) and _safe_int(poll_state.get("retry_after_secs"), 0) <= 0 and isinstance(last_completed_ms, int):
            agent_name = str(poll_state.get("agent_name") or "skrye")
            poll_interval_secs = max(0, _safe_int(poll_state.get("poll_interval_secs"), 0))
            header_floor_ms = (last_completed_ms + (poll_interval_secs * 1000)) if poll_interval_secs > 0 else 0
            slot_ms = max(compute_next_poll_slot_ms(last_completed_ms, agent_name, poll_interval_minutes=poll_interval_minutes), header_floor_ms)
            return min(next_poll_at_ms, slot_ms)
        return next_poll_at_ms

    MAX_SLEEP_CHUNK_MS = 60_000

    def wait_until_due(self, now_override_ms: int | None = None, max_chunk_ms: int = MAX_SLEEP_CHUNK_MS) -> int:
        """Sleep in bounded chunks until persisted next_poll_at_ms is reached, re-checking the wall clock each chunk."""
        next_poll_at_ms = self._effective_next_poll_at_ms(self.state_store.read_state(), poll_interval_minutes=self.poll_interval_minutes)
        if not isinstance(next_poll_at_ms, int):
            return 0
        chunk_limit_ms = max(1, _safe_int(max_chunk_ms, self.MAX_SLEEP_CHUNK_MS))
        if now_override_ms is not None:
            current_ms = _safe_int(now_override_ms, self.clock())
            remaining_ms = next_poll_at_ms - current_ms
            if remaining_ms <= 0:
                return 0
            total_slept_ms = 0
            while remaining_ms > 0:
                chunk_ms = min(remaining_ms, chunk_limit_ms)
                self.sleeper(chunk_ms / 1000.0)
                total_slept_ms += chunk_ms
                remaining_ms -= chunk_ms
            return total_slept_ms

        total_slept_ms = 0
        while True:
            current_ms = self.clock()
            remaining_ms = next_poll_at_ms - current_ms
            if remaining_ms <= 0:
                return total_slept_ms
            chunk_ms = min(remaining_ms, chunk_limit_ms)
            self.sleeper(chunk_ms / 1000.0)
            total_slept_ms += chunk_ms

    wait_for_startup_slot = wait_until_next_poll = wait_until_due

    def _persist_provisional_next_poll(self, current_ms: int) -> tuple[int, int]:
        provisional_next_ms = compute_next_poll_slot_ms(current_ms, self.state_store.agent_name, poll_interval_minutes=self.poll_interval_minutes)
        self.state_store.write_state({"last_poll_started_at_ms": current_ms, "next_poll_at_ms": provisional_next_ms, "last_jitter_ms": 0}, now_override_ms=current_ms)
        return provisional_next_ms, 0

    def poll_once(self, now_override_ms: int | None = None, poll_open_prs: bool = True, poll_open_issues: bool = True) -> dict:
        """Execute one conditional /notifications poll plus the 6-owner open PR and issue polls."""
        start_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        prior_last_modified = self.state_store.read_state().get("last_modified")
        provisional_next_ms, provisional_jitter_ms = self._persist_provisional_next_poll(start_ms)
        status, headers, raw_items = self.gh_client.poll_notifications(last_modified=prior_last_modified if isinstance(prior_last_modified, str) else None)
        finish_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        wait_ms, base_wait_sec, post_jitter_ms = compute_backoff_wait_ms(headers=headers, now_ms_val=finish_ms, rng=self.jitter_rng, status=status, agent_name=self.state_store.agent_name, poll_interval_minutes=self.poll_interval_minutes)
        computed_next_poll_ms = finish_ms + wait_ms

        filtered_records, actionable_threads, queued_followups, dismissed_threads = [], [], [], []
        actionable_prs, open_pull_requests, actionable_issues, open_issues = [], [], [], []
        team_label_candidates, coercive_items, signoff_ready_prs = [], [], []
        if 200 <= status < 300:
            filtered_records = [norm for item in raw_items if (norm := normalize_notification_record(item)) is not None]
            ingest_result = self.state_store.record_polled_notifications(filtered_records, now_override_ms=finish_ms)
            actionable_threads, queued_followups = list(ingest_result["actionable_threads"]), list(ingest_result["queued_followups"])
            if not self.read_only_trial:
                for tid in ingest_result.get("auto_dismiss_threads") or []:
                    with contextlib.suppress(Exception):
                        self.gh_client.dismiss_notification(tid)
                        dismissed_threads.append(tid)

        poll_interval_hdr = max(0, _safe_int(headers.get("x-poll-interval"), 0))
        retry_after_hdr = parse_retry_after_seconds(headers.get("retry-after"), finish_ms // 1000)
        remaining_hdr = headers.get("x-ratelimit-remaining")
        remaining_exhausted = remaining_hdr is not None and str(remaining_hdr).strip() != "" and _safe_int(remaining_hdr, 1) <= 0
        is_rate_limited = bool(status in (403, 429) or remaining_exhausted or retry_after_hdr > 0)

        open_prs_poll_error: str | None = None
        open_issues_poll_error: str | None = None
        if poll_open_prs and not is_rate_limited:
            try:
                if poll_open_issues and hasattr(self.gh_client, "poll_open_items"):
                    open_pull_requests, open_issues = self.gh_client.poll_open_items()
                else:
                    open_pull_requests = self.gh_client.poll_open_pull_requests()
            except Exception as exc:
                open_prs_poll_error = str(exc) or exc.__class__.__name__
            if open_pull_requests:
                pr_ingest = self.state_store.record_polled_pull_requests(open_pull_requests, self_github_login=GITHUB_AGENT_LOGINS[self.state_store.agent_name], now_override_ms=finish_ms)
                actionable_prs = list(pr_ingest["actionable_prs"])
                signoff_ready_prs = list(pr_ingest.get("signoff_ready_prs") or [])
                team_label_candidates.extend(pr_ingest.get("team_label_candidates") or [])
                coercive_items.extend(pr_ingest.get("coercive_items") or [])
                for qf in pr_ingest["queued_followups"]:
                    if qf not in queued_followups:
                        queued_followups.append(qf)
            if open_issues:
                issue_ingest = self.state_store.record_polled_issues(open_issues, now_override_ms=finish_ms)
                actionable_issues = list(issue_ingest["actionable_issues"])
                team_label_candidates.extend(issue_ingest.get("team_label_candidates") or [])
                coercive_items.extend(issue_ingest.get("coercive_items") or [])
                for qf in issue_ingest["queued_followups"]:
                    if qf not in queued_followups:
                        queued_followups.append(qf)

        new_last_modified = headers["last-modified"].strip() if (200 <= status < 300 and isinstance(headers.get("last-modified"), str) and headers["last-modified"].strip()) else prior_last_modified
        ratelimit_reset_hdr = (_safe_int(headers.get("x-ratelimit-reset"), 0) or None) if is_rate_limited else None
        self.state_store.write_state({"last_poll_completed_at_ms": finish_ms, "last_status": status, "last_modified": new_last_modified, "next_poll_at_ms": computed_next_poll_ms, "poll_interval_secs": poll_interval_hdr, "retry_after_secs": retry_after_hdr, "last_poll_rate_limited": is_rate_limited, "ratelimit_reset_epoch": ratelimit_reset_hdr, "last_jitter_ms": post_jitter_ms, "last_open_prs_poll_error": open_prs_poll_error, "last_open_issues_poll_error": open_issues_poll_error}, now_override_ms=finish_ms)

        dispatched_threads: list[str] = []
        if not self.read_only_trial and actionable_threads and self.on_actionable_threads is not None:
            self.on_actionable_threads(actionable_threads)
            dispatched_threads = list(actionable_threads)

        return {"status": status, "provisional_next_poll_at_ms": provisional_next_ms, "provisional_jitter_ms": provisional_jitter_ms, "next_poll_at_ms": computed_next_poll_ms, "base_wait_secs": base_wait_sec, "jitter_ms": post_jitter_ms, "last_modified": new_last_modified, "filtered_notifications": filtered_records, "open_pull_requests": open_pull_requests, "open_prs_poll_error": open_prs_poll_error, "open_issues": open_issues, "open_issues_poll_error": open_issues_poll_error, "actionable_threads": actionable_threads, "actionable_prs": actionable_prs, "actionable_issues": actionable_issues, "signoff_ready_prs": signoff_ready_prs, "team_label_candidates": team_label_candidates, "coercive_items": coercive_items, "dismissed_threads": dismissed_threads, "queued_followups": queued_followups, "dispatched_threads": dispatched_threads, "read_only_trial": self.read_only_trial}


class LocalExecutionCoordinator:
    """Serialise all targeted turns, 6-hour reconciliation sweeps, and weekly sweeps under coordinator.lock and active-dispatch.json."""

    def __init__(self, state_store: CompanionStateStore, rpc_client: MoltisRpcClient, data_dir: Path | str, agent_name: str, agent_display_name: str = "", update_model: str = "", sweep_model: str = "", code_model: str = "", matrix_client: MatrixClient | None = None, telegram_client: TelegramClient | None = None, telegram_bot_token_path: Path | str | None = None, telegram_allowed_users_path: Path | str | None = None, telegram_api_url: str = DEFAULT_TELEGRAM_API_URL, session_key: str = DEFAULT_GH_SESSION_KEY, room_id: str = DEFAULT_ROOM_ID, schedule_dow: int | None = None, schedule_day_name: str = "", completion_timeout_ms: int | None = None, recovery_deadline_ms: int | None = None, completion_wait_timeout_secs: float | None = None, recovery_wait_timeout_secs: float | None = None, rpc_timeout_secs: float = DEFAULT_RPC_TIMEOUT_SECS, poll_interval_ms: int = DEFAULT_COMPLETION_POLL_INTERVAL_MS, clock: Callable[[], int] = now_ms, sleeper: Callable[[float], None] = time.sleep, linear_client: linear_sync.LinearSyncClient | None = None, gh_client: GhApiSafeClient | None = None, shadow_worker: shadow_eval.ShadowEvalWorker | None = None):
        self.state_store = state_store
        self.rpc_client = rpc_client
        self.data_dir = Path(data_dir)
        self.agent_name = normalize_agent_name(agent_name)
        self.agent_display_name = derive_display_name(self.agent_name, agent_display_name)
        self.update_model, self.sweep_model, self.code_model = resolve_model_tiers(
            update_model=update_model,
            sweep_model=sweep_model,
            code_model=code_model,
        )
        self.matrix_client = matrix_client
        self.telegram_client = telegram_client or (TelegramClient(bot_token_path=telegram_bot_token_path, allowed_users_path=telegram_allowed_users_path, api_url=telegram_api_url) if (telegram_bot_token_path or telegram_allowed_users_path) else None)
        self.linear_client = linear_client
        self.gh_client = gh_client
        self.shadow_worker = shadow_worker
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

    def build_dispatch_prompt(self, *, dispatch_id: str, kind: str, thread_id: str | None = None, repo: str | None = None, number: int | None = None, subject_kind: str | None = None, head_sha: str | None = None, trigger_reason: str | None = None, comment_id: int | str | None = None, review_id: int | str | None = None, trusted_item_id: int | str | None = None, community_auto_merge_eligible: bool | None = None, team_label: str | None = None, triaged_head_sha: str | None = None, head_sha_changed: bool = False, linear_issue_id: str | None = None, linear_issue_identifier: str | None = None, linear_issue_url: str | None = None, linear_issue_estimate: int | None = None, linear_comment_id: str | None = None, linear_comment_parent_id: str | None = None, linear_comment_author: str | None = None, operator_guidance: Iterable[dict[str, str]] | None = None, github_url: str | None = None, bypass_reasons: Iterable[str] | None = None, lane_a_polish_notes: str | None = None, extra_instructions: str = "") -> str:
        header = f"# {self.agent_display_name} Scheduled Maintenance Heartbeat"
        meta_lines = [f"dispatch_id: {dispatch_id}", f"dispatch_kind: {kind}", f"agent_name: {self.agent_name}", f"schedule_day_name: {self.schedule_day_name}", f"schedule_dow: {self.schedule_dow}"]
        if thread_id:
            meta_lines.append(f"thread_id: {thread_id}")
        if kind == "targeted" or kind in MODE_1B_DISPATCH_KINDS or repo or number:
            eff_item_id = trusted_item_id if trusted_item_id is not None else (comment_id or review_id)
            meta_lines.extend([f"repo: {repo or ''}", f"number: {number if number is not None else ''}", f"kind: {subject_kind or 'PullRequest'}", f"head_sha: {head_sha or ''}", f"trigger_reason: {trigger_reason or 'notification'}"])
            if comment_id is not None and str(comment_id).strip():
                meta_lines.append(f"comment_id: {comment_id}")
            if review_id is not None and str(review_id).strip():
                meta_lines.append(f"review_id: {review_id}")
            if eff_item_id is not None and str(eff_item_id).strip():
                meta_lines.append(f"trusted_item_id: {eff_item_id}")
            if community_auto_merge_eligible is not None:
                meta_lines.append(f"community_auto_merge_eligible: {'true' if community_auto_merge_eligible else 'false'}")
            if team_label:
                meta_lines.append(f"team_label: {team_label}")
            if triaged_head_sha:
                meta_lines.append(f"triaged_head_sha: {triaged_head_sha}")
            if head_sha_changed:
                meta_lines.append("head_sha_changed: true")
        for meta_key, meta_val in (
            ("linear_issue_id", linear_issue_id),
            ("linear_issue_identifier", linear_issue_identifier),
            ("linear_issue_url", linear_issue_url),
            ("linear_comment_id", linear_comment_id),
            ("linear_comment_parent_id", linear_comment_parent_id),
            ("linear_comment_author", linear_comment_author),
            ("github_url", github_url),
        ):
            clean_val = str(meta_val).strip() if meta_val is not None else ""
            if clean_val:
                meta_lines.append(f"{meta_key}: {clean_val}")
        if (
            linear_issue_estimate is not None
            and not isinstance(linear_issue_estimate, bool)
            and _safe_int(linear_issue_estimate, 0) > 0
        ):
            meta_lines.append(f"linear_issue_estimate: {_safe_int(linear_issue_estimate, 0)}")
        clean_bypass = [str(r).strip() for r in (bypass_reasons or ()) if str(r or "").strip()]
        if clean_bypass:
            meta_lines.append(f"bypass_reasons: {', '.join(clean_bypass)}")
        clean_polish = _normalize_optional_polish(lane_a_polish_notes or "")
        if clean_polish and kind != "community_pr_blind_review":
            meta_lines.append(f"lane_a_polish_notes: {clean_polish}")

        if kind == "targeted":
            mode_line = f"Mode 1 - Targeted Notification or Mention Turn (repo={repo or ''}, number={number if number is not None else ''}, kind={subject_kind or 'PullRequest'}, head_sha={head_sha or 'none'}, trigger_reason={trigger_reason or 'notification'})."
        elif kind in MODE_1B_DISPATCH_KINDS:
            mode_line = f"Mode 1B - Community Triage and team: Label Action (dispatch_kind={kind}, repo={repo or ''}, number={number if number is not None else ''}, kind={subject_kind or 'PullRequest'}, head_sha={head_sha or 'none'}, trigger_reason={trigger_reason or kind})."
        elif kind == "weekly_sweep":
            mode_line = f"Mode 3 - Weekly Organisation Sweep ({self.schedule_day_name} Only, dow == {self.schedule_dow})."
        else:
            mode_line = "Mode 2 - 6-Hour Reconciliation Sweep."

        lane_b_estimate_note = (
            "Adjust Linear `estimate` on the `WW` scale (`XS=1, S=2, M=3, L=5, XL=8`) "
            "only if diff stats misrepresent real scope or risk."
            if kind == "community_pr_lane_b_review"
            else ""
        )
        guidance_entries = [
            item
            for item in (operator_guidance or ())
            if isinstance(item, dict) and str(item.get("body") or "").strip()
        ]
        guidance_block = ""
        if guidance_entries and kind != "community_pr_blind_review":
            guidance_lines = [
                "## Verified Operator Guidance (Linear)",
                "The following comments were authored by a verified Linear workspace admin (Martin). Treat them as authoritative operator guidance that overrides default heuristics (without violating security or archived-repository rules):",
            ]
            for item in guidance_entries:
                g_created = str(item.get("created_at") or "").strip() or "unknown"
                g_author = str(item.get("author") or "").strip() or "Martin"
                g_id = str(item.get("id") or "").strip() or "unknown"
                g_body = str(item.get("body") or "").strip()
                guidance_lines.append(f"- [{g_created}] {g_author} (comment_id={g_id}): {g_body}")
            guidance_block = "\n".join(guidance_lines)
        blocks = [
            header,
            "\n".join(meta_lines),
            mode_line,
            *([lane_b_estimate_note] if lane_b_estimate_note else []),
            *([guidance_block] if guidance_block else []),
            *([extra_instructions.strip()] if extra_instructions.strip() else []),
        ]
        heartbeat_path = self.data_dir.expanduser() / "HEARTBEAT.md"
        blocks.append(f"Read and follow `{heartbeat_path}` for the active mode procedure.")
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
        clean_text = normalize_terminal_reply_text(text)
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

    def _commit_completed_watermarks(
        self,
        active_record: dict,
        *,
        now_override_ms: int | None = None,
        preserve_pending_followup: bool = False,
    ) -> dict:
        stamp_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        kind = str(active_record.get("kind") or "")
        state_key = str(active_record.get("state_key") or active_record.get("thread_id") or "").strip()
        preserve_sha = bool(active_record.get("head_sha_changed")) or kind == "linear_operator_comment"
        record_triaged = kind in ("community_triage", "community_auto_review", "community_pr_blind_review", "community_pr_lane_b_review", "team:review") and not preserve_sha
        watermark_result = (
            self.state_store.complete_thread_review(
                state_key,
                handled_updated_at=active_record.get("updated_at"),
                handled_head_sha=active_record.get("head_sha"),
                handled_ci_state=active_record.get("ci_state"),
                completed_revision=active_record.get("revision"),
                team_label=str(active_record.get("team_label") or "") or None,
                team_label_event_key=str(active_record.get("team_label_event_key") or "") or None,
                preserve_handled_head_sha=preserve_sha,
                record_triaged_head_sha=record_triaged,
                apply_cooldown=True,
                preserve_pending_followup=preserve_pending_followup,
                now_override_ms=stamp_ms,
            )
            if state_key
            else None
        )
        if kind in SWEEP_DISPATCH_KINDS:
            self.state_store.complete_sweep(kind, sweep_date=str(active_record["sweep_date"]).strip() if active_record.get("sweep_date") else None, now_override_ms=stamp_ms)
        return {"watermark": watermark_result, "queued_followup": bool(_as_dict(watermark_result).get("pending_followup"))}

    def _clear_active_dispatch_if_matching(self, active_record: dict, *, now_override_ms: int | None = None) -> None:
        dispatch_id = str(active_record.get("dispatch_id") or "").strip()
        current = self.state_store.read_active_dispatch().get("active")
        if not isinstance(current, dict) or not dispatch_id or str(current.get("dispatch_id") or "").strip() == dispatch_id:
            self.state_store.write_active_dispatch(None, now_override_ms=now_override_ms)

    def _fetch_linear_issue_state(self, linear_id: str) -> tuple[str | None, Exception | None]:
        """Fetch a Linear issue's lowercased workflow state name with one retry on transient failure."""
        return _fetch_linear_issue_state_with_retry(self.linear_client, linear_id)

    def _revert_stranded_linear_todo_on_recovery(self, active_record: dict) -> tuple[bool, bool, str | None]:
        """Reconcile a linear_todo_implement issue on recovery; return (reverted, reconciled, error)."""
        if self.linear_client is None or active_record.get("kind") != "linear_todo_implement":
            return False, True, None
        linear_issue_id = str(active_record.get("linear_issue_id") or "").strip()
        if not linear_issue_id:
            return False, True, None
        post_state_name, verify_exc = self._fetch_linear_issue_state(linear_issue_id)
        if _is_linear_issue_not_found_error(verify_exc):
            return False, True, None
        if verify_exc is not None or not post_state_name:
            detail = str(verify_exc) if verify_exc is not None else "missing workflow state in Linear response"
            sys.stderr.write(f"moltis-github-companion linear-todo-recovery-verify warning ({active_record.get('state_key') or linear_issue_id} / {linear_issue_id}): {detail}\n")
            return False, False, f"linear_todo_recovery_verify_failed: {detail}"
        if post_state_name not in ("in progress", "in_progress"):
            return False, True, None
        try:
            self.linear_client.update_issue(linear_issue_id, state="Todo")
        except Exception as exc:
            if _is_linear_issue_not_found_error(exc):
                return False, True, None
            sys.stderr.write(f"moltis-github-companion linear-todo-recovery-revert warning ({active_record.get('state_key') or linear_issue_id} / {linear_issue_id}): {exc}\n")
            return False, False, f"linear_todo_recovery_revert_failed: {exc}"
        return True, True, None

    def defer_linear_todo_verification(
        self,
        dispatch_result: dict,
        *,
        verification_error: str,
        failure_reason: str | None = None,
        now_override_ms: int | None = None,
    ) -> dict:
        """Retain active-dispatch.json marked verification_deferred when post-turn Linear verification or rollback fails."""
        active_record = _as_dict(dispatch_result.get("_deferred_active_record"))
        clean_error = str(verification_error or "linear_todo_state_verify_failed").strip()
        clean_failure = str(failure_reason or "").strip() if failure_reason is not None else ""
        if active_record:
            with self.state_store.coordinator_lock():
                stamp_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
                current = self.state_store.read_active_dispatch().get("active")
                dispatch_id = str(active_record.get("dispatch_id") or "").strip()
                current_dispatch_id = str(current.get("dispatch_id") or "").strip() if isinstance(current, dict) else ""
                if isinstance(current, dict) and dispatch_id and current_dispatch_id == dispatch_id:
                    updated_active = dict(current)
                    updated_active["verification_deferred"] = True
                    updated_active["verification_error"] = clean_error
                    if clean_failure:
                        updated_active["deferred_failure_reason"] = clean_failure
                    self.state_store.write_active_dispatch(updated_active, now_override_ms=stamp_ms)
                else:
                    linear_issue_id = str(active_record.get("linear_issue_id") or "").strip()
                    if linear_issue_id and active_record.get("kind") == "linear_todo_implement":
                        self.state_store.enqueue_linear_todo_reconciliation(
                            linear_issue_id,
                            str(active_record.get("state_key") or active_record.get("thread_id") or "").strip() or None,
                            dispatch_id=dispatch_id or None,
                            reason=clean_error,
                            now_override_ms=stamp_ms,
                        )
        dispatch_result.pop("_deferred_active_record", None)
        dispatch_result["verification_deferred"] = True
        dispatch_result["verification_error"] = clean_error
        if clean_failure:
            dispatch_result["status"] = "failed"
            dispatch_result["task_succeeded"] = False
            dispatch_result["failure_reason"] = clean_failure
        elif dispatch_result.get("task_succeeded"):
            dispatch_result["status"] = "unverified"
        else:
            dispatch_result["status"] = "failed"
            dispatch_result["task_succeeded"] = False
        return dispatch_result

    def _finalize_recovery_failure(
        self,
        active_record: dict,
        *,
        failure_reason: str,
        now_override_ms: int,
    ) -> tuple[dict, bool, bool, str, int]:
        """Reconcile any stranded linear_todo_implement issue on recovery and finalize or defer active-dispatch.json."""
        linear_todo_reverted, reconciled, rec_err = self._revert_stranded_linear_todo_on_recovery(active_record)
        if reconciled:
            fin = self._finalize_failed_dispatch(active_record, failure_reason=failure_reason, now_override_ms=now_override_ms)
            return fin, linear_todo_reverted, False, failure_reason, _safe_int(active_record.get("linear_recovery_attempts"), 0)

        attempts = _safe_int(active_record.get("linear_recovery_attempts"), 0) + 1
        err_reason = rec_err or "linear_todo_recovery_failed"
        if attempts < MAX_LINEAR_TODO_RECOVERY_ATTEMPTS:
            updated_active = dict(active_record)
            updated_active["verification_deferred"] = True
            updated_active["linear_recovery_attempts"] = attempts
            updated_active["verification_error"] = err_reason
            updated_active.setdefault("deferred_failure_reason", failure_reason)
            self.state_store.write_active_dispatch(updated_active, now_override_ms=now_override_ms)
            state_key = str(active_record.get("state_key") or active_record.get("thread_id") or "").strip()
            watermark_result = self.state_store.get_thread_state(state_key) if state_key else None
            fin = {"watermark": watermark_result, "queued_followup": bool(_as_dict(watermark_result).get("pending_followup"))}
            return fin, False, True, err_reason, attempts

        sys.stderr.write(
            f"moltis-github-companion linear-todo-recovery-exhausted warning "
            f"({active_record.get('state_key') or active_record.get('linear_issue_id')} / {active_record.get('linear_issue_id')}): "
            f"{err_reason} after {attempts} attempts\n"
        )
        exhausted_reason = f"linear_todo_recovery_exhausted: {err_reason}"
        linear_issue_id = str(active_record.get("linear_issue_id") or "").strip()
        if linear_issue_id and active_record.get("kind") == "linear_todo_implement":
            self.state_store.enqueue_linear_todo_reconciliation(
                linear_issue_id,
                str(active_record.get("state_key") or active_record.get("thread_id") or "").strip() or None,
                dispatch_id=str(active_record.get("dispatch_id") or "").strip() or None,
                reason=exhausted_reason,
                now_override_ms=now_override_ms,
            )
        fin = self._finalize_failed_dispatch(active_record, failure_reason=exhausted_reason, now_override_ms=now_override_ms)
        return fin, False, False, exhausted_reason, attempts

    def _finalize_completed_dispatch(
        self,
        active_record: dict,
        now_override_ms: int | None = None,
        *,
        defer_watermark_commit: bool = False,
    ) -> dict:
        stamp_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        if defer_watermark_commit:
            state_key = str(active_record.get("state_key") or active_record.get("thread_id") or "").strip()
            watermark_result = self.state_store.get_thread_state(state_key) if state_key else None
            return {"watermark": watermark_result, "queued_followup": bool(_as_dict(watermark_result).get("pending_followup"))}
        fin = self._commit_completed_watermarks(active_record, now_override_ms=stamp_ms)
        self.state_store.write_active_dispatch(None, now_override_ms=stamp_ms)
        return fin

    def commit_deferred_dispatch(self, dispatch_result: dict, *, now_override_ms: int | None = None) -> dict:
        """Commit thread watermarks and clear active-dispatch.json for a dispatch completed with defer_watermark_commit=True."""
        active_record = _as_dict(dispatch_result.get("_deferred_active_record"))
        if not active_record:
            dispatch_result["watermark_deferred"] = False
            return {"watermark": dispatch_result.get("watermark"), "queued_followup": bool(dispatch_result.get("queued_followup"))}
        with self.state_store.coordinator_lock():
            stamp_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
            fin = self._commit_completed_watermarks(active_record, now_override_ms=stamp_ms, preserve_pending_followup=True)
            self._clear_active_dispatch_if_matching(active_record, now_override_ms=stamp_ms)
        dispatch_result.pop("_deferred_active_record", None)
        dispatch_result["watermark_deferred"] = False
        dispatch_result["watermark"] = fin["watermark"]
        dispatch_result["queued_followup"] = fin["queued_followup"]
        return fin

    def fail_deferred_dispatch(self, dispatch_result: dict, *, failure_reason: str | None = None, now_override_ms: int | None = None) -> dict:
        """Record a post-turn failure and clear active-dispatch.json for a deferred dispatch without advancing handled watermarks."""
        active_record = _as_dict(dispatch_result.get("_deferred_active_record"))
        if not active_record:
            dispatch_result["watermark_deferred"] = False
            return {"watermark": dispatch_result.get("watermark"), "queued_followup": bool(dispatch_result.get("queued_followup"))}
        with self.state_store.coordinator_lock():
            stamp_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
            kind = str(active_record.get("kind") or "")
            state_key = str(active_record.get("state_key") or active_record.get("thread_id") or "").strip()
            reason = (failure_reason or "post_turn_write_failed").strip()
            watermark_result = self.state_store.fail_thread_review(state_key, failure_reason=reason, now_override_ms=stamp_ms) if state_key else None
            if kind in SWEEP_DISPATCH_KINDS:
                self.state_store.fail_sweep(kind, failure_reason=reason, attempt_at_ms=_safe_int(active_record.get("started_at_ms"), 0) or None, now_override_ms=stamp_ms)
            self._clear_active_dispatch_if_matching(active_record, now_override_ms=stamp_ms)
        dispatch_result.pop("_deferred_active_record", None)
        dispatch_result["watermark_deferred"] = False
        queued = bool(_as_dict(watermark_result).get("pending_followup"))
        dispatch_result["watermark"] = watermark_result
        dispatch_result["queued_followup"] = queued
        dispatch_result["status"] = "failed"
        dispatch_result["task_succeeded"] = False
        dispatch_result["failure_reason"] = reason
        return {"watermark": watermark_result, "queued_followup": queued}

    def _finalize_failed_dispatch(self, active_record: dict, failure_reason: str | None = None, now_override_ms: int | None = None) -> dict:
        """Clear active-dispatch.json after a failed or interrupted turn and increment retry_count up to 3."""
        stamp_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        kind = str(active_record.get("kind") or "")
        state_key = str(active_record.get("state_key") or active_record.get("thread_id") or "").strip()
        watermark_result = self.state_store.fail_thread_review(state_key, failure_reason=failure_reason, now_override_ms=stamp_ms) if state_key else None
        if kind in SWEEP_DISPATCH_KINDS:
            self.state_store.fail_sweep(kind, failure_reason=failure_reason, attempt_at_ms=_safe_int(active_record.get("started_at_ms"), 0) or None, now_override_ms=stamp_ms)
        self.state_store.write_active_dispatch(None, now_override_ms=stamp_ms)
        return {"watermark": watermark_result, "queued_followup": bool(_as_dict(watermark_result).get("pending_followup"))}

    def _resolve_turn_outcome(self, active_record: dict, check: dict, *, rpc_response: dict | None = None, rpc_error: Exception | None = None, recovery: dict | None = None, start_notice: tuple[bool, str, str | None] | None = None, is_recovery: bool = False, defer_watermark_commit: bool = False, now_override_ms: int | None = None) -> dict:
        stamp_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        dispatch_id = str(active_record.get("dispatch_id") or "")
        session_key = str(active_record.get("session_key") or self.session_key)
        defer_commit = bool(defer_watermark_commit or active_record.get("defer_watermark_commit"))
        defer_failure = bool(defer_commit and not is_recovery and active_record.get("kind") == "linear_todo_implement")
        reply_text = ""
        task_succeeded, failure_reason, tg_ok, tg_err = False, None, False, None
        linear_todo_reverted = False
        recovery_deferred = False
        linear_recovery_attempts = _safe_int(active_record.get("linear_recovery_attempts"), 0)
        if check["completed"]:
            reply_text = extract_terminal_reply_text(rpc_response=rpc_response, assistant_record=check.get("assistant_record"))
            task_succeeded, failure_reason = classify_terminal_turn_outcome(reply_text, assistant_record=check.get("assistant_record"), rpc_response=rpc_response)
            if task_succeeded and active_record.get("kind") == "community_pr_lane_a_merge":
                merge_outcome, merge_detail = parse_lane_a_merge_reply(
                    reply_text,
                    repo=str(active_record.get("repo") or ""),
                    number=_safe_int(active_record.get("number"), 0),
                    linear_url=str(active_record.get("linear_issue_url") or "") or None,
                )
                if merge_outcome == "unconfirmed":
                    task_succeeded = False
                    failure_reason = f"lane_a_merge_unconfirmed ({merge_detail})"
            elif (
                task_succeeded
                and active_record.get("kind") == "team:merge"
                and active_record.get("trigger_reason") == "linear_todo_merge"
                and not bool(active_record.get("head_sha_changed"))
            ):
                merge_outcome, merge_detail = parse_linear_todo_merge_reply(
                    reply_text,
                    repo=str(active_record.get("repo") or ""),
                    number=_safe_int(active_record.get("number"), 0),
                    linear_url=str(active_record.get("linear_issue_url") or "") or None,
                )
                if merge_outcome == "unconfirmed":
                    task_succeeded = False
                    failure_reason = f"linear_todo_merge_unconfirmed ({merge_detail})"
            if task_succeeded:
                if defer_commit and is_recovery:
                    task_succeeded = False
                    failure_reason = str(active_record.get("deferred_failure_reason") or "").strip() or "interrupted_deferred_post_turn_write"
                    fin, linear_todo_reverted, recovery_deferred, failure_reason, linear_recovery_attempts = self._finalize_recovery_failure(
                        active_record,
                        failure_reason=failure_reason,
                        now_override_ms=stamp_ms,
                    )
                else:
                    if active_record.get("kind") not in SILENT_TELEGRAM_DISPATCH_KINDS:
                        tg_ok, tg_err = self._send_telegram_safe(reply_text)
                    fin = self._finalize_completed_dispatch(active_record, now_override_ms=stamp_ms, defer_watermark_commit=defer_commit)
            else:
                if is_recovery:
                    fin, linear_todo_reverted, recovery_deferred, failure_reason, linear_recovery_attempts = self._finalize_recovery_failure(
                        active_record,
                        failure_reason=failure_reason or "turn_failed",
                        now_override_ms=stamp_ms,
                    )
                elif defer_failure:
                    state_key = str(active_record.get("state_key") or active_record.get("thread_id") or "").strip()
                    watermark_result = self.state_store.get_thread_state(state_key) if state_key else None
                    fin = {"watermark": watermark_result, "queued_followup": bool(_as_dict(watermark_result).get("pending_followup"))}
                else:
                    fin = self._finalize_failed_dispatch(active_record, failure_reason=failure_reason, now_override_ms=stamp_ms)
        else:
            default_timeout = "turn_recovery_timeout" if is_recovery else (f"rpc_error: {rpc_error}" if rpc_error is not None else "turn_completion_timeout")
            failure_reason = "interrupted_turn_without_terminal_reply" if check.get("peek_active") is False else default_timeout
            if is_recovery:
                if check.get("peek_active") is False and str(active_record.get("deferred_failure_reason") or "").strip():
                    failure_reason = str(active_record.get("deferred_failure_reason") or "").strip()
                fin, linear_todo_reverted, recovery_deferred, failure_reason, linear_recovery_attempts = self._finalize_recovery_failure(
                    active_record,
                    failure_reason=failure_reason,
                    now_override_ms=stamp_ms,
                )
            elif defer_failure:
                state_key = str(active_record.get("state_key") or active_record.get("thread_id") or "").strip()
                watermark_result = self.state_store.get_thread_state(state_key) if state_key else None
                fin = {"watermark": watermark_result, "queued_followup": bool(_as_dict(watermark_result).get("pending_followup"))}
            else:
                fin = self._finalize_failed_dispatch(active_record, failure_reason=failure_reason, now_override_ms=stamp_ms)

        if is_recovery:
            status = "recovery_deferred" if recovery_deferred else ("recovered_completed" if task_succeeded else "recovered_failed")
        else:
            status = "completed" if task_succeeded else "failed"
        res: dict[str, object] = {"status": status, "execution_terminated": bool(check.get("completed") or check.get("peek_active") is False), "task_succeeded": task_succeeded, "failure_reason": failure_reason, "dispatch_id": dispatch_id, "session_key": session_key, "kind": active_record.get("kind"), "thread_id": active_record.get("thread_id"), "state_key": active_record.get("state_key"), "reply_text": reply_text, "telegram_forwarded": tg_ok, "telegram_error": tg_err, "queued_followup": fin["queued_followup"], "watermark": fin["watermark"]}
        if (defer_commit and task_succeeded and not is_recovery) or (defer_failure and not task_succeeded):
            res["watermark_deferred"] = True
            res["_deferred_active_record"] = dict(active_record)
        if is_recovery:
            res["can_dispatch"] = not recovery_deferred
            if active_record.get("kind") == "linear_todo_implement":
                res["linear_todo_reverted"] = linear_todo_reverted
                res["linear_recovery_attempts"] = linear_recovery_attempts
                if recovery_deferred:
                    res["verification_deferred"] = True
                    res["verification_error"] = failure_reason
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

    def select_dispatch_model(self, *, kind: str, is_automated_pr: bool = False, model: str | None = None) -> str:
        override = (model or "").strip()
        if override:
            return override
        if kind == "targeted" and is_automated_pr:
            return (self.update_model or self.sweep_model or self.code_model).strip()
        if kind in SWEEP_DISPATCH_KINDS:
            return (self.sweep_model or self.code_model or self.update_model).strip()
        return (self.code_model or self.sweep_model or self.update_model).strip()

    def execute_dispatch(self, *, kind: str, model: str | None = None, is_automated_pr: bool = False, session_key: str | None = None, thread_id: str | None = None, state_key: str | None = None, repo: str | None = None, number: int | None = None, subject_kind: str | None = None, head_sha: str | None = None, ci_state: str | None = None, updated_at: str | None = None, trigger_reason: str | None = None, comment_id: int | str | None = None, review_id: int | str | None = None, trusted_item_id: int | str | None = None, community_auto_merge_eligible: bool | None = None, team_label: str | None = None, team_label_event_key: str | None = None, triaged_head_sha: str | None = None, head_sha_changed: bool = False, linear_issue_id: str | None = None, linear_issue_identifier: str | None = None, linear_issue_url: str | None = None, linear_issue_estimate: int | None = None, linear_comment_id: str | None = None, linear_comment_parent_id: str | None = None, linear_comment_author: str | None = None, operator_guidance: Iterable[dict[str, str]] | None = None, github_url: str | None = None, bypass_reasons: Iterable[str] | None = None, lane_a_polish_notes: str | None = None, revision: str | None = None, sweep_date: str | None = None, extra_instructions: str = "", dispatch_id: str | None = None, defer_watermark_commit: bool = False, now_override_ms: int | None = None, **_ignored: object) -> dict:
        """Serialise a model turn under coordinator.lock while allowing state.json updates under companion.lock."""
        with self.state_store.coordinator_lock():
            recovery = self._recover_unlocked(now_override_ms=now_override_ms)
            if not recovery.get("can_dispatch", True):
                return {
                    "status": str(recovery.get("status") or "recovery_deferred"),
                    "dispatched": False,
                    "execution_terminated": False,
                    "task_succeeded": False,
                    "failure_reason": recovery.get("failure_reason") or "active_dispatch_recovery_pending",
                    "kind": kind,
                    "thread_id": thread_id,
                    "state_key": (state_key or thread_id or (make_pr_key(repo, number) if repo and number else "")).strip(),
                    "verification_deferred": bool(recovery.get("verification_deferred")),
                    "recovery": recovery,
                }
            start_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
            resolved_session_key = (session_key or self.session_key or DEFAULT_GH_SESSION_KEY).strip()
            resolved_model = self.select_dispatch_model(kind=kind, is_automated_pr=is_automated_pr, model=model)
            resolved_dispatch_id = (dispatch_id or f"ghd-{self.agent_name}-{uuid.uuid4().hex}").strip()
            eff_state_key = (state_key or thread_id or (make_pr_key(repo, number) if repo and number else "")).strip()

            if eff_state_key:
                wm_entry = self.state_store.mark_thread_in_flight(eff_state_key, updated_at=updated_at, head_sha=head_sha, ci_state=ci_state, now_override_ms=start_ms)
                updated_at, head_sha, ci_state = updated_at or wm_entry.get("in_flight_updated_at"), head_sha or wm_entry.get("in_flight_head_sha"), ci_state or wm_entry.get("in_flight_ci_state")
            if kind in SWEEP_DISPATCH_KINDS:
                self.state_store.record_sweep_attempt(kind, now_override_ms=start_ms)

            active_record: dict[str, object] = {"dispatch_id": resolved_dispatch_id, "session_key": resolved_session_key, "kind": kind, "started_at_ms": start_ms, "status": "in_flight"}
            for k, v in (
                ("thread_id", thread_id),
                ("state_key", eff_state_key),
                ("repo", repo),
                ("number", number),
                ("subject_kind", subject_kind),
                ("head_sha", head_sha),
                ("ci_state", ci_state),
                ("updated_at", updated_at),
                ("trigger_reason", trigger_reason),
                ("team_label", team_label),
                ("team_label_event_key", team_label_event_key),
                ("triaged_head_sha", triaged_head_sha),
                ("linear_issue_id", str(linear_issue_id).strip() if linear_issue_id is not None else ""),
                ("linear_issue_identifier", str(linear_issue_identifier).strip() if linear_issue_identifier is not None else ""),
                ("linear_issue_url", str(linear_issue_url).strip() if linear_issue_url is not None else ""),
                ("linear_comment_id", str(linear_comment_id).strip() if linear_comment_id is not None else ""),
                ("linear_comment_parent_id", str(linear_comment_parent_id).strip() if linear_comment_parent_id is not None else ""),
                ("linear_comment_author", str(linear_comment_author).strip() if linear_comment_author is not None else ""),
                ("github_url", str(github_url).strip() if github_url is not None else ""),
                ("revision", revision),
                ("sweep_date", sweep_date),
            ):
                if v is not None and v != "":
                    active_record[k] = v
            if head_sha_changed:
                active_record["head_sha_changed"] = True
            if defer_watermark_commit:
                active_record["defer_watermark_commit"] = True
            self.state_store.write_active_dispatch(active_record, now_override_ms=start_ms)

            start_notice_text = format_start_of_work_notice(agent_display_name=self.agent_display_name, kind=kind, repo=repo, number=number, subject_kind=subject_kind, trigger_reason=trigger_reason, sweep_date=sweep_date, schedule_day_name=self.schedule_day_name)
            start_notice_sent, start_notice_error = False, None
            prompt_message = self.build_dispatch_prompt(dispatch_id=resolved_dispatch_id, kind=kind, thread_id=thread_id, repo=repo, number=number, subject_kind=subject_kind, head_sha=head_sha, trigger_reason=trigger_reason, comment_id=comment_id, review_id=review_id, trusted_item_id=trusted_item_id, community_auto_merge_eligible=community_auto_merge_eligible, team_label=team_label, triaged_head_sha=triaged_head_sha, head_sha_changed=head_sha_changed, linear_issue_id=linear_issue_id, linear_issue_identifier=linear_issue_identifier, linear_issue_url=linear_issue_url, linear_issue_estimate=linear_issue_estimate, linear_comment_id=linear_comment_id, linear_comment_parent_id=linear_comment_parent_id, linear_comment_author=linear_comment_author, operator_guidance=operator_guidance, github_url=github_url, bypass_reasons=bypass_reasons, lane_a_polish_notes=lane_a_polish_notes, extra_instructions=extra_instructions)

            shadow_worker_enabled = bool(
                self.shadow_worker is not None
                and getattr(self.shadow_worker, "enabled", bool(getattr(self.shadow_worker, "shadow_model", "")))
            )
            should_shadow = bool(
                shadow_worker_enabled
                and kind == "targeted"
                and is_automated_pr
                and not (model or "").strip()
                and resolved_model == self.update_model
                and repo
                and number
            )
            pre_action_snapshot: dict[str, object] | None = None
            if should_shadow and self.gh_client is not None:
                try:
                    pre_action_snapshot = shadow_eval.capture_pr_snapshot(
                        self.gh_client,
                        agent=self.agent_name,
                        repo=str(repo),
                        number=_safe_int(number, 0),
                        head_sha=str(head_sha or ""),
                        trigger_reason=str(trigger_reason or ""),
                        now_ms_fn=self.clock,
                    )
                except Exception as exc:
                    sys.stderr.write(f"moltis-shadow-eval capture warning ({self.agent_name}): {exc}\n")
                    pre_action_snapshot = None

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
            result = self._resolve_turn_outcome(active_record, check, rpc_response=rpc_response, rpc_error=rpc_error, recovery=recovery, start_notice=(start_notice_sent, start_notice_text, start_notice_error), is_recovery=False, defer_watermark_commit=defer_watermark_commit, now_override_ms=finish_ms)

        if should_shadow and pre_action_snapshot is not None and self.shadow_worker is not None:
            try:
                history_records = load_session_history_records(
                    self.data_dir,
                    resolved_session_key,
                    agent_name=self.agent_name,
                    room_id=self.room_id,
                )
                self.shadow_worker.enqueue({
                    "snapshot": pre_action_snapshot,
                    "dispatch_id": resolved_dispatch_id,
                    "agent": self.agent_name,
                    "gemini_model": resolved_model,
                    "history_records": history_records,
                    "reply_text": str(result.get("reply_text") or ""),
                    "task_succeeded": bool(result.get("task_succeeded", False)),
                })
            except Exception as exc:
                sys.stderr.write(f"moltis-shadow-eval enqueue warning ({self.agent_name}): {exc}\n")

        return result


LINEAR_WRITE_CONSECUTIVE_FAILURE_LIMIT = 3


def _is_linear_permission_or_auth_error(exc: Exception) -> bool:
    if isinstance(exc, linear_sync.LinearAPIError):
        return exc.is_permission_or_auth_error()
    return False


class _LinearWriteCircuitBreaker:
    """Fail-fast per-poll circuit breaker for Linear write batches."""

    def __init__(self, *, consecutive_limit: int = LINEAR_WRITE_CONSECUTIVE_FAILURE_LIMIT):
        self.consecutive_limit = max(1, int(consecutive_limit))
        self.consecutive_errors = 0
        self.tripped = False
        self.reason: str | None = None
        self._logged_scopes: set[str] = set()

    def record_success(self) -> None:
        self.consecutive_errors = 0

    def record_error(self, exc: Exception, *, scope: str, item_key: str) -> bool:
        """Record a Linear write exception; return True when the breaker trips."""
        if _is_linear_permission_or_auth_error(exc):
            self.tripped = True
            self.reason = str(exc)
            self._emit_trip_warning(scope=scope, item_key=item_key, immediate=True)
            return True
        if isinstance(exc, linear_sync.LinearAPIError):
            self.consecutive_errors += 1
            if self.consecutive_errors >= self.consecutive_limit:
                self.tripped = True
                self.reason = str(exc)
                self._emit_trip_warning(scope=scope, item_key=item_key, immediate=False)
                return True
        return False

    def skip_if_tripped(self, *, scope: str) -> bool:
        if not self.tripped:
            return False
        if scope not in self._logged_scopes:
            self._logged_scopes.add(scope)
            sys.stderr.write(
                f"moltis-github-companion {scope} skipped: Linear write circuit breaker tripped ({self.reason})\n"
            )
        return True

    def _emit_trip_warning(self, *, scope: str, item_key: str, immediate: bool) -> None:
        self._logged_scopes.add(scope)
        if immediate:
            sys.stderr.write(
                f"moltis-github-companion {scope} circuit breaker tripped on auth/permission error ({item_key}): {self.reason}\n"
            )
        else:
            sys.stderr.write(
                f"moltis-github-companion {scope} circuit breaker tripped after {self.consecutive_errors} consecutive Linear API errors ({item_key}): {self.reason}\n"
            )


class GithubCompanionRunner:
    """Orchestrate 300s notification and open-PR polling, inline trigger evaluation, and serialised turns."""

    def __init__(
        self,
        state_store: CompanionStateStore,
        gh_client: GhApiSafeClient,
        poller: NotificationPoller,
        trust_filter: TrustFilterAndSnapshotBuilder,
        execution_coordinator: LocalExecutionCoordinator,
        matrix_client: MatrixClient | None = None,
        read_only_trial: bool = False,
        reconcile_interval_ms: int = RECONCILE_SWEEP_INTERVAL_MS,
        clock: Callable[[], int] = now_ms,
        linear_client: linear_sync.LinearSyncClient | None = None,
        telegram_client: TelegramClient | None = None,
        operator_digest_enabled: bool | str | None = None,
        security_release_repos: Iterable[str] | str | None = None,
        security_release_extra_repos: Iterable[str] | str | None = None,
        security_release_cooldown_secs: int | str | None = None,
        poll_interval_minutes: int | None = None,
    ):
        self.state_store = state_store
        self.gh_client = gh_client
        self.poller = poller
        self.poll_interval_minutes = (
            resolve_poll_interval_minutes(poll_interval_minutes)
            if poll_interval_minutes is not None
            else getattr(poller, "poll_interval_minutes", None)
        )
        self.trust_filter = trust_filter
        self.execution_coordinator = execution_coordinator
        resolved_telegram = telegram_client or self.execution_coordinator.telegram_client or self.trust_filter.telegram_client
        self.telegram_client = resolved_telegram
        if self.trust_filter.telegram_client is None and resolved_telegram is not None:
            self.trust_filter.telegram_client = resolved_telegram
        if self.execution_coordinator.telegram_client is None and resolved_telegram is not None:
            self.execution_coordinator.telegram_client = resolved_telegram
        self.matrix_client = matrix_client
        self.linear_client = linear_client
        if self.execution_coordinator.linear_client is None and self.linear_client is not None:
            self.execution_coordinator.linear_client = self.linear_client
        if self.execution_coordinator.gh_client is None and self.gh_client is not None:
            self.execution_coordinator.gh_client = self.gh_client
        self.read_only_trial = bool(read_only_trial)
        self.reconcile_interval_ms = max(60_000, _safe_int(reconcile_interval_ms, RECONCILE_SWEEP_INTERVAL_MS))
        self.clock = clock
        self._operator_digest_enabled = operator_digest_enabled
        self._security_release_extra_repos = (
            security_release_extra_repos if security_release_extra_repos is not None else security_release_repos
        )
        self._security_release_repos = self._security_release_extra_repos
        self._security_release_cooldown_secs = security_release_cooldown_secs

    @contextlib.contextmanager
    def _deferred_dispatch_guard(self, dispatch_result: dict, *, now_override_ms: int | None = None) -> Iterator[None]:
        """Ensure deferred dispatches are committed or failed on normal exit or Exception without masking process-exit crash recovery."""
        try:
            yield
        except Exception:
            if dispatch_result.get("watermark_deferred"):
                self.execution_coordinator.fail_deferred_dispatch(
                    dispatch_result,
                    failure_reason="deferred_post_turn_aborted",
                    now_override_ms=now_override_ms,
                )
            raise
        if dispatch_result.get("watermark_deferred") and not dispatch_result.get("verification_deferred"):
            self.execution_coordinator.fail_deferred_dispatch(
                dispatch_result,
                failure_reason="deferred_post_turn_uncommitted",
                now_override_ms=now_override_ms,
            )

    def is_reconcile_sweep_due(self, now_override_ms: int | None = None) -> bool:
        if self.state_store.agent_name == "traya" or self.execution_coordinator.schedule_dow <= 0:
            return False
        current_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        state = self.state_store.read_state()
        reconcile_retry_ms = _safe_int(state.get("reconcile_sweep_retry_after_ms"), 0)
        weekly_retry_ms = _safe_int(state.get("weekly_sweep_retry_after_ms"), 0)
        if (reconcile_retry_ms > 0 and current_ms < reconcile_retry_ms) or (weekly_retry_ms > 0 and current_ms < weekly_retry_ms):
            return False
        last_sweep = state.get("last_reconcile_sweep_at_ms")
        if not isinstance(last_sweep, int) or last_sweep <= 0:
            initial_offset_ms = RECONCILE_SWEEP_INITIAL_OFFSET_MS.get(self.state_store.agent_name, 0)
            if initial_offset_ms > 0:
                anchor_ms = _safe_int(self.state_store.started_at_ms, 0)
                if anchor_ms > 0 and (current_ms - anchor_ms) < initial_offset_ms:
                    return False
            return True
        return (current_ms - last_sweep) >= self.reconcile_interval_ms

    def is_weekly_sweep_due(self, now_override_ms: int | None = None) -> tuple[bool, str]:
        current_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        dt = _london_datetime(current_ms)
        today_str = dt.strftime("%Y-%m-%d")
        if self.state_store.agent_name == "traya" or self.execution_coordinator.schedule_dow <= 0 or self.execution_coordinator.schedule_day_name.lower() == "disabled":
            return False, today_str
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

    def _create_linear_triage_stubs(
        self,
        actionable_issues: Iterable[dict],
        *,
        slot_id: str,
        current_ms: int,
        linear_breaker: _LinearWriteCircuitBreaker | None = None,
    ) -> list[dict]:
        if self.linear_client is None or self.state_store.agent_name not in SWEEP_AGENT_ORDER:
            return []
        breaker = linear_breaker if linear_breaker is not None else _LinearWriteCircuitBreaker()
        if breaker.skip_if_tripped(scope="linear-triage-stub"):
            return []
        created_stubs: list[dict] = []
        for issue_item in actionable_issues or ():
            if not isinstance(issue_item, dict):
                continue
            issue_key = str(issue_item.get("key") or "").strip()
            repo = str(issue_item.get("repo") or "").strip()
            number = _safe_int(issue_item.get("number"), 0)
            if not issue_key or not repo or number <= 0:
                continue
            if not is_allowed_notification_repo(repo) or compute_issue_owner(repo, number) != self.state_store.agent_name:
                continue
            issue_entry = _as_dict(self.state_store.get_thread_state(issue_key))
            if issue_entry.get("linear_issue_id") or issue_item.get("linear_issue_id"):
                continue
            if bool(issue_entry.get("coercion_blocked")) or _safe_int(issue_entry.get("retry_count"), 0) >= MAX_THREAD_FAILURE_RETRIES:
                continue
            if not self.state_store.can_consume_throttle("triage_stubs", slot_id=slot_id, now_override_ms=current_ms):
                break
            issue_url = str(issue_item.get("url") or issue_entry.get("url") or "").strip() or f"https://github.com/{repo}/issues/{number}"
            title = str(issue_item.get("title") or issue_entry.get("title") or "").strip() or f"{repo}#{number}"
            updated_at = str(issue_item.get("updated_at") or issue_entry.get("updated_at") or "").strip() or None
            try:
                linear_issue = self.linear_client.ensure_issue_for_github_item(
                    github_url=issue_url,
                    title=title,
                    repo=repo,
                    item_kind="Issue",
                    state="Triage",
                )
                linear_id = str(linear_issue.get("id") or "").strip()
                if not linear_id:
                    raise RuntimeError("Linear issue response missing id")
                linear_identifier = str(linear_issue.get("identifier") or "").strip() or None
                linear_url = str(linear_issue.get("url") or "").strip() or None
            except Exception as exc:
                if breaker.record_error(exc, scope="linear-triage-stub", item_key=issue_key):
                    break
                sys.stderr.write(f"moltis-github-companion linear-triage-stub warning ({issue_key}): {exc}\n")
                continue
            breaker.record_success()
            if is_ignored_linear_issue_state(linear_issue):
                self.state_store.update_thread_state(
                    issue_key,
                    {
                        "repo": repo,
                        "number": number,
                        "subject_type": "Issue",
                        "url": issue_url,
                        "title": title,
                        "linear_issue_id": linear_id,
                        "linear_issue_identifier": linear_identifier,
                        "linear_issue_url": linear_url,
                        "handled_updated_at": updated_at or issue_entry.get("handled_updated_at"),
                    },
                    now_override_ms=current_ms,
                )
                continue
            self.state_store.consume_throttle("triage_stubs", slot_id=slot_id, now_override_ms=current_ms)
            self.state_store.update_thread_state(
                issue_key,
                {
                    "repo": repo,
                    "number": number,
                    "subject_type": "Issue",
                    "url": issue_url,
                    "title": title,
                    "linear_issue_id": linear_id,
                    "linear_issue_identifier": linear_identifier,
                    "linear_issue_url": linear_url,
                    "handled_updated_at": updated_at or issue_entry.get("handled_updated_at"),
                },
                now_override_ms=current_ms,
            )
            created_stubs.append({
                "key": issue_key,
                "repo": repo,
                "number": number,
                "github_url": issue_url,
                "title": title,
                "linear_issue_id": linear_id,
                "linear_issue_identifier": linear_identifier,
                "linear_issue_url": linear_url,
            })
        return created_stubs

    def _promote_team_implement_issue_to_linear(
        self,
        *,
        cand: dict,
        cand_key: str,
        verified_event_key: str | None,
        current_ms: int,
        linear_breaker: _LinearWriteCircuitBreaker | None = None,
    ) -> dict | None:
        if self.linear_client is None or self.state_store.agent_name not in SWEEP_AGENT_ORDER:
            return None
        if linear_breaker is not None and linear_breaker.skip_if_tripped(scope="linear-promote"):
            return None
        repo = str(cand.get("repo") or "").strip()
        number = _safe_int(cand.get("number"), 0)
        if not repo or number <= 0:
            return None
        cand_entry = _as_dict(self.state_store.get_thread_state(cand_key))
        issue_url = str(cand.get("url") or cand_entry.get("url") or "").strip() or f"https://github.com/{repo}/issues/{number}"
        title = str(cand.get("title") or cand_entry.get("title") or "").strip() or f"{repo}#{number}"
        updated_at = str(cand.get("updated_at") or cand_entry.get("updated_at") or "").strip() or None
        try:
            linear_issue = self.linear_client.ensure_issue_for_github_item(
                github_url=issue_url,
                title=title,
                repo=repo,
                item_kind="Issue",
                state="Todo",
                extra_labels=("ready-to-implement",),
            )
            linear_id = str(linear_issue.get("id") or "").strip()
            if not linear_id:
                raise RuntimeError("Linear issue response missing id")
            if is_ignored_linear_issue_state(linear_issue):
                if linear_breaker is not None:
                    linear_breaker.record_success()
                handled_team_labels = dict(_as_dict(cand_entry.get("handled_team_labels")))
                if verified_event_key:
                    handled_team_labels["team:implement"] = verified_event_key
                self.state_store.update_thread_state(
                    cand_key,
                    {
                        "repo": repo,
                        "number": number,
                        "subject_type": "Issue",
                        "url": issue_url,
                        "title": title,
                        "linear_issue_id": linear_id,
                        "linear_issue_identifier": str(linear_issue.get("identifier") or "").strip() or None,
                        "linear_issue_url": str(linear_issue.get("url") or "").strip() or None,
                        "handled_team_labels": handled_team_labels,
                        **({"handled_updated_at": updated_at} if updated_at and not cand_entry.get("handled_updated_at") else {}),
                    },
                    now_override_ms=current_ms,
                )
                return None
            state_obj = _as_dict(linear_issue.get("state"))
            state_name = str(state_obj.get("name") or "").strip().lower()
            state_type = str(state_obj.get("type") or "").strip().lower()
            promoted_state = False
            if state_name in ("triage", "backlog") or state_type in ("triage", "backlog"):
                linear_issue = self.linear_client.update_issue(
                    linear_id,
                    state="Todo",
                    add_labels=("ready-to-implement",),
                    remove_labels=("sign-off-required",),
                )
                promoted_state = True
            linear_identifier = str(linear_issue.get("identifier") or "").strip() or None
            linear_url = str(linear_issue.get("url") or "").strip() or None
            final_state_name = str(_as_dict(linear_issue.get("state")).get("name") or "").strip() or None
        except Exception as exc:
            if linear_breaker is not None and linear_breaker.record_error(exc, scope="linear-promote", item_key=cand_key):
                return None
            sys.stderr.write(f"moltis-github-companion linear-promote warning ({cand_key}): {exc}\n")
            return None
        if linear_breaker is not None:
            linear_breaker.record_success()
        handled_team_labels = dict(_as_dict(cand_entry.get("handled_team_labels")))
        if verified_event_key:
            handled_team_labels["team:implement"] = verified_event_key
        updates: dict[str, object] = {
            "repo": repo,
            "number": number,
            "subject_type": "Issue",
            "url": issue_url,
            "title": title,
            "linear_issue_id": linear_id,
            "linear_issue_identifier": linear_identifier,
            "linear_issue_url": linear_url,
            "handled_team_labels": handled_team_labels,
        }
        if updated_at and not cand_entry.get("handled_updated_at"):
            updates["handled_updated_at"] = updated_at
        self.state_store.update_thread_state(cand_key, updates, now_override_ms=current_ms)
        return {
            "key": cand_key,
            "repo": repo,
            "number": number,
            "github_url": issue_url,
            "title": title,
            "linear_issue_id": linear_id,
            "linear_issue_identifier": linear_identifier,
            "linear_issue_url": linear_url,
            "state": final_state_name,
            "promoted_from_triage_or_backlog": promoted_state,
            "event_key": verified_event_key,
        }

    def _poll_active_linear_issues(self) -> list[dict] | None:
        if self.linear_client is None or self.state_store.agent_name not in AGENT_ORDER:
            return None
        try:
            raw_issues = self.linear_client.list_project_issues_by_state(("Triage", "Backlog", "Todo", "In Progress", "In Review"))
        except Exception as exc:
            sys.stderr.write(f"moltis-github-companion linear-poll warning ({self.state_store.agent_name}): {exc}\n")
            return None
        return [item for item in (raw_issues or ()) if isinstance(item, dict)]

    def _get_linear_issue_operator_guidance(
        self,
        linear_issue: dict | None,
        *,
        fallback_issue: dict | None = None,
        comments: Iterable[dict] | None = None,
    ) -> list[dict[str, str]]:
        if comments is not None:
            return _resolve_linear_operator_guidance(linear_issue, comments=comments)
        if isinstance(linear_issue, dict) and "comments" in linear_issue:
            return _resolve_linear_operator_guidance(linear_issue)
        if isinstance(fallback_issue, dict) and "comments" in fallback_issue:
            return _resolve_linear_operator_guidance(fallback_issue)
        if self.linear_client is not None:
            linear_id = str(_as_dict(linear_issue).get("id") or _as_dict(fallback_issue).get("id") or "").strip()
            if linear_id:
                try:
                    fetched = self.linear_client.list_issue_comments(linear_id)
                except Exception as exc:
                    sys.stderr.write(f"moltis-github-companion linear-guidance-comments warning ({linear_id}): {exc}\n")
                    return []
                return _resolve_linear_operator_guidance(linear_issue, comments=fetched)
        return []

    def _sync_closed_github_items_to_linear(
        self,
        active_linear_issues: Iterable[dict],
        *,
        poll_result: dict,
        current_ms: int,
        linear_breaker: _LinearWriteCircuitBreaker | None = None,
    ) -> list[dict]:
        _ = current_ms
        if (
            self.linear_client is None
            or self.state_store.agent_name not in SWEEP_AGENT_ORDER
            or poll_result.get("open_prs_poll_error") is not None
            or poll_result.get("open_issues_poll_error") is not None
            or poll_result.get("status") in (403, 429)
        ):
            return []
        breaker = linear_breaker if linear_breaker is not None else _LinearWriteCircuitBreaker()
        if breaker.skip_if_tripped(scope="linear-close-sync"):
            return []
        open_issue_keys: set[str] = set()
        for item in poll_result.get("open_issues") or ():
            if not isinstance(item, dict):
                continue
            key = str(item.get("issue_key") or "").strip().lower()
            if not key:
                r, n = str(item.get("repo") or "").strip(), _safe_int(item.get("number"), 0)
                if r and n > 0:
                    key = make_pr_key(r, n)
            if key:
                open_issue_keys.add(key)
        open_pr_keys: set[str] = set()
        for item in poll_result.get("open_pull_requests") or ():
            if not isinstance(item, dict):
                continue
            key = str(item.get("pr_key") or "").strip().lower()
            if not key:
                r, n = str(item.get("repo") or "").strip(), _safe_int(item.get("number"), 0)
                if r and n > 0:
                    key = make_pr_key(r, n)
            if key:
                open_pr_keys.add(key)

        synced: list[dict] = []
        for linear_issue in active_linear_issues or ():
            if not isinstance(linear_issue, dict) or linear_issue.get("archivedAt"):
                continue
            linear_id = str(linear_issue.get("id") or "").strip()
            if not linear_id:
                continue
            if is_ignored_linear_issue_state(linear_issue):
                continue
            labels = extract_linear_issue_labels(linear_issue)
            expected_kind = "PR" if "pr" in labels else ("Issue" if "issue" in labels else None)
            target = extract_linear_github_target(linear_issue, expected_kind=expected_kind)
            if target is None:
                continue
            repo, item_label, number, github_url = target
            if not is_allowed_notification_repo(repo):
                continue
            expected_owner = compute_pr_owner(repo, number) if item_label == "PR" else compute_issue_owner(repo, number)
            if expected_owner != self.state_store.agent_name:
                continue
            item_key = make_pr_key(repo, number)
            if (item_label == "PR" and item_key in open_pr_keys) or (item_label == "Issue" and item_key in open_issue_keys):
                continue
            endpoint = f"repos/{repo}/{'pulls' if item_label == 'PR' else 'issues'}/{number}"
            try:
                live_obj = self.gh_client.fetch_json_object(endpoint)
            except Exception as exc:
                sys.stderr.write(f"moltis-github-companion linear-close-sync fetch warning ({item_key}): {exc}\n")
                continue
            if not isinstance(live_obj, dict) or not live_obj:
                continue
            live_state = str(live_obj.get("state") or "").strip().lower()
            if item_label == "PR":
                is_merged = bool(live_obj.get("merged")) or bool(str(live_obj.get("merged_at") or "").strip())
                if is_merged:
                    target_state = "Done"
                elif live_state == "closed":
                    target_state = "Canceled"
                else:
                    continue
            else:
                if live_state != "closed":
                    continue
                state_reason = str(live_obj.get("state_reason") or "").strip().lower()
                target_state = "Canceled" if state_reason in ("not_planned", "duplicate") else "Done"
            try:
                self.linear_client.update_issue(linear_id, state=target_state)
            except Exception as exc:
                if breaker.record_error(exc, scope="linear-close-sync", item_key=item_key):
                    break
                sys.stderr.write(f"moltis-github-companion linear-close-sync update warning ({item_key} / {linear_id}): {exc}\n")
                continue
            breaker.record_success()
            synced.append({
                "key": item_key,
                "repo": repo,
                "number": number,
                "kind": item_label,
                "github_url": github_url,
                "linear_issue_id": linear_id,
                "linear_issue_identifier": str(linear_issue.get("identifier") or "").strip() or None,
                "linear_issue_url": str(linear_issue.get("url") or "").strip() or None,
                "target_state": target_state,
            })
        return synced

    def _resolve_owned_linear_issue_candidate(self, linear_issue: object, *, dispatched_targets: set[str]) -> dict | None:
        if not isinstance(linear_issue, dict) or is_ignored_linear_issue_state(linear_issue):
            return None
        linear_id = str(linear_issue.get("id") or "").strip()
        if not linear_id:
            return None
        labels = extract_linear_issue_labels(linear_issue)
        if "issue" not in labels or "pr" in labels:
            return None
        target = extract_linear_github_target(linear_issue, expected_kind="Issue")
        if target is None:
            return None
        repo, _, number, github_url = target
        if not is_allowed_notification_repo(repo) or compute_issue_owner(repo, number) != self.state_store.agent_name:
            return None
        issue_key = make_pr_key(repo, number)
        if issue_key in dispatched_targets:
            return None
        entry = _as_dict(self.state_store.get_thread_state(issue_key))
        if bool(entry.get("coercion_blocked")) or _safe_int(entry.get("retry_count"), 0) >= MAX_THREAD_FAILURE_RETRIES:
            return None
        state_obj = _as_dict(linear_issue.get("state"))
        return {
            "linear_id": linear_id,
            "linear_identifier": str(linear_issue.get("identifier") or "").strip() or None,
            "linear_url": str(linear_issue.get("url") or "").strip() or None,
            "title": str(linear_issue.get("title") or "").strip() or str(entry.get("title") or "").strip() or f"{repo}#{number}",
            "updated_at": str(entry.get("updated_at") or linear_issue.get("updatedAt") or "").strip() or None,
            "state_name": str(state_obj.get("name") or "").strip().lower(),
            "state_type": str(state_obj.get("type") or "").strip().lower(),
            "repo": repo,
            "number": number,
            "github_url": github_url,
            "issue_key": issue_key,
        }

    def _dispatch_linear_operator_comments(
        self,
        active_linear_issues: Iterable[dict],
        *,
        slot_id: str | None = None,
        dispatched_targets: set[str],
        current_ms: int,
        now_override_ms: int | None,
    ) -> list[dict]:
        if self.linear_client is None or self.state_store.agent_name not in AGENT_ORDER:
            return []
        eff_slot_id = (
            slot_id
            if isinstance(slot_id, str) and slot_id.strip()
            else compute_throttle_slot_id(
                current_ms,
                self.state_store.agent_name,
                poll_interval_minutes=self.poll_interval_minutes,
            )
        )
        dispatches: list[dict] = []
        for linear_issue in active_linear_issues or ():
            if len(dispatches) >= MAX_LINEAR_OPERATOR_COMMENTS_PER_POLL:
                break
            if not isinstance(linear_issue, dict) or is_ignored_linear_issue_state(linear_issue):
                continue
            linear_id = str(linear_issue.get("id") or "").strip()
            if not linear_id:
                continue
            target = extract_linear_github_target(linear_issue)
            if target is not None:
                repo, item_label, number, github_url = target
                subject_kind = "PullRequest" if item_label == "PR" else "Issue"
                state_key = make_pr_key(repo, number)
            else:
                repo, number, subject_kind, github_url = None, None, "Issue", None
                state_key = f"linear:{linear_id}"
            if state_key in dispatched_targets:
                continue
            entry = _as_dict(self.state_store.get_thread_state(state_key))
            if bool(entry.get("in_flight")) or _safe_int(entry.get("retry_count"), 0) >= MAX_THREAD_FAILURE_RETRIES:
                continue

            delegate_agent: str | None = None
            delegate_obj = linear_issue.get("delegate")
            if isinstance(delegate_obj, dict):
                for field_name in ("name", "displayName"):
                    raw_delegate = str(delegate_obj.get(field_name) or "").strip().lower()
                    if raw_delegate in LOGIN_TO_AGENT_NAME:
                        delegate_agent = LOGIN_TO_AGENT_NAME[raw_delegate]
                        break
            if delegate_agent is None and repo and number is not None:
                delegate_agent = (
                    compute_pr_owner(repo, number)
                    if subject_kind == "PullRequest"
                    else compute_issue_owner(repo, number)
                )

            if "comments" in linear_issue:
                raw_comments: object = linear_issue.get("comments")
            else:
                try:
                    raw_comments = self.linear_client.list_issue_comments(linear_id)
                except Exception as exc:
                    sys.stderr.write(
                        f"moltis-github-companion linear-operator-comments warning ({state_key} / {linear_id}): {exc}\n"
                    )
                    continue
            all_verified = linear_sync.extract_verified_operator_comments(raw_comments)
            if not all_verified:
                continue

            handled_ids = set(
                CompanionStateStore._normalize_handled_linear_comment_ids(
                    entry.get("handled_linear_comment_ids")
                )
            )
            matching_unhandled = [
                comment
                for comment in all_verified
                if comment["id"]
                and comment["id"] not in handled_ids
                and self.state_store.agent_name
                in linear_sync.parse_linear_operator_mentions(
                    comment["body"],
                    delegate_agent=delegate_agent,
                )
            ]
            if not matching_unhandled:
                continue

            newest_comment = matching_unhandled[-1]
            reply_parent_id = newest_comment["parent_id"] or newest_comment["id"]
            linear_identifier = str(linear_issue.get("identifier") or "").strip() or None
            linear_url = str(linear_issue.get("url") or "").strip() or None
            title = (
                str(linear_issue.get("title") or "").strip()
                or str(entry.get("title") or "").strip()
                or (f"{repo}#{number}" if repo and number is not None else (linear_identifier or linear_id))
            )
            updated_at = str(entry.get("updated_at") or linear_issue.get("updatedAt") or "").strip() or None
            state_updates: dict[str, object] = {
                "subject_type": subject_kind,
                "title": title,
                "linear_issue_id": linear_id,
                "linear_issue_identifier": linear_identifier,
                "linear_issue_url": linear_url,
            }
            if repo:
                state_updates["repo"] = repo
            if number is not None:
                state_updates["number"] = number
            if github_url:
                state_updates["url"] = github_url
            self.state_store.update_thread_state(state_key, state_updates, now_override_ms=current_ms)
            self.state_store.record_operator_task(slot_id=eff_slot_id, now_override_ms=current_ms)
            dispatched_targets.add(state_key)
            res = self.execution_coordinator.execute_dispatch(
                kind="linear_operator_comment",
                is_automated_pr=False,
                state_key=state_key,
                repo=repo,
                number=number,
                subject_kind=subject_kind,
                updated_at=updated_at,
                trigger_reason="linear_operator_comment",
                linear_issue_id=linear_id,
                linear_issue_identifier=linear_identifier,
                linear_issue_url=linear_url,
                linear_comment_id=newest_comment["id"],
                linear_comment_parent_id=reply_parent_id,
                linear_comment_author=newest_comment["author"],
                operator_guidance=all_verified,
                github_url=github_url,
                now_override_ms=now_override_ms,
            )
            if res.get("task_succeeded"):
                latest_entry = _as_dict(self.state_store.get_thread_state(state_key))
                existing_handled = CompanionStateStore._normalize_handled_linear_comment_ids(
                    latest_entry.get("handled_linear_comment_ids")
                )
                new_ids = [comment["id"] for comment in matching_unhandled if comment["id"]]
                updated_handled = CompanionStateStore._normalize_handled_linear_comment_ids(
                    [*existing_handled, *new_ids]
                )
                self.state_store.update_thread_state(
                    state_key,
                    {"handled_linear_comment_ids": updated_handled},
                    now_override_ms=current_ms,
                )
            dispatches.append(res)
        return dispatches

    def _dispatch_linear_triage_research(self, active_linear_issues: Iterable[dict], *, slot_id: str, dispatched_targets: set[str], current_ms: int, now_override_ms: int | None) -> list[dict]:
        if self.linear_client is None or self.state_store.agent_name not in SWEEP_AGENT_ORDER:
            return []
        dispatches: list[dict] = []
        for linear_issue in active_linear_issues or ():
            cand = self._resolve_owned_linear_issue_candidate(linear_issue, dispatched_targets=dispatched_targets)
            if cand is None or (cand["state_name"] != "triage" and cand["state_type"] != "triage"):
                continue
            if not self.state_store.can_consume_throttle("triage_research", slot_id=slot_id, now_override_ms=current_ms):
                break
            consumed, _ = self.state_store.consume_throttle("triage_research", slot_id=slot_id, now_override_ms=current_ms)
            if not consumed:
                break
            operator_guidance = self._get_linear_issue_operator_guidance(linear_issue)
            self.state_store.update_thread_state(
                cand["issue_key"],
                {
                    "repo": cand["repo"],
                    "number": cand["number"],
                    "subject_type": "Issue",
                    "url": cand["github_url"],
                    "title": cand["title"],
                    "linear_issue_id": cand["linear_id"],
                    "linear_issue_identifier": cand["linear_identifier"],
                    "linear_issue_url": cand["linear_url"],
                },
                now_override_ms=current_ms,
            )
            dispatched_targets.add(cand["issue_key"])
            res = self.execution_coordinator.execute_dispatch(
                kind="linear_triage_research",
                is_automated_pr=False,
                state_key=cand["issue_key"],
                repo=cand["repo"],
                number=cand["number"],
                subject_kind="Issue",
                updated_at=cand["updated_at"],
                trigger_reason="linear_triage_research",
                linear_issue_id=cand["linear_id"],
                linear_issue_identifier=cand["linear_identifier"],
                linear_issue_url=cand["linear_url"],
                operator_guidance=operator_guidance,
                github_url=cand["github_url"],
                defer_watermark_commit=True,
                now_override_ms=now_override_ms,
            )
            if res.get("task_succeeded"):
                with self._deferred_dispatch_guard(res, now_override_ms=now_override_ms):
                    try:
                        refreshed = self.linear_client.get_issue(cand["linear_id"])
                    except Exception as exc:
                        sys.stderr.write(f"moltis-github-companion linear-triage-verify warning ({cand['issue_key']} / {cand['linear_id']}): {exc}\n")
                        self.execution_coordinator.fail_deferred_dispatch(
                            res,
                            failure_reason=f"linear_triage_state_verify_failed: {exc}",
                            now_override_ms=now_override_ms,
                        )
                    else:
                        post_state = _as_dict(_as_dict(refreshed).get("state"))
                        post_state_name = str(post_state.get("name") or "").strip().lower()
                        post_state_type = str(post_state.get("type") or "").strip().lower()
                        if (not post_state_name and not post_state_type) or post_state_name == "triage" or post_state_type == "triage":
                            self.execution_coordinator.fail_deferred_dispatch(
                                res,
                                failure_reason="linear_triage_state_unchanged",
                                now_override_ms=now_override_ms,
                            )
                        else:
                            self.execution_coordinator.commit_deferred_dispatch(res, now_override_ms=now_override_ms)
            dispatches.append(res)
        return dispatches

    def _fetch_linear_issue_state(self, linear_id: str) -> tuple[str | None, Exception | None]:
        """Fetch a Linear issue's lowercased workflow state name with one retry on transient failure."""
        return _fetch_linear_issue_state_with_retry(self.linear_client, linear_id)

    def _reconcile_pending_linear_todo_claims(self, *, current_ms: int) -> list[dict]:
        """Drain durable pending_linear_todo_reconciliations without blocking other dispatches."""
        if self.linear_client is None:
            return []
        pending = self.state_store.list_linear_todo_reconciliations()
        if not pending:
            return []
        results: list[dict] = []
        for linear_id, entry in pending.items():
            thread_key = str(_as_dict(entry).get("thread_key") or "").strip() or None
            try:
                refreshed = self.linear_client.get_issue(linear_id)
            except Exception as exc:
                if _is_linear_issue_not_found_error(exc):
                    self.state_store.remove_linear_todo_reconciliation(linear_id, now_override_ms=current_ms)
                    results.append({
                        "linear_issue_id": linear_id,
                        "thread_key": thread_key,
                        "action": "removed_not_found",
                        "error": str(exc),
                    })
                else:
                    sys.stderr.write(
                        f"moltis-github-companion linear-todo-reconcile-verify warning ({thread_key or linear_id} / {linear_id}): {exc}\n"
                    )
                    results.append({
                        "linear_issue_id": linear_id,
                        "thread_key": thread_key,
                        "action": "deferred_transient_error",
                        "error": str(exc),
                    })
                continue
            post_state = _as_dict(_as_dict(refreshed).get("state"))
            post_state_name = str(post_state.get("name") or "").strip().lower()
            if not post_state_name:
                sys.stderr.write(
                    f"moltis-github-companion linear-todo-reconcile-verify warning ({thread_key or linear_id} / {linear_id}): missing workflow state in Linear response\n"
                )
                results.append({
                    "linear_issue_id": linear_id,
                    "thread_key": thread_key,
                    "action": "deferred_transient_error",
                    "error": "missing workflow state in Linear response",
                })
                continue
            if post_state_name in ("in progress", "in_progress"):
                try:
                    self.linear_client.update_issue(linear_id, state="Todo")
                except Exception as exc:
                    if _is_linear_issue_not_found_error(exc):
                        self.state_store.remove_linear_todo_reconciliation(linear_id, now_override_ms=current_ms)
                        results.append({
                            "linear_issue_id": linear_id,
                            "thread_key": thread_key,
                            "action": "removed_not_found",
                            "error": str(exc),
                        })
                    else:
                        sys.stderr.write(
                            f"moltis-github-companion linear-todo-reconcile-revert warning ({thread_key or linear_id} / {linear_id}): {exc}\n"
                        )
                        results.append({
                            "linear_issue_id": linear_id,
                            "thread_key": thread_key,
                            "action": "deferred_revert_error",
                            "error": str(exc),
                        })
                    continue
                self.state_store.remove_linear_todo_reconciliation(linear_id, now_override_ms=current_ms)
                results.append({
                    "linear_issue_id": linear_id,
                    "thread_key": thread_key,
                    "action": "reverted_to_todo",
                    "previous_state": post_state_name,
                })
            else:
                self.state_store.remove_linear_todo_reconciliation(linear_id, now_override_ms=current_ms)
                results.append({
                    "linear_issue_id": linear_id,
                    "thread_key": thread_key,
                    "action": "cleared_already_moved",
                    "state": post_state_name,
                })
        return results

    def _dispatch_linear_todo_implementations(
        self,
        active_linear_issues: Iterable[dict],
        *,
        slot_id: str,
        dispatched_targets: set[str],
        current_ms: int,
        now_override_ms: int | None,
        open_pr_by_closing_issue_key: dict[str, list[dict]] | None = None,
        linear_breaker: _LinearWriteCircuitBreaker | None = None,
    ) -> list[dict]:
        if self.linear_client is None or self.state_store.agent_name not in SWEEP_AGENT_ORDER:
            return []
        dispatches: list[dict] = []
        for linear_issue in active_linear_issues or ():
            cand = self._resolve_owned_linear_issue_candidate(linear_issue, dispatched_targets=dispatched_targets)
            if cand is None or (cand["state_name"] != "todo" and cand["state_type"] != "unstarted"):
                continue
            linking_prs = (open_pr_by_closing_issue_key or {}).get(cand["issue_key"]) or []
            issue_entry = _as_dict(self.state_store.get_thread_state(cand["issue_key"]))
            if linking_prs:
                first_pr = linking_prs[0] if isinstance(linking_prs[0], dict) else {}
                pr_url = str(first_pr.get("url") or "").strip()
                if not pr_url:
                    pr_repo = str(first_pr.get("repo") or "").strip()
                    pr_num = _safe_int(first_pr.get("number"), 0)
                    if pr_repo and pr_num > 0:
                        pr_url = f"https://github.com/{pr_repo}/pull/{pr_num}"
                if pr_url and issue_entry.get("paused_by_open_pr_url") != pr_url:
                    comment_posted = False
                    can_comment = hasattr(self.linear_client, "post_comment") and (
                        linear_breaker is None or not linear_breaker.skip_if_tripped(scope="linear-todo-pause-comment")
                    )
                    if can_comment:
                        try:
                            self.linear_client.post_comment(
                                cand["linear_id"],
                                f"Autonomous implementation is paused while open pull request {pr_url} already references this issue.",
                            )
                            comment_posted = True
                            if linear_breaker is not None:
                                linear_breaker.record_success()
                        except Exception as exc:
                            if linear_breaker is not None:
                                linear_breaker.record_error(
                                    exc,
                                    scope="linear-todo-pause-comment",
                                    item_key=cand["issue_key"],
                                )
                            sys.stderr.write(
                                f"moltis-github-companion linear-todo-pause-comment warning ({cand['issue_key']} / {cand['linear_id']}): {exc}\n"
                            )
                    if comment_posted or not hasattr(self.linear_client, "post_comment"):
                        self.state_store.update_thread_state(
                            cand["issue_key"],
                            {
                                "repo": cand["repo"],
                                "number": cand["number"],
                                "subject_type": "Issue",
                                "url": cand["github_url"],
                                "linear_issue_id": cand["linear_id"],
                                "paused_by_open_pr_url": pr_url,
                            },
                            now_override_ms=current_ms,
                        )
                continue
            if issue_entry.get("paused_by_open_pr_url"):
                self.state_store.update_thread_state(
                    cand["issue_key"],
                    {"paused_by_open_pr_url": None},
                    now_override_ms=current_ms,
                )
            if not self.state_store.can_consume_throttle("todo_implementations", slot_id=slot_id, now_override_ms=current_ms):
                break
            try:
                self.linear_client.update_issue(cand["linear_id"], state="In Progress")
            except Exception as exc:
                sys.stderr.write(f"moltis-github-companion linear-todo-claim warning ({cand['issue_key']} / {cand['linear_id']}): {exc}\n")
                continue
            consumed, _ = self.state_store.consume_throttle("todo_implementations", slot_id=slot_id, now_override_ms=current_ms)
            if not consumed:
                try:
                    self.linear_client.update_issue(cand["linear_id"], state="Todo")
                except Exception as exc:
                    if not _is_linear_issue_not_found_error(exc):
                        sys.stderr.write(f"moltis-github-companion linear-todo-throttle-revert warning ({cand['issue_key']} / {cand['linear_id']}): {exc}\n")
                        self.state_store.enqueue_linear_todo_reconciliation(
                            cand["linear_id"],
                            cand["issue_key"],
                            reason=f"linear_todo_throttle_revert_failed: {exc}",
                            now_override_ms=current_ms,
                        )
                break
            operator_guidance = self._get_linear_issue_operator_guidance(linear_issue)
            self.state_store.update_thread_state(
                cand["issue_key"],
                {
                    "repo": cand["repo"],
                    "number": cand["number"],
                    "subject_type": "Issue",
                    "url": cand["github_url"],
                    "title": cand["title"],
                    "linear_issue_id": cand["linear_id"],
                    "linear_issue_identifier": cand["linear_identifier"],
                    "linear_issue_url": cand["linear_url"],
                },
                now_override_ms=current_ms,
            )
            dispatched_targets.add(cand["issue_key"])
            res = self.execution_coordinator.execute_dispatch(
                kind="linear_todo_implement",
                is_automated_pr=False,
                state_key=cand["issue_key"],
                repo=cand["repo"],
                number=cand["number"],
                subject_kind="Issue",
                updated_at=cand["updated_at"],
                trigger_reason="linear_todo_implement",
                linear_issue_id=cand["linear_id"],
                linear_issue_identifier=cand["linear_identifier"],
                linear_issue_url=cand["linear_url"],
                operator_guidance=operator_guidance,
                github_url=cand["github_url"],
                defer_watermark_commit=True,
                now_override_ms=now_override_ms,
            )
            if not res.get("dispatched", True):
                try:
                    self.linear_client.update_issue(cand["linear_id"], state="Todo")
                except Exception as exc:
                    if not _is_linear_issue_not_found_error(exc):
                        sys.stderr.write(f"moltis-github-companion linear-todo-undispatched-revert warning ({cand['issue_key']} / {cand['linear_id']}): {exc}\n")
                        self.state_store.enqueue_linear_todo_reconciliation(
                            cand["linear_id"],
                            cand["issue_key"],
                            reason=f"linear_todo_undispatched_revert_failed: {exc}",
                            now_override_ms=current_ms,
                        )
                dispatches.append(res)
                break
            with self._deferred_dispatch_guard(res, now_override_ms=now_override_ms):
                turn_succeeded = bool(res.get("task_succeeded"))
                orig_failure_reason = str(res.get("failure_reason") or "turn_failed")
                post_state_name, verify_exc = self._fetch_linear_issue_state(cand["linear_id"])
                if verify_exc is not None or not post_state_name:
                    detail = str(verify_exc) if verify_exc is not None else "missing workflow state in Linear response"
                    sys.stderr.write(f"moltis-github-companion linear-todo-verify warning ({cand['issue_key']} / {cand['linear_id']}): {detail}\n")
                    self.execution_coordinator.defer_linear_todo_verification(
                        res,
                        verification_error=f"linear_todo_state_verify_failed: {detail}",
                        failure_reason=None if turn_succeeded else orig_failure_reason,
                        now_override_ms=now_override_ms,
                    )
                elif post_state_name in ("in progress", "in_progress"):
                    try:
                        self.linear_client.update_issue(cand["linear_id"], state="Todo")
                    except Exception as exc:
                        sys.stderr.write(f"moltis-github-companion linear-todo-revert warning ({cand['issue_key']} / {cand['linear_id']}): {exc}\n")
                        self.execution_coordinator.defer_linear_todo_verification(
                            res,
                            verification_error=f"linear_todo_revert_failed: {exc}",
                            failure_reason="linear_todo_state_unchanged_in_progress" if turn_succeeded else orig_failure_reason,
                            now_override_ms=now_override_ms,
                        )
                    else:
                        self.execution_coordinator.fail_deferred_dispatch(
                            res,
                            failure_reason="linear_todo_state_unchanged_in_progress" if turn_succeeded else orig_failure_reason,
                            now_override_ms=now_override_ms,
                        )
                elif turn_succeeded:
                    self.execution_coordinator.commit_deferred_dispatch(res, now_override_ms=now_override_ms)
                else:
                    self.execution_coordinator.fail_deferred_dispatch(
                        res,
                        failure_reason=orig_failure_reason,
                        now_override_ms=now_override_ms,
                    )
            dispatches.append(res)
        return dispatches

    def _send_do_not_merge_signoff_pings(self, signoff_ready_prs: Iterable[dict], *, current_ms: int) -> list[dict]:
        if self.state_store.agent_name not in SWEEP_AGENT_ORDER:
            return []
        notifications: list[dict] = []
        for pr_item in signoff_ready_prs or ():
            if not isinstance(pr_item, dict):
                continue
            repo = str(pr_item.get("repo") or "").strip()
            number = _safe_int(pr_item.get("number"), 0)
            pr_key = str(pr_item.get("key") or "").strip() or (make_pr_key(repo, number) if repo and number > 0 else "")
            head_sha = str(pr_item.get("head_sha") or "").strip()
            if not pr_key or not head_sha:
                continue
            if repo and number > 0 and compute_pr_owner(repo, number) != self.state_store.agent_name:
                continue
            entry = _as_dict(self.state_store.get_thread_state(pr_key))
            if bool(entry.get("coercion_blocked")) or entry.get("ready_for_signoff_notified_sha") == head_sha:
                continue
            pr_url = str(pr_item.get("url") or entry.get("url") or "").strip() or (f"https://github.com/{repo}/pull/{number}" if repo and number > 0 else "")
            if not pr_url:
                continue
            raw_title = str(pr_item.get("title") or entry.get("title") or "").strip()
            pr_title = " ".join(raw_title.splitlines()).strip() or (f"{repo}#{number}" if repo and number > 0 else pr_key)
            msg = f"🚦 {pr_url} - {pr_title}"
            sent, err = self.execution_coordinator._send_telegram_safe(msg)
            if not sent:
                continue
            self.state_store.update_thread_state(
                pr_key,
                {
                    **({"repo": repo} if repo else {}),
                    **({"number": number} if number > 0 else {}),
                    "url": pr_url,
                    "title": pr_title,
                    "ready_for_signoff_notified_sha": head_sha,
                },
                now_override_ms=current_ms,
            )
            notifications.append({
                "key": pr_key,
                "repo": repo,
                "number": number or None,
                "head_sha": head_sha,
                "url": pr_url,
                "title": pr_title,
                "message": msg,
                "sent": True,
                "error": err,
            })
        return notifications

    def _send_needs_decision_ping(
        self,
        *,
        pr_key: str,
        linear_url: str,
        repo: str,
        number: int,
        title: str,
        head_sha: str,
        current_ms: int,
    ) -> dict | None:
        clean_key = str(pr_key or "").strip()
        clean_url = str(linear_url or "").strip()
        clean_sha = str(head_sha or "").strip()
        if not clean_key or not clean_url or not clean_sha:
            return None
        entry = _as_dict(self.state_store.get_thread_state(clean_key))
        if entry.get("decision_notified_sha") == clean_sha:
            return None
        clean_title = " ".join(str(title or entry.get("title") or "").splitlines()).strip() or f"{repo}#{number}"
        msg = f"🧑‍⚖️ {clean_url} - {repo}#{number}: {clean_title}"
        sent, err = self.execution_coordinator._send_telegram_safe(msg)
        if not sent:
            return None
        self.state_store.update_thread_state(
            clean_key,
            {
                **({"repo": repo} if repo else {}),
                **({"number": number} if number > 0 else {}),
                "title": clean_title,
                "linear_issue_url": clean_url,
                "decision_notified_sha": clean_sha,
            },
            now_override_ms=current_ms,
        )
        return {
            "key": clean_key,
            "repo": repo,
            "number": number,
            "head_sha": clean_sha,
            "linear_url": clean_url,
            "title": clean_title,
            "message": msg,
            "sent": True,
            "error": err,
        }

    @staticmethod
    def _latest_blind_verdict(
        verdicts: list[dict[str, object]],
        predicate: Callable[[dict[str, object]], bool],
    ) -> dict[str, object] | None:
        matched = [v for v in verdicts if predicate(v)]
        if not matched:
            return None
        best_idx = 0
        best_key = (0, 0)
        for idx, item in enumerate(matched):
            _, ts_ms = normalize_ts(item.get("created_at") or item.get("updated_at"))
            sort_key = (ts_ms, idx)
            if sort_key >= best_key:
                best_key = sort_key
                best_idx = idx
        return matched[best_idx]

    def _evaluate_lane_a_consensus(
        self,
        *,
        linear_id: str,
        linear_identifier: str | None,
        linear_url: str | None,
        pr_entry: dict,
        head_sha: str,
        ci_state: str,
        unresolved_thread_count: int,
        slot_id: str,
        dispatched_targets: set[str],
        current_ms: int,
        now_override_ms: int | None,
    ) -> dict | None:
        _ = slot_id
        if self.linear_client is None or self.state_store.agent_name not in SWEEP_AGENT_ORDER:
            return None
        clean_linear_id = str(linear_id or "").strip()
        clean_sha = str(head_sha or "").strip()
        if not clean_linear_id or not clean_sha:
            return None
        repo = str(pr_entry.get("repo") or "").strip()
        number = _safe_int(pr_entry.get("number"), 0)
        pr_key = str(pr_entry.get("pr_key") or pr_entry.get("key") or "").strip() or (make_pr_key(repo, number) if repo and number > 0 else "")
        if not pr_key or not repo or number <= 0:
            return None
        pr_url = str(pr_entry.get("url") or "").strip() or f"https://github.com/{repo}/pull/{number}"
        title = str(pr_entry.get("title") or "").strip() or f"{repo}#{number}"
        updated_at = str(pr_entry.get("updated_at") or pr_entry.get("updatedAt") or "").strip() or None
        pr_labels = extract_label_names(pr_entry.get("labels"))
        norm_ci = normalize_ci_state(ci_state)
        unresolved = max(0, _safe_int(unresolved_thread_count, 0))

        try:
            comments = self.linear_client.list_issue_comments(clean_linear_id)
        except Exception as exc:
            sys.stderr.write(f"moltis-github-companion lane-a-comments warning ({pr_key} / {clean_linear_id}): {exc}\n")
            return None

        verdicts = linear_sync.parse_blind_review_verdicts(comments, head_sha=clean_sha)
        gemini_verdict = self._latest_blind_verdict(
            verdicts,
            lambda v: str(v.get("model_family") or "").strip().lower() == "gemini",
        )
        gpt_verdict = self._latest_blind_verdict(
            verdicts,
            lambda v: str(v.get("model_family") or "").strip().lower() == "gpt"
            or str(v.get("agent") or "").strip().lower() == "traya",
        )
        gemini_val = str(gemini_verdict.get("verdict") or "").strip().lower() if gemini_verdict else None
        gpt_val = str(gpt_verdict.get("verdict") or "").strip().lower() if gpt_verdict else None

        if (gemini_val is not None and gemini_val != "pass") or (gpt_val is not None and gpt_val != "pass"):
            try:
                self.linear_client.update_issue(
                    clean_linear_id,
                    state="Backlog",
                    add_labels=("needs-decision",),
                    remove_labels=("ready-to-merge",),
                )
            except Exception as exc:
                sys.stderr.write(f"moltis-github-companion lane-a-escalate warning ({pr_key} / {clean_linear_id}): {exc}\n")
                return None
            ping = self._send_needs_decision_ping(
                pr_key=pr_key,
                linear_url=str(linear_url or pr_entry.get("linear_issue_url") or "").strip(),
                repo=repo,
                number=number,
                title=title,
                head_sha=clean_sha,
                current_ms=current_ms,
            )
            self.state_store.complete_thread_review(
                pr_key,
                handled_updated_at=updated_at,
                handled_head_sha=clean_sha,
                handled_ci_state=norm_ci,
                record_triaged_head_sha=True,
                apply_cooldown=False,
                now_override_ms=current_ms,
            )
            return {
                "action": "escalated_needs_decision",
                "key": pr_key,
                "repo": repo,
                "number": number,
                "head_sha": clean_sha,
                "linear_issue_id": clean_linear_id,
                "linear_issue_identifier": linear_identifier,
                "linear_issue_url": linear_url,
                "gemini_verdict": gemini_val,
                "gpt_verdict": gpt_val,
                "needs_decision_notification": ping,
                "dispatch": None,
            }

        if (
            gemini_val == "pass"
            and gpt_val == "pass"
            and norm_ci in ("SUCCESS", "NONE")
            and unresolved == 0
            and not has_do_not_merge_label(pr_labels)
        ):
            stored_entry = _as_dict(self.state_store.get_thread_state(pr_key))
            if _safe_int(stored_entry.get("retry_count"), 0) >= MAX_THREAD_FAILURE_RETRIES:
                return None
            if not self.state_store.can_consume_throttle("community_pr_reviews", slot_id=slot_id, now_override_ms=current_ms):
                return None
            consumed, _ = self.state_store.consume_throttle("community_pr_reviews", slot_id=slot_id, now_override_ms=current_ms)
            if not consumed:
                return None
            comments_by_id = {
                str(c.get("id")): str(c.get("body") or "")
                for c in (comments or ())
                if isinstance(c, dict) and c.get("id") is not None
            }
            polish_parts: list[str] = []
            for v_item in (gemini_verdict, gpt_verdict):
                cid = v_item.get("comment_id") if isinstance(v_item, dict) else None
                if cid is not None and str(cid) in comments_by_id:
                    p_note = _extract_polish_from_comment_body(comments_by_id[str(cid)])
                    if p_note and p_note not in polish_parts:
                        polish_parts.append(p_note)
            lane_a_polish = "; ".join(polish_parts) if polish_parts else None
            operator_guidance = _resolve_linear_operator_guidance(None, comments=comments)
            dispatched_targets.add(pr_key)
            dispatch_res = self.execution_coordinator.execute_dispatch(
                kind="community_pr_lane_a_merge",
                is_automated_pr=False,
                thread_id=str(stored_entry.get("thread_id") or pr_entry.get("thread_id") or "").strip() or None,
                state_key=pr_key,
                repo=repo,
                number=number,
                subject_kind="PullRequest",
                head_sha=clean_sha,
                ci_state=norm_ci,
                updated_at=updated_at,
                trigger_reason="community_pr_lane_a_consensus",
                community_auto_merge_eligible=True,
                linear_issue_id=clean_linear_id,
                linear_issue_identifier=linear_identifier,
                linear_issue_url=linear_url,
                operator_guidance=operator_guidance,
                github_url=pr_url,
                lane_a_polish_notes=lane_a_polish,
                defer_watermark_commit=True,
                now_override_ms=now_override_ms,
            )
            action = "lane_a_merge_failed"
            ping: dict | None = None
            if dispatch_res.get("task_succeeded"):
                with self._deferred_dispatch_guard(dispatch_res, now_override_ms=now_override_ms):
                    merge_outcome, merge_detail = parse_lane_a_merge_reply(
                        str(dispatch_res.get("reply_text") or ""),
                        repo=repo,
                        number=number,
                        linear_url=linear_url,
                    )
                    if merge_outcome == "merged":
                        if self.gh_client.is_pull_request_merged(repo, number):
                            action = "lane_a_merged"
                            try:
                                self.linear_client.update_issue(clean_linear_id, state="Done")
                            except Exception as exc:
                                sys.stderr.write(f"moltis-github-companion lane-a-done warning ({pr_key} / {clean_linear_id}): {exc}\n")
                            self.execution_coordinator.commit_deferred_dispatch(dispatch_res, now_override_ms=now_override_ms)
                        else:
                            action = "lane_a_merge_failed"
                            self.execution_coordinator.fail_deferred_dispatch(
                                dispatch_res,
                                failure_reason="merge_not_confirmed_on_github",
                                now_override_ms=now_override_ms,
                            )
                    elif merge_outcome == "needs_decision":
                        try:
                            self.linear_client.update_issue(
                                clean_linear_id,
                                state="Backlog",
                                add_labels=("needs-decision",),
                                remove_labels=("ready-to-merge",),
                            )
                        except Exception as exc:
                            sys.stderr.write(f"moltis-github-companion lane-a-escalate warning ({pr_key} / {clean_linear_id}): {exc}\n")
                            self.execution_coordinator.fail_deferred_dispatch(
                                dispatch_res,
                                failure_reason=f"linear_lane_a_escalate_failed: {exc}",
                                now_override_ms=now_override_ms,
                            )
                            action = "lane_a_merge_escalate_failed"
                        else:
                            action = "lane_a_merge_needs_decision"
                            self.execution_coordinator.commit_deferred_dispatch(dispatch_res, now_override_ms=now_override_ms)
                            clean_linear_url = str(linear_url or pr_entry.get("linear_issue_url") or "").strip()
                            if dispatch_res.get("telegram_forwarded"):
                                self.state_store.update_thread_state(
                                    pr_key,
                                    {
                                        "repo": repo,
                                        "number": number,
                                        "title": title,
                                        **({"linear_issue_url": clean_linear_url} if clean_linear_url else {}),
                                        "decision_notified_sha": clean_sha,
                                    },
                                    now_override_ms=current_ms,
                                )
                                ping = {
                                    "key": pr_key,
                                    "repo": repo,
                                    "number": number,
                                    "head_sha": clean_sha,
                                    "linear_url": clean_linear_url,
                                    "title": title,
                                    "message": merge_detail,
                                    "sent": True,
                                    "error": None,
                                }
                    else:
                        self.execution_coordinator.commit_deferred_dispatch(dispatch_res, now_override_ms=now_override_ms)
            return {
                "action": action,
                "key": pr_key,
                "repo": repo,
                "number": number,
                "head_sha": clean_sha,
                "linear_issue_id": clean_linear_id,
                "linear_issue_identifier": linear_identifier,
                "linear_issue_url": linear_url,
                "gemini_verdict": gemini_val,
                "gpt_verdict": gpt_val,
                "lane_a_polish_notes": lane_a_polish,
                "needs_decision_notification": ping,
                "dispatch": dispatch_res,
            }

        return None

    def _run_own_blind_review_and_post(
        self,
        *,
        pr_key: str,
        repo: str,
        number: int,
        pr_url: str,
        head_sha: str,
        ci_state: str,
        updated_at: str | None,
        thread_id: str | None,
        linear_id: str,
        linear_identifier: str | None,
        linear_url: str | None,
        slot_id: str,
        dispatched_targets: set[str],
        current_ms: int,
        now_override_ms: int | None,
    ) -> tuple[dict | None, dict | None]:
        """Run owning Gemini agent's diff-only blind review and post verdict to Linear."""
        if self.linear_client is None:
            return None, None
        if not self.state_store.can_consume_throttle("community_pr_reviews", slot_id=slot_id, now_override_ms=current_ms):
            return None, None
        consumed, _ = self.state_store.consume_throttle("community_pr_reviews", slot_id=slot_id, now_override_ms=current_ms)
        if not consumed:
            return None, None
        dispatched_targets.add(pr_key)
        review_res = self.execution_coordinator.execute_dispatch(
            kind="community_pr_blind_review",
            is_automated_pr=False,
            thread_id=thread_id,
            state_key=pr_key,
            repo=repo,
            number=number,
            subject_kind="PullRequest",
            head_sha=head_sha,
            ci_state=ci_state,
            updated_at=updated_at,
            trigger_reason="community_pr_blind_review",
            community_auto_merge_eligible=True,
            linear_issue_id=linear_id,
            linear_issue_identifier=linear_identifier,
            linear_issue_url=linear_url,
            github_url=pr_url,
            defer_watermark_commit=True,
            now_override_ms=now_override_ms,
        )
        if not review_res.get("task_succeeded"):
            return review_res, {
                "action": "blind_review_failed",
                "key": pr_key,
                "repo": repo,
                "number": number,
                "head_sha": head_sha,
                "agent": self.state_store.agent_name,
                "model_family": MODEL_FAMILY_BY_AGENT.get(self.state_store.agent_name, "gemini"),
                "verdict": None,
                "linear_issue_id": linear_id,
                "linear_issue_identifier": linear_identifier,
                "linear_issue_url": linear_url,
            }
        with self._deferred_dispatch_guard(review_res, now_override_ms=now_override_ms):
            verdict, findings, polish = parse_blind_review_reply(str(review_res.get("reply_text") or ""))
            summary_parts: list[str] = []
            if findings:
                summary_parts.append(f"FINDINGS: {findings}")
            if polish:
                summary_parts.append(f"POLISH: {polish}")
            verdict_summary = "\n".join(summary_parts)
            model_family = MODEL_FAMILY_BY_AGENT.get(self.state_store.agent_name, "gemini")
            try:
                self.linear_client.post_blind_review_verdict(
                    linear_id,
                    agent=self.state_store.agent_name,
                    model_family=model_family,
                    head_sha=head_sha,
                    verdict=verdict,
                    summary=verdict_summary,
                )
            except Exception as exc:
                sys.stderr.write(f"moltis-github-companion blind-verdict-post warning ({pr_key} / {linear_id}): {exc}\n")
                self.execution_coordinator.fail_deferred_dispatch(
                    review_res,
                    failure_reason=f"linear_blind_verdict_post_failed: {exc}",
                    now_override_ms=now_override_ms,
                )
                return review_res, None
            self.execution_coordinator.commit_deferred_dispatch(review_res, now_override_ms=now_override_ms)
        return review_res, {
            "action": "blind_review_posted",
            "key": pr_key,
            "repo": repo,
            "number": number,
            "head_sha": head_sha,
            "agent": self.state_store.agent_name,
            "model_family": model_family,
            "verdict": verdict,
            "findings": findings,
            "polish": polish,
            "linear_issue_id": linear_id,
            "linear_issue_identifier": linear_identifier,
            "linear_issue_url": linear_url,
        }

    def _maybe_approve_action_required_ci(
        self,
        *,
        pr_key: str,
        repo: str,
        number: int,
        head_sha: str,
        live_pr: dict,
        pr_entry: dict,
        linear_id: str,
        linear_identifier: str | None,
        linear_url: str | None,
        current_ms: int,
        allow_first_time: bool = False,
    ) -> dict | None:
        clean_sha = str(head_sha or "").strip()
        if not clean_sha or not hasattr(self.gh_client, "approve_pending_pr_workflow_runs"):
            return None
        rollup = live_pr.get("statusCheckRollup") if "statusCheckRollup" in live_pr else pr_entry.get("statusCheckRollup")
        if not has_action_required_ci(rollup):
            return None
        author_association = str(
            live_pr.get("author_association")
            or live_pr.get("authorAssociation")
            or pr_entry.get("author_association")
            or ""
        ).strip().upper()
        if not allow_first_time and is_first_time_contributor_association(author_association):
            return None
        file_paths = live_pr.get("file_paths") if "file_paths" in live_pr else pr_entry.get("file_paths")
        files_has_next_page = bool(live_pr.get("files_has_next_page", pr_entry.get("files_has_next_page", False)))
        paths_list = [str(p).strip() for p in (file_paths or ()) if isinstance(p, str) and str(p).strip()] if file_paths is not None else []
        if files_has_next_page or not paths_list or any(is_sensitive_community_pr_path(p) for p in paths_list):
            return None
        stored_entry = _as_dict(self.state_store.get_thread_state(pr_key))
        if stored_entry.get("ci_approved_head_sha") == clean_sha:
            return None
        try:
            approved_ids = self.gh_client.approve_pending_pr_workflow_runs(repo, clean_sha)
        except Exception as exc:
            sys.stderr.write(f"moltis-github-companion ci-workflow-approve warning ({pr_key} / {linear_id}): {exc}\n")
            return None
        if not approved_ids:
            return None
        self.state_store.update_thread_state(
            pr_key,
            {"ci_approved_head_sha": clean_sha},
            now_override_ms=current_ms,
        )
        return {
            "action": "ci_workflows_approved",
            "key": pr_key,
            "repo": repo,
            "number": number,
            "head_sha": clean_sha,
            "approved_run_ids": list(approved_ids),
            "linear_issue_id": linear_id,
            "linear_issue_identifier": linear_identifier,
            "linear_issue_url": linear_url,
        }

    def _run_lane_a_pr_evaluation(
        self,
        *,
        pr_key: str,
        repo: str,
        number: int,
        pr_url: str,
        title: str,
        head_sha: str,
        ci_state: str,
        updated_at: str | None,
        pr_labels: list[str],
        unresolved_threads: int,
        thread_id: str | None,
        pr_entry: dict,
        live_pr: dict,
        linear_id: str,
        linear_identifier: str | None,
        linear_url: str | None,
        own_family: str,
        slot_id: str,
        dispatched_targets: set[str],
        processed_pr_keys: set[str],
        dispatches: list[dict],
        linear_pr_actions: list[dict],
        notifications: list[dict],
        current_ms: int,
        now_override_ms: int | None,
    ) -> None:
        if self.linear_client is None:
            return
        try:
            existing_comments = self.linear_client.list_issue_comments(linear_id)
        except Exception as exc:
            sys.stderr.write(f"moltis-github-companion lane-a-comments warning ({pr_key} / {linear_id}): {exc}\n")
            return
        existing_verdicts = linear_sync.parse_blind_review_verdicts(existing_comments, head_sha=head_sha)
        own_verdict = self._latest_blind_verdict(
            existing_verdicts,
            lambda v: str(v.get("agent") or "").strip().lower() == self.state_store.agent_name
            or str(v.get("model_family") or "").strip().lower() == own_family,
        )
        own_verdict_is_pass = bool(own_verdict and str(own_verdict.get("verdict") or "").strip().lower() == "pass")
        if own_verdict is None:
            review_res, action_rec = self._run_own_blind_review_and_post(
                pr_key=pr_key,
                repo=repo,
                number=number,
                pr_url=pr_url,
                head_sha=head_sha,
                ci_state=ci_state,
                updated_at=updated_at,
                thread_id=thread_id,
                linear_id=linear_id,
                linear_identifier=linear_identifier,
                linear_url=linear_url,
                slot_id=slot_id,
                dispatched_targets=dispatched_targets,
                current_ms=current_ms,
                now_override_ms=now_override_ms,
            )
            if review_res is None:
                return
            processed_pr_keys.add(pr_key)
            dispatches.append(review_res)
            if action_rec is not None:
                linear_pr_actions.append(action_rec)
            if not review_res.get("task_succeeded") or action_rec is None:
                return
            own_verdict_is_pass = str(action_rec.get("verdict") or "").strip().lower() == "pass"
        else:
            processed_pr_keys.add(pr_key)

        pr_info = {
            **pr_entry,
            **live_pr,
            "pr_key": pr_key,
            "repo": repo,
            "number": number,
            "url": pr_url,
            "title": title,
            "head_sha": head_sha,
            "ci_state": ci_state,
            "updated_at": updated_at,
            "labels": pr_labels,
            "linear_issue_url": linear_url,
        }
        consensus = self._evaluate_lane_a_consensus(
            linear_id=linear_id,
            linear_identifier=linear_identifier,
            linear_url=linear_url,
            pr_entry=pr_info,
            head_sha=head_sha,
            ci_state=ci_state,
            unresolved_thread_count=unresolved_threads,
            slot_id=slot_id,
            dispatched_targets=dispatched_targets,
            current_ms=current_ms,
            now_override_ms=now_override_ms,
        )
        if consensus is not None:
            linear_pr_actions.append(consensus)
            if isinstance(consensus.get("dispatch"), dict):
                dispatches.append(consensus["dispatch"])
            if isinstance(consensus.get("needs_decision_notification"), dict):
                notifications.append(consensus["needs_decision_notification"])
        elif own_verdict_is_pass:
            ci_action = self._maybe_approve_action_required_ci(
                pr_key=pr_key,
                repo=repo,
                number=number,
                head_sha=head_sha,
                live_pr=live_pr,
                pr_entry=pr_entry,
                linear_id=linear_id,
                linear_identifier=linear_identifier,
                linear_url=linear_url,
                current_ms=current_ms,
                allow_first_time=False,
            )
            if ci_action is not None:
                linear_pr_actions.append(ci_action)

    def _run_lane_b_pr_review(
        self,
        *,
        pr_key: str,
        repo: str,
        number: int,
        pr_url: str,
        title: str,
        head_sha: str,
        ci_state: str,
        updated_at: str | None,
        additions: object,
        deletions: object,
        changed_files: object,
        file_paths: object,
        files_has_next_page: bool,
        author_association: str | None = None,
        mergeable: str | None = None,
        merge_state_status: str | None = None,
        auto_merge_eligible: bool,
        thread_id: str | None,
        linear_id: str,
        linear_identifier: str | None,
        linear_url: str | None,
        linear_estimate: int | None = None,
        operator_guidance: Iterable[dict[str, str]] | None = None,
        slot_id: str,
        dispatched_targets: set[str],
        processed_pr_keys: set[str],
        dispatches: list[dict],
        linear_pr_actions: list[dict],
        notifications: list[dict],
        current_ms: int,
        now_override_ms: int | None,
    ) -> str:
        if self.linear_client is None:
            return "throttled"
        is_first_time = is_first_time_contributor_association(author_association)
        has_conflicts = is_merge_conflicting(mergeable, merge_state_status)
        guidance_list = [
            item
            for item in (operator_guidance or ())
            if isinstance(item, dict) and str(item.get("body") or "").strip()
        ]
        has_operator_guidance = bool(guidance_list)
        bypass_reasons = compute_lane_a_bypass_reasons(
            repo=repo,
            additions=additions,  # type: ignore[arg-type]
            deletions=deletions,  # type: ignore[arg-type]
            changed_files=changed_files,  # type: ignore[arg-type]
            file_paths=file_paths,  # type: ignore[arg-type]
            files_has_next_page=files_has_next_page,
            ci_state=ci_state,
            author_association=author_association,
            mergeable=mergeable,
            merge_state_status=merge_state_status,
            has_operator_guidance=has_operator_guidance,
            enabled=self.state_store.community_auto_merge_enabled,
            max_lines=self.state_store.community_auto_merge_max_lines,
            max_files=self.state_store.community_auto_merge_max_files,
            excluded_repos=self.state_store.community_auto_merge_excluded_repos,
        )
        if not self.state_store.can_consume_throttle("community_pr_reviews", slot_id=slot_id, now_override_ms=current_ms):
            return "throttled"
        consumed, _ = self.state_store.consume_throttle("community_pr_reviews", slot_id=slot_id, now_override_ms=current_ms)
        if not consumed:
            return "throttled"
        dispatched_targets.add(pr_key)
        processed_pr_keys.add(pr_key)
        lane_b_res = self.execution_coordinator.execute_dispatch(
            kind="community_pr_lane_b_review",
            is_automated_pr=False,
            thread_id=thread_id,
            state_key=pr_key,
            repo=repo,
            number=number,
            subject_kind="PullRequest",
            head_sha=head_sha,
            ci_state=ci_state,
            updated_at=updated_at,
            trigger_reason="community_pr_lane_b_review",
            community_auto_merge_eligible=bool(auto_merge_eligible),
            linear_issue_id=linear_id,
            linear_issue_identifier=linear_identifier,
            linear_issue_url=linear_url,
            linear_issue_estimate=linear_estimate,
            operator_guidance=guidance_list,
            github_url=pr_url,
            bypass_reasons=bypass_reasons,
            defer_watermark_commit=True,
            now_override_ms=now_override_ms,
        )
        dispatches.append(lane_b_res)
        if not lane_b_res.get("task_succeeded"):
            linear_pr_actions.append({
                "action": "lane_b_review_failed",
                "key": pr_key,
                "repo": repo,
                "number": number,
                "head_sha": head_sha,
                "bypass_reasons": bypass_reasons,
                "linear_issue_id": linear_id,
                "linear_issue_identifier": linear_identifier,
                "linear_issue_url": linear_url,
            })
            return "dispatch_failed"
        with self._deferred_dispatch_guard(lane_b_res, now_override_ms=now_override_ms):
            lane_b_verdict, lane_b_summary = parse_lane_b_reply(str(lane_b_res.get("reply_text") or ""))
            add_list: list[str] = []
            rem_list: list[str] = []
            if is_first_time:
                add_list.append("first-time")
            if has_conflicts:
                add_list.append("merge-conflicts")
            if is_first_time or has_conflicts:
                rem_list.append("ready-to-merge")
                if lane_b_verdict == "needs-decision":
                    add_list.append("needs-decision")
                else:
                    rem_list.append("needs-decision")
            elif lane_b_verdict == "ready-to-merge":
                add_list.append("ready-to-merge")
                rem_list.append("needs-decision")
            else:
                add_list.append("needs-decision")
                rem_list.append("ready-to-merge")
            add_lbls = tuple(add_list)
            rem_lbls = tuple(rem_list)
            try:
                self.linear_client.update_issue(
                    linear_id,
                    state="Backlog",
                    add_labels=add_lbls,
                    remove_labels=rem_lbls,
                )
            except Exception as exc:
                sys.stderr.write(f"moltis-github-companion lane-b-update warning ({pr_key} / {linear_id}): {exc}\n")
                self.execution_coordinator.fail_deferred_dispatch(
                    lane_b_res,
                    failure_reason=f"linear_lane_b_update_failed: {exc}",
                    now_override_ms=now_override_ms,
                )
                return "update_failed"
            self.execution_coordinator.commit_deferred_dispatch(lane_b_res, now_override_ms=now_override_ms)
        ping = None
        if lane_b_verdict == "needs-decision":
            ping = self._send_needs_decision_ping(
                pr_key=pr_key,
                linear_url=linear_url or "",
                repo=repo,
                number=number,
                title=title,
                head_sha=head_sha,
                current_ms=current_ms,
            )
            if ping is not None:
                notifications.append(ping)
        linear_pr_actions.append({
            "action": "lane_b_reviewed",
            "key": pr_key,
            "repo": repo,
            "number": number,
            "head_sha": head_sha,
            "verdict": lane_b_verdict,
            "summary": lane_b_summary,
            "bypass_reasons": bypass_reasons,
            "linear_issue_id": linear_id,
            "linear_issue_identifier": linear_identifier,
            "linear_issue_url": linear_url,
            "needs_decision_notification": ping,
        })
        return "updated"

    def _process_linear_community_prs(
        self,
        actionable_prs: Iterable[dict],
        *,
        active_linear_issues: Iterable[dict],
        open_prs_by_key: dict[str, dict],
        slot_id: str,
        dispatched_targets: set[str],
        current_ms: int,
        now_override_ms: int | None,
        linear_breaker: _LinearWriteCircuitBreaker | None = None,
    ) -> dict:
        dispatches: list[dict] = []
        linear_pr_actions: list[dict] = []
        notifications: list[dict] = []
        linear_issues_by_pr_key: dict[str, dict] = {}
        if self.linear_client is None or self.state_store.agent_name not in SWEEP_AGENT_ORDER:
            return {
                "dispatches": dispatches,
                "linear_pr_actions": linear_pr_actions,
                "needs_decision_notifications": notifications,
                "linear_issues_by_pr_key": linear_issues_by_pr_key,
            }

        breaker = linear_breaker if linear_breaker is not None else _LinearWriteCircuitBreaker()
        processed_pr_keys: set[str] = set()
        own_family = MODEL_FAMILY_BY_AGENT.get(self.state_store.agent_name, "gemini")
        active_linear_by_id: dict[str, dict] = {}
        active_linear_by_pr_key: dict[str, dict] = {}
        for active_item in active_linear_issues or ():
            if not isinstance(active_item, dict):
                continue
            aid = str(active_item.get("id") or "").strip()
            if aid:
                active_linear_by_id[aid] = active_item
            a_target = extract_linear_github_target(active_item, expected_kind="PR")
            if a_target is not None:
                active_linear_by_pr_key[make_pr_key(a_target[0], a_target[2])] = active_item

        for pr_item in actionable_prs or ():
            if breaker.skip_if_tripped(scope="linear-pr-ensure"):
                break
            if not isinstance(pr_item, dict) or not bool(pr_item.get("is_community")):
                continue
            pr_key = str(pr_item.get("key") or "").strip()
            repo = str(pr_item.get("repo") or "").strip()
            number = _safe_int(pr_item.get("number"), 0)
            if not pr_key or not repo or number <= 0:
                continue
            if not is_allowed_notification_repo(repo) or compute_pr_owner(repo, number) != self.state_store.agent_name:
                continue
            if pr_key in dispatched_targets:
                continue
            pr_entry = _as_dict(self.state_store.get_thread_state(pr_key))
            if bool(pr_entry.get("coercion_blocked")) or _safe_int(pr_entry.get("retry_count"), 0) >= MAX_THREAD_FAILURE_RETRIES:
                continue
            trig_reason = str(pr_item.get("trigger_reason") or "open_pr_poll")
            if trig_reason != "ci_green_after_approval" and _safe_int(pr_entry.get("followup_cooldown_until_ms"), 0) > current_ms:
                continue

            live_pr = _as_dict(open_prs_by_key.get(pr_key))
            head_sha = str(pr_item.get("head_sha") or live_pr.get("head_sha") or pr_entry.get("head_sha") or "").strip()
            ci_state = normalize_ci_state(pr_item.get("ci_state") or live_pr.get("ci_state") or pr_entry.get("ci_state"))
            updated_at = str(pr_item.get("updated_at") or live_pr.get("updated_at") or pr_entry.get("updated_at") or "").strip() or None
            pr_url = str(live_pr.get("url") or pr_entry.get("url") or "").strip() or f"https://github.com/{repo}/pull/{number}"
            title = str(live_pr.get("title") or pr_entry.get("title") or "").strip() or f"{repo}#{number}"
            pr_labels = extract_label_names(live_pr.get("labels") if "labels" in live_pr else pr_entry.get("labels"))
            has_dnm = has_do_not_merge_label(pr_labels)
            unresolved_threads = max(
                0,
                _safe_int(
                    live_pr.get("unresolved_thread_count") if "unresolved_thread_count" in live_pr else pr_entry.get("unresolved_thread_count"),
                    0,
                ),
            )
            additions = pr_item.get("additions") if "additions" in pr_item else live_pr.get("additions")
            deletions = pr_item.get("deletions") if "deletions" in pr_item else live_pr.get("deletions")
            changed_files = pr_item.get("changed_files") if "changed_files" in pr_item else live_pr.get("changed_files")
            file_paths = pr_item.get("file_paths") if "file_paths" in pr_item else live_pr.get("file_paths")
            files_has_next_page = bool(pr_item.get("files_has_next_page", live_pr.get("files_has_next_page", False)))
            author_association = str(
                pr_item.get("author_association")
                or live_pr.get("author_association")
                or live_pr.get("authorAssociation")
                or pr_entry.get("author_association")
                or ""
            ).strip().upper()
            mergeable = normalize_mergeable_state(
                live_pr.get("mergeable") if "mergeable" in live_pr else pr_item.get("mergeable"),
                live_pr.get("merge_state_status") or live_pr.get("mergeStateStatus") or pr_item.get("merge_state_status"),
            )
            merge_state_status = str(
                live_pr.get("merge_state_status")
                or live_pr.get("mergeStateStatus")
                or pr_item.get("merge_state_status")
                or ""
            ).strip().upper()
            is_first_time = is_first_time_contributor_association(author_association)
            has_conflicts = mergeable == "CONFLICTING"
            pre_guidance = _resolve_linear_operator_guidance(active_linear_by_pr_key.get(pr_key))
            pre_has_operator_guidance = bool(pre_guidance)
            raw_eligible = pr_item.get("community_auto_merge_eligible")
            auto_merge_eligible = (
                bool(raw_eligible) and not is_first_time and not has_conflicts and not pre_has_operator_guidance
                if isinstance(raw_eligible, bool)
                else compute_community_auto_merge_eligible(
                    repo=repo,
                    additions=additions,
                    deletions=deletions,
                    changed_files=changed_files,
                    file_paths=file_paths,
                    files_has_next_page=files_has_next_page,
                    author_association=author_association,
                    mergeable=mergeable,
                    merge_state_status=merge_state_status,
                    has_operator_guidance=pre_has_operator_guidance,
                    enabled=self.state_store.community_auto_merge_enabled,
                    max_lines=self.state_store.community_auto_merge_max_lines,
                    max_files=self.state_store.community_auto_merge_max_files,
                    excluded_repos=self.state_store.community_auto_merge_excluded_repos,
                )
            )
            ci_needs_approval = has_action_required_ci(
                live_pr.get("statusCheckRollup") if "statusCheckRollup" in live_pr else pr_item.get("statusCheckRollup")
            )
            is_lane_a = bool(auto_merge_eligible) and (ci_state in ("SUCCESS", "NONE") or ci_needs_approval) and not has_dnm and not has_conflicts
            initial_state = "In Review" if is_lane_a else "Backlog"
            initial_extra_labels = tuple(
                lbl
                for lbl, cond in (("first-time", is_first_time), ("merge-conflicts", has_conflicts))
                if cond
            )

            pr_estimate = compute_pr_size_estimate(
                additions=additions,  # type: ignore[arg-type]
                deletions=deletions,  # type: ignore[arg-type]
                changed_files=changed_files,  # type: ignore[arg-type]
                file_paths=file_paths,  # type: ignore[arg-type]
                files_has_next_page=files_has_next_page,
            )

            try:
                linear_issue = self.linear_client.ensure_issue_for_github_item(
                    github_url=pr_url,
                    title=title,
                    repo=repo,
                    item_kind="PR",
                    state=initial_state,
                    extra_labels=initial_extra_labels,
                    estimate=pr_estimate,
                )
                linear_id = str(linear_issue.get("id") or "").strip()
                if not linear_id:
                    raise RuntimeError("Linear issue response missing id")
                linear_identifier = str(linear_issue.get("identifier") or "").strip() or None
                linear_url = str(linear_issue.get("url") or "").strip() or None
            except Exception as exc:
                if breaker.record_error(exc, scope="linear-pr-ensure", item_key=pr_key):
                    break
                sys.stderr.write(f"moltis-github-companion linear-pr-ensure warning ({pr_key}): {exc}\n")
                continue
            breaker.record_success()

            resolved_labels = extract_linear_issue_labels(linear_issue)
            if "issue" in resolved_labels and "pr" not in resolved_labels:
                sys.stderr.write(
                    f"moltis-github-companion linear-pr-kind-mismatch warning ({pr_key} / {linear_id}): refusing to update Issue-labelled Linear item\n"
                )
                continue
            linear_issues_by_pr_key[pr_key] = linear_issue
            if is_ignored_linear_issue_state(linear_issue):
                self.state_store.update_thread_state(
                    pr_key,
                    {
                        "repo": repo,
                        "number": number,
                        "subject_type": "PullRequest",
                        "url": pr_url,
                        "title": title,
                        "linear_issue_id": linear_id,
                        "linear_issue_identifier": linear_identifier,
                        "linear_issue_url": linear_url,
                        "handled_updated_at": updated_at or pr_entry.get("handled_updated_at"),
                        "handled_head_sha": head_sha or pr_entry.get("handled_head_sha"),
                        "handled_ci_state": ci_state or pr_entry.get("handled_ci_state"),
                    },
                    now_override_ms=current_ms,
                )
                processed_pr_keys.add(pr_key)
                continue

            self.state_store.update_thread_state(
                pr_key,
                {
                    "repo": repo,
                    "number": number,
                    "subject_type": "PullRequest",
                    "url": pr_url,
                    "title": title,
                    "linear_issue_id": linear_id,
                    "linear_issue_identifier": linear_identifier,
                    "linear_issue_url": linear_url,
                },
                now_override_ms=current_ms,
            )

            operator_guidance = self._get_linear_issue_operator_guidance(
                linear_issue,
                fallback_issue=active_linear_by_id.get(linear_id) or active_linear_by_pr_key.get(pr_key),
            )
            if operator_guidance:
                auto_merge_eligible = False
                is_lane_a = False

            thread_id = str(pr_item.get("thread_id") or pr_entry.get("thread_id") or "").strip() or None
            if is_lane_a:
                issue_state_name = str(_as_dict(linear_issue.get("state")).get("name") or "").strip().lower()
                issue_labels = resolved_labels
                if (
                    issue_state_name != "in review"
                    or "needs-decision" in issue_labels
                    or "ready-to-merge" in issue_labels
                ):
                    try:
                        self.linear_client.update_issue(
                            linear_id,
                            state="In Review",
                            remove_labels=("needs-decision", "ready-to-merge"),
                        )
                    except Exception as exc:
                        sys.stderr.write(
                            f"moltis-github-companion lane-a-issue-update warning ({pr_key} / {linear_id}): {exc}\n"
                        )
                        continue
                self._run_lane_a_pr_evaluation(
                    pr_key=pr_key,
                    repo=repo,
                    number=number,
                    pr_url=pr_url,
                    title=title,
                    head_sha=head_sha,
                    ci_state=ci_state,
                    updated_at=updated_at,
                    pr_labels=pr_labels,
                    unresolved_threads=unresolved_threads,
                    thread_id=thread_id,
                    pr_entry=pr_entry,
                    live_pr={**live_pr, **({"statusCheckRollup": pr_item["statusCheckRollup"]} if "statusCheckRollup" in pr_item and "statusCheckRollup" not in live_pr else {}), **({"file_paths": file_paths} if file_paths is not None and "file_paths" not in live_pr else {}), **({"files_has_next_page": files_has_next_page} if "files_has_next_page" not in live_pr else {})},
                    linear_id=linear_id,
                    linear_identifier=linear_identifier,
                    linear_url=linear_url,
                    own_family=own_family,
                    slot_id=slot_id,
                    dispatched_targets=dispatched_targets,
                    processed_pr_keys=processed_pr_keys,
                    dispatches=dispatches,
                    linear_pr_actions=linear_pr_actions,
                    notifications=notifications,
                    current_ms=current_ms,
                    now_override_ms=now_override_ms,
                )
            else:
                issue_labels = resolved_labels
                upfront_add = tuple(
                    lbl
                    for lbl, needed in (
                        ("first-time", is_first_time and "first-time" not in issue_labels),
                        ("merge-conflicts", has_conflicts and "merge-conflicts" not in issue_labels),
                    )
                    if needed
                )
                upfront_rem = ("ready-to-merge",) if "ready-to-merge" in issue_labels else ()
                if upfront_add or upfront_rem:
                    try:
                        linear_issue = self.linear_client.update_issue(
                            linear_id,
                            add_labels=upfront_add,
                            remove_labels=upfront_rem,
                        )
                    except Exception as exc:
                        sys.stderr.write(
                            f"moltis-github-companion lane-b-upfront-label warning ({pr_key} / {linear_id}): {exc}\n"
                        )
                    else:
                        linear_issues_by_pr_key[pr_key] = linear_issue
                        for lbl in upfront_add:
                            issue_labels.add(lbl)
                        for lbl in upfront_rem:
                            issue_labels.discard(lbl)
                raw_lin_est = linear_issue.get("estimate")
                linear_estimate = (
                    raw_lin_est
                    if isinstance(raw_lin_est, int) and not isinstance(raw_lin_est, bool) and raw_lin_est > 0
                    else pr_estimate
                )
                lane_b_outcome = self._run_lane_b_pr_review(
                    pr_key=pr_key,
                    repo=repo,
                    number=number,
                    pr_url=pr_url,
                    title=title,
                    head_sha=head_sha,
                    ci_state=ci_state,
                    updated_at=updated_at,
                    additions=additions,
                    deletions=deletions,
                    changed_files=changed_files,
                    file_paths=file_paths,
                    files_has_next_page=files_has_next_page,
                    author_association=author_association,
                    mergeable=mergeable,
                    merge_state_status=merge_state_status,
                    auto_merge_eligible=bool(auto_merge_eligible),
                    thread_id=thread_id,
                    linear_id=linear_id,
                    linear_identifier=linear_identifier,
                    linear_url=linear_url,
                    linear_estimate=linear_estimate,
                    operator_guidance=operator_guidance,
                    slot_id=slot_id,
                    dispatched_targets=dispatched_targets,
                    processed_pr_keys=processed_pr_keys,
                    dispatches=dispatches,
                    linear_pr_actions=linear_pr_actions,
                    notifications=notifications,
                    current_ms=current_ms,
                    now_override_ms=now_override_ms,
                )
                if lane_b_outcome in ("throttled", "dispatch_failed", "update_failed") and "ready-to-merge" in issue_labels:
                    try:
                        self.linear_client.update_issue(linear_id, remove_labels=("ready-to-merge",))
                    except Exception as exc:
                        sys.stderr.write(
                            f"moltis-github-companion lane-b-stale-label warning ({pr_key} / {linear_id}): {exc}\n"
                        )

        for linear_issue in active_linear_issues or ():
            if not isinstance(linear_issue, dict) or is_ignored_linear_issue_state(linear_issue):
                continue
            linear_id = str(linear_issue.get("id") or "").strip()
            if not linear_id:
                continue
            lin_labels = extract_linear_issue_labels(linear_issue)
            if "pr" not in lin_labels:
                continue
            target = extract_linear_github_target(linear_issue, expected_kind="PR")
            if target is None:
                continue
            repo, _, number, github_url = target
            if not is_allowed_notification_repo(repo) or compute_pr_owner(repo, number) != self.state_store.agent_name:
                continue
            pr_key = make_pr_key(repo, number)
            if pr_key in processed_pr_keys or pr_key in dispatched_targets:
                continue
            live_pr = _as_dict(open_prs_by_key.get(pr_key))
            if not live_pr:
                continue
            pr_entry = _as_dict(self.state_store.get_thread_state(pr_key))
            if bool(pr_entry.get("coercion_blocked")) or _safe_int(pr_entry.get("retry_count"), 0) >= MAX_THREAD_FAILURE_RETRIES:
                continue

            state_obj = _as_dict(linear_issue.get("state"))
            state_name = str(state_obj.get("name") or "").strip().lower()
            state_type = str(state_obj.get("type") or "").strip().lower()
            linear_identifier = str(linear_issue.get("identifier") or "").strip() or None
            linear_url = str(linear_issue.get("url") or "").strip() or None
            head_sha = str(live_pr.get("head_sha") or live_pr.get("headRefOid") or pr_entry.get("head_sha") or "").strip()
            ci_state = normalize_ci_state(live_pr.get("ci_state") or live_pr.get("statusCheckRollup") or pr_entry.get("ci_state"))
            updated_at = str(live_pr.get("updated_at") or live_pr.get("updatedAt") or pr_entry.get("updated_at") or "").strip() or None
            title = str(live_pr.get("title") or linear_issue.get("title") or pr_entry.get("title") or "").strip() or f"{repo}#{number}"
            pr_url = str(live_pr.get("url") or github_url or f"https://github.com/{repo}/pull/{number}").strip()
            pr_labels = extract_label_names(live_pr.get("labels"))
            unresolved_threads = max(0, _safe_int(live_pr.get("unresolved_thread_count"), 0))
            thread_id = str(pr_entry.get("thread_id") or "").strip() or None
            author_association = str(
                live_pr.get("author_association")
                or live_pr.get("authorAssociation")
                or pr_entry.get("author_association")
                or ""
            ).strip().upper()
            mergeable = normalize_mergeable_state(
                live_pr.get("mergeable"),
                live_pr.get("merge_state_status") or live_pr.get("mergeStateStatus"),
            )
            merge_state_status = str(live_pr.get("merge_state_status") or live_pr.get("mergeStateStatus") or "").strip().upper()
            has_conflicts = mergeable == "CONFLICTING"
            ci_needs_approval = has_action_required_ci(live_pr.get("statusCheckRollup"))
            linear_issues_by_pr_key[pr_key] = linear_issue
            issue_operator_guidance = self._get_linear_issue_operator_guidance(linear_issue)
            issue_has_operator_guidance = bool(issue_operator_guidance)

            if pr_entry.get("linear_issue_id") != linear_id or pr_entry.get("linear_issue_url") != linear_url:
                self.state_store.update_thread_state(
                    pr_key,
                    {
                        "repo": repo,
                        "number": number,
                        "subject_type": "PullRequest",
                        "url": pr_url,
                        "title": title,
                        "linear_issue_id": linear_id,
                        "linear_issue_identifier": linear_identifier,
                        "linear_issue_url": linear_url,
                    },
                    now_override_ms=current_ms,
                )

            if state_name == "in review":
                if not head_sha or pr_entry.get("linear_todo_reviewed_sha") == head_sha:
                    continue
                pr_info = {
                    **pr_entry,
                    **live_pr,
                    "pr_key": pr_key,
                    "repo": repo,
                    "number": number,
                    "url": pr_url,
                    "title": title,
                    "head_sha": head_sha,
                    "ci_state": ci_state,
                    "updated_at": updated_at,
                    "labels": pr_labels,
                    "linear_issue_url": linear_url,
                }
                consensus = self._evaluate_lane_a_consensus(
                    linear_id=linear_id,
                    linear_identifier=linear_identifier,
                    linear_url=linear_url,
                    pr_entry=pr_info,
                    head_sha=head_sha,
                    ci_state=ci_state,
                    unresolved_thread_count=unresolved_threads,
                    slot_id=slot_id,
                    dispatched_targets=dispatched_targets,
                    current_ms=current_ms,
                    now_override_ms=now_override_ms,
                )
                if consensus is not None:
                    processed_pr_keys.add(pr_key)
                    linear_pr_actions.append(consensus)
                    if isinstance(consensus.get("dispatch"), dict):
                        dispatches.append(consensus["dispatch"])
                    if isinstance(consensus.get("needs_decision_notification"), dict):
                        notifications.append(consensus["needs_decision_notification"])
                elif (
                    not is_trusted_github_actor(live_pr.get("author"))
                    and not has_do_not_merge_label(pr_labels)
                    and (ci_state in ("SUCCESS", "NONE") or ci_needs_approval)
                    and (
                        pr_entry.get("handled_head_sha") != head_sha
                        or (
                            bool(pr_entry.get("handled_ci_state"))
                            and normalize_ci_state(pr_entry.get("handled_ci_state")) not in ("SUCCESS", "NONE")
                        )
                        or (ci_needs_approval and pr_entry.get("ci_approved_head_sha") != head_sha)
                    )
                    and compute_community_auto_merge_eligible(
                        repo=repo,
                        additions=live_pr.get("additions"),
                        deletions=live_pr.get("deletions"),
                        changed_files=live_pr.get("changed_files"),
                        file_paths=live_pr.get("file_paths"),
                        files_has_next_page=bool(live_pr.get("files_has_next_page", False)),
                        author_association=author_association,
                        mergeable=mergeable,
                        merge_state_status=merge_state_status,
                        has_operator_guidance=issue_has_operator_guidance,
                        enabled=self.state_store.community_auto_merge_enabled,
                        max_lines=self.state_store.community_auto_merge_max_lines,
                        max_files=self.state_store.community_auto_merge_max_files,
                        excluded_repos=self.state_store.community_auto_merge_excluded_repos,
                    )
                ):
                    try:
                        existing_comments = self.linear_client.list_issue_comments(linear_id)
                    except Exception:
                        continue
                    existing_verdicts = linear_sync.parse_blind_review_verdicts(existing_comments, head_sha=head_sha)
                    own_verdict = self._latest_blind_verdict(
                        existing_verdicts,
                        lambda v: str(v.get("agent") or "").strip().lower() == self.state_store.agent_name
                        or str(v.get("model_family") or "").strip().lower() == own_family,
                    )
                    if own_verdict is None:
                        review_res, action_rec = self._run_own_blind_review_and_post(
                            pr_key=pr_key,
                            repo=repo,
                            number=number,
                            pr_url=pr_url,
                            head_sha=head_sha,
                            ci_state=ci_state,
                            updated_at=updated_at,
                            thread_id=thread_id,
                            linear_id=linear_id,
                            linear_identifier=linear_identifier,
                            linear_url=linear_url,
                            slot_id=slot_id,
                            dispatched_targets=dispatched_targets,
                            current_ms=current_ms,
                            now_override_ms=now_override_ms,
                        )
                        if review_res is not None:
                            processed_pr_keys.add(pr_key)
                            dispatches.append(review_res)
                            if action_rec is not None:
                                linear_pr_actions.append(action_rec)
                            if review_res.get("task_succeeded") and action_rec is not None:
                                post_consensus = self._evaluate_lane_a_consensus(
                                    linear_id=linear_id,
                                    linear_identifier=linear_identifier,
                                    linear_url=linear_url,
                                    pr_entry=pr_info,
                                    head_sha=head_sha,
                                    ci_state=ci_state,
                                    unresolved_thread_count=unresolved_threads,
                                    slot_id=slot_id,
                                    dispatched_targets=dispatched_targets,
                                    current_ms=current_ms,
                                    now_override_ms=now_override_ms,
                                )
                                if post_consensus is not None:
                                    linear_pr_actions.append(post_consensus)
                                    if isinstance(post_consensus.get("dispatch"), dict):
                                        dispatches.append(post_consensus["dispatch"])
                                    if isinstance(post_consensus.get("needs_decision_notification"), dict):
                                        notifications.append(post_consensus["needs_decision_notification"])
                                elif str(action_rec.get("verdict") or "").strip().lower() == "pass":
                                    ci_action = self._maybe_approve_action_required_ci(
                                        pr_key=pr_key,
                                        repo=repo,
                                        number=number,
                                        head_sha=head_sha,
                                        live_pr=live_pr,
                                        pr_entry=pr_entry,
                                        linear_id=linear_id,
                                        linear_identifier=linear_identifier,
                                        linear_url=linear_url,
                                        current_ms=current_ms,
                                        allow_first_time=False,
                                    )
                                    if ci_action is not None:
                                        linear_pr_actions.append(ci_action)
                    elif str(own_verdict.get("verdict") or "").strip().lower() == "pass":
                        ci_action = self._maybe_approve_action_required_ci(
                            pr_key=pr_key,
                            repo=repo,
                            number=number,
                            head_sha=head_sha,
                            live_pr=live_pr,
                            pr_entry=pr_entry,
                            linear_id=linear_id,
                            linear_identifier=linear_identifier,
                            linear_url=linear_url,
                            current_ms=current_ms,
                            allow_first_time=False,
                        )
                        if ci_action is not None:
                            processed_pr_keys.add(pr_key)
                            linear_pr_actions.append(ci_action)
            elif state_name == "todo" or state_type == "unstarted":
                triaged_sha = str(pr_entry.get("triaged_head_sha") or "").strip() or None
                if "ready-to-merge" in lin_labels:
                    sha_changed = not triaged_sha or not head_sha or triaged_sha != head_sha
                    if has_do_not_merge_label(pr_labels) and not sha_changed:
                        dispatched_targets.add(pr_key)
                        processed_pr_keys.add(pr_key)
                        with contextlib.suppress(Exception):
                            self.linear_client.update_issue(
                                linear_id,
                                state="Backlog",
                                add_labels=("needs-decision",),
                                remove_labels=("ready-to-merge",),
                            )
                        ping = self._send_needs_decision_ping(
                            pr_key=pr_key,
                            linear_url=linear_url or "",
                            repo=repo,
                            number=number,
                            title=title,
                            head_sha=head_sha,
                            current_ms=current_ms,
                        )
                        if ping is not None:
                            notifications.append(ping)
                        linear_pr_actions.append({
                            "action": "linear_todo_merge_blocked_do_not_merge",
                            "key": pr_key,
                            "repo": repo,
                            "number": number,
                            "head_sha": head_sha,
                            "head_sha_changed": False,
                            "linear_issue_id": linear_id,
                            "linear_issue_identifier": linear_identifier,
                            "linear_issue_url": linear_url,
                            "needs_decision_notification": ping,
                        })
                        continue
                    if not self.state_store.can_consume_throttle("community_pr_reviews", slot_id=slot_id, now_override_ms=current_ms):
                        continue
                    applied_team_merge = False
                    if not sha_changed and not any(lbl == "team:merge" for lbl in pr_labels):
                        try:
                            self.gh_client.add_pull_request_label(repo, number, "team:merge")
                            applied_team_merge = True
                        except Exception as exc:
                            sys.stderr.write(f"moltis-github-companion linear-todo-merge-label warning ({pr_key} / {linear_id}): {exc}\n")
                            self.state_store.fail_thread_review(
                                pr_key,
                                failure_reason=f"team_merge_label_failed: {exc}",
                                now_override_ms=current_ms,
                            )
                            dispatched_targets.add(pr_key)
                            processed_pr_keys.add(pr_key)
                            linear_pr_actions.append({
                                "action": "linear_todo_merge_label_failed",
                                "key": pr_key,
                                "repo": repo,
                                "number": number,
                                "head_sha": head_sha,
                                "head_sha_changed": False,
                                "linear_issue_id": linear_id,
                                "linear_issue_identifier": linear_identifier,
                                "linear_issue_url": linear_url,
                                "needs_decision_notification": None,
                            })
                            continue
                    consumed, _ = self.state_store.consume_throttle("community_pr_reviews", slot_id=slot_id, now_override_ms=current_ms)
                    if not consumed:
                        if applied_team_merge:
                            with contextlib.suppress(Exception):
                                self.gh_client.remove_pull_request_label(repo, number, "team:merge")
                        continue
                    dispatched_targets.add(pr_key)
                    processed_pr_keys.add(pr_key)
                    merge_res = self.execution_coordinator.execute_dispatch(
                        kind="team:merge",
                        is_automated_pr=False,
                        thread_id=thread_id,
                        state_key=pr_key,
                        repo=repo,
                        number=number,
                        subject_kind="PullRequest",
                        head_sha=head_sha or None,
                        ci_state=ci_state or None,
                        updated_at=updated_at,
                        trigger_reason="linear_todo_merge",
                        team_label="team:merge",
                        triaged_head_sha=triaged_sha,
                        head_sha_changed=sha_changed,
                        linear_issue_id=linear_id,
                        linear_issue_identifier=linear_identifier,
                        linear_issue_url=linear_url,
                        github_url=pr_url,
                        defer_watermark_commit=True,
                        now_override_ms=now_override_ms,
                    )
                    dispatches.append(merge_res)
                    ping = None
                    action = "linear_todo_merge_blocked_sha_changed" if sha_changed else "linear_todo_merge_failed"
                    if merge_res.get("task_succeeded"):
                        with self._deferred_dispatch_guard(merge_res, now_override_ms=now_override_ms):
                            if sha_changed:
                                try:
                                    self.linear_client.update_issue(
                                        linear_id,
                                        state="Backlog",
                                        add_labels=("needs-decision",),
                                        remove_labels=("ready-to-merge",),
                                    )
                                except Exception as exc:
                                    sys.stderr.write(f"moltis-github-companion linear-todo-merge-escalate warning ({pr_key} / {linear_id}): {exc}\n")
                                    self.execution_coordinator.fail_deferred_dispatch(
                                        merge_res,
                                        failure_reason=f"linear_todo_merge_escalate_failed: {exc}",
                                        now_override_ms=now_override_ms,
                                    )
                                    action = "linear_todo_merge_escalate_failed"
                                else:
                                    self.execution_coordinator.commit_deferred_dispatch(merge_res, now_override_ms=now_override_ms)
                                    ping = self._send_needs_decision_ping(
                                        pr_key=pr_key,
                                        linear_url=linear_url or "",
                                        repo=repo,
                                        number=number,
                                        title=title,
                                        head_sha=head_sha,
                                        current_ms=current_ms,
                                    )
                                    if ping is not None:
                                        notifications.append(ping)
                            else:
                                merge_outcome, merge_detail = parse_linear_todo_merge_reply(
                                    str(merge_res.get("reply_text") or ""),
                                    repo=repo,
                                    number=number,
                                    linear_url=linear_url,
                                )
                                if merge_outcome == "merged":
                                    if self.gh_client.is_pull_request_merged(repo, number):
                                        action = "linear_todo_merged"
                                        try:
                                            self.linear_client.update_issue(linear_id, state="Done")
                                        except Exception as exc:
                                            sys.stderr.write(f"moltis-github-companion linear-todo-merge-done warning ({pr_key} / {linear_id}): {exc}\n")
                                        self.execution_coordinator.commit_deferred_dispatch(merge_res, now_override_ms=now_override_ms)
                                    else:
                                        if applied_team_merge:
                                            with contextlib.suppress(Exception):
                                                self.gh_client.remove_pull_request_label(repo, number, "team:merge")
                                        action = "linear_todo_merge_failed"
                                        self.execution_coordinator.fail_deferred_dispatch(
                                            merge_res,
                                            failure_reason="merge_not_confirmed_on_github",
                                            now_override_ms=now_override_ms,
                                        )
                                elif merge_outcome in ("blocked", "needs_decision"):
                                    if applied_team_merge:
                                        with contextlib.suppress(Exception):
                                            self.gh_client.remove_pull_request_label(repo, number, "team:merge")
                                    try:
                                        self.linear_client.update_issue(
                                            linear_id,
                                            state="Backlog",
                                            add_labels=("needs-decision",),
                                            remove_labels=("ready-to-merge",),
                                        )
                                    except Exception as exc:
                                        sys.stderr.write(f"moltis-github-companion linear-todo-merge-escalate warning ({pr_key} / {linear_id}): {exc}\n")
                                        self.execution_coordinator.fail_deferred_dispatch(
                                            merge_res,
                                            failure_reason=f"linear_todo_merge_escalate_failed: {exc}",
                                            now_override_ms=now_override_ms,
                                        )
                                        action = "linear_todo_merge_escalate_failed"
                                    else:
                                        action = "linear_todo_merge_blocked" if merge_outcome == "blocked" else "linear_todo_merge_needs_decision"
                                        self.execution_coordinator.commit_deferred_dispatch(merge_res, now_override_ms=now_override_ms)
                                        if merge_outcome == "needs_decision" and merge_res.get("telegram_forwarded"):
                                            clean_linear_url = str(linear_url or pr_entry.get("linear_issue_url") or "").strip()
                                            self.state_store.update_thread_state(
                                                pr_key,
                                                {
                                                    "repo": repo,
                                                    "number": number,
                                                    "title": title,
                                                    **({"linear_issue_url": clean_linear_url} if clean_linear_url else {}),
                                                    "decision_notified_sha": head_sha,
                                                },
                                                now_override_ms=current_ms,
                                            )
                                            ping = {
                                                "key": pr_key,
                                                "repo": repo,
                                                "number": number,
                                                "head_sha": head_sha,
                                                "linear_url": clean_linear_url,
                                                "title": title,
                                                "message": merge_detail,
                                                "sent": True,
                                                "error": None,
                                            }
                                            notifications.append(ping)
                                        else:
                                            ping = self._send_needs_decision_ping(
                                                pr_key=pr_key,
                                                linear_url=linear_url or "",
                                                repo=repo,
                                                number=number,
                                                title=title,
                                                head_sha=head_sha,
                                                current_ms=current_ms,
                                            )
                                            if ping is not None:
                                                notifications.append(ping)
                                else:
                                    if applied_team_merge:
                                        with contextlib.suppress(Exception):
                                            self.gh_client.remove_pull_request_label(repo, number, "team:merge")
                                    self.execution_coordinator.commit_deferred_dispatch(merge_res, now_override_ms=now_override_ms)
                    elif applied_team_merge:
                        with contextlib.suppress(Exception):
                            self.gh_client.remove_pull_request_label(repo, number, "team:merge")
                    linear_pr_actions.append({
                        "action": action,
                        "key": pr_key,
                        "repo": repo,
                        "number": number,
                        "head_sha": head_sha,
                        "head_sha_changed": sha_changed,
                        "linear_issue_id": linear_id,
                        "linear_issue_identifier": linear_identifier,
                        "linear_issue_url": linear_url,
                        "needs_decision_notification": ping,
                    })
                else:
                    if not self.state_store.can_consume_throttle("community_pr_reviews", slot_id=slot_id, now_override_ms=current_ms):
                        continue
                    consumed, _ = self.state_store.consume_throttle("community_pr_reviews", slot_id=slot_id, now_override_ms=current_ms)
                    if not consumed:
                        continue
                    dispatched_targets.add(pr_key)
                    processed_pr_keys.add(pr_key)
                    review_res = self.execution_coordinator.execute_dispatch(
                        kind="team:review",
                        is_automated_pr=False,
                        thread_id=thread_id,
                        state_key=pr_key,
                        repo=repo,
                        number=number,
                        subject_kind="PullRequest",
                        head_sha=head_sha or None,
                        ci_state=ci_state or None,
                        updated_at=updated_at,
                        trigger_reason="linear_todo_review",
                        team_label="team:review",
                        triaged_head_sha=triaged_sha,
                        linear_issue_id=linear_id,
                        linear_issue_identifier=linear_identifier,
                        linear_issue_url=linear_url,
                        github_url=pr_url,
                        defer_watermark_commit=True,
                        now_override_ms=now_override_ms,
                    )
                    dispatches.append(review_res)
                    review_action = "linear_todo_review_failed"
                    if review_res.get("task_succeeded"):
                        with self._deferred_dispatch_guard(review_res, now_override_ms=now_override_ms):
                            try:
                                self.linear_client.update_issue(linear_id, state="In Review")
                            except Exception as exc:
                                sys.stderr.write(f"moltis-github-companion linear-todo-review-update warning ({pr_key} / {linear_id}): {exc}\n")
                                self.execution_coordinator.fail_deferred_dispatch(
                                    review_res,
                                    failure_reason=f"linear_todo_review_update_failed: {exc}",
                                    now_override_ms=now_override_ms,
                                )
                            else:
                                self.execution_coordinator.commit_deferred_dispatch(review_res, now_override_ms=now_override_ms)
                                if head_sha:
                                    self.state_store.update_thread_state(
                                        pr_key,
                                        {"linear_todo_reviewed_sha": head_sha},
                                        now_override_ms=current_ms,
                                    )
                                    ci_action = self._maybe_approve_action_required_ci(
                                        pr_key=pr_key,
                                        repo=repo,
                                        number=number,
                                        head_sha=head_sha,
                                        live_pr=live_pr,
                                        pr_entry=pr_entry,
                                        linear_id=linear_id,
                                        linear_identifier=linear_identifier,
                                        linear_url=linear_url,
                                        current_ms=current_ms,
                                        allow_first_time=True,
                                    )
                                    if ci_action is not None:
                                        linear_pr_actions.append(ci_action)
                                review_action = "linear_todo_reviewed"
                    linear_pr_actions.append({
                        "action": review_action,
                        "key": pr_key,
                        "repo": repo,
                        "number": number,
                        "head_sha": head_sha,
                        "linear_issue_id": linear_id,
                        "linear_issue_identifier": linear_identifier,
                        "linear_issue_url": linear_url,
                    })
            elif state_name == "backlog" or state_type == "backlog":
                if (
                    str(live_pr.get("state") or "OPEN").upper() != "OPEN"
                    or is_trusted_github_actor(live_pr.get("author"))
                    or not head_sha
                    or bool(pr_entry.get("in_flight"))
                ):
                    continue
                is_draft = bool(live_pr.get("is_draft"))
                handled_sha = str(pr_entry.get("handled_head_sha") or "").strip()
                triaged_sha = str(pr_entry.get("triaged_head_sha") or "").strip()
                handled_ci = normalize_ci_state(pr_entry.get("handled_ci_state")) if pr_entry.get("handled_ci_state") else ""
                sha_unchanged = handled_sha == head_sha and (not triaged_sha or triaged_sha == head_sha)

                def _strip_stale_ready_to_merge(
                    _linear_id: str = linear_id,
                    _pr_key: str = pr_key,
                    _lin_labels: set[str] = lin_labels,
                ) -> None:
                    if "ready-to-merge" not in _lin_labels or self.linear_client is None:
                        return
                    try:
                        self.linear_client.update_issue(_linear_id, remove_labels=("ready-to-merge",))
                    except Exception as exc:
                        sys.stderr.write(
                            f"moltis-github-companion backlog-stale-label warning ({_pr_key} / {_linear_id}): {exc}\n"
                        )
                    else:
                        _lin_labels.discard("ready-to-merge")

                has_dnm = has_do_not_merge_label(pr_labels)
                backlog_blockers: list[str] = []
                if is_draft:
                    backlog_blockers.append("draft")
                if has_dnm:
                    backlog_blockers.append("do_not_merge")
                if has_conflicts:
                    backlog_blockers.append("merge_conflicts")
                if ci_state not in ("SUCCESS", "NONE"):
                    backlog_blockers.append(f"ci_{ci_state.lower()}")
                if unresolved_threads > 0:
                    backlog_blockers.append("unresolved_threads")

                if (is_draft or sha_unchanged) and "ready-to-merge" in lin_labels and backlog_blockers:
                    try:
                        self.linear_client.update_issue(
                            linear_id,
                            state="Backlog",
                            add_labels=("needs-decision",),
                            remove_labels=("ready-to-merge",),
                        )
                    except Exception as exc:
                        sys.stderr.write(
                            f"moltis-github-companion backlog-blocker-update warning ({pr_key} / {linear_id}): {exc}\n"
                        )
                        continue
                    self.state_store.update_thread_state(
                        pr_key,
                        {"handled_ci_state": ci_state},
                        now_override_ms=current_ms,
                    )
                    ping = self._send_needs_decision_ping(
                        pr_key=pr_key,
                        linear_url=linear_url or "",
                        repo=repo,
                        number=number,
                        title=title,
                        head_sha=head_sha,
                        current_ms=current_ms,
                    )
                    if ping is not None:
                        notifications.append(ping)
                    dispatched_targets.add(pr_key)
                    processed_pr_keys.add(pr_key)
                    linear_pr_actions.append({
                        "action": "backlog_ready_to_merge_blocked",
                        "key": pr_key,
                        "repo": repo,
                        "number": number,
                        "head_sha": head_sha,
                        "blockers": backlog_blockers,
                        "linear_issue_id": linear_id,
                        "linear_issue_identifier": linear_identifier,
                        "linear_issue_url": linear_url,
                        "needs_decision_notification": ping,
                    })
                    continue

                if is_draft:
                    continue
                additions = live_pr.get("additions")
                deletions = live_pr.get("deletions")
                changed_files = live_pr.get("changed_files")
                file_paths = live_pr.get("file_paths")
                files_has_next_page = bool(live_pr.get("files_has_next_page", False))
                auto_merge_eligible = compute_community_auto_merge_eligible(
                    repo=repo,
                    additions=additions,
                    deletions=deletions,
                    changed_files=changed_files,
                    file_paths=file_paths,
                    files_has_next_page=files_has_next_page,
                    author_association=author_association,
                    mergeable=mergeable,
                    merge_state_status=merge_state_status,
                    has_operator_guidance=issue_has_operator_guidance,
                    enabled=self.state_store.community_auto_merge_enabled,
                    max_lines=self.state_store.community_auto_merge_max_lines,
                    max_files=self.state_store.community_auto_merge_max_files,
                    excluded_repos=self.state_store.community_auto_merge_excluded_repos,
                )
                is_lane_a = bool(auto_merge_eligible) and (ci_state in ("SUCCESS", "NONE") or ci_needs_approval) and not has_dnm and not has_conflicts
                ci_turned_green_for_lane_a = (
                    sha_unchanged
                    and is_lane_a
                    and bool(handled_ci)
                    and handled_ci not in ("SUCCESS", "NONE")
                )
                if sha_unchanged and not ci_turned_green_for_lane_a:
                    continue

                if not sha_unchanged:
                    _strip_stale_ready_to_merge()

                if not ci_turned_green_for_lane_a and _safe_int(pr_entry.get("followup_cooldown_until_ms"), 0) > current_ms:
                    continue
                if auto_merge_eligible and not has_dnm and ci_state == "PENDING":
                    continue

                if is_lane_a:
                    if ci_turned_green_for_lane_a:
                        try:
                            backlog_comments = self.linear_client.list_issue_comments(linear_id)
                        except Exception as exc:
                            sys.stderr.write(
                                f"moltis-github-companion backlog-lane-a-comments warning ({pr_key} / {linear_id}): {exc}\n"
                            )
                            continue
                        backlog_verdicts = linear_sync.parse_blind_review_verdicts(backlog_comments, head_sha=head_sha)
                        if any(str(v.get("verdict") or "").strip().lower() != "pass" for v in backlog_verdicts):
                            self.state_store.update_thread_state(
                                pr_key,
                                {"handled_ci_state": ci_state},
                                now_override_ms=current_ms,
                            )
                            continue
                    try:
                        self.linear_client.update_issue(
                            linear_id,
                            state="In Review",
                            remove_labels=("needs-decision", "ready-to-merge"),
                        )
                    except Exception as exc:
                        sys.stderr.write(
                            f"moltis-github-companion backlog-lane-a-update warning ({pr_key} / {linear_id}): {exc}\n"
                        )
                        continue
                    self._run_lane_a_pr_evaluation(
                        pr_key=pr_key,
                        repo=repo,
                        number=number,
                        pr_url=pr_url,
                        title=title,
                        head_sha=head_sha,
                        ci_state=ci_state,
                        updated_at=updated_at,
                        pr_labels=pr_labels,
                        unresolved_threads=unresolved_threads,
                        thread_id=thread_id,
                        pr_entry=pr_entry,
                        live_pr=live_pr,
                        linear_id=linear_id,
                        linear_identifier=linear_identifier,
                        linear_url=linear_url,
                        own_family=own_family,
                        slot_id=slot_id,
                        dispatched_targets=dispatched_targets,
                        processed_pr_keys=processed_pr_keys,
                        dispatches=dispatches,
                        linear_pr_actions=linear_pr_actions,
                        notifications=notifications,
                        current_ms=current_ms,
                        now_override_ms=now_override_ms,
                    )
                else:
                    raw_lin_est = linear_issue.get("estimate")
                    linear_estimate = (
                        raw_lin_est
                        if isinstance(raw_lin_est, int) and not isinstance(raw_lin_est, bool) and raw_lin_est > 0
                        else None
                    )
                    lane_b_outcome = self._run_lane_b_pr_review(
                        pr_key=pr_key,
                        repo=repo,
                        number=number,
                        pr_url=pr_url,
                        title=title,
                        head_sha=head_sha,
                        ci_state=ci_state,
                        updated_at=updated_at,
                        additions=additions,
                        deletions=deletions,
                        changed_files=changed_files,
                        file_paths=file_paths,
                        files_has_next_page=files_has_next_page,
                        author_association=author_association,
                        mergeable=mergeable,
                        merge_state_status=merge_state_status,
                        auto_merge_eligible=bool(auto_merge_eligible),
                        thread_id=thread_id,
                        linear_id=linear_id,
                        linear_identifier=linear_identifier,
                        linear_url=linear_url,
                        linear_estimate=linear_estimate,
                        operator_guidance=issue_operator_guidance,
                        slot_id=slot_id,
                        dispatched_targets=dispatched_targets,
                        processed_pr_keys=processed_pr_keys,
                        dispatches=dispatches,
                        linear_pr_actions=linear_pr_actions,
                        notifications=notifications,
                        current_ms=current_ms,
                        now_override_ms=now_override_ms,
                    )
                    if lane_b_outcome in ("throttled", "dispatch_failed", "update_failed"):
                        _strip_stale_ready_to_merge()

        return {
            "dispatches": dispatches,
            "linear_pr_actions": linear_pr_actions,
            "needs_decision_notifications": notifications,
            "linear_issues_by_pr_key": linear_issues_by_pr_key,
        }

    def _run_traya_blind_pr_reviews(
        self,
        *,
        open_prs_by_key: dict[str, dict],
        slot_id: str,
        dispatched_targets: set[str],
        current_ms: int,
        now_override_ms: int | None,
    ) -> list[dict]:
        if self.state_store.agent_name != "traya" or self.linear_client is None:
            return []
        eligible_open_prs: dict[str, dict] = {}
        for pr_key, live_pr in (open_prs_by_key or {}).items():
            if not isinstance(live_pr, dict):
                continue
            if live_pr.get("is_draft") or str(live_pr.get("state") or "OPEN").upper() != "OPEN":
                continue
            if is_trusted_github_actor(live_pr.get("author")):
                continue
            if has_do_not_merge_label(live_pr.get("labels")):
                continue
            ci_state = normalize_ci_state(live_pr.get("ci_state") or live_pr.get("statusCheckRollup"))
            if ci_state not in ("SUCCESS", "NONE") and not has_action_required_ci(live_pr.get("statusCheckRollup")):
                continue
            repo = str(live_pr.get("repo") or "").strip()
            number = _safe_int(live_pr.get("number"), 0)
            if not repo or number <= 0 or not is_allowed_notification_repo(repo):
                continue
            raw_text = "\n".join(t for t in (str(live_pr.get("title") or ""), str(live_pr.get("body") or "")) if t)
            if detect_coercion_patterns(raw_text) or extract_mentioned_github_agents(raw_text):
                continue
            entry = _as_dict(self.state_store.get_thread_state(pr_key))
            if bool(entry.get("coercion_blocked")) or _safe_int(entry.get("retry_count"), 0) >= MAX_THREAD_FAILURE_RETRIES:
                continue
            if not compute_community_auto_merge_eligible(
                repo=repo,
                additions=live_pr.get("additions"),
                deletions=live_pr.get("deletions"),
                changed_files=live_pr.get("changed_files"),
                file_paths=live_pr.get("file_paths"),
                files_has_next_page=bool(live_pr.get("files_has_next_page", False)),
                author_association=live_pr.get("author_association") or live_pr.get("authorAssociation"),
                mergeable=live_pr.get("mergeable"),
                merge_state_status=live_pr.get("merge_state_status") or live_pr.get("mergeStateStatus"),
                enabled=self.state_store.community_auto_merge_enabled,
                max_lines=self.state_store.community_auto_merge_max_lines,
                max_files=self.state_store.community_auto_merge_max_files,
                excluded_repos=self.state_store.community_auto_merge_excluded_repos,
            ):
                continue
            eligible_open_prs[pr_key] = live_pr

        if not eligible_open_prs:
            return []

        try:
            in_review_issues = self.linear_client.list_project_issues_by_state(("In Review",))
        except Exception as exc:
            sys.stderr.write(f"moltis-github-companion traya-linear-poll warning: {exc}\n")
            return []

        results: list[dict] = []
        for linear_issue in in_review_issues or ():
            if not isinstance(linear_issue, dict) or is_ignored_linear_issue_state(linear_issue):
                continue
            linear_id = str(linear_issue.get("id") or "").strip()
            if not linear_id:
                continue
            lin_labels = extract_linear_issue_labels(linear_issue)
            if "pr" not in lin_labels or "needs-decision" in lin_labels:
                continue
            target = extract_linear_github_target(linear_issue, expected_kind="PR")
            if target is None:
                continue
            repo, _, number, github_url = target
            if not is_allowed_notification_repo(repo):
                continue
            pr_key = make_pr_key(repo, number)
            if pr_key in dispatched_targets or pr_key not in eligible_open_prs:
                continue
            live_pr = eligible_open_prs[pr_key]
            head_sha = str(live_pr.get("head_sha") or live_pr.get("headRefOid") or "").strip()
            if not head_sha:
                continue
            try:
                comments = self.linear_client.list_issue_comments(linear_id)
            except Exception as exc:
                sys.stderr.write(f"moltis-github-companion traya-blind-comments warning ({pr_key} / {linear_id}): {exc}\n")
                continue
            existing_verdicts = linear_sync.parse_blind_review_verdicts(comments, head_sha=head_sha)
            has_traya_verdict = any(
                str(v.get("agent") or "").strip().lower() == "traya"
                or str(v.get("model_family") or "").strip().lower() == "gpt"
                for v in existing_verdicts
            )
            if has_traya_verdict:
                continue
            if not self.state_store.can_consume_throttle("community_pr_reviews", slot_id=slot_id, now_override_ms=current_ms):
                break
            consumed, _ = self.state_store.consume_throttle("community_pr_reviews", slot_id=slot_id, now_override_ms=current_ms)
            if not consumed:
                break

            pr_url = str(live_pr.get("url") or github_url or f"https://github.com/{repo}/pull/{number}").strip()
            ci_state = normalize_ci_state(live_pr.get("ci_state") or live_pr.get("statusCheckRollup"))
            updated_at = str(live_pr.get("updated_at") or live_pr.get("updatedAt") or "").strip() or None
            linear_identifier = str(linear_issue.get("identifier") or "").strip() or None
            linear_url = str(linear_issue.get("url") or "").strip() or None

            dispatched_targets.add(pr_key)
            review_res = self.execution_coordinator.execute_dispatch(
                kind="community_pr_blind_review",
                is_automated_pr=False,
                state_key=pr_key,
                repo=repo,
                number=number,
                subject_kind="PullRequest",
                head_sha=head_sha,
                ci_state=ci_state,
                updated_at=updated_at,
                trigger_reason="community_pr_blind_review",
                community_auto_merge_eligible=True,
                linear_issue_id=linear_id,
                linear_issue_identifier=linear_identifier,
                linear_issue_url=linear_url,
                github_url=pr_url,
                defer_watermark_commit=True,
                now_override_ms=now_override_ms,
            )
            if not review_res.get("task_succeeded"):
                results.append({
                    "key": pr_key,
                    "repo": repo,
                    "number": number,
                    "head_sha": head_sha,
                    "agent": "traya",
                    "model_family": MODEL_FAMILY_BY_AGENT["traya"],
                    "verdict": None,
                    "posted": False,
                    "linear_issue_id": linear_id,
                    "linear_issue_identifier": linear_identifier,
                    "linear_issue_url": linear_url,
                    "dispatch": review_res,
                })
                continue
            with self._deferred_dispatch_guard(review_res, now_override_ms=now_override_ms):
                verdict, findings, polish = parse_blind_review_reply(str(review_res.get("reply_text") or ""))
                summary_parts: list[str] = []
                if findings:
                    summary_parts.append(f"FINDINGS: {findings}")
                if polish:
                    summary_parts.append(f"POLISH: {polish}")
                verdict_summary = "\n".join(summary_parts)
                posted = False
                try:
                    self.linear_client.post_blind_review_verdict(
                        linear_id,
                        agent="traya",
                        model_family=MODEL_FAMILY_BY_AGENT["traya"],
                        head_sha=head_sha,
                        verdict=verdict,
                        summary=verdict_summary,
                    )
                    posted = True
                except Exception as exc:
                    sys.stderr.write(f"moltis-github-companion traya-verdict-post warning ({pr_key} / {linear_id}): {exc}\n")
                    self.execution_coordinator.fail_deferred_dispatch(
                        review_res,
                        failure_reason=f"linear_blind_verdict_post_failed: {exc}",
                        now_override_ms=now_override_ms,
                    )
                else:
                    self.execution_coordinator.commit_deferred_dispatch(review_res, now_override_ms=now_override_ms)
            results.append({
                "key": pr_key,
                "repo": repo,
                "number": number,
                "head_sha": head_sha,
                "agent": "traya",
                "model_family": MODEL_FAMILY_BY_AGENT["traya"],
                "verdict": verdict,
                "findings": findings,
                "polish": polish,
                "posted": posted,
                "linear_issue_id": linear_id,
                "linear_issue_identifier": linear_identifier,
                "linear_issue_url": linear_url,
                "dispatch": review_res,
            })
        return results

    def _reconcile_community_pr_merge_conflicts(
        self,
        *,
        open_prs_by_key: dict[str, dict],
        active_linear_issues: Iterable[dict],
        known_linear_issues_by_pr_key: dict[str, dict] | None,
        poll_result: dict,
        current_ms: int,
        linear_breaker: _LinearWriteCircuitBreaker | None = None,
    ) -> list[dict]:
        if (
            self.linear_client is None
            or self.state_store.agent_name not in SWEEP_AGENT_ORDER
            or poll_result.get("open_prs_poll_error") is not None
            or poll_result.get("status") in (403, 429)
        ):
            return []
        breaker = linear_breaker if linear_breaker is not None else _LinearWriteCircuitBreaker()
        linear_by_pr_key: dict[str, dict] = {}
        for issue in active_linear_issues or ():
            if not isinstance(issue, dict):
                continue
            labels = extract_linear_issue_labels(issue)
            if "pr" not in labels:
                continue
            target = extract_linear_github_target(issue, expected_kind="PR")
            if target is None:
                continue
            t_repo, _, t_num, _ = target
            linear_by_pr_key[make_pr_key(t_repo, t_num)] = issue
        for pk, issue in (known_linear_issues_by_pr_key or {}).items():
            if isinstance(issue, dict):
                linear_by_pr_key[pk] = issue

        def _resolve_existing_linear_pr(pr_key: str, pr_url: str, pr_entry: dict) -> dict | None:
            if pr_key in linear_by_pr_key:
                cand = linear_by_pr_key[pr_key]
            else:
                cand = None
                stored_id = str(pr_entry.get("linear_issue_id") or "").strip()
                if stored_id:
                    try:
                        cand = self.linear_client.get_issue(stored_id)
                    except Exception:
                        cand = None
                if cand is None:
                    try:
                        cand = self.linear_client.find_issue_by_github_url(pr_url, item_kind="PR")
                    except Exception:
                        cand = None
                if isinstance(cand, dict):
                    linear_by_pr_key[pr_key] = cand
            if not isinstance(cand, dict):
                return None
            c_labels = extract_linear_issue_labels(cand)
            if "issue" in c_labels and "pr" not in c_labels:
                return None
            return cand

        def _post_linear_comment_safe(linear_id: str, body: str, pr_key: str) -> bool:
            if not linear_id or not hasattr(self.linear_client, "post_comment"):
                return False
            if breaker.skip_if_tripped(scope="linear-conflict-comment"):
                return False
            try:
                self.linear_client.post_comment(linear_id, body)
            except Exception as exc:
                breaker.record_error(exc, scope="linear-conflict-comment", item_key=pr_key)
                sys.stderr.write(f"moltis-github-companion linear-conflict-comment warning ({pr_key} / {linear_id}): {exc}\n")
                return False
            breaker.record_success()
            return True

        def _update_linear_safe(
            linear_id: str,
            *,
            pr_key: str,
            state: str | None = None,
            add_labels: tuple[str, ...] = (),
            remove_labels: tuple[str, ...] = (),
        ) -> dict | None:
            if not linear_id or breaker.skip_if_tripped(scope="linear-conflict-update"):
                return None
            try:
                updated = self.linear_client.update_issue(
                    linear_id,
                    state=state,
                    add_labels=add_labels,
                    remove_labels=remove_labels,
                )
            except Exception as exc:
                breaker.record_error(exc, scope="linear-conflict-update", item_key=pr_key)
                sys.stderr.write(f"moltis-github-companion linear-conflict-update warning ({pr_key} / {linear_id}): {exc}\n")
                return None
            breaker.record_success()
            if isinstance(updated, dict):
                linear_by_pr_key[pr_key] = updated
            return updated

        actions: list[dict] = []
        closures_this_poll = 0

        for pr_key, live_pr in sorted((open_prs_by_key or {}).items()):
            if not isinstance(live_pr, dict):
                continue
            if str(live_pr.get("state") or "OPEN").upper() != "OPEN":
                continue
            repo = str(live_pr.get("repo") or "").strip()
            number = _safe_int(live_pr.get("number"), 0)
            if not repo or number <= 0 or not is_allowed_notification_repo(repo):
                continue
            if compute_pr_owner(repo, number) != self.state_store.agent_name:
                continue
            author = str(live_pr.get("author") or "").strip()
            author_norm = normalize_github_actor(author)
            if is_trusted_github_actor(author_norm):
                continue
            pr_labels = extract_label_names(live_pr.get("labels"))
            if has_do_not_merge_label(pr_labels):
                continue
            if is_automated_update_pr(
                author_norm,
                repo=repo,
                head_ref=str(live_pr.get("head_ref") or ""),
                labels=pr_labels,
                title=str(live_pr.get("title") or ""),
            ):
                continue
            mergeable_state = normalize_mergeable_state(
                live_pr.get("mergeable"),
                live_pr.get("merge_state_status") or live_pr.get("mergeStateStatus"),
            )
            if mergeable_state == "UNKNOWN":
                continue
            pr_entry = _as_dict(self.state_store.get_thread_state(pr_key))
            if bool(pr_entry.get("coercion_blocked")):
                continue
            pr_url = str(live_pr.get("url") or pr_entry.get("url") or "").strip() or f"https://github.com/{repo}/pull/{number}"
            head_sha = str(live_pr.get("head_sha") or live_pr.get("headRefOid") or pr_entry.get("head_sha") or "").strip()
            is_draft = bool(live_pr.get("is_draft"))

            # Branch A: 90-day idle conflicting draft PRs.
            if is_draft:
                if mergeable_state != "CONFLICTING":
                    continue
                _, updated_at_ms = normalize_ts(live_pr.get("updated_at") or live_pr.get("updatedAt"))
                if updated_at_ms <= 0 or (current_ms - updated_at_ms) < DRAFT_CONFLICT_CLOSE_AFTER_MS:
                    continue
                if closures_this_poll >= MAX_CONFLICT_CLOSURES_PER_POLL:
                    continue
                existing_linear = _resolve_existing_linear_pr(pr_key, pr_url, pr_entry)
                if existing_linear is not None and is_ignored_linear_issue_state(existing_linear):
                    continue
                try:
                    self.gh_client.close_pull_request(
                        repo,
                        number,
                        format_draft_merge_conflict_close_github_comment(author),
                    )
                except Exception as exc:
                    sys.stderr.write(f"moltis-github-companion draft-conflict-close warning ({pr_key}): {exc}\n")
                    continue
                closures_this_poll += 1
                lin_id = str(_as_dict(existing_linear).get("id") or "").strip() or None
                lin_ident = str(_as_dict(existing_linear).get("identifier") or "").strip() or None
                lin_url = str(_as_dict(existing_linear).get("url") or "").strip() or None
                if lin_id:
                    _post_linear_comment_safe(
                        lin_id,
                        format_linear_conflict_closed_comment(pr_url=pr_url, is_draft=True),
                        pr_key,
                    )
                    _update_linear_safe(
                        lin_id,
                        pr_key=pr_key,
                        state="Canceled",
                        add_labels=("merge-conflicts", "stale-closed"),
                        remove_labels=("ready-to-merge", "needs-decision"),
                    )
                self.state_store.update_thread_state(
                    pr_key,
                    {
                        "repo": repo,
                        "number": number,
                        "subject_type": "PullRequest",
                        "url": pr_url,
                        "conflict_closed_at_ms": current_ms,
                        "conflict_closed_reason": "draft_90d_conflicts",
                    },
                    now_override_ms=current_ms,
                )
                actions.append({
                    "action": "draft_conflict_closed",
                    "key": pr_key,
                    "repo": repo,
                    "number": number,
                    "author": author,
                    "head_sha": head_sha,
                    "linear_issue_id": lin_id,
                    "linear_issue_identifier": lin_ident,
                    "linear_issue_url": lin_url,
                })
                continue

            # Non-draft community PRs: resolve existing Linear item and skip ignored states.
            linear_issue = _resolve_existing_linear_pr(pr_key, pr_url, pr_entry)
            if linear_issue is not None and is_ignored_linear_issue_state(linear_issue):
                continue
            lin_id = str(_as_dict(linear_issue).get("id") or "").strip() or None
            lin_ident = str(_as_dict(linear_issue).get("identifier") or "").strip() or None
            lin_url = str(_as_dict(linear_issue).get("url") or "").strip() or None
            lin_labels = extract_linear_issue_labels(linear_issue) if linear_issue is not None else set()
            lin_state_name = str(_as_dict(_as_dict(linear_issue).get("state")).get("name") or "").strip().lower()

            # Branch B: Conflicts resolved on a non-draft PR.
            if mergeable_state == "MERGEABLE":
                had_conflict_tracking = bool(pr_entry.get("conflict_notified_head_sha")) or ("merge-conflicts" in lin_labels)
                if not had_conflict_tracking:
                    continue
                if lin_id and "merge-conflicts" in lin_labels:
                    _update_linear_safe(
                        lin_id,
                        pr_key=pr_key,
                        remove_labels=("merge-conflicts",),
                    )
                    _post_linear_comment_safe(
                        lin_id,
                        format_linear_conflict_resolved_comment(pr_url=pr_url, head_sha=head_sha),
                        pr_key,
                    )
                self.state_store.update_thread_state(
                    pr_key,
                    {
                        "conflict_notified_head_sha": None,
                        "conflict_notified_at_ms": None,
                    },
                    now_override_ms=current_ms,
                )
                actions.append({
                    "action": "merge_conflicts_resolved",
                    "key": pr_key,
                    "repo": repo,
                    "number": number,
                    "author": author,
                    "head_sha": head_sha,
                    "linear_issue_id": lin_id,
                    "linear_issue_identifier": lin_ident,
                    "linear_issue_url": lin_url,
                })
                continue

            # Branch C: Non-draft PR has merge conflicts.
            if lin_id and (
                "merge-conflicts" not in lin_labels
                or "ready-to-merge" in lin_labels
                or lin_state_name == "in review"
            ):
                _update_linear_safe(
                    lin_id,
                    pr_key=pr_key,
                    state="Backlog" if lin_state_name == "in review" else None,
                    add_labels=("merge-conflicts",) if "merge-conflicts" not in lin_labels else (),
                    remove_labels=("ready-to-merge",) if "ready-to-merge" in lin_labels else (),
                )

            notified_sha = str(pr_entry.get("conflict_notified_head_sha") or "").strip()
            notified_at_ms = _safe_int(pr_entry.get("conflict_notified_at_ms"), 0)

            if not head_sha:
                continue

            if notified_sha != head_sha or notified_at_ms <= 0:
                recovered_ms = 0
                if not notified_sha:
                    try:
                        prior_comments = self.gh_client.fetch_issue_comments(repo, number)
                    except Exception as exc:
                        sys.stderr.write(f"moltis-github-companion conflict-comments-check warning ({pr_key}): {exc}\n")
                        continue
                    for cm in prior_comments or ():
                        if not isinstance(cm, dict):
                            continue
                        cm_actor = normalize_github_actor(cm.get("user") or cm.get("author"))
                        cm_body = str(cm.get("body") or "")
                        if is_trusted_github_actor(cm_actor) and CONFLICT_NOTICE_MARKER_PHRASE in cm_body:
                            _, cm_ms = normalize_ts(cm.get("created_at") or cm.get("createdAt"))
                            if cm_ms > recovered_ms:
                                recovered_ms = cm_ms
                if recovered_ms > 0:
                    self.state_store.update_thread_state(
                        pr_key,
                        {
                            "conflict_notified_head_sha": head_sha,
                            "conflict_notified_at_ms": recovered_ms,
                        },
                        now_override_ms=current_ms,
                    )
                    notified_sha = head_sha
                    notified_at_ms = recovered_ms
                else:
                    try:
                        self.gh_client.post_pull_request_comment(
                            repo,
                            number,
                            format_pr_merge_conflict_github_comment(author),
                        )
                    except Exception as exc:
                        sys.stderr.write(f"moltis-github-companion conflict-notify warning ({pr_key}): {exc}\n")
                        continue
                    notified_at_ms = current_ms
                    self.state_store.update_thread_state(
                        pr_key,
                        {
                            "conflict_notified_head_sha": head_sha,
                            "conflict_notified_at_ms": notified_at_ms,
                        },
                        now_override_ms=current_ms,
                    )
                    if lin_id:
                        _post_linear_comment_safe(
                            lin_id,
                            format_linear_conflict_notice_comment(author=author, pr_url=pr_url, head_sha=head_sha),
                            pr_key,
                        )
                    actions.append({
                        "action": "merge_conflict_notified",
                        "key": pr_key,
                        "repo": repo,
                        "number": number,
                        "author": author,
                        "head_sha": head_sha,
                        "linear_issue_id": lin_id,
                        "linear_issue_identifier": lin_ident,
                        "linear_issue_url": lin_url,
                    })
                    continue

            # Already notified on this head_sha: check whether 30 days elapsed with no author activity.
            if (current_ms - notified_at_ms) < CONFLICT_CLOSE_AFTER_MS:
                continue
            if closures_this_poll >= MAX_CONFLICT_CLOSURES_PER_POLL:
                continue
            try:
                pr_comments = self.gh_client.fetch_issue_comments(repo, number)
            except Exception as exc:
                sys.stderr.write(f"moltis-github-companion conflict-close-comments warning ({pr_key}): {exc}\n")
                continue
            latest_activity_ms = 0
            for cm in pr_comments or ():
                if not isinstance(cm, dict):
                    continue
                cm_actor = normalize_github_actor(cm.get("user") or cm.get("author"))
                if cm_actor == author_norm or cm_actor in TRUSTED_HUMAN_ACTORS:
                    _, cm_ms = normalize_ts(cm.get("created_at") or cm.get("createdAt"))
                    if cm_ms > latest_activity_ms:
                        latest_activity_ms = cm_ms
            if latest_activity_ms > notified_at_ms:
                self.state_store.update_thread_state(
                    pr_key,
                    {"conflict_notified_at_ms": latest_activity_ms},
                    now_override_ms=current_ms,
                )
                continue
            try:
                self.gh_client.close_pull_request(
                    repo,
                    number,
                    format_pr_merge_conflict_close_github_comment(author),
                )
            except Exception as exc:
                sys.stderr.write(f"moltis-github-companion conflict-close warning ({pr_key}): {exc}\n")
                continue
            closures_this_poll += 1
            if lin_id:
                _post_linear_comment_safe(
                    lin_id,
                    format_linear_conflict_closed_comment(pr_url=pr_url, is_draft=False),
                    pr_key,
                )
                _update_linear_safe(
                    lin_id,
                    pr_key=pr_key,
                    state="Canceled",
                    add_labels=("merge-conflicts", "stale-closed"),
                    remove_labels=("ready-to-merge", "needs-decision"),
                )
            self.state_store.update_thread_state(
                pr_key,
                {
                    "conflict_closed_at_ms": current_ms,
                    "conflict_closed_reason": "pr_30d_conflicts",
                },
                now_override_ms=current_ms,
            )
            actions.append({
                "action": "merge_conflict_closed",
                "key": pr_key,
                "repo": repo,
                "number": number,
                "author": author,
                "head_sha": head_sha,
                "linear_issue_id": lin_id,
                "linear_issue_identifier": lin_ident,
                "linear_issue_url": lin_url,
            })

        return actions

    def _reconcile_in_review_linear_pr_status(
        self,
        *,
        active_linear_issues: Iterable[dict],
        open_prs_by_key: dict[str, dict],
        signoff_ready_pr_keys: set[str],
        poll_result: dict,
        current_ms: int,
        linear_breaker: _LinearWriteCircuitBreaker | None = None,
        hydrated_mergeability_node_ids: set[str] | None = None,
    ) -> list[dict]:
        """Reconcile Linear `allow-merge` one-shot triggers and live `In Review` PR status labels."""
        _ = current_ms
        if (
            self.linear_client is None
            or self.state_store.agent_name not in SWEEP_AGENT_ORDER
            or poll_result.get("open_prs_poll_error") is not None
            or poll_result.get("status") in (403, 429)
        ):
            return []

        breaker = linear_breaker if linear_breaker is not None else _LinearWriteCircuitBreaker()
        norm_signoff_keys = {
            str(k).strip().lower()
            for k in (signoff_ready_pr_keys or ())
            if str(k or "").strip()
        }
        issues_list = [issue for issue in (active_linear_issues or ()) if isinstance(issue, dict)]

        # Hydrate mergeability for open PRs attached to owned `In Review` Linear issues (including trusted/agent PRs).
        already_hydrated = hydrated_mergeability_node_ids if hydrated_mergeability_node_ids is not None else set()
        if hasattr(self.gh_client, "fetch_pull_request_mergeability"):
            in_review_hydrate_by_node_id: dict[str, str] = {}
            for issue in issues_list:
                if is_ignored_linear_issue_state(issue):
                    continue
                st_name = str(_as_dict(issue.get("state")).get("name") or "").strip().lower()
                if st_name not in ("in review", "in_review"):
                    continue
                target = extract_linear_github_target(issue, expected_kind="PR")
                if target is None:
                    continue
                t_repo, _, t_num, _ = target
                if not is_allowed_notification_repo(t_repo) or compute_pr_owner(t_repo, t_num) != self.state_store.agent_name:
                    continue
                pk = make_pr_key(t_repo, t_num)
                live_pr = (open_prs_by_key or {}).get(pk)
                if not isinstance(live_pr, dict) or str(live_pr.get("state") or "OPEN").upper() != "OPEN":
                    continue
                needs_mergeability = (
                    normalize_mergeable_state(
                        live_pr.get("mergeable"),
                        live_pr.get("merge_state_status") or live_pr.get("mergeStateStatus"),
                    )
                    == "UNKNOWN"
                )
                needs_reviews = (
                    "latest_opinionated_reviews" not in live_pr
                    and has_do_not_merge_label(live_pr.get("labels"))
                    and is_small_agent_pr_auto_merge_eligible(
                        live_pr,
                        max_lines=self.state_store.community_auto_merge_max_lines,
                        max_files=self.state_store.community_auto_merge_max_files,
                        excluded_repos=self.state_store.community_auto_merge_excluded_repos,
                    )
                )
                if not needs_mergeability and not needs_reviews:
                    continue
                nid = str(live_pr.get("node_id") or (live_pr.get("id") if isinstance(live_pr.get("id"), str) else "")).strip()
                if nid and nid not in already_hydrated:
                    in_review_hydrate_by_node_id[nid] = pk
            if in_review_hydrate_by_node_id:
                already_hydrated.update(in_review_hydrate_by_node_id.keys())
                try:
                    mergeability_map = self.gh_client.fetch_pull_request_mergeability(in_review_hydrate_by_node_id.keys())
                except Exception as exc:
                    sys.stderr.write(
                        f"moltis-github-companion in-review-mergeability warning ({self.state_store.agent_name}): {exc}\n"
                    )
                    mergeability_map = {}
                for nid, entry in (mergeability_map or {}).items():
                    pk = in_review_hydrate_by_node_id.get(nid)
                    if not pk or pk not in open_prs_by_key:
                        continue
                    _apply_pull_request_mergeability_entry(open_prs_by_key[pk], entry)

        def _merge_updated_issue(original: dict, updated: dict | None) -> dict:
            if not isinstance(updated, dict):
                return original
            merged = dict(updated)
            for preserve_key in ("attachments", "comments"):
                if preserve_key in original and preserve_key not in merged:
                    merged[preserve_key] = original[preserve_key]
            return merged

        def _update_linear_labels(
            linear_id: str,
            original_issue: dict,
            *,
            scope: str,
            pr_key: str,
            add_labels: tuple[str, ...] = (),
            remove_labels: tuple[str, ...] = (),
        ) -> dict | None:
            if not linear_id or breaker.skip_if_tripped(scope=scope):
                return None
            try:
                updated = self.linear_client.update_issue(
                    linear_id,
                    add_labels=add_labels,
                    remove_labels=remove_labels,
                )
            except Exception as exc:
                breaker.record_error(exc, scope=scope, item_key=pr_key)
                sys.stderr.write(f"moltis-github-companion {scope} warning ({pr_key} / {linear_id}): {exc}\n")
                return None
            breaker.record_success()
            return _merge_updated_issue(original_issue, updated)

        actions: list[dict] = []

        for raw_issue in issues_list:
            linear_issue = raw_issue
            if is_ignored_linear_issue_state(linear_issue):
                continue
            linear_id = str(linear_issue.get("id") or "").strip()
            if not linear_id:
                continue
            linear_identifier = str(linear_issue.get("identifier") or linear_id).strip()
            target = extract_linear_github_target(linear_issue, expected_kind="PR")
            if target is None:
                continue
            pr_repo, _, pr_number, normalized_pr_url = target
            if not is_allowed_notification_repo(pr_repo):
                continue
            if compute_pr_owner(pr_repo, pr_number) != self.state_store.agent_name:
                continue
            pr_key = make_pr_key(pr_repo, pr_number)
            pr = (open_prs_by_key or {}).get(pr_key)
            if not isinstance(pr, dict) or str(pr.get("state") or "OPEN").upper() != "OPEN":
                continue
            pr_url = str(pr.get("url") or normalized_pr_url or f"https://github.com/{pr_repo}/pull/{pr_number}").strip()
            linear_labels = extract_linear_issue_labels(linear_issue)

            # Part 1 — `allow-merge` one-shot trigger (any active state, open trusted PR only).
            if ALLOW_MERGE_LINEAR_LABEL in linear_labels:
                if (
                    is_trusted_instruction_actor(pr.get("author"))
                    and hasattr(self.linear_client, "verify_label_added_by_admin")
                    and not breaker.skip_if_tripped(scope="linear-allow-merge-verify")
                ):
                    verified: dict | None = None
                    verify_ok = False
                    try:
                        raw_verified = self.linear_client.verify_label_added_by_admin(linear_id, ALLOW_MERGE_LINEAR_LABEL)
                        verified = raw_verified if isinstance(raw_verified, dict) else None
                        verify_ok = True
                    except Exception as exc:
                        breaker.record_error(exc, scope="linear-allow-merge-verify", item_key=pr_key)
                        sys.stderr.write(
                            f"moltis-github-companion linear-allow-merge-verify warning ({pr_key} / {linear_id}): {exc}\n"
                        )
                    if verify_ok:
                        breaker.record_success()
                    if verified is not None:
                        if has_do_not_merge_label(pr.get("labels")):
                            gh_removed = False
                            try:
                                self.gh_client.remove_pull_request_label(pr_repo, pr_number, DO_NOT_MERGE_LABEL)
                                gh_removed = True
                            except Exception as exc:
                                sys.stderr.write(
                                    f"moltis-github-companion allow-merge-github-label warning ({pr_key} / {linear_id}): {exc}\n"
                                )
                            if gh_removed:
                                pr["labels"] = [
                                    lbl
                                    for lbl in extract_label_names(pr.get("labels"))
                                    if lbl.strip().lower() != DO_NOT_MERGE_LABEL
                                ]
                                updated_issue = _update_linear_labels(
                                    linear_id,
                                    linear_issue,
                                    scope="linear-allow-merge-clear",
                                    pr_key=pr_key,
                                    remove_labels=(ALLOW_MERGE_LINEAR_LABEL,),
                                )
                                if updated_issue is not None:
                                    linear_issue = updated_issue
                                    linear_labels = extract_linear_issue_labels(linear_issue)
                                comment_posted = False
                                if hasattr(self.linear_client, "post_comment") and not breaker.skip_if_tripped(
                                    scope="linear-allow-merge-comment"
                                ):
                                    audit_body = (
                                        f"Removed `{DO_NOT_MERGE_LABEL}` on {pr_url} after admin `{ALLOW_MERGE_LINEAR_LABEL}` "
                                        "approval; automated review and merge checks are active."
                                    )
                                    try:
                                        self.linear_client.post_comment(linear_id, audit_body)
                                        breaker.record_success()
                                        comment_posted = True
                                    except Exception as exc:
                                        breaker.record_error(exc, scope="linear-allow-merge-comment", item_key=pr_key)
                                        sys.stderr.write(
                                            f"moltis-github-companion linear-allow-merge-comment warning ({pr_key} / {linear_id}): {exc}\n"
                                        )
                                actions.append({
                                    "action": "allow_merge_hold_lifted",
                                    "pr_key": pr_key,
                                    "repo": pr_repo,
                                    "number": pr_number,
                                    "pr_url": pr_url,
                                    "linear_issue_id": linear_id,
                                    "linear_identifier": linear_identifier,
                                    "verified_by": verified,
                                    "comment_posted": comment_posted,
                                    "updated_issue": linear_issue,
                                })
                        else:
                            updated_issue = _update_linear_labels(
                                linear_id,
                                linear_issue,
                                scope="linear-allow-merge-clear",
                                pr_key=pr_key,
                                remove_labels=(ALLOW_MERGE_LINEAR_LABEL,),
                            )
                            if updated_issue is not None:
                                linear_issue = updated_issue
                                linear_labels = extract_linear_issue_labels(linear_issue)
                                actions.append({
                                    "action": "allow_merge_cleared",
                                    "pr_key": pr_key,
                                    "repo": pr_repo,
                                    "number": pr_number,
                                    "pr_url": pr_url,
                                    "linear_issue_id": linear_id,
                                    "linear_identifier": linear_identifier,
                                    "verified_by": verified,
                                    "updated_issue": linear_issue,
                                })

            # Part 2 — Live `In Review` status labels (`approved`, `merge-conflicts`, `ci-failing`, `changes-requested`).
            state_name = str(_as_dict(linear_issue.get("state")).get("name") or "").strip().lower()
            if state_name not in ("in review", "in_review"):
                continue

            has_conflicts = is_merge_conflicting(
                pr.get("mergeable"),
                pr.get("merge_state_status") or pr.get("mergeStateStatus"),
            )
            ci_norm = normalize_ci_state(pr.get("ci_state") if "ci_state" in pr else pr.get("statusCheckRollup"))
            has_ci_failure = ci_norm in ("FAILURE", "ERROR")
            review_decision = str(pr.get("review_decision") or pr.get("reviewDecision") or "").strip().upper()
            unresolved_thread_count = (
                max(0, _safe_int(pr.get("unresolved_thread_count"), 0))
                if "unresolved_thread_count" in pr
                else count_unresolved_review_threads(
                    pr.get("reviewThreads") if "reviewThreads" in pr else pr.get("review_threads")
                )
            )
            has_unresolved_threads = unresolved_thread_count > 0 or bool(pr.get("has_unresolved_review_threads"))
            has_changes_requested = (review_decision == "CHANGES_REQUESTED") or has_unresolved_threads
            has_do_not_merge = has_do_not_merge_label(pr.get("labels"))

            if has_do_not_merge and is_small_agent_pr_auto_merge_eligible(
                pr,
                max_lines=self.state_store.community_auto_merge_max_lines,
                max_files=self.state_store.community_auto_merge_max_files,
                excluded_repos=self.state_store.community_auto_merge_excluded_repos,
                has_operator_guidance=False,
            ):
                operator_guidance = self._get_linear_issue_operator_guidance(linear_issue)
                if is_small_agent_pr_auto_merge_eligible(
                    pr,
                    max_lines=self.state_store.community_auto_merge_max_lines,
                    max_files=self.state_store.community_auto_merge_max_files,
                    excluded_repos=self.state_store.community_auto_merge_excluded_repos,
                    has_operator_guidance=bool(operator_guidance),
                ):
                    head_sha = str(pr.get("head_sha") or pr.get("headRefOid") or "").strip()
                    if head_sha:
                        raw_req_reviewers = (
                            pr.get("requested_reviewers")
                            if "requested_reviewers" in pr
                            else (pr.get("review_requests") if "review_requests" in pr else pr.get("reviewRequests"))
                        )
                        requested_reviewers = set(extract_review_request_logins(raw_req_reviewers))
                        opinionated_reviews = extract_latest_opinionated_reviews(
                            pr.get("latest_opinionated_reviews")
                            if "latest_opinionated_reviews" in pr
                            else pr.get("latestOpinionatedReviews")
                        )
                        traya_reviewed_head = any(
                            r["author"] == "sith-traya" and r["commit_oid"].lower() == head_sha.lower()
                            for r in opinionated_reviews
                        )
                        pr_entry = _as_dict(self.state_store.get_thread_state(pr_key))
                        if (
                            "sith-traya" not in requested_reviewers
                            and not traya_reviewed_head
                            and str(pr_entry.get("traya_review_requested_sha") or "").strip() != head_sha
                            and hasattr(self.gh_client, "add_pull_request_reviewer")
                        ):
                            try:
                                self.gh_client.add_pull_request_reviewer(pr_repo, pr_number, "sith-traya")
                                self.state_store.update_thread_state(
                                    pr_key,
                                    {
                                        "repo": pr_repo,
                                        "number": pr_number,
                                        "subject_type": "PullRequest",
                                        "traya_review_requested_sha": head_sha,
                                    },
                                    now_override_ms=current_ms,
                                )
                                actions.append({
                                    "action": "traya_review_requested",
                                    "pr_key": pr_key,
                                    "repo": pr_repo,
                                    "number": pr_number,
                                    "pr_url": pr_url,
                                    "head_sha": head_sha,
                                    "linear_issue_id": linear_id,
                                    "linear_identifier": linear_identifier,
                                })
                            except Exception as exc:
                                sys.stderr.write(
                                    f"moltis-github-companion small-agent-pr-traya-reviewer warning ({pr_key} / {linear_id}): {exc}\n"
                                )

                        if (
                            not has_conflicts
                            and not has_ci_failure
                            and not has_changes_requested
                            and ci_norm in ("SUCCESS", "NONE")
                            and has_dual_family_head_approvals(pr)
                        ):
                            gh_removed = False
                            try:
                                self.gh_client.remove_pull_request_label(pr_repo, pr_number, DO_NOT_MERGE_LABEL)
                                gh_removed = True
                            except Exception as exc:
                                sys.stderr.write(
                                    f"moltis-github-companion small-agent-pr-remove-hold warning ({pr_key} / {linear_id}): {exc}\n"
                                )
                            if gh_removed:
                                pr["labels"] = [
                                    lbl
                                    for lbl in extract_label_names(pr.get("labels"))
                                    if lbl.strip().lower() != DO_NOT_MERGE_LABEL
                                ]
                                has_do_not_merge = False
                                clear_labels = tuple(
                                    lbl
                                    for lbl in (APPROVED_LINEAR_LABEL, ALLOW_MERGE_LINEAR_LABEL)
                                    if lbl in linear_labels
                                )
                                if clear_labels:
                                    updated_issue = _update_linear_labels(
                                        linear_id,
                                        linear_issue,
                                        scope="linear-small-agent-pr-hold-clear",
                                        pr_key=pr_key,
                                        remove_labels=clear_labels,
                                    )
                                    if updated_issue is not None:
                                        linear_issue = updated_issue
                                        linear_labels = extract_linear_issue_labels(linear_issue)
                                comment_posted = False
                                if hasattr(self.linear_client, "post_comment") and not breaker.skip_if_tripped(
                                    scope="linear-small-agent-pr-hold-comment"
                                ):
                                    audit_body = (
                                        f"Dual-family consensus (Gemini + Traya) verified on {pr_url} ({head_sha[:12]}); "
                                        f"removed `{DO_NOT_MERGE_LABEL}` for automated merge."
                                    )
                                    try:
                                        self.linear_client.post_comment(linear_id, audit_body)
                                        breaker.record_success()
                                        comment_posted = True
                                    except Exception as exc:
                                        breaker.record_error(
                                            exc,
                                            scope="linear-small-agent-pr-hold-comment",
                                            item_key=pr_key,
                                        )
                                        sys.stderr.write(
                                            f"moltis-github-companion linear-small-agent-pr-hold-comment warning ({pr_key} / {linear_id}): {exc}\n"
                                        )
                                actions.append({
                                    "action": "small_agent_pr_hold_lifted",
                                    "pr_key": pr_key,
                                    "repo": pr_repo,
                                    "number": pr_number,
                                    "pr_url": pr_url,
                                    "head_sha": head_sha,
                                    "linear_issue_id": linear_id,
                                    "linear_identifier": linear_identifier,
                                    "comment_posted": comment_posted,
                                    "updated_issue": linear_issue,
                                })

            is_approved_signoff_ready = (
                not has_conflicts
                and not has_ci_failure
                and not has_changes_requested
                and ci_norm in ("SUCCESS", "NONE")
                and has_do_not_merge
                and (pr_key in norm_signoff_keys or review_decision == "APPROVED")
            )

            add_labels: list[str] = []
            remove_labels: list[str] = []
            if is_approved_signoff_ready:
                if APPROVED_LINEAR_LABEL not in linear_labels:
                    add_labels.append(APPROVED_LINEAR_LABEL)
                for lbl in IN_REVIEW_APPROVED_CLEAR_LABELS:
                    if lbl in linear_labels:
                        remove_labels.append(lbl)
            else:
                blocker_flags = (
                    (MERGE_CONFLICTS_LABEL, has_conflicts),
                    (CI_FAILING_LINEAR_LABEL, has_ci_failure),
                    (CHANGES_REQUESTED_LINEAR_LABEL, has_changes_requested),
                )
                for lbl, is_active in blocker_flags:
                    if is_active and lbl not in linear_labels:
                        add_labels.append(lbl)
                if APPROVED_LINEAR_LABEL in linear_labels:
                    remove_labels.append(APPROVED_LINEAR_LABEL)
                for lbl, is_active in blocker_flags:
                    if not is_active and lbl in linear_labels:
                        remove_labels.append(lbl)
                if has_conflicts and "ready-to-merge" in linear_labels:
                    remove_labels.append("ready-to-merge")

            if not add_labels and not remove_labels:
                continue

            updated_issue = _update_linear_labels(
                linear_id,
                linear_issue,
                scope="linear-in-review-labels",
                pr_key=pr_key,
                add_labels=tuple(add_labels),
                remove_labels=tuple(remove_labels),
            )
            if updated_issue is not None:
                actions.append({
                    "action": "in_review_labels_synced",
                    "pr_key": pr_key,
                    "repo": pr_repo,
                    "number": pr_number,
                    "pr_url": pr_url,
                    "linear_issue_id": linear_id,
                    "linear_identifier": linear_identifier,
                    "added": list(add_labels),
                    "removed": list(remove_labels),
                    "updated_issue": updated_issue,
                })

        return actions

    def _process_stale_issues(
        self,
        *,
        open_issues: Iterable[dict],
        active_linear_issues: Iterable[dict],
        poll_result: dict,
        current_ms: int,
        linear_breaker: _LinearWriteCircuitBreaker | None = None,
    ) -> list[dict]:
        """Run ongoing 365-day stale-issue check-in and 30-day closure for owned community issues."""
        if (
            self.linear_client is None
            or self.state_store.agent_name not in SWEEP_AGENT_ORDER
            or poll_result.get("open_prs_poll_error") is not None
            or poll_result.get("open_issues_poll_error") is not None
            or poll_result.get("status") in (403, 429)
            or not hasattr(self.gh_client, "fetch_issue_stale_details")
        ):
            return []

        breaker = linear_breaker if linear_breaker is not None else _LinearWriteCircuitBreaker()

        # Pre-filter cheap checks before calling batched GraphQL details.
        candidates: dict[str, dict] = {}
        for raw_issue in open_issues or ():
            if not isinstance(raw_issue, dict):
                continue
            if str(raw_issue.get("state") or "OPEN").upper() != "OPEN":
                continue
            repo = str(raw_issue.get("repo") or "").strip()
            number = _safe_int(raw_issue.get("number"), 0)
            if not repo or number <= 0 or not is_allowed_notification_repo(repo):
                continue
            if compute_issue_owner(repo, number) != self.state_store.agent_name:
                continue
            if is_stale_issue_excluded_repo(repo):
                continue
            if is_stale_issue_excluded_author(raw_issue.get("author")):
                continue
            if _has_stale_issue_excluded_label(extract_label_names(raw_issue.get("labels"))):
                continue
            issue_key = make_pr_key(repo, number)
            issue_entry = _as_dict(self.state_store.get_thread_state(issue_key))
            if bool(issue_entry.get("coercion_blocked")):
                continue
            _, state_checkin_ms = normalize_ts(issue_entry.get("stale_checkin_posted_at"))
            has_pending_checkin = state_checkin_ms > 0
            if not has_pending_checkin:
                latest_cm = _as_dict(raw_issue.get("latest_comment"))
                latest_actor = normalize_github_actor(latest_cm.get("author") or latest_cm.get("user"))
                latest_body = str(latest_cm.get("body") or "").lower()
                if latest_actor in TRUSTED_INSTRUCTION_ACTORS and STALE_ISSUE_CHECKIN_MARKER_PHRASE in latest_body:
                    has_pending_checkin = True
            _, updated_at_ms = normalize_ts(raw_issue.get("updated_at") or raw_issue.get("updatedAt"))
            if not has_pending_checkin and (updated_at_ms <= 0 or (current_ms - updated_at_ms) < STALE_ISSUE_INACTIVE_AFTER_MS):
                continue
            candidates[issue_key] = {
                "repo": repo,
                "number": number,
                "issue_key": issue_key,
                "live_issue": raw_issue,
                "issue_entry": issue_entry,
                "state_checkin_ms": state_checkin_ms,
            }

        if not candidates:
            return []

        details_by_key = self.gh_client.fetch_issue_stale_details(
            [(c["repo"], c["number"]) for c in candidates.values()]
        )
        if not details_by_key:
            return []

        linear_by_issue_key: dict[str, dict] = {}
        for issue in active_linear_issues or ():
            if not isinstance(issue, dict):
                continue
            labels = extract_linear_issue_labels(issue)
            if "pr" in labels and "issue" not in labels:
                continue
            target = extract_linear_github_target(issue, expected_kind="Issue")
            if target is None:
                continue
            t_repo, _, t_num, _ = target
            linear_by_issue_key[make_pr_key(t_repo, t_num)] = issue

        def _resolve_existing_linear_issue(issue_key: str, issue_url: str, issue_entry: dict) -> tuple[dict | None, bool]:
            if issue_key in linear_by_issue_key:
                cand = linear_by_issue_key[issue_key]
            else:
                cand = None
                stored_id = str(issue_entry.get("linear_issue_id") or "").strip()
                if stored_id:
                    try:
                        cand = self.linear_client.get_issue(stored_id)
                    except Exception as exc:
                        if not _is_linear_issue_not_found_error(exc):
                            sys.stderr.write(
                                f"moltis-github-companion stale-issue linear-get warning ({issue_key} / {stored_id}): {exc}\n"
                            )
                            return None, False
                        cand = None
                if cand is None:
                    try:
                        cand = self.linear_client.find_issue_by_github_url(issue_url, item_kind="Issue")
                    except Exception as exc:
                        sys.stderr.write(
                            f"moltis-github-companion stale-issue linear-find warning ({issue_key}): {exc}\n"
                        )
                        return None, False
                if isinstance(cand, dict):
                    linear_by_issue_key[issue_key] = cand
            if not isinstance(cand, dict):
                return None, True
            c_labels = extract_linear_issue_labels(cand)
            if "pr" in c_labels and "issue" not in c_labels:
                return None, True
            return cand, True

        def _post_linear_comment_safe(linear_id: str, body: str, issue_key: str) -> bool:
            if not linear_id or not hasattr(self.linear_client, "post_comment"):
                return False
            if breaker.skip_if_tripped(scope="linear-stale-issue-comment"):
                return False
            try:
                self.linear_client.post_comment(linear_id, body)
            except Exception as exc:
                breaker.record_error(exc, scope="linear-stale-issue-comment", item_key=issue_key)
                sys.stderr.write(
                    f"moltis-github-companion linear-stale-issue-comment warning ({issue_key} / {linear_id}): {exc}\n"
                )
                return False
            breaker.record_success()
            return True

        def _update_linear_safe(
            linear_id: str,
            *,
            issue_key: str,
            state: str | None = None,
            add_labels: tuple[str, ...] = (),
        ) -> dict | None:
            if not linear_id or breaker.skip_if_tripped(scope="linear-stale-issue-update"):
                return None
            try:
                updated = self.linear_client.update_issue(
                    linear_id,
                    state=state,
                    add_labels=add_labels,
                )
            except Exception as exc:
                breaker.record_error(exc, scope="linear-stale-issue-update", item_key=issue_key)
                sys.stderr.write(
                    f"moltis-github-companion linear-stale-issue-update warning ({issue_key} / {linear_id}): {exc}\n"
                )
                return None
            breaker.record_success()
            if isinstance(updated, dict):
                linear_by_issue_key[issue_key] = updated
            return updated

        def _clear_pending_checkin_if_set(issue_key: str, state_checkin_ms: int) -> None:
            if state_checkin_ms > 0:
                self.state_store.update_thread_state(
                    issue_key,
                    {"stale_checkin_posted_at": None},
                    now_override_ms=current_ms,
                )

        actions: list[dict] = []
        actions_this_poll = 0

        for issue_key in sorted(candidates):
            if actions_this_poll >= MAX_STALE_ISSUE_ACTIONS_PER_POLL:
                break
            cand = candidates[issue_key]
            details = details_by_key.get(issue_key)
            if not isinstance(details, dict):
                continue

            repo = str(cand["repo"])
            number = int(cand["number"])
            live_issue = _as_dict(cand["live_issue"])
            issue_entry = _as_dict(cand["issue_entry"])
            state_checkin_ms = int(cand["state_checkin_ms"])
            issue_url = (
                str(live_issue.get("url") or issue_entry.get("url") or "").strip()
                or f"https://github.com/{repo}/issues/{number}"
            )

            # Full guard checks on fetched issue details.
            if str(details.get("state") or "").strip().upper() != "OPEN":
                _clear_pending_checkin_if_set(issue_key, state_checkin_ms)
                continue
            if is_stale_issue_excluded_repo(repo):
                _clear_pending_checkin_if_set(issue_key, state_checkin_ms)
                continue
            detail_author_obj = details.get("author")
            detail_author_assoc = details.get("authorAssociation")
            if is_stale_issue_excluded_author(detail_author_obj, detail_author_assoc):
                _clear_pending_checkin_if_set(issue_key, state_checkin_ms)
                continue
            detail_labels = extract_label_names(details.get("labels"))
            if _has_stale_issue_excluded_label(detail_labels):
                _clear_pending_checkin_if_set(issue_key, state_checkin_ms)
                continue
            if _stale_issue_has_linked_pr(details.get("timelineItems")):
                _clear_pending_checkin_if_set(issue_key, state_checkin_ms)
                continue
            if _safe_int(_as_dict(details.get("reactions")).get("totalCount"), 0) > 1:
                _clear_pending_checkin_if_set(issue_key, state_checkin_ms)
                continue

            # CRITICAL Linear guard: look up existing Linear issue without ever creating one.
            linear_issue, lookup_ok = _resolve_existing_linear_issue(issue_key, issue_url, issue_entry)
            if not lookup_ok:
                continue
            if linear_issue is not None and is_stale_issue_protected_linear_issue(linear_issue):
                _clear_pending_checkin_if_set(issue_key, state_checkin_ms)
                continue

            # Qualifying type guard: require a qualifying GitHub label OR Linear Feature/Improvement (never bug).
            gh_labels_lower = {lbl.strip().lower() for lbl in detail_labels if lbl.strip()}
            lin_labels_lower = extract_linear_issue_labels(linear_issue) if linear_issue is not None else set()
            has_qualifying_gh_label = bool(gh_labels_lower & STALE_ISSUE_QUALIFYING_GITHUB_LABELS)
            has_qualifying_linear_label = (
                linear_issue is not None
                and "bug" not in lin_labels_lower
                and bool(lin_labels_lower & STALE_ISSUE_QUALIFYING_LINEAR_LABELS)
            )
            if not (has_qualifying_gh_label or has_qualifying_linear_label):
                _clear_pending_checkin_if_set(issue_key, state_checkin_ms)
                continue

            detail_author = extract_actor_login(detail_author_obj) or str(live_issue.get("author") or "").strip()
            detail_author_norm = normalize_github_actor(detail_author_obj) or normalize_github_actor(detail_author)
            comment_nodes = _stale_issue_comment_nodes(details.get("comments"))
            prior_closed_ms = _safe_int(issue_entry.get("stale_closed_at_ms"), 0)
            gh_checkin_ms = _find_stale_issue_checkin_ts(comment_nodes, after_ms=prior_closed_ms)
            checkin_ts_ms = gh_checkin_ms if gh_checkin_ms > 0 else state_checkin_ms

            lin_id = str(_as_dict(linear_issue).get("id") or "").strip() or None
            lin_ident = str(_as_dict(linear_issue).get("identifier") or "").strip() or None
            lin_url = str(_as_dict(linear_issue).get("url") or "").strip() or None

            # Stage 2: a prior check-in comment exists.
            if checkin_ts_ms > 0:
                if _has_human_comment_after(comment_nodes, checkin_ts_ms):
                    _clear_pending_checkin_if_set(issue_key, state_checkin_ms)
                    continue
                if _stale_issue_has_community_commenter(comment_nodes, issue_author_norm=detail_author_norm):
                    _clear_pending_checkin_if_set(issue_key, state_checkin_ms)
                    continue
                if (current_ms - checkin_ts_ms) < STALE_ISSUE_CLOSE_AFTER_MS:
                    if state_checkin_ms != checkin_ts_ms:
                        self.state_store.update_thread_state(
                            issue_key,
                            {"stale_checkin_posted_at": checkin_ts_ms},
                            now_override_ms=current_ms,
                        )
                    continue
                try:
                    self.gh_client.close_issue(
                        repo,
                        number,
                        comment=format_stale_issue_close_github_comment(),
                        reason="not planned",
                    )
                except Exception as exc:
                    sys.stderr.write(f"moltis-github-companion stale-issue-close warning ({issue_key}): {exc}\n")
                    continue
                actions_this_poll += 1
                self.state_store.update_thread_state(
                    issue_key,
                    {
                        "repo": repo,
                        "number": number,
                        "subject_type": "Issue",
                        "url": issue_url,
                        "stale_checkin_posted_at": None,
                        "stale_closed_at_ms": current_ms,
                        "stale_closed_reason": "issue_365d_inactive_30d_checkin",
                    },
                    now_override_ms=current_ms,
                )
                if lin_id:
                    _update_linear_safe(
                        lin_id,
                        issue_key=issue_key,
                        state="Canceled",
                        add_labels=("stale-closed",),
                    )
                    _post_linear_comment_safe(
                        lin_id,
                        format_linear_stale_issue_closed_comment(issue_url=issue_url),
                        issue_key,
                    )
                actions.append({
                    "action": "stale_issue_closed",
                    "key": issue_key,
                    "repo": repo,
                    "number": number,
                    "author": detail_author,
                    "linear_issue_id": lin_id,
                    "linear_issue_identifier": lin_ident,
                    "linear_issue_url": lin_url,
                })
                continue

            # Stage 1: no prior check-in comment exists.
            if _stale_issue_has_community_commenter(comment_nodes, issue_author_norm=detail_author_norm):
                continue
            _, detail_updated_at_ms = normalize_ts(details.get("updatedAt") or live_issue.get("updated_at"))
            if detail_updated_at_ms <= 0 or (current_ms - detail_updated_at_ms) < STALE_ISSUE_INACTIVE_AFTER_MS:
                continue
            try:
                self.gh_client.comment_on_issue(
                    repo,
                    number,
                    format_stale_issue_checkin_github_comment(),
                )
            except Exception as exc:
                sys.stderr.write(f"moltis-github-companion stale-issue-checkin warning ({issue_key}): {exc}\n")
                continue
            actions_this_poll += 1
            self.state_store.update_thread_state(
                issue_key,
                {
                    "repo": repo,
                    "number": number,
                    "subject_type": "Issue",
                    "url": issue_url,
                    "stale_checkin_posted_at": current_ms,
                },
                now_override_ms=current_ms,
            )
            if lin_id:
                _post_linear_comment_safe(
                    lin_id,
                    format_linear_stale_issue_checkin_comment(issue_url=issue_url),
                    issue_key,
                )
            actions.append({
                "action": "stale_issue_checkin_posted",
                "key": issue_key,
                "repo": repo,
                "number": number,
                "author": detail_author,
                "linear_issue_id": lin_id,
                "linear_issue_identifier": lin_ident,
                "linear_issue_url": lin_url,
            })

        return actions

    def _evaluate_health_alerts(
        self,
        *,
        poll_result: dict,
        linear_breaker: _LinearWriteCircuitBreaker | None,
        current_ms: int,
    ) -> list[dict]:
        """Track consecutive poll failures, Linear circuit breaker trips, and dead-lettered items, emitting deduplicated Telegram alerts."""
        state = self.state_store.read_state()
        health = dict(state.get("health") or self.state_store._default_health())
        last_alerts = dict(_as_dict(health.get("last_health_alerts")))
        notified_dl = dict(_as_dict(health.get("notified_dead_letter_keys")))
        threads = _as_dict(state.get("threads"))

        has_poll_error = bool(
            poll_result.get("open_prs_poll_error")
            or poll_result.get("open_issues_poll_error")
            or poll_result.get("status") in (403, 429)
        )
        if has_poll_error:
            consecutive_poll_failures = max(0, _safe_int(health.get("consecutive_poll_failures"), 0)) + 1
        else:
            consecutive_poll_failures = 0

        display_name = derive_display_name(self.state_store.agent_name, self.execution_coordinator.agent_display_name)
        emitted: list[dict] = []

        def _cooldown_allows(alert_key: str) -> bool:
            last_sent = _safe_int(last_alerts.get(alert_key), 0)
            return last_sent <= 0 or (current_ms - last_sent) >= HEALTH_ALERT_COOLDOWN_MS

        def _try_send(message: str) -> bool:
            if self.read_only_trial or self.telegram_client is None:
                return False
            try:
                self.telegram_client.send_message(message)
                return True
            except Exception as exc:
                sys.stderr.write(f"moltis-github-companion health-alert telegram warning ({self.state_store.agent_name}): {exc}\n")
                return False

        if consecutive_poll_failures >= HEALTH_POLL_FAILURE_THRESHOLD and _cooldown_allows("poll_failures"):
            parts: list[str] = []
            if poll_result.get("status") in (403, 429):
                parts.append(f"GitHub HTTP {poll_result.get('status')}")
            if poll_result.get("open_prs_poll_error"):
                parts.append("open PRs poll error")
            if poll_result.get("open_issues_poll_error"):
                parts.append("open issues poll error")
            detail = ", ".join(parts) or "poll error"
            msg = f"🚨 [{display_name} health] {consecutive_poll_failures} consecutive poll failures ({detail})."
            if _try_send(msg):
                last_alerts["poll_failures"] = current_ms
                emitted.append({
                    "key": "poll_failures",
                    "consecutive_poll_failures": consecutive_poll_failures,
                    "message": msg,
                    "sent": True,
                })

        if linear_breaker is not None and linear_breaker.tripped and _cooldown_allows("linear_circuit_breaker"):
            reason_safe = _sanitize_health_reason(linear_breaker.reason or "Linear write errors") or "Linear write errors"
            msg = f"🚨 [{display_name} health] Linear write circuit breaker tripped ({reason_safe})."
            if _try_send(msg):
                last_alerts["linear_circuit_breaker"] = current_ms
                emitted.append({
                    "key": "linear_circuit_breaker",
                    "reason": reason_safe,
                    "message": msg,
                    "sent": True,
                })

        new_dead_letters: list[tuple[str, int, str, str]] = []
        active_thread_keys = set(threads.keys())
        for stale_key in list(notified_dl.keys()):
            if stale_key not in active_thread_keys:
                notified_dl.pop(stale_key, None)
        for key, entry in sorted(threads.items()):
            if not isinstance(entry, dict):
                continue
            retry_count = _safe_int(entry.get("retry_count"), 0)
            if retry_count < MAX_THREAD_FAILURE_RETRIES:
                notified_dl.pop(key, None)
                continue
            raw_reason = str(entry.get("last_failure_reason") or "").strip()
            fingerprint = f"{retry_count}:{raw_reason}"
            if notified_dl.get(key) != fingerprint:
                new_dead_letters.append((key, retry_count, raw_reason, fingerprint))

        if new_dead_letters:
            lines = [f"🚨 [{display_name} health] Dead-lettered items ({len(new_dead_letters)}):"]
            for dl_key, dl_retries, dl_reason, _ in new_dead_letters[:10]:
                safe_reason = _sanitize_health_reason(dl_reason, max_len=60) if dl_reason else "max retries reached"
                lines.append(f"- {dl_key} ({dl_retries} retries, {safe_reason})")
            if len(new_dead_letters) > 10:
                lines.append(f"- +{len(new_dead_letters) - 10} more")
            msg = "\n".join(lines)
            if _try_send(msg):
                for dl_key, _, _, dl_fp in new_dead_letters:
                    notified_dl[dl_key] = dl_fp
                emitted.append({
                    "key": "dead_letter",
                    "items": [dl_key for dl_key, _, _, _ in new_dead_letters],
                    "message": msg,
                    "sent": True,
                })

        self.state_store.write_state(
            {
                "health": {
                    "consecutive_poll_failures": consecutive_poll_failures,
                    "last_health_alerts": last_alerts,
                    "notified_dead_letter_keys": notified_dl,
                }
            },
            now_override_ms=current_ms,
        )
        return emitted

    def _collect_pending_security_releases(self, *, active_linear_issues: Iterable[dict]) -> list[dict]:
        """Collect pending security patch releases from active Linear release cards and local state."""
        pending: list[dict] = []
        seen_ids: set[str] = set()
        seen_urls: set[str] = set()

        for issue in active_linear_issues or ():
            if not isinstance(issue, dict) or is_ignored_linear_issue_state(issue):
                continue
            labels = extract_linear_issue_labels(issue)
            if "release" not in labels:
                continue
            lin_id = str(issue.get("id") or "").strip()
            lin_url = str(issue.get("url") or "").strip()
            if lin_id:
                seen_ids.add(lin_id)
            if lin_url:
                seen_urls.add(lin_url)
            pending.append({
                "title": str(issue.get("title") or "").strip(),
                "linear_issue_id": lin_id,
                "linear_url": lin_url,
                "url": lin_url,
                "has_non_patch_commits": "unreleased feat" in str(issue.get("description") or "").lower()
                or "non-patch" in str(issue.get("description") or "").lower(),
            })

        state = self.state_store.read_state()
        notified = _as_dict(_as_dict(state.get("security_releases")).get("notified_releases"))
        for repo_key in sorted(notified.keys()):
            rec = notified.get(repo_key)
            if not isinstance(rec, dict) or not rec.get("pending", True):
                continue
            lin_id = str(rec.get("linear_issue_id") or "").strip()
            lin_url = str(rec.get("linear_url") or "").strip()
            if (lin_id and lin_id in seen_ids) or (lin_url and lin_url in seen_urls):
                continue
            pending.append({
                "repo": str(rec.get("repo") or repo_key).strip(),
                "next_tag": str(rec.get("next_tag") or "").strip(),
                "linear_issue_id": lin_id,
                "linear_url": lin_url,
                "url": lin_url,
                "has_non_patch_commits": bool(rec.get("has_non_patch_commits")),
            })
        return pending

    def _maybe_send_operator_digest(
        self,
        *,
        active_linear_issues: Iterable[dict],
        pending_security_releases: list[dict],
        current_ms: int,
    ) -> dict | None:
        """Send the scheduled weekday 08:30 Europe/London 'Waiting on Martin' digest from `skrye`."""
        if self.read_only_trial:
            return None
        if self.state_store.agent_name != OPERATOR_DIGEST_AGENT:
            return None
        if not resolve_operator_digest_enabled(self._operator_digest_enabled):
            return None
        if self.telegram_client is None:
            return None

        dt = _london_datetime(current_ms)
        if dt.weekday() >= 5:
            return None
        if (dt.hour, dt.minute) < (OPERATOR_DIGEST_HOUR_LONDON, OPERATOR_DIGEST_MINUTE_LONDON):
            return None

        today_str = dt.strftime("%Y-%m-%d")
        is_monday = dt.weekday() == 0
        state = self.state_store.read_state()
        if _as_dict(state.get("digest")).get("last_digest_date") == today_str:
            return None

        approved: list[dict] = []
        ready_to_merge: list[dict] = []
        needs_decision: list[dict] = []
        first_time_prs: list[dict] = []
        signoff_issues: list[dict] = []
        for issue in active_linear_issues or ():
            if not isinstance(issue, dict) or is_ignored_linear_issue_state(issue):
                continue
            labels = extract_linear_issue_labels(issue)
            is_pr = "pr" in labels
            is_issue = "issue" in labels
            is_approved = APPROVED_LINEAR_LABEL in labels
            if is_approved:
                approved.append(issue)
            if is_pr and "ready-to-merge" in labels and not is_approved:
                ready_to_merge.append(issue)
            if (is_pr or is_issue) and "needs-decision" in labels:
                needs_decision.append(issue)
            if is_pr and "first-time" in labels and "needs-decision" not in labels:
                first_time_prs.append(issue)
            if is_issue and "sign-off-required" in labels and not is_approved:
                signoff_issues.append(issue)

        threads = _as_dict(state.get("threads"))
        dead_letter_keys = sorted(
            str(k)
            for k, entry in threads.items()
            if isinstance(entry, dict) and _safe_int(entry.get("retry_count"), 0) >= MAX_THREAD_FAILURE_RETRIES
        )

        text = format_operator_digest(
            date_str=today_str,
            approved=approved,
            ready_to_merge=ready_to_merge,
            needs_decision=needs_decision,
            first_time_prs=first_time_prs,
            signoff_issues=signoff_issues,
            security_releases=list(pending_security_releases or []),
            dead_letter_keys=dead_letter_keys,
            is_monday=is_monday,
        )
        if not text:
            return None

        try:
            self.telegram_client.send_message(text)
        except Exception as exc:
            sys.stderr.write(f"moltis-github-companion operator-digest telegram warning ({self.state_store.agent_name}): {exc}\n")
            return None

        self.state_store.write_state(
            {"digest": {"last_digest_date": today_str}},
            now_override_ms=current_ms,
        )
        return {
            "date": today_str,
            "is_monday": is_monday,
            "sent": True,
            "counts": {
                "approved": len(approved),
                "ready_to_merge": len(ready_to_merge),
                "needs_decision": len(needs_decision),
                "first_time_prs": len(first_time_prs),
                "signoff_issues": len(signoff_issues),
                "security_releases": len(pending_security_releases or []),
                "dead_letter_keys": len(dead_letter_keys),
            },
            "message": text,
        }

    def _link_open_prs_to_linear_issues(
        self,
        *,
        open_prs_by_key: dict[str, dict],
        active_linear_issues: Iterable[dict],
        known_linear_issues_by_pr_key: dict[str, dict] | None = None,
        current_ms: int,
        linear_breaker: _LinearWriteCircuitBreaker | None = None,
    ) -> list[dict]:
        """Link owned open PR Linear cards to referenced active GitHub Issue Linear cards via `related` relations."""
        if (
            self.linear_client is None
            or self.state_store.agent_name not in SWEEP_AGENT_ORDER
            or not hasattr(self.linear_client, "create_issue_relation")
        ):
            return []
        breaker = linear_breaker if linear_breaker is not None else _LinearWriteCircuitBreaker()
        if breaker.skip_if_tripped(scope="linear-pr-issue-link"):
            return []

        linear_pr_by_key: dict[str, dict] = {}
        for k, val in (known_linear_issues_by_pr_key or {}).items():
            if isinstance(val, dict) and not is_ignored_linear_issue_state(val):
                linear_pr_by_key[str(k).strip().lower()] = val

        linear_issue_by_key: dict[str, dict] = {}
        for issue in active_linear_issues or ():
            if not isinstance(issue, dict) or is_ignored_linear_issue_state(issue):
                continue
            labels = extract_linear_issue_labels(issue)
            if "pr" in labels:
                pr_target = extract_linear_github_target(issue, expected_kind="PR")
                if pr_target is not None:
                    pk = make_pr_key(pr_target[0], pr_target[2])
                    linear_pr_by_key.setdefault(pk, issue)
            if "issue" in labels and "pr" not in labels:
                iss_target = extract_linear_github_target(issue, expected_kind="Issue")
                if iss_target is not None:
                    ik = make_pr_key(iss_target[0], iss_target[2])
                    linear_issue_by_key.setdefault(ik, issue)

        linked: list[dict] = []
        for pr_key, live_pr in sorted((open_prs_by_key or {}).items()):
            if not isinstance(live_pr, dict) or str(live_pr.get("state") or "OPEN").upper() != "OPEN":
                continue
            repo = str(live_pr.get("repo") or "").strip()
            number = _safe_int(live_pr.get("number"), 0)
            if not repo or number <= 0 or not is_allowed_notification_repo(repo):
                continue
            if compute_pr_owner(repo, number) != self.state_store.agent_name:
                continue
            pr_linear = linear_pr_by_key.get(pr_key.lower())
            if pr_linear is None:
                continue
            pr_linear_id = str(pr_linear.get("id") or "").strip()
            if not pr_linear_id:
                continue
            closing_issues = extract_pr_closing_issues(live_pr, default_repo=repo)
            if not closing_issues:
                continue
            pr_entry = _as_dict(self.state_store.get_thread_state(pr_key))
            linked_ids = [
                str(x).strip()
                for x in (pr_entry.get("linked_linear_issue_ids") or [])
                if str(x or "").strip()
            ]
            for ref in closing_issues:
                issue_key = str(ref.get("issue_key") or "").strip().lower()
                issue_linear = linear_issue_by_key.get(issue_key)
                if issue_linear is None:
                    continue
                issue_linear_id = str(issue_linear.get("id") or "").strip()
                if not issue_linear_id or issue_linear_id == pr_linear_id or issue_linear_id in linked_ids:
                    continue
                if breaker.skip_if_tripped(scope="linear-pr-issue-link"):
                    return linked
                try:
                    relation = self.linear_client.create_issue_relation(
                        pr_linear_id,
                        issue_linear_id,
                        relation_type="related",
                    )
                except Exception as exc:
                    if breaker.record_error(exc, scope="linear-pr-issue-link", item_key=f"{pr_key}->{issue_key}"):
                        return linked
                    sys.stderr.write(
                        f"moltis-github-companion linear-pr-issue-link warning ({pr_key} -> {issue_key}): {exc}\n"
                    )
                    continue
                breaker.record_success()
                linked_ids.append(issue_linear_id)
                self.state_store.update_thread_state(
                    pr_key,
                    {
                        "repo": repo,
                        "number": number,
                        "linked_linear_issue_ids": list(linked_ids),
                    },
                    now_override_ms=current_ms,
                )
                linked.append({
                    "pr_key": pr_key,
                    "issue_key": issue_key,
                    "pr_linear_id": pr_linear_id,
                    "issue_linear_id": issue_linear_id,
                    "relation_id": str(_as_dict(relation).get("id") or "").strip() or None,
                    "relation_type": "related",
                })
        return linked

    def _resolve_security_release_repos(
        self,
        *,
        current_ms: int,
        extra_repos: Iterable[str] | str | None = None,
    ) -> tuple[str, ...]:
        """Resolve release-managed repos from 6h-cached Haberdasher discovery plus configured extra repos."""
        state = self.state_store.read_state()
        sec_state = dict(state.get("security_releases") or self.state_store._default_security_releases())
        cached_sources = [
            norm
            for entry in (sec_state.get("haberdasher_sources") or [])
            if (norm := _normalize_valid_haberdasher_repo(entry)) is not None
        ]
        fetched_at_ms = _safe_int(sec_state.get("haberdasher_sources_fetched_at_ms"), 0)
        cache_stale = (
            not cached_sources
            or fetched_at_ms <= 0
            or (current_ms - fetched_at_ms) >= HABERDASHER_SOURCES_CACHE_TTL_MS
        )

        fetcher = getattr(self.gh_client, "fetch_haberdasher_sources", None)
        if cache_stale and callable(fetcher):
            fetched: tuple[str, ...] | None = None
            try:
                raw_fetched = fetcher()
                if raw_fetched is not None:
                    fetched = tuple(
                        norm
                        for entry in raw_fetched
                        if (norm := _normalize_valid_haberdasher_repo(entry)) is not None
                    )
            except Exception as exc:
                sys.stderr.write(f"moltis-github-companion haberdasher-sources warning: {exc}\n")
                fetched = None
            if fetched is not None:
                deduped_fetched: list[str] = []
                for repo in fetched:
                    if repo not in deduped_fetched:
                        deduped_fetched.append(repo)
                cached_sources = deduped_fetched
                self.state_store.write_state(
                    {
                        "security_releases": {
                            "haberdasher_sources": cached_sources,
                            "haberdasher_sources_fetched_at_ms": current_ms,
                        }
                    },
                    now_override_ms=current_ms,
                )

        if extra_repos is None:
            sec_cfg = resolve_security_release_config(
                extra_repos=self._security_release_extra_repos,
                cooldown_secs=self._security_release_cooldown_secs,
            )
            resolved_extra = tuple(sec_cfg["extra_repos"])  # type: ignore[arg-type]
        else:
            resolved_extra = parse_repo_list(extra_repos, default=())

        combined: list[str] = []
        for candidate in (*cached_sources, *resolved_extra):
            norm = _normalize_valid_haberdasher_repo(candidate)
            if norm and norm not in combined:
                combined.append(norm)
        return tuple(combined)

    def _evaluate_security_patch_releases(
        self,
        *,
        open_prs_by_key: dict[str, dict],
        poll_result: dict,
        current_ms: int,
        linear_breaker: _LinearWriteCircuitBreaker | None = None,
    ) -> list[dict]:
        """Watch pending security release tags on every poll and evaluate eligible repos hourly."""
        if (
            self.linear_client is None
            or self.state_store.agent_name not in SWEEP_AGENT_ORDER
            or poll_result.get("status") in (403, 429)
        ):
            return []

        breaker = linear_breaker if linear_breaker is not None else _LinearWriteCircuitBreaker()
        if breaker.skip_if_tripped(scope="security-patch-release"):
            return []

        state = self.state_store.read_state()
        sec_state = dict(state.get("security_releases") or self.state_store._default_security_releases())
        last_checked = dict(_as_dict(sec_state.get("last_checked_at_ms")))
        notified = dict(_as_dict(sec_state.get("notified_releases")))
        pending_releases = dict(_as_dict(sec_state.get("pending_releases")))
        completed_releases = dict(_as_dict(sec_state.get("completed_releases")))
        state_dirty = False
        actions: list[dict] = []
        phase_a_handled_repos: set[str] = set()

        # Phase A: Watch pending pushed release tags on every poll (not throttled by the 1h interval).
        progress_fetcher = getattr(self.gh_client, "fetch_tag_release_progress", None)
        if callable(progress_fetcher) and pending_releases:
            for repo, raw_entry in list(pending_releases.items()):
                if not isinstance(raw_entry, dict):
                    continue
                if compute_repo_owner(repo) != self.state_store.agent_name:
                    continue
                tag = str(raw_entry.get("tag") or "").strip()
                head_oid = str(raw_entry.get("head_oid") or "").strip()
                linear_issue_id = str(raw_entry.get("linear_issue_id") or "").strip()
                linear_issue_url = str(raw_entry.get("linear_issue_url") or "").strip()
                release_kind = str(raw_entry.get("release_kind") or "patch").strip() or "patch"
                if not tag:
                    continue
                try:
                    progress = progress_fetcher(repo, tag)
                except Exception as exc:
                    sys.stderr.write(
                        f"moltis-github-companion security-release-watch warning ({repo} {tag}): {exc}\n"
                    )
                    continue
                if not isinstance(progress, dict):
                    continue

                if progress.get("any_failed"):
                    failed_run_url = str(
                        progress.get("failed_run_url") or progress.get("latest_run_url") or ""
                    ).strip()
                    if linear_issue_id:
                        if breaker.skip_if_tripped(scope="security-patch-release"):
                            continue
                        try:
                            self.linear_client.update_issue(
                                linear_issue_id,
                                state="Backlog",
                                add_labels=("needs-decision",),
                            )
                            breaker.record_success()
                        except Exception as exc:
                            if breaker.record_error(exc, scope="security-patch-release", item_key=repo):
                                break
                            sys.stderr.write(
                                f"moltis-github-companion security-release-watch linear warning ({repo} {tag}): {exc}\n"
                            )
                            continue
                        if callable(getattr(self.linear_client, "post_comment", None)) and not breaker.skip_if_tripped(
                            scope="security-patch-release"
                        ):
                            comment_body = (
                                f"Release workflow for tag `{tag}` failed: {failed_run_url}"
                                if failed_run_url
                                else f"Release workflow for tag `{tag}` failed."
                            )
                            try:
                                self.linear_client.post_comment(linear_issue_id, comment_body)
                                breaker.record_success()
                            except Exception as exc:
                                breaker.record_error(exc, scope="security-patch-release", item_key=repo)
                                sys.stderr.write(
                                    f"moltis-github-companion security-release-watch comment warning ({repo} {tag}): {exc}\n"
                                )
                    alert_target = failed_run_url or linear_issue_url
                    alert_msg = (
                        f"🚨 {repo} {tag} release workflow failed ({alert_target})"
                        if alert_target
                        else f"🚨 {repo} {tag} release workflow failed"
                    )
                    telegram_sent = False
                    if not self.read_only_trial and self.telegram_client is not None:
                        try:
                            self.telegram_client.send_message(alert_msg)
                            telegram_sent = True
                        except Exception as exc:
                            sys.stderr.write(
                                f"moltis-github-companion security-release-watch telegram warning ({repo} {tag}): {exc}\n"
                            )
                    pending_releases.pop(repo, None)
                    if repo in notified and isinstance(notified[repo], dict):
                        notified[repo] = {
                            **notified[repo],
                            "pending": True,
                            "auto_tag_attempted": True,
                            "auto_tag_status": "workflow_failed",
                        }
                    phase_a_handled_repos.add(repo)
                    state_dirty = True
                    actions.append({
                        "action": "security_release_failed",
                        "repo": repo,
                        "tag": tag,
                        "next_tag": tag,
                        "head_oid": head_oid,
                        "release_kind": release_kind,
                        "linear_issue_id": linear_issue_id,
                        "linear_url": linear_issue_url,
                        "failed_run_url": failed_run_url or None,
                        "telegram_sent": telegram_sent,
                        "telegram_message": alert_msg,
                    })
                elif (
                    progress.get("release_published")
                    and not progress.get("any_in_progress")
                    and (progress.get("all_succeeded") or _safe_int(progress.get("total_runs"), 0) == 0)
                ):
                    release_url = str(
                        progress.get("release_url") or f"https://github.com/{repo}/releases/tag/{tag}"
                    ).strip()
                    if linear_issue_id:
                        if breaker.skip_if_tripped(scope="security-patch-release"):
                            continue
                        try:
                            self.linear_client.update_issue(
                                linear_issue_id,
                                state="Done",
                                remove_labels=("needs-decision",),
                            )
                            breaker.record_success()
                        except Exception as exc:
                            if breaker.record_error(exc, scope="security-patch-release", item_key=repo):
                                break
                            sys.stderr.write(
                                f"moltis-github-companion security-release-watch linear warning ({repo} {tag}): {exc}\n"
                            )
                            continue
                        if callable(getattr(self.linear_client, "post_comment", None)) and not breaker.skip_if_tripped(
                            scope="security-patch-release"
                        ):
                            try:
                                self.linear_client.post_comment(
                                    linear_issue_id,
                                    f"Published release `{tag}`: {release_url}",
                                )
                                breaker.record_success()
                            except Exception as exc:
                                breaker.record_error(exc, scope="security-patch-release", item_key=repo)
                                sys.stderr.write(
                                    f"moltis-github-companion security-release-watch comment warning ({repo} {tag}): {exc}\n"
                                )
                    notice_msg = f"🚀 {repo} {tag} released ({release_url})"
                    telegram_sent = False
                    if not self.read_only_trial and self.telegram_client is not None:
                        try:
                            self.telegram_client.send_message(notice_msg)
                            telegram_sent = True
                        except Exception as exc:
                            sys.stderr.write(
                                f"moltis-github-companion security-release-watch telegram warning ({repo} {tag}): {exc}\n"
                            )
                    pending_releases.pop(repo, None)
                    completed_releases[repo] = tag
                    if repo in notified and isinstance(notified[repo], dict):
                        notified[repo] = {**notified[repo], "pending": False}
                    phase_a_handled_repos.add(repo)
                    state_dirty = True
                    actions.append({
                        "action": "security_release_completed",
                        "repo": repo,
                        "tag": tag,
                        "next_tag": tag,
                        "head_oid": head_oid,
                        "release_kind": release_kind,
                        "linear_issue_id": linear_issue_id,
                        "linear_url": linear_issue_url,
                        "release_url": release_url,
                        "telegram_sent": telegram_sent,
                        "telegram_message": notice_msg,
                    })

        # Phase B: Evaluate ready repositories on the hourly schedule.
        if (
            poll_result.get("open_prs_poll_error") is None
            and hasattr(self.gh_client, "fetch_repo_security_release_status")
            and hasattr(self.linear_client, "ensure_release_task")
            and not breaker.skip_if_tripped(scope="security-patch-release")
        ):
            sec_cfg = resolve_security_release_config(
                extra_repos=self._security_release_extra_repos,
                cooldown_secs=self._security_release_cooldown_secs,
            )
            candidate_repos = self._resolve_security_release_repos(
                current_ms=current_ms,
                extra_repos=sec_cfg["extra_repos"],  # type: ignore[arg-type]
            )
            refreshed_sec_state = _as_dict(self.state_store.read_state().get("security_releases"))
            haberdasher_set = {
                norm
                for entry in (refreshed_sec_state.get("haberdasher_sources") or [])
                if (norm := _normalize_valid_haberdasher_repo(entry)) is not None
            }
            owned_repos = [
                repo
                for repo in candidate_repos
                if is_allowed_notification_repo(repo) and compute_repo_owner(repo) == self.state_store.agent_name
            ]
            cooldown_ms = _safe_int(sec_cfg["cooldown_secs"], DEFAULT_SECURITY_PATCH_RELEASE_COOLDOWN_SECS) * 1000
            can_auto_tag = callable(getattr(self.gh_client, "create_security_release_tag", None))

            for repo in owned_repos:
                if repo in pending_releases or repo in phase_a_handled_repos:
                    continue
                prev_checked_ms = _safe_int(last_checked.get(repo), 0)
                if prev_checked_ms > 0 and (current_ms - prev_checked_ms) < SECURITY_RELEASE_CHECK_INTERVAL_MS:
                    continue

                status = self.gh_client.fetch_repo_security_release_status(repo)
                last_checked[repo] = current_ms
                state_dirty = True
                if not isinstance(status, dict):
                    continue

                # Gate 1: not archived, valid stable semver latest_tag, head moved past tag
                if status.get("is_archived") or status.get("latest_is_draft") or status.get("latest_is_prerelease"):
                    continue
                latest_tag = str(status.get("latest_tag") or "").strip()
                latest_tag_oid = str(status.get("latest_tag_oid") or "").strip()
                head_oid = str(status.get("head_oid") or "").strip()
                if parse_semver_tag(latest_tag) is None or not head_oid:
                    continue
                if head_oid == latest_tag_oid:
                    if repo in notified and isinstance(notified[repo], dict) and notified[repo].get("pending", True):
                        notified[repo] = {**notified[repo], "pending": False}
                        state_dirty = True
                    continue

                # Gate 2: zero open security PRs for this repo
                has_open_security_pr = any(
                    isinstance(live_pr, dict)
                    and str(live_pr.get("repo") or "").strip().lower() == repo
                    and str(live_pr.get("state") or "OPEN").upper() == "OPEN"
                    and is_security_merged_pr(live_pr)
                    for live_pr in (open_prs_by_key or {}).values()
                )
                if has_open_security_pr:
                    continue

                # Gate 3: at least one security PR merged since latest release and cooldown elapsed
                merged_security_prs = [
                    pr
                    for pr in (status.get("merged_prs_since_tag") or ())
                    if isinstance(pr, dict) and is_security_merged_pr(pr)
                ]
                if not merged_security_prs:
                    if repo in notified and isinstance(notified[repo], dict) and notified[repo].get("pending", True):
                        notified[repo] = {**notified[repo], "pending": False}
                        state_dirty = True
                    continue
                latest_security_merge_ms = max(
                    (_safe_int(pr.get("merged_at_ms"), 0) or normalize_ts(pr.get("mergedAt") or pr.get("merged_at"))[1])
                    for pr in merged_security_prs
                )
                if latest_security_merge_ms <= 0 or (current_ms - latest_security_merge_ms) < cooldown_ms:
                    continue

                # Gate 4: default-branch CI on head_oid is green or empty
                ci_state = normalize_ci_state(status.get("ci_state"))
                if ci_state not in ("SUCCESS", "NONE"):
                    continue

                commit_subjects = [
                    str(c.get("messageHeadline") or c.get("subject") or "").strip()
                    for c in (status.get("commits_since_tag") or ())
                    if isinstance(c, dict)
                ]
                classified = classify_unreleased_commits(commit_subjects)
                breaking_commits = classified["breaking"]
                feature_commits = classified["features"]
                non_patch_commits = classified["non_patch"]
                has_breaking_commits = bool(breaking_commits)
                has_feature_commits = bool(feature_commits)
                has_non_patch_commits = bool(non_patch_commits)
                default_branch = str(status.get("default_branch") or "main").strip() or "main"

                if has_breaking_commits:
                    next_tag = bump_semver_minor(latest_tag) if has_feature_commits else bump_semver_patch(latest_tag)
                    release_kind = "breaking_hold"
                elif has_feature_commits:
                    next_tag = bump_semver_minor(latest_tag)
                    release_kind = "minor"
                else:
                    next_tag = bump_semver_patch(latest_tag)
                    release_kind = "patch"
                if not next_tag:
                    continue

                is_haberdasher_auto = (not has_breaking_commits) and (repo in haberdasher_set) and can_auto_tag

                # Deduplicate per (repo, latest_tag, head_oid), allowing untagged legacy or manual entries
                # to upgrade once automatic Haberdasher tagging becomes available.
                dedup_key = f"{repo}:{latest_tag}:{head_oid}"
                prev_notified = _as_dict(notified.get(repo))
                if prev_notified.get("dedup_key") == dedup_key:
                    prev_auto_attempted = bool(prev_notified.get("auto_tag_attempted"))
                    prev_auto_status = str(prev_notified.get("auto_tag_status") or "").strip().lower()
                    already_handled_auto = (
                        prev_auto_attempted
                        or prev_auto_status in ("tagged", "failed", "workflow_failed")
                        or (
                            prev_notified.get("pending") is False
                            and str(prev_notified.get("next_tag") or "").strip() == next_tag
                        )
                    )
                    if not (is_haberdasher_auto and not already_handled_auto):
                        continue

                pr_lines = []
                for pr in merged_security_prs:
                    pr_num = _safe_int(pr.get("number"), 0)
                    pr_title = " ".join(str(pr.get("title") or "").splitlines()).strip()
                    pr_url = str(pr.get("url") or "").strip()
                    ref_label = f"#{pr_num}" if pr_num > 0 else "PR"
                    pr_lines.append(f"- {ref_label}: {pr_title} ({pr_url})" if pr_url else f"- {ref_label}: {pr_title}")

                if has_breaking_commits:
                    branch_status_lines = [
                        f"Blocked: `{default_branch}` contains unreleased breaking commits since `{latest_tag}`:",
                        *(f"- {subj}" for subj in breaking_commits[:10]),
                    ]
                    if feature_commits:
                        branch_status_lines.extend([
                            "Additional unreleased feature commits:",
                            *(f"- {subj}" for subj in feature_commits[:10]),
                        ])
                elif has_feature_commits:
                    branch_status_lines = [
                        f"`{default_branch}` contains unreleased feature commits since `{latest_tag}`; cutting minor release `{next_tag}`:",
                        *(f"- {subj}" for subj in feature_commits[:10]),
                    ]
                else:
                    branch_status_lines = [
                        f"Clean `{default_branch}`: all unreleased commits since `{latest_tag}` are patch-safe.",
                    ]

                notes_lines = [f"- {subj}" for subj in commit_subjects[:15] if subj] or pr_lines
                release_cmd = f'git tag -a {next_tag} {head_oid} -m "Release {next_tag}" && git push origin {next_tag}'

                if has_breaking_commits:
                    title = f"Release {repo} {next_tag} (security release blocked by breaking commits)"
                    summary_line = (
                        f"Security release `{latest_tag}` -> `{next_tag}` on `{default_branch}` (`{head_oid}`) "
                        "is held due to unreleased breaking commits."
                    )
                    target_state = "Backlog"
                elif release_kind == "minor":
                    title = f"Release {repo} {next_tag} (security minor release)"
                    summary_line = (
                        f"Security minor release `{latest_tag}` -> `{next_tag}` on `{default_branch}` (`{head_oid}`)."
                    )
                    target_state = "In Progress" if is_haberdasher_auto else "Backlog"
                else:
                    title = f"Release {repo} {next_tag} (security patch)"
                    summary_line = (
                        f"Prepared security-patch release `{latest_tag}` -> `{next_tag}` on `{default_branch}` (`{head_oid}`)."
                    )
                    target_state = "In Progress" if is_haberdasher_auto else "Backlog"

                description = "\n".join([
                    summary_line,
                    "",
                    "## Merged security pull requests",
                    *pr_lines,
                    "",
                    "## Branch cleanliness",
                    *branch_status_lines,
                    "",
                    "## Draft release notes",
                    *notes_lines,
                    "",
                    "## Manual fallback tag command",
                    "```sh",
                    release_cmd,
                    "```",
                ])

                if breaker.skip_if_tripped(scope="security-patch-release"):
                    break
                try:
                    linear_issue, created = self.linear_client.ensure_release_task(
                        repo=repo,
                        next_tag=next_tag,
                        title=title,
                        description=description,
                        state=target_state,
                    )
                except Exception as exc:
                    if breaker.record_error(exc, scope="security-patch-release", item_key=repo):
                        break
                    sys.stderr.write(f"moltis-github-companion security-patch-release warning ({repo}): {exc}\n")
                    continue
                breaker.record_success()

                linear_id = str(linear_issue.get("id") or "").strip()
                linear_identifier = str(linear_issue.get("identifier") or "").strip() or None
                linear_url = str(linear_issue.get("url") or "").strip()

                if has_breaking_commits:
                    if (
                        linear_id
                        and not is_ignored_linear_issue_state(linear_issue)
                        and callable(getattr(self.linear_client, "update_issue", None))
                        and not breaker.skip_if_tripped(scope="security-patch-release")
                    ):
                        try:
                            self.linear_client.update_issue(
                                linear_id,
                                state="Backlog",
                                add_labels=("needs-decision",),
                            )
                            breaker.record_success()
                        except Exception as exc:
                            if breaker.record_error(exc, scope="security-patch-release", item_key=repo):
                                break
                            sys.stderr.write(
                                f"moltis-github-companion security-patch-release label warning ({repo}): {exc}\n"
                            )
                    ping_msg = f"📦 {repo}: security release blocked by breaking commits ({linear_url})"
                    telegram_sent = False
                    if not self.read_only_trial and self.telegram_client is not None:
                        try:
                            self.telegram_client.send_message(ping_msg)
                            telegram_sent = True
                        except Exception as exc:
                            sys.stderr.write(
                                f"moltis-github-companion security-patch-release telegram warning ({repo}): {exc}\n"
                            )
                    notified[repo] = {
                        "dedup_key": dedup_key,
                        "repo": repo,
                        "current_tag": latest_tag,
                        "next_tag": next_tag,
                        "head_oid": head_oid,
                        "release_kind": release_kind,
                        "linear_issue_id": linear_id,
                        "linear_issue_identifier": linear_identifier,
                        "linear_url": linear_url,
                        "has_breaking_commits": True,
                        "breaking_commits": breaking_commits,
                        "has_feature_commits": has_feature_commits,
                        "feature_commits": feature_commits,
                        "has_non_patch_commits": has_non_patch_commits,
                        "non_patch_commits": non_patch_commits,
                        "auto_tag_attempted": False,
                        "auto_tag_status": "held",
                        "pending": True,
                        "notified_at_ms": current_ms,
                    }
                    state_dirty = True
                    actions.append({
                        "action": "security_release_held",
                        "repo": repo,
                        "current_tag": latest_tag,
                        "next_tag": next_tag,
                        "head_oid": head_oid,
                        "release_kind": release_kind,
                        "created": created,
                        "linear_issue_id": linear_id,
                        "linear_issue_identifier": linear_identifier,
                        "linear_url": linear_url,
                        "has_breaking_commits": True,
                        "breaking_commits": breaking_commits,
                        "has_feature_commits": has_feature_commits,
                        "feature_commits": feature_commits,
                        "has_non_patch_commits": has_non_patch_commits,
                        "non_patch_commits": non_patch_commits,
                        "release_command": release_cmd,
                        "telegram_sent": telegram_sent,
                        "telegram_message": ping_msg,
                    })
                elif is_haberdasher_auto:
                    if (
                        not created
                        and linear_id
                        and not is_ignored_linear_issue_state(linear_issue)
                        and callable(getattr(self.linear_client, "update_issue", None))
                        and str(_as_dict(linear_issue.get("state")).get("name") or "").strip().lower() != "in progress"
                        and not breaker.skip_if_tripped(scope="security-patch-release")
                    ):
                        try:
                            self.linear_client.update_issue(linear_id, state="In Progress")
                            breaker.record_success()
                        except Exception as exc:
                            breaker.record_error(exc, scope="security-patch-release", item_key=repo)
                            sys.stderr.write(
                                f"moltis-github-companion security-patch-release state warning ({repo}): {exc}\n"
                            )
                    try:
                        self.gh_client.create_security_release_tag(repo, next_tag, head_oid)
                    except Exception as exc:
                        tag_err = _sanitize_health_reason(exc, max_len=240) or str(exc)
                        if (
                            linear_id
                            and not is_ignored_linear_issue_state(linear_issue)
                            and callable(getattr(self.linear_client, "update_issue", None))
                            and not breaker.skip_if_tripped(scope="security-patch-release")
                        ):
                            try:
                                self.linear_client.update_issue(
                                    linear_id,
                                    state="Backlog",
                                    add_labels=("needs-decision",),
                                )
                                breaker.record_success()
                            except Exception as lin_exc:
                                breaker.record_error(lin_exc, scope="security-patch-release", item_key=repo)
                                sys.stderr.write(
                                    f"moltis-github-companion security-release-tag linear warning ({repo} {next_tag}): {lin_exc}\n"
                                )
                        if (
                            linear_id
                            and callable(getattr(self.linear_client, "post_comment", None))
                            and not breaker.skip_if_tripped(scope="security-patch-release")
                        ):
                            try:
                                self.linear_client.post_comment(
                                    linear_id,
                                    f"Failed to push release tag `{next_tag}` at `{head_oid[:12]}`: {tag_err}",
                                )
                                breaker.record_success()
                            except Exception as cmt_exc:
                                breaker.record_error(cmt_exc, scope="security-patch-release", item_key=repo)
                                sys.stderr.write(
                                    f"moltis-github-companion security-release-tag comment warning ({repo} {next_tag}): {cmt_exc}\n"
                                )
                        alert_msg = f"🚨 {repo}: failed to tag {next_tag} ({linear_url})"
                        telegram_sent = False
                        if not self.read_only_trial and self.telegram_client is not None:
                            try:
                                self.telegram_client.send_message(alert_msg)
                                telegram_sent = True
                            except Exception as tg_exc:
                                sys.stderr.write(
                                    f"moltis-github-companion security-release-tag telegram warning ({repo} {next_tag}): {tg_exc}\n"
                                )
                        notified[repo] = {
                            "dedup_key": dedup_key,
                            "repo": repo,
                            "current_tag": latest_tag,
                            "next_tag": next_tag,
                            "head_oid": head_oid,
                            "release_kind": release_kind,
                            "linear_issue_id": linear_id,
                            "linear_issue_identifier": linear_identifier,
                            "linear_url": linear_url,
                            "has_breaking_commits": False,
                            "breaking_commits": [],
                            "has_feature_commits": has_feature_commits,
                            "feature_commits": feature_commits,
                            "has_non_patch_commits": has_non_patch_commits,
                            "non_patch_commits": non_patch_commits,
                            "auto_tag_attempted": True,
                            "auto_tag_status": "failed",
                            "pending": True,
                            "notified_at_ms": current_ms,
                        }
                        state_dirty = True
                        actions.append({
                            "action": "security_release_tag_failed",
                            "repo": repo,
                            "current_tag": latest_tag,
                            "next_tag": next_tag,
                            "head_oid": head_oid,
                            "release_kind": release_kind,
                            "created": created,
                            "linear_issue_id": linear_id,
                            "linear_issue_identifier": linear_identifier,
                            "linear_url": linear_url,
                            "error": tag_err,
                            "release_command": release_cmd,
                            "telegram_sent": telegram_sent,
                            "telegram_message": alert_msg,
                        })
                        continue

                    pending_releases[repo] = {
                        "tag": next_tag,
                        "head_oid": head_oid,
                        "linear_issue_id": linear_id,
                        "linear_issue_url": linear_url,
                        "pushed_at_ms": current_ms,
                        "release_kind": release_kind,
                    }
                    if (
                        linear_id
                        and callable(getattr(self.linear_client, "post_comment", None))
                        and not breaker.skip_if_tripped(scope="security-patch-release")
                    ):
                        try:
                            self.linear_client.post_comment(
                                linear_id,
                                f"Pushed release tag {next_tag} at {head_oid[:12]}; watching GoReleaser workflow.",
                            )
                            breaker.record_success()
                        except Exception as cmt_exc:
                            breaker.record_error(cmt_exc, scope="security-patch-release", item_key=repo)
                            sys.stderr.write(
                                f"moltis-github-companion security-release-tag comment warning ({repo} {next_tag}): {cmt_exc}\n"
                            )
                    ping_msg = f"🏷️ {repo}: tagged {next_tag} for security release ({linear_url})"
                    telegram_sent = False
                    if not self.read_only_trial and self.telegram_client is not None:
                        try:
                            self.telegram_client.send_message(ping_msg)
                            telegram_sent = True
                        except Exception as exc:
                            sys.stderr.write(
                                f"moltis-github-companion security-release-tag telegram warning ({repo} {next_tag}): {exc}\n"
                            )
                    prev_linear_id = str(prev_notified.get("linear_issue_id") or "").strip()
                    if (
                        prev_notified.get("dedup_key") == dedup_key
                        and prev_linear_id
                        and prev_linear_id != linear_id
                        and callable(getattr(self.linear_client, "update_issue", None))
                        and not breaker.skip_if_tripped(scope="security-patch-release")
                    ):
                        try:
                            self.linear_client.update_issue(prev_linear_id, state="Canceled")
                            breaker.record_success()
                        except Exception as sup_exc:
                            breaker.record_error(sup_exc, scope="security-patch-release", item_key=repo)
                            sys.stderr.write(
                                f"moltis-github-companion security-release-supersede warning ({repo} {prev_linear_id}): {sup_exc}\n"
                            )
                        if callable(getattr(self.linear_client, "post_comment", None)) and not breaker.skip_if_tripped(
                            scope="security-patch-release"
                        ):
                            sup_body = (
                                f"Superseded by automated security release `{next_tag}` ({linear_url})."
                                if linear_url
                                else f"Superseded by automated security release `{next_tag}`."
                            )
                            try:
                                self.linear_client.post_comment(prev_linear_id, sup_body)
                                breaker.record_success()
                            except Exception as sup_cmt_exc:
                                breaker.record_error(sup_cmt_exc, scope="security-patch-release", item_key=repo)
                                sys.stderr.write(
                                    f"moltis-github-companion security-release-supersede-comment warning ({repo} {prev_linear_id}): {sup_cmt_exc}\n"
                                )
                    notified[repo] = {
                        "dedup_key": dedup_key,
                        "repo": repo,
                        "current_tag": latest_tag,
                        "next_tag": next_tag,
                        "head_oid": head_oid,
                        "release_kind": release_kind,
                        "linear_issue_id": linear_id,
                        "linear_issue_identifier": linear_identifier,
                        "linear_url": linear_url,
                        "has_breaking_commits": False,
                        "breaking_commits": [],
                        "has_feature_commits": has_feature_commits,
                        "feature_commits": feature_commits,
                        "has_non_patch_commits": has_non_patch_commits,
                        "non_patch_commits": non_patch_commits,
                        "auto_tag_attempted": True,
                        "auto_tag_status": "tagged",
                        "pending": False,
                        "notified_at_ms": current_ms,
                    }
                    state_dirty = True
                    actions.append({
                        "action": "security_release_tagged",
                        "repo": repo,
                        "current_tag": latest_tag,
                        "next_tag": next_tag,
                        "head_oid": head_oid,
                        "release_kind": release_kind,
                        "created": created,
                        "linear_issue_id": linear_id,
                        "linear_issue_identifier": linear_identifier,
                        "linear_url": linear_url,
                        "has_breaking_commits": False,
                        "breaking_commits": [],
                        "has_feature_commits": has_feature_commits,
                        "feature_commits": feature_commits,
                        "has_non_patch_commits": has_non_patch_commits,
                        "non_patch_commits": non_patch_commits,
                        "release_command": release_cmd,
                        "telegram_sent": telegram_sent,
                        "telegram_message": ping_msg,
                    })
                else:
                    ping_msg = f"📦 {repo}: security {release_kind} {next_tag} ready ({linear_url})"
                    if has_non_patch_commits:
                        ping_msg += " ⚠️ unreleased feat/breaking commits on main"
                    telegram_sent = False
                    if not self.read_only_trial and self.telegram_client is not None:
                        try:
                            self.telegram_client.send_message(ping_msg)
                            telegram_sent = True
                        except Exception as exc:
                            sys.stderr.write(
                                f"moltis-github-companion security-patch-release telegram warning ({repo}): {exc}\n"
                            )
                    notified[repo] = {
                        "dedup_key": dedup_key,
                        "repo": repo,
                        "current_tag": latest_tag,
                        "next_tag": next_tag,
                        "head_oid": head_oid,
                        "release_kind": release_kind,
                        "linear_issue_id": linear_id,
                        "linear_issue_identifier": linear_identifier,
                        "linear_url": linear_url,
                        "has_breaking_commits": False,
                        "breaking_commits": [],
                        "has_feature_commits": has_feature_commits,
                        "feature_commits": feature_commits,
                        "has_non_patch_commits": has_non_patch_commits,
                        "non_patch_commits": non_patch_commits,
                        "auto_tag_attempted": False,
                        "auto_tag_status": "prepared",
                        "pending": True,
                        "notified_at_ms": current_ms,
                    }
                    state_dirty = True
                    actions.append({
                        "action": "security_release_prepared",
                        "repo": repo,
                        "current_tag": latest_tag,
                        "next_tag": next_tag,
                        "head_oid": head_oid,
                        "release_kind": release_kind,
                        "created": created,
                        "linear_issue_id": linear_id,
                        "linear_issue_identifier": linear_identifier,
                        "linear_url": linear_url,
                        "has_breaking_commits": False,
                        "breaking_commits": [],
                        "has_feature_commits": has_feature_commits,
                        "feature_commits": feature_commits,
                        "has_non_patch_commits": has_non_patch_commits,
                        "non_patch_commits": non_patch_commits,
                        "release_command": release_cmd,
                        "telegram_sent": telegram_sent,
                        "telegram_message": ping_msg,
                    })

        if state_dirty:
            self.state_store.write_state(
                {
                    "security_releases": {
                        "last_checked_at_ms": last_checked,
                        "notified_releases": notified,
                        "pending_releases": pending_releases,
                        "completed_releases": completed_releases,
                    }
                },
                now_override_ms=current_ms,
            )

        return actions

    def run_cycle(self, *, run_sweeps_if_due: bool = True, now_override_ms: int | None = None) -> dict:
        if self.matrix_client is not None:
            with contextlib.suppress(Exception):
                self.matrix_client.flush_outbox()

        poll_result = self.poller.poll_once(now_override_ms=now_override_ms)
        dismissed_threads: list[str] = list(poll_result.get("dismissed_threads") or [])
        if self.read_only_trial:
            return {"status": "ok", "recovery": {"status": "read_only_trial", "can_dispatch": False}, "poll_result": poll_result, "targeted_dispatches": [], "dismissed_threads": dismissed_threads, "sweep_dispatch": None, "linear_triage_stubs": [], "linear_promoted_todos": [], "linear_synced_closed": [], "signoff_notifications": [], "linear_pr_actions": [], "merge_conflict_actions": [], "in_review_pr_actions": [], "stale_issue_actions": [], "needs_decision_notifications": [], "traya_blind_reviews": [], "linear_todo_reconciliations": [], "linear_operator_comment_dispatches": [], "health_alerts": [], "operator_digest": None, "linked_pr_issue_relations": [], "security_release_actions": []}
        if self._is_coordinator_busy():
            return {"status": "turn_in_progress", "recovery": {"status": "busy", "can_dispatch": False}, "poll_result": poll_result, "targeted_dispatches": [], "dismissed_threads": dismissed_threads, "sweep_dispatch": None, "linear_triage_stubs": [], "linear_promoted_todos": [], "linear_synced_closed": [], "signoff_notifications": [], "linear_pr_actions": [], "merge_conflict_actions": [], "in_review_pr_actions": [], "stale_issue_actions": [], "needs_decision_notifications": [], "traya_blind_reviews": [], "linear_todo_reconciliations": [], "linear_operator_comment_dispatches": [], "health_alerts": [], "operator_digest": None, "linked_pr_issue_relations": [], "security_release_actions": []}

        recovery = self.execution_coordinator.recover_active_dispatch(now_override_ms=now_override_ms)
        if not recovery.get("can_dispatch", True):
            return {
                "status": str(recovery.get("status") or "recovery_deferred"),
                "recovery": recovery,
                "poll_result": poll_result,
                "targeted_dispatches": [],
                "dismissed_threads": dismissed_threads,
                "sweep_dispatch": None,
                "linear_triage_stubs": [],
                "linear_promoted_todos": [],
                "linear_synced_closed": [],
                "signoff_notifications": [],
                "linear_pr_actions": [],
                "merge_conflict_actions": [],
                "in_review_pr_actions": [],
                "stale_issue_actions": [],
                "needs_decision_notifications": [],
                "traya_blind_reviews": [],
                "linear_todo_reconciliations": [],
                "linear_operator_comment_dispatches": [],
                "health_alerts": [],
                "operator_digest": None,
                "linked_pr_issue_relations": [],
                "security_release_actions": [],
            }
        current_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        slot_id = compute_throttle_slot_id(
            current_ms,
            self.state_store.agent_name,
            poll_interval_minutes=self.poll_interval_minutes,
        )
        targeted_dispatches: list[dict] = []
        dispatched_targets: set[str] = set()
        threads = _as_dict(self.state_store.read_state().get("threads"))

        def _complete_skipped(key_val: str, tid_val: str | None, prep_res: dict, entry_val: dict) -> None:
            if prep_res.get("skip_reason") == "subject_fetch_failed":
                self.state_store.update_thread_state(key_val, {"pending_followup": True}, now_override_ms=now_override_ms)
                return
            if prep_res.get("skip_reason") in ("closed_or_draft_pr", "archived_repo", "bot_update_ignored_for_traya", "unowned_automated_pr") and tid_val and tid_val.isdigit():
                try:
                    self.gh_client.dismiss_notification(tid_val)
                    if tid_val not in dismissed_threads:
                        dismissed_threads.append(tid_val)
                except Exception as exc:
                    sys.stderr.write(f"moltis-github-companion dismiss warning ({self.execution_coordinator.agent_name} thread {tid_val}): {exc}\n")
                    return
            self.state_store.complete_thread_review(key_val, handled_updated_at=entry_val.get("updated_at"), handled_head_sha=prep_res.get("head_sha") or entry_val.get("head_sha"), handled_ci_state=entry_val.get("ci_state"), preserve_handled_head_sha=prep_res.get("skip_reason") in ("untrusted_actor", "coercion_pattern"), apply_cooldown=False, now_override_ms=now_override_ms)

        # Deterministic zero-LLM housekeeping before LLM dispatches.
        for coercive in poll_result.get("coercive_items") or []:
            if not isinstance(coercive, dict):
                continue
            c_repo = str(coercive.get("repo") or "").strip()
            c_num = _safe_int(coercive.get("number"), 0) or None
            if not c_repo or c_num is None:
                continue
            self.trust_filter._record_security_event_and_alert(
                repo=c_repo,
                subject_type=str(coercive.get("subject_type") or "PullRequest"),
                number=c_num,
                thread_id=str(coercive.get("thread_id") or coercive.get("key") or make_pr_key(c_repo, c_num)),
                item_kind=str(coercive.get("item_kind") or ("pull_request" if str(coercive.get("subject_type") or "").lower().startswith("pull") else "issue")),
                item_id=coercive.get("item_id") or c_num,
                actor=str(coercive.get("actor") or "unknown"),
                raw_texts=[str(t) for t in (coercive.get("raw_texts") or []) if isinstance(t, str) and t],
                stamp_ms=current_ms,
            )

        signoff_notifications = self._send_do_not_merge_signoff_pings(
            poll_result.get("signoff_ready_prs") or [],
            current_ms=current_ms,
        )

        linear_breaker = _LinearWriteCircuitBreaker()
        linear_promoted_todos: list[dict] = []
        verified_team_label_dispatches: list[dict] = []
        for cand in poll_result.get("team_label_candidates") or []:
            if not isinstance(cand, dict):
                continue
            cand_key = str(cand.get("key") or "").strip()
            cand_repo = str(cand.get("repo") or "").strip()
            cand_num = _safe_int(cand.get("number"), 0) or None
            cand_labels = [str(lbl) for lbl in (cand.get("team_labels") or []) if str(lbl) in TEAM_LABELS]
            if not cand_key or not cand_repo or cand_num is None or not cand_labels:
                continue
            cand_entry = _as_dict(self.state_store.get_thread_state(cand_key))
            if _safe_int(cand_entry.get("retry_count"), 0) >= MAX_THREAD_FAILURE_RETRIES:
                continue
            use_timeline = "team:merge" in cand_labels
            try:
                events = (
                    self.gh_client.fetch_issue_timeline(cand_repo, cand_num)
                    if use_timeline
                    else self.gh_client.fetch_issue_events(cand_repo, cand_num)
                )
            except Exception as exc:
                sys.stderr.write(f"moltis-github-companion label-events warning ({cand_key}): {exc}\n")
                continue
            handled_team_labels = dict(_as_dict(cand_entry.get("handled_team_labels")))
            verified_label: str | None = None
            verified_event_key: str | None = None
            for lbl in cand_labels:
                ver = verify_team_label_from_events(events, lbl)
                if ver is None:
                    continue
                ev_key = str(ver.get("event_key") or f"{lbl}:{ver.get('event_id') or ver.get('created_at') or cand.get('updated_at') or ''}").strip()
                if ev_key and handled_team_labels.get(lbl.lower()) == ev_key:
                    continue
                verified_label = lbl
                verified_event_key = ev_key
                break
            if not verified_label:
                continue
            cand_kind = str(cand.get("kind") or cand.get("subject_type") or "PullRequest")
            if self.linear_client is not None and verified_label == "team:implement" and cand_kind.strip().lower() == "issue":
                promoted = self._promote_team_implement_issue_to_linear(
                    cand=cand,
                    cand_key=cand_key,
                    verified_event_key=verified_event_key,
                    current_ms=current_ms,
                    linear_breaker=linear_breaker,
                )
                if promoted is not None:
                    linear_promoted_todos.append(promoted)
                continue
            cand_head_sha = str(cand.get("head_sha") or "").strip() or None
            triaged_sha = str(cand.get("triaged_head_sha") or cand_entry.get("triaged_head_sha") or "").strip() or None
            if verified_label == "team:merge":
                timeline_ver = verify_team_merge_timeline(events, cand_head_sha)
                sha_changed = bool(
                    timeline_ver is None
                    or not cand_head_sha
                    or (triaged_sha and triaged_sha != cand_head_sha)
                )
            else:
                sha_changed = False
            verified_team_label_dispatches.append({
                "cand": cand,
                "cand_key": cand_key,
                "cand_repo": cand_repo,
                "cand_num": cand_num,
                "cand_kind": cand_kind,
                "verified_label": verified_label,
                "verified_event_key": verified_event_key,
                "cand_head_sha": cand_head_sha,
                "triaged_sha": triaged_sha,
                "sha_changed": sha_changed,
            })

        open_prs_by_key: dict[str, dict] = {}
        open_pr_by_closing_issue_key: dict[str, list[dict]] = {}
        for raw_open_pr in poll_result.get("open_pull_requests") or ():
            if not isinstance(raw_open_pr, dict):
                continue
            pk = str(raw_open_pr.get("pr_key") or "").strip().lower()
            r_name = str(raw_open_pr.get("repo") or "").strip()
            r_num = _safe_int(raw_open_pr.get("number"), 0)
            if not pk and r_name and r_num > 0:
                pk = make_pr_key(r_name, r_num)
            if pk:
                pr_copy = dict(raw_open_pr)
                if "closing_issues" not in pr_copy:
                    pr_copy["closing_issues"] = extract_pr_closing_issues(pr_copy, default_repo=r_name)
                open_prs_by_key[pk] = pr_copy
                if str(pr_copy.get("state") or "OPEN").upper() == "OPEN":
                    for ref in pr_copy.get("closing_issues") or ():
                        ik = str(ref.get("issue_key") or "").strip().lower()
                        if ik:
                            open_pr_by_closing_issue_key.setdefault(ik, []).append(pr_copy)

        hydrated_mergeability_node_ids: set[str] = set()
        if (
            self.linear_client is not None
            and poll_result.get("open_prs_poll_error") is None
            and hasattr(self.gh_client, "fetch_pull_request_mergeability")
        ):
            hydrate_by_node_id: dict[str, str] = {}
            for pk, live_pr in open_prs_by_key.items():
                if str(live_pr.get("state") or "OPEN").upper() != "OPEN":
                    continue
                if is_trusted_github_actor(live_pr.get("author")):
                    continue
                repo_h = str(live_pr.get("repo") or "").strip()
                num_h = _safe_int(live_pr.get("number"), 0)
                if not repo_h or num_h <= 0:
                    continue
                if self.state_store.agent_name in SWEEP_AGENT_ORDER and compute_pr_owner(repo_h, num_h) != self.state_store.agent_name:
                    continue
                if normalize_mergeable_state(live_pr.get("mergeable"), live_pr.get("merge_state_status") or live_pr.get("mergeStateStatus")) != "UNKNOWN":
                    continue
                nid = str(live_pr.get("node_id") or (live_pr.get("id") if isinstance(live_pr.get("id"), str) else "")).strip()
                if nid:
                    hydrate_by_node_id[nid] = pk
            if hydrate_by_node_id:
                hydrated_mergeability_node_ids.update(hydrate_by_node_id.keys())
                mergeability_map = self.gh_client.fetch_pull_request_mergeability(hydrate_by_node_id.keys())
                for nid, entry in (mergeability_map or {}).items():
                    pk = hydrate_by_node_id.get(nid)
                    if not pk or pk not in open_prs_by_key:
                        continue
                    _apply_pull_request_mergeability_entry(open_prs_by_key[pk], entry)

        community_actionable_prs: list[dict] = []
        non_community_actionable_prs: list[dict] = []
        for pr_item in poll_result.get("actionable_prs") or []:
            if not isinstance(pr_item, dict):
                continue
            if self.linear_client is not None and bool(pr_item.get("is_community")):
                pr_item_copy = dict(pr_item)
                pk_item = str(pr_item_copy.get("key") or "").strip().lower()
                if pk_item and pk_item in open_prs_by_key:
                    hydrated = open_prs_by_key[pk_item]
                    m_state = normalize_mergeable_state(
                        hydrated.get("mergeable"),
                        hydrated.get("merge_state_status") or hydrated.get("mergeStateStatus"),
                    )
                    if m_state != "UNKNOWN":
                        pr_item_copy["mergeable"] = m_state
                        pr_item_copy["merge_state_status"] = str(hydrated.get("merge_state_status") or "").strip().upper()
                        pr_item_copy["has_merge_conflicts"] = m_state == "CONFLICTING"
                        if m_state == "CONFLICTING":
                            pr_item_copy["community_auto_merge_eligible"] = False
                community_actionable_prs.append(pr_item_copy)
            else:
                non_community_actionable_prs.append(pr_item)

        linear_todo_reconciliations: list[dict] = []
        if self.linear_client is not None:
            linear_todo_reconciliations = self._reconcile_pending_linear_todo_claims(current_ms=current_ms)

        linear_triage_stubs = self._create_linear_triage_stubs(
            poll_result.get("actionable_issues") or [],
            slot_id=slot_id,
            current_ms=current_ms,
            linear_breaker=linear_breaker,
        )

        linear_synced_closed: list[dict] = []
        linear_pr_actions: list[dict] = []
        merge_conflict_actions: list[dict] = []
        in_review_pr_actions: list[dict] = []
        stale_issue_actions: list[dict] = []
        needs_decision_notifications: list[dict] = []
        traya_blind_reviews: list[dict] = []
        linear_operator_comment_dispatches: list[dict] = []
        linked_pr_issue_relations: list[dict] = []
        security_release_actions: list[dict] = []
        remaining_linear_issues: list[dict] = []

        if self.linear_client is not None and self.state_store.agent_name in AGENT_ORDER:
            active_linear_issues = self._poll_active_linear_issues()
            if active_linear_issues:
                if self.state_store.agent_name in SWEEP_AGENT_ORDER:
                    linear_synced_closed = self._sync_closed_github_items_to_linear(
                        active_linear_issues,
                        poll_result=poll_result,
                        current_ms=current_ms,
                        linear_breaker=linear_breaker,
                    )
                    synced_closed_ids = {
                        str(item.get("linear_issue_id") or "").strip()
                        for item in linear_synced_closed
                        if str(item.get("linear_issue_id") or "").strip()
                    }
                    remaining_linear_issues = [
                        issue
                        for issue in active_linear_issues
                        if str(issue.get("id") or "").strip() not in synced_closed_ids
                    ]
                else:
                    remaining_linear_issues = list(active_linear_issues)

            if self.state_store.agent_name in SWEEP_AGENT_ORDER:
                signoff_ready_pr_keys: set[str] = set()
                for item in poll_result.get("signoff_ready_prs") or ():
                    if not isinstance(item, dict):
                        continue
                    sk = str(item.get("key") or "").strip().lower()
                    if not sk:
                        s_repo = str(item.get("repo") or "").strip()
                        s_num = _safe_int(item.get("number"), 0)
                        if s_repo and s_num > 0:
                            sk = make_pr_key(s_repo, s_num)
                    if sk:
                        signoff_ready_pr_keys.add(sk)
                in_review_pr_actions = self._reconcile_in_review_linear_pr_status(
                    active_linear_issues=remaining_linear_issues,
                    open_prs_by_key=open_prs_by_key,
                    signoff_ready_pr_keys=signoff_ready_pr_keys,
                    poll_result=poll_result,
                    current_ms=current_ms,
                    linear_breaker=linear_breaker,
                    hydrated_mergeability_node_ids=hydrated_mergeability_node_ids,
                )
                if in_review_pr_actions and remaining_linear_issues:
                    updated_in_review_by_id: dict[str, dict] = {}
                    for act in in_review_pr_actions:
                        upd = act.get("updated_issue")
                        if isinstance(upd, dict) and str(upd.get("id") or "").strip():
                            updated_in_review_by_id[str(upd["id"]).strip()] = upd
                    if updated_in_review_by_id:
                        remaining_linear_issues = [
                            updated_in_review_by_id.get(str(issue.get("id") or "").strip(), issue)
                            for issue in remaining_linear_issues
                        ]
                stale_issue_actions = self._process_stale_issues(
                    open_issues=poll_result.get("open_issues") or [],
                    active_linear_issues=remaining_linear_issues,
                    poll_result=poll_result,
                    current_ms=current_ms,
                    linear_breaker=linear_breaker,
                )
                if stale_issue_actions and remaining_linear_issues:
                    stale_closed_ids = {
                        str(item.get("linear_issue_id") or "").strip()
                        for item in stale_issue_actions
                        if item.get("action") == "stale_issue_closed"
                        and str(item.get("linear_issue_id") or "").strip()
                    }
                    if stale_closed_ids:
                        remaining_linear_issues = [
                            issue
                            for issue in remaining_linear_issues
                            if str(issue.get("id") or "").strip() not in stale_closed_ids
                        ]

        # Priority 1: Direct operator @mentions on Linear (exempt from slot/daily LLM caps, bounded by MAX_LINEAR_OPERATOR_COMMENTS_PER_POLL).
        if self.linear_client is not None and remaining_linear_issues:
            linear_operator_comment_dispatches = self._dispatch_linear_operator_comments(
                remaining_linear_issues,
                slot_id=slot_id,
                dispatched_targets=dispatched_targets,
                current_ms=current_ms,
                now_override_ms=now_override_ms,
            )
            targeted_dispatches.extend(linear_operator_comment_dispatches)

        # Priority 2: Targeted GitHub notifications, verified team:* labels, and open/automated PR merges.
        candidate_thread_ids: list[str] = list(poll_result.get("actionable_threads") or [])
        for tid, entry in threads.items():
            if not isinstance(entry, dict) or "#" in tid or tid in candidate_thread_ids or _safe_int(entry.get("retry_count"), 0) >= MAX_THREAD_FAILURE_RETRIES:
                continue
            if str(entry.get("subject_type") or "").strip().lower() in ("pullrequest", "pull_request", "pr") and _safe_int(entry.get("followup_cooldown_until_ms"), 0) > current_ms:
                continue
            if entry.get("pending_followup") or is_timestamp_newer(entry.get("updated_at"), entry.get("handled_updated_at")):
                candidate_thread_ids.append(tid)

        for tid in candidate_thread_ids:
            entry = _as_dict(threads.get(tid))
            if not entry or _safe_int(entry.get("retry_count"), 0) >= MAX_THREAD_FAILURE_RETRIES:
                continue
            if str(entry.get("subject_type") or "").strip().lower() in ("pullrequest", "pull_request", "pr") and _safe_int(entry.get("followup_cooldown_until_ms"), 0) > current_ms:
                continue
            repo, number = str(entry.get("repo") or "").strip(), _safe_int(entry.get("number"), 0) or None
            dedup_key = make_pr_key(repo, number) if (repo and number) else tid
            if dedup_key in dispatched_targets:
                continue
            prep = self.trust_filter.fetch_and_prepare_notification(entry, now_override_ms=now_override_ms)
            if not prep.get("should_dispatch"):
                _complete_skipped(tid, tid, prep, entry)
                continue
            if not self.state_store.can_consume_throttle("tasks", slot_id=slot_id, now_override_ms=current_ms):
                continue
            consumed, _ = self.state_store.consume_throttle("tasks", slot_id=slot_id, now_override_ms=current_ms)
            if not consumed:
                continue
            dispatched_targets.add(dedup_key)
            targeted_dispatches.append(self.execution_coordinator.execute_dispatch(kind="targeted", is_automated_pr=bool(prep.get("is_automated_pr") or entry.get("is_automated_pr")), thread_id=tid, state_key=tid, repo=prep.get("repo") or repo, number=prep.get("number") or number, subject_kind=prep.get("kind") or entry.get("subject_type"), head_sha=prep.get("head_sha") or entry.get("head_sha"), ci_state=entry.get("ci_state"), updated_at=entry.get("updated_at"), trigger_reason=prep.get("trigger_reason") or entry.get("reason"), comment_id=prep.get("comment_id"), review_id=prep.get("review_id"), trusted_item_id=prep.get("trusted_item_id"), now_override_ms=now_override_ms))

        for item in verified_team_label_dispatches:
            cand = item["cand"]
            cand_key = item["cand_key"]
            if cand_key in dispatched_targets:
                continue
            if not self.state_store.can_consume_throttle("tasks", slot_id=slot_id, now_override_ms=current_ms):
                break
            consumed, _ = self.state_store.consume_throttle("tasks", slot_id=slot_id, now_override_ms=current_ms)
            if not consumed:
                break
            verified_label = item["verified_label"]
            dispatched_targets.add(cand_key)
            targeted_dispatches.append(
                self.execution_coordinator.execute_dispatch(
                    kind=verified_label,
                    is_automated_pr=False,
                    thread_id=str(cand.get("thread_id") or "").strip() or None,
                    state_key=cand_key,
                    repo=item["cand_repo"],
                    number=item["cand_num"],
                    subject_kind=item["cand_kind"],
                    head_sha=item["cand_head_sha"],
                    ci_state=str(cand.get("ci_state") or "") or None,
                    updated_at=str(cand.get("updated_at") or "") or None,
                    trigger_reason=TEAM_LABEL_TRIGGER_REASONS.get(verified_label, verified_label),
                    community_auto_merge_eligible=cand.get("community_auto_merge_eligible"),
                    team_label=verified_label,
                    team_label_event_key=item["verified_event_key"],
                    triaged_head_sha=item["triaged_sha"],
                    head_sha_changed=item["sha_changed"],
                    now_override_ms=now_override_ms,
                )
            )

        for pr_item in non_community_actionable_prs:
            pr_key = str(pr_item.get("key") or "").strip()
            pr_entry = _as_dict(self.state_store.get_thread_state(pr_key))
            if not pr_key or pr_key in dispatched_targets or _safe_int(pr_entry.get("retry_count"), 0) >= MAX_THREAD_FAILURE_RETRIES:
                continue
            trig_reason = str(pr_item.get("trigger_reason") or "open_pr_poll")
            if trig_reason != "ci_green_after_approval" and _safe_int(pr_entry.get("followup_cooldown_until_ms"), 0) > current_ms:
                continue
            if not self.state_store.can_consume_throttle("tasks", slot_id=slot_id, now_override_ms=current_ms):
                break
            consumed, _ = self.state_store.consume_throttle("tasks", slot_id=slot_id, now_override_ms=current_ms)
            if not consumed:
                break
            dispatched_targets.add(pr_key)
            pr_dispatch_kind = str(pr_item.get("dispatch_kind") or "targeted")
            targeted_dispatches.append(self.execution_coordinator.execute_dispatch(kind=pr_dispatch_kind, is_automated_pr=bool(pr_item.get("is_automated_pr") or pr_entry.get("is_automated_pr")), thread_id=str(pr_item.get("thread_id") or "").strip() or None, state_key=pr_key, repo=str(pr_item.get("repo") or ""), number=_safe_int(pr_item.get("number"), 0) or None, subject_kind="PullRequest", head_sha=str(pr_item.get("head_sha") or "") or None, ci_state=str(pr_item.get("ci_state") or "") or None, updated_at=str(pr_item.get("updated_at") or "") or None, trigger_reason=trig_reason, community_auto_merge_eligible=pr_item.get("community_auto_merge_eligible"), triaged_head_sha=str(pr_entry.get("triaged_head_sha") or "") or None, now_override_ms=now_override_ms))

        # Priority 3: Community PR blind reviews and Lane A/B merges, plus deterministic PR links and conflict reconciliation.
        if self.linear_client is not None and self.state_store.agent_name in SWEEP_AGENT_ORDER:
            pr_pipeline = self._process_linear_community_prs(
                community_actionable_prs,
                active_linear_issues=remaining_linear_issues,
                open_prs_by_key=open_prs_by_key,
                slot_id=slot_id,
                dispatched_targets=dispatched_targets,
                current_ms=current_ms,
                now_override_ms=now_override_ms,
                linear_breaker=linear_breaker,
            )
            targeted_dispatches.extend(pr_pipeline["dispatches"])
            linear_pr_actions.extend(pr_pipeline["linear_pr_actions"])
            needs_decision_notifications.extend(pr_pipeline["needs_decision_notifications"])
            linked_pr_issue_relations = self._link_open_prs_to_linear_issues(
                open_prs_by_key=open_prs_by_key,
                active_linear_issues=remaining_linear_issues,
                known_linear_issues_by_pr_key=pr_pipeline.get("linear_issues_by_pr_key"),
                current_ms=current_ms,
                linear_breaker=linear_breaker,
            )
            merge_conflict_actions = self._reconcile_community_pr_merge_conflicts(
                open_prs_by_key=open_prs_by_key,
                active_linear_issues=remaining_linear_issues,
                known_linear_issues_by_pr_key=pr_pipeline.get("linear_issues_by_pr_key"),
                poll_result=poll_result,
                current_ms=current_ms,
                linear_breaker=linear_breaker,
            )
            linear_pr_actions.extend(merge_conflict_actions)
            if remaining_linear_issues:
                # Priority 4: Todo implementations (before Triage research).
                targeted_dispatches.extend(
                    self._dispatch_linear_todo_implementations(
                        remaining_linear_issues,
                        slot_id=slot_id,
                        dispatched_targets=dispatched_targets,
                        current_ms=current_ms,
                        now_override_ms=now_override_ms,
                        open_pr_by_closing_issue_key=open_pr_by_closing_issue_key,
                        linear_breaker=linear_breaker,
                    )
                )
                # Priority 5: Triage research (fills any remaining slot/daily LLM task budget).
                targeted_dispatches.extend(
                    self._dispatch_linear_triage_research(
                        remaining_linear_issues,
                        slot_id=slot_id,
                        dispatched_targets=dispatched_targets,
                        current_ms=current_ms,
                        now_override_ms=now_override_ms,
                    )
                )
            security_release_actions = self._evaluate_security_patch_releases(
                open_prs_by_key=open_prs_by_key,
                poll_result=poll_result,
                current_ms=current_ms,
                linear_breaker=linear_breaker,
            )
        elif self.linear_client is not None and self.state_store.agent_name == "traya":
            if poll_result.get("open_prs_poll_error") is None:
                traya_blind_reviews = self._run_traya_blind_pr_reviews(
                    open_prs_by_key=open_prs_by_key,
                    slot_id=slot_id,
                    dispatched_targets=dispatched_targets,
                    current_ms=current_ms,
                    now_override_ms=now_override_ms,
                )
                for traya_item in traya_blind_reviews:
                    if isinstance(traya_item.get("dispatch"), dict):
                        targeted_dispatches.append(traya_item["dispatch"])

        sweep_dispatch: dict | None = None
        if run_sweeps_if_due and not any(d.get("verification_deferred") for d in targeted_dispatches):
            weekly_due, today_str = self.is_weekly_sweep_due(now_override_ms=now_override_ms)
            if weekly_due or self.is_reconcile_sweep_due(now_override_ms=now_override_ms):
                sweep_dispatch = self.execution_coordinator.execute_dispatch(kind="weekly_sweep" if weekly_due else "reconcile_sweep", sweep_date=today_str if weekly_due else None, now_override_ms=now_override_ms)

        health_alerts = self._evaluate_health_alerts(
            poll_result=poll_result,
            linear_breaker=linear_breaker,
            current_ms=current_ms,
        )
        pending_security_releases = self._collect_pending_security_releases(
            active_linear_issues=remaining_linear_issues,
        )
        operator_digest = self._maybe_send_operator_digest(
            active_linear_issues=remaining_linear_issues,
            pending_security_releases=pending_security_releases,
            current_ms=current_ms,
        )

        return {
            "status": "ok",
            "recovery": recovery,
            "poll_result": poll_result,
            "targeted_dispatches": targeted_dispatches,
            "dismissed_threads": dismissed_threads,
            "sweep_dispatch": sweep_dispatch,
            "linear_triage_stubs": linear_triage_stubs,
            "linear_promoted_todos": linear_promoted_todos,
            "linear_synced_closed": linear_synced_closed,
            "signoff_notifications": signoff_notifications,
            "linear_pr_actions": linear_pr_actions,
            "merge_conflict_actions": merge_conflict_actions,
            "in_review_pr_actions": in_review_pr_actions,
            "stale_issue_actions": stale_issue_actions,
            "needs_decision_notifications": needs_decision_notifications,
            "traya_blind_reviews": traya_blind_reviews,
            "linear_todo_reconciliations": linear_todo_reconciliations,
            "linear_operator_comment_dispatches": linear_operator_comment_dispatches,
            "health_alerts": health_alerts,
            "operator_digest": operator_digest,
            "linked_pr_issue_relations": linked_pr_issue_relations,
            "security_release_actions": security_release_actions,
        }


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Moltis GitHub notification and pull-request companion")
    parser.add_argument("--agent-name", default=os.environ.get("MOLTIS_GITHUB_COMPANION_AGENT_NAME") or os.environ.get("MOLTIS_COMPANION_AGENT_NAME", ""))
    parser.add_argument("--agent-display-name", default=os.environ.get("MOLTIS_GITHUB_COMPANION_AGENT_DISPLAY_NAME") or os.environ.get("MOLTIS_COMPANION_AGENT_DISPLAY_NAME", ""))
    parser.add_argument("--update-model", default=os.environ.get("MOLTIS_GITHUB_COMPANION_UPDATE_MODEL", ""))
    parser.add_argument("--sweep-model", default=os.environ.get("MOLTIS_GITHUB_COMPANION_SWEEP_MODEL", ""))
    parser.add_argument("--code-model", default=os.environ.get("MOLTIS_GITHUB_COMPANION_CODE_MODEL", ""))
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
    parser.add_argument("--community-auto-merge-enabled", default=os.environ.get("MOLTIS_GITHUB_COMPANION_COMMUNITY_AUTO_MERGE_ENABLED", ""))
    parser.add_argument("--community-auto-merge-max-lines", default=os.environ.get("MOLTIS_GITHUB_COMPANION_COMMUNITY_AUTO_MERGE_MAX_LINES", ""))
    parser.add_argument("--community-auto-merge-max-files", default=os.environ.get("MOLTIS_GITHUB_COMPANION_COMMUNITY_AUTO_MERGE_MAX_FILES", ""))
    parser.add_argument("--community-auto-merge-excluded-repos", default=os.environ.get("MOLTIS_GITHUB_COMPANION_COMMUNITY_AUTO_MERGE_EXCLUDED_REPOS", ""))
    parser.add_argument("--poll-interval-minutes", default=os.environ.get("MOLTIS_GITHUB_COMPANION_POLL_INTERVAL_MINUTES", ""))
    parser.add_argument("--max-tasks-per-slot", default=os.environ.get("MOLTIS_GITHUB_COMPANION_MAX_TASKS_PER_SLOT", ""))
    parser.add_argument("--max-tasks-per-day", default=os.environ.get("MOLTIS_GITHUB_COMPANION_MAX_TASKS_PER_DAY", ""))
    parser.add_argument("--daily-implementations-cap", default=os.environ.get("MOLTIS_GITHUB_COMPANION_DAILY_IMPLEMENTATIONS_CAP", ""))
    parser.add_argument("--shadow-eval-enabled", default=os.environ.get("MOLTIS_GITHUB_COMPANION_SHADOW_EVAL_ENABLED", ""))
    parser.add_argument("--shadow-model", default=os.environ.get("MOLTIS_GITHUB_COMPANION_SHADOW_MODEL") or os.environ.get("MOLTIS_GITHUB_COMPANION_SHADOW_EVAL_MODEL", ""))
    parser.add_argument("--shadow-api-url", default=os.environ.get("MOLTIS_GITHUB_COMPANION_SHADOW_API_URL") or os.environ.get("MOLTIS_GITHUB_COMPANION_SHADOW_EVAL_API_URL", ""))
    parser.add_argument("--shadow-summary-path", default=None)
    parser.add_argument("--shadow-timeout-secs", default=os.environ.get("MOLTIS_GITHUB_COMPANION_SHADOW_TIMEOUT_SECS") or os.environ.get("MOLTIS_GITHUB_COMPANION_SHADOW_EVAL_TIMEOUT_SECS", ""))
    parser.add_argument("--replay-shadow", default="")
    parser.add_argument("--shadow-output", default="")
    parser.add_argument("--read-only-trial", action="store_true", default=os.environ.get("MOLTIS_GITHUB_COMPANION_READ_ONLY_TRIAL", "").strip() in ("1", "true", "yes"))
    parser.add_argument("--reprocess-community", action="store_true")
    parser.add_argument("--once", action="store_true")
    return parser


def _resolve_shadow_config_from_args(args: argparse.Namespace, *, agent_name: str = "") -> dict[str, object]:
    raw_enabled = getattr(args, "shadow_eval_enabled", "")
    raw_model = getattr(args, "shadow_model", "") or os.environ.get("MOLTIS_GITHUB_COMPANION_SHADOW_MODEL", "")
    raw_api_url = getattr(args, "shadow_api_url", "") or os.environ.get("MOLTIS_GITHUB_COMPANION_SHADOW_API_URL", "")
    arg_summary_path = getattr(args, "shadow_summary_path", None)
    if arg_summary_path is None or not str(arg_summary_path).strip():
        raw_summary_path = (
            os.environ.get("MOLTIS_GITHUB_COMPANION_SHADOW_SUMMARY_PATH")
            or os.environ.get("MOLTIS_GITHUB_COMPANION_SHADOW_EVAL_SUMMARY_PATH", "")
        )
    else:
        raw_summary_path = str(arg_summary_path)
    raw_timeout_secs = getattr(args, "shadow_timeout_secs", "") or os.environ.get("MOLTIS_GITHUB_COMPANION_SHADOW_TIMEOUT_SECS", "")
    return shadow_eval.resolve_shadow_eval_config(
        agent_name=agent_name,
        enabled=raw_enabled if str(raw_enabled).strip() != "" else None,
        model=raw_model if str(raw_model).strip() != "" else None,
        api_url=raw_api_url if str(raw_api_url).strip() != "" else None,
        summary_path=raw_summary_path if str(raw_summary_path).strip() != "" else None,
        timeout_secs=raw_timeout_secs if str(raw_timeout_secs).strip() != "" else None,
    )


def resolve_runtime_config(args: argparse.Namespace) -> dict:
    agent_name = normalize_agent_name(args.agent_name)
    default_dow, default_day_name = AGENT_DEFAULT_SCHEDULES[agent_name]
    env_dow = os.environ.get("MOLTIS_GITHUB_COMPANION_SCHEDULE_DOW", "").strip()
    explicit_dow = getattr(args, "schedule_dow", None)
    if explicit_dow is None and env_dow:
        explicit_dow = _safe_int(env_dow, default_dow)
    state_dir_raw = (args.state_dir or "").strip()
    xdg_state = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    update_model, sweep_model, code_model = resolve_model_tiers(
        update_model=getattr(args, "update_model", "") or os.environ.get("MOLTIS_GITHUB_COMPANION_UPDATE_MODEL", ""),
        sweep_model=getattr(args, "sweep_model", "") or os.environ.get("MOLTIS_GITHUB_COMPANION_SWEEP_MODEL", ""),
        code_model=getattr(args, "code_model", "") or os.environ.get("MOLTIS_GITHUB_COMPANION_CODE_MODEL", ""),
    )
    cam_cfg = resolve_community_auto_merge_config(
        enabled=getattr(args, "community_auto_merge_enabled", "") or None,
        max_lines=getattr(args, "community_auto_merge_max_lines", "") or None,
        max_files=getattr(args, "community_auto_merge_max_files", "") or None,
        excluded_repos=getattr(args, "community_auto_merge_excluded_repos", "") or None,
    )
    shadow_cfg = _resolve_shadow_config_from_args(args, agent_name=agent_name)
    raw_poll_interval = getattr(args, "poll_interval_minutes", "")
    raw_max_tasks_slot = getattr(args, "max_tasks_per_slot", "")
    raw_max_tasks_day = getattr(args, "max_tasks_per_day", "")
    raw_daily_impl_cap = getattr(args, "daily_implementations_cap", "")
    return {
        "agent_name": agent_name, "agent_display_name": derive_display_name(agent_name, args.agent_display_name),
        "update_model": update_model,
        "sweep_model": sweep_model,
        "code_model": code_model,
        "schedule_dow": _safe_int(explicit_dow, default_dow) if explicit_dow is not None else default_dow,
        "schedule_day_name": (getattr(args, "schedule_day_name", "") or os.environ.get("MOLTIS_GITHUB_COMPANION_SCHEDULE_DAY_NAME", "") or default_day_name).strip(),
        "self_user_id": (args.self_user_id or f"@{agent_name}:{SERVER_DOMAIN}").strip(), "room_id": (args.room_id or DEFAULT_ROOM_ID).strip(),
        "homeserver_url": (args.homeserver_url or DEFAULT_HOMESERVER_URL).strip(), "password_path": (args.password_path or "").strip() or None,
        "telegram_bot_token_path": (getattr(args, "telegram_bot_token_path", "") or os.environ.get("MOLTIS_GITHUB_COMPANION_TELEGRAM_BOT_TOKEN_PATH", "")).strip() or None,
        "telegram_allowed_users_path": (getattr(args, "telegram_allowed_users_path", "") or os.environ.get("MOLTIS_GITHUB_COMPANION_TELEGRAM_ALLOWED_USERS_PATH", "")).strip() or None,
        "telegram_api_url": (getattr(args, "telegram_api_url", "") or os.environ.get("MOLTIS_GITHUB_COMPANION_TELEGRAM_API_URL", "") or DEFAULT_TELEGRAM_API_URL).strip(),
        "data_dir": Path(args.data_dir).expanduser(), "state_dir": Path(state_dir_raw).expanduser() if state_dir_raw else (Path(xdg_state) / "moltis" / f"github-companion-{agent_name}"),
        "rpc_url": (args.rpc_url or DEFAULT_RPC_URL).strip(), "gh_api_safe_bin": (args.gh_api_safe_bin or "gh-api-safe").strip(),
        "community_auto_merge_enabled": cam_cfg["enabled"],
        "community_auto_merge_max_lines": cam_cfg["max_lines"],
        "community_auto_merge_max_files": cam_cfg["max_files"],
        "community_auto_merge_excluded_repos": cam_cfg["excluded_repos"],
        "poll_interval_minutes": resolve_poll_interval_minutes(raw_poll_interval if str(raw_poll_interval).strip() != "" else None),
        "max_tasks_per_slot": resolve_max_tasks_per_slot(raw_max_tasks_slot if str(raw_max_tasks_slot).strip() != "" else None, agent_name=agent_name),
        "max_tasks_per_day": resolve_max_tasks_per_day(raw_max_tasks_day if str(raw_max_tasks_day).strip() != "" else None),
        "daily_implementations_cap": resolve_daily_implementations_cap(raw_daily_impl_cap if str(raw_daily_impl_cap).strip() != "" else None, agent_name=agent_name),
        "shadow_eval_enabled": bool(shadow_cfg["enabled"]),
        "shadow_model": str(shadow_cfg["model"]),
        "shadow_api_url": str(shadow_cfg["api_url"]),
        "shadow_summary_path": shadow_cfg["summary_path"],
        "shadow_timeout_secs": float(shadow_cfg["timeout_secs"]),
        "replay_shadow": str(getattr(args, "replay_shadow", "") or "").strip() or None,
        "shadow_output": str(getattr(args, "shadow_output", "") or "").strip() or None,
        "read_only_trial": bool(getattr(args, "read_only_trial", False)),
        "reprocess_community": bool(getattr(args, "reprocess_community", False)),
        "once": bool(getattr(args, "once", False)),
    }


def _regenerate_shadow_report_html(cfg: dict) -> Path | None:
    raw_summary = cfg.get("shadow_summary_path")
    if raw_summary is None or not str(raw_summary).strip():
        return None
    summary_path = Path(raw_summary).expanduser()
    html_path = summary_path.parent / "index.html"
    jsonl_path = Path(cfg["state_dir"]).expanduser() / shadow_eval.SHADOW_EVAL_JSONL_FILENAME
    try:
        shadow_report.render_host_report_from_jsonl(
            jsonl_path,
            html_path,
            agent=str(cfg.get("agent_name") or ""),
            shadow_model=str(cfg.get("shadow_model") or ""),
            gemini_model=str(cfg.get("update_model") or ""),
        )
        return html_path
    except Exception as exc:
        safe_err = shadow_eval.redact_secrets(str(exc))
        sys.stderr.write(
            f"moltis-github-companion shadow report HTML warning ({cfg.get('agent_name', '')}): {safe_err}\n"
        )
        return None


def _ensure_shadow_report_index(cfg: dict) -> Path | None:
    raw_summary = cfg.get("shadow_summary_path")
    if raw_summary is None or not str(raw_summary).strip():
        return None
    summary_path = Path(raw_summary).expanduser()
    html_path = summary_path.parent / "index.html"
    state_dir = Path(cfg["state_dir"]).expanduser()
    jsonl_path = state_dir / shadow_eval.SHADOW_EVAL_JSONL_FILENAME
    try:
        return shadow_report.ensure_host_report_index(
            output_path=html_path,
            summary_path=summary_path,
            state_dir=state_dir,
            jsonl_path=jsonl_path,
            agent=str(cfg.get("agent_name") or ""),
            shadow_model=str(cfg.get("shadow_model") or ""),
            gemini_model=str(cfg.get("update_model") or ""),
        )
    except Exception as exc:
        safe_err = shadow_eval.redact_secrets(str(exc))
        sys.stderr.write(
            f"moltis-github-companion shadow report index warning ({cfg.get('agent_name', '')}): {safe_err}\n"
        )
        return None


def main(argv: list[str] | None = None) -> int:
    args = build_arg_parser().parse_args(argv)
    replay_path = str(getattr(args, "replay_shadow", "") or "").strip()
    if replay_path:
        raw_agent = str(getattr(args, "agent_name", "") or "").strip()
        replay_agent = normalize_agent_name(raw_agent) if raw_agent else ""
        shadow_cfg = _resolve_shadow_config_from_args(args, agent_name=replay_agent)
        explicit_summary_arg = str(getattr(args, "shadow_summary_path", None) or "").strip()
        replay_summary_path = Path(explicit_summary_arg).expanduser() if explicit_summary_arg else None
        replay_output_path = str(getattr(args, "shadow_output", "") or "").strip() or None
        summary = shadow_eval.replay_shadow_jsonl(
            replay_path,
            shadow_model=str(shadow_cfg["model"]),
            shadow_api_url=str(shadow_cfg["api_url"]),
            output_path=replay_output_path,
            summary_path=replay_summary_path,
            timeout_secs=float(shadow_cfg["timeout_secs"]),
        )
        print(json.dumps(summary, sort_keys=True, ensure_ascii=False))
        return 0
    cfg = resolve_runtime_config(args)
    store = CompanionStateStore(
        state_dir=cfg["state_dir"],
        agent_name=cfg["agent_name"],
        room_id=cfg["room_id"],
        community_auto_merge_enabled=cfg["community_auto_merge_enabled"],
        community_auto_merge_max_lines=cfg["community_auto_merge_max_lines"],
        community_auto_merge_max_files=cfg["community_auto_merge_max_files"],
        community_auto_merge_excluded_repos=cfg["community_auto_merge_excluded_repos"],
        max_tasks_per_slot=cfg["max_tasks_per_slot"],
        max_tasks_per_day=cfg["max_tasks_per_day"],
        daily_implementations_cap=cfg["daily_implementations_cap"],
    )
    if cfg["reprocess_community"]:
        reset_count = store.reprocess_community_entries()
        print(json.dumps({"status": "ok", "agent_name": cfg["agent_name"], "reset_count": reset_count}, sort_keys=True))
        return 0
    gh_client = GhApiSafeClient(gh_api_safe_bin=cfg["gh_api_safe_bin"])
    has_matrix_creds = bool(cfg["password_path"] or os.environ.get("MATRIX" + "_PASSWORD", "").strip())
    matrix_client = MatrixClient(homeserver_url=cfg["homeserver_url"], self_user_id=cfg["self_user_id"], agent_name=cfg["agent_name"], room_id=cfg["room_id"], password_path=cfg["password_path"], state_store=store) if has_matrix_creds else None
    tok_env_key = "TELEGRAM_BOT_" + "TOKEN"
    has_telegram_creds = bool(cfg["telegram_bot_token_path"] or cfg["telegram_allowed_users_path"] or os.environ.get(tok_env_key, "").strip() or os.environ.get("TELEGRAM_ALLOWED_USERS", "").strip())
    telegram_client = TelegramClient(bot_token_path=cfg["telegram_bot_token_path"], allowed_users_path=cfg["telegram_allowed_users_path"], api_url=cfg["telegram_api_url"]) if has_telegram_creds else None
    rpc_client = MoltisRpcClient(rpc_url=cfg["rpc_url"])
    poller = NotificationPoller(state_store=store, gh_client=gh_client, read_only_trial=cfg["read_only_trial"], poll_interval_minutes=cfg["poll_interval_minutes"])
    trust_filter = TrustFilterAndSnapshotBuilder(state_store=store, gh_client=gh_client, matrix_client=matrix_client, telegram_client=telegram_client, agent_name=cfg["agent_name"])
    linear_client = linear_sync.LinearSyncClient.from_env()
    shadow_worker: shadow_eval.ShadowEvalWorker | None = None
    if cfg["shadow_eval_enabled"]:
        shadow_worker = shadow_eval.ShadowEvalWorker(
            state_dir=cfg["state_dir"],
            shadow_model=cfg["shadow_model"],
            shadow_api_url=cfg["shadow_api_url"],
            summary_path=cfg["shadow_summary_path"],
            timeout_secs=cfg["shadow_timeout_secs"],
            on_record_written=lambda _record, _summary: _regenerate_shadow_report_html(cfg),
        )
        _ensure_shadow_report_index(cfg)
    execution_coordinator = LocalExecutionCoordinator(state_store=store, rpc_client=rpc_client, data_dir=cfg["data_dir"], agent_name=cfg["agent_name"], agent_display_name=cfg["agent_display_name"], update_model=cfg["update_model"], sweep_model=cfg["sweep_model"], code_model=cfg["code_model"], matrix_client=matrix_client, telegram_client=telegram_client, room_id=cfg["room_id"], schedule_dow=cfg["schedule_dow"], schedule_day_name=cfg["schedule_day_name"], linear_client=linear_client, gh_client=gh_client, shadow_worker=shadow_worker)
    runner = GithubCompanionRunner(state_store=store, gh_client=gh_client, poller=poller, trust_filter=trust_filter, execution_coordinator=execution_coordinator, matrix_client=matrix_client, read_only_trial=cfg["read_only_trial"], linear_client=linear_client, telegram_client=telegram_client, poll_interval_minutes=cfg["poll_interval_minutes"])
    try:
        if cfg["once"]:
            poller.wait_until_due()
            runner.run_cycle()
            if shadow_worker is not None:
                shadow_worker.drain(timeout=float(cfg["shadow_timeout_secs"]) + 5.0)
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
    finally:
        if shadow_worker is not None:
            with contextlib.suppress(Exception):
                shadow_worker.drain(timeout=5.0)
            with contextlib.suppress(Exception):
                shadow_worker.close(timeout=5.0)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        print("Moltis: GitHub companion failed.", file=sys.stderr)
        sys.exit(1)
