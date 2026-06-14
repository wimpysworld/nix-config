#!/usr/bin/env python3
"""Deterministic Communication Rules scanner."""

from __future__ import annotations

import argparse
import json
import re
import shlex
import sys
from pathlib import Path


FALLBACK_RULES_TEXT = "Communication Rules were not loaded."

DEFAULT_POLICY = {
    "blockedCodepoints": [
        {"codepoint": "U+2014", "name": "em dash"},
        {"codepoint": "U+2013", "name": "en dash"},
    ],
    "hardGateBannedTerms": [
        "delve",
        "leverage",
        "tapestry",
        "robust",
        "seamless",
        "pivotal",
        "crucial",
        "testament",
        "cutting-edge",
        "multifaceted",
        "realm",
        "vibrant",
        "nuanced",
        "intricate",
        "showcasing",
        "streamline",
        "garnered",
        "underpinning",
        "underscores",
    ],
}

BODY_FLAGS = {
    "--body",
    "-b",
    "--message",
    "-m",
    "--notes",
    "-n",
    "--title",
    "-t",
}
BODY_FILE_FLAGS = {
    "--body-file",
    "--notes-file",
}
API_FIELD_FLAGS = {
    "-f",
    "-F",
    "--field",
    "--raw-field",
}
API_BODY_KEYS = {
    "body",
    "comment",
    "message",
    "note",
    "notes",
    "text",
    "title",
}
POST_COMMANDS = {
    ("issue", "create"),
    ("issue", "edit"),
    ("issue", "comment"),
    ("pr", "create"),
    ("pr", "edit"),
    ("pr", "comment"),
    ("pr", "review"),
    ("release", "create"),
    ("release", "edit"),
}
REDIRECT_HEREDOC_COMMANDS = {
    "cat",
    "tee",
}
PROSE_SUFFIXES = {
    ".md",
    ".markdown",
    ".txt",
    ".adoc",
    ".rst",
}
PROSE_NAME_PARTS = {
    "body",
    "comment",
    "issue",
    "message",
    "pr",
    "release",
    "review",
}
DYNAMIC_MARKERS = ("$(", "${", "`", "<(")


class Config:
    def __init__(
        self,
        rules_text: str,
        reminder_prompt: str | None,
        block_message: str | None,
        policy: dict,
    ) -> None:
        self.rules_text = rules_text
        self.reminder_prompt = reminder_prompt or format_reminder(rules_text)
        self.block_message = block_message or format_block_message(rules_text)
        self.policy = policy


def format_reminder(rules_text: str) -> str:
    return (
        "Reminder: Follow the Communication Rules for any prose you produce or write.\n\n"
        f"Communication Rules:\n{rules_text}"
    )


def format_block_message(rules_text: str) -> str:
    return (
        "Blocked. Revise this prose to follow the Communication Rules.\n\n"
        f"Communication Rules:\n{rules_text}"
    )


def normalise_loaded_config(value: object) -> dict:
    if not isinstance(value, dict):
        return {}
    if isinstance(value.get("agentic"), dict):
        agentic = value["agentic"]
        if isinstance(agentic.get("communicationRules"), dict):
            return agentic["communicationRules"]
    if isinstance(value.get("communicationRules"), dict):
        return value["communicationRules"]
    return value


def read_text_file(path: str) -> str | None:
    try:
        return Path(path).read_text(encoding="utf-8")
    except OSError:
        return None
    except UnicodeDecodeError:
        return None


def load_config(args: argparse.Namespace) -> Config | None:
    rules_text = FALLBACK_RULES_TEXT
    reminder_prompt = None
    block_message = None
    policy = dict(DEFAULT_POLICY)

    if getattr(args, "policy_json", None):
        raw_json = read_text_file(args.policy_json)
        if raw_json is None:
            return None
        try:
            loaded = normalise_loaded_config(json.loads(raw_json))
        except json.JSONDecodeError:
            return None

        loaded_text = loaded.get("text") or loaded.get("rulesText")
        if isinstance(loaded_text, str):
            rules_text = loaded_text

        if isinstance(loaded.get("reminderPrompt"), str):
            reminder_prompt = loaded["reminderPrompt"]
        if isinstance(loaded.get("blockMessage"), str):
            block_message = loaded["blockMessage"]
        if isinstance(loaded.get("detectionPolicy"), dict):
            policy = merge_policy(policy, loaded["detectionPolicy"])

    if getattr(args, "rules", None):
        loaded_rules = read_text_file(args.rules)
        if loaded_rules is None:
            return None
        rules_text = loaded_rules.strip()
        if reminder_prompt is None:
            reminder_prompt = format_reminder(rules_text)
        if block_message is None:
            block_message = format_block_message(rules_text)

    return Config(rules_text, reminder_prompt, block_message, policy)


