"""GitHub notification, open pull-request, and mention wake daemon for Moltis agents."""

from __future__ import annotations

import argparse
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
from collections.abc import Callable, Iterable
from pathlib import Path

_SCRIPT_DIR = str(Path(__file__).resolve().parent)
if _SCRIPT_DIR not in sys.path:
    sys.path.insert(0, _SCRIPT_DIR)

import linear_sync

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
DEFAULT_SLOT_TRIAGE_STUBS_CAP = 10
DEFAULT_SLOT_TRIAGE_RESEARCH_CAP = 2
DEFAULT_SLOT_COMMUNITY_PR_REVIEWS_CAP = 2
DEFAULT_SLOT_TODO_IMPLEMENTATIONS_CAP = 1
DEFAULT_DAILY_IMPLEMENTATIONS_CAP = 3
DEFAULT_THROTTLE_LIMITS: dict[str, int] = {
    "triage_stubs": DEFAULT_SLOT_TRIAGE_STUBS_CAP,
    "triage_research": DEFAULT_SLOT_TRIAGE_RESEARCH_CAP,
    "community_pr_reviews": DEFAULT_SLOT_COMMUNITY_PR_REVIEWS_CAP,
    "todo_implementations": DEFAULT_SLOT_TODO_IMPLEMENTATIONS_CAP,
    "daily_implementations": DEFAULT_DAILY_IMPLEMENTATIONS_CAP,
}
_THROTTLE_BUCKET_TO_STATE_KEY: dict[str, str] = {
    "triage_stubs": "slot_triage_stubs",
    "triage_research": "slot_triage_research",
    "community_pr_reviews": "slot_community_pr_reviews",
    "todo_implementations": "slot_todo_implementations",
}
STATE_FILENAME, ACTIVE_DISPATCH_FILENAME, SECURITY_EVENTS_FILENAME = "state.json", "active-dispatch.json", "security-events.jsonl"
LEGACY_POLL_STATE_FILENAME, LEGACY_NOTIFICATIONS_STATE_FILENAME = "poll-state.json", "notifications-state.json"
LEGACY_WATERMARKS_FILENAME, LEGACY_SECURITY_OWNERSHIP_FILENAME = "watermarks.json", "security-ownership.json"
OUTBOX_FILENAME, AUTH_STATE_FILENAME = "outbox.json", "auth.json"
COORDINATOR_LOCK_FILENAME, STATE_LOCK_FILENAME = "coordinator.lock", "companion.lock"
ENCODED_COMPONENT_BYTES, MAX_RESPONSE_BYTES = 120, 4 * 1048576
DEFAULT_GH_SESSION_KEY, MAX_THREAD_FAILURE_RETRIES = "companion:github", 3
TEAM_LABELS = ("team:implement", "team:merge", "team:review")
PR_TEAM_LABELS = ("team:merge", "team:review", "team:implement")
ISSUE_TEAM_LABELS = ("team:implement", "team:review")
DO_NOT_MERGE_LABEL = "team:do-not-merge"
TEAM_LABEL_TRIGGER_REASONS: dict[str, str] = {
    "team:implement": "team_implement",
    "team:merge": "team_merge",
    "team:review": "team_review",
}
MODEL_FAMILY_BY_AGENT: dict[str, str] = {"skrye": "gemini", "zannah": "gemini", "traya": "gpt"}
LINEAR_ISSUE_DISPATCH_KINDS = frozenset({"linear_triage_research", "linear_todo_implement"})
LINEAR_PR_DISPATCH_KINDS = frozenset({"community_pr_blind_review", "community_pr_lane_a_merge", "community_pr_lane_b_review"})
MODE_1B_DISPATCH_KINDS = frozenset({"community_triage", "community_auto_review", *TEAM_LABELS, *LINEAR_ISSUE_DISPATCH_KINDS, *LINEAR_PR_DISPATCH_KINDS})
SILENT_TELEGRAM_DISPATCH_KINDS = frozenset({"linear_triage_research", "community_pr_blind_review", "community_pr_lane_b_review"})
DEFAULT_COMMUNITY_AUTO_MERGE_ENABLED = True
DEFAULT_COMMUNITY_AUTO_MERGE_MAX_LINES = 150
DEFAULT_COMMUNITY_AUTO_MERGE_MAX_FILES = 5
DEFAULT_COMMUNITY_AUTO_MERGE_EXCLUDED_REPOS = ("wimpysworld/nix-config",)
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


def verify_team_label_from_events(events: Iterable[dict], label_name: str) -> dict | None:
    """Verify via issue events that the latest `labeled` event for `label_name` came from `TRUSTED_INSTRUCTION_ACTORS`."""
    target = (label_name or "").strip().lower()
    if not target:
        return None
    best_event: dict | None = None
    best_sort_key: tuple[int, int] = (-1, -1)
    for idx, ev in enumerate(events or ()):
        if not isinstance(ev, dict) or str(ev.get("event") or "").strip().lower() != "labeled":
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
    if best_event is None:
        return None
    actor_norm = normalize_github_actor(best_event.get("actor") or best_event.get("user"))
    if not is_trusted_instruction_actor(actor_norm):
        return None
    ev_id = best_event.get("id")
    created_at = str(best_event.get("created_at") or "").strip()
    event_key = f"{target}:{ev_id if ev_id is not None else (created_at or 'verified')}"
    return {"label": target, "actor": actor_norm, "event_id": ev_id, "created_at": created_at, "event_key": event_key}


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


def compute_community_auto_merge_eligible(
    *,
    repo: str,
    additions: int | None,
    deletions: int | None,
    changed_files: int | None,
    file_paths: Iterable[str] | None,
    files_has_next_page: bool = False,
    enabled: bool = DEFAULT_COMMUNITY_AUTO_MERGE_ENABLED,
    max_lines: int = DEFAULT_COMMUNITY_AUTO_MERGE_MAX_LINES,
    max_files: int = DEFAULT_COMMUNITY_AUTO_MERGE_MAX_FILES,
    excluded_repos: Iterable[str] = DEFAULT_COMMUNITY_AUTO_MERGE_EXCLUDED_REPOS,
) -> bool:
    if not enabled:
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


def compute_lane_a_bypass_reasons(
    *,
    repo: str,
    additions: int | None,
    deletions: int | None,
    changed_files: int | None,
    file_paths: Iterable[str] | None,
    files_has_next_page: bool = False,
    ci_state: str | None = None,
    enabled: bool = DEFAULT_COMMUNITY_AUTO_MERGE_ENABLED,
    max_lines: int = DEFAULT_COMMUNITY_AUTO_MERGE_MAX_LINES,
    max_files: int = DEFAULT_COMMUNITY_AUTO_MERGE_MAX_FILES,
    excluded_repos: Iterable[str] = DEFAULT_COMMUNITY_AUTO_MERGE_EXCLUDED_REPOS,
) -> list[str]:
    """Return ordered Lane A bypass reason tokens for a community pull request."""
    reasons: list[str] = []
    if not enabled:
        reasons.append("disabled")
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
    ("tool_invocation_directive", re.compile(r"\b(?:gh-bot-merge|gh-code-scanning-dismiss|gh-notification-dismiss|gh-review-resolve|gh-review-unresolve|gh-review-inline|gh-review-reply|moltis-telegram-voice|chat\.send_sync|exec_command|tool_call)\b", re.IGNORECASE)),
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
    ("tool_or_turn_failed", re.compile(r"^\s*(?:the\s+)?(?:github|gh|gh-api-safe|gh-bot-merge|gh-review-inline|gh-review-reply|gh-review-resolve|gh-review-unresolve|gh-notification-dismiss|git|exec|shell|rpc|model|provider|api|command|request|turn|dispatch|tool)\s+(?:tool\s+|command\s+|call\s+|request\s+|execution\s+|turn\s+|helper\s+)?(?:failed|errored|timed\s+out|aborted|crashed|was\s+blocked|is\s+unavailable)\b", re.IGNORECASE)),
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


