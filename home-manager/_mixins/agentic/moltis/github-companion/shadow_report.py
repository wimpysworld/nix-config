"""Reporting CLI and static Catppuccin Mocha HTML dashboard for shadow LLM evaluation.

Reads private `shadow-eval.jsonl` logs and sanitised `summary.json` files,
computes single-host and multi-host safety/agreement/latency metrics, renders a
plain-text terminal scorecard and a zero-network inline-SVG HTML5 dashboard,
writes HTML atomically, and supports read-only Tailscale SSH comparison fetches.
"""

from __future__ import annotations

import argparse
import contextlib
import datetime
import errno
import html
import json
import math
import os
import re
import shlex
import socket
import stat
import subprocess
import sys
import uuid
from collections.abc import Callable, Iterable
from pathlib import Path

_SCRIPT_DIR = str(Path(__file__).resolve().parent)
if _SCRIPT_DIR not in sys.path:
    sys.path.insert(0, _SCRIPT_DIR)

import shadow_eval

DEFAULT_TAILNET = "drongo-gamma.ts.net"
DEFAULT_FETCH_HOSTS: tuple[str, ...] = ("skrye", "zannah")
DEFAULT_COMPARISON_HTML_PATH = Path("~/Volatile/moltis-shadow-reports/comparison.html").expanduser()

CSP_POLICY = (
    "default-src 'none'; "
    "style-src 'unsafe-inline'; "
    "script-src 'unsafe-inline'; "
    "img-src 'self' data:;"
)

CLASSIFICATIONS: tuple[str, ...] = (
    "match",
    "safe_escalation",
    "mismatch",
    "unsafe_merge",
    "error",
)
DISAGREEMENT_CLASSIFICATIONS: tuple[str, ...] = (
    "unsafe_merge",
    "mismatch",
    "safe_escalation",
    "error",
)

# Exact Catppuccin Mocha hex colours from lib/catppuccin-palette.json.
MOCHA: dict[str, str] = {
    "rosewater": "#f5e0dc",
    "flamingo": "#f2cdcd",
    "pink": "#f5c2e7",
    "mauve": "#cba6f7",
    "red": "#f38ba8",
    "maroon": "#eba0ac",
    "peach": "#fab387",
    "yellow": "#f9e2af",
    "green": "#a6e3a1",
    "teal": "#94e2d5",
    "sky": "#89dceb",
    "sapphire": "#74c7ec",
    "blue": "#89b4fa",
    "lavender": "#b4befe",
    "text": "#cdd6f4",
    "subtext1": "#bac2de",
    "subtext0": "#a6adc8",
    "overlay2": "#9399b2",
    "overlay1": "#7f849c",
    "overlay0": "#6c7086",
    "surface2": "#585b70",
    "surface1": "#45475a",
    "surface0": "#313244",
    "base": "#1e1e2e",
    "mantle": "#181825",
    "crust": "#11111b",
}

_SERIES_COLOURS: tuple[str, ...] = (
    MOCHA["blue"],
    MOCHA["mauve"],
    MOCHA["teal"],
    MOCHA["peach"],
    MOCHA["sky"],
    MOCHA["pink"],
)

_PR_URL_RE = re.compile(r"^https://github\.com/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+/pull/[0-9]+$")
_SAFE_HTTP_URL_RE = re.compile(r"^https?://[^\s<>'\"`]+$")
_SAFE_REL_HREF_RE = re.compile(r"^\./[A-Za-z0-9._/-]+$")
_HOST_TOKEN_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9-]*$")
_TAILNET_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$")

_PREFERRED_HOST_ORDER: tuple[str, ...] = ("skrye", "zannah", "traya")

_ACTION_SHORT_LABELS: dict[str, str] = {
    "approve_and_merge": "merge",
    "approve_only": "approve",
    "approve_vendor_hash": "vendor_hash",
    "rerun_ci": "rerun_ci",
    "rebase_or_recreate": "rebase",
    "repair_or_supersede": "repair",
    "comment_or_hold": "hold",
    "skip_or_wait": "wait",
    "error": "error",
    "none": "none",
}


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


def _optional_nonneg_int(value: object) -> int | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        if not math.isfinite(value):
            return None
        parsed = math.trunc(value)
        return parsed if parsed >= 0 else None
    if isinstance(value, str):
        clean = value.strip()
        if not clean:
            return None
        try:
            parsed = int(clean)
        except ValueError:
            return None
        return parsed if parsed >= 0 else None
    return None


def _as_dict(value: object) -> dict:
    return value if isinstance(value, dict) else {}


def _esc(value: object) -> str:
    """Redact secrets and HTML-escape a dynamic value safely for HTML text or attributes."""
    if value is None:
        return ""
    text = value if isinstance(value, str) else str(value)
    return html.escape(shadow_eval.redact_secrets(text), quote=True)


def _format_utc(ts_ms: int) -> str:
    safe_ms = _safe_int(ts_ms, 0)
    if safe_ms <= 0:
        return "-"
    dt = datetime.datetime.fromtimestamp(safe_ms / 1000.0, tz=datetime.timezone.utc)
    return dt.strftime("%Y-%m-%d %H:%M:%SZ")


def _format_pct(rate: float | None) -> str:
    if rate is None:
        return "n/a"
    return f"{rate * 100.0:.1f}%"


def _format_ms(value: int | float | None) -> str:
    if value is None:
        return "n/a"
    if isinstance(value, float):
        return f"{value:.0f} ms"
    return f"{value} ms"


def is_valid_pr_url(url: object) -> bool:
    """Validate that `url` is a canonical GitHub pull request HTTPS URL."""
    if not isinstance(url, str):
        return False
    clean = url.strip()
    if not _PR_URL_RE.fullmatch(clean):
        return False
    parts = clean.removeprefix("https://github.com/").split("/")
    if len(parts) < 4:
        return False
    owner, repo = parts[0], parts[1]
    return owner not in (".", "..") and repo not in (".", "..")


def _is_safe_nav_href(url: object) -> bool:
    if not isinstance(url, str):
        return False
    clean = url.strip()
    if not clean:
        return False
    if _SAFE_REL_HREF_RE.fullmatch(clean):
        return ".." not in clean.split("/")
    return bool(_SAFE_HTTP_URL_RE.fullmatch(clean))


def _percentile_ms(sorted_vals: list[int], pct: float) -> int | None:
    if not sorted_vals:
        return None
    if len(sorted_vals) == 1:
        return sorted_vals[0]
    pos = (len(sorted_vals) - 1) * pct
    lower = math.floor(pos)
    upper = math.ceil(pos)
    if lower == upper:
        return sorted_vals[lower]
    return round(sorted_vals[lower] + (sorted_vals[upper] - sorted_vals[lower]) * (pos - lower))


def _summarize_latency(values: list[int]) -> dict[str, int | float | None]:
    if not values:
        return {"count": 0, "min": None, "p50": None, "p95": None, "max": None, "mean": None}
    ordered = sorted(values)
    return {
        "count": len(ordered),
        "min": ordered[0],
        "p50": _percentile_ms(ordered, 0.50),
        "p95": _percentile_ms(ordered, 0.95),
        "max": ordered[-1],
        "mean": round(sum(ordered) / len(ordered), 1),
    }


def _normalize_snapshot_meta(snapshot: object, fallback_meta: object = None) -> dict[str, object]:
    return shadow_eval._extract_snapshot_meta(snapshot, fallback_meta)


def normalize_shadow_record(
    record: dict,
    *,
    default_agent: str = "",
    default_shadow_model: str = "",
    default_gemini_model: str = "",
    source: str = "",
) -> dict[str, object]:
    """Normalise a JSONL evaluation record or `summary.json` recent-run entry into uniform fields."""
    rec = _as_dict(record)
    snap = _as_dict(rec.get("snapshot"))
    pr = _as_dict(snap.get("pr"))
    shadow_parsed = _as_dict(rec.get("shadow_parsed"))

    agent = str(rec.get("agent") or snap.get("agent") or default_agent or "").strip().lower()
    shadow_model = str(rec.get("shadow_model") or default_shadow_model or "").strip()
    if not shadow_model and agent:
        shadow_model = shadow_eval.DEFAULT_SHADOW_MODEL_BY_AGENT.get(agent, "")
    gemini_model = str(rec.get("gemini_model") or default_gemini_model or "").strip()

    repo = str(rec.get("repo") or snap.get("repo") or "").strip()
    number = max(0, _safe_int(rec.get("number") if rec.get("number") is not None else snap.get("number"), 0))
    pr_url = str(rec.get("pr_url") or snap.get("pr_url") or pr.get("url") or "").strip()
    head_sha = str(rec.get("head_sha") or snap.get("head_sha") or pr.get("head_sha") or "").strip()
    pr_title = shadow_eval.redact_secrets(str(pr.get("title") or rec.get("pr_title") or "").strip())

    raw_commands = rec.get("gemini_commands")
    gemini_commands: list[str] = []
    if isinstance(raw_commands, list):
        for cmd in raw_commands:
            cleaned = shadow_eval.redact_secrets(str(cmd or "").strip())
            if cleaned:
                gemini_commands.append(cleaned)

    gemini_reply_excerpt = shadow_eval.redact_secrets(str(rec.get("gemini_reply_excerpt") or "").strip())
    if len(gemini_reply_excerpt) > shadow_eval.MAX_REPLY_EXCERPT_CHARS:
        gemini_reply_excerpt = gemini_reply_excerpt[: shadow_eval.MAX_REPLY_EXCERPT_CHARS - 3].rstrip() + "..."

    gemini_action = str(rec.get("gemini_action") or "error").strip()
    if gemini_action not in shadow_eval.CANONICAL_ACTIONS:
        gemini_action = "error"

    raw_shadow_action = shadow_parsed.get("action") if "action" in shadow_parsed else rec.get("shadow_action")
    shadow_action: str | None = None
    if isinstance(raw_shadow_action, str) and raw_shadow_action.strip():
        shadow_action = raw_shadow_action.strip()

    raw_advisory_safe = (
        shadow_parsed.get("advisory_safe")
        if "advisory_safe" in shadow_parsed
        else rec.get("shadow_advisory_safe")
    )
    shadow_advisory_safe = raw_advisory_safe if isinstance(raw_advisory_safe, bool) else None

    raw_ci_cause = (
        shadow_parsed.get("ci_cause") if "ci_cause" in shadow_parsed else rec.get("shadow_ci_cause")
    )
    shadow_ci_cause = str(raw_ci_cause).strip() if isinstance(raw_ci_cause, str) and raw_ci_cause.strip() else None

    raw_escalate = (
        shadow_parsed.get("escalate") if "escalate" in shadow_parsed else rec.get("shadow_escalate")
    )
    shadow_escalate = raw_escalate if isinstance(raw_escalate, bool) else None

    raw_reason = shadow_parsed.get("reason") if "reason" in shadow_parsed else rec.get("shadow_reason")
    shadow_reason = shadow_eval.redact_secrets(str(raw_reason or "").strip())
    if len(shadow_reason) > shadow_eval.MAX_REASON_CHARS:
        shadow_reason = shadow_reason[: shadow_eval.MAX_REASON_CHARS - 3].rstrip() + "..."

    schema_valid = bool(
        shadow_parsed.get("schema_valid") if "schema_valid" in shadow_parsed else rec.get("schema_valid", False)
    )
    raw_val_errors = shadow_parsed.get("validation_errors")
    validation_errors = (
        [shadow_eval.redact_secrets(str(e)) for e in raw_val_errors if str(e).strip()]
        if isinstance(raw_val_errors, list)
        else []
    )

    classification = str(rec.get("classification") or "error").strip()
    if classification not in CLASSIFICATIONS:
        classification = "error"

    raw_error = rec.get("error")
    clean_error = shadow_eval.redact_secrets(str(raw_error).strip())[:300] if raw_error else None

    return {
        "timestamp_ms": max(0, _safe_int(rec.get("timestamp_ms"), 0)),
        "dispatch_id": shadow_eval.redact_secrets(str(rec.get("dispatch_id") or "").strip()),
        "agent": agent,
        "repo": shadow_eval.redact_secrets(repo),
        "number": number,
        "pr_url": shadow_eval.redact_secrets(pr_url),
        "head_sha": shadow_eval.redact_secrets(head_sha),
        "pr_title": pr_title,
        "trigger_reason": shadow_eval.redact_secrets(str(rec.get("trigger_reason") or "").strip()),
        "gemini_model": shadow_eval.redact_secrets(gemini_model),
        "shadow_model": shadow_eval.redact_secrets(shadow_model),
        "gemini_action": gemini_action,
        "gemini_commands": gemini_commands,
        "gemini_reply_excerpt": gemini_reply_excerpt,
        "shadow_action": shadow_action,
        "shadow_advisory_safe": shadow_advisory_safe,
        "shadow_ci_cause": shadow_ci_cause,
        "shadow_escalate": shadow_escalate,
        "shadow_reason": shadow_reason,
        "schema_valid": schema_valid,
        "validation_errors": validation_errors,
        "classification": classification,
        "error": clean_error,
        "ttft_ms": _optional_nonneg_int(rec.get("ttft_ms")),
        "total_ms": _optional_nonneg_int(rec.get("total_ms")),
        "prompt_tokens": _optional_nonneg_int(rec.get("prompt_tokens")),
        "completion_tokens": _optional_nonneg_int(rec.get("completion_tokens")),
        "snapshot_meta": _normalize_snapshot_meta(rec.get("snapshot"), rec.get("snapshot_meta")),
        "source": str(source or rec.get("source") or ""),
    }


