#!/usr/bin/env bash
set -euo pipefail

adapter_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
contract_path="${TRIPWIRE_ADAPTER_CONTRACT:-${adapter_dir}/contract.sh}"

# shellcheck source=/dev/null
source "${contract_path}"

# Tier B world-output PreToolUse cap, split by blast radius. Strikes deny and
# re-issue the rules so the model retries; on the limit-th strike the gate yields
# and allows the call with a user notice.
#
# Sub-tier B1 (local: bash, apply_patch, edit, write). Cheap to retract on disk.
# Three-strike-then-yield, keyed on a STABLE target (session + turn + tool + file
# path) so a model that revises the body between retries still walks the cap.
# Bash and a pathless patch fall back to session+turn+tool.
CODEX_LOCAL_STRIKE_LIMIT=3

# Sub-tier B2 (external: gh, gh-api-safe, post-capable MCP tools). Irretractable
# the instant it yields. Five-strike-then-yield, keyed on a stable identity
# (session + turn + tool, no body) so reworded retries share one budget, with an
# operator-visible notice that names the tool and target.
CODEX_EXTERNAL_STRIKE_LIMIT=5

# Tier A facing-prose handoff. Stop never blocks; it sets a pending flag so the
# next UserPromptSubmit re-issues the rules to the model.
CODEX_REISSUE_SUBDIR="reissue"

codex_payload_file=""

codex_cleanup() {
  if [[ -n "${codex_payload_file}" ]]; then
    rm -f -- "${codex_payload_file}"
  fi
}

trap codex_cleanup EXIT

codex_json_string() {
  python3 -c 'import json, sys; print(json.dumps(sys.stdin.read()))'
}

codex_emit_context() {
  local event_name="$1"
  local context_text="$2"
  local event_json
  local context_json

  event_json="$(printf '%s' "${event_name}" | codex_json_string)"
  context_json="$(printf '%s' "${context_text}" | codex_json_string)"
  printf '{"hookSpecificOutput":{"hookEventName":%s,"additionalContext":%s}}\n' \
    "${event_json}" \
    "${context_json}"
}

# Tier B world-output PreToolUse decisions use hookSpecificOutput.permissionDecision.
# The deny "permissionDecisionReason" is model-facing (re-issue the rules there);
# the allow "permissionDecisionReason" is the user-facing yield notice. Codex
# additionalContext on PreToolUse is broken (openai/codex#19385), so it is not
# used here.
codex_emit_pretooluse_deny() {
  local reason="$1"
  local reason_json

  reason_json="$(printf '%s' "${reason}" | codex_json_string)"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' \
    "${reason_json}"
}

codex_emit_pretooluse_allow() {
  local notice="$1"
  local notice_json

  notice_json="$(printf '%s' "${notice}" | codex_json_string)"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":%s}}\n' \
    "${notice_json}"
}

codex_strike_dir() {
  if [[ -n "${TRIPWIRE_RETRY_DIR:-}" ]]; then
    printf '%s\n' "${TRIPWIRE_RETRY_DIR}"
    return 0
  fi

  printf '%s\n' "${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/agent-communication-rules/codex-retries"
}

codex_strike_count() {
  local key="$1"
  local dir
  local path
  local count

  dir="$(codex_strike_dir)"
  path="${dir}/${key}.count"
  if ! mkdir -p -- "${dir}" 2>/dev/null; then
    printf '1\n'
    return 0
  fi

  if [[ -r "${path}" ]]; then
    count="$(<"${path}")"
  else
    count="0"
  fi

  if [[ ! "${count}" =~ ^[0-9]+$ ]]; then
    count="0"
  fi

  count="$((count + 1))"
  printf '%s\n' "${count}" >"${path}" 2>/dev/null || true
  printf '%s\n' "${count}"
}

codex_strike_reset() {
  local key="$1"
  local dir

  dir="$(codex_strike_dir)"
  rm -f -- "${dir}/${key}.count" 2>/dev/null || true
}

