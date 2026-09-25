#!/usr/bin/env python3
"""Offline launcher contracts. Gate: just test-codex-launchers."""

import json
import os
import shlex
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

MODULE = Path(__file__).with_name("default.nix")
DEFAULT_ARGS = ["-c", 'service_tier="default"']


def launcher_shell(home):
    """Extract the real shell body and replace only its Nix path interpolations."""
    source = MODULE.read_text()
    package = source.split("  codexLauncherPackage = pkgs.writeShellApplication {", 1)[
        1
    ]
    shell = package.split("    text = ''\n", 1)[1].split("\n    '';", 1)[0]
    paths = {
        "lib.escapeShellArg codexDir": shlex.quote(str(home / ".codex")),
        "codexStableBin": str(home / ".local/share/codex/bin/codex"),
        "codexLegacyStableBin": str(home / ".codex/bin/codex"),
        "codexXdgStableBin": str(home / ".config/codex/bin/codex"),
    }
    for name, value in paths.items():
        shell = shell.replace("${" + name + "}", value)
    if "${" in shell.replace("''${", ""):
        raise AssertionError("Unresolved Nix interpolation in launcher fixture")
    return "set -euo pipefail\n" + textwrap.dedent(shell.replace("''${", "${"))


class ServiceTierTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="codex-tier-")
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name) / "home with spaces"
        self.config = self.home / ".codex/config.toml"
        self.config.parent.mkdir(parents=True)
        self.config.write_text('service_tier = "fast"\n')
        self.binary = self.home / ".local/share/codex/bin/codex"
        self.binary.parent.mkdir(parents=True)
        self.binary.write_text(
            f"#!{sys.executable}\n"
            "import json, os, pathlib, sys\n"
            "config = pathlib.Path(os.environ['CODEX_HOME']) / 'config.toml'\n"
            "print(json.dumps({'args': sys.argv[1:], 'config': config.read_text()}))\n"
        )
        self.binary.chmod(0o755)
        self.launcher = self.home / "launcher.sh"
        self.launcher.write_text(launcher_shell(self.home))

    def launch(self, args, bypass=False):
        result = subprocess.run(
            ["bash", str(self.launcher), *args],
            env={
                "PATH": os.defpath,
                "HOME": str(self.home),
                "CODEX_HOME": str(self.home / "unused"),
                "NOUGHTY_CODEX_BYPASS": "1" if bypass else "0",
            },
            cwd=self.home,
            capture_output=True,
            text=True,
            check=True,
            timeout=5,
        )
        captured = json.loads(result.stdout)
        self.assertEqual(captured["config"], 'service_tier = "fast"\n')
        self.assertEqual(self.config.read_text(), captured["config"])
        return captured["args"]

    def test_declarative_default(self):
        settings = MODULE.read_text().split("  codexSettings = {", 1)[1]
        self.assertIn('    service_tier = "default";', settings)

    def test_automatic_resume_for_bare_prompt_and_flags(self):
        for args in ([], [""], ["a prompt with spaces"], ["--model", "example"]):
            with self.subTest(args=args):
                self.assertEqual(
                    self.launch(args), DEFAULT_ARGS + ["resume", "--last"] + args
                )

    def test_fresh_prefix_preserves_arguments_and_fence_bypass(self):
        for args in (
            [],
            [""],
            ["a prompt with spaces"],
            ["--model", "example", ""],
            ["--", "--noughty-fresh"],
            ["resume", "session-id", "a prompt"],
            ["resume", "--last"],
            ["fork", "session-id"],
            ["fork", "--last"],
            ["exec", "a request"],
            ["--help"],
            ["--version"],
        ):
            for bypass in (False, True):
                with self.subTest(args=args, bypass=bypass):
                    expected = (
                        DEFAULT_ARGS
                        + (["--dangerously-bypass-approvals-and-sandbox"] if bypass else [])
                        + args
                    )
                    self.assertEqual(
                        self.launch(["--noughty-fresh", *args], bypass=bypass), expected
                    )

    def test_fenced_entry_forwards_fresh_mode_through_both_paths(self):
        package = MODULE.read_text().split(
            "  codexFencedPackage = pkgs.writeShellApplication {", 1
        )[1]
        shell = package.split("    text = ''\n", 1)[1].split("\n    '';", 1)[0]
        for helper in (
            "fenceAgentShare.captureShell",
            "fenceWaylandBridge.setupShell",
            "fenceAgentShare.setupShell",
            "fenceGit.setupShell",
            "fenceChromium.setupShell",
            "fenceLogging.setupShell",
        ):
            shell = shell.replace("${" + helper + "}", ":")
        shell = shell.replace(
            '${lib.getExe\' codexLauncherPackage "codex"}',
            "bash " + shlex.quote(str(self.launcher)),
        )
        if "${" in shell.replace("''${", ""):
            self.fail("Unresolved Nix interpolation in fenced fixture")
        fixture = self.home / "fenced.sh"
        fixture.write_text(
            "set -euo pipefail\n"
            "fence_args=(--fixture)\n"
            "fence_env=(FENCE_SANDBOX=1)\n"
            "fence_direnv=(env)\n"
            "fence() {\n"
            "  [[ ${NOUGHTY_CODEX_BYPASS:-0} == 0 && $HERDR_AGENT == codex ]]\n"
            "  [[ $1 == --fixture && $2 == -- ]]\n"
            "  printf 'fence\\n' >&2\n"
            "  shift 2\n"
            '  env "$@"\n'
            "}\n"
            + textwrap.dedent(shell.replace("''${", "${"))
        )
        for sandbox in ("0", "1"):
            for args in (
                [], [""], ["--model", "example"], ["resume", "id"], ["fork", "id"]
            ):
                with self.subTest(sandbox=sandbox, args=args):
                    result = subprocess.run(
                        ["bash", str(fixture), "--noughty-fresh", *args],
                        env={"PATH": os.defpath, "FENCE_SANDBOX": sandbox},
                        capture_output=True,
                        text=True,
                        check=True,
                        timeout=5,
                    )
                    self.assertEqual(result.stderr, "fence\n" if sandbox == "0" else "")
                    self.assertEqual(
                        json.loads(result.stdout)["args"],
                        DEFAULT_ARGS
                        + ["--dangerously-bypass-approvals-and-sandbox"]
                        + args,
                    )

    def test_fresh_mode_does_not_affect_the_next_launch(self):
        self.launch(["--noughty-fresh"])
        self.assertEqual(self.launch([]), DEFAULT_ARGS + ["resume", "--last"])

    def test_fresh_prefix_is_not_consumed_from_prompt_arguments(self):
        for args in (["--", "--noughty-fresh"], ["", "--noughty-fresh"]):
            with self.subTest(args=args):
                self.assertEqual(
                    self.launch(args), DEFAULT_ARGS + ["resume", "--last"] + args
                )

    def test_explicit_subcommands_and_help(self):
        for args in (
            ["resume", "--last"],
            ["resume", "session-id"],
            ["exec", "a fresh request"],
            ["fork", "--last"],
            ["--help"],
            ["--version"],
        ):
            with self.subTest(args=args):
                self.assertEqual(self.launch(args), DEFAULT_ARGS + args)

    def test_later_fast_override_stays_after_default(self):
        for flag in ("-c", "--config"):
            for prefix in ([], ["resume", "--last"], ["exec"]):
                args = prefix + [flag, 'service_tier="fast"', "a prompt with spaces"]
                expected = (
                    DEFAULT_ARGS + ([] if prefix else ["resume", "--last"]) + args
                )
                with self.subTest(flag=flag, prefix=prefix):
                    self.assertEqual(self.launch(args), expected)

    def test_fence_bypass_stays_before_resume(self):
        self.assertEqual(
            self.launch(["hello"], bypass=True),
            DEFAULT_ARGS
            + [
                "--dangerously-bypass-approvals-and-sandbox",
                "resume",
                "--last",
                "hello",
            ],
        )

    def test_new_process_after_fast_starts_with_default(self):
        self.launch(["-c", 'service_tier="fast"'])
        self.assertEqual(self.launch([]), DEFAULT_ARGS + ["resume", "--last"])
        self.assertEqual(
            self.launch(["resume", "--last"]), DEFAULT_ARGS + ["resume", "--last"]
        )

    def test_stable_binary_fallbacks(self):
        for relative in (".codex/bin/codex", ".config/codex/bin/codex"):
            target = self.home / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            self.binary.rename(target)
            self.binary = target
            with self.subTest(relative=relative):
                self.assertEqual(self.launch([]), DEFAULT_ARGS + ["resume", "--last"])


if __name__ == "__main__":
    unittest.main()