def merge_policy(default_policy: dict, loaded_policy: dict) -> dict:
    merged = dict(default_policy)
    if isinstance(loaded_policy.get("blockedCodepoints"), list):
        merged["blockedCodepoints"] = loaded_policy["blockedCodepoints"]
    if isinstance(loaded_policy.get("hardGateBannedTerms"), list):
        merged["hardGateBannedTerms"] = loaded_policy["hardGateBannedTerms"]
    return merged


def write_message(message: str) -> int:
    sys.stdout.write(message.rstrip("\n"))
    sys.stdout.write("\n")
    return 0


def emit_scan_result(blocked: bool, output_format: str) -> int:
    result = "block" if blocked else "pass"
    if output_format == "json":
        sys.stdout.write(json.dumps({"result": result}, sort_keys=True))
        sys.stdout.write("\n")
    else:
        sys.stdout.write(f"{result}\n")
    return 1 if blocked else 0


def strip_fenced_code_blocks(text: str) -> str:
    output: list[str] = []
    in_fence = False
    fence_char = ""
    fence_len = 0

    for line in text.splitlines(keepends=True):
        if not in_fence:
            match = re.match(r"^[ \t]{0,3}(`{3,}|~{3,})", line)
            if match:
                fence = match.group(1)
                in_fence = True
                fence_char = fence[0]
                fence_len = len(fence)
                continue
            output.append(line)
            continue

        close_pattern = r"^[ \t]{0,3}" + re.escape(fence_char) + "{" + str(fence_len) + r",}[ \t]*$"
        if re.match(close_pattern, line.rstrip("\n\r")):
            in_fence = False
            fence_char = ""
            fence_len = 0

    return "".join(output)


def strip_outer_fence(text: str) -> str:
    lines = text.strip().splitlines()
    if len(lines) < 2:
        return text.strip()

    opening = re.match(r"^[ \t]{0,3}(`{3,}|~{3,})(?:[A-Za-z0-9_-]+)?[ \t]*$", lines[0])
    if not opening:
        return text.strip()

    fence = opening.group(1)
    closing = re.match(
        r"^[ \t]{0,3}" + re.escape(fence[0]) + "{" + str(len(fence)) + r",}[ \t]*$",
        lines[-1],
    )
    if not closing:
        return text.strip()

    return "\n".join(lines[1:-1]).strip()


def strip_blockquote_markers(text: str) -> str:
    lines = text.strip().splitlines()
    nonempty = [line for line in lines if line.strip()]
    if not nonempty or not all(line.lstrip().startswith(">") for line in nonempty):
        return text.strip()

    output: list[str] = []
    for line in lines:
        stripped = line.lstrip()
        if stripped.startswith(">"):
            stripped = stripped[1:]
            if stripped.startswith(" "):
                stripped = stripped[1:]
        output.append(stripped)
    return "\n".join(output).strip()


def strip_disclosure_heading(text: str) -> str:
    stripped = text.strip()
    for heading in ("Communication Rules:", "## Communication Rules"):
        if stripped == heading:
            return ""
        prefix = heading + "\n"
        if stripped.startswith(prefix):
            return stripped[len(prefix) :].strip()
    return stripped


def canonical_disclosure_body(text: str) -> str:
    return strip_disclosure_heading(strip_blockquote_markers(strip_outer_fence(text)))


def is_canonical_rules_disclosure(text: str, config: Config) -> bool:
    return canonical_disclosure_body(text) == config.rules_text.strip()


def blocked_codepoint_chars(policy: dict) -> list[str]:
    chars: list[str] = []
    for item in policy.get("blockedCodepoints", []):
        if not isinstance(item, dict):
            continue
        codepoint = item.get("codepoint")
        if not isinstance(codepoint, str) or not codepoint.upper().startswith("U+"):
            continue
        try:
            chars.append(chr(int(codepoint[2:], 16)))
        except ValueError:
            continue
    return chars


def term_pattern(term: str) -> re.Pattern[str] | None:
    parts = term.strip().split()
    if not parts:
        return None
    body = r"\s+".join(re.escape(part) for part in parts)
    return re.compile(r"(?<![A-Za-z0-9_])" + body + r"(?![A-Za-z0-9_])", re.IGNORECASE)


def term_patterns(policy: dict) -> list[re.Pattern[str]]:
    patterns: list[re.Pattern[str]] = []
    for term in policy.get("hardGateBannedTerms", []):
        if not isinstance(term, str):
            continue
        pattern = term_pattern(term)
        if pattern is not None:
            patterns.append(pattern)
    return patterns


