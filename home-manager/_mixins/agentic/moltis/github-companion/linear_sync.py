"""Linear GraphQL sync client for Moltis GitHub companion."""

from __future__ import annotations

import contextlib
import fcntl
import hashlib
import importlib
import importlib.util
import json
import math
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable, Iterable, Mapping
from pathlib import Path
from types import ModuleType

DEFAULT_GRAPHQL_URL = "https://api.linear.app/graphql"
DEFAULT_TEAM_KEY = "WW"
DEFAULT_PROJECT_NAME = "Community Contributions"
REPOSITORY_LABEL_GROUP = "Repository"
WORKFLOW_LABELS = (
    "Issue",
    "PR",
    "ready-to-implement",
    "sign-off-required",
    "ready-to-merge",
    "needs-decision",
)
DEFAULT_TIMEOUT_SECS = 20.0
MAX_RESPONSE_BYTES = 4 * 1048576
BLIND_REVIEW_MARKER_PREFIX = "moltis:blind-review:v1"
GITHUB_URL_MARKER_PREFIX = "moltis:github-url:v1"

ENV_LINEAR_CLIENT_ID_PATH = "MOLTIS_GITHUB_COMPANION_LINEAR_CLIENT_ID_PATH"
ENV_LINEAR_CLIENT_SECRET_PATH = "MOLTIS_GITHUB_COMPANION_LINEAR_CLIENT_SECRET_PATH"
ENV_LINEAR_TOKEN_CACHE_DIR = "MOLTIS_GITHUB_COMPANION_LINEAR_TOKEN_CACHE_DIR"
ENV_LINEAR_TEAM_KEY = "MOLTIS_GITHUB_COMPANION_LINEAR_TEAM_KEY"
ENV_LINEAR_API_URL = "MOLTIS_GITHUB_COMPANION_LINEAR_API_URL"

_WORKFLOW_LABEL_BY_LOWER: dict[str, str] = {label.lower(): label for label in WORKFLOW_LABELS}
_REPO_SLUG_RE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
_BLIND_REVIEW_MARKER_RE = re.compile(
    r"\A\s*<!--\s*" + re.escape(BLIND_REVIEW_MARKER_PREFIX) + r"\s+(\{[^\r\n]*?\})\s*-->[ \t]*(?:\r?\n|\Z)",
)
_GITHUB_URL_MARKER_RE = re.compile(
    r"\A\s*<!--\s*" + re.escape(GITHUB_URL_MARKER_PREFIX) + r"\s+(\{[^\r\n]*?\})\s*-->[ \t]*(?:\r?\n|\Z)",
)