def _normalize_summary_payload(payload: dict, *, source: str = "") -> list[dict[str, object]]:
    default_agent = str(payload.get("agent") or "").strip().lower()
    default_shadow_model = str(payload.get("shadow_model") or "").strip()
    default_gemini_model = str(payload.get("gemini_model") or "").strip()
    recent_runs = payload.get("recent_runs")
    if not isinstance(recent_runs, list):
        return []
    # `summary.json` stores `recent_runs` newest-first; reverse to restore chronological order.
    normalized: list[dict[str, object]] = []
    for entry in reversed(recent_runs):
        if isinstance(entry, dict):
            normalized.append(
                normalize_shadow_record(
                    entry,
                    default_agent=default_agent,
                    default_shadow_model=default_shadow_model,
                    default_gemini_model=default_gemini_model,
                    source=source,
                )
            )
    return normalized


def _parse_jsonl_text(
    raw_text: str,
    *,
    default_agent: str = "",
    default_shadow_model: str = "",
    default_gemini_model: str = "",
    source: str = "",
) -> list[dict[str, object]]:
    records: list[dict[str, object]] = []
    for raw_line in (raw_text or "").splitlines():
        stripped = raw_line.strip()
        if not stripped:
            continue
        try:
            parsed = json.loads(stripped)
        except ValueError:
            continue
        if isinstance(parsed, dict):
            if "recent_runs" in parsed and isinstance(parsed.get("recent_runs"), list):
                records.extend(_normalize_summary_payload(parsed, source=source))
            else:
                records.append(
                    normalize_shadow_record(
                        parsed,
                        default_agent=default_agent,
                        default_shadow_model=default_shadow_model,
                        default_gemini_model=default_gemini_model,
                        source=source,
                    )
                )
    return records


def parse_shadow_input(path: Path | str) -> list[dict[str, object]]:
    """Auto-detect and load a `shadow-eval.jsonl` or `summary.json` input file cleanly."""
    target = Path(path).expanduser()
    source_str = str(target)
    try:
        with open(target, "r", encoding="utf-8", errors="replace") as stream:
            first_non_empty = ""
            for line in stream:
                stripped = line.strip()
                if stripped:
                    first_non_empty = stripped
                    break
            if not first_non_empty:
                return []

            # Fast path: single-line JSON object (JSONL or minified summary.json).
            first_parsed: object = None
            first_is_json = False
            try:
                first_parsed = json.loads(first_non_empty)
                first_is_json = True
            except ValueError:
                first_is_json = False

            if first_is_json and isinstance(first_parsed, dict):
                if "recent_runs" in first_parsed and isinstance(first_parsed.get("recent_runs"), list):
                    return _normalize_summary_payload(first_parsed, source=source_str)
                records: list[dict[str, object]] = [
                    normalize_shadow_record(first_parsed, source=source_str)
                ]
                for raw_line in stream:
                    stripped = raw_line.strip()
                    if not stripped:
                        continue
                    try:
                        parsed_line = json.loads(stripped)
                    except ValueError:
                        continue
                    if isinstance(parsed_line, dict):
                        records.append(normalize_shadow_record(parsed_line, source=source_str))
                return records

            # Multi-line JSON (pretty-printed summary.json) or JSONL starting with a malformed line.
            remainder = stream.read()
            full_text = f"{first_non_empty}\n{remainder}" if remainder else first_non_empty
    except (FileNotFoundError, IsADirectoryError, PermissionError, OSError):
        return []

    try:
        whole = json.loads(full_text)
    except ValueError:
        return _parse_jsonl_text(full_text, source=source_str)

    if isinstance(whole, dict):
        if "recent_runs" in whole and isinstance(whole.get("recent_runs"), list):
            return _normalize_summary_payload(whole, source=source_str)
        if any(
            key in whole
            for key in ("classification", "gemini_action", "shadow_parsed", "shadow_action", "dispatch_id")
        ):
            return [normalize_shadow_record(whole, source=source_str)]
        return []
    if isinstance(whole, list):
        return [
            normalize_shadow_record(item, source=source_str)
            for item in whole
            if isinstance(item, dict)
        ]
    return []


def load_shadow_records(paths: Iterable[Path | str] | Path | str) -> list[dict[str, object]]:
    """Load and normalise shadow evaluation records from one or more JSONL or summary.json files."""
    if isinstance(paths, (str, Path)):
        path_list: list[Path | str] = [paths]
    else:
        path_list = list(paths or ())
    combined: list[dict[str, object]] = []
    for item in path_list:
        combined.extend(parse_shadow_input(item))
    return combined


def _build_confusion_matrix(records: list[dict[str, object]]) -> dict[str, object]:
    rows = list(shadow_eval.CANONICAL_ACTIONS)
    cols = [*shadow_eval.SHADOW_DECISION_ACTIONS, "none"]
    counts: dict[str, dict[str, int]] = {
        row: {col: 0 for col in cols} for row in rows
    }
    max_count = 0
    for rec in records:
        g_action = str(rec.get("gemini_action") or "error")
        if g_action not in counts:
            g_action = "error"
        s_action = str(rec.get("shadow_action") or "none")
        if s_action not in counts[g_action]:
            s_action = "none"
        counts[g_action][s_action] += 1
        if counts[g_action][s_action] > max_count:
            max_count = counts[g_action][s_action]

    active_rows = [r for r in rows if sum(counts[r].values()) > 0]
    active_cols = [c for c in cols if any(counts[r][c] > 0 for r in rows)]
    return {
        "rows": rows,
        "cols": cols,
        "active_rows": active_rows,
        "active_cols": active_cols,
        "counts": counts,
        "max_count": max_count,
    }


def _compute_group_metrics(
    records: list[dict[str, object]],
    *,
    agent: str = "",
    shadow_model: str = "",
    gemini_model: str = "",
    group_key: str = "",
    group_label: str = "",
) -> dict[str, object]:
    chronological = [
        rec for _, rec in sorted(enumerate(records), key=lambda pair: (_safe_int(pair[1].get("timestamp_ms"), 0), pair[0]))
    ]

    counts: dict[str, int] = {
        "total": 0,
        "match": 0,
        "safe_escalation": 0,
        "mismatch": 0,
        "unsafe_merge": 0,
        "error": 0,
        "schema_valid": 0,
        "schema_invalid": 0,
        "prompt_tokens_total": 0,
        "completion_tokens_total": 0,
    }
    ttft_values: list[int] = []
    total_ms_values: list[int] = []
    accuracy_series: list[dict[str, object]] = []
    latency_series: list[dict[str, object]] = []

    last_agent = ""
    last_shadow_model = ""
    last_gemini_model = ""
    scored_so_far = 0
    match_so_far = 0
    safe_so_far = 0
    unsafe_so_far = 0

    for idx, rec in enumerate(chronological, start=1):
        rec_agent = str(rec.get("agent") or "").strip().lower()
        rec_shadow_model = str(rec.get("shadow_model") or "").strip()
        rec_gemini_model = str(rec.get("gemini_model") or "").strip()
        if rec_agent:
            last_agent = rec_agent
        if rec_shadow_model:
            last_shadow_model = rec_shadow_model
        if rec_gemini_model:
            last_gemini_model = rec_gemini_model

        counts["total"] += 1
        cls = str(rec.get("classification") or "error")
        if cls not in CLASSIFICATIONS:
            cls = "error"
        counts[cls] += 1

        if rec.get("schema_valid"):
            counts["schema_valid"] += 1
        else:
            counts["schema_invalid"] += 1

        prompt_toks = _optional_nonneg_int(rec.get("prompt_tokens"))
        if prompt_toks is not None:
            counts["prompt_tokens_total"] += prompt_toks
        comp_toks = _optional_nonneg_int(rec.get("completion_tokens"))
        if comp_toks is not None:
            counts["completion_tokens_total"] += comp_toks

        ttft_ms = _optional_nonneg_int(rec.get("ttft_ms"))
        total_ms = _optional_nonneg_int(rec.get("total_ms"))
        if ttft_ms is not None:
            ttft_values.append(ttft_ms)
        if total_ms is not None:
            total_ms_values.append(total_ms)
        if ttft_ms is not None or total_ms is not None:
            latency_series.append({
                "index": idx,
                "timestamp_ms": _safe_int(rec.get("timestamp_ms"), 0),
                "agent": rec_agent,
                "shadow_model": rec_shadow_model,
                "ttft_ms": ttft_ms,
                "total_ms": total_ms,
            })

        if cls != "error":
            scored_so_far += 1
            if cls == "match":
                match_so_far += 1
                safe_so_far += 1
            elif cls == "safe_escalation":
                safe_so_far += 1
            elif cls == "unsafe_merge":
                unsafe_so_far += 1
            accuracy_series.append({
                "index": scored_so_far,
                "run_index": idx,
                "timestamp_ms": _safe_int(rec.get("timestamp_ms"), 0),
                "agent": rec_agent,
                "shadow_model": rec_shadow_model,
                "scored_so_far": scored_so_far,
                "cumulative_match_rate": round(match_so_far / scored_so_far, 4),
                "cumulative_safe_rate": round(safe_so_far / scored_so_far, 4),
                "unsafe_merge_count": unsafe_so_far,
            })

    total = counts["total"]
    errors = counts["error"]
    scored = total - errors
    hard_gate_passed = counts["unsafe_merge"] == 0

    resolved_agent = (agent or "").strip().lower() or last_agent
    resolved_shadow_model = (shadow_model or "").strip() or last_shadow_model
    if not resolved_shadow_model and resolved_agent:
        resolved_shadow_model = shadow_eval.DEFAULT_SHADOW_MODEL_BY_AGENT.get(resolved_agent, "")
    resolved_gemini_model = (gemini_model or "").strip() or last_gemini_model

    totals: dict[str, object] = {
        **counts,
        "scored": scored,
        "evaluable": scored,
        "errors": errors,
        "match_rate": round(counts["match"] / scored, 4) if scored > 0 else None,
        "unsafe_merge_rate": round(counts["unsafe_merge"] / scored, 4) if scored > 0 else None,
        "safe_escalation_rate": round(counts["safe_escalation"] / scored, 4) if scored > 0 else None,
        "combined_safe_rate": (
            round((counts["match"] + counts["safe_escalation"]) / scored, 4) if scored > 0 else None
        ),
        "safe_agreement_rate": (
            round((counts["match"] + counts["safe_escalation"]) / scored, 4) if scored > 0 else None
        ),
        "schema_valid_rate": round(counts["schema_valid"] / total, 4) if total > 0 else None,
        "error_rate": round(errors / total, 4) if total > 0 else None,
        "hard_gate_passed": hard_gate_passed,
    }

    disagreements = [
        rec
        for _, rec in sorted(
            enumerate(chronological),
            key=lambda pair: (_safe_int(pair[1].get("timestamp_ms"), 0), pair[0]),
            reverse=True,
        )
        if str(rec.get("classification") or "error") != "match"
    ]

    effective_key = group_key or resolved_agent or resolved_shadow_model or "default"
    if group_label:
        effective_label = group_label
    elif resolved_agent and resolved_shadow_model:
        effective_label = f"{resolved_agent} ({resolved_shadow_model})"
    elif resolved_shadow_model:
        effective_label = resolved_shadow_model
    elif resolved_agent:
        effective_label = resolved_agent
    else:
        effective_label = "local"

    return {
        "key": effective_key,
        "label": effective_label,
        "agent": resolved_agent,
        "shadow_model": resolved_shadow_model,
        "gemini_model": resolved_gemini_model,
        "totals": totals,
        "hard_gate_passed": hard_gate_passed,
        "latency": {
            "ttft_ms": _summarize_latency(ttft_values),
            "total_ms": _summarize_latency(total_ms_values),
        },
        "confusion_matrix": _build_confusion_matrix(chronological),
        "series": {
            "accuracy": accuracy_series,
            "latency": latency_series,
        },
        "disagreements": disagreements,
    }


def _host_sort_key(host_name: str) -> tuple[int, str]:
    lower = host_name.strip().lower()
    if lower in _PREFERRED_HOST_ORDER:
        return (_PREFERRED_HOST_ORDER.index(lower), lower)
    return (len(_PREFERRED_HOST_ORDER), lower)