def compute_next_poll_slot_ms(now_ms_val: int, agent_name: str = "skrye") -> int:
    norm_agent = normalize_agent_name(agent_name) if (agent_name or "").strip().lower() in AGENT_POLL_MINUTE_SLOTS else "skrye"
    slots = sorted(AGENT_POLL_MINUTE_SLOTS[norm_agent])
    safe_now = max(0, _safe_int(now_ms_val, 0))
    dt = datetime.datetime.fromtimestamp(safe_now / 1000.0, tz=datetime.timezone.utc)
    hour_start = dt.replace(minute=0, second=0, microsecond=0)
    for hour_offset in (0, 1):
        base_hour = hour_start + datetime.timedelta(hours=hour_offset)
        for slot_min in slots:
            cand = base_hour.replace(minute=slot_min)
            cand_ms = math.trunc(cand.timestamp() * 1000)
            if cand_ms > safe_now:
                return cand_ms
    return safe_now + POLL_SLOT_INTERVAL_MS


def compute_throttle_slot_id(now_ms_val: int, agent_name: str = "skrye") -> str:
    """Return a deterministic throttle slot identifier aligned to the agent's 30-minute poll slot."""
    norm_agent = normalize_agent_name(agent_name) if (agent_name or "").strip().lower() in AGENT_POLL_MINUTE_SLOTS else "skrye"
    return f"{norm_agent}:{compute_next_poll_slot_ms(now_ms_val, norm_agent)}"


