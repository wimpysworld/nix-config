#!/usr/bin/env bash
set -euo pipefail

adapter_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
contract_path="${TRIPWIRE_ADAPTER_CONTRACT:-${adapter_dir}/contract.sh}"

# shellcheck source=/dev/null
source "${contract_path}"

opencode_usage() {
	cat <<'EOF'
Usage: opencode.sh <command> [--existing-blocked] [payload.json]

Commands:
  tool-execute-before  Gate outgoing prose from tool.execute.before payloads.
  post-display         Request correction for displayed final or subagent prose.
EOF
}

opencode_read_payload() {
	local payload_path="${1:-}"

	if [[ -n "${payload_path}" ]]; then
		cat -- "${payload_path}"
		return 0
	fi

	cat
}

opencode_extract_payload() {
	local mode="$1"
	local payload="$2"
	local action_path="$3"
	local value_path="$4"

	OPENCODE_PAYLOAD="${payload}" python3 - "${mode}" "${action_path}" "${value_path}" <<'PY'
from __future__ import annotations

import json
import os
import sys
from typing import Any


WRITE_FIELDS = ("content", "text", "body", "value", "newContent", "fileContent")
EDIT_FIELDS = ("newString", "new_string", "replacement", "content", "text")
PATCH_FIELDS = ("patch", "patchText", "diff", "content", "text")
BASH_FIELDS = ("command", "cmd", "script", "bash")
POST_FIELDS = ("body", "comment", "message", "note", "notes", "text", "title")
DISPLAY_FIELDS = ("content", "message", "text", "output", "final", "response")


def write_result(action: str, value: str = "") -> int:
    action_path = sys.argv[2]
    value_path = sys.argv[3]
    with open(action_path, "w", encoding="utf-8") as handle:
        handle.write(action)
    with open(value_path, "w", encoding="utf-8") as handle:
        handle.write(value)
    return 0


def load_payload() -> Any:
    raw = os.environ.get("OPENCODE_PAYLOAD", "")
    return json.loads(raw)


def strings(value: Any) -> list[str]:
    output: list[str] = []
    if isinstance(value, str):
        if value:
            output.append(value)
    elif isinstance(value, list):
        for item in value:
            output.extend(strings(item))
    elif isinstance(value, dict):
        for item in value.values():
            output.extend(strings(item))
    return output


def first_string(data: Any, keys: tuple[str, ...]) -> str | None:
    if not isinstance(data, dict):
        return None
    for key in keys:
        value = data.get(key)
        if isinstance(value, str) and value:
            return value
    for value in data.values():
        if isinstance(value, dict):
            found = first_string(value, keys)
            if found:
                return found
    return None


def collect_strings(data: Any, keys: tuple[str, ...]) -> list[str]:
    found: list[str] = []
    if isinstance(data, dict):
        for key, value in data.items():
            if key in keys:
                found.extend(strings(value))
            elif isinstance(value, (dict, list)):
                found.extend(collect_strings(value, keys))
    elif isinstance(data, list):
        for item in data:
            found.extend(collect_strings(item, keys))
    return found


def tool_name(data: Any) -> str:
    candidates = []
    if isinstance(data, dict):
        candidates.extend(
            [
                data.get("tool"),
                data.get("toolName"),
                data.get("tool_name"),
                data.get("name"),
                data.get("id"),
            ]
        )
        tool = data.get("tool")
        if isinstance(tool, dict):
            candidates.extend([tool.get("name"), tool.get("id")])
        call = data.get("call")
        if isinstance(call, dict):
            candidates.extend([call.get("name"), call.get("tool"), call.get("id")])
    for candidate in candidates:
        if isinstance(candidate, str) and candidate:
            return candidate
    return ""


def arguments(data: Any) -> Any:
    if not isinstance(data, dict):
        return {}
    for key in ("args", "arguments", "input", "parameters"):
        value = data.get(key)
        if isinstance(value, (dict, list, str)):
            return value
    tool = data.get("tool")
    if isinstance(tool, dict):
        for key in ("args", "arguments", "input", "parameters"):
            value = tool.get(key)
            if isinstance(value, (dict, list, str)):
                return value
    call = data.get("call")
    if isinstance(call, dict):
        for key in ("args", "arguments", "input", "parameters"):
            value = call.get(key)
            if isinstance(value, (dict, list, str)):
                return value
    return {}


def event_name(data: Any) -> str:
    if not isinstance(data, dict):
        return ""
    for key in ("event", "hook", "type"):
        value = data.get(key)
        if isinstance(value, str):
            return value
    return ""


def normalise_name(name: str) -> str:
    return name.lower().replace("-", "_").replace(".", "_")


def command_from_args(args: Any) -> str | None:
    if isinstance(args, str) and args:
        return args
    if isinstance(args, list) and args:
        return " ".join(str(item) for item in args)
    if isinstance(args, dict):
        command = first_string(args, BASH_FIELDS)
        if command:
            return command
        argv = args.get("argv") or args.get("args")
        if isinstance(argv, list) and argv:
            return " ".join(str(item) for item in argv)
    return None


def is_write_tool(name: str) -> bool:
    normalised = normalise_name(name)
    return normalised in {"write", "file_write", "write_file"} or normalised.endswith("_write")


def is_edit_tool(name: str) -> bool:
    normalised = normalise_name(name)
    return normalised in {"edit", "multiedit", "multi_edit", "str_replace"} or normalised.endswith("_edit")


def is_patch_tool(name: str) -> bool:
    normalised = normalise_name(name)
    return normalised in {"patch", "apply_patch"} or normalised.endswith("_patch")


def is_bash_tool(name: str) -> bool:
    normalised = normalise_name(name)
    return normalised in {"bash", "shell", "run_command", "execute_command"}


def is_post_tool(name: str, args: Any) -> bool:
    normalised = normalise_name(name)
    if normalised in {"gh", "gh_api_safe", "github"}:
        return True
    command = command_from_args(args)
    if command:
        stripped = command.strip()
        return stripped.startswith("gh ") or stripped.startswith("gh-api-safe ")
    if isinstance(args, dict):
        return any(key in args for key in POST_FIELDS)
    return False


def patch_added_text(patch: str) -> str:
    lines: list[str] = []
    for line in patch.splitlines():
        if not line.startswith("+"):
            continue
        if line == "+++" or line.startswith("+++ ") or line.startswith("+++\t"):
            continue
        lines.append(line[1:])
    return "\n".join(lines)


def extract_tool(data: Any) -> tuple[str, str]:
    if event_name(data) not in {"", "tool.execute.before"}:
        return "pass", ""

    name = tool_name(data)
    args = arguments(data)

    if is_write_tool(name):
        text = first_string(args, WRITE_FIELDS)
        return ("gate-text", text) if text else ("fail-closed", "")

    if is_edit_tool(name):
        text = first_string(args, EDIT_FIELDS)
        return ("gate-text", text) if text else ("fail-closed", "")

    if is_patch_tool(name):
        text = first_string(args, PATCH_FIELDS)
        if not text:
            return "fail-closed", ""
        additions = patch_added_text(text)
        return ("gate-text", additions) if additions else ("pass", "")

    if is_bash_tool(name):
        command = command_from_args(args)
        return ("gate-bash", command) if command else ("fail-closed", "")

    if is_post_tool(name, args):
        command = command_from_args(args)
        if command:
            return "gate-bash", command
        texts = collect_strings(args, POST_FIELDS)
        return ("gate-text", "\n".join(texts)) if texts else ("fail-closed", "")

    return "pass", ""


def display_surface(data: Any) -> bool:
    if not isinstance(data, dict):
        return False
    event = event_name(data)
    if event in {"message.final", "message.end", "subagent.final", "subagent.end"}:
        return True
    surface = data.get("surface") or data.get("messageType") or data.get("kind")
    return surface in {"final", "subagent"}


def extract_display(data: Any) -> tuple[str, str]:
    if not display_surface(data):
        return "pass", ""
    texts = collect_strings(data, DISPLAY_FIELDS)
    if not texts:
        return "pass", ""
    return "correction", "\n".join(texts)


def main() -> int:
    mode = sys.argv[1]
    try:
        data = load_payload()
    except (json.JSONDecodeError, OSError):
        return write_result("fail-closed", "")

    if mode == "tool-execute-before":
        action, value = extract_tool(data)
    elif mode == "post-display":
        action, value = extract_display(data)
    else:
        action, value = "usage", ""

    return write_result(action, value)


raise SystemExit(main())
PY
}