def scan_prose(text: str, config: Config, strip_fences: bool) -> bool:
    if is_canonical_rules_disclosure(text, config):
        return False

    inspected = strip_fenced_code_blocks(text) if strip_fences else text
    for char in blocked_codepoint_chars(config.policy):
        if char in inspected:
            return True
    for pattern in term_patterns(config.policy):
        if pattern.search(inspected):
            return True
    return False


def command_text_from_args(parts: list[str]) -> str:
    if parts:
        return " ".join(parts)
    return sys.stdin.read()


def parse_command_line(line: str) -> list[str] | None:
    try:
        return shlex.split(line, posix=True)
    except ValueError:
        return None


def split_command_segments(argv: list[str]) -> list[list[str]]:
    # Split a parsed argv on sequential shell control operators so each chained
    # command is scanned in isolation. shlex.split keeps these operators as
    # standalone tokens, so a single line such as "gh ... && echo ... > notes.md"
    # yields a segment per command and the second command's redirect is no longer
    # hidden. A pipe "|" is deliberately not a split operator: it is a data
    # conduit, not a command boundary, so prose piped into "tee" or a redirect
    # must stay in one segment for the redirect collector to see the sink.
    segments: list[list[str]] = []
    current: list[str] = []
    for token in argv:
        if token in {"&&", "||", ";", "&"}:
            if current:
                segments.append(current)
            current = []
            continue
        current.append(token)
    if current:
        segments.append(current)
    return segments


def command_name(argv: list[str]) -> str:
    if not argv:
        return ""
    return Path(argv[0]).name


def has_dynamic_value(value: str) -> bool:
    stripped = value.strip()
    if stripped.startswith("$"):
        return True
    return any(marker in stripped for marker in DYNAMIC_MARKERS)


def option_value(argv: list[str], index: int) -> tuple[str | None, int]:
    token = argv[index]
    if "=" in token and token.startswith("--"):
        return token.split("=", 1)[1], index
    if index + 1 >= len(argv):
        return None, index
    return argv[index + 1], index + 1


def read_body_file(value: str) -> tuple[str | None, bool]:
    if has_dynamic_value(value) or value == "-":
        return None, True
    text = read_text_file(value)
    if text is None:
        return None, True
    return text, False


def clean_literal_path(value: str) -> str | None:
    cleaned = value.strip("'\"")
    if not cleaned or has_dynamic_value(cleaned):
        return None
    return cleaned