_CANONICAL_STATE_ALIASES: dict[str, str] = {
    "triage": "Triage",
    "backlog": "Backlog",
    "todo": "Todo",
    "unstarted": "Todo",
    "in progress": "In Progress",
    "in_progress": "In Progress",
    "in review": "In Review",
    "in_review": "In Review",
    "done": "Done",
    "completed": "Done",
    "canceled": "Canceled",
    "cancelled": "Canceled",
    "duplicate": "Duplicate",
}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    """Reject HTTP redirects on Linear GraphQL requests."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError("HTTP redirect refused")


class LinearAPIError(RuntimeError):
    """Structured Linear HTTP or GraphQL API error."""

    def __init__(
        self,
        message: str = "",
        *,
        status: int | None = None,
        errors: list[dict[str, object]] | None = None,
    ):
        default_msg = f"Linear HTTP {status}" if status is not None else "Linear API error"
        super().__init__(message or default_msg)
        self.status = status
        self.errors = list(errors) if errors else []


def load_linear_token_module() -> ModuleType:
    """Load `linear_token` via normal import first, then from the sibling `linear-token` directory."""
    try:
        return importlib.import_module("linear_token")
    except ModuleNotFoundError:
        pass

    candidate = Path(__file__).resolve().parent.parent / "linear-token" / "linear_token.py"
    if not candidate.is_file():
        raise ImportError(f"Unable to locate linear_token module at {candidate}")

    spec = importlib.util.spec_from_file_location("linear_token", str(candidate))
    if spec is None or spec.loader is None:
        raise ImportError(f"Unable to load linear_token module spec from {candidate}")

    module = importlib.util.module_from_spec(spec)
    sys.modules["linear_token"] = module
    try:
        spec.loader.exec_module(module)
    except Exception:
        sys.modules.pop("linear_token", None)
        raise
    return module


def _validate_http_url(url: str) -> urllib.parse.SplitResult:
    if not isinstance(url, str) or not url.strip():
        raise ValueError("Unsupported or invalid HTTP URL")
    parsed = urllib.parse.urlsplit(url.strip())
    if parsed.scheme not in ("http", "https") or not parsed.netloc or not parsed.hostname:
        raise ValueError("Unsupported or invalid HTTP URL")
    if parsed.username is not None or parsed.password is not None:
        raise ValueError("HTTP URL must not include embedded credentials")
    return parsed


def _validate_timeout(timeout: float) -> float:
    if isinstance(timeout, bool) or not isinstance(timeout, (int, float)) or not math.isfinite(timeout) or timeout <= 0:
        raise ValueError("Timeout must be a positive finite number")
    return float(timeout)


def _extract_graphql_errors(raw: bytes) -> tuple[str, list[dict[str, object]]]:
    if not raw:
        return "", []
    try:
        payload = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, ValueError):
        return "", []
    if not isinstance(payload, dict):
        return "", []
    raw_errors = payload.get("errors")
    if not isinstance(raw_errors, list):
        return "", []
    parsed_errors = [err for err in raw_errors if isinstance(err, dict)]
    messages = [
        str(err.get("message") or "").strip()
        for err in parsed_errors
        if str(err.get("message") or "").strip()
    ]
    return "; ".join(messages), parsed_errors


def _graphql_request(
    url: str,
    query: str,
    variables: dict[str, object] | None = None,
    *,
    token: str,
    timeout: float = DEFAULT_TIMEOUT_SECS,
    refresh_token: Callable[[str], str] | None = None,
) -> dict[str, object]:
    """Execute a Linear GraphQL POST request with redirect blocking, size bounds, and single HTTP 401 refresh."""
    _validate_http_url(url)
    bounded_timeout = _validate_timeout(timeout)
    if not isinstance(token, str) or not token.strip():
        raise LinearAPIError("Linear access token is missing")

    body = json.dumps({"query": query, "variables": variables or {}}, ensure_ascii=False).encode("utf-8")
    opener = urllib.request.build_opener(NoRedirect)
    current_token = token

    for attempt in range(2):
        request = urllib.request.Request(
            url,
            data=body,
            method="POST",
            headers={
                "Content-Type": "application/json",
                "Accept": "application/json",
                "Authorization": f"Bearer {current_token}",
            },
        )
        try:
            with opener.open(request, timeout=bounded_timeout) as response:
                status = getattr(response, "status", 200)
                raw = response.read(MAX_RESPONSE_BYTES + 1)
        except urllib.error.HTTPError as exc:
            status_code = exc.code
            err_raw = b""
            with contextlib.suppress(Exception):
                err_raw = exc.read(MAX_RESPONSE_BYTES + 1)
            with contextlib.suppress(Exception):
                exc.close()
            if status_code == 401 and attempt == 0 and refresh_token is not None:
                current_token = refresh_token(current_token)
                continue
            summary, parsed_errors = _extract_graphql_errors(err_raw[:MAX_RESPONSE_BYTES])
            message = f"Linear GraphQL HTTP {status_code}: {summary}" if summary else f"Linear GraphQL HTTP {status_code}"
            raise LinearAPIError(message, status=status_code, errors=parsed_errors) from None
        except urllib.error.URLError as exc:
            raise LinearAPIError(f"Linear GraphQL transport error: {exc.reason}") from None

        if len(raw) > MAX_RESPONSE_BYTES:
            raise ValueError("Oversized Linear GraphQL response")

        try:
            payload = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, ValueError) as exc:
            raise LinearAPIError("Invalid JSON in Linear GraphQL response", status=status) from exc

        if not isinstance(payload, dict):
            raise LinearAPIError("Unexpected Linear GraphQL response format", status=status)

        raw_errors = payload.get("errors")
        if isinstance(raw_errors, list) and raw_errors:
            parsed_errors = [err for err in raw_errors if isinstance(err, dict)]
            messages = [
                str(err.get("message") or "").strip()
                for err in parsed_errors
                if str(err.get("message") or "").strip()
            ]
            summary = "; ".join(messages) or "Linear GraphQL request returned errors"
            raise LinearAPIError(summary, status=status, errors=parsed_errors)

        data = payload.get("data")
        if not isinstance(data, dict):
            raise LinearAPIError("Linear GraphQL response missing data", status=status)
        return data

    raise LinearAPIError("Linear GraphQL authentication failed after refresh", status=401)


def normalize_github_url(url: str) -> str:
    """Normalise a GitHub issue or pull request URL to canonical HTTPS form."""
    if not isinstance(url, str) or not url.strip():
        raise ValueError("GitHub URL must be a non-empty string")
    parsed = _validate_http_url(url)
    host = (parsed.hostname or "").lower()
    segments = [seg for seg in parsed.path.split("/") if seg]

    if host in ("github.com", "www.github.com"):
        if len(segments) >= 4 and segments[2].lower() in ("pull", "pulls", "issue", "issues") and segments[3].isdigit():
            owner = segments[0].lower()
            repo = segments[1].lower()
            kind = "pull" if segments[2].lower() in ("pull", "pulls") else "issues"
            number = str(int(segments[3]))
            return f"https://github.com/{owner}/{repo}/{kind}/{number}"
        if len(segments) >= 2:
            owner = segments[0].lower()
            repo = segments[1].lower()
            rest = segments[2:]
            suffix = "/" + "/".join(rest) if rest else ""
            return f"https://github.com/{owner}/{repo}{suffix}"
        raise ValueError(f"Unsupported GitHub URL path: {url}")

    if host == "api.github.com":
        if (
            len(segments) >= 5
            and segments[0].lower() == "repos"
            and segments[3].lower() in ("pulls", "issues")
            and segments[4].isdigit()
        ):
            owner = segments[1].lower()
            repo = segments[2].lower()
            kind = "pull" if segments[3].lower() == "pulls" else "issues"
            number = str(int(segments[4]))
            return f"https://github.com/{owner}/{repo}/{kind}/{number}"
        raise ValueError(f"Unsupported GitHub API URL path: {url}")

    raise ValueError(f"Unsupported GitHub URL host: {url}")


def _parse_github_url_parts(normalized_url: str) -> tuple[str, str | None, int | None]:
    parsed = urllib.parse.urlsplit(normalized_url)
    segments = [seg for seg in parsed.path.split("/") if seg]
    if len(segments) < 2:
        return "", None, None
    repo = f"{segments[0].lower()}/{segments[1].lower()}"
    if len(segments) >= 4 and segments[2] in ("pull", "issues") and segments[3].isdigit():
        item_label = "PR" if segments[2] == "pull" else "Issue"
        return repo, item_label, int(segments[3])
    return repo, None, None


def format_github_url_marker(github_url: str) -> str:
    """Format a deterministic leading HTML comment marker for a canonical GitHub URL."""
    normalized_url = normalize_github_url(github_url)
    encoded = json.dumps({"url": normalized_url}, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    encoded = encoded.replace("<", "\\u003c").replace(">", "\\u003e")
    return f"<!-- {GITHUB_URL_MARKER_PREFIX} {encoded} -->"


def parse_github_url_marker(description: object) -> str | None:
    """Extract and normalise the canonical GitHub URL from a leading issue description marker."""
    if not isinstance(description, str) or not description:
        return None
    match = _GITHUB_URL_MARKER_RE.match(description)
    if match is None:
        return None
    try:
        payload = json.loads(match.group(1))
    except ValueError:
        return None
    if not isinstance(payload, dict):
        return None
    raw_url = payload.get("url")
    if not isinstance(raw_url, str) or not raw_url.strip():
        return None
    try:
        return normalize_github_url(raw_url)
    except ValueError:
        return None


def format_issue_description_with_github_url(description: str, github_url: str) -> str:
    """Ensure the canonical GitHub URL marker leads the Linear issue description."""
    normalized_url = normalize_github_url(github_url)
    marker = format_github_url_marker(normalized_url)
    body = str(description or "")
    if not body.strip():
        return marker
    if parse_github_url_marker(body) == normalized_url:
        return body
    return f"{marker}\n\n{body}"


def _normalize_repo_name(repo: str) -> str:
    clean = str(repo or "").strip().lower()
    if not _REPO_SLUG_RE.match(clean):
        raise ValueError(f"Invalid repository name (expected <owner>/<repo>): {repo!r}")
    return clean


def _normalize_item_kind_label(item_kind: str) -> str:
    norm = str(item_kind or "").strip().lower()
    if norm in ("pr", "pull", "pulls", "pull_request", "pullrequest", "pull request"):
        return "PR"
    if norm in ("issue", "issues"):
        return "Issue"
    raise ValueError(f"Unsupported GitHub item kind: {item_kind!r}")


def _normalize_verdict_fields(
    agent: str,
    model_family: str,
    head_sha: str,
    verdict: str,
) -> dict[str, str]:
    values = {
        "agent": str(agent or "").strip().lower(),
        "head_sha": str(head_sha or "").strip().lower(),
        "model_family": str(model_family or "").strip().lower(),
        "verdict": str(verdict or "").strip().lower(),
    }
    for field_name, value in values.items():
        if not value or "\n" in value or "\r" in value or "-->" in value:
            raise ValueError(f"Invalid blind review verdict field {field_name!r}")
    return values


def _escape_verdict_summary(summary: str) -> str:
    """Escape HTML comment delimiters so summary text cannot smuggle verdict markers."""
    return str(summary or "").strip().replace("<!--", "&lt;!--").replace("-->", "--&gt;")


def format_blind_review_verdict_comment(
    agent: str,
    model_family: str,
    head_sha: str,
    verdict: str,
    summary: str = "",
) -> str:
    """Format a deterministic blind review verdict comment with a structured HTML comment marker."""
    fields = _normalize_verdict_fields(agent, model_family, head_sha, verdict)
    encoded = json.dumps(fields, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    marker = f"<!-- {BLIND_REVIEW_MARKER_PREFIX} {encoded} -->"
    lines = [
        marker,
        f"**Blind review verdict ({fields['agent']} / {fields['model_family']})**: `{fields['verdict']}` on `{fields['head_sha']}`",
    ]
    clean_summary = _escape_verdict_summary(summary)
    if clean_summary:
        lines.extend(["", clean_summary])
    return "\n".join(lines)


def parse_blind_review_verdicts(
    comments: Iterable[dict[str, object] | str],
    head_sha: str | None = None,
) -> list[dict[str, object]]:
    """Parse one canonical leading blind review verdict marker per Linear comment."""
    target_sha = str(head_sha).strip().lower() if head_sha is not None else None
    parsed_verdicts: list[dict[str, object]] = []

    for comment in comments or ():
        body = comment if isinstance(comment, str) else (comment.get("body") if isinstance(comment, dict) else "")
        if not isinstance(body, str) or not body:
            continue
        match = _BLIND_REVIEW_MARKER_RE.match(body)
        if match is None:
            continue
        try:
            raw_payload = json.loads(match.group(1))
        except ValueError:
            continue
        if not isinstance(raw_payload, dict):
            continue
        try:
            fields = _normalize_verdict_fields(
                str(raw_payload.get("agent") or ""),
                str(raw_payload.get("model_family") or ""),
                str(raw_payload.get("head_sha") or ""),
                str(raw_payload.get("verdict") or ""),
            )
        except ValueError:
            continue
        if target_sha is not None and fields["head_sha"] != target_sha:
            continue
        entry: dict[str, object] = dict(fields)
        if isinstance(comment, dict):
            if comment.get("id") is not None:
                entry["comment_id"] = comment.get("id")
            if comment.get("createdAt") is not None:
                entry["created_at"] = comment.get("createdAt")
            if comment.get("updatedAt") is not None:
                entry["updated_at"] = comment.get("updatedAt")
        parsed_verdicts.append(entry)

    return parsed_verdicts


_TEAM_BY_KEY_QUERY = """
query($key: String!) {
  teams(filter: { key: { eq: $key } }, first: 10) {
    nodes {
      id
      key
      name
    }
  }
}
""".strip()

_TEAM_PROJECTS_QUERY = """
query($teamId: String!, $after: String) {
  team(id: $teamId) {
    projects(first: 100, after: $after) {
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        id
        name
        state
      }
    }
  }
}
""".strip()

_PROJECT_CREATE_MUTATION = """
mutation($input: ProjectCreateInput!) {
  projectCreate(input: $input) {
    success
    project {
      id
      name
      state
    }
  }
}
""".strip()

_TEAM_STATES_QUERY = """
query($teamId: String!, $after: String) {
  team(id: $teamId) {
    states(first: 100, after: $after) {
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        id
        name
        type
        position
      }
    }
  }
}
""".strip()

_ISSUE_LABELS_QUERY = """
query($filter: IssueLabelFilter, $after: String) {
  issueLabels(filter: $filter, first: 100, after: $after) {
    pageInfo {
      hasNextPage
      endCursor
    }
    nodes {
      id
      name
      isGroup
      parent {
        id
        name
      }
      team {
        id
      }
    }
  }
}
""".strip()

_ISSUE_LABEL_CREATE_MUTATION = """
mutation($input: IssueLabelCreateInput!) {
  issueLabelCreate(input: $input) {
    success
    issueLabel {
      id
      name
      isGroup
      parent {
        id
        name
      }
      team {
        id
      }
    }
  }
}
""".strip()

_ISSUE_FIELDS = """
id
identifier
title
description
url
estimate
priority
updatedAt
archivedAt
state {
  id
  name
  type
}
project {
  id
  name
}
team {
  id
  key
}
labels(first: 50) {
  nodes {
    id
    name
    parent {
      id
      name
    }
  }
}
""".strip()

_ATTACHMENTS_FOR_URL_QUERY = f"""
query($url: String!, $after: String) {{
  attachmentsForURL(url: $url, first: 50, after: $after) {{
    pageInfo {{
      hasNextPage
      endCursor
    }}
    nodes {{
      id
      url
      title
      issue {{
        {_ISSUE_FIELDS}
      }}
    }}
  }}
}}
""".strip()

_ISSUE_GET_QUERY = f"""
query($id: String!) {{
  issue(id: $id) {{
    {_ISSUE_FIELDS}
  }}
}}
""".strip()

_ISSUE_CREATE_MUTATION = f"""
mutation($input: IssueCreateInput!) {{
  issueCreate(input: $input) {{
    success
    issue {{
      {_ISSUE_FIELDS}
    }}
  }}
}}
""".strip()

_ISSUE_UPDATE_MUTATION = f"""
mutation($id: String!, $input: IssueUpdateInput!) {{
  issueUpdate(id: $id, input: $input) {{
    success
    issue {{
      {_ISSUE_FIELDS}
    }}
  }}
}}
""".strip()

_ATTACHMENT_CREATE_MUTATION = """
mutation($input: AttachmentCreateInput!) {
  attachmentCreate(input: $input) {
    success
    attachment {
      id
      url
      title
    }
  }
}
""".strip()

_PROJECT_ISSUES_QUERY = f"""
query($filter: IssueFilter, $first: Int!, $after: String, $includeArchived: Boolean!) {{
  issues(filter: $filter, first: $first, after: $after, includeArchived: $includeArchived) {{
    pageInfo {{
      hasNextPage
      endCursor
    }}
    nodes {{
      {_ISSUE_FIELDS}
      attachments(first: 20) {{
        nodes {{
          id
          url
          title
        }}
      }}
    }}
  }}
}}
""".strip()

_ISSUE_COMMENTS_QUERY = """
query($issueId: String!, $first: Int!, $after: String) {
  issue(id: $issueId) {
    id
    comments(first: $first, after: $after) {
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        id
        body
        createdAt
        updatedAt
        user {
          id
          name
        }
      }
    }
  }
}
""".strip()

_COMMENT_CREATE_MUTATION = """
mutation($input: CommentCreateInput!) {
  commentCreate(input: $input) {
    success
    comment {
      id
      body
      createdAt
      updatedAt
    }
  }
}
""".strip()


class LinearSyncClient:
    """Linear GraphQL client for synchronising GitHub community items and blind review verdicts."""

    def __init__(
        self,
        *,
        client_id_path: Path | str,
        client_secret_path: Path | str,
        token_cache_dir: Path | str,
        team_key: str = DEFAULT_TEAM_KEY,
        project_name: str = DEFAULT_PROJECT_NAME,
        api_url: str = DEFAULT_GRAPHQL_URL,
        timeout: float = DEFAULT_TIMEOUT_SECS,
        linear_token_module: ModuleType | None = None,
    ):
        clean_client_id = str(client_id_path or "").strip()
        clean_client_secret = str(client_secret_path or "").strip()
        clean_cache_dir = str(token_cache_dir or "").strip()
        if not clean_client_id or not clean_client_secret or not clean_cache_dir:
            raise ValueError("Linear client credential paths and token cache directory must be non-empty")

        self.client_id_path = clean_client_id
        self.client_secret_path = clean_client_secret
        self.token_cache_dir = clean_cache_dir
        self.team_key = (team_key or DEFAULT_TEAM_KEY).strip() or DEFAULT_TEAM_KEY
        self.project_name = (project_name or DEFAULT_PROJECT_NAME).strip() or DEFAULT_PROJECT_NAME
        self.api_url = (api_url or DEFAULT_GRAPHQL_URL).strip()
        _validate_http_url(self.api_url)
        self.timeout = _validate_timeout(timeout)
        self._linear_token_module = linear_token_module

        self._team_id: str | None = None
        self._project_ids_by_lower_name: dict[str, str] = {}
        self._states_loaded = False
        self._states_by_canonical: dict[str, dict[str, object]] = {}
        self._states_by_lower_name: dict[str, dict[str, object]] = {}
        self._states_by_id: dict[str, dict[str, object]] = {}
        self._triage_fallback_warned = False

        self._labels_loaded = False
        self._labels_by_id: dict[str, dict[str, object]] = {}
        self._label_groups_by_lower_name: dict[str, dict[str, object]] = {}
        self._repo_labels_by_lower_name: dict[str, dict[str, object]] = {}
        self._flat_labels_by_lower_name: dict[str, dict[str, object]] = {}
        self._repository_label_group_id: str | None = None

    def __repr__(self) -> str:
        return (
            f"LinearSyncClient(api_url={self.api_url!r}, "
            f"team_key={self.team_key!r}, project_name={self.project_name!r})"
        )

    @classmethod
    def from_env(cls, env: Mapping[str, str] | None = None) -> LinearSyncClient | None:
        """Create a client from environment variables, or return None when credential paths are empty."""
        source = os.environ if env is None else env
        client_id_path = str(source.get(ENV_LINEAR_CLIENT_ID_PATH) or "").strip()
        client_secret_path = str(source.get(ENV_LINEAR_CLIENT_SECRET_PATH) or "").strip()
        token_cache_dir = str(source.get(ENV_LINEAR_TOKEN_CACHE_DIR) or "").strip()
        if not client_id_path or not client_secret_path or not token_cache_dir:
            return None
        team_key = str(source.get(ENV_LINEAR_TEAM_KEY) or "").strip() or DEFAULT_TEAM_KEY
        api_url = str(source.get(ENV_LINEAR_API_URL) or "").strip() or DEFAULT_GRAPHQL_URL
        return cls(
            client_id_path=client_id_path,
            client_secret_path=client_secret_path,
            token_cache_dir=token_cache_dir,
            team_key=team_key,
            api_url=api_url,
        )

    def _get_linear_token_module(self) -> ModuleType:
        if self._linear_token_module is None:
            self._linear_token_module = load_linear_token_module()
        return self._linear_token_module

    def _get_access_token(self) -> str:
        lt = self._get_linear_token_module()
        return str(lt.access_token(self.client_id_path, self.client_secret_path, self.token_cache_dir))

    def _refresh_access_token(self, failed_token: str) -> str:
        """Force-refresh an access token after HTTP 401 under the shared cache lock."""
        lt = self._get_linear_token_module()
        client_id = lt.read_credential(self.client_id_path)
        client_secret = lt.read_credential(self.client_secret_path)
        identity = hashlib.sha256(json.dumps([client_id, client_secret, lt.SCOPE]).encode()).hexdigest()

        Path(self.token_cache_dir).mkdir(mode=0o700, parents=True, exist_ok=True)
        directory = os.open(self.token_cache_dir, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            lt.check_private(directory, directory=True)
            fd = os.open(
                "lock",
                os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK,
                0o600,
                dir_fd=directory,
            )
            with os.fdopen(fd, "r+") as lock:
                lt.check_private(lock.fileno())
                fcntl.flock(lock, fcntl.LOCK_EX)
                cached = lt.read_cache(directory)
                if cached.get("identity") != identity:
                    cached = {}
                now = time.time()
                cached_token = cached.get("access_token")
                expires_at = cached.get("expires_at", 0)
                if (
                    isinstance(cached_token, str)
                    and cached_token
                    and cached_token != failed_token
                    and expires_at > now
                ):
                    return cached_token
                token, lifetime = lt.request_token(client_id, client_secret)
                lt.write_cache(
                    directory,
                    {
                        "identity": identity,
                        "access_token": token,
                        "expires_at": now + lifetime,
                    },
                )
                return str(token)
        finally:
            os.close(directory)

    def _graphql_request(
        self,
        query: str,
        variables: dict[str, object] | None = None,
    ) -> dict[str, object]:
        token = self._get_access_token()
        return _graphql_request(
            self.api_url,
            query,
            variables,
            token=token,
            timeout=self.timeout,
            refresh_token=self._refresh_access_token,
        )

    def resolve_team_id(self) -> str:
        """Resolve and cache the Linear team ID for `self.team_key`."""
        if self._team_id is not None:
            return self._team_id
        data = self._graphql_request(_TEAM_BY_KEY_QUERY, {"key": self.team_key})
        teams = data.get("teams")
        nodes = teams.get("nodes") if isinstance(teams, dict) else None
        if isinstance(nodes, list):
            for node in nodes:
                if isinstance(node, dict) and str(node.get("key") or "").strip().upper() == self.team_key.upper():
                    team_id = str(node.get("id") or "").strip()
                    if team_id:
                        self._team_id = team_id
                        return team_id
        raise LinearAPIError(f"Linear team not found for key {self.team_key!r}")

    def _resolve_existing_project_id(self, project_name: str | None = None) -> str | None:
        """Resolve and cache an existing Linear project ID for the team without creating one."""
        target = (project_name or self.project_name).strip() or self.project_name
        target_lower = target.lower()
        if target_lower in self._project_ids_by_lower_name:
            return self._project_ids_by_lower_name[target_lower]

        team_id = self.resolve_team_id()
        after: str | None = None
        seen_cursors: set[str] = set()
        fallback_id: str | None = None

        while True:
            data = self._graphql_request(_TEAM_PROJECTS_QUERY, {"teamId": team_id, "after": after})
            team = data.get("team")
            projects = team.get("projects") if isinstance(team, dict) else None
            nodes = projects.get("nodes") if isinstance(projects, dict) else None
            if isinstance(nodes, list):
                for node in nodes:
                    if not isinstance(node, dict):
                        continue
                    node_id = str(node.get("id") or "").strip()
                    node_name = str(node.get("name") or "").strip()
                    if not node_id or not node_name:
                        continue
                    self._project_ids_by_lower_name.setdefault(node_name.lower(), node_id)
                    if node_name == target:
                        self._project_ids_by_lower_name[target_lower] = node_id
                        return node_id
                    if node_name.lower() == target_lower and fallback_id is None:
                        fallback_id = node_id

            page_info = projects.get("pageInfo") if isinstance(projects, dict) else None
            has_next = bool(page_info.get("hasNextPage")) if isinstance(page_info, dict) else False
            end_cursor = str(page_info.get("endCursor") or "").strip() if isinstance(page_info, dict) else ""
            if not has_next or not end_cursor or end_cursor in seen_cursors:
                break
            seen_cursors.add(end_cursor)
            after = end_cursor

        if fallback_id is not None:
            self._project_ids_by_lower_name[target_lower] = fallback_id
            return fallback_id

        return None

    def ensure_project(self, project_name: str | None = None) -> str:
        """Resolve or create a Linear project attached to the team and cache its ID."""
        target = (project_name or self.project_name).strip() or self.project_name
        target_lower = target.lower()
        existing_id = self._resolve_existing_project_id(target)
        if existing_id is not None:
            return existing_id

        team_id = self.resolve_team_id()
        created = self._graphql_request(
            _PROJECT_CREATE_MUTATION,
            {"input": {"name": target, "teamIds": [team_id]}},
        )
        payload = created.get("projectCreate")
        project = payload.get("project") if isinstance(payload, dict) else None
        project_id = str(project.get("id") or "").strip() if isinstance(project, dict) else ""
        if not isinstance(payload, dict) or not payload.get("success") or not project_id:
            raise LinearAPIError(f"Failed to create Linear project {target!r}")
        self._project_ids_by_lower_name[target_lower] = project_id
        return project_id

    def resolve_workflow_states(self) -> dict[str, dict[str, object]]:
        """Resolve and cache team workflow states by Linear type and name."""
        if self._states_loaded:
            return dict(self._states_by_canonical)

        team_id = self.resolve_team_id()
        after: str | None = None
        seen_cursors: set[str] = set()
        raw_states: list[dict[str, object]] = []

        while True:
            data = self._graphql_request(_TEAM_STATES_QUERY, {"teamId": team_id, "after": after})
            team = data.get("team")
            states = team.get("states") if isinstance(team, dict) else None
            nodes = states.get("nodes") if isinstance(states, dict) else None
            if isinstance(nodes, list):
                for node in nodes:
                    if isinstance(node, dict) and str(node.get("id") or "").strip():
                        raw_states.append(node)

            page_info = states.get("pageInfo") if isinstance(states, dict) else None
            has_next = bool(page_info.get("hasNextPage")) if isinstance(page_info, dict) else False
            end_cursor = str(page_info.get("endCursor") or "").strip() if isinstance(page_info, dict) else ""
            if not has_next or not end_cursor or end_cursor in seen_cursors:
                break
            seen_cursors.add(end_cursor)
            after = end_cursor

        def _sort_key(item: dict[str, object]) -> tuple[float, str]:
            pos = item.get("position")
            pos_val = float(pos) if isinstance(pos, (int, float)) and not isinstance(pos, bool) and math.isfinite(pos) else 0.0
            return (pos_val, str(item.get("name") or "").strip().lower())

        ordered = sorted(raw_states, key=_sort_key)
        self._states_by_id.clear()
        self._states_by_lower_name.clear()
        self._states_by_canonical.clear()

        for node in ordered:
            state_id = str(node.get("id") or "").strip()
            name = str(node.get("name") or "").strip()
            if state_id:
                self._states_by_id[state_id] = node
            if name:
                self._states_by_lower_name.setdefault(name.lower(), node)

        def _find_state(
            *,
            types: tuple[str, ...],
            names: tuple[str, ...],
            exclude_names: tuple[str, ...] = (),
            allow_type_only: bool = True,
        ) -> dict[str, object] | None:
            for node in ordered:
                node_type = str(node.get("type") or "").strip().lower()
                node_name = str(node.get("name") or "").strip().lower()
                if node_type in types and node_name in names:
                    return node
            if allow_type_only:
                for node in ordered:
                    node_type = str(node.get("type") or "").strip().lower()
                    node_name = str(node.get("name") or "").strip().lower()
                    if node_type in types and node_name not in exclude_names:
                        return node
            for node in ordered:
                node_name = str(node.get("name") or "").strip().lower()
                if node_name in names:
                    return node
            return None

        resolved_pairs: tuple[tuple[str, dict[str, object] | None], ...] = (
            ("Triage", _find_state(types=("triage",), names=("triage",))),
            ("Backlog", _find_state(types=("backlog",), names=("backlog",))),
            ("Todo", _find_state(types=("unstarted",), names=("todo",))),
            ("In Progress", _find_state(types=("started",), names=("in progress",), exclude_names=("in review",))),
            ("In Review", _find_state(types=("started",), names=("in review",), allow_type_only=False)),
            ("Done", _find_state(types=("completed",), names=("done",))),
            ("Duplicate", _find_state(types=("duplicate",), names=("duplicate",), allow_type_only=True)),
            ("Canceled", _find_state(types=("canceled",), names=("canceled", "cancelled"), exclude_names=("duplicate",))),
        )
        for canonical_name, state_node in resolved_pairs:
            if state_node is not None:
                self._states_by_canonical[canonical_name] = state_node

        # Some Linear teams represent Duplicate as a canceled-type state named Duplicate.
        if "Duplicate" not in self._states_by_canonical:
            dup_canceled = _find_state(types=("canceled",), names=("duplicate",), allow_type_only=False)
            if dup_canceled is not None:
                self._states_by_canonical["Duplicate"] = dup_canceled

        if "Triage" not in self._states_by_canonical and "Backlog" in self._states_by_canonical:
            self._states_by_canonical["Triage"] = self._states_by_canonical["Backlog"]
            self._states_by_lower_name["triage"] = self._states_by_canonical["Backlog"]
            if not self._triage_fallback_warned:
                self._triage_fallback_warned = True
                print(
                    f"moltis-github-companion: Linear team {self.team_key} has no Triage state; mapping Triage to Backlog.",
                    file=sys.stderr,
                )

        self._states_loaded = True
        return dict(self._states_by_canonical)

    def resolve_state_id(self, state_name: str) -> str:
        """Resolve a workflow state name, canonical alias, or state ID to its Linear state ID."""
        if not self._states_loaded:
            self.resolve_workflow_states()
        raw = str(state_name or "").strip()
        if not raw:
            raise LinearAPIError(f"Workflow state name must be non-empty for team {self.team_key}")
        if raw in self._states_by_id:
            return raw
        lowered = raw.lower()
        canonical = _CANONICAL_STATE_ALIASES.get(lowered)
        if canonical and canonical in self._states_by_canonical:
            return str(self._states_by_canonical[canonical]["id"])
        if lowered in self._states_by_lower_name:
            return str(self._states_by_lower_name[lowered]["id"])
        raise LinearAPIError(f"Unknown Linear workflow state for team {self.team_key}: {state_name!r}")

    def _register_label(self, node: dict[str, object], team_id: str) -> None:
        label_id = str(node.get("id") or "").strip()
        name = str(node.get("name") or "").strip()
        if not label_id or not name:
            return
        lowered = name.lower()
        self._labels_by_id[label_id] = node
        team_obj = node.get("team")
        node_team_id = str(team_obj.get("id") or "").strip() if isinstance(team_obj, dict) else ""
        is_team_scoped = bool(node_team_id and node_team_id == team_id)

        if node.get("isGroup") is True:
            existing = self._label_groups_by_lower_name.get(lowered)
            if existing is None or is_team_scoped:
                self._label_groups_by_lower_name[lowered] = node
            if lowered == REPOSITORY_LABEL_GROUP.lower() and (
                self._repository_label_group_id is None or is_team_scoped
            ):
                self._repository_label_group_id = label_id
            return

        parent = node.get("parent")
        parent_id = str(parent.get("id") or "").strip() if isinstance(parent, dict) else ""
        parent_name = str(parent.get("name") or "").strip().lower() if isinstance(parent, dict) else ""
        is_repo_child = bool(
            (self._repository_label_group_id and parent_id == self._repository_label_group_id)
            or parent_name == REPOSITORY_LABEL_GROUP.lower()
        )
        if is_repo_child:
            existing_repo = self._repo_labels_by_lower_name.get(lowered)
            if existing_repo is None or is_team_scoped:
                self._repo_labels_by_lower_name[lowered] = node
        else:
            existing_flat = self._flat_labels_by_lower_name.get(lowered)
            if existing_flat is None or is_team_scoped:
                self._flat_labels_by_lower_name[lowered] = node

    def _load_labels(self) -> None:
        if self._labels_loaded:
            return
        team_id = self.resolve_team_id()
        after: str | None = None
        seen_cursors: set[str] = set()
        raw_nodes: list[dict[str, object]] = []
        label_filter: dict[str, object] = {
            "or": [
                {"team": {"id": {"eq": team_id}}},
                {"team": {"null": True}},
            ]
        }

        while True:
            data = self._graphql_request(_ISSUE_LABELS_QUERY, {"filter": label_filter, "after": after})
            labels = data.get("issueLabels")
            nodes = labels.get("nodes") if isinstance(labels, dict) else None
            if isinstance(nodes, list):
                for node in nodes:
                    if isinstance(node, dict):
                        raw_nodes.append(node)

            page_info = labels.get("pageInfo") if isinstance(labels, dict) else None
            has_next = bool(page_info.get("hasNextPage")) if isinstance(page_info, dict) else False
            end_cursor = str(page_info.get("endCursor") or "").strip() if isinstance(page_info, dict) else ""
            if not has_next or not end_cursor or end_cursor in seen_cursors:
                break
            seen_cursors.add(end_cursor)
            after = end_cursor

        # Register groups first so child labels can match the Repository group ID.
        for node in raw_nodes:
            if node.get("isGroup") is True:
                self._register_label(node, team_id)
        for node in raw_nodes:
            if node.get("isGroup") is not True:
                self._register_label(node, team_id)
        self._labels_loaded = True

    def _create_label(
        self,
        *,
        name: str,
        is_group: bool = False,
        parent_id: str | None = None,
    ) -> dict[str, object]:
        team_id = self.resolve_team_id()
        payload_input: dict[str, object] = {"name": name, "teamId": team_id}
        if is_group:
            payload_input["isGroup"] = True
        if parent_id is not None:
            payload_input["parentId"] = parent_id
        data = self._graphql_request(_ISSUE_LABEL_CREATE_MUTATION, {"input": payload_input})
        result = data.get("issueLabelCreate")
        label = result.get("issueLabel") if isinstance(result, dict) else None
        if not isinstance(result, dict) or not result.get("success") or not isinstance(label, dict) or not label.get("id"):
            raise LinearAPIError(f"Failed to create Linear label {name!r}")
        self._register_label(label, team_id)
        return label

    def ensure_repository_label_group(self) -> str:
        """Resolve or create the `Repository` label group (`isGroup: true`)."""
        self._load_labels()
        if self._repository_label_group_id is not None:
            return self._repository_label_group_id
        existing = self._label_groups_by_lower_name.get(REPOSITORY_LABEL_GROUP.lower())
        if existing is not None:
            self._repository_label_group_id = str(existing["id"])
            return self._repository_label_group_id
        created = self._create_label(name=REPOSITORY_LABEL_GROUP, is_group=True)
        self._repository_label_group_id = str(created["id"])
        return self._repository_label_group_id

    def ensure_repository_label(self, repo: str) -> str:
        """Resolve or create an `<owner>/<repo>` child label under the `Repository` group."""
        clean_repo = _normalize_repo_name(repo)
        self._load_labels()
        existing = self._repo_labels_by_lower_name.get(clean_repo)
        if existing is not None:
            return str(existing["id"])
        group_id = self.ensure_repository_label_group()
        created = self._create_label(name=clean_repo, parent_id=group_id)
        return str(created["id"])

    def ensure_workflow_label(self, label_name: str) -> str:
        """Resolve or create one of the six workflow labels on demand."""
        canonical = _WORKFLOW_LABEL_BY_LOWER.get(str(label_name or "").strip().lower())
        if canonical is None:
            raise ValueError(f"Unsupported workflow label: {label_name!r}")
        self._load_labels()
        existing = self._flat_labels_by_lower_name.get(canonical.lower())
        if existing is not None:
            return str(existing["id"])
        created = self._create_label(name=canonical)
        return str(created["id"])

    def ensure_label(self, label_name: str) -> str:
        """Resolve or create a workflow label, repository label, or custom team label."""
        raw = str(label_name or "").strip()
        if not raw:
            raise ValueError("Label name must be non-empty")
        self._load_labels()
        if raw in self._labels_by_id:
            return raw
        if raw.lower() in _WORKFLOW_LABEL_BY_LOWER:
            return self.ensure_workflow_label(raw)
        if _REPO_SLUG_RE.match(raw):
            return self.ensure_repository_label(raw)
        existing = self._flat_labels_by_lower_name.get(raw.lower())
        if existing is not None:
            return str(existing["id"])
        created = self._create_label(name=raw)
        return str(created["id"])

    def _lookup_existing_label_id(self, label_name: str, issue_labels: list[dict[str, object]]) -> str | None:
        raw = str(label_name or "").strip()
        if not raw:
            return None
        lowered = raw.lower()
        for item in issue_labels:
            item_id = str(item.get("id") or "").strip()
            item_name = str(item.get("name") or "").strip().lower()
            if raw == item_id or lowered == item_name:
                return item_id or None
        self._load_labels()
        if raw in self._labels_by_id:
            return raw
        for table in (self._flat_labels_by_lower_name, self._repo_labels_by_lower_name):
            found = table.get(lowered)
            if found is not None:
                return str(found["id"])
        return None

    def get_issue(self, issue_id: str) -> dict[str, object]:
        """Fetch a single Linear issue by ID or identifier."""
        clean_id = str(issue_id or "").strip()
        if not clean_id:
            raise ValueError("issue_id must be non-empty")
        data = self._graphql_request(_ISSUE_GET_QUERY, {"id": clean_id})
        issue = data.get("issue")
        if not isinstance(issue, dict) or not issue.get("id"):
            raise LinearAPIError(f"Linear issue not found: {clean_id!r}")
        return issue

    def _find_issue_by_attachment_url(self, normalized_url: str, team_id: str) -> dict[str, object] | None:
        after: str | None = None
        seen_cursors: set[str] = set()
        team_fallback: dict[str, object] | None = None
        project_lower = self.project_name.lower()

        while True:
            data = self._graphql_request(_ATTACHMENTS_FOR_URL_QUERY, {"url": normalized_url, "after": after})
            attachments = data.get("attachmentsForURL")
            nodes = attachments.get("nodes") if isinstance(attachments, dict) else None
            if isinstance(nodes, list):
                for node in nodes:
                    if not isinstance(node, dict):
                        continue
                    att_url = str(node.get("url") or "").strip()
                    if att_url:
                        try:
                            if normalize_github_url(att_url) != normalized_url:
                                continue
                        except ValueError:
                            if att_url != normalized_url:
                                continue
                    issue = node.get("issue")
                    if not isinstance(issue, dict) or not issue.get("id") or issue.get("archivedAt"):
                        continue
                    issue_team = issue.get("team")
                    issue_team_id = str(issue_team.get("id") or "").strip() if isinstance(issue_team, dict) else ""
                    if issue_team_id and issue_team_id != team_id:
                        continue
                    issue_project = issue.get("project")
                    issue_project_name = (
                        str(issue_project.get("name") or "").strip().lower()
                        if isinstance(issue_project, dict)
                        else ""
                    )
                    if issue_project_name == project_lower:
                        return issue
                    if team_fallback is None:
                        team_fallback = issue

            page_info = attachments.get("pageInfo") if isinstance(attachments, dict) else None
            has_next = bool(page_info.get("hasNextPage")) if isinstance(page_info, dict) else False
            end_cursor = str(page_info.get("endCursor") or "").strip() if isinstance(page_info, dict) else ""
            if not has_next or not end_cursor or end_cursor in seen_cursors:
                break
            seen_cursors.add(end_cursor)
            after = end_cursor

        return team_fallback

    def _find_issue_by_description_marker(
        self,
        normalized_url: str,
        team_id: str,
        *,
        page_size: int = 50,
    ) -> dict[str, object] | None:
        """Scan non-archived issues in the target project for an exact leading GitHub URL marker."""
        project_id = self._resolve_existing_project_id()
        if project_id is None:
            return None

        issue_filter: dict[str, object] = {
            "team": {"id": {"eq": team_id}},
            "project": {"id": {"eq": project_id}},
        }
        after: str | None = None
        seen_cursors: set[str] = set()

        while True:
            data = self._graphql_request(
                _PROJECT_ISSUES_QUERY,
                {
                    "filter": issue_filter,
                    "first": page_size,
                    "after": after,
                    "includeArchived": False,
                },
            )
            issues = data.get("issues")
            nodes = issues.get("nodes") if isinstance(issues, dict) else None
            if isinstance(nodes, list):
                for issue in nodes:
                    if not isinstance(issue, dict) or not issue.get("id") or issue.get("archivedAt"):
                        continue
                    issue_team = issue.get("team")
                    issue_team_id = str(issue_team.get("id") or "").strip() if isinstance(issue_team, dict) else ""
                    if issue_team_id and issue_team_id != team_id:
                        continue
                    if parse_github_url_marker(issue.get("description")) == normalized_url:
                        return issue

            page_info = issues.get("pageInfo") if isinstance(issues, dict) else None
            has_next = bool(page_info.get("hasNextPage")) if isinstance(page_info, dict) else False
            end_cursor = str(page_info.get("endCursor") or "").strip() if isinstance(page_info, dict) else ""
            if not has_next or not end_cursor or end_cursor in seen_cursors:
                break
            seen_cursors.add(end_cursor)
            after = end_cursor

        return None

    @staticmethod
    def _issue_has_github_attachment(issue: Mapping[str, object], normalized_url: str) -> bool:
        attachments = issue.get("attachments")
        raw_nodes = attachments.get("nodes") if isinstance(attachments, dict) else None
        if not isinstance(raw_nodes, list):
            return False
        for node in raw_nodes:
            if not isinstance(node, dict):
                continue
            att_url = str(node.get("url") or "").strip()
            if not att_url:
                continue
            try:
                if normalize_github_url(att_url) == normalized_url:
                    return True
            except ValueError:
                if att_url == normalized_url:
                    return True
        return False

    def _attach_github_url(
        self,
        *,
        issue_id: str,
        normalized_url: str,
        resolved_repo: str,
        parsed_num: int | None,
        fallback_title: str,
        attachment_title: str | None = None,
        attachment_subtitle: str | None = None,
    ) -> dict[str, object] | None:
        resolved_attachment_title = (
            str(attachment_title).strip()
            if attachment_title is not None and str(attachment_title).strip()
            else (
                f"{resolved_repo}#{parsed_num}"
                if resolved_repo and parsed_num is not None
                else (fallback_title or normalized_url)
            )
        )
        attachment_input: dict[str, object] = {
            "issueId": issue_id,
            "url": normalized_url,
            "title": resolved_attachment_title,
        }
        if attachment_subtitle is not None and str(attachment_subtitle).strip():
            attachment_input["subtitle"] = str(attachment_subtitle).strip()

        att_result = self._graphql_request(_ATTACHMENT_CREATE_MUTATION, {"input": attachment_input})
        att_payload = att_result.get("attachmentCreate")
        if not isinstance(att_payload, dict) or not att_payload.get("success"):
            raise LinearAPIError(f"Failed to attach GitHub URL to Linear issue {issue_id}")
        attachment = att_payload.get("attachment")
        return attachment if isinstance(attachment, dict) else None

    def find_issue_by_github_url(self, github_url: str) -> dict[str, object] | None:
        """Find an existing Linear issue linked to the normalised GitHub URL via attachments or description marker."""
        normalized_url = normalize_github_url(github_url)
        team_id = self.resolve_team_id()
        found = self._find_issue_by_attachment_url(normalized_url, team_id)
        if found is not None:
            return found
        return self._find_issue_by_description_marker(normalized_url, team_id)

    def ensure_issue_for_github_item(
        self,
        *,
        github_url: str,
        title: str,
        repo: str | None = None,
        item_kind: str | None = None,
        description: str = "",
        state: str = "Triage",
        extra_labels: Iterable[str] = (),
        priority: int | None = None,
        estimate: int | None = None,
        attachment_title: str | None = None,
        attachment_subtitle: str | None = None,
    ) -> dict[str, object]:
        """Return an existing issue for the GitHub item, or create it with labels and attachment."""
        normalized_url = normalize_github_url(github_url)
        team_id = self.resolve_team_id()
        existing = self._find_issue_by_attachment_url(normalized_url, team_id)
        if existing is not None:
            return existing

        parsed_repo, parsed_kind, parsed_num = _parse_github_url_parts(normalized_url)
        orphaned = self._find_issue_by_description_marker(normalized_url, team_id)
        if orphaned is not None:
            if not self._issue_has_github_attachment(orphaned, normalized_url):
                reconcile_repo = _normalize_repo_name(repo) if repo is not None else parsed_repo
                fallback_title = str(title or "").strip() or str(orphaned.get("title") or "").strip()
                created_attachment = self._attach_github_url(
                    issue_id=str(orphaned["id"]),
                    normalized_url=normalized_url,
                    resolved_repo=reconcile_repo,
                    parsed_num=parsed_num,
                    fallback_title=fallback_title,
                    attachment_title=attachment_title,
                    attachment_subtitle=attachment_subtitle,
                )
                if created_attachment is not None:
                    att_conn = orphaned.get("attachments")
                    if isinstance(att_conn, dict) and isinstance(att_conn.get("nodes"), list):
                        att_conn["nodes"].append(created_attachment)
            return orphaned

        clean_title = str(title or "").strip()
        if not clean_title:
            raise ValueError("Issue title must be non-empty")

        resolved_repo = _normalize_repo_name(repo if repo is not None else parsed_repo)
        resolved_kind = _normalize_item_kind_label(item_kind if item_kind is not None else (parsed_kind or ""))

        project_id = self.ensure_project()
        state_id = self.resolve_state_id(state)

        label_ids: list[str] = []
        for label_id in (
            self.ensure_repository_label(resolved_repo),
            self.ensure_workflow_label(resolved_kind),
            *(self.ensure_label(extra) for extra in extra_labels if str(extra or "").strip()),
        ):
            if label_id not in label_ids:
                label_ids.append(label_id)

        issue_input: dict[str, object] = {
            "teamId": team_id,
            "projectId": project_id,
            "stateId": state_id,
            "title": clean_title,
            "description": format_issue_description_with_github_url(description, normalized_url),
            "labelIds": label_ids,
        }
        if priority is not None:
            issue_input["priority"] = priority
        if estimate is not None:
            issue_input["estimate"] = estimate

        created = self._graphql_request(_ISSUE_CREATE_MUTATION, {"input": issue_input})
        create_payload = created.get("issueCreate")
        issue = create_payload.get("issue") if isinstance(create_payload, dict) else None
        issue_id = str(issue.get("id") or "").strip() if isinstance(issue, dict) else ""
        if not isinstance(create_payload, dict) or not create_payload.get("success") or not issue_id:
            raise LinearAPIError(f"Failed to create Linear issue for {normalized_url}")

        self._attach_github_url(
            issue_id=issue_id,
            normalized_url=normalized_url,
            resolved_repo=resolved_repo,
            parsed_num=parsed_num,
            fallback_title=clean_title,
            attachment_title=attachment_title,
            attachment_subtitle=attachment_subtitle,
        )

        return issue

    def update_issue(
        self,
        issue_id: str,
        *,
        state: str | None = None,
        title: str | None = None,
        description: str | None = None,
        estimate: int | None = None,
        priority: int | None = None,
        labels: Iterable[str] | None = None,
        add_labels: Iterable[str] = (),
        remove_labels: Iterable[str] = (),
    ) -> dict[str, object]:
        """Update an existing Linear issue's state, fields, and labels."""
        clean_id = str(issue_id or "").strip()
        if not clean_id:
            raise ValueError("issue_id must be non-empty")

        add_list = [str(lbl).strip() for lbl in add_labels if str(lbl or "").strip()]
        remove_list = [str(lbl).strip() for lbl in remove_labels if str(lbl or "").strip()]
        if labels is not None and (add_list or remove_list):
            raise ValueError("Provide either explicit labels or add_labels/remove_labels, not both")

        update_input: dict[str, object] = {}
        if state is not None:
            update_input["stateId"] = self.resolve_state_id(state)
        if title is not None:
            update_input["title"] = title
        if description is not None:
            update_input["description"] = description
        if estimate is not None:
            update_input["estimate"] = estimate
        if priority is not None:
            update_input["priority"] = priority

        if labels is not None:
            explicit_ids: list[str] = []
            for lbl in labels:
                if str(lbl or "").strip():
                    resolved_id = self.ensure_label(lbl)
                    if resolved_id not in explicit_ids:
                        explicit_ids.append(resolved_id)
            update_input["labelIds"] = explicit_ids
        elif add_list or remove_list:
            current_issue = self.get_issue(clean_id)
            labels_conn = current_issue.get("labels")
            raw_nodes = labels_conn.get("nodes") if isinstance(labels_conn, dict) else None
            issue_label_nodes = [node for node in raw_nodes if isinstance(node, dict)] if isinstance(raw_nodes, list) else []

            remove_ids: set[str] = set()
            for lbl in remove_list:
                found_id = self._lookup_existing_label_id(lbl, issue_label_nodes)
                if found_id is not None:
                    remove_ids.add(found_id)

            final_ids: list[str] = []
            for node in issue_label_nodes:
                node_id = str(node.get("id") or "").strip()
                if node_id and node_id not in remove_ids and node_id not in final_ids:
                    final_ids.append(node_id)
            for lbl in add_list:
                added_id = self.ensure_label(lbl)
                if added_id not in final_ids:
                    final_ids.append(added_id)
            update_input["labelIds"] = final_ids

        if not update_input:
            return self.get_issue(clean_id)

        data = self._graphql_request(
            _ISSUE_UPDATE_MUTATION,
            {"id": clean_id, "input": update_input},
        )
        payload = data.get("issueUpdate")
        updated_issue = payload.get("issue") if isinstance(payload, dict) else None
        if not isinstance(payload, dict) or not payload.get("success") or not isinstance(updated_issue, dict):
            raise LinearAPIError(f"Failed to update Linear issue {clean_id!r}")
        return updated_issue

    def list_project_issues_by_state(
        self,
        states: str | Iterable[str] | None = None,
        *,
        project_name: str | None = None,
        page_size: int = 50,
        include_archived: bool = False,
    ) -> list[dict[str, object]]:
        """List all issues in the target project optionally filtered by workflow states using cursor pagination."""
        if isinstance(page_size, bool) or not isinstance(page_size, int) or page_size <= 0:
            raise ValueError("page_size must be a positive integer")

        team_id = self.resolve_team_id()
        project_id = self.ensure_project(project_name)
        issue_filter: dict[str, object] = {
            "team": {"id": {"eq": team_id}},
            "project": {"id": {"eq": project_id}},
        }

        if states is not None:
            raw_states = [states] if isinstance(states, str) else list(states)
            state_ids: list[str] = []
            for state_name in raw_states:
                if str(state_name or "").strip():
                    sid = self.resolve_state_id(state_name)
                    if sid not in state_ids:
                        state_ids.append(sid)
            if state_ids:
                issue_filter["state"] = {"id": {"in": state_ids}}

        results: list[dict[str, object]] = []
        after: str | None = None
        seen_cursors: set[str] = set()

        while True:
            data = self._graphql_request(
                _PROJECT_ISSUES_QUERY,
                {
                    "filter": issue_filter,
                    "first": page_size,
                    "after": after,
                    "includeArchived": bool(include_archived),
                },
            )
            issues = data.get("issues")
            nodes = issues.get("nodes") if isinstance(issues, dict) else None
            if isinstance(nodes, list):
                for node in nodes:
                    if isinstance(node, dict):
                        results.append(node)

            page_info = issues.get("pageInfo") if isinstance(issues, dict) else None
            has_next = bool(page_info.get("hasNextPage")) if isinstance(page_info, dict) else False
            end_cursor = str(page_info.get("endCursor") or "").strip() if isinstance(page_info, dict) else ""
            if not has_next or not end_cursor or end_cursor in seen_cursors:
                break
            seen_cursors.add(end_cursor)
            after = end_cursor

        return results

    def list_issue_comments(self, issue_id: str, *, page_size: int = 100) -> list[dict[str, object]]:
        """List all comments on a Linear issue using cursor pagination."""
        clean_id = str(issue_id or "").strip()
        if not clean_id:
            raise ValueError("issue_id must be non-empty")
        if isinstance(page_size, bool) or not isinstance(page_size, int) or page_size <= 0:
            raise ValueError("page_size must be a positive integer")

        comments: list[dict[str, object]] = []
        after: str | None = None
        seen_cursors: set[str] = set()

        while True:
            data = self._graphql_request(
                _ISSUE_COMMENTS_QUERY,
                {"issueId": clean_id, "first": page_size, "after": after},
            )
            issue = data.get("issue")
            if not isinstance(issue, dict) or not issue.get("id"):
                raise LinearAPIError(f"Linear issue not found: {clean_id!r}")
            conn = issue.get("comments")
            nodes = conn.get("nodes") if isinstance(conn, dict) else None
            if isinstance(nodes, list):
                for node in nodes:
                    if isinstance(node, dict):
                        comments.append(node)

            page_info = conn.get("pageInfo") if isinstance(conn, dict) else None
            has_next = bool(page_info.get("hasNextPage")) if isinstance(page_info, dict) else False
            end_cursor = str(page_info.get("endCursor") or "").strip() if isinstance(page_info, dict) else ""
            if not has_next or not end_cursor or end_cursor in seen_cursors:
                break
            seen_cursors.add(end_cursor)
            after = end_cursor

        return comments

    def post_blind_review_verdict(
        self,
        issue_id: str,
        *,
        agent: str,
        model_family: str,
        head_sha: str,
        verdict: str,
        summary: str = "",
    ) -> dict[str, object]:
        """Post a blind review verdict comment idempotently per (agent, model_family, head_sha, verdict)."""
        clean_id = str(issue_id or "").strip()
        if not clean_id:
            raise ValueError("issue_id must be non-empty")
        fields = _normalize_verdict_fields(agent, model_family, head_sha, verdict)

        existing_comments = self.list_issue_comments(clean_id)
        comments_by_id = {
            str(comment.get("id")): comment
            for comment in existing_comments
            if comment.get("id") is not None
        }
        for existing in parse_blind_review_verdicts(existing_comments, head_sha=fields["head_sha"]):
            if (
                existing["agent"] == fields["agent"]
                and existing["model_family"] == fields["model_family"]
                and existing["head_sha"] == fields["head_sha"]
                and existing["verdict"] == fields["verdict"]
            ):
                comment_id = existing.get("comment_id")
                if comment_id is not None and str(comment_id) in comments_by_id:
                    return comments_by_id[str(comment_id)]
                return dict(existing)

        body = format_blind_review_verdict_comment(
            agent=fields["agent"],
            model_family=fields["model_family"],
            head_sha=fields["head_sha"],
            verdict=fields["verdict"],
            summary=summary,
        )
        data = self._graphql_request(
            _COMMENT_CREATE_MUTATION,
            {"input": {"issueId": clean_id, "body": body}},
        )
        payload = data.get("commentCreate")
        comment = payload.get("comment") if isinstance(payload, dict) else None
        if not isinstance(payload, dict) or not payload.get("success") or not isinstance(comment, dict):
            raise LinearAPIError(f"Failed to post blind review verdict comment on issue {clean_id!r}")
        return comment