codex_block_reason() {
  if tripwire_existing_blocked "$@"; then
    return 1
  fi

  # shellcheck disable=SC2154
  if ! "$tripwire_scanner" block-message 2>/dev/null; then
    tripwire_emit_fallback_block
  fi
}

codex_emit_yield_json() {
  local system_message="$1"
  local message_json

  message_json="$(printf '%s' "${system_message}" | codex_json_string)"
  printf '{"systemMessage":%s}\n' "${message_json}"
}

# --- Tier B: PreToolUse three-strike-then-yield ----------------------------

codex_pretooluse_strike_key() {
  codex_extract pretooluse-strike-key
}

codex_pretooluse_surface() {
  codex_extract pretooluse-surface
}

# Resolve the strike key for the current surface: the stable session+turn+tool+
# target key for B1 locals, the stable session+turn+tool key for B2 externals.
codex_pretooluse_active_strike_key() {
  if [[ "$(codex_pretooluse_surface)" == "external" ]]; then
    codex_extract pretooluse-external-strike-key
  else
    codex_extract pretooluse-strike-key
  fi
}

codex_pretooluse_block_or_yield() {
  local surface
  local strike_key
  local strike_limit
  local strike_count
  local notice
  local reason

  if tripwire_existing_blocked "$@"; then
    return 0
  fi

  surface="$(codex_pretooluse_surface)"
  if [[ "${surface}" == "external" ]]; then
    strike_key="$(codex_extract pretooluse-external-strike-key)"
    strike_limit="${CODEX_EXTERNAL_STRIKE_LIMIT}"
    notice="Rules breach posted: $(codex_extract pretooluse-external-target)"
  else
    strike_key="$(codex_pretooluse_strike_key)"
    strike_limit="${CODEX_LOCAL_STRIKE_LIMIT}"
    notice="Communication Rules unmet after retries, output allowed."
  fi

  strike_count="$(codex_strike_count "${strike_key}")"
  if [[ "${strike_count}" -ge "${strike_limit}" ]]; then
    # Best-effort yield: after the denials stop blocking, allow the call, reset
    # the counter, and emit only the user-facing notice.
    codex_strike_reset "${strike_key}"
    codex_emit_pretooluse_allow "${notice}"
    return 0
  fi

  if ! reason="$(codex_block_reason "$@")"; then
    return 0
  fi
  codex_emit_pretooluse_deny "${reason}"
}

codex_fail_closed() {
  codex_pretooluse_block_or_yield "$@"
}

codex_scan_text() {
  local text="$1"

  if printf '%s' "${text}" | tripwire_scan_command scan-text >/dev/null; then
    codex_strike_reset "$(codex_pretooluse_active_strike_key)"
    return 0
  fi

  codex_pretooluse_block_or_yield
}

codex_scan_bash() {
  local command="$1"

  if printf '%s' "${command}" | tripwire_scan_command scan-bash >/dev/null; then
    codex_strike_reset "$(codex_pretooluse_active_strike_key)"
    return 0
  fi

  codex_pretooluse_block_or_yield
}

# --- Tier A: Stop / SubagentStop never-block silent re-issue ----------------

codex_reissue_key() {
  python3 - "$codex_payload_file" <<'PY'
import json
import re
import sys

try:
    with open(sys.argv[1], "r", encoding="utf-8") as handle:
        payload = json.load(handle)
except (OSError, json.JSONDecodeError):
    print("fallback")
    sys.exit(0)

session = payload.get("session_id")
raw = str(session) if isinstance(session, (str, int, float)) else ""
safe = re.sub(r"[^A-Za-z0-9_.-]", "_", raw)
print(safe or "fallback")
PY
}

codex_reissue_file() {
  local key="$1"
  local dir

  dir="$(codex_strike_dir)/${CODEX_REISSUE_SUBDIR}"
  if ! mkdir -p -- "${dir}" 2>/dev/null; then
    return 1
  fi
  printf '%s/%s.flag\n' "${dir}" "${key}"
}