def extract_heredoc_blocks(script: str) -> list[tuple[str, str]]:
    lines = script.splitlines()
    blocks: list[tuple[str, str]] = []
    index = 0
    while index < len(lines):
        command_line = lines[index]
        match = re.search(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1", command_line)
        if not match:
            index += 1
            continue
        delimiter = match.group(2)
        index += 1
        body: list[str] = []
        while index < len(lines) and lines[index].strip() != delimiter:
            body.append(lines[index])
            index += 1
        if body:
            blocks.append((command_line.strip(), "\n".join(body)))
        if index < len(lines):
            index += 1
    return blocks


def heredoc_bodies_by_line(blocks: list[tuple[str, str]]) -> dict[str, list[str]]:
    bodies: dict[str, list[str]] = {}
    for line, body in blocks:
        bodies.setdefault(line, []).append(body)
    return bodies


def heredoc_body_files(blocks: list[tuple[str, str]]) -> dict[str, str]:
    files: dict[str, str] = {}
    for line, body in blocks:
        argv = parse_command_line(line)
        if argv is None or command_name(argv) not in REDIRECT_HEREDOC_COMMANDS:
            continue
        for target in redirect_targets(argv):
            cleaned = clean_literal_path(target)
            if cleaned is not None:
                files[cleaned] = body
    return files


def command_lines_without_heredoc_bodies(script: str) -> list[str]:
    lines = script.splitlines()
    output: list[str] = []
    index = 0
    while index < len(lines):
        line = lines[index]
        output.append(line)
        match = re.search(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1", line)
        if not match:
            index += 1
            continue
        delimiter = match.group(2)
        index += 1
        while index < len(lines) and lines[index].strip() != delimiter:
            index += 1
        if index < len(lines):
            index += 1
    return output


def is_known_post_command(argv: list[str]) -> bool:
    if is_help_command(argv):
        return False
    name = command_name(argv)
    if name == "gh":
        if len(argv) >= 3 and (argv[1], argv[2]) in POST_COMMANDS:
            return True
        if len(argv) >= 2 and argv[1] == "api":
            return has_api_post_signal(argv[2:])
        return any(has_body_flag(argv, index) for index in range(len(argv)))
    if name == "gh-api-safe":
        return has_api_post_signal(argv[1:])
    return False


def is_help_command(argv: list[str]) -> bool:
    return any(token in {"-h", "--help"} for token in argv[1:])


def has_body_flag(argv: list[str], index: int) -> bool:
    token = argv[index]
    if token in BODY_FLAGS or token in BODY_FILE_FLAGS or token in API_FIELD_FLAGS:
        return True
    if token.startswith("--body=") or token.startswith("--message="):
        return True
    if token.startswith("--notes=") or token.startswith("--title="):
        return True
    if token.startswith("--field=") or token.startswith("--raw-field="):
        return True
    return False


def has_api_post_signal(argv: list[str]) -> bool:
    index = 0
    while index < len(argv):
        token = argv[index]
        value = None
        if token in {"-X", "--method"}:
            value, index = option_value(argv, index)
            if value and value.upper() in {"POST", "PATCH", "PUT"}:
                return True
        elif token.startswith("--method="):
            if token.split("=", 1)[1].upper() in {"POST", "PATCH", "PUT"}:
                return True
        elif token in API_FIELD_FLAGS or token.startswith("--field=") or token.startswith("--raw-field="):
            return True
        elif token == "--input" or token.startswith("--input="):
            return True
        index += 1
    return False


def read_post_body_file(value: str, heredoc_files: dict[str, str]) -> tuple[str | None, bool]:
    cleaned = clean_literal_path(value)
    if cleaned is None or cleaned == "-":
        return None, True
    if cleaned in heredoc_files:
        return heredoc_files[cleaned], False
    return read_body_file(cleaned)


def extract_post_texts(argv: list[str], heredoc_files: dict[str, str]) -> tuple[list[str], bool]:
    texts: list[str] = []
    unresolved = False
    index = 0

    while index < len(argv):
        token = argv[index]

        if token in BODY_FLAGS or any(token.startswith(flag + "=") for flag in BODY_FLAGS if flag.startswith("--")):
            value, index = option_value(argv, index)
            if value is None or has_dynamic_value(value):
                unresolved = True
            else:
                texts.append(value)
        elif token in BODY_FILE_FLAGS or any(token.startswith(flag + "=") for flag in BODY_FILE_FLAGS if flag.startswith("--")):
            value, index = option_value(argv, index)
            if value is None:
                unresolved = True
            else:
                text, failed = read_post_body_file(value, heredoc_files)
                unresolved = unresolved or failed
                if text is not None:
                    texts.append(text)
        elif token in API_FIELD_FLAGS or token.startswith("--field=") or token.startswith("--raw-field="):
            value, index = option_value(argv, index)
            text, failed = extract_api_field_text(value, heredoc_files)
            unresolved = unresolved or failed
            if text is not None:
                texts.append(text)
        elif token == "--input" or token.startswith("--input="):
            value, index = option_value(argv, index)
            if value is None:
                unresolved = True
            else:
                text, failed = read_post_body_file(value, heredoc_files)
                unresolved = unresolved or failed
                if text is not None:
                    texts.append(text)

        index += 1

    return texts, unresolved


def extract_api_field_text(value: str | None, heredoc_files: dict[str, str]) -> tuple[str | None, bool]:
    if value is None or "=" not in value:
        return None, True
    key, raw_value = value.split("=", 1)
    if key not in API_BODY_KEYS:
        return None, False
    if has_dynamic_value(raw_value):
        return None, True
    if raw_value.startswith("@"):
        return read_post_body_file(raw_value[1:], heredoc_files)
    return raw_value, False


def prose_target(path_value: str) -> bool:
    cleaned = clean_literal_path(path_value)
    if cleaned is None:
        return False
    path = Path(cleaned)
    if path.suffix.lower() in PROSE_SUFFIXES:
        return True
    lowered = path.name.lower()
    return any(part in lowered for part in PROSE_NAME_PARTS)


def redirect_targets(argv: list[str]) -> list[str]:
    targets: list[str] = []
    index = 0
    while index < len(argv):
        token = argv[index]
        if token in {">", ">>"}:
            if index + 1 < len(argv):
                targets.append(argv[index + 1])
                index += 1
        elif token.startswith(">>") and len(token) > 2:
            targets.append(token[2:])
        elif token.startswith(">") and len(token) > 1:
            targets.append(token[1:])
        elif token == "tee":
            index += 1
            while index < len(argv) and argv[index].startswith("-"):
                index += 1
            if index < len(argv):
                targets.append(argv[index])
        index += 1
    return targets


def extract_redirect_texts(argv: list[str], heredocs: list[str]) -> tuple[list[str], bool]:
    targets = [target for target in redirect_targets(argv) if prose_target(target)]
    if not targets:
        return [], False

    command = command_name(argv)
    if command in {"echo", "printf"}:
        texts: list[str] = []
        for token in argv[1:]:
            if token in {">", ">>"} or token.startswith(">") or token.startswith("<<"):
                break
            if has_dynamic_value(token):
                return [], True
            texts.append(token)
        return ([" ".join(texts)], False) if texts else ([], True)

    if command in REDIRECT_HEREDOC_COMMANDS and "<<" in " ".join(argv) and heredocs:
        return heredocs, False

    return [], False


def scan_bash(command_text: str, config: Config) -> bool:
    heredoc_blocks = extract_heredoc_blocks(command_text)
    heredocs_by_line = heredoc_bodies_by_line(heredoc_blocks)
    body_files = heredoc_body_files(heredoc_blocks)
    blocked = False

    for line in command_lines_without_heredoc_bodies(command_text):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        argv = parse_command_line(stripped)
        if argv is None:
            continue

        heredocs = heredocs_by_line.get(stripped, [])
        for segment in split_command_segments(argv):
            if is_known_post_command(segment):
                texts, unresolved = extract_post_texts(segment, body_files)
                if unresolved or not texts:
                    return True
                for text in texts:
                    blocked = blocked or scan_prose(text, config, strip_fences=True)

            texts, unresolved = extract_redirect_texts(segment, heredocs)
            if unresolved:
                return True
            for text in texts:
                blocked = blocked or scan_prose(text, config, strip_fences=True)

    return blocked


def run_scan_text(args: argparse.Namespace, config: Config) -> int:
    text = " ".join(args.text) if args.text else sys.stdin.read()
    blocked = scan_prose(text, config, strip_fences=not args.no_strip_fences)
    return emit_scan_result(blocked, args.output_format)


def run_scan_file(args: argparse.Namespace, config: Config) -> int:
    text = read_text_file(args.path)
    if text is None:
        return emit_scan_result(True, args.output_format)
    blocked = scan_prose(text, config, strip_fences=not args.no_strip_fences)
    return emit_scan_result(blocked, args.output_format)


def run_scan_bash(args: argparse.Namespace, config: Config) -> int:
    command_text = command_text_from_args(args.bash_command)
    blocked = scan_bash(command_text, config)
    return emit_scan_result(blocked, args.output_format)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Scan generated prose for Communication Rules hard gates.")
    parser.add_argument("--policy-json", "--policy", dest="policy_json", help="JSON policy or generated config path.")
    parser.add_argument("--rules", help="Generated Communication Rules text path.")

    subparsers = parser.add_subparsers(dest="mode", required=True)

    subparsers.add_parser("remind", help="Print the reminder prompt.")
    subparsers.add_parser("block-message", help="Print the user-facing block message.")

    scan_text_parser = subparsers.add_parser("scan-text", help="Scan text from an argument or stdin.")
    scan_text_parser.add_argument("--format", dest="output_format", choices=("plain", "json"), default="plain")
    scan_text_parser.add_argument("--no-strip-fences", action="store_true")
    scan_text_parser.add_argument("text", nargs=argparse.REMAINDER)

    scan_file_parser = subparsers.add_parser("scan-file", help="Scan a prose file.")
    scan_file_parser.add_argument("--format", dest="output_format", choices=("plain", "json"), default="plain")
    scan_file_parser.add_argument("--no-strip-fences", action="store_true")
    scan_file_parser.add_argument("path")

    scan_bash_parser = subparsers.add_parser("scan-bash", help="Scan supported Bash prose side effects.")
    scan_bash_parser.add_argument("--format", dest="output_format", choices=("plain", "json"), default="plain")
    scan_bash_parser.add_argument("bash_command", nargs=argparse.REMAINDER)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    config = load_config(args)

    if args.mode == "remind":
        if config is None:
            config = Config(FALLBACK_RULES_TEXT, None, None, DEFAULT_POLICY)
        return write_message(config.reminder_prompt)

    if args.mode == "block-message":
        if config is None:
            config = Config(FALLBACK_RULES_TEXT, None, None, DEFAULT_POLICY)
        return write_message(config.block_message)

    if config is None:
        output_format = getattr(args, "output_format", "plain")
        return emit_scan_result(True, output_format)

    if args.mode == "scan-text":
        return run_scan_text(args, config)
    if args.mode == "scan-file":
        return run_scan_file(args, config)
    if args.mode == "scan-bash":
        return run_scan_bash(args, config)

    parser.error(f"unknown command: {args.mode}")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