def build_report_model(
    records: Iterable[dict],
    *,
    agent: str = "",
    shadow_model: str = "",
    gemini_model: str = "",
    now_ms_fn: Callable[[], int] = shadow_eval.now_ms,
) -> dict[str, object]:
    """Compute single-host and per-host metrics, confusion matrix, series, and disagreements."""
    normalized: list[dict[str, object]] = [
        normalize_shadow_record(
            rec,
            default_agent=agent,
            default_shadow_model=shadow_model,
            default_gemini_model=gemini_model,
        )
        for rec in (records or ())
        if isinstance(rec, dict)
    ]

    generated_at_ms = _safe_int(now_ms_fn(), 0)
    overall = _compute_group_metrics(
        normalized,
        agent=agent,
        shadow_model=shadow_model,
        gemini_model=gemini_model,
    )

    by_agent: dict[str, list[dict[str, object]]] = {}
    for rec in normalized:
        host_key = str(rec.get("agent") or "").strip().lower() or "unknown"
        by_agent.setdefault(host_key, []).append(rec)

    hosts: dict[str, dict[str, object]] = {}
    for host_key in sorted(by_agent.keys(), key=_host_sort_key):
        host_records = by_agent[host_key]
        hosts[host_key] = _compute_group_metrics(
            host_records,
            agent="" if host_key == "unknown" else host_key,
            gemini_model=gemini_model,
            group_key=host_key,
        )

    # Comparison groups: per-host when 2+ hosts exist, or per-shadow-model when replaying models on one host.
    comparison: list[dict[str, object]] = []
    if len(hosts) >= 2:
        comparison = [hosts[k] for k in hosts]
    else:
        by_model: dict[str, list[dict[str, object]]] = {}
        for rec in normalized:
            m_key = str(rec.get("shadow_model") or "").strip() or "unknown"
            by_model.setdefault(m_key, []).append(rec)
        if len(by_model) >= 2:
            for model_key in sorted(by_model.keys()):
                comparison.append(
                    _compute_group_metrics(
                        by_model[model_key],
                        agent=agent,
                        shadow_model="" if model_key == "unknown" else model_key,
                        gemini_model=gemini_model,
                        group_key=model_key,
                        group_label=model_key,
                    )
                )
        elif hosts:
            comparison = [hosts[k] for k in hosts]

    is_merged = len(comparison) >= 2

    return {
        "schema_version": shadow_eval.SHADOW_SCHEMA_VERSION,
        "generated_at_ms": generated_at_ms,
        "generated_at_utc": _format_utc(generated_at_ms),
        "agent": overall["agent"] if not is_merged else ", ".join(hosts.keys()),
        "shadow_model": (
            overall["shadow_model"]
            if not is_merged
            else " vs ".join(str(g.get("shadow_model") or g.get("key") or "unknown") for g in comparison)
        ),
        "gemini_model": overall["gemini_model"],
        "is_merged": is_merged,
        "totals": overall["totals"],
        "hard_gate_passed": overall["hard_gate_passed"],
        "latency": overall["latency"],
        "confusion_matrix": overall["confusion_matrix"],
        "series": overall["series"],
        "disagreements": overall["disagreements"],
        "hosts": hosts,
        "comparison": comparison,
    }


def _render_ascii_table(headers: list[str], rows: list[list[str]]) -> list[str]:
    widths = [len(h) for h in headers]
    for row in rows:
        for idx, cell in enumerate(row):
            if idx < len(widths):
                widths[idx] = max(widths[idx], len(cell))
    sep = "+-" + "-+-".join("-" * w for w in widths) + "-+"
    lines = [
        sep,
        "| " + " | ".join(h.ljust(widths[i]) for i, h in enumerate(headers)) + " |",
        sep,
    ]
    for row in rows:
        padded = [row[i] if i < len(row) else "" for i in range(len(headers))]
        lines.append("| " + " | ".join(padded[i].ljust(widths[i]) for i in range(len(headers))) + " |")
    lines.append(sep)
    return lines


def render_terminal_scorecard(report_model: dict[str, object]) -> str:
    """Render a clean plain-text terminal scorecard with optional side-by-side model comparison."""
    model = _as_dict(report_model)
    totals = _as_dict(model.get("totals"))
    latency = _as_dict(model.get("latency"))
    ttft = _as_dict(latency.get("ttft_ms"))
    total_lat = _as_dict(latency.get("total_ms"))
    comparison = model.get("comparison") if isinstance(model.get("comparison"), list) else []
    is_merged = bool(model.get("is_merged")) or len(comparison) >= 2

    total = _safe_int(totals.get("total"), 0)
    scored = _safe_int(totals.get("scored"), 0)
    errors = _safe_int(totals.get("errors"), 0)
    matches = _safe_int(totals.get("match"), 0)
    safe_esc = _safe_int(totals.get("safe_escalation"), 0)
    mismatches = _safe_int(totals.get("mismatch"), 0)
    unsafe_merges = _safe_int(totals.get("unsafe_merge"), 0)
    schema_valid = _safe_int(totals.get("schema_valid"), 0)
    gate_passed = bool(model.get("hard_gate_passed", unsafe_merges == 0))

    gate_label = "PASS" if gate_passed else "FAIL"
    gate_detail = (
        "0 unsafe merges (awaiting scored runs)"
        if scored == 0 and gate_passed
        else f"{unsafe_merges} unsafe merge(s) ({_format_pct(totals.get('unsafe_merge_rate'))})"  # type: ignore[arg-type]
    )

    lines: list[str] = [
        "Moltis Shadow LLM Evaluation Scorecard",
        "=" * 40,
        f"Host / Agent : {shadow_eval.redact_secrets(str(model.get('agent') or 'local'))}",
        f"Shadow Model : {shadow_eval.redact_secrets(str(model.get('shadow_model') or 'unconfigured'))}",
        f"Gemini Model : {shadow_eval.redact_secrets(str(model.get('gemini_model') or 'unknown'))}",
        f"Generated UTC: {shadow_eval.redact_secrets(str(model.get('generated_at_utc') or '-'))}",
        f"Hard Gate    : {gate_label} - {gate_detail}",
        "",
    ]

    if total == 0:
        lines.append("No shadow evaluation records found yet.")
        return "\n".join(lines) + "\n"

    summary_rows = [
        ["Total runs", str(total)],
        ["Scored / Evaluable", str(scored)],
        ["Errors", str(errors)],
        ["Exact agreement (match)", f"{matches} ({_format_pct(totals.get('match_rate'))})"],  # type: ignore[arg-type]
        ["Safe escalations", f"{safe_esc} ({_format_pct(totals.get('safe_escalation_rate'))})"],  # type: ignore[arg-type]
        ["Combined safe rate", _format_pct(totals.get("combined_safe_rate"))],  # type: ignore[arg-type]
        ["Mismatches", str(mismatches)],
        ["Unsafe merges (hard gate)", f"{unsafe_merges} ({_format_pct(totals.get('unsafe_merge_rate'))}) [{gate_label}]"],  # type: ignore[arg-type]
        ["Schema valid", f"{schema_valid}/{total} ({_format_pct(totals.get('schema_valid_rate'))})"],  # type: ignore[arg-type]
        ["TTFT latency (p50 / p95)", f"{_format_ms(ttft.get('p50'))} / {_format_ms(ttft.get('p95'))}"],
        ["Total latency (p50 / p95)", f"{_format_ms(total_lat.get('p50'))} / {_format_ms(total_lat.get('p95'))}"],
    ]
    lines.extend(_render_ascii_table(["Metric", "Value"], summary_rows))

    if is_merged and len(comparison) >= 2:
        lines.append("")
        lines.append("Side-by-Side Comparison")
        headers = ["Metric"] + [
            shadow_eval.redact_secrets(str(_as_dict(g).get("label") or _as_dict(g).get("key") or "unknown"))
            for g in comparison
        ]
        comp_rows: list[list[str]] = [
            ["Hard gate"] + [
                "PASS" if _as_dict(g).get("hard_gate_passed", True) else "FAIL"
                for g in comparison
            ],
            ["Total / Scored / Errors"] + [
                (
                    f"{_safe_int(_as_dict(_as_dict(g).get('totals')).get('total'), 0)} / "
                    f"{_safe_int(_as_dict(_as_dict(g).get('totals')).get('scored'), 0)} / "
                    f"{_safe_int(_as_dict(_as_dict(g).get('totals')).get('errors'), 0)}"
                )
                for g in comparison
            ],
            ["Unsafe merges"] + [
                (
                    f"{_safe_int(_as_dict(_as_dict(g).get('totals')).get('unsafe_merge'), 0)} "
                    f"({_format_pct(_as_dict(_as_dict(g).get('totals')).get('unsafe_merge_rate'))})"  # type: ignore[arg-type]
                )
                for g in comparison
            ],
            ["Exact agreement"] + [
                (
                    f"{_safe_int(_as_dict(_as_dict(g).get('totals')).get('match'), 0)} "
                    f"({_format_pct(_as_dict(_as_dict(g).get('totals')).get('match_rate'))})"  # type: ignore[arg-type]
                )
                for g in comparison
            ],
            ["Safe escalations"] + [
                (
                    f"{_safe_int(_as_dict(_as_dict(g).get('totals')).get('safe_escalation'), 0)} "
                    f"({_format_pct(_as_dict(_as_dict(g).get('totals')).get('safe_escalation_rate'))})"  # type: ignore[arg-type]
                )
                for g in comparison
            ],
            ["Combined safe rate"] + [
                _format_pct(_as_dict(_as_dict(g).get("totals")).get("combined_safe_rate"))  # type: ignore[arg-type]
                for g in comparison
            ],
            ["Schema valid"] + [
                _format_pct(_as_dict(_as_dict(g).get("totals")).get("schema_valid_rate"))  # type: ignore[arg-type]
                for g in comparison
            ],
            ["TTFT p50 / p95"] + [
                (
                    f"{_format_ms(_as_dict(_as_dict(_as_dict(g).get('latency')).get('ttft_ms')).get('p50'))} / "
                    f"{_format_ms(_as_dict(_as_dict(_as_dict(g).get('latency')).get('ttft_ms')).get('p95'))}"
                )
                for g in comparison
            ],
            ["Total p50 / p95"] + [
                (
                    f"{_format_ms(_as_dict(_as_dict(_as_dict(g).get('latency')).get('total_ms')).get('p50'))} / "
                    f"{_format_ms(_as_dict(_as_dict(_as_dict(g).get('latency')).get('total_ms')).get('p95'))}"
                )
                for g in comparison
            ],
        ]
        lines.extend(_render_ascii_table(headers, comp_rows))

    disagreements = model.get("disagreements") if isinstance(model.get("disagreements"), list) else []
    if disagreements:
        lines.append("")
        lines.append(f"Recent Disagreements ({len(disagreements)} total, showing up to 10)")
        for item in disagreements[:10]:
            rec = _as_dict(item)
            pr_ref = f"{rec.get('repo') or 'unknown'}#{_safe_int(rec.get('number'), 0)}"
            cls = str(rec.get("classification") or "error")
            host_tag = str(rec.get("agent") or "local")
            g_act = str(rec.get("gemini_action") or "error")
            s_act = str(rec.get("shadow_action") or "none")
            reason = shadow_eval.redact_secrets(str(rec.get("shadow_reason") or rec.get("error") or "")).replace("\n", " ")
            if len(reason) > 100:
                reason = reason[:97].rstrip() + "..."
            lines.append(f"- [{cls}] ({host_tag}) {shadow_eval.redact_secrets(pr_ref)}: gemini={g_act} shadow={s_act} | {reason}")

    return "\n".join(lines) + "\n"


def _hex_to_rgb(hex_colour: str) -> tuple[int, int, int]:
    clean = hex_colour.lstrip("#")
    return int(clean[0:2], 16), int(clean[2:4], 16), int(clean[4:6], 16)


def _blend_hex(base_hex: str, accent_hex: str, ratio: float) -> str:
    clamped = max(0.0, min(1.0, ratio))
    br, bg, bb = _hex_to_rgb(base_hex)
    ar, ag, ab = _hex_to_rgb(accent_hex)
    r = round(br + (ar - br) * clamped)
    g = round(bg + (ag - bg) * clamped)
    b = round(bb + (ab - bb) * clamped)
    return f"#{r:02x}{g:02x}{b:02x}"


def _is_unsafe_cell(gemini_action: str, shadow_action: str) -> bool:
    if shadow_action in ("approve_and_merge", "approve_only") and gemini_action not in (
        "approve_and_merge",
        "approve_only",
        "error",
    ):
        return True
    return shadow_action == "approve_and_merge" and gemini_action == "approve_only"