codex_set_pending_reissue() {
  local flag_file

  flag_file="$(codex_reissue_file "$(codex_reissue_key)")" || return 0
  : >"${flag_file}" 2>/dev/null || true
}

# Tier A facing prose: never block, never re-roll. Emit only a short user notice
# so the turn ends, and set the pending flag so the next UserPromptSubmit
# re-issues the rules to the model.
codex_emit_facing_notice() {
  if tripwire_existing_blocked "$@"; then
    return 0
  fi

  codex_set_pending_reissue
  codex_emit_yield_json "Communication Rules breach seen, correcting next reply."
}

codex_scan_surface_text() {
  local text="$1"

  if printf '%s' "${text}" | tripwire_scan_command scan-text >/dev/null; then
    return 0
  fi

  codex_emit_facing_notice
}

# UserPromptSubmit: if a Tier A breach is pending, inject the rules re-issue as
# model-only additionalContext on this next request, then clear the flag. Codex
# supports additionalContext on UserPromptSubmit (unlike PreToolUse).
codex_emit_pending_reissue() {
  local flag_file
  local reissue

  flag_file="$(codex_reissue_file "$(codex_reissue_key)")" || return 0
  if [[ ! -e "${flag_file}" ]]; then
    return 0
  fi
  rm -f -- "${flag_file}" 2>/dev/null || true

  reissue="$(tripwire_emit_correction)"
  codex_emit_context "UserPromptSubmit" "${reissue}"
}