def compute_backoff_wait_ms(headers: dict[str, str] | None, now_ms_val: int, rng: Callable[[int, int], int] | None = None, status: int | None = None, agent_name: str = "skrye") -> tuple[int, int, int]:
    """Return (total_wait_ms, base_wait_secs, jitter_ms) aligned to the agent's 30-minute wall-clock poll slot."""
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
    slot_wait_ms = max(1_000, compute_next_poll_slot_ms(now_ms_val, agent_name) - now_ms_val)
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
    return {
        "pr_key": make_pr_key(repo_full_name, number),
        "id": raw.get("databaseId") or raw.get("id") or number,
        "repo": repo_full_name,
        "owner": repo_full_name.split("/", 1)[0].lower(),
        "number": number,
        "author": extract_actor_login(raw.get("author") or raw.get("user")),
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
    ):
        self.state_dir = Path(state_dir)
        self.agent_name = normalize_agent_name(agent_name)
        self.room_id = room_id
        self.started_at_ms = _safe_int(started_at_ms, now_ms()) if started_at_ms is not None else now_ms()
        self.followup_cooldown_ms = max(0, _safe_int(followup_cooldown_ms, PR_REVIEW_COOLDOWN_MS))
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
        }

    @staticmethod
    def _default_throttles() -> dict:
        return {
            "daily_date": None,
            "daily_implementations": 0,
            "slot_id": None,
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
            "daily_implementations": max(0, _safe_int(data.get("daily_implementations"), 0)),
            "slot_id": slot_id_raw.strip() if isinstance(slot_id_raw, str) and slot_id_raw.strip() else None,
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
            throttles["daily_implementations"] = 0
        clean_slot_id = slot_id.strip() if isinstance(slot_id, str) and slot_id.strip() else None
        if clean_slot_id is not None and throttles["slot_id"] != clean_slot_id:
            throttles["slot_id"] = clean_slot_id
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
    def _resolve_throttle_limits(limits: dict | None = None) -> dict[str, int]:
        resolved = dict(DEFAULT_THROTTLE_LIMITS)
        if isinstance(limits, dict):
            for key, default_val in DEFAULT_THROTTLE_LIMITS.items():
                if key in limits and limits[key] is not None and not isinstance(limits[key], bool):
                    resolved[key] = max(0, _safe_int(limits[key], default_val))
        return resolved

    def _default_state(self) -> dict:
        return {"version": STATE_SCHEMA_VERSION, "agent_name": self.agent_name, "next_poll_at_ms": None, "last_poll_started_at_ms": None, "last_poll_completed_at_ms": None, "last_status": None, "last_modified": None, "poll_interval_secs": 0, "retry_after_secs": 0, "last_poll_rate_limited": False, "ratelimit_reset_epoch": None, "last_jitter_ms": None, "last_open_prs_poll_error": None, "last_open_issues_poll_error": None, "last_reconcile_sweep_at_ms": None, "last_reconcile_sweep_attempt_at_ms": None, "reconcile_sweep_retry_after_ms": None, "reconcile_sweep_failure_count": 0, "last_reconcile_sweep_failure_reason": None, "last_weekly_sweep_date": None, "last_weekly_sweep_attempt_at_ms": None, "weekly_sweep_retry_after_ms": None, "weekly_sweep_failure_count": 0, "last_weekly_sweep_failure_reason": None, "throttles": self._default_throttles(), "threads": {}, "updated_at_ms": self.started_at_ms}

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
                state.update({k: v for k, v in updates.items() if k not in ("threads", "throttles")})
                state["threads"] = merged_threads
            else:
                state.update({k: v for k, v in updates.items() if k != "throttles"})
            if "throttles" in updates and isinstance(updates["throttles"], dict):
                state["throttles"] = self._normalize_throttles({**self._normalize_throttles(state.get("throttles")), **updates["throttles"]})
            else:
                state["throttles"] = self._normalize_throttles(state.get("throttles"))
            self._normalize_sweep_fields(state)
            state.update({"agent_name": self.agent_name, "updated_at_ms": stamp_ms})
            atomic_write_json_in_dir(dir_fd, STATE_FILENAME, state)
            return dict(state)

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

    def can_consume_throttle(self, bucket: str, *, slot_id: str | None = None, limits: dict | None = None, now_override_ms: int | None = None) -> bool:
        clean_bucket, state_key = self._validate_throttle_bucket(bucket)
        eff_limits = self._resolve_throttle_limits(limits)
        throttles = self.get_throttle_state(slot_id=slot_id, now_override_ms=now_override_ms)
        if throttles[state_key] + 1 > eff_limits[clean_bucket]:
            return False
        if clean_bucket == "todo_implementations" and throttles["daily_implementations"] + 1 > eff_limits["daily_implementations"]:
            return False
        return True

    def consume_throttle(self, bucket: str, *, count: int = 1, slot_id: str | None = None, limits: dict | None = None, now_override_ms: int | None = None) -> tuple[bool, dict]:
        clean_bucket, state_key = self._validate_throttle_bucket(bucket)
        if isinstance(count, bool) or _safe_int(count, 0) <= 0:
            raise ValueError(f"Throttle consume count must be positive: {count!r}")
        step = _safe_int(count, 1)
        eff_limits = self._resolve_throttle_limits(limits)
        stamp_ms = _safe_int(now_override_ms, now_ms()) if now_override_ms is not None else now_ms()
        with self._locked_dir() as dir_fd:
            state = self._read_state_unlocked(dir_fd)
            throttles = self._rollover_throttles(state.get("throttles"), stamp_ms=stamp_ms, slot_id=slot_id)
            if throttles[state_key] + step > eff_limits[clean_bucket]:
                return False, dict(throttles)
            if clean_bucket == "todo_implementations" and throttles["daily_implementations"] + step > eff_limits["daily_implementations"]:
                return False, dict(throttles)
            throttles[state_key] += step
            if clean_bucket == "todo_implementations":
                throttles["daily_implementations"] += step
            state["throttles"] = throttles
            state["agent_name"] = self.agent_name
            state["updated_at_ms"] = stamp_ms
            atomic_write_json_in_dir(dir_fd, STATE_FILENAME, state)
            return True, dict(throttles)

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

                auto_merge_eligible = (
                    compute_community_auto_merge_eligible(
                        repo=repo,
                        additions=norm_pr.get("additions"),
                        deletions=norm_pr.get("deletions"),
                        changed_files=norm_pr.get("changed_files"),
                        file_paths=norm_pr.get("file_paths"),
                        files_has_next_page=bool(norm_pr.get("files_has_next_page", False)),
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
                            "updated_at": updated_at,
                            "trigger_reason": trigger_reason,
                            "is_automated_pr": is_auto_update,
                            "is_community": is_community,
                            "community_auto_merge_eligible": auto_merge_eligible,
                            "additions": norm_pr.get("additions"),
                            "deletions": norm_pr.get("deletions"),
                            "changed_files": norm_pr.get("changed_files"),
                            "file_paths": norm_pr.get("file_paths"),
                            "files_has_next_page": bool(norm_pr.get("files_has_next_page", False)),
                        })
                entry = {**existing, "pr_key": pr_key, "repo": repo, "number": number, "subject_type": "PullRequest", "author": author, "title": title or existing.get("title") or "", "url": resolved_pr_url, "head_sha": head_sha, "ci_state": ci_state, "review_decision": review_decision, "review_requests": review_requests, "unresolved_thread_count": unresolved_thread_count, "labels": labels, "updated_at": updated_at or existing.get("updated_at"), "handled_updated_at": handled_u, "handled_head_sha": handled_sha, "handled_ci_state": handled_ci, "retry_count": retry_count, "trigger_reason": trigger_reason or existing.get("trigger_reason"), "is_automated_pr": is_auto_update, "is_community": is_community, "community_auto_merge_eligible": auto_merge_eligible, "coercion_blocked": False, "in_flight": in_flight, "pending_followup": pending_followup, "last_polled_at_ms": stamp_ms, "updated_at_ms": stamp_ms}
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
            has_newer = bool((was_in_flight and entry.get("pending_followup")) or (seen_u and fin_u and is_timestamp_newer(seen_u, fin_u)) or sha_newer)
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
        status, raw = _http_json_request(url=f"{self.api_url}/bot{bot_cred}/sendMessage", method="POST", headers={"Content-Type": "application/json", "Accept": "application/json"}, raw_body=json.dumps({"chat_id": chat_id, "text": clean_text, "link_preview_options": {"is_disabled": True}}, ensure_ascii=False).encode("utf-8"), timeout=self.timeout, allow_loopback_self_signed=False)
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


OPEN_PRS_GRAPHQL_QUERY_TEMPLATE = (
    "query($endCursor: String) { "
    "search(query: %s, type: ISSUE, first: 100, after: $endCursor) { "
    "pageInfo { hasNextPage endCursor } "
    "nodes { "
    "__typename "
    "... on PullRequest { "
    "id number title body url state isDraft updatedAt headRefName headRefOid reviewDecision additions deletions changedFiles "
    "repository { nameWithOwner isArchived } "
    "author { __typename login } "
    "labels(first: 20) { nodes { name } } "
    "files(first: 25) { pageInfo { hasNextPage } nodes { path } } "
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
    """Subprocess wrapper around `gh-api-safe`, `gh-notification-dismiss`, and scoped `gh` PR label edits."""

    def __init__(self, gh_api_safe_bin: str = "gh-api-safe", gh_notification_dismiss_bin: str = "gh-notification-dismiss", gh_bin: str = "gh", runner: Callable[..., subprocess.CompletedProcess] | None = None, timeout: float = 45.0):
        self.gh_api_safe_bin = gh_api_safe_bin
        self.gh_notification_dismiss_bin = gh_notification_dismiss_bin
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

    def fetch_issue_events(self, repo: str, number: int, timeout: float | None = None) -> list[dict]:
        """Fetch issue or pull request timeline events for label-actor verification."""
        return self.fetch_json_items(f"repos/{repo}/issues/{number}/events?per_page=100", paginate=True, timeout=timeout)

    @staticmethod
    def _validate_pr_label_target(repo: str, number: int, label: str) -> tuple[str, str, str]:
        clean_repo = (repo or "").strip()
        if (
            not clean_repo
            or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*", clean_repo)
            or any(part in (".", "..") for part in clean_repo.split("/"))
            or not is_allowed_notification_repo(clean_repo)
        ):
            raise ValueError(f"Unsupported repository for pull request label edit: {repo!r}")
        clean_num = _safe_int(number, 0)
        if clean_num <= 0:
            raise ValueError(f"Invalid pull request number for label edit: {number!r}")
        clean_label = (label or "").strip()
        if clean_label not in TEAM_LABELS:
            raise ValueError(f"Unsupported pull request team label: {label!r}")
        return clean_repo, f"https://github.com/{clean_repo}/pull/{clean_num}", clean_label

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
        """Remove an allowlisted `team:` label from a pull request via `gh pr edit --remove-label`."""
        _, pr_url, clean_label = self._validate_pr_label_target(repo, number, label)
        cmd = [self.gh_bin, "pr", "edit", pr_url, "--remove-label", clean_label]
        proc = self.runner(cmd, capture_output=True, text=True, timeout=timeout or self.timeout, check=False)
        if proc.returncode != 0:
            err_text = (proc.stderr or proc.stdout or "").strip()
            raise RuntimeError(f"gh pr edit {pr_url} --remove-label {clean_label} exited {proc.returncode}: {err_text}")
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
            agent_name = str(poll_state.get("agent_name") or "skrye")
            poll_interval_secs = max(0, _safe_int(poll_state.get("poll_interval_secs"), 0))
            header_floor_ms = (last_completed_ms + (poll_interval_secs * 1000)) if poll_interval_secs > 0 else 0
            slot_ms = max(compute_next_poll_slot_ms(last_completed_ms, agent_name), header_floor_ms)
            return min(next_poll_at_ms, slot_ms)
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
        provisional_next_ms = compute_next_poll_slot_ms(current_ms, self.state_store.agent_name)
        self.state_store.write_state({"last_poll_started_at_ms": current_ms, "next_poll_at_ms": provisional_next_ms, "last_jitter_ms": 0}, now_override_ms=current_ms)
        return provisional_next_ms, 0

    def poll_once(self, now_override_ms: int | None = None, poll_open_prs: bool = True, poll_open_issues: bool = True) -> dict:
        """Execute one conditional /notifications poll plus the 6-owner open PR and issue polls."""
        start_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        prior_last_modified = self.state_store.read_state().get("last_modified")
        provisional_next_ms, provisional_jitter_ms = self._persist_provisional_next_poll(start_ms)
        status, headers, raw_items = self.gh_client.poll_notifications(last_modified=prior_last_modified if isinstance(prior_last_modified, str) else None)
        finish_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        wait_ms, base_wait_sec, post_jitter_ms = compute_backoff_wait_ms(headers=headers, now_ms_val=finish_ms, rng=self.jitter_rng, status=status, agent_name=self.state_store.agent_name)
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

    def __init__(self, state_store: CompanionStateStore, rpc_client: MoltisRpcClient, data_dir: Path | str, agent_name: str, agent_display_name: str = "", main_model: str = "", review_model: str = "", matrix_client: MatrixClient | None = None, telegram_client: TelegramClient | None = None, telegram_bot_token_path: Path | str | None = None, telegram_allowed_users_path: Path | str | None = None, telegram_api_url: str = DEFAULT_TELEGRAM_API_URL, session_key: str = DEFAULT_GH_SESSION_KEY, room_id: str = DEFAULT_ROOM_ID, schedule_dow: int | None = None, schedule_day_name: str = "", completion_timeout_ms: int | None = None, recovery_deadline_ms: int | None = None, completion_wait_timeout_secs: float | None = None, recovery_wait_timeout_secs: float | None = None, rpc_timeout_secs: float = DEFAULT_RPC_TIMEOUT_SECS, poll_interval_ms: int = DEFAULT_COMPLETION_POLL_INTERVAL_MS, clock: Callable[[], int] = now_ms, sleeper: Callable[[float], None] = time.sleep):
        self.state_store = state_store
        self.rpc_client = rpc_client
        self.data_dir = Path(data_dir)
        self.agent_name = normalize_agent_name(agent_name)
        self.agent_display_name = derive_display_name(self.agent_name, agent_display_name)
        self.main_model = (main_model or "").strip()
        self.review_model = (review_model or self.main_model).strip()
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

    def build_dispatch_prompt(self, *, dispatch_id: str, kind: str, thread_id: str | None = None, repo: str | None = None, number: int | None = None, subject_kind: str | None = None, head_sha: str | None = None, trigger_reason: str | None = None, comment_id: int | str | None = None, review_id: int | str | None = None, trusted_item_id: int | str | None = None, community_auto_merge_eligible: bool | None = None, team_label: str | None = None, triaged_head_sha: str | None = None, head_sha_changed: bool = False, linear_issue_id: str | None = None, linear_issue_identifier: str | None = None, linear_issue_url: str | None = None, github_url: str | None = None, bypass_reasons: Iterable[str] | None = None, lane_a_polish_notes: str | None = None, extra_instructions: str = "") -> str:
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
            ("github_url", github_url),
        ):
            clean_val = str(meta_val).strip() if meta_val is not None else ""
            if clean_val:
                meta_lines.append(f"{meta_key}: {clean_val}")
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

    def _finalize_completed_dispatch(self, active_record: dict, now_override_ms: int | None = None) -> dict:
        stamp_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        kind = str(active_record.get("kind") or "")
        state_key = str(active_record.get("state_key") or active_record.get("thread_id") or "").strip()
        preserve_sha = bool(active_record.get("head_sha_changed"))
        record_triaged = kind in ("community_triage", "community_auto_review", "community_pr_blind_review", "community_pr_lane_b_review", "team:review") and not preserve_sha
        watermark_result = self.state_store.complete_thread_review(state_key, handled_updated_at=active_record.get("updated_at"), handled_head_sha=active_record.get("head_sha"), handled_ci_state=active_record.get("ci_state"), completed_revision=active_record.get("revision"), team_label=str(active_record.get("team_label") or "") or None, team_label_event_key=str(active_record.get("team_label_event_key") or "") or None, preserve_handled_head_sha=preserve_sha, record_triaged_head_sha=record_triaged, apply_cooldown=True, now_override_ms=stamp_ms) if state_key else None
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
                if active_record.get("kind") not in SILENT_TELEGRAM_DISPATCH_KINDS:
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

    def execute_dispatch(self, *, kind: str, model: str | None = None, is_automated_pr: bool = False, session_key: str | None = None, thread_id: str | None = None, state_key: str | None = None, repo: str | None = None, number: int | None = None, subject_kind: str | None = None, head_sha: str | None = None, ci_state: str | None = None, updated_at: str | None = None, trigger_reason: str | None = None, comment_id: int | str | None = None, review_id: int | str | None = None, trusted_item_id: int | str | None = None, community_auto_merge_eligible: bool | None = None, team_label: str | None = None, team_label_event_key: str | None = None, triaged_head_sha: str | None = None, head_sha_changed: bool = False, linear_issue_id: str | None = None, linear_issue_identifier: str | None = None, linear_issue_url: str | None = None, github_url: str | None = None, bypass_reasons: Iterable[str] | None = None, lane_a_polish_notes: str | None = None, revision: str | None = None, sweep_date: str | None = None, extra_instructions: str = "", dispatch_id: str | None = None, now_override_ms: int | None = None, **_ignored: object) -> dict:
        """Serialise a model turn under coordinator.lock while allowing state.json updates under companion.lock."""
        with self.state_store.coordinator_lock():
            recovery = self._recover_unlocked(now_override_ms=now_override_ms)
            start_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
            resolved_session_key = (session_key or self.session_key or DEFAULT_GH_SESSION_KEY).strip()
            is_issue_triage = kind == "community_triage" and str(subject_kind or "").strip().lower() == "issue"
            use_review_model = (kind == "targeted" and not is_automated_pr) or (kind in MODE_1B_DISPATCH_KINDS and not is_issue_triage) or (kind in LINEAR_PR_DISPATCH_KINDS)
            resolved_model = (model or ((self.review_model or self.main_model) if use_review_model else self.main_model)).strip()
            resolved_dispatch_id = (dispatch_id or f"ghd-{self.agent_name}-{uuid.uuid4().hex}").strip()
            eff_state_key = (state_key or thread_id or (make_pr_key(repo, number) if repo and number else "")).strip()

            if eff_state_key:
                wm_entry = self.state_store.mark_thread_in_flight(eff_state_key, updated_at=updated_at, head_sha=head_sha, ci_state=ci_state, now_override_ms=start_ms)
                updated_at, head_sha, ci_state = updated_at or wm_entry.get("in_flight_updated_at"), head_sha or wm_entry.get("in_flight_head_sha"), ci_state or wm_entry.get("in_flight_ci_state")
            if kind in ("reconcile_sweep", "weekly_sweep"):
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
                ("github_url", str(github_url).strip() if github_url is not None else ""),
                ("revision", revision),
                ("sweep_date", sweep_date),
            ):
                if v is not None and v != "":
                    active_record[k] = v
            if head_sha_changed:
                active_record["head_sha_changed"] = True
            self.state_store.write_active_dispatch(active_record, now_override_ms=start_ms)

            start_notice_text = format_start_of_work_notice(agent_display_name=self.agent_display_name, kind=kind, repo=repo, number=number, subject_kind=subject_kind, trigger_reason=trigger_reason, sweep_date=sweep_date, schedule_day_name=self.schedule_day_name)
            start_notice_sent, start_notice_error = False, None
            prompt_message = self.build_dispatch_prompt(dispatch_id=resolved_dispatch_id, kind=kind, thread_id=thread_id, repo=repo, number=number, subject_kind=subject_kind, head_sha=head_sha, trigger_reason=trigger_reason, comment_id=comment_id, review_id=review_id, trusted_item_id=trusted_item_id, community_auto_merge_eligible=community_auto_merge_eligible, team_label=team_label, triaged_head_sha=triaged_head_sha, head_sha_changed=head_sha_changed, linear_issue_id=linear_issue_id, linear_issue_identifier=linear_issue_identifier, linear_issue_url=linear_issue_url, github_url=github_url, bypass_reasons=bypass_reasons, lane_a_polish_notes=lane_a_polish_notes, extra_instructions=extra_instructions)

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
    ):
        self.state_store = state_store
        self.gh_client = gh_client
        self.poller = poller
        self.trust_filter = trust_filter
        self.execution_coordinator = execution_coordinator
        if self.trust_filter.telegram_client is None and self.execution_coordinator.telegram_client is not None:
            self.trust_filter.telegram_client = self.execution_coordinator.telegram_client
        self.matrix_client = matrix_client
        self.linear_client = linear_client
        self.read_only_trial = bool(read_only_trial)
        self.reconcile_interval_ms = max(60_000, _safe_int(reconcile_interval_ms, RECONCILE_SWEEP_INTERVAL_MS))
        self.clock = clock

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

    def _create_linear_triage_stubs(self, actionable_issues: Iterable[dict], *, slot_id: str, current_ms: int) -> list[dict]:
        if self.linear_client is None or self.state_store.agent_name not in SWEEP_AGENT_ORDER:
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
                sys.stderr.write(f"moltis-github-companion linear-triage-stub warning ({issue_key}): {exc}\n")
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

    def _promote_team_implement_issue_to_linear(self, *, cand: dict, cand_key: str, verified_event_key: str | None, current_ms: int) -> dict | None:
        if self.linear_client is None or self.state_store.agent_name not in SWEEP_AGENT_ORDER:
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
            sys.stderr.write(f"moltis-github-companion linear-promote warning ({cand_key}): {exc}\n")
            return None
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
        if self.linear_client is None or self.state_store.agent_name not in SWEEP_AGENT_ORDER:
            return None
        try:
            raw_issues = self.linear_client.list_project_issues_by_state(("Triage", "Backlog", "Todo", "In Progress", "In Review"))
        except Exception as exc:
            sys.stderr.write(f"moltis-github-companion linear-poll warning ({self.state_store.agent_name}): {exc}\n")
            return None
        return [item for item in (raw_issues or ()) if isinstance(item, dict)]

    def _sync_closed_github_items_to_linear(self, active_linear_issues: Iterable[dict], *, poll_result: dict, current_ms: int) -> list[dict]:
        _ = current_ms
        if (
            self.linear_client is None
            or self.state_store.agent_name not in SWEEP_AGENT_ORDER
            or poll_result.get("open_prs_poll_error") is not None
            or poll_result.get("open_issues_poll_error") is not None
            or poll_result.get("status") in (403, 429)
        ):
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
            state_obj = _as_dict(linear_issue.get("state"))
            state_name = str(state_obj.get("name") or "").strip().lower()
            state_type = str(state_obj.get("type") or "").strip().lower()
            if state_type in ("completed", "canceled", "cancelled", "duplicate") or state_name in ("done", "canceled", "cancelled", "duplicate"):
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
                sys.stderr.write(f"moltis-github-companion linear-close-sync update warning ({item_key} / {linear_id}): {exc}\n")
                continue
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
        if not isinstance(linear_issue, dict) or linear_issue.get("archivedAt"):
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
            dispatches.append(
                self.execution_coordinator.execute_dispatch(
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
                    github_url=cand["github_url"],
                    now_override_ms=now_override_ms,
                )
            )
        return dispatches

    def _dispatch_linear_todo_implementations(self, active_linear_issues: Iterable[dict], *, slot_id: str, dispatched_targets: set[str], current_ms: int, now_override_ms: int | None) -> list[dict]:
        if self.linear_client is None or self.state_store.agent_name not in SWEEP_AGENT_ORDER:
            return []
        dispatches: list[dict] = []
        for linear_issue in active_linear_issues or ():
            cand = self._resolve_owned_linear_issue_candidate(linear_issue, dispatched_targets=dispatched_targets)
            if cand is None or (cand["state_name"] != "todo" and cand["state_type"] != "unstarted"):
                continue
            if not self.state_store.can_consume_throttle("todo_implementations", slot_id=slot_id, now_override_ms=current_ms):
                break
            try:
                self.linear_client.update_issue(cand["linear_id"], state="In Progress")
            except Exception as exc:
                sys.stderr.write(f"moltis-github-companion linear-todo-claim warning ({cand['issue_key']} / {cand['linear_id']}): {exc}\n")
                continue
            consumed, _ = self.state_store.consume_throttle("todo_implementations", slot_id=slot_id, now_override_ms=current_ms)
            if not consumed:
                with contextlib.suppress(Exception):
                    self.linear_client.update_issue(cand["linear_id"], state="Todo")
                break
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
                github_url=cand["github_url"],
                now_override_ms=now_override_ms,
            )
            if not res.get("task_succeeded"):
                try:
                    self.linear_client.update_issue(cand["linear_id"], state="Todo")
                except Exception as exc:
                    sys.stderr.write(f"moltis-github-companion linear-todo-revert warning ({cand['issue_key']} / {cand['linear_id']}): {exc}\n")
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
                github_url=pr_url,
                lane_a_polish_notes=lane_a_polish,
                now_override_ms=now_override_ms,
            )
            action = "lane_a_merge_failed"
            ping: dict | None = None
            if dispatch_res.get("task_succeeded"):
                merge_outcome, merge_detail = parse_lane_a_merge_reply(
                    str(dispatch_res.get("reply_text") or ""),
                    repo=repo,
                    number=number,
                    linear_url=linear_url,
                )
                if merge_outcome == "merged":
                    action = "lane_a_merged"
                    try:
                        self.linear_client.update_issue(clean_linear_id, state="Done")
                    except Exception as exc:
                        sys.stderr.write(f"moltis-github-companion lane-a-done warning ({pr_key} / {clean_linear_id}): {exc}\n")
                elif merge_outcome == "needs_decision":
                    action = "lane_a_merge_needs_decision"
                    try:
                        self.linear_client.update_issue(
                            clean_linear_id,
                            state="Backlog",
                            add_labels=("needs-decision",),
                            remove_labels=("ready-to-merge",),
                        )
                    except Exception as exc:
                        sys.stderr.write(f"moltis-github-companion lane-a-escalate warning ({pr_key} / {clean_linear_id}): {exc}\n")
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
            return review_res, None
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
        has_own_verdict = any(
            str(v.get("agent") or "").strip().lower() == self.state_store.agent_name
            or str(v.get("model_family") or "").strip().lower() == own_family
            for v in existing_verdicts
        )
        if not has_own_verdict:
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
        auto_merge_eligible: bool,
        thread_id: str | None,
        linear_id: str,
        linear_identifier: str | None,
        linear_url: str | None,
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
        bypass_reasons = compute_lane_a_bypass_reasons(
            repo=repo,
            additions=additions,  # type: ignore[arg-type]
            deletions=deletions,  # type: ignore[arg-type]
            changed_files=changed_files,  # type: ignore[arg-type]
            file_paths=file_paths,  # type: ignore[arg-type]
            files_has_next_page=files_has_next_page,
            ci_state=ci_state,
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
            github_url=pr_url,
            bypass_reasons=bypass_reasons,
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
        lane_b_verdict, lane_b_summary = parse_lane_b_reply(str(lane_b_res.get("reply_text") or ""))
        if lane_b_verdict == "ready-to-merge":
            add_lbls, rem_lbls = ("ready-to-merge",), ("needs-decision",)
        else:
            add_lbls, rem_lbls = ("needs-decision",), ("ready-to-merge",)
        try:
            self.linear_client.update_issue(
                linear_id,
                state="Backlog",
                add_labels=add_lbls,
                remove_labels=rem_lbls,
            )
        except Exception as exc:
            sys.stderr.write(f"moltis-github-companion lane-b-update warning ({pr_key} / {linear_id}): {exc}\n")
            return "update_failed"
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
    ) -> dict:
        dispatches: list[dict] = []
        linear_pr_actions: list[dict] = []
        notifications: list[dict] = []
        if self.linear_client is None or self.state_store.agent_name not in SWEEP_AGENT_ORDER:
            return {
                "dispatches": dispatches,
                "linear_pr_actions": linear_pr_actions,
                "needs_decision_notifications": notifications,
            }

        processed_pr_keys: set[str] = set()
        own_family = MODEL_FAMILY_BY_AGENT.get(self.state_store.agent_name, "gemini")

        for pr_item in actionable_prs or ():
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
            raw_eligible = pr_item.get("community_auto_merge_eligible")
            auto_merge_eligible = (
                bool(raw_eligible)
                if isinstance(raw_eligible, bool)
                else compute_community_auto_merge_eligible(
                    repo=repo,
                    additions=additions,
                    deletions=deletions,
                    changed_files=changed_files,
                    file_paths=file_paths,
                    files_has_next_page=files_has_next_page,
                    enabled=self.state_store.community_auto_merge_enabled,
                    max_lines=self.state_store.community_auto_merge_max_lines,
                    max_files=self.state_store.community_auto_merge_max_files,
                    excluded_repos=self.state_store.community_auto_merge_excluded_repos,
                )
            )
            is_lane_a = bool(auto_merge_eligible) and ci_state in ("SUCCESS", "NONE") and not has_dnm
            initial_state = "In Review" if is_lane_a else "Backlog"

            try:
                linear_issue = self.linear_client.ensure_issue_for_github_item(
                    github_url=pr_url,
                    title=title,
                    repo=repo,
                    item_kind="PR",
                    state=initial_state,
                )
                linear_id = str(linear_issue.get("id") or "").strip()
                if not linear_id:
                    raise RuntimeError("Linear issue response missing id")
                linear_identifier = str(linear_issue.get("identifier") or "").strip() or None
                linear_url = str(linear_issue.get("url") or "").strip() or None
            except Exception as exc:
                sys.stderr.write(f"moltis-github-companion linear-pr-ensure warning ({pr_key}): {exc}\n")
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

            thread_id = str(pr_item.get("thread_id") or pr_entry.get("thread_id") or "").strip() or None
            if is_lane_a:
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
                self._run_lane_b_pr_review(
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
                    auto_merge_eligible=bool(auto_merge_eligible),
                    thread_id=thread_id,
                    linear_id=linear_id,
                    linear_identifier=linear_identifier,
                    linear_url=linear_url,
                    slot_id=slot_id,
                    dispatched_targets=dispatched_targets,
                    processed_pr_keys=processed_pr_keys,
                    dispatches=dispatches,
                    linear_pr_actions=linear_pr_actions,
                    notifications=notifications,
                    current_ms=current_ms,
                    now_override_ms=now_override_ms,
                )

        for linear_issue in active_linear_issues or ():
            if not isinstance(linear_issue, dict) or linear_issue.get("archivedAt"):
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
                    and ci_state in ("SUCCESS", "NONE")
                    and pr_entry.get("handled_head_sha") != head_sha
                    and compute_community_auto_merge_eligible(
                        repo=repo,
                        additions=live_pr.get("additions"),
                        deletions=live_pr.get("deletions"),
                        changed_files=live_pr.get("changed_files"),
                        file_paths=live_pr.get("file_paths"),
                        files_has_next_page=bool(live_pr.get("files_has_next_page", False)),
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
                    has_own_verdict = any(
                        str(v.get("agent") or "").strip().lower() == self.state_store.agent_name
                        or str(v.get("model_family") or "").strip().lower() == own_family
                        for v in existing_verdicts
                    )
                    if not has_own_verdict:
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
                        now_override_ms=now_override_ms,
                    )
                    dispatches.append(merge_res)
                    ping = None
                    action = "linear_todo_merge_blocked_sha_changed" if sha_changed else "linear_todo_merge_failed"
                    if merge_res.get("task_succeeded"):
                        if sha_changed:
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
                        else:
                            merge_outcome, merge_detail = parse_linear_todo_merge_reply(
                                str(merge_res.get("reply_text") or ""),
                                repo=repo,
                                number=number,
                                linear_url=linear_url,
                            )
                            if merge_outcome == "merged":
                                action = "linear_todo_merged"
                                try:
                                    self.linear_client.update_issue(linear_id, state="Done")
                                except Exception as exc:
                                    sys.stderr.write(f"moltis-github-companion linear-todo-merge-done warning ({pr_key} / {linear_id}): {exc}\n")
                            elif merge_outcome in ("blocked", "needs_decision"):
                                action = "linear_todo_merge_blocked" if merge_outcome == "blocked" else "linear_todo_merge_needs_decision"
                                if applied_team_merge:
                                    with contextlib.suppress(Exception):
                                        self.gh_client.remove_pull_request_label(repo, number, "team:merge")
                                with contextlib.suppress(Exception):
                                    self.linear_client.update_issue(
                                        linear_id,
                                        state="Backlog",
                                        add_labels=("needs-decision",),
                                        remove_labels=("ready-to-merge",),
                                    )
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
                            elif applied_team_merge:
                                with contextlib.suppress(Exception):
                                    self.gh_client.remove_pull_request_label(repo, number, "team:merge")
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
                        now_override_ms=now_override_ms,
                    )
                    dispatches.append(review_res)
                    if review_res.get("task_succeeded"):
                        if head_sha:
                            self.state_store.update_thread_state(
                                pr_key,
                                {"linear_todo_reviewed_sha": head_sha},
                                now_override_ms=current_ms,
                            )
                        try:
                            self.linear_client.update_issue(linear_id, state="In Review")
                        except Exception as exc:
                            sys.stderr.write(f"moltis-github-companion linear-todo-review-update warning ({pr_key} / {linear_id}): {exc}\n")
                    linear_pr_actions.append({
                        "action": "linear_todo_reviewed" if review_res.get("task_succeeded") else "linear_todo_review_failed",
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
                    live_pr.get("is_draft")
                    or str(live_pr.get("state") or "OPEN").upper() != "OPEN"
                    or is_trusted_github_actor(live_pr.get("author"))
                    or not head_sha
                    or bool(pr_entry.get("in_flight"))
                ):
                    continue
                handled_sha = str(pr_entry.get("handled_head_sha") or "").strip()
                triaged_sha = str(pr_entry.get("triaged_head_sha") or "").strip()
                if handled_sha == head_sha and (not triaged_sha or triaged_sha == head_sha):
                    continue

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

                has_dnm = has_do_not_merge_label(pr_labels)
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
                    enabled=self.state_store.community_auto_merge_enabled,
                    max_lines=self.state_store.community_auto_merge_max_lines,
                    max_files=self.state_store.community_auto_merge_max_files,
                    excluded_repos=self.state_store.community_auto_merge_excluded_repos,
                )
                is_lane_a = bool(auto_merge_eligible) and ci_state in ("SUCCESS", "NONE") and not has_dnm

                if _safe_int(pr_entry.get("followup_cooldown_until_ms"), 0) > current_ms:
                    _strip_stale_ready_to_merge()
                    continue
                if auto_merge_eligible and not has_dnm and ci_state == "PENDING":
                    _strip_stale_ready_to_merge()
                    continue

                if is_lane_a:
                    try:
                        self.linear_client.update_issue(
                            linear_id,
                            state="In Review",
                            remove_labels=("ready-to-merge", "needs-decision"),
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
                        auto_merge_eligible=bool(auto_merge_eligible),
                        thread_id=thread_id,
                        linear_id=linear_id,
                        linear_identifier=linear_identifier,
                        linear_url=linear_url,
                        slot_id=slot_id,
                        dispatched_targets=dispatched_targets,
                        processed_pr_keys=processed_pr_keys,
                        dispatches=dispatches,
                        linear_pr_actions=linear_pr_actions,
                        notifications=notifications,
                        current_ms=current_ms,
                        now_override_ms=now_override_ms,
                    )
                    if lane_b_outcome in ("throttled", "dispatch_failed"):
                        _strip_stale_ready_to_merge()

        return {
            "dispatches": dispatches,
            "linear_pr_actions": linear_pr_actions,
            "needs_decision_notifications": notifications,
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
            if ci_state not in ("SUCCESS", "NONE"):
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
            if not isinstance(linear_issue, dict) or linear_issue.get("archivedAt"):
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

    def run_cycle(self, *, run_sweeps_if_due: bool = True, now_override_ms: int | None = None) -> dict:
        if self.matrix_client is not None:
            with contextlib.suppress(Exception):
                self.matrix_client.flush_outbox()

        poll_result = self.poller.poll_once(now_override_ms=now_override_ms)
        dismissed_threads: list[str] = list(poll_result.get("dismissed_threads") or [])
        if self.read_only_trial:
            return {"status": "ok", "recovery": {"status": "read_only_trial", "can_dispatch": False}, "poll_result": poll_result, "targeted_dispatches": [], "dismissed_threads": dismissed_threads, "sweep_dispatch": None, "linear_triage_stubs": [], "linear_promoted_todos": [], "linear_synced_closed": [], "signoff_notifications": [], "linear_pr_actions": [], "needs_decision_notifications": [], "traya_blind_reviews": []}
        if self._is_coordinator_busy():
            return {"status": "turn_in_progress", "recovery": {"status": "busy", "can_dispatch": False}, "poll_result": poll_result, "targeted_dispatches": [], "dismissed_threads": dismissed_threads, "sweep_dispatch": None, "linear_triage_stubs": [], "linear_promoted_todos": [], "linear_synced_closed": [], "signoff_notifications": [], "linear_pr_actions": [], "needs_decision_notifications": [], "traya_blind_reviews": []}

        recovery = self.execution_coordinator.recover_active_dispatch(now_override_ms=now_override_ms)
        current_ms = _safe_int(now_override_ms, self.clock()) if now_override_ms is not None else self.clock()
        slot_id = compute_throttle_slot_id(current_ms, self.state_store.agent_name)
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
            dispatched_targets.add(dedup_key)
            targeted_dispatches.append(self.execution_coordinator.execute_dispatch(kind="targeted", is_automated_pr=bool(prep.get("is_automated_pr") or entry.get("is_automated_pr")), thread_id=tid, state_key=tid, repo=prep.get("repo") or repo, number=prep.get("number") or number, subject_kind=prep.get("kind") or entry.get("subject_type"), head_sha=prep.get("head_sha") or entry.get("head_sha"), ci_state=entry.get("ci_state"), updated_at=entry.get("updated_at"), trigger_reason=prep.get("trigger_reason") or entry.get("reason"), comment_id=prep.get("comment_id"), review_id=prep.get("review_id"), trusted_item_id=prep.get("trusted_item_id"), now_override_ms=now_override_ms))

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

        linear_promoted_todos: list[dict] = []
        for cand in poll_result.get("team_label_candidates") or []:
            if not isinstance(cand, dict):
                continue
            cand_key = str(cand.get("key") or "").strip()
            cand_repo = str(cand.get("repo") or "").strip()
            cand_num = _safe_int(cand.get("number"), 0) or None
            cand_labels = [str(lbl) for lbl in (cand.get("team_labels") or []) if str(lbl) in TEAM_LABELS]
            if not cand_key or not cand_repo or cand_num is None or not cand_labels or cand_key in dispatched_targets:
                continue
            cand_entry = _as_dict(self.state_store.get_thread_state(cand_key))
            if _safe_int(cand_entry.get("retry_count"), 0) >= MAX_THREAD_FAILURE_RETRIES:
                continue
            try:
                events = self.gh_client.fetch_issue_events(cand_repo, cand_num)
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
                )
                if promoted is not None:
                    linear_promoted_todos.append(promoted)
                continue
            cand_head_sha = str(cand.get("head_sha") or "").strip() or None
            triaged_sha = str(cand.get("triaged_head_sha") or cand_entry.get("triaged_head_sha") or "").strip() or None
            sha_changed = bool(verified_label == "team:merge" and triaged_sha and cand_head_sha and triaged_sha != cand_head_sha)
            dispatched_targets.add(cand_key)
            targeted_dispatches.append(
                self.execution_coordinator.execute_dispatch(
                    kind=verified_label,
                    is_automated_pr=False,
                    thread_id=str(cand.get("thread_id") or "").strip() or None,
                    state_key=cand_key,
                    repo=cand_repo,
                    number=cand_num,
                    subject_kind=cand_kind,
                    head_sha=cand_head_sha,
                    ci_state=str(cand.get("ci_state") or "") or None,
                    updated_at=str(cand.get("updated_at") or "") or None,
                    trigger_reason=TEAM_LABEL_TRIGGER_REASONS.get(verified_label, verified_label),
                    community_auto_merge_eligible=cand.get("community_auto_merge_eligible"),
                    team_label=verified_label,
                    team_label_event_key=verified_event_key,
                    triaged_head_sha=triaged_sha,
                    head_sha_changed=sha_changed,
                    now_override_ms=now_override_ms,
                )
            )

        open_prs_by_key: dict[str, dict] = {}
        for raw_open_pr in poll_result.get("open_pull_requests") or ():
            if not isinstance(raw_open_pr, dict):
                continue
            pk = str(raw_open_pr.get("pr_key") or "").strip().lower()
            if not pk:
                r_name, r_num = str(raw_open_pr.get("repo") or "").strip(), _safe_int(raw_open_pr.get("number"), 0)
                if r_name and r_num > 0:
                    pk = make_pr_key(r_name, r_num)
            if pk:
                open_prs_by_key[pk] = raw_open_pr

        community_actionable_prs: list[dict] = []
        for pr_item in poll_result.get("actionable_prs") or []:
            if not isinstance(pr_item, dict):
                continue
            if self.linear_client is not None and bool(pr_item.get("is_community")):
                community_actionable_prs.append(pr_item)
                continue
            pr_key = str(pr_item.get("key") or "").strip()
            pr_entry = _as_dict(self.state_store.get_thread_state(pr_key))
            if not pr_key or pr_key in dispatched_targets or _safe_int(pr_entry.get("retry_count"), 0) >= MAX_THREAD_FAILURE_RETRIES:
                continue
            trig_reason = str(pr_item.get("trigger_reason") or "open_pr_poll")
            if trig_reason != "ci_green_after_approval" and _safe_int(pr_entry.get("followup_cooldown_until_ms"), 0) > current_ms:
                continue
            dispatched_targets.add(pr_key)
            pr_dispatch_kind = str(pr_item.get("dispatch_kind") or "targeted")
            targeted_dispatches.append(self.execution_coordinator.execute_dispatch(kind=pr_dispatch_kind, is_automated_pr=bool(pr_item.get("is_automated_pr") or pr_entry.get("is_automated_pr")), thread_id=str(pr_item.get("thread_id") or "").strip() or None, state_key=pr_key, repo=str(pr_item.get("repo") or ""), number=_safe_int(pr_item.get("number"), 0) or None, subject_kind="PullRequest", head_sha=str(pr_item.get("head_sha") or "") or None, ci_state=str(pr_item.get("ci_state") or "") or None, updated_at=str(pr_item.get("updated_at") or "") or None, trigger_reason=trig_reason, community_auto_merge_eligible=pr_item.get("community_auto_merge_eligible"), triaged_head_sha=str(pr_entry.get("triaged_head_sha") or "") or None, now_override_ms=now_override_ms))

        linear_triage_stubs = self._create_linear_triage_stubs(
            poll_result.get("actionable_issues") or [],
            slot_id=slot_id,
            current_ms=current_ms,
        )

        linear_synced_closed: list[dict] = []
        linear_pr_actions: list[dict] = []
        needs_decision_notifications: list[dict] = []
        traya_blind_reviews: list[dict] = []
        if self.linear_client is not None and self.state_store.agent_name in SWEEP_AGENT_ORDER:
            active_linear_issues = self._poll_active_linear_issues()
            remaining_linear_issues: list[dict] = []
            if active_linear_issues:
                linear_synced_closed = self._sync_closed_github_items_to_linear(
                    active_linear_issues,
                    poll_result=poll_result,
                    current_ms=current_ms,
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
            pr_pipeline = self._process_linear_community_prs(
                community_actionable_prs,
                active_linear_issues=remaining_linear_issues,
                open_prs_by_key=open_prs_by_key,
                slot_id=slot_id,
                dispatched_targets=dispatched_targets,
                current_ms=current_ms,
                now_override_ms=now_override_ms,
            )
            targeted_dispatches.extend(pr_pipeline["dispatches"])
            linear_pr_actions.extend(pr_pipeline["linear_pr_actions"])
            needs_decision_notifications.extend(pr_pipeline["needs_decision_notifications"])
            if remaining_linear_issues:
                targeted_dispatches.extend(
                    self._dispatch_linear_triage_research(
                        remaining_linear_issues,
                        slot_id=slot_id,
                        dispatched_targets=dispatched_targets,
                        current_ms=current_ms,
                        now_override_ms=now_override_ms,
                    )
                )
                targeted_dispatches.extend(
                    self._dispatch_linear_todo_implementations(
                        remaining_linear_issues,
                        slot_id=slot_id,
                        dispatched_targets=dispatched_targets,
                        current_ms=current_ms,
                        now_override_ms=now_override_ms,
                    )
                )
        elif self.linear_client is not None and self.state_store.agent_name == "traya" and poll_result.get("open_prs_poll_error") is None:
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
        if run_sweeps_if_due:
            weekly_due, today_str = self.is_weekly_sweep_due(now_override_ms=now_override_ms)
            if weekly_due or self.is_reconcile_sweep_due(now_override_ms=now_override_ms):
                sweep_dispatch = self.execution_coordinator.execute_dispatch(kind="weekly_sweep" if weekly_due else "reconcile_sweep", sweep_date=today_str if weekly_due else None, now_override_ms=now_override_ms)

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
            "needs_decision_notifications": needs_decision_notifications,
            "traya_blind_reviews": traya_blind_reviews,
        }


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Moltis GitHub notification and pull-request companion")
    parser.add_argument("--agent-name", default=os.environ.get("MOLTIS_GITHUB_COMPANION_AGENT_NAME") or os.environ.get("MOLTIS_COMPANION_AGENT_NAME", ""))
    parser.add_argument("--agent-display-name", default=os.environ.get("MOLTIS_GITHUB_COMPANION_AGENT_DISPLAY_NAME") or os.environ.get("MOLTIS_COMPANION_AGENT_DISPLAY_NAME", ""))
    parser.add_argument("--main-model", default=os.environ.get("MOLTIS_GITHUB_COMPANION_MAIN_MODEL") or os.environ.get("MOLTIS_COMPANION_MAIN_MODEL", ""))
    parser.add_argument("--review-model", default=os.environ.get("MOLTIS_GITHUB_COMPANION_REVIEW_MODEL") or os.environ.get("MOLTIS_COMPANION_REVIEW_MODEL", ""))
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
    parser.add_argument("--read-only-trial", action="store_true", default=os.environ.get("MOLTIS_GITHUB_COMPANION_READ_ONLY_TRIAL", "").strip() in ("1", "true", "yes"))
    parser.add_argument("--reprocess-community", action="store_true")
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
    main_model = (args.main_model or "").strip()
    cam_cfg = resolve_community_auto_merge_config(
        enabled=getattr(args, "community_auto_merge_enabled", "") or None,
        max_lines=getattr(args, "community_auto_merge_max_lines", "") or None,
        max_files=getattr(args, "community_auto_merge_max_files", "") or None,
        excluded_repos=getattr(args, "community_auto_merge_excluded_repos", "") or None,
    )
    return {
        "agent_name": agent_name, "agent_display_name": derive_display_name(agent_name, args.agent_display_name),
        "main_model": main_model,
        "review_model": (getattr(args, "review_model", "") or os.environ.get("MOLTIS_GITHUB_COMPANION_REVIEW_MODEL", "") or main_model).strip(),
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
        "read_only_trial": bool(getattr(args, "read_only_trial", False)),
        "reprocess_community": bool(getattr(args, "reprocess_community", False)),
        "once": bool(getattr(args, "once", False)),
    }