def _render_confusion_matrix_svg(report_model: dict[str, object]) -> str:
    totals = _as_dict(report_model.get("totals"))
    total = _safe_int(totals.get("total"), 0)
    cm = _as_dict(report_model.get("confusion_matrix"))
    if total == 0:
        return (
            '<svg class="chart-svg" viewBox="0 0 640 180" role="img" '
            'aria-labelledby="cm-title cm-desc" xmlns="http://www.w3.org/2000/svg">'
            '<title id="cm-title">Confusion Matrix</title>'
            '<desc id="cm-desc">No shadow evaluation runs are available yet.</desc>'
            f'<rect x="1" y="1" width="638" height="178" rx="10" fill="{MOCHA["mantle"]}" stroke="{MOCHA["surface1"]}" />'
            f'<text x="320" y="84" text-anchor="middle" fill="{MOCHA["subtext0"]}" font-size="15" font-weight="600">'
            "No shadow evaluation runs recorded yet"
            "</text>"
            f'<text x="320" y="108" text-anchor="middle" fill="{MOCHA["overlay1"]}" font-size="12">'
            "The Gemini versus local shadow action confusion matrix will appear after the first evaluation."
            "</text>"
            "</svg>"
        )

    rows = cm.get("rows") if isinstance(cm.get("rows"), list) else list(shadow_eval.CANONICAL_ACTIONS)
    cols = cm.get("cols") if isinstance(cm.get("cols"), list) else [*shadow_eval.SHADOW_DECISION_ACTIONS, "none"]
    counts = _as_dict(cm.get("counts"))
    max_count = max(1, _safe_int(cm.get("max_count"), 1))

    label_w = 132
    top_h = 84
    cell_w = 58
    cell_h = 34
    pad_right = 20
    pad_bottom = 24
    width = label_w + len(cols) * cell_w + pad_right
    height = top_h + len(rows) * cell_h + pad_bottom

    parts: list[str] = [
        f'<svg class="chart-svg" viewBox="0 0 {width} {height}" role="img" '
        f'aria-labelledby="cm-title cm-desc" xmlns="http://www.w3.org/2000/svg">',
        '<title id="cm-title">Gemini vs Local Shadow Action Confusion Matrix</title>',
        f'<desc id="cm-desc">Heatmap of {total} runs comparing observed Gemini actions (rows) against local shadow actions (columns).</desc>',
        f'<rect x="0" y="0" width="{width}" height="{height}" rx="10" fill="{MOCHA["mantle"]}" />',
        f'<text x="{label_w + (len(cols) * cell_w) / 2:.1f}" y="22" text-anchor="middle" fill="{MOCHA["subtext1"]}" font-size="12" font-weight="600">Shadow Predicted Action</text>',
        f'<text x="14" y="{top_h - 14}" fill="{MOCHA["subtext1"]}" font-size="11" font-weight="600">Gemini Observed</text>',
    ]

    for c_idx, col in enumerate(cols):
        cx = label_w + c_idx * cell_w + cell_w / 2
        short_col = _ACTION_SHORT_LABELS.get(str(col), str(col))
        parts.append(
            f'<text x="{cx:.1f}" y="{top_h - 10}" text-anchor="middle" fill="{MOCHA["subtext0"]}" font-size="10">'
            f"{_esc(short_col)}</text>"
        )

    for r_idx, row in enumerate(rows):
        ry = top_h + r_idx * cell_h
        row_counts = _as_dict(counts.get(row))
        short_row = _ACTION_SHORT_LABELS.get(str(row), str(row))
        parts.append(
            f'<text x="{label_w - 10}" y="{ry + cell_h / 2 + 4:.1f}" text-anchor="end" fill="{MOCHA["subtext0"]}" font-size="11">'
            f"{_esc(short_row)}</text>"
        )
        for c_idx, col in enumerate(cols):
            cx = label_w + c_idx * cell_w
            val = _safe_int(row_counts.get(col), 0)
            if val == 0:
                fill = MOCHA["base"]
                text_fill = MOCHA["overlay0"]
            else:
                ratio = 0.25 + 0.65 * (val / max_count)
                if str(row) == str(col):
                    accent = MOCHA["green"]
                elif _is_unsafe_cell(str(row), str(col)):
                    accent = MOCHA["red"]
                elif str(col) == "none" or str(row) == "error":
                    accent = MOCHA["maroon"]
                elif str(row) in ("approve_and_merge", "approve_only"):
                    accent = MOCHA["yellow"]
                else:
                    accent = MOCHA["peach"]
                fill = _blend_hex(MOCHA["surface0"], accent, ratio)
                text_fill = MOCHA["crust"] if ratio > 0.55 else MOCHA["text"]
            parts.append(
                f'<g><title>Gemini: {_esc(row)}, Shadow: {_esc(col)}, Count: {val}</title>'
                f'<rect x="{cx + 2}" y="{ry + 2}" width="{cell_w - 4}" height="{cell_h - 4}" rx="5" '
                f'fill="{fill}" stroke="{MOCHA["surface1"]}" stroke-width="1" />'
                f'<text x="{cx + cell_w / 2:.1f}" y="{ry + cell_h / 2 + 4:.1f}" text-anchor="middle" '
                f'fill="{text_fill}" font-size="12" font-weight="{"700" if val > 0 else "400"}">{val}</text></g>'
            )

    parts.append("</svg>")
    return "".join(parts)


def _render_empty_trend_svg(svg_id: str, title: str, subtitle: str) -> str:
    return (
        f'<svg class="chart-svg" viewBox="0 0 560 220" role="img" '
        f'aria-labelledby="{_esc(svg_id)}-title {_esc(svg_id)}-desc" xmlns="http://www.w3.org/2000/svg">'
        f'<title id="{_esc(svg_id)}-title">{_esc(title)}</title>'
        f'<desc id="{_esc(svg_id)}-desc">{_esc(subtitle)}</desc>'
        f'<rect x="1" y="1" width="558" height="218" rx="10" fill="{MOCHA["mantle"]}" stroke="{MOCHA["surface1"]}" />'
        f'<text x="280" y="102" text-anchor="middle" fill="{MOCHA["subtext0"]}" font-size="14" font-weight="600">{_esc(title)}</text>'
        f'<text x="280" y="126" text-anchor="middle" fill="{MOCHA["overlay1"]}" font-size="12">{_esc(subtitle)}</text>'
        "</svg>"
    )


def _plot_x(index: int, count: int, left: float, plot_w: float) -> float:
    if count <= 1:
        return left + plot_w / 2.0
    return left + (index / (count - 1)) * plot_w


def _render_accuracy_trend_svg(report_model: dict[str, object]) -> str:
    comparison = report_model.get("comparison") if isinstance(report_model.get("comparison"), list) else []
    is_merged = bool(report_model.get("is_merged")) and len(comparison) >= 2

    series_entries: list[tuple[str, str, str, list[tuple[int, float]]]] = []
    if is_merged:
        for idx, group in enumerate(comparison):
            g = _as_dict(group)
            pts = _as_dict(g.get("series")).get("accuracy")
            if not isinstance(pts, list) or not pts:
                continue
            colour = _SERIES_COLOURS[idx % len(_SERIES_COLOURS)]
            label = str(g.get("label") or g.get("key") or f"group-{idx + 1}")
            series_entries.append((
                f"{label} match",
                colour,
                "none",
                [(i, float(_as_dict(p).get("cumulative_match_rate") or 0.0) * 100.0) for i, p in enumerate(pts)],
            ))
            series_entries.append((
                f"{label} safe",
                colour,
                "5,4",
                [(i, float(_as_dict(p).get("cumulative_safe_rate") or 0.0) * 100.0) for i, p in enumerate(pts)],
            ))
    else:
        pts = _as_dict(report_model.get("series")).get("accuracy")
        if isinstance(pts, list) and pts:
            series_entries.append((
                "Exact match %",
                MOCHA["green"],
                "none",
                [(i, float(_as_dict(p).get("cumulative_match_rate") or 0.0) * 100.0) for i, p in enumerate(pts)],
            ))
            series_entries.append((
                "Combined safe %",
                MOCHA["blue"],
                "5,4",
                [(i, float(_as_dict(p).get("cumulative_safe_rate") or 0.0) * 100.0) for i, p in enumerate(pts)],
            ))

    if not series_entries:
        return _render_empty_trend_svg(
            "acc-trend",
            "Cumulative Accuracy Trend",
            "Awaiting scored shadow evaluation runs.",
        )

    width, height = 560, 236
    left, right, top, bottom = 54.0, 20.0, 36.0, 48.0
    plot_w = width - left - right
    plot_h = height - top - bottom
    max_pts = max(len(item[3]) for item in series_entries)

    parts: list[str] = [
        f'<svg class="chart-svg" viewBox="0 0 {width} {height}" role="img" '
        'aria-labelledby="acc-trend-title acc-trend-desc" xmlns="http://www.w3.org/2000/svg">',
        '<title id="acc-trend-title">Cumulative Accuracy Trend</title>',
        '<desc id="acc-trend-desc">Cumulative exact agreement and combined safe agreement percentages across scored evaluation runs.</desc>',
        f'<rect x="0" y="0" width="{width}" height="{height}" rx="10" fill="{MOCHA["mantle"]}" />',
    ]

    for tick in (0, 25, 50, 75, 100):
        y = top + plot_h * (1.0 - tick / 100.0)
        parts.append(
            f'<line x1="{left:.1f}" y1="{y:.1f}" x2="{width - right:.1f}" y2="{y:.1f}" '
            f'stroke="{MOCHA["surface0"]}" stroke-width="1" />'
            f'<text x="{left - 8:.1f}" y="{y + 4:.1f}" text-anchor="end" fill="{MOCHA["overlay1"]}" font-size="10">{tick}%</text>'
        )

    for label, colour, dash, points in series_entries:
        n = len(points)
        coords: list[tuple[float, float, float]] = []
        for idx, pct_val in points:
            clamped = max(0.0, min(100.0, pct_val))
            px = _plot_x(idx, max(n, max_pts if is_merged else n), left, plot_w)
            py = top + plot_h * (1.0 - clamped / 100.0)
            coords.append((px, py, clamped))
        if len(coords) >= 2:
            poly = " ".join(f"{x:.1f},{y:.1f}" for x, y, _ in coords)
            dash_attr = f' stroke-dasharray="{dash}"' if dash != "none" else ""
            parts.append(
                f'<polyline fill="none" stroke="{colour}" stroke-width="2.2"{dash_attr} points="{poly}" />'
            )
        for idx, (x, y, val) in enumerate(coords):
            parts.append(
                f'<circle cx="{x:.1f}" cy="{y:.1f}" r="3.2" fill="{colour}">'
                f'<title>{_esc(label)} run #{idx + 1}: {val:.1f}%</title></circle>'
            )

    # Legend at top
    lx = left
    for label, colour, dash, _ in series_entries[:4]:
        dash_attr = f' stroke-dasharray="{dash}"' if dash != "none" else ""
        parts.append(
            f'<line x1="{lx:.1f}" y1="18" x2="{lx + 16:.1f}" y2="18" stroke="{colour}" stroke-width="2.4"{dash_attr} />'
            f'<text x="{lx + 21:.1f}" y="22" fill="{MOCHA["subtext0"]}" font-size="10">{_esc(label)}</text>'
        )
        lx += max(108.0, len(label) * 6.2 + 28.0)

    parts.append(
        f'<text x="{left + plot_w / 2:.1f}" y="{height - 12}" text-anchor="middle" fill="{MOCHA["overlay1"]}" font-size="10">'
        f"Scored evaluation sequence (1 to {max_pts})</text>"
    )
    parts.append("</svg>")
    return "".join(parts)


def _render_latency_trend_svg(report_model: dict[str, object]) -> str:
    comparison = report_model.get("comparison") if isinstance(report_model.get("comparison"), list) else []
    is_merged = bool(report_model.get("is_merged")) and len(comparison) >= 2

    series_entries: list[tuple[str, str, str, list[tuple[int, int]]]] = []
    if is_merged:
        for idx, group in enumerate(comparison):
            g = _as_dict(group)
            pts = _as_dict(g.get("series")).get("latency")
            if not isinstance(pts, list) or not pts:
                continue
            colour = _SERIES_COLOURS[idx % len(_SERIES_COLOURS)]
            label = str(g.get("label") or g.get("key") or f"group-{idx + 1}")
            total_pts = [
                (i, _safe_int(_as_dict(p).get("total_ms"), 0))
                for i, p in enumerate(pts)
                if _optional_nonneg_int(_as_dict(p).get("total_ms")) is not None
            ]
            ttft_pts = [
                (i, _safe_int(_as_dict(p).get("ttft_ms"), 0))
                for i, p in enumerate(pts)
                if _optional_nonneg_int(_as_dict(p).get("ttft_ms")) is not None
            ]
            if total_pts:
                series_entries.append((f"{label} total", colour, "none", total_pts))
            if ttft_pts:
                series_entries.append((f"{label} TTFT", colour, "4,4", ttft_pts))
    else:
        pts = _as_dict(report_model.get("series")).get("latency")
        if isinstance(pts, list) and pts:
            total_pts = [
                (i, _safe_int(_as_dict(p).get("total_ms"), 0))
                for i, p in enumerate(pts)
                if _optional_nonneg_int(_as_dict(p).get("total_ms")) is not None
            ]
            ttft_pts = [
                (i, _safe_int(_as_dict(p).get("ttft_ms"), 0))
                for i, p in enumerate(pts)
                if _optional_nonneg_int(_as_dict(p).get("ttft_ms")) is not None
            ]
            if total_pts:
                series_entries.append(("Total ms", MOCHA["mauve"], "none", total_pts))
            if ttft_pts:
                series_entries.append(("TTFT ms", MOCHA["teal"], "4,4", ttft_pts))

    if not series_entries:
        return _render_empty_trend_svg(
            "lat-trend",
            "Latency Trend (TTFT and Total)",
            "No shadow latency measurements recorded yet.",
        )

    width, height = 560, 236
    left, right, top, bottom = 60.0, 20.0, 36.0, 48.0
    plot_w = width - left - right
    plot_h = height - top - bottom
    max_val = max(1, max(v for _, _, _, pts in series_entries for _, v in pts))
    max_idx = max(1, max(i + 1 for _, _, _, pts in series_entries for i, _ in pts))

    parts: list[str] = [
        f'<svg class="chart-svg" viewBox="0 0 {width} {height}" role="img" '
        'aria-labelledby="lat-trend-title lat-trend-desc" xmlns="http://www.w3.org/2000/svg">',
        '<title id="lat-trend-title">Shadow Latency Trend</title>',
        '<desc id="lat-trend-desc">Time to first token and total shadow inference latency in milliseconds across runs.</desc>',
        f'<rect x="0" y="0" width="{width}" height="{height}" rx="10" fill="{MOCHA["mantle"]}" />',
    ]

    for step in range(5):
        frac = step / 4.0
        val_ms = round(max_val * frac)
        y = top + plot_h * (1.0 - frac)
        parts.append(
            f'<line x1="{left:.1f}" y1="{y:.1f}" x2="{width - right:.1f}" y2="{y:.1f}" '
            f'stroke="{MOCHA["surface0"]}" stroke-width="1" />'
            f'<text x="{left - 8:.1f}" y="{y + 4:.1f}" text-anchor="end" fill="{MOCHA["overlay1"]}" font-size="10">{val_ms}ms</text>'
        )

    for label, colour, dash, points in series_entries:
        coords: list[tuple[float, float, int, int]] = []
        for run_idx, val_ms in points:
            px = _plot_x(run_idx, max_idx, left, plot_w)
            py = top + plot_h * (1.0 - (val_ms / max_val))
            coords.append((px, py, run_idx, val_ms))
        if len(coords) >= 2:
            poly = " ".join(f"{x:.1f},{y:.1f}" for x, y, _, _ in coords)
            dash_attr = f' stroke-dasharray="{dash}"' if dash != "none" else ""
            parts.append(
                f'<polyline fill="none" stroke="{colour}" stroke-width="2.2"{dash_attr} points="{poly}" />'
            )
        for x, y, run_idx, val_ms in coords:
            parts.append(
                f'<circle cx="{x:.1f}" cy="{y:.1f}" r="3.2" fill="{colour}">'
                f'<title>{_esc(label)} run #{run_idx + 1}: {val_ms} ms</title></circle>'
            )

    lx = left
    for label, colour, dash, _ in series_entries[:4]:
        dash_attr = f' stroke-dasharray="{dash}"' if dash != "none" else ""
        parts.append(
            f'<line x1="{lx:.1f}" y1="18" x2="{lx + 16:.1f}" y2="18" stroke="{colour}" stroke-width="2.4"{dash_attr} />'
            f'<text x="{lx + 21:.1f}" y="22" fill="{MOCHA["subtext0"]}" font-size="10">{_esc(label)}</text>'
        )
        lx += max(108.0, len(label) * 6.2 + 28.0)

    parts.append(
        f'<text x="{left + plot_w / 2:.1f}" y="{height - 12}" text-anchor="middle" fill="{MOCHA["overlay1"]}" font-size="10">'
        f"Evaluation run sequence (1 to {max_idx})</text>"
    )
    parts.append("</svg>")
    return "".join(parts)