codex_extract() {
  python3 - "$codex_payload_file" "$@" <<'PY'
import hashlib
import json
import os
from pathlib import Path
import sys

# Baked fallbacks for the post-detection data. fragment.nix is the single
# canonical source; these copies apply only when TRIPWIRE_POLICY_JSON is unset or
# unreadable, such as in the fixture harnesses.
_FALLBACK_POST_TEXT_KEYS = (
    "body",
    "comment",
    "comments",
    "content",
    "description",
    "message",
    "messages",
    "note",
    "notes",
    "review",
    "summary",
    "text",
    "title",
)
_FALLBACK_POST_TOOL_TERMS = (
    "comment",
    "create",
    "edit",
    "post",
    "publish",
    "reply",
    "review",
    "send",
    "submit",
    "update",
    "write",
)
_FALLBACK_EXTERNAL_TARGET_KEYS = (
    "url",
    "pull_number",
    "issue_number",
    "number",
    "pullRequestId",
    "issueId",
    "discussionId",
    "id",
    "path",
    "repo",
    "repository",
    "owner",
)


def _load_post_detection():
    fallback = {
        "postTextKeys": _FALLBACK_POST_TEXT_KEYS,
        "postToolTerms": _FALLBACK_POST_TOOL_TERMS,
        "externalTargetKeys": _FALLBACK_EXTERNAL_TARGET_KEYS,
    }
    path = os.environ.get("TRIPWIRE_POLICY_JSON")
    if not path:
        return fallback
    try:
        raw = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return fallback
    node = raw
    for key in ("communicationRules", "detectionPolicy", "postDetection"):
        if not isinstance(node, dict):
            node = None
            break
        node = node.get(key)
    if not isinstance(node, dict):
        return fallback
    result = dict(fallback)
    for key in ("postTextKeys", "postToolTerms", "externalTargetKeys"):
        value = node.get(key)
        if isinstance(value, list) and all(isinstance(item, str) for item in value):
            result[key] = tuple(value)
    return result


_POST_DETECTION = _load_post_detection()
BODY_KEYS = set(_POST_DETECTION["postTextKeys"])
POST_TOOL_TERMS = _POST_DETECTION["postToolTerms"]
EXTERNAL_TARGET_KEYS = _POST_DETECTION["externalTargetKeys"]

_GH_POST_FLAGS = {
    "-b",
    "--body",
    "-F",
    "--body-file",
    "-f",
    "--field",
    "--raw-field",
    "--notes",
    "-m",
    "--message",
    "-t",
    "--title",
}


def load_payload(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def read_path(data, path):
    value = data
    for part in path.split("."):
        if isinstance(value, dict) and part in value:
            value = value[part]
        else:
            return None
    return value


def as_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, list) and all(isinstance(item, str) for item in value):
        return "\n".join(value)
    return None


def text_content(value):
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        output = []
        for item in value:
            output.extend(text_content(item))
        return output
    if isinstance(value, dict):
        if isinstance(value.get("text"), str):
            return [value["text"]]
        if isinstance(value.get("content"), str):
            return [value["content"]]
        if isinstance(value.get("content"), list):
            return text_content(value["content"])
    return []


def assistant_text_from_object(value):
    if not isinstance(value, dict):
        return []

    if value.get("role") == "assistant":
        return text_content(value.get("content"))

    message = value.get("message")
    if isinstance(message, dict) and message.get("role") == "assistant":
        return text_content(message.get("content"))

    if value.get("type") in {"assistant", "assistant_message"}:
        return text_content(value.get("content") or value.get("message"))

    return []


def transcript_last_assistant_text(path):
    try:
        raw = Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None

    stripped = raw.strip()
    if not stripped:
        return None

    last_text = None
    try:
        parsed = json.loads(stripped)
    except json.JSONDecodeError:
        parsed = None

    if isinstance(parsed, list):
        for item in parsed:
            parts = assistant_text_from_object(item)
            if parts:
                last_text = "\n".join(parts)
        return last_text

    if isinstance(parsed, dict):
        parts = assistant_text_from_object(parsed)
        if parts:
            return "\n".join(parts)

    for line in raw.splitlines():
        if not line.strip():
            continue
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            continue
        parts = assistant_text_from_object(item)
        if parts:
            last_text = "\n".join(parts)

    return last_text


def collect_body_texts(value):
    texts = []
    if isinstance(value, dict):
        for key, child in value.items():
            if key in BODY_KEYS and isinstance(child, str):
                texts.append(child)
            else:
                texts.extend(collect_body_texts(child))
    elif isinstance(value, list):
        for child in value:
            texts.extend(collect_body_texts(child))
    return texts


def is_post_capable_mcp_tool(name):
    # Match the Claude Code/Pi shape: exact gh/gh-api-safe, or an mcp__ tool whose
    # leaf segment (after the final "__") contains a post verb. No loose substring
    # match on arbitrary tool names.
    if name in {"gh", "gh-api-safe"}:
        return True
    if not name.startswith("mcp__"):
        return False
    leaf = name.rsplit("__", 1)[-1].lower()
    return any(term in leaf for term in POST_TOOL_TERMS)


def is_bash_gh_post(command):
    # A Bash command is external (B2) when its first token is gh/gh-api-safe and
    # it carries a post signal: a body-bearing flag or a POST/PATCH/PUT method.
    if not isinstance(command, str):
        return False
    argv = command.split()
    if not argv or argv[0] not in {"gh", "gh-api-safe"}:
        return False
    for index, token in enumerate(argv):
        if token in _GH_POST_FLAGS:
            return True
        if token.startswith(("--body=", "--body-file=", "--field=", "--raw-field=")):
            return True
        if token.startswith(("--notes=", "--message=", "--title=")):
            return True
        if token in {"-X", "--method"} and index + 1 < len(argv):
            if argv[index + 1].upper() in {"POST", "PATCH", "PUT"}:
                return True
        if token.startswith("--method=") and token.split("=", 1)[1].upper() in {
            "POST",
            "PATCH",
            "PUT",
        }:
            return True
        if token == "--input" or token.startswith("--input="):
            return True
    return False


def bash_command(tool_input):
    if isinstance(tool_input, dict):
        return as_text(tool_input.get("command"))
    return None


def is_external_surface(name, tool_input):
    # External (B2): a post-capable MCP tool / gh CLI tool, or a gh post run
    # through the Bash tool. Everything else is local (B1).
    if is_post_capable_mcp_tool(name):
        return True
    if name == "Bash" or name.lower() == "bash":
        return is_bash_gh_post(bash_command(tool_input))
    return False


def is_post_tool(name):
    # Post-body extraction targets: the gh CLI tools and post-capable MCP tools.
    return is_post_capable_mcp_tool(name)


def pre_tool_use_target(name, tool_input):
    # The STABLE B1 target the local strike counter keys on. For file tools this
    # is the file path, so a model that revises the body between retries still
    # accumulates strikes against the same path and yields on the 3rd. Bash and a
    # pathless patch return None: the key falls back to session+tool (see the
    # pretooluse-strike-key mode), a consecutive-block counter that resets on a
    # clean pass. Keying on the body instead would let a revising model dodge the
    # cap forever, the bug this fix removes. Trade-off for the fallback: two
    # unrelated bash commands with no pass between them share one budget. Rare and
    # acceptable.
    lowered = name.lower()
    if lowered in {"edit", "write", "apply_patch"}:
        if isinstance(tool_input, dict):
            for key in ("file_path", "path", "filename", "file"):
                path = as_text(tool_input.get(key))
                if path:
                    return path
        return None
    return None


def external_target(name, tool_input):
    # Operator-visible target for the B2 yield notice: name the post destination
    # so a breach can be retracted fast. Prefer an explicit identifier from the
    # tool input, else fall back to the tool name.
    label = name or "post"
    if isinstance(tool_input, dict):
        # Bash gh posts have no structured identifier, so name the gh subcommand
        # (e.g. "gh pr comment") from the command string.
        if label == "Bash":
            command = as_text(tool_input.get("command"))
            if isinstance(command, str):
                argv = command.split()
                if argv and argv[0] in {"gh", "gh-api-safe"}:
                    return " ".join(argv[:3])
        for key in EXTERNAL_TARGET_KEYS:
            value = tool_input.get(key)
            if isinstance(value, (str, int)) and str(value):
                return f"{label} {value}"
    return label


payload = load_payload(sys.argv[1])
mode = sys.argv[2]

if mode == "event":
    print(read_path(payload, "hook_event_name") or "")
elif mode == "pretooluse-strike-key":
    # STABLE B1 key: session + turn + tool + target, where target is the file
    # path for file tools and "" for Bash or a pathless patch. Keying on the
    # target rather than the body means a model that revises the content between
    # retries still accumulates strikes against the same path and yields on the
    # 3rd, instead of minting a fresh strike-1 key on every revision. Resets on a
    # clean pass.
    name = read_path(payload, "tool_name") or ""
    tool_input = read_path(payload, "tool_input")
    target = pre_tool_use_target(name, tool_input) or ""
    parts = [
        str(read_path(payload, "session_id") or ""),
        str(read_path(payload, "turn_id") or ""),
        str(name),
        target,
    ]
    raw = "\0".join(parts)
    print(hashlib.sha256(raw.encode("utf-8", "replace")).hexdigest())
elif mode == "pretooluse-surface":
    # B1 (local) covers bash, apply_patch, edit and write: cheap to retract on
    # disk. B2 (external) covers gh/gh-api-safe and post-capable MCP tools, plus
    # a gh post run through the Bash tool: irretractable the instant they yield.
    name = read_path(payload, "tool_name") or ""
    tool_input = read_path(payload, "tool_input")
    print("external" if is_external_surface(name, tool_input) else "local")
elif mode == "pretooluse-external-strike-key":
    # STABLE B2 key: session_id + turn_id + tool_name, with NO body hash, so
    # reworded retries of the same logical post in the same turn draw down one
    # budget. Resets on any allow or pass.
    name = read_path(payload, "tool_name") or ""
    parts = [
        "external",
        str(read_path(payload, "session_id") or ""),
        str(read_path(payload, "turn_id") or ""),
        str(name),
    ]
    raw = "\0".join(parts)
    print(hashlib.sha256(raw.encode("utf-8", "replace")).hexdigest())
elif mode == "pretooluse-external-target":
    name = read_path(payload, "tool_name") or ""
    tool_input = read_path(payload, "tool_input")
    print(external_target(name, tool_input))
elif mode == "tool-name":
    print(read_path(payload, "tool_name") or "")
elif mode == "tool-command":
    tool_input = read_path(payload, "tool_input")
    text = None
    if isinstance(tool_input, dict):
        text = as_text(tool_input.get("command"))
    print(text or "")
elif mode == "tool-text":
    tool_input = read_path(payload, "tool_input")
    text = None
    if isinstance(tool_input, dict):
        for key in ("content", "new_string", "text", "patch", "command", "input"):
            text = as_text(tool_input.get(key))
            if text:
                break
    elif isinstance(tool_input, str):
        text = tool_input
    print(text or "")
elif mode == "post-text":
    name = read_path(payload, "tool_name") or ""
    tool_input = read_path(payload, "tool_input")
    if not is_post_tool(name):
        sys.exit(3)
    texts = collect_body_texts(tool_input)
    if not texts:
        sys.exit(2)
    print("\n".join(texts))
elif mode == "assistant-message":
    value = read_path(payload, "last_assistant_message")
    if isinstance(value, str) and value:
        print(value)
        sys.exit(0)
    for path_key in ("transcript_path", "agent_transcript_path"):
        transcript_path = read_path(payload, path_key)
        if isinstance(transcript_path, str) and transcript_path:
            text = transcript_last_assistant_text(transcript_path)
            if isinstance(text, str) and text:
                print(text)
                sys.exit(0)
    sys.exit(2)
else:
    sys.exit(64)
PY
}

