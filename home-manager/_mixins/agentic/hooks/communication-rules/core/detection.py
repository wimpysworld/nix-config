"""Conservative prose lint, with no rewriting or permission policy."""

from __future__ import annotations

import re
import shlex
import sys
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from core.config import Config

MAX_TEXT = 100_000
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


def read_text_file(path: str) -> str | None:
    try:
        with Path(path).open(encoding="utf-8") as stream:
            text = stream.read(MAX_TEXT + 1)
        return text if len(text) <= MAX_TEXT else None
    except (OSError, UnicodeError, ValueError):
        return None


def strip_fenced_code_blocks(text: str) -> str:
    output = []
    fence = ""
    for line in text.splitlines(keepends=True):
        match = re.match(r"^[ \t]{0,3}(\x60{3,}|~{3,})", line)
        if not fence and match:
            fence = match[1]
            output.append("\n")
        elif fence:
            if re.match(
                r"^[ \t]{0,3}"
                + re.escape(fence[0])
                + "{"
                + str(len(fence))
                + r",}\s*$",
                line,
            ):
                fence = ""
            output.append("\n")
        else:
            output.append(line)
    return "".join(output)


def prose_lines(text: str):
    if len(text) > MAX_TEXT:
        return
    if re.search(
        r"(?im)^\s*(?:copyright\b|SPDX-License-Identifier:|"
        r"permission is hereby granted\b|licensed under\b|"
        r"GNU (?:general|lesser|affero)|apache license\b|MIT license\b)",
        text,
    ):
        return
    text = strip_fenced_code_blocks(text)
    # Multiline quoted evidence keeps its line positions.
    text = re.sub(
        r'(?s)"[^"]*"|“[^”]*”|‘[^’]*’', lambda match: "\n" * match[0].count("\n"), text
    )
    for number, line in enumerate(text.splitlines(), 1):
        if re.match(r"^\s*(?:>|<!--|<[/!]?\w|[$#]\s|//|/\*|\*)", line):
            continue
        if line.startswith(("    ", "\t")):
            continue
        if re.match(
            r"^\s*(?:import|from|const|let|var|def|class|function|"
            r"return|export|package|using|SELECT|INSERT|UPDATE)\b",
            line,
        ):
            continue
        if re.match(
            r"^\s*(?:git|gh|nix|just|rg|python\d*|node|curl|"
            r"printf|echo|cat|sed|awk|npm|pnpm|sudo|bash|sh)\b",
            line,
        ):
            continue
        if re.search(r"(?:=>|:=|\$\(|\$\{|&&|\|\||[{};]|^\s*\w+\s*=)", line):
            continue
        line = re.sub(r"\x60+[^\x60]*\x60+", "", line)
        line = re.sub(r"(?<!\w)'[^'\n]+'(?!\w)", "", line)
        line = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", line)
        line = re.sub(r"(?:https?://|www\.)\S+|<?[\w.+-]+@[\w.-]+>?", "", line)
        line = re.sub(
            r"\S*[/\\_]\S*|\b\w+(?:[.-]\w+)+\b|\b\w*[a-z][A-Z]\w*\b", "", line
        )
        if re.search(r"[A-Za-z]", line):
            yield number, line


def prose_findings(text: str, config: Config) -> list[tuple[str, int]]:
    if text.strip() == config.rules_text.strip():
        return []
    terms = config.policy.get(
        "advisoryTerms", config.policy.get("hardGateBannedTerms", [])
    )
    for number, line in prose_lines(text):
        for item in config.policy.get("blockedCodepoints", []):
            if not isinstance(item, dict):
                continue
            try:
                char = chr(int(item.get("codepoint", "")[2:], 16))
            except (ValueError, TypeError, OverflowError):
                continue
            if char in line:
                return [("check sentence punctuation", number)]
        for term in terms:
            if not isinstance(term, str) or not term:
                continue
            if re.search(r"(?<![\w-])" + re.escape(term) + r"(?![\w-])", line, re.I):
                return [("check whether this wording needs a simpler term", number)]
    return []


def scan_prose(text: str, config: Config, strip_fences: bool = True) -> bool:
    return bool(prose_findings(text, config))


def publication_command_texts(command: str) -> list[str]:
    """Accept literal prose fields of one known publication command only."""
    if len(command) > MAX_TEXT or any(
        marker in command
        for marker in ("\n", "\r", "$", "\x60", ";", "&&", "||", "|", "<", ">")
    ):
        return []
    try:
        argv = shlex.split(command)
    except ValueError:
        return []
    if len(argv) < 3 or argv[0] != "gh" or tuple(argv[1:3]) not in POST_COMMANDS:
        return []
    result = []
    i = 3
    while i < len(argv):
        token = argv[i]
        if token in {"--body", "-b", "--title", "-t", "--notes", "-n"}:
            if i + 1 >= len(argv):
                return []
            result.append(argv[i + 1])
            i += 2
            continue
        if token.startswith(("--body=", "--title=", "--notes=")):
            result.append(token.split("=", 1)[1])
        i += 1
    return result


def scan_bash(command: str, config: Config) -> bool:
    return any(scan_prose(text, config) for text in publication_command_texts(command))


def command_text_from_args(parts: list[str]) -> str:
    return " ".join(parts) if parts else sys.stdin.read(MAX_TEXT + 1)
