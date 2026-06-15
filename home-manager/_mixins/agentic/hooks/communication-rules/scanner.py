#!/usr/bin/env python3
"""Deterministic Communication Rules scanner."""

from __future__ import annotations

import argparse
import json
import sys

from core.config import (
    DEFAULT_POLICY,
    FALLBACK_RULES_TEXT,
    Config,
    load_config,
)
from core.detection import (
    command_text_from_args,
    read_text_file,
    scan_bash,
    scan_prose,
)
from core.dispatch import AGENTS, decision_to_json, dispatch, shape_response

# Command-hook agents whose runtime consumes the agent's NATIVE wire JSON on
# stdout, not the raw core Decision. For these the scanner shapes the decision
# through core.responses and emits the wire dict (or nothing). Pi and OpenCode
# load an in-process shim that reads the raw Decision and translates it, so they
# keep the decision_to_json output unchanged.
COMMAND_HOOK_AGENTS = ("claude-code", "codex")


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

    # Dispatch form: each agent name is a subcommand that takes an event
    # string. The agent set is disjoint from the five subcommands above, so
    # the names never collide. The global --policy-json and --rules options
    # apply to this form too.
    for agent in AGENTS:
        agent_parser = subparsers.add_parser(agent, help=f"Dispatch a {agent} event through the core.")
        agent_parser.add_argument("event", help="The agent event name to dispatch.")
        # Accept --policy-json and --rules after the event too, so the
        # dispatch form takes them on either side of the subcommand. The
        # SUPPRESS default leaves the global value untouched when the flag is
        # absent on the subcommand.
        agent_parser.add_argument(
            "--policy-json", "--policy", dest="policy_json", default=argparse.SUPPRESS, help=argparse.SUPPRESS
        )
        agent_parser.add_argument("--rules", dest="rules", default=argparse.SUPPRESS, help=argparse.SUPPRESS)

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

    if args.mode in AGENTS:
        decision = dispatch(args.mode, args.event, config)
        if args.mode in COMMAND_HOOK_AGENTS:
            # The command hook pipes stdout straight into the agent, which
            # validates the agent's native wire JSON. Shape the decision and
            # emit the wire dict; a pass / no-action shapes to None and emits
            # nothing (empty stdout, exit 0), never the raw Decision.
            shaped = shape_response(args.mode, args.event, decision, config)
            if shaped is not None:
                sys.stdout.write(json.dumps(shaped))
                sys.stdout.write("\n")
            return 0
        # Pi and OpenCode load an in-process shim that reads the raw Decision.
        sys.stdout.write(decision_to_json(decision))
        sys.stdout.write("\n")
        return 0

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