def main(argv: list[str] | None = None) -> int:
    cfg = resolve_runtime_config(build_arg_parser().parse_args(argv))
    store = CompanionStateStore(
        state_dir=cfg["state_dir"],
        agent_name=cfg["agent_name"],
        room_id=cfg["room_id"],
        community_auto_merge_enabled=cfg["community_auto_merge_enabled"],
        community_auto_merge_max_lines=cfg["community_auto_merge_max_lines"],
        community_auto_merge_max_files=cfg["community_auto_merge_max_files"],
        community_auto_merge_excluded_repos=cfg["community_auto_merge_excluded_repos"],
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
    poller = NotificationPoller(state_store=store, gh_client=gh_client, read_only_trial=cfg["read_only_trial"])
    trust_filter = TrustFilterAndSnapshotBuilder(state_store=store, gh_client=gh_client, matrix_client=matrix_client, telegram_client=telegram_client, agent_name=cfg["agent_name"])
    execution_coordinator = LocalExecutionCoordinator(state_store=store, rpc_client=rpc_client, data_dir=cfg["data_dir"], agent_name=cfg["agent_name"], agent_display_name=cfg["agent_display_name"], main_model=cfg["main_model"], review_model=cfg["review_model"], matrix_client=matrix_client, telegram_client=telegram_client, room_id=cfg["room_id"], schedule_dow=cfg["schedule_dow"], schedule_day_name=cfg["schedule_day_name"])
    linear_client = linear_sync.LinearSyncClient.from_env()
    runner = GithubCompanionRunner(state_store=store, gh_client=gh_client, poller=poller, trust_filter=trust_filter, execution_coordinator=execution_coordinator, matrix_client=matrix_client, read_only_trial=cfg["read_only_trial"], linear_client=linear_client)
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