codex_handle_reminder() {
  local event_name="$1"
  local reminder

  if ! reminder="$("$tripwire_scanner" remind 2>/dev/null)"; then
    return 0
  fi

  if [[ -n "${reminder}" ]]; then
    codex_emit_context "${event_name}" "${reminder}"
  fi
}

codex_handle_pre_tool_use() {
  local tool_name
  local command
  local text

  tool_name="$(codex_extract tool-name)"
  case "${tool_name}" in
    Bash)
      command="$(codex_extract tool-command)"
      if [[ -z "${command}" ]]; then
        codex_fail_closed "$@"
        return 0
      fi
      codex_scan_bash "${command}"
      ;;
    apply_patch | Edit | Write)
      text="$(codex_extract tool-text)"
      if [[ -z "${text}" ]]; then
        codex_fail_closed "$@"
        return 0
      fi
      codex_scan_text "${text}"
      ;;
    *)
      if text="$(codex_extract post-text)"; then
        codex_scan_text "${text}"
      else
        case "$?" in
          2)
            codex_fail_closed "$@"
            ;;
          *)
            return 0
            ;;
        esac
      fi
      ;;
  esac
}

codex_handle_stop() {
  local message

  if ! message="$(codex_extract assistant-message)"; then
    codex_emit_facing_notice "$@"
    return 0
  fi

  codex_scan_surface_text "${message}"
}

codex_main() {
  local event_name

  codex_payload_file="$(mktemp "${TMPDIR:-/tmp}/tripwire-codex.XXXXXX")"
  cat >"${codex_payload_file}"

  event_name="$(codex_extract event)"
  case "${event_name}" in
    SessionStart | SubagentStart)
      codex_handle_reminder "${event_name}"
      ;;
    UserPromptSubmit)
      codex_emit_pending_reissue
      ;;
    PreToolUse)
      codex_handle_pre_tool_use "$@"
      ;;
    Stop | SubagentStop)
      codex_handle_stop "$@"
      ;;
    *)
      return 0
      ;;
  esac
}

codex_main "$@"