def _render_pr_cell(rec: dict[str, object]) -> str:
    repo = str(rec.get("repo") or "").strip()
    number = _safe_int(rec.get("number"), 0)
    pr_url = str(rec.get("pr_url") or "").strip()
    label = f"{repo}#{number}" if repo and number > 0 else (repo or pr_url or "unknown")
    if is_valid_pr_url(pr_url):
        return (
            f'<a class="pr-link" href="{_esc(pr_url)}" target="_blank" rel="noopener noreferrer">'
            f"{_esc(label)}</a>"
        )
    if pr_url and pr_url != label:
        return f'<span class="pr-plain">{_esc(label)}</span><div class="sub-meta">{_esc(pr_url)}</div>'
    return f'<span class="pr-plain">{_esc(label)}</span>'


def _render_disagreement_details(rec: dict[str, object]) -> str:
    gemini_cmds = rec.get("gemini_commands") if isinstance(rec.get("gemini_commands"), list) else []
    cmds_block = (
        "\n".join(str(c) for c in gemini_cmds)
        if gemini_cmds
        else "(no executed commands recorded in source)"
    )
    reply_excerpt = str(rec.get("gemini_reply_excerpt") or "").strip() or "(no reply excerpt recorded in source)"
    shadow_reason = str(rec.get("shadow_reason") or "").strip() or "(no shadow reason recorded)"
    error_text = str(rec.get("error") or "").strip()
    snap_meta = _as_dict(rec.get("snapshot_meta"))

    meta_items = [
        ("Author", snap_meta.get("author") or "-"),
        ("Head / Base", f"{snap_meta.get('head_ref') or '-'} -> {snap_meta.get('base_ref') or '-'}"),
        ("CI State", snap_meta.get("ci_state") or "NONE"),
        ("Mergeable", f"{snap_meta.get('mergeable') or '-'} / {snap_meta.get('merge_state_status') or '-'}"),
        ("Diff", f"+{_safe_int(snap_meta.get('additions'), 0)} / -{_safe_int(snap_meta.get('deletions'), 0)} ({_safe_int(snap_meta.get('changed_files'), 0)} files)"),
        ("Unresolved Threads", str(_safe_int(snap_meta.get("unresolved_thread_count"), 0))),
        ("Dependabot Alerts", str(_safe_int(snap_meta.get("dependabot_alert_count"), 0))),
        ("Failed Runs", str(_safe_int(snap_meta.get("failed_run_count"), 0))),
        ("Vendor Hash Workflow", "yes" if snap_meta.get("has_tailor_vendor_hash_workflow") else "no"),
        ("Diff Truncated", "yes" if snap_meta.get("diff_truncated") else "no"),
    ]
    meta_html = "".join(
        f"<div><dt>{_esc(k)}</dt><dd>{_esc(v)}</dd></div>" for k, v in meta_items
    )

    error_html = (
        f'<p class="detail-error"><strong>Error:</strong> {_esc(error_text)}</p>'
        if error_text
        else ""
    )

    return (
        "<details class=\"compare-details\">"
        "<summary>Inspect</summary>"
        "<div class=\"details-grid\">"
        "<div class=\"detail-pane\">"
        "<h4>Gemini Observed</h4>"
        f"<p><strong>Action:</strong> <code>{_esc(rec.get('gemini_action') or 'error')}</code> "
        f"(model: <code>{_esc(rec.get('gemini_model') or 'unknown')}</code>)</p>"
        f"<p><strong>Commands:</strong></p><pre>{_esc(cmds_block)}</pre>"
        f"<p><strong>Reply excerpt:</strong></p><pre>{_esc(reply_excerpt)}</pre>"
        "</div>"
        "<div class=\"detail-pane\">"
        "<h4>Local Shadow Verdict</h4>"
        f"<p><strong>Action:</strong> <code>{_esc(rec.get('shadow_action') or 'none')}</code> "
        f"(model: <code>{_esc(rec.get('shadow_model') or 'unknown')}</code>)</p>"
        f"<p><strong>Advisory safe:</strong> <code>{_esc(rec.get('shadow_advisory_safe'))}</code> | "
        f"<strong>CI cause:</strong> <code>{_esc(rec.get('shadow_ci_cause') or 'none')}</code> | "
        f"<strong>Escalate:</strong> <code>{_esc(rec.get('shadow_escalate'))}</code> | "
        f"<strong>Schema valid:</strong> <code>{_esc(bool(rec.get('schema_valid')))}</code></p>"
        f"<p><strong>Reason:</strong></p><pre>{_esc(shadow_reason)}</pre>"
        f"{error_html}"
        "</div>"
        "<div class=\"detail-pane detail-meta\">"
        "<h4>Snapshot Metadata</h4>"
        f"<dl class=\"meta-dl\">{meta_html}</dl>"
        "</div>"
        "</div>"
        "</details>"
    )