opencode_handle_tool_execute_before() {
	local value
	local action="$1"
	local value_path="$2"
	shift 2
	local existing_blocked_args=("$@")

	value="$(cat -- "${value_path}")"
	case "${action}" in
	pass)
		tripwire_state pass
		;;
	gate-text)
		tripwire_gate scan-text "${existing_blocked_args[@]}" "${value}"
		;;
	gate-bash)
		tripwire_gate scan-bash "${existing_blocked_args[@]}" "${value}"
		;;
	fail-closed)
		tripwire_fail_closed "${existing_blocked_args[@]}"
		;;
	*)
		opencode_usage >&2
		return 2
		;;
	esac
}

opencode_handle_post_display() {
	local value
	local action="$1"
	local value_path="$2"

	value="$(cat -- "${value_path}")"
	case "${action}" in
	pass)
		tripwire_state pass
		;;
	correction)
		if tripwire_scan_command scan-text "${value}" >/dev/null; then
			tripwire_state pass
			return 0
		fi
		tripwire_emit_correction
		printf 'correction-request\n'
		return 1
		;;
	fail-closed)
		tripwire_state pass
		;;
	*)
		opencode_usage >&2
		return 2
		;;
	esac
}

opencode_main() {
	local command="${1:-}"
	shift || true

	local existing_blocked_args=()
	local payload_path=""
	local arg
	for arg in "$@"; do
		case "${arg}" in
		--existing-blocked)
			existing_blocked_args+=("${arg}")
			;;
		*)
			payload_path="${arg}"
			;;
		esac
	done

	case "${command}" in
	tool-execute-before | post-display)
		;;
	-h | --help | help)
		opencode_usage
		return 0
		;;
	*)
		opencode_usage >&2
		return 2
		;;
	esac

	local payload
	payload="$(opencode_read_payload "${payload_path}")"

	local action_path
	local value_path
	action_path="$(mktemp)"
	value_path="$(mktemp)"
	trap 'rm -f -- "${action_path}" "${value_path}"' RETURN

	opencode_extract_payload "${command}" "${payload}" "${action_path}" "${value_path}"
	local action
	action="$(cat -- "${action_path}")"

	case "${command}" in
	tool-execute-before)
		opencode_handle_tool_execute_before "${action}" "${value_path}" "${existing_blocked_args[@]}"
		;;
	post-display)
		opencode_handle_post_display "${action}" "${value_path}"
		;;
	esac
}

opencode_main "$@"
