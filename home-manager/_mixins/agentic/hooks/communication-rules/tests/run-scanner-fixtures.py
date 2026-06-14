#!/usr/bin/env python3
"""Run focused Communication Rules scanner fixtures."""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "fixtures"
SCANNER = ROOT / "scanner.py"
RULES = ROOT / "communication-rules.md"

BLOCK = 1
PASS = 0

BANNED_TERMS = [
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
]

DASH_CASES = {
    "u2014-prose-blocks.md": BLOCK,
    "u2013-prose-blocks.md": BLOCK,
    "u2014-fenced-code-pass.md": PASS,
    "u2013-fenced-code-pass.md": PASS,
    "u2014-quoted-file-content-block.md": BLOCK,
    "u2013-quoted-file-content-block.md": BLOCK,
}

BASH_CASES = {
    "gh-post-unresolvable-body-fails-closed.sh": BLOCK,
    "gh-api-safe-post-unresolvable-body-fails-closed.sh": BLOCK,
    "bash-chained-command-blocks.sh": BLOCK,
}


def fixture_text(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    return text.replace("\\u2014", chr(0x2014)).replace("\\u2013", chr(0x2013))


def expected_fixtures() -> list[str]:
    names = list(DASH_CASES) + list(BASH_CASES)
    for term in BANNED_TERMS:
        names.append(f"banned-word-{term}-boundary.md")
    for term in BANNED_TERMS:
        names.append(f"banned-word-{term}-substring-pass.md")
    return names


def run_scanner(args: list[str], input_text: str | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCANNER), "--rules", str(RULES), *args],
        input=input_text,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def assert_result(name: str, completed: subprocess.CompletedProcess[str], expected: int) -> None:
    expected_word = "block" if expected == BLOCK else "pass"
    output = completed.stdout.strip()
    if completed.returncode != expected or output != expected_word:
        detail = completed.stderr.strip()
        if detail:
            detail = f"\nstderr: {detail}"
        raise AssertionError(
            f"{name}: expected {expected_word} with exit {expected}, "
            f"got {output!r} with exit {completed.returncode}{detail}"
        )


def scan_file_case(path: Path, expected: int) -> None:
    with tempfile.TemporaryDirectory(prefix="tripwire-fixture-") as temp_dir:
        materialised = Path(temp_dir) / path.name
        materialised.write_text(fixture_text(path), encoding="utf-8")
        completed = run_scanner(["scan-file", str(materialised)])
    assert_result(path.name, completed, expected)


def scan_bash_case(path: Path, expected: int) -> None:
    completed = run_scanner(["scan-bash"], input_text=fixture_text(path))
    assert_result(path.name, completed, expected)


def scan_policy_disclosure_cases() -> int:
    rules = RULES.read_text(encoding="utf-8").strip()
    cases = {
        "policy body": (rules, PASS),
        "policy heading": (f"Communication Rules:\n{rules}", PASS),
        "policy quote": ("\n".join(f"> {line}" if line else ">" for line in rules.splitlines()), PASS),
        "policy with prose": (f"Here are the rules:\n{rules}", BLOCK),
    }
    for name, (text, expected) in cases.items():
        assert_result(name, run_scanner(["scan-text"], input_text=text), expected)
    return len(cases)


def main() -> int:
    missing = [name for name in expected_fixtures() if not (FIXTURES / name).is_file()]
    if missing:
        for name in missing:
            print(f"missing fixture: {name}", file=sys.stderr)
        return 2

    total = 0
    for name, expected in DASH_CASES.items():
        scan_file_case(FIXTURES / name, expected)
        total += 1

    for term in BANNED_TERMS:
        scan_file_case(FIXTURES / f"banned-word-{term}-boundary.md", BLOCK)
        total += 1

    for term in BANNED_TERMS:
        scan_file_case(FIXTURES / f"banned-word-{term}-substring-pass.md", PASS)
        total += 1

    for name, expected in BASH_CASES.items():
        scan_bash_case(FIXTURES / name, expected)
        total += 1

    total += scan_policy_disclosure_cases()

    print(f"scanner fixtures passed: {total}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