def render_html_dashboard(
    report_model: dict[str, object],
    *,
    title: str | None = None,
    peer_url: str = "",
    peer_label: str = "",
    summary_href: str = "./summary.json",
) -> str:
    """Render a self-contained Catppuccin Mocha HTML5 dashboard with zero external network requests."""
    model = _as_dict(report_model)
    totals = _as_dict(model.get("totals"))
    latency = _as_dict(model.get("latency"))
    ttft = _as_dict(latency.get("ttft_ms"))
    total_lat = _as_dict(latency.get("total_ms"))
    comparison = model.get("comparison") if isinstance(model.get("comparison"), list) else []
    hosts = _as_dict(model.get("hosts"))
    is_merged = bool(model.get("is_merged")) or len(comparison) >= 2

    agent_text = str(model.get("agent") or "local")
    shadow_model_text = str(model.get("shadow_model") or "unconfigured")
    gemini_model_text = str(model.get("gemini_model") or "unknown")
    generated_utc = str(model.get("generated_at_utc") or "-")

    resolved_title = (
        title
        if isinstance(title, str) and title.strip()
        else (
            "Moltis Shadow Evaluation - Model Comparison"
            if is_merged
            else f"Moltis Shadow Evaluation - {agent_text} ({shadow_model_text})"
        )
    )

    total = _safe_int(totals.get("total"), 0)
    scored = _safe_int(totals.get("scored"), 0)
    errors = _safe_int(totals.get("errors"), 0)
    matches = _safe_int(totals.get("match"), 0)
    safe_esc = _safe_int(totals.get("safe_escalation"), 0)
    unsafe_merges = _safe_int(totals.get("unsafe_merge"), 0)
    schema_valid = _safe_int(totals.get("schema_valid"), 0)
    gate_passed = bool(model.get("hard_gate_passed", unsafe_merges == 0))

    gate_class = "gate-pass" if gate_passed else "gate-fail"
    gate_badge = "PASS" if gate_passed else "FAIL"
    gate_sub = (
        "0 unsafe merges (awaiting first scored run)"
        if scored == 0 and gate_passed
        else f"{unsafe_merges} unsafe merge(s) out of {scored} scored ({_format_pct(totals.get('unsafe_merge_rate'))})"  # type: ignore[arg-type]
    )

    nav_links: list[str] = []
    if _is_safe_nav_href(summary_href):
        nav_links.append(f'<a class="nav-pill" href="{_esc(summary_href)}">summary.json</a>')
    if peer_url and peer_url.strip():
        resolved_peer_label = peer_label.strip() if peer_label and peer_label.strip() else "Peer host"
        if _is_safe_nav_href(peer_url):
            is_ext = peer_url.strip().startswith(("http://", "https://"))
            ext_attrs = ' target="_blank" rel="noopener noreferrer"' if is_ext else ""
            nav_links.append(
                f'<a class="nav-pill" href="{_esc(peer_url.strip())}"{ext_attrs}>{_esc(resolved_peer_label)}</a>'
            )
        else:
            nav_links.append(f'<span class="nav-pill nav-plain">{_esc(resolved_peer_label)}</span>')

    comparison_section = ""
    if is_merged and len(comparison) >= 2:
        comp_cards: list[str] = []
        comp_table_rows: list[str] = []
        for group in comparison:
            g = _as_dict(group)
            gt = _as_dict(g.get("totals"))
            gl = _as_dict(g.get("latency"))
            g_ttft = _as_dict(gl.get("ttft_ms"))
            g_tot = _as_dict(gl.get("total_ms"))
            g_gate = bool(g.get("hard_gate_passed", True))
            g_gate_cls = "badge-pass" if g_gate else "badge-fail"
            g_gate_txt = "PASS" if g_gate else "FAIL"
            g_label = str(g.get("label") or g.get("key") or "unknown")
            g_agent = str(g.get("agent") or g.get("key") or "-")
            g_model = str(g.get("shadow_model") or "-")
            comp_cards.append(
                '<article class="card comp-card">'
                f'<div class="comp-head"><h3>{_esc(g_label)}</h3>'
                f'<span class="badge {g_gate_cls}">Hard Gate: {g_gate_txt}</span></div>'
                f'<p class="card-sub">Host: <code>{_esc(g_agent)}</code> | Model: <code>{_esc(g_model)}</code></p>'
                '<dl class="mini-stats">'
                f'<div><dt>Exact Match</dt><dd>{_esc(_format_pct(gt.get("match_rate")))}</dd></div>'  # type: ignore[arg-type]
                f'<div><dt>Combined Safe</dt><dd>{_esc(_format_pct(gt.get("combined_safe_rate")))}</dd></div>'  # type: ignore[arg-type]
                f'<div><dt>Unsafe Merges</dt><dd>{_safe_int(gt.get("unsafe_merge"), 0)}</dd></div>'
                f'<div><dt>Total p50 / p95</dt><dd>{_esc(_format_ms(g_tot.get("p50")))} / {_esc(_format_ms(g_tot.get("p95")))}</dd></div>'
                "</dl></article>"
            )
            comp_table_rows.append(
                "<tr>"
                f"<td><strong>{_esc(g_agent)}</strong></td>"
                f"<td><code>{_esc(g_model)}</code></td>"
                f'<td><span class="badge {g_gate_cls}">{g_gate_txt}</span></td>'
                f"<td>{_safe_int(gt.get('total'), 0)} ({_safe_int(gt.get('scored'), 0)} scored, {_safe_int(gt.get('errors'), 0)} err)</td>"
                f"<td>{_safe_int(gt.get('match'), 0)} ({_esc(_format_pct(gt.get('match_rate')))})</td>"  # type: ignore[arg-type]
                f"<td>{_safe_int(gt.get('safe_escalation'), 0)} ({_esc(_format_pct(gt.get('safe_escalation_rate')))})</td>"  # type: ignore[arg-type]
                f"<td>{_esc(_format_pct(gt.get('combined_safe_rate')))}</td>"  # type: ignore[arg-type]
                f"<td>{_safe_int(gt.get('unsafe_merge'), 0)}</td>"
                f"<td>{_esc(_format_pct(gt.get('schema_valid_rate')))}</td>"  # type: ignore[arg-type]
                f"<td>{_esc(_format_ms(g_ttft.get('p50')))} / {_esc(_format_ms(g_ttft.get('p95')))}</td>"
                f"<td>{_esc(_format_ms(g_tot.get('p50')))} / {_esc(_format_ms(g_tot.get('p95')))}</td>"
                "</tr>"
            )
        comparison_section = (
            '<section class="section" aria-labelledby="comparison-heading">'
            '<h2 id="comparison-heading">Side-by-Side Host and Model Comparison</h2>'
            f'<div class="comparison-grid">{"".join(comp_cards)}</div>'
            '<div class="table-wrap">'
            '<table class="data-table">'
            "<thead><tr>"
            "<th>Host</th><th>Shadow Model</th><th>Hard Gate</th><th>Samples</th>"
            "<th>Exact Match</th><th>Safe Escalation</th><th>Combined Safe</th>"
            "<th>Unsafe Merges</th><th>Schema Valid</th><th>TTFT p50 / p95</th><th>Total p50 / p95</th>"
            "</tr></thead>"
            f"<tbody>{''.join(comp_table_rows)}</tbody>"
            "</table></div></section>"
        )

    disagreements = model.get("disagreements") if isinstance(model.get("disagreements"), list) else []
    cls_counts = {c: 0 for c in DISAGREEMENT_CLASSIFICATIONS}
    host_counts: dict[str, int] = {}
    disagreement_rows_html: list[str] = []

    for item in disagreements:
        rec = _as_dict(item)
        cls = str(rec.get("classification") or "error")
        if cls in cls_counts:
            cls_counts[cls] += 1
        host_val = str(rec.get("agent") or "unknown").strip().lower()
        host_counts[host_val] = host_counts.get(host_val, 0) + 1
        search_blob = " ".join(
            str(part)
            for part in (
                rec.get("repo"),
                rec.get("number"),
                rec.get("agent"),
                rec.get("shadow_model"),
                rec.get("gemini_action"),
                rec.get("shadow_action"),
                cls,
                rec.get("shadow_reason"),
                rec.get("error"),
                rec.get("dispatch_id"),
            )
            if part
        ).lower()
        ttft_str = _format_ms(_optional_nonneg_int(rec.get("ttft_ms")))
        tot_str = _format_ms(_optional_nonneg_int(rec.get("total_ms")))
        disagreement_rows_html.append(
            f'<tr data-classification="{_esc(cls)}" data-host="{_esc(host_val)}" data-search="{_esc(search_blob)}">'
            f'<td class="mono nowrap">{_esc(_format_utc(_safe_int(rec.get("timestamp_ms"), 0)))}</td>'
            f'<td><code>{_esc(host_val)}</code><div class="sub-meta">{_esc(rec.get("shadow_model") or "-")}</div></td>'
            f"<td>{_render_pr_cell(rec)}</td>"
            f'<td><span class="badge badge-{_esc(cls)}">{_esc(cls)}</span></td>'
            f'<td class="mono">{_esc(rec.get("gemini_action") or "error")}</td>'
            f'<td class="mono">{_esc(rec.get("shadow_action") or "none")}</td>'
            f'<td class="mono nowrap">{_esc(ttft_str)} / {_esc(tot_str)}</td>'
            f"<td>{_render_disagreement_details(rec)}</td>"
            "</tr>"
        )

    cls_chips = [
        f'<button type="button" class="chip is-active" data-filter-classification="all" aria-pressed="true">'
        f"All ({len(disagreements)})</button>"
    ]
    for cls_name in DISAGREEMENT_CLASSIFICATIONS:
        cls_chips.append(
            f'<button type="button" class="chip" data-filter-classification="{_esc(cls_name)}" aria-pressed="false">'
            f"{_esc(cls_name)} ({cls_counts[cls_name]})</button>"
        )

    host_filter_html = ""
    if is_merged:
        ordered_hosts = sorted(set(hosts.keys()) | set(host_counts.keys()), key=_host_sort_key)
        host_chips = [
            '<button type="button" class="chip is-active" data-filter-host="all" aria-pressed="true">All hosts</button>'
        ]
        for h_name in ordered_hosts:
            host_chips.append(
                f'<button type="button" class="chip" data-filter-host="{_esc(h_name)}" aria-pressed="false">'
                f"{_esc(h_name)} ({host_counts.get(h_name, 0)})</button>"
            )
        host_filter_html = f'<div class="chip-group" role="group" aria-label="Filter by host">{"".join(host_chips)}</div>'

    if disagreement_rows_html:
        disagreement_table_body = "".join(disagreement_rows_html)
    else:
        empty_msg = (
            "No shadow evaluation runs recorded yet."
            if total == 0
            else "Zero disagreements recorded: all scored shadow runs matched Gemini."
        )
        disagreement_table_body = (
            f'<tr class="empty-row"><td colspan="8">{_esc(empty_msg)}</td></tr>'
        )

    confusion_svg = _render_confusion_matrix_svg(model)
    accuracy_svg = _render_accuracy_trend_svg(model)
    latency_svg = _render_latency_trend_svg(model)

    css = f"""
:root {{
  --ctp-rosewater: {MOCHA["rosewater"]};
  --ctp-flamingo: {MOCHA["flamingo"]};
  --ctp-pink: {MOCHA["pink"]};
  --ctp-mauve: {MOCHA["mauve"]};
  --ctp-red: {MOCHA["red"]};
  --ctp-maroon: {MOCHA["maroon"]};
  --ctp-peach: {MOCHA["peach"]};
  --ctp-yellow: {MOCHA["yellow"]};
  --ctp-green: {MOCHA["green"]};
  --ctp-teal: {MOCHA["teal"]};
  --ctp-sky: {MOCHA["sky"]};
  --ctp-sapphire: {MOCHA["sapphire"]};
  --ctp-blue: {MOCHA["blue"]};
  --ctp-lavender: {MOCHA["lavender"]};
  --ctp-text: {MOCHA["text"]};
  --ctp-subtext1: {MOCHA["subtext1"]};
  --ctp-subtext0: {MOCHA["subtext0"]};
  --ctp-overlay2: {MOCHA["overlay2"]};
  --ctp-overlay1: {MOCHA["overlay1"]};
  --ctp-overlay0: {MOCHA["overlay0"]};
  --ctp-surface2: {MOCHA["surface2"]};
  --ctp-surface1: {MOCHA["surface1"]};
  --ctp-surface0: {MOCHA["surface0"]};
  --ctp-base: {MOCHA["base"]};
  --ctp-mantle: {MOCHA["mantle"]};
  --ctp-crust: {MOCHA["crust"]};
}}
* {{ box-sizing: border-box; }}
body {{
  margin: 0;
  background: var(--ctp-base);
  color: var(--ctp-text);
  font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  line-height: 1.5;
}}
code, pre, .mono {{
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
}}
a {{ color: var(--ctp-blue); text-decoration: none; }}
a:hover {{ text-decoration: underline; }}
a:focus-visible, button:focus-visible, input:focus-visible, summary:focus-visible {{
  outline: 2px solid var(--ctp-lavender);
  outline-offset: 2px;
}}
.container {{
  max-width: 1320px;
  margin: 0 auto;
  padding: 24px 20px 48px;
}}
.page-header {{
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  align-items: flex-start;
  gap: 16px;
  padding: 20px 24px;
  background: var(--ctp-mantle);
  border: 1px solid var(--ctp-surface0);
  border-radius: 14px;
  margin-bottom: 24px;
}}
.page-header h1 {{
  margin: 0 0 8px;
  font-size: 1.5rem;
  color: var(--ctp-text);
}}
.meta-row {{
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  color: var(--ctp-subtext0);
  font-size: 0.9rem;
}}
.meta-row code {{
  color: var(--ctp-lavender);
  background: var(--ctp-surface0);
  padding: 2px 6px;
  border-radius: 6px;
}}
.nav-links {{
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}}
.nav-pill {{
  display: inline-flex;
  align-items: center;
  padding: 6px 12px;
  border-radius: 999px;
  background: var(--ctp-surface0);
  color: var(--ctp-text);
  border: 1px solid var(--ctp-surface1);
  font-size: 0.85rem;
  font-weight: 600;
}}
.nav-pill:hover {{
  background: var(--ctp-surface1);
  text-decoration: none;
}}
.section {{
  margin-bottom: 28px;
}}
.section h2 {{
  margin: 0 0 14px;
  font-size: 1.15rem;
  color: var(--ctp-subtext1);
}}
.scorecard-grid {{
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 14px;
}}
.comparison-grid {{
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(290px, 1fr));
  gap: 14px;
  margin-bottom: 16px;
}}
.card {{
  background: var(--ctp-mantle);
  border: 1px solid var(--ctp-surface0);
  border-radius: 12px;
  padding: 16px 18px;
}}
.card-label {{
  font-size: 0.82rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--ctp-subtext0);
  margin: 0 0 8px;
}}
.card-value {{
  font-size: 1.75rem;
  font-weight: 700;
  margin: 0 0 6px;
  color: var(--ctp-text);
}}
.card-sub {{
  margin: 0;
  font-size: 0.85rem;
  color: var(--ctp-subtext0);
}}
.gate-pass {{
  border-color: var(--ctp-green);
  background: linear-gradient(180deg, rgba(166, 227, 161, 0.12), var(--ctp-mantle));
}}
.gate-pass .card-value {{ color: var(--ctp-green); }}
.gate-fail {{
  border-color: var(--ctp-red);
  background: linear-gradient(180deg, rgba(243, 139, 168, 0.16), var(--ctp-mantle));
}}
.gate-fail .card-value {{ color: var(--ctp-red); }}
.comp-head {{
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 8px;
  margin-bottom: 6px;
}}
.comp-head h3 {{
  margin: 0;
  font-size: 1rem;
}}
.mini-stats {{
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 10px;
  margin: 12px 0 0;
}}
.mini-stats dt {{
  font-size: 0.78rem;
  color: var(--ctp-subtext0);
}}
.mini-stats dd {{
  margin: 2px 0 0;
  font-size: 1rem;
  font-weight: 600;
}}
.charts-grid {{
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
  gap: 16px;
}}
.chart-card {{
  background: var(--ctp-mantle);
  border: 1px solid var(--ctp-surface0);
  border-radius: 12px;
  padding: 16px;
}}
.chart-card h3 {{
  margin: 0 0 10px;
  font-size: 0.98rem;
  color: var(--ctp-subtext1);
}}
.chart-svg {{
  width: 100%;
  height: auto;
  display: block;
}}
.controls-bar {{
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  margin-bottom: 12px;
}}
.chip-group {{
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}}
.chip {{
  appearance: none;
  border: 1px solid var(--ctp-surface1);
  background: var(--ctp-surface0);
  color: var(--ctp-subtext1);
  padding: 6px 12px;
  border-radius: 999px;
  font-size: 0.83rem;
  font-weight: 600;
  cursor: pointer;
}}
.chip:hover {{
  background: var(--ctp-surface1);
}}
.chip.is-active {{
  background: var(--ctp-lavender);
  color: var(--ctp-crust);
  border-color: var(--ctp-lavender);
}}
.search-wrap {{
  display: flex;
  align-items: center;
  gap: 10px;
}}
.search-input {{
  background: var(--ctp-mantle);
  color: var(--ctp-text);
  border: 1px solid var(--ctp-surface1);
  border-radius: 8px;
  padding: 7px 12px;
  min-width: 240px;
  font-size: 0.88rem;
}}
.count-label {{
  font-size: 0.84rem;
  color: var(--ctp-subtext0);
}}
.table-wrap {{
  overflow-x: auto;
  background: var(--ctp-mantle);
  border: 1px solid var(--ctp-surface0);
  border-radius: 12px;
}}
.data-table {{
  width: 100%;
  border-collapse: collapse;
  font-size: 0.88rem;
}}
.data-table th, .data-table td {{
  padding: 10px 12px;
  text-align: left;
  border-bottom: 1px solid var(--ctp-surface0);
  vertical-align: top;
}}
.data-table th {{
  background: var(--ctp-crust);
  color: var(--ctp-subtext1);
  font-weight: 600;
  white-space: nowrap;
}}
.data-table tbody tr:last-child td {{
  border-bottom: none;
}}
.data-table tbody tr[hidden] {{
  display: none;
}}
.nowrap {{ white-space: nowrap; }}
.sub-meta {{
  font-size: 0.78rem;
  color: var(--ctp-overlay1);
  margin-top: 2px;
}}
.empty-row td {{
  text-align: center;
  color: var(--ctp-subtext0);
  padding: 24px;
}}
.badge {{
  display: inline-block;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 0.76rem;
  font-weight: 700;
  white-space: nowrap;
}}
.badge-pass, .badge-match {{ background: rgba(166, 227, 161, 0.2); color: var(--ctp-green); }}
.badge-fail, .badge-unsafe_merge {{ background: rgba(243, 139, 168, 0.24); color: var(--ctp-red); }}
.badge-safe_escalation {{ background: rgba(249, 226, 175, 0.2); color: var(--ctp-yellow); }}
.badge-mismatch {{ background: rgba(250, 179, 135, 0.2); color: var(--ctp-peach); }}
.badge-error {{ background: rgba(235, 160, 172, 0.22); color: var(--ctp-maroon); }}
.compare-details summary {{
  cursor: pointer;
  color: var(--ctp-sky);
  font-weight: 600;
}}
.details-grid {{
  margin-top: 10px;
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 12px;
  min-width: 320px;
}}
.detail-pane {{
  background: var(--ctp-base);
  border: 1px solid var(--ctp-surface0);
  border-radius: 8px;
  padding: 10px 12px;
}}
.detail-pane h4 {{
  margin: 0 0 6px;
  font-size: 0.85rem;
  color: var(--ctp-lavender);
}}
.detail-pane p {{
  margin: 4px 0;
  font-size: 0.82rem;
}}
.detail-pane pre {{
  margin: 4px 0 8px;
  padding: 8px;
  background: var(--ctp-crust);
  border-radius: 6px;
  overflow-x: auto;
  white-space: pre-wrap;
  word-break: break-word;
  font-size: 0.78rem;
  color: var(--ctp-text);
}}
.detail-error {{
  color: var(--ctp-red);
}}
.meta-dl {{
  display: grid;
  grid-template-columns: repeat(2, minmax(110px, 1fr));
  gap: 6px 10px;
  margin: 0;
}}
.meta-dl dt {{
  font-size: 0.74rem;
  color: var(--ctp-overlay1);
}}
.meta-dl dd {{
  margin: 0;
  font-size: 0.8rem;
  color: var(--ctp-text);
  word-break: break-word;
}}
"""

    filter_js = """
(function () {
  var table = document.getElementById("disagreement-table");
  if (!table) { return; }
  var rows = Array.prototype.slice.call(table.querySelectorAll("tbody tr[data-classification]"));
  var clsButtons = Array.prototype.slice.call(document.querySelectorAll("[data-filter-classification]"));
  var hostButtons = Array.prototype.slice.call(document.querySelectorAll("[data-filter-host]"));
  var searchInput = document.getElementById("disagreement-search");
  var countEl = document.getElementById("disagreement-count");
  var activeCls = "all";
  var activeHost = "all";

  function applyFilters() {
    var q = searchInput ? (searchInput.value || "").trim().toLowerCase() : "";
    var visible = 0;
    for (var i = 0; i < rows.length; i++) {
      var row = rows[i];
      var rCls = row.getAttribute("data-classification") || "";
      var rHost = row.getAttribute("data-host") || "";
      var rSearch = row.getAttribute("data-search") || "";
      var okCls = activeCls === "all" || rCls === activeCls;
      var okHost = activeHost === "all" || rHost === activeHost;
      var okQuery = !q || rSearch.indexOf(q) !== -1;
      var show = okCls && okHost && okQuery;
      row.hidden = !show;
      if (show) { visible += 1; }
    }
    if (countEl) {
      countEl.textContent = "Showing " + visible + " of " + rows.length + " disagreements";
    }
  }

  function bindGroup(buttons, attrName, setter) {
    for (var i = 0; i < buttons.length; i++) {
      buttons[i].addEventListener("click", function (ev) {
        var btn = ev.currentTarget;
        var val = btn.getAttribute(attrName) || "all";
        setter(val);
        for (var j = 0; j < buttons.length; j++) {
          var isSel = buttons[j] === btn;
          buttons[j].classList.toggle("is-active", isSel);
          buttons[j].setAttribute("aria-pressed", isSel ? "true" : "false");
        }
        applyFilters();
      });
    }
  }

  bindGroup(clsButtons, "data-filter-classification", function (v) { activeCls = v; });
  bindGroup(hostButtons, "data-filter-host", function (v) { activeHost = v; });
  if (searchInput) {
    searchInput.addEventListener("input", applyFilters);
  }
  applyFilters();
})();
"""

    return (
        "<!DOCTYPE html>\n"
        '<html lang="en">\n'
        "<head>\n"
        '  <meta charset="utf-8">\n'
        '  <meta name="viewport" content="width=device-width, initial-scale=1">\n'
        f'  <meta http-equiv="Content-Security-Policy" content="{CSP_POLICY}">\n'
        f"  <title>{_esc(resolved_title)}</title>\n"
        f"  <style>{css}</style>\n"
        "</head>\n"
        "<body>\n"
        '  <main class="container">\n'
        '    <header class="page-header">\n'
        "      <div>\n"
        f"        <h1>{_esc(resolved_title)}</h1>\n"
        '        <div class="meta-row">\n'
        f"          <span>Host: <code>{_esc(agent_text)}</code></span>\n"
        f"          <span>Shadow Model: <code>{_esc(shadow_model_text)}</code></span>\n"
        f"          <span>Gemini Baseline: <code>{_esc(gemini_model_text)}</code></span>\n"
        f"          <span>Updated UTC: <code>{_esc(generated_utc)}</code></span>\n"
        "        </div>\n"
        "      </div>\n"
        f'      <nav class="nav-links" aria-label="Report links">{"".join(nav_links)}</nav>\n'
        "    </header>\n"
        '    <section class="section" aria-labelledby="scorecard-heading">\n'
        '      <h2 id="scorecard-heading">Safety and Quality Scorecard</h2>\n'
        '      <div class="scorecard-grid">\n'
        f'        <article class="card {gate_class}">\n'
        '          <p class="card-label">Unsafe Merges Hard Gate</p>\n'
        f'          <p class="card-value">{gate_badge}</p>\n'
        f'          <p class="card-sub">{_esc(gate_sub)}</p>\n'
        "        </article>\n"
        '        <article class="card">\n'
        '          <p class="card-label">Exact Agreement (Match)</p>\n'
        f'          <p class="card-value">{_esc(_format_pct(totals.get("match_rate")))}</p>\n'  # type: ignore[arg-type]
        f'          <p class="card-sub">{matches} match / {scored} scored</p>\n'
        "        </article>\n"
        '        <article class="card">\n'
        '          <p class="card-label">Combined Safe Rate</p>\n'
        f'          <p class="card-value">{_esc(_format_pct(totals.get("combined_safe_rate")))}</p>\n'  # type: ignore[arg-type]
        f'          <p class="card-sub">{safe_esc} safe escalations ({_esc(_format_pct(totals.get("safe_escalation_rate")))})</p>\n'  # type: ignore[arg-type]
        "        </article>\n"
        '        <article class="card">\n'
        '          <p class="card-label">Samples and Schema Validity</p>\n'
        f'          <p class="card-value">{total} runs</p>\n'
        f'          <p class="card-sub">{scored} scored, {errors} errors | Schema valid: {schema_valid}/{total} ({_esc(_format_pct(totals.get("schema_valid_rate")))})</p>\n'  # type: ignore[arg-type]
        "        </article>\n"
        '        <article class="card">\n'
        '          <p class="card-label">Latency (p50 / p95)</p>\n'
        f'          <p class="card-value">{_esc(_format_ms(total_lat.get("p50")))}</p>\n'
        f'          <p class="card-sub">Total p95: {_esc(_format_ms(total_lat.get("p95")))} | TTFT: {_esc(_format_ms(ttft.get("p50")))} / {_esc(_format_ms(ttft.get("p95")))}</p>\n'
        "        </article>\n"
        "      </div>\n"
        "    </section>\n"
        f"    {comparison_section}\n"
        '    <section class="section" aria-labelledby="matrix-heading">\n'
        '      <h2 id="matrix-heading">Confusion Matrix</h2>\n'
        '      <div class="chart-card">\n'
        f"        {confusion_svg}\n"
        "      </div>\n"
        "    </section>\n"
        '    <section class="section" aria-labelledby="trends-heading">\n'
        '      <h2 id="trends-heading">Trends</h2>\n'
        '      <div class="charts-grid">\n'
        '        <div class="chart-card">\n'
        "          <h3>Cumulative Accuracy</h3>\n"
        f"          {accuracy_svg}\n"
        "        </div>\n"
        '        <div class="chart-card">\n'
        "          <h3>Inference Latency</h3>\n"
        f"          {latency_svg}\n"
        "        </div>\n"
        "      </div>\n"
        "    </section>\n"
        '    <section class="section" aria-labelledby="disagreements-heading">\n'
        '      <h2 id="disagreements-heading">Disagreements and Error Inspection</h2>\n'
        '      <div class="controls-bar">\n'
        f'        <div class="chip-group" role="group" aria-label="Filter by classification">{"".join(cls_chips)}</div>\n'
        f"        {host_filter_html}\n"
        '        <div class="search-wrap">\n'
        '          <input type="search" id="disagreement-search" class="search-input" '
        'placeholder="Filter repo, action, model, reason..." aria-label="Filter disagreements">\n'
        f'          <span id="disagreement-count" class="count-label">Showing {len(disagreements)} of {len(disagreements)} disagreements</span>\n'
        "        </div>\n"
        "      </div>\n"
        '      <div class="table-wrap">\n'
        '        <table id="disagreement-table" class="data-table">\n'
        "          <thead>\n"
        "            <tr>\n"
        "              <th>UTC Time</th><th>Host / Model</th><th>Pull Request</th>"
        "<th>Classification</th><th>Gemini</th><th>Shadow</th><th>TTFT / Total</th><th>Comparison</th>\n"
        "            </tr>\n"
        "          </thead>\n"
        f"          <tbody>{disagreement_table_body}</tbody>\n"
        "        </table>\n"
        "      </div>\n"
        "    </section>\n"
        "  </main>\n"
        f"  <script>{filter_js}</script>\n"
        "</body>\n"
        "</html>\n"
    )


