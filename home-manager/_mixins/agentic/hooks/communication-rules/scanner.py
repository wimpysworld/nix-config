#!/usr/bin/env python3
"""Advisory Communication Rules scanner."""

from __future__ import annotations

import argparse
import json
import signal
import sys

from core.config import load_config
from core.detection import command_text_from_args, read_text_file, scan_bash, scan_prose
from core.dispatch import AGENTS, decision_to_json, dispatch, shape_response
from core.types import Decision

COMMAND_HOOK_AGENTS = ("claude-code", "codex")
GUIDANCE = "Use plain British English for new prose. Preserve exact source text. Style advice never changes permissions."


def emit_scan_result(finding: bool, output_format: str) -> int:
    result = "advisory" if finding else "pass"
    print(json.dumps({"result": result}) if output_format == "json" else result)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Offer bounded advice on authored prose."
    )
    parser.add_argument("--policy-json", "--policy", dest="policy_json")
    parser.add_argument("--rules")
    modes = parser.add_subparsers(dest="mode", required=True)
    modes.add_parser("remind")
    brief = modes.add_parser("remind-brief")
    brief.add_argument("agent", nargs="?", default="")
    modes.add_parser("block-message", help=argparse.SUPPRESS)
    for name in ("scan-text", "scan-file", "scan-bash"):
        mode = modes.add_parser(name)
        mode.add_argument(
            "--format", dest="output_format", choices=("plain", "json"), default="plain"
        )
        if name != "scan-bash":
            mode.add_argument(
                "--no-strip-fences", action="store_true", help=argparse.SUPPRESS
            )
        if name == "scan-file":
            mode.add_argument("path")
        elif name == "scan-text":
            mode.add_argument("text", nargs=argparse.REMAINDER)
        else:
            mode.add_argument("bash_command", nargs=argparse.REMAINDER)
    for agent in AGENTS:
        mode = modes.add_parser(agent)
        mode.add_argument("event")
        mode.add_argument(
            "--policy-json", "--policy", dest="policy_json", default=argparse.SUPPRESS
        )
        mode.add_argument("--rules", default=argparse.SUPPRESS)
    return parser


def _timeout(signum, frame):
    raise TimeoutError("style check timeout")


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.mode in {"remind", "remind-brief", "block-message"}:
        print(GUIDANCE)
        return 0
    previous = signal.signal(signal.SIGALRM, _timeout)
    signal.alarm(3)
    try:
        try:
            config = load_config(args)
        except Exception:
            config = None
        if args.mode in AGENTS:
            try:
                decision = dispatch(args.mode, args.event, config)
            except Exception:
                decision = Decision()
            if args.mode in COMMAND_HOOK_AGENTS:
                shaped = shape_response(args.mode, args.event, decision, config)
                if shaped is not None:
                    print(json.dumps(shaped))
            else:
                print(decision_to_json(decision))
            return 0
        finding = False
        if config is not None:
            if args.mode == "scan-text":
                text = " ".join(args.text) if args.text else sys.stdin.read(100_001)
                finding = scan_prose(text, config)
            elif args.mode == "scan-file":
                text = read_text_file(args.path)
                finding = text is not None and scan_prose(text, config)
            elif args.mode == "scan-bash":
                finding = scan_bash(command_text_from_args(args.bash_command), config)
        return emit_scan_result(finding, args.output_format)
    except Exception:
        if args.mode in AGENTS:
            if args.mode not in COMMAND_HOOK_AGENTS:
                print(decision_to_json(Decision()))
            return 0
        return emit_scan_result(False, args.output_format)
    finally:
        signal.alarm(0)
        signal.signal(signal.SIGALRM, previous)


if __name__ == "__main__":
    raise SystemExit(main())
