"""Boundary tests run by the HushMic job in .github/workflows/freshener.yml."""

import base64
import copy
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import hushmic

OLD = "a" * 40
NEW = "b" * 40


def lock(revision):
    source = {
        "type": "github",
        "owner": "Fovty",
        "repo": "hushmic-nix",
        "rev": revision,
    }
    return {
        "version": 7,
        "root": "root",
        "nodes": {
            "root": {"inputs": {"hushmic": "hushmic", "nixpkgs": "nixpkgs"}},
            "hushmic": {
                "inputs": {"nixpkgs": "private"},
                "locked": source,
                "original": source,
            },
            "private": {"locked": {"rev": revision}},
            "nixpkgs": {"locked": {"rev": OLD}},
        },
    }


def package(version):
    source = (
        f'version = "{version}";\n'
        + """src = fetchFromGitHub {
  owner = "Fovty";
  repo = "hushmic";
  tag = "v${version}";
  hash = "sha256-AAAA=";
};
"""
    )
    return base64.b64encode(source.encode()).decode()


class FreshenerTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        previous = Path.cwd()
        os.chdir(self.directory.name)
        self.addCleanup(os.chdir, previous)
        Path("flake.nix").write_text(
            f'hushmic.url = "github:Fovty/hushmic-nix/{OLD}";\n'
        )
        Path("flake.lock").write_text(json.dumps(lock(OLD)))
        self.before = self.files()
        self.responses = [
            {"default_branch": "master"},
            {"sha": NEW},
            {"status": "ahead"},
            {"content": package("1.2.3")},
            {"content": package("1.2.2")},
            {"tag_name": "v1.2.3", "draft": False, "prerelease": False},
        ]

    def files(self):
        return [Path(name).read_bytes() for name in ("flake.nix", "flake.lock")]

    def test_update_is_scoped_and_outputs_packaging_revision(self):
        def command(arguments, **kwargs):
            self.assertEqual(
                arguments,
                [
                    "nix",
                    "shell",
                    "--inputs-from",
                    ".",
                    "--no-write-lock-file",
                    "nixpkgs#just",
                    "--command",
                    "just",
                    "update",
                    "hushmic",
                ],
            )
            self.assertTrue(kwargs["check"])
            Path("flake.lock").write_text(json.dumps(lock(NEW)))

        with (
            patch.object(hushmic, "api", side_effect=self.responses),
            patch.object(hushmic.subprocess, "run", side_effect=command),
        ):
            self.assertEqual(hushmic.update(), f"1.2.3-{NEW[:12]}")
        self.assertIn(NEW, Path("flake.nix").read_text())

    def test_dry_run_does_not_write_or_run_nix(self):
        with (
            patch.object(hushmic, "api", side_effect=self.responses),
            patch.object(hushmic.subprocess, "run") as command,
        ):
            hushmic.update(dry_run=True)
            command.assert_not_called()
        self.assertEqual(self.files(), self.before)

    def test_unchanged_pin_needs_no_update(self):
        with (
            patch.object(
                hushmic, "api", side_effect=[{"default_branch": "master"}, {"sha": OLD}]
            ),
            patch.object(hushmic.subprocess, "run") as command,
        ):
            self.assertIsNone(hushmic.update())
            command.assert_not_called()
        self.assertEqual(self.files(), self.before)

    def test_untrusted_metadata_fails_before_writes(self):
        for index, replacement in [
            (1, {"sha": "$(touch injected)"}),
            (2, {"status": "diverged"}),
            (3, {"content": package("1.2.3-rc.1")}),
            (3, {"content": package("1.2.1")}),
            (3, {"content": base64.b64encode(b'version = "1.2.3";').decode()}),
            (5, {"tag_name": "v1.2.3", "draft": False, "prerelease": True}),
            (5, {"tag_name": "v1.2.3", "draft": True, "prerelease": False}),
            (5, {"tag_name": "v9.9.9", "draft": False, "prerelease": False}),
        ]:
            with self.subTest(replacement=replacement):
                responses = copy.deepcopy(self.responses)
                responses[index] = replacement
                with (
                    patch.object(hushmic, "api", side_effect=responses),
                    patch.object(hushmic.subprocess, "run") as command,
                ):
                    with self.assertRaises(ValueError):
                        hushmic.update()
                    command.assert_not_called()
                self.assertEqual(self.files(), self.before)

    def test_unrelated_and_shared_lock_changes_fail(self):
        before = lock(OLD)
        after = lock(NEW)
        after["nodes"]["nixpkgs"]["locked"]["rev"] = NEW
        with self.assertRaises(ValueError):
            hushmic.validate_lock(before, after, NEW)
        before["nodes"]["root"]["inputs"]["other"] = "private"
        after = copy.deepcopy(before)
        after["nodes"]["private"]["locked"]["rev"] = NEW
        with self.assertRaises(ValueError):
            hushmic.validate_lock(before, after, NEW)

    def test_follows_dependencies_remain_protected(self):
        before = lock(OLD)
        before["nodes"]["root"]["inputs"]["other"] = ["hushmic", "nixpkgs"]
        after = copy.deepcopy(before)
        after["nodes"]["private"]["locked"]["rev"] = NEW
        with self.assertRaises(ValueError):
            hushmic.validate_lock(before, after, NEW)

    def test_workflow_output_protocol(self):
        for version in (None, f"1.2.3-{NEW[:12]}"):
            with (
                self.subTest(version=version),
                patch.object(hushmic, "update", return_value=version),
                patch.dict(os.environ, {"GITHUB_OUTPUT": "output"}),
                patch("sys.argv", ["hushmic.py"]),
            ):
                Path("output").write_text("")
                hushmic.main()
                lines = Path("output").read_text().splitlines()
                self.assertEqual(
                    lines,
                    ["updated=false"]
                    if version is None
                    else [
                        "updated=true",
                        f"version={version}",
                        "files=flake.nix flake.lock",
                    ],
                )

    def test_failed_update_restores_files(self):
        for failure in (True, False):
            with self.subTest(command_failure=failure):

                def command(*args, failure=failure, **kwargs):
                    changed = lock(NEW)
                    changed["nodes"]["nixpkgs"]["locked"]["rev"] = NEW
                    Path("flake.lock").write_text(json.dumps(changed))
                    if failure:
                        raise subprocess.CalledProcessError(1, "nix")

                with (
                    patch.object(hushmic, "api", side_effect=self.responses),
                    patch.object(hushmic.subprocess, "run", side_effect=command),
                    self.assertRaises((ValueError, subprocess.CalledProcessError)),
                ):
                    hushmic.update()
                self.assertEqual(self.files(), self.before)


if __name__ == "__main__":
    unittest.main()