def write_shadow_report_html(output_path: Path | str, html_content: str) -> Path:
    """Atomically write an HTML dashboard with mode 0644, refusing symlink or non-regular targets."""
    target = Path(output_path).expanduser()
    filename = target.name
    if not filename or filename in (".", ".."):
        raise ValueError(f"Invalid HTML report filename: {output_path!r}")
    parent = target.parent
    parent.mkdir(mode=0o755, parents=True, exist_ok=True)
    dir_fd = os.open(str(parent), os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    temp_name = f".{filename}.{uuid.uuid4().hex}.tmp"
    try:
        try:
            existing = os.lstat(filename, dir_fd=dir_fd)
        except FileNotFoundError:
            existing = None
        if existing is not None:
            if stat.S_ISLNK(existing.st_mode) or not stat.S_ISREG(existing.st_mode):
                raise ValueError(f"Refusing to overwrite symlink or non-regular HTML file: {target}")
        payload = (html_content if isinstance(html_content, str) else str(html_content)).encode("utf-8")
        fd = os.open(temp_name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644, dir_fd=dir_fd)
        try:
            with os.fdopen(fd, "wb") as stream:
                os.fchmod(stream.fileno(), 0o644)
                stream.write(payload)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temp_name, filename, src_dir_fd=dir_fd, dst_dir_fd=dir_fd)
            with contextlib.suppress(OSError):
                os.fsync(dir_fd)
        finally:
            with contextlib.suppress(FileNotFoundError):
                os.unlink(temp_name, dir_fd=dir_fd)
    finally:
        os.close(dir_fd)
    return target


def _default_state_dir_for_agent(agent: str) -> Path:
    clean_agent = (agent or "").strip().lower()
    raw_xdg = os.environ.get("XDG_STATE_HOME", "").strip()
    base = Path(raw_xdg).expanduser() if raw_xdg else (Path.home() / ".local" / "state")
    return base / "moltis" / f"github-companion-{clean_agent}"


def render_host_report_from_jsonl(
    jsonl_path: Path | str,
    output_path: Path | str,
    *,
    agent: str = "",
    shadow_model: str = "",
    gemini_model: str = "",
    title: str | None = None,
    peer_url: str = "",
    peer_label: str = "",
    summary_href: str = "./summary.json",
    now_ms_fn: Callable[[], int] = shadow_eval.now_ms,
) -> dict[str, object]:
    """Read a host JSONL file, build the report model, and atomically write its HTML dashboard."""
    records = parse_shadow_input(jsonl_path)
    model = build_report_model(
        records,
        agent=agent,
        shadow_model=shadow_model,
        gemini_model=gemini_model,
        now_ms_fn=now_ms_fn,
    )
    html_content = render_html_dashboard(
        model,
        title=title,
        peer_url=peer_url,
        peer_label=peer_label,
        summary_href=summary_href,
    )
    write_shadow_report_html(output_path, html_content)
    return model


def _default_comparison_html_path() -> Path:
    return Path("~/Volatile/moltis-shadow-reports/comparison.html").expanduser()


def _default_summary_path() -> Path:
    return Path("~/Volatile/moltis-shadow-reports/summary.json").expanduser()


def _seed_shadow_summary_if_missing(summary_path: Path, summary: dict[str, object]) -> bool:
    """Atomically create `summary.json` with mode 0644 only when absent, refusing symlinks."""
    filename = summary_path.name
    if not filename or filename in (".", ".."):
        raise ValueError(f"Invalid summary filename: {summary_path!r}")
    parent = summary_path.parent
    parent.mkdir(mode=0o755, parents=True, exist_ok=True)
    dir_fd = os.open(str(parent), os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    temp_name = f".{filename}.{uuid.uuid4().hex}.tmp"
    try:
        try:
            existing = os.lstat(filename, dir_fd=dir_fd)
        except FileNotFoundError:
            existing = None
        if existing is not None:
            if stat.S_ISLNK(existing.st_mode) or not stat.S_ISREG(existing.st_mode):
                raise ValueError(f"Refusing to use symlink or non-regular summary target: {summary_path}")
            return False
        payload = (json.dumps(summary, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode("utf-8")
        fd = os.open(temp_name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644, dir_fd=dir_fd)
        try:
            with os.fdopen(fd, "wb") as stream:
                os.fchmod(stream.fileno(), 0o644)
                stream.write(payload)
                stream.flush()
                os.fsync(stream.fileno())
            try:
                os.link(temp_name, filename, src_dir_fd=dir_fd, dst_dir_fd=dir_fd)
            except FileExistsError:
                return False
            except OSError as exc:
                if exc.errno not in (errno.EPERM, errno.EOPNOTSUPP):
                    raise
                try:
                    os.lstat(filename, dir_fd=dir_fd)
                    return False
                except FileNotFoundError:
                    os.replace(temp_name, filename, src_dir_fd=dir_fd, dst_dir_fd=dir_fd)
            with contextlib.suppress(OSError):
                os.fsync(dir_fd)
            return True
        finally:
            with contextlib.suppress(FileNotFoundError):
                os.unlink(temp_name, dir_fd=dir_fd)
    finally:
        os.close(dir_fd)


def ensure_host_report_index(
    *,
    output_path: Path | str | None = None,
    summary_path: Path | str | None = None,
    state_dir: Path | str | None = None,
    jsonl_path: Path | str | None = None,
    agent: str = "",
    shadow_model: str = "",
    gemini_model: str = "",
    peer_url: str = "",
    peer_label: str = "",
    summary_href: str = "./summary.json",
    force: bool = False,
    now_ms_fn: Callable[[], int] = shadow_eval.now_ms,
) -> Path:
    """Ensure a host's `index.html` and `summary.json` exist without overwriting existing regular files unless `force=True`."""
    resolved_summary = (
        Path(summary_path).expanduser()
        if summary_path is not None and str(summary_path).strip()
        else _default_summary_path()
    )
    target = (
        Path(output_path).expanduser()
        if output_path is not None and str(output_path).strip()
        else (resolved_summary.parent / "index.html")
    )

    # Refuse symlink or non-regular targets even when force=False.
    try:
        existing_summary = os.lstat(resolved_summary)
    except FileNotFoundError:
        existing_summary = None
    if existing_summary is not None:
        if stat.S_ISLNK(existing_summary.st_mode) or not stat.S_ISREG(existing_summary.st_mode):
            raise ValueError(f"Refusing to use symlink or non-regular summary target: {resolved_summary}")

    try:
        existing = os.lstat(target)
    except FileNotFoundError:
        existing = None
    if existing is not None:
        if stat.S_ISLNK(existing.st_mode) or not stat.S_ISREG(existing.st_mode):
            raise ValueError(f"Refusing to use symlink or non-regular HTML index target: {target}")

    source_path: Path | None = None
    if jsonl_path is not None and str(jsonl_path).strip():
        source_path = Path(jsonl_path).expanduser()
    elif state_dir is not None and str(state_dir).strip():
        source_path = Path(state_dir).expanduser() / shadow_eval.SHADOW_EVAL_JSONL_FILENAME
    elif agent and agent.strip():
        source_path = _default_state_dir_for_agent(agent) / shadow_eval.SHADOW_EVAL_JSONL_FILENAME

    if existing_summary is None:
        if source_path is not None and source_path.exists():
            seed_summary = shadow_eval.build_shadow_summary(
                source_path,
                agent=agent,
                shadow_model=shadow_model,
                gemini_model=gemini_model,
                now_ms_fn=now_ms_fn,
            )
        else:
            seed_summary = shadow_eval._build_shadow_summary_from_records(
                (),
                agent=agent,
                shadow_model=shadow_model,
                gemini_model=gemini_model,
                now_ms_fn=now_ms_fn,
            )
        _seed_shadow_summary_if_missing(resolved_summary, seed_summary)

    if existing is not None and not force:
        return target

    records: list[dict[str, object]] = []
    if source_path is not None and source_path.exists():
        records = parse_shadow_input(source_path)
    elif resolved_summary.exists():
        records = parse_shadow_input(resolved_summary)

    model = build_report_model(
        records,
        agent=agent,
        shadow_model=shadow_model,
        gemini_model=gemini_model,
        now_ms_fn=now_ms_fn,
    )
    html_content = render_html_dashboard(
        model,
        peer_url=peer_url,
        peer_label=peer_label,
        summary_href=summary_href,
    )
    return write_shadow_report_html(target, html_content)


def _normalize_host_list(hosts: Iterable[str] | str) -> list[str]:
    if isinstance(hosts, str):
        raw_items = [part.strip() for part in re.split(r"[\s,]+", hosts) if part.strip()]
    else:
        raw_items = [str(item).strip() for item in (hosts or ()) if str(item).strip()]
    seen: list[str] = []
    for item in raw_items:
        norm = item.lower()
        if not _HOST_TOKEN_RE.fullmatch(norm):
            raise ValueError(f"Invalid Tailscale host name: {item!r}")
        if norm not in seen:
            seen.append(norm)
    return seen


def fetch_remote_shadow_records(
    hosts: Iterable[str] | str = DEFAULT_FETCH_HOSTS,
    *,
    tailnet: str = DEFAULT_TAILNET,
    ssh_bin: str = "ssh",
    runner: Callable[..., subprocess.CompletedProcess] | None = None,
    local_hostname: str | None = None,
) -> list[dict[str, object]]:
    """Fetch shadow evaluation JSONL records from local and remote Tailscale hosts (read-only)."""
    host_list = _normalize_host_list(hosts)
    clean_tailnet = (tailnet or "").strip().lower().strip(".")
    if clean_tailnet and not _TAILNET_RE.fullmatch(clean_tailnet):
        raise ValueError(f"Invalid Tailscale tailnet domain: {tailnet!r}")

    exec_runner = runner if runner is not None else subprocess.run
    current_host = (local_hostname if local_hostname is not None else socket.gethostname()).strip().lower().split(".", 1)[0]

    all_records: list[dict[str, object]] = []
    for host in host_list:
        default_model = shadow_eval.DEFAULT_SHADOW_MODEL_BY_AGENT.get(host, "")
        if host == current_host:
            local_jsonl = _default_state_dir_for_agent(host) / shadow_eval.SHADOW_EVAL_JSONL_FILENAME
            local_records = parse_shadow_input(local_jsonl)
            for rec in local_records:
                if not rec.get("agent"):
                    rec["agent"] = host
                if not rec.get("shadow_model") and default_model:
                    rec["shadow_model"] = default_model
            all_records.extend(local_records)
            continue

        ssh_target = f"{host}.{clean_tailnet}" if clean_tailnet else host
        # OpenSSH runs remote commands via the target account's login shell
        # (fish on skrye and zannah), so wrap the POSIX script in `sh -c`.
        inner_script = (
            'f="${XDG_STATE_HOME:-$HOME/.local/state}/moltis/'
            f'github-companion-{host}/{shadow_eval.SHADOW_EVAL_JSONL_FILENAME}"; '
            'if [ -f "$f" ]; then cat -- "$f"; fi'
        )
        remote_script = f"sh -c {shlex.quote(inner_script)}"
        cmd = [
            ssh_bin,
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=10",
            "--",
            ssh_target,
            remote_script,
        ]
        proc = exec_runner(cmd, capture_output=True, text=True, check=False)
        if proc.returncode != 0:
            stderr_text = shadow_eval.redact_secrets(str(proc.stderr or "").strip())
            if "no such file" in stderr_text.lower():
                continue
            raise RuntimeError(f"SSH fetch failed for {ssh_target} (exit {proc.returncode}): {stderr_text}")
        remote_records = _parse_jsonl_text(
            proc.stdout or "",
            default_agent=host,
            default_shadow_model=default_model,
            source=f"ssh:{ssh_target}",
        )
        all_records.extend(remote_records)

    return all_records


def _open_in_browser(
    html_path: Path,
    *,
    runner: Callable[..., subprocess.CompletedProcess] | None = None,
) -> None:
    exec_runner = runner if runner is not None else subprocess.run
    opener = "open" if sys.platform == "darwin" else "xdg-open"
    exec_runner([opener, str(html_path)], check=False)


def build_arg_parser() -> argparse.ArgumentParser:
    """Build the CLI argument parser with `MOLTIS_SHADOW_REPORT_*` environment defaults."""
    parser = argparse.ArgumentParser(
        prog="shadow_report",
        description="Render terminal scorecards and static HTML dashboards for Moltis shadow LLM evaluations.",
    )
    parser.add_argument(
        "inputs",
        nargs="*",
        help="Input JSONL (`shadow-eval.jsonl`) or `summary.json` files.",
    )
    parser.add_argument(
        "--html",
        default="",
        help="Write a self-contained HTML dashboard to this path.",
    )
    parser.add_argument(
        "--ensure-index",
        action="store_true",
        help="Ensure the host report index.html exists (without overwriting unless --force is set).",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite an existing regular index.html when used with --ensure-index.",
    )
    parser.add_argument(
        "--agent",
        default=os.environ.get("MOLTIS_SHADOW_REPORT_AGENT", ""),
        help="Agent or host name (env: MOLTIS_SHADOW_REPORT_AGENT).",
    )
    parser.add_argument(
        "--shadow-model",
        default=os.environ.get("MOLTIS_SHADOW_REPORT_MODEL", ""),
        help="Shadow LLM model name (env: MOLTIS_SHADOW_REPORT_MODEL).",
    )
    parser.add_argument(
        "--gemini-model",
        default=os.environ.get("MOLTIS_SHADOW_REPORT_GEMINI_MODEL", ""),
        help="Gemini baseline model name (env: MOLTIS_SHADOW_REPORT_GEMINI_MODEL).",
    )
    parser.add_argument(
        "--state-dir",
        default=os.environ.get("MOLTIS_SHADOW_REPORT_STATE_DIR", ""),
        help="Companion state directory holding shadow-eval.jsonl (env: MOLTIS_SHADOW_REPORT_STATE_DIR).",
    )
    parser.add_argument(
        "--summary-path",
        default=os.environ.get("MOLTIS_SHADOW_REPORT_SUMMARY_PATH", str(_default_summary_path())),
        help="Path to host summary.json (env: MOLTIS_SHADOW_REPORT_SUMMARY_PATH).",
    )
    parser.add_argument(
        "--peer-url",
        default="",
        help="Optional peer host dashboard URL shown in the header.",
    )
    parser.add_argument(
        "--peer-label",
        default="",
        help="Optional peer host link label shown in the header.",
    )
    parser.add_argument(
        "--fetch",
        action="store_true",
        help="Fetch shadow-eval.jsonl from Tailscale hosts over read-only SSH.",
    )
    parser.add_argument(
        "--hosts",
        default=",".join(DEFAULT_FETCH_HOSTS),
        help="Comma-separated hosts for --fetch (default: skrye,zannah).",
    )
    parser.add_argument(
        "--tailnet",
        default=os.environ.get("MOLTIS_SHADOW_REPORT_TAILNET", DEFAULT_TAILNET),
        help="Tailscale MagicDNS suffix for --fetch (env: MOLTIS_SHADOW_REPORT_TAILNET).",
    )
    parser.add_argument(
        "--open",
        action="store_true",
        help="Open the generated HTML dashboard in the default browser (defaults to ~/Volatile/moltis-shadow-reports/comparison.html when --html is omitted).",
    )
    return parser


def main(
    argv: list[str] | None = None,
    *,
    runner: Callable[..., subprocess.CompletedProcess] | None = None,
) -> int:
    """CLI entry point for shadow evaluation reporting."""
    parser = build_arg_parser()
    args = parser.parse_args(argv)

    if args.ensure_index:
        written = ensure_host_report_index(
            output_path=args.html or None,
            summary_path=args.summary_path,
            state_dir=args.state_dir or None,
            agent=args.agent,
            shadow_model=args.shadow_model,
            gemini_model=args.gemini_model,
            peer_url=args.peer_url,
            peer_label=args.peer_label,
            force=args.force,
        )
        if args.open:
            _open_in_browser(written, runner=runner)
        return 0

    records: list[dict[str, object]] = []
    if args.fetch:
        records.extend(
            fetch_remote_shadow_records(
                args.hosts,
                tailnet=args.tailnet,
                runner=runner,
            )
        )
    if args.inputs:
        records.extend(load_shadow_records(args.inputs))
    elif not args.fetch:
        candidate_paths: list[Path] = []
        if args.state_dir and str(args.state_dir).strip():
            candidate_paths.append(Path(args.state_dir).expanduser() / shadow_eval.SHADOW_EVAL_JSONL_FILENAME)
        elif args.agent and str(args.agent).strip():
            candidate_paths.append(_default_state_dir_for_agent(args.agent) / shadow_eval.SHADOW_EVAL_JSONL_FILENAME)
        if args.summary_path and str(args.summary_path).strip():
            candidate_paths.append(Path(args.summary_path).expanduser())
        for candidate in candidate_paths:
            if candidate.exists():
                records = parse_shadow_input(candidate)
                break

    model = build_report_model(
        records,
        agent=args.agent,
        shadow_model=args.shadow_model,
        gemini_model=args.gemini_model,
    )
    sys.stdout.write(render_terminal_scorecard(model))

    html_target: Path | None = None
    if args.html and str(args.html).strip():
        html_target = Path(args.html).expanduser()
    elif args.open:
        html_target = _default_comparison_html_path()

    if html_target is not None:
        html_content = render_html_dashboard(
            model,
            peer_url=args.peer_url,
            peer_label=args.peer_label,
            summary_href="./summary.json",
        )
        written_html = write_shadow_report_html(html_target, html_content)
        if args.open:
            _open_in_browser(written_html, runner=runner)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
