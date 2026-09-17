#!/usr/bin/env python3
"""Boundary and generated-output tests for export-agentic-dots."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import tomllib
import yaml

EXPORTER_PATH = Path(
    os.environ.get(
        "AGENTIC_DOTS_TEST_EXPORTER", Path(__file__).parents[1] / "exporter.py"
    )
)
SPEC = importlib.util.spec_from_file_location("agentic_dots_exporter", EXPORTER_PATH)
assert SPEC is not None and SPEC.loader is not None
exporter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(exporter)


def manifest_file(root: Path, files: dict[str, str]) -> Path:
    path = root / "manifest.json"
    path.write_text(
        json.dumps(
            {
                "schemaVersion": 1,
                "sourceRevision": "test",
                "policy": "explicit-public-allowlist",
                "files": [
                    {
                        "path": name,
                        "content": content,
                        "mode": "0644",
                        "dependencies": [],
                    }
                    for name, content in files.items()
                ],
            }
        ),
        encoding="utf-8",
    )
    return path


class ExporterBoundaryTests(unittest.TestCase):
    def test_rejects_path_escapes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for unsafe in ("../escape", "/escape", "dir\\escape"):
                with self.subTest(path=unsafe):
                    manifest = manifest_file(root, {unsafe: "bad"})
                    with self.assertRaises(exporter.ExportError):
                        exporter.export(manifest, root / "output")

    def test_rejects_unsafe_references_before_writing(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for unsafe in ("/nix/store/item", "/home/alice/item", "sops.placeholder"):
                with self.subTest(reference=unsafe):
                    destination = root / unsafe.rsplit("/", 1)[-1] / "output"
                    manifest = manifest_file(root, {"unsafe.txt": unsafe})
                    with self.assertRaises(exporter.ExportError):
                        exporter.export(manifest, destination)
                    self.assertFalse(destination.parent.exists())

    def test_allows_documented_placeholder_search_example(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            manifest = manifest_file(
                root,
                {
                    "claude/.claude/skills/gh/SKILL.md": (
                        'gh search code "sops.placeholder" --repo owner/repo --language nix'
                    )
                },
            )
            exporter.export(manifest, root / "output")

    def test_rejects_link_escape_before_creating_parent(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            external = root / "external"
            external.mkdir()
            (root / "link").symlink_to(external, target_is_directory=True)
            manifest = manifest_file(root, {"safe.txt": "safe"})

            with self.assertRaises(exporter.ExportError):
                exporter.export(manifest, root / "link" / "created" / "output")

            self.assertFalse((external / "created").exists())

    def test_rejects_link_inside_owned_destination(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            destination = root / "output"
            manifest = manifest_file(root, {"safe.txt": "safe"})
            exporter.export(manifest, destination)
            (destination / "link").symlink_to(root, target_is_directory=True)

            with self.assertRaises(exporter.ExportError):
                exporter.export(manifest, destination)

    def test_rejects_reserved_and_transaction_path_conflicts(self) -> None:
        cases = (
            {f"{exporter.OWNERSHIP_FILE}/child": "bad"},
            {f"{exporter.OWNERSHIP_TEMP_FILE}/child": "bad"},
            {"a.txt": "one", ".a.txt.agentic-dots-new": "two"},
            {"parent": "one", "parent/child": "two"},
        )
        for files in cases:
            with (
                self.subTest(paths=sorted(files)),
                tempfile.TemporaryDirectory() as temporary,
            ):
                root = Path(temporary)
                destination = root / "output"
                manifest = manifest_file(root, files)

                with self.assertRaises(exporter.ExportError):
                    exporter.export(manifest, destination)

                self.assertFalse(destination.exists())

    def test_preflights_all_temporary_outputs_before_updates(self) -> None:
        for conflict_name in (
            ".b.txt.agentic-dots-new",
            exporter.OWNERSHIP_TEMP_FILE,
        ):
            with (
                self.subTest(conflict=conflict_name),
                tempfile.TemporaryDirectory() as temporary,
            ):
                root = Path(temporary)
                destination = root / "output"
                first = manifest_file(root, {"a.txt": "old-a", "b.txt": "old-b"})
                exporter.export(first, destination)
                ownership_path = destination / exporter.OWNERSHIP_FILE
                old_ownership = ownership_path.read_bytes()
                conflict = destination / conflict_name
                conflict.write_text("pre-existing", encoding="utf-8")
                changed = manifest_file(root, {"a.txt": "new-a", "b.txt": "new-b"})

                with self.assertRaises(exporter.ExportError):
                    exporter.export(changed, destination)

                self.assertEqual((destination / "a.txt").read_text(), "old-a")
                self.assertEqual((destination / "b.txt").read_text(), "old-b")
                self.assertEqual(ownership_path.read_bytes(), old_ownership)
                self.assertEqual(conflict.read_text(), "pre-existing")

                conflict.unlink()
                exporter.export(changed, destination)
                self.assertEqual((destination / "a.txt").read_text(), "new-a")
                self.assertEqual((destination / "b.txt").read_text(), "new-b")

    def test_apply_failure_rolls_back_outputs_and_keeps_ownership(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            destination = root / "output"
            first = manifest_file(root, {"a.txt": "old-a", "b.txt": "old-b"})
            exporter.export(first, destination)
            ownership_path = destination / exporter.OWNERSHIP_FILE
            old_ownership = ownership_path.read_bytes()
            changed = manifest_file(root, {"a.txt": "new-a", "b.txt": "new-b"})
            real_replace = exporter.os.replace

            def fail_second_output(
                source: str | os.PathLike[str], target: str | os.PathLike[str]
            ) -> None:
                source_path = Path(source)
                target_path = Path(target)
                if (
                    source_path.name == ".b.txt.agentic-dots-new"
                    and target_path.name == "b.txt"
                ):
                    raise OSError("injected apply failure")
                real_replace(source, target)

            with (
                mock.patch.object(
                    exporter.os, "replace", side_effect=fail_second_output
                ),
                self.assertRaises(exporter.ExportError),
            ):
                exporter.export(changed, destination)

            self.assertEqual((destination / "a.txt").read_text(), "old-a")
            self.assertEqual((destination / "b.txt").read_text(), "old-b")
            self.assertEqual(ownership_path.read_bytes(), old_ownership)
            self.assertFalse((destination / ".a.txt.agentic-dots-new").exists())
            self.assertFalse((destination / ".b.txt.agentic-dots-new").exists())

            exporter.export(changed, destination)
            self.assertEqual((destination / "a.txt").read_text(), "new-a")
            self.assertEqual((destination / "b.txt").read_text(), "new-b")

    def test_repeat_export_keeps_ownership_hashes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            destination = root / "output"
            manifest = manifest_file(root, {"a.txt": "alpha", "b.txt": "beta"})

            self.assertEqual(exporter.export(manifest, destination), [])
            self.assertEqual(exporter.export(manifest, destination), [])

            ownership = json.loads(
                (destination / exporter.OWNERSHIP_FILE).read_text(encoding="utf-8")
            )
            hashes = {entry["path"]: entry["sha256"] for entry in ownership["files"]}
            self.assertEqual(
                hashes,
                {
                    "a.txt": hashlib.sha256(b"alpha").hexdigest(),
                    "b.txt": hashlib.sha256(b"beta").hexdigest(),
                },
            )

    def test_changed_owned_file_blocks_export_and_preserves_content(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            destination = root / "output"
            first = manifest_file(root, {"owned.txt": "generated"})
            exporter.export(first, destination)
            target = destination / "owned.txt"
            target.write_text("local edit", encoding="utf-8")
            changed = manifest_file(root, {"owned.txt": "replacement"})

            with self.assertRaises(exporter.ExportError):
                exporter.export(changed, destination)

            self.assertEqual(target.read_text(encoding="utf-8"), "local edit")

    def test_unknown_destination_file_blocks_export_and_preserves_content(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            destination = root / "output"
            first = manifest_file(root, {"owned.txt": "generated"})
            exporter.export(first, destination)
            unknown = destination / "new.txt"
            unknown.write_text("user content", encoding="utf-8")
            changed = manifest_file(
                root, {"owned.txt": "generated", "new.txt": "replacement"}
            )

            with self.assertRaises(exporter.ExportError):
                exporter.export(changed, destination)

            self.assertEqual(unknown.read_text(encoding="utf-8"), "user content")

    def test_stale_owned_file_is_reported_and_preserved(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            destination = root / "output"
            first = manifest_file(root, {"current.txt": "one", "stale.txt": "keep"})
            exporter.export(first, destination)
            second = manifest_file(root, {"current.txt": "two"})

            self.assertEqual(exporter.export(second, destination), ["stale.txt"])
            self.assertEqual(
                (destination / "stale.txt").read_text(encoding="utf-8"), "keep"
            )
            ownership = json.loads(
                (destination / exporter.OWNERSHIP_FILE).read_text(encoding="utf-8")
            )
            self.assertEqual(
                [entry["path"] for entry in ownership["files"]], ["current.txt"]
            )


class GeneratedExportTests(unittest.TestCase):
    def test_packaged_export_is_portable_and_parseable(self) -> None:
        command = os.environ.get("AGENTIC_DOTS_TEST_COMMAND")
        manifest_path = os.environ.get("AGENTIC_DOTS_TEST_MANIFEST")
        if not command or not manifest_path:
            self.skipTest("packaged exporter inputs are not set")

        manifest = json.loads(Path(manifest_path).read_text(encoding="utf-8"))
        paths = {entry["path"] for entry in manifest["files"]}
        contents = "\n".join(entry["content"] for entry in manifest["files"])

        for root in ("claude/", "codex/", "opencode/", "pi/"):
            self.assertTrue(any(path.startswith(root) for path in paths), root)
        for expected in (
            "claude/.mcp.json",
            "codex/.codex/config.toml",
            "opencode/.config/opencode/opencode.json",
            "pi/.pi/agent/settings.json",
            "pi/.pi/agent/subagents.json",
            "integrations/communication-rules/scanner.py",
        ):
            self.assertIn(expected, paths)

        self.assertFalse(any(path.startswith("codex/.config/codex/") for path in paths))
        self.assertFalse(any(path.endswith(".sops") for path in paths))
        self.assertNotIn("/nix/store/", contents)
        self.assertNotRegex(contents, r"/home/[^/\s]+/")
        placeholder_entries = [
            entry
            for entry in manifest["files"]
            if "sops.placeholder" in entry["content"]
        ]
        self.assertTrue(placeholder_entries)
        for entry in placeholder_entries:
            self.assertTrue(entry["path"].endswith("/skills/gh/SKILL.md"))
            self.assertIn(
                'gh search code "sops.placeholder" --repo owner/repo --language nix',
                entry["content"].splitlines(),
            )
        for excluded in (
            "draft-self-review",
            "gather-review-data",
            "make-pr",
            "post-comment",
            "review-open-source-attestation",
            "self-review",
            "slack",
            "wtb",
            "zk",
            "herdr",
        ):
            self.assertFalse(any(f"/{excluded}/" in f"/{path}/" for path in paths))

        entries = {entry["path"]: entry for entry in manifest["files"]}
        pi_settings = json.loads(entries["pi/.pi/agent/settings.json"]["content"])
        expected_packages = {
            "npm:pi-mcp-adapter@2.32.1",
            "npm:@tintinweb/pi-subagents@0.19.0",
        }
        self.assertEqual(set(pi_settings["packages"]), expected_packages)

        canonical_pi_path = os.environ.get("AGENTIC_DOTS_TEST_CANONICAL_PI")
        assert canonical_pi_path is not None
        canonical_pi = Path(canonical_pi_path).read_text(encoding="utf-8")
        canonical_versions = {
            match.group(1): match.group(2)
            for match in re.finditer(
                r'(piMcpAdapterVersion|piSubagentsVersion) = "([^"]+)";',
                canonical_pi,
            )
        }
        self.assertEqual(
            expected_packages,
            {
                f"npm:pi-mcp-adapter@{canonical_versions['piMcpAdapterVersion']}",
                "npm:@tintinweb/pi-subagents@"
                f"{canonical_versions['piSubagentsVersion']}",
            },
        )

        subagents = json.loads(entries["pi/.pi/agent/subagents.json"]["content"])
        self.assertEqual(subagents["maxConcurrent"], 12)
        self.assertEqual(subagents["maxConcurrentForeground"], 12)
        self.assertEqual(subagents["maxSubagentDepth"], 1)
        self.assertFalse(subagents["worktreeIsolation"])

        for path in (
            "claude/.claude/rules/instructions.md",
            "codex/.codex/AGENTS.md",
            "opencode/.config/opencode/AGENTS.md",
            "pi/.pi/agent/AGENTS.md",
        ):
            instructions = entries[path]["content"]
            for unavailable in (
                "Fence",
                "babysit-pr",
                "gh-api-safe",
                "gh-review-reply",
                "gh-review-resolve",
                "slack-post",
            ):
                self.assertNotIn(unavailable, instructions, path)

        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "agentic-dots"
            export_command = [
                command,
                str(destination),
                "--source-revision",
                "0123456789abcdef-dirty",
            ]
            subprocess.run(export_command, check=True)
            subprocess.run(export_command, check=True)

            ownership = json.loads(
                (destination / exporter.OWNERSHIP_FILE).read_text(encoding="utf-8")
            )
            self.assertEqual(ownership["sourceRevision"], "0123456789abcdef-dirty")

            for path in sorted(destination.rglob("*.json")):
                json.loads(path.read_text(encoding="utf-8"))
            for path in sorted(destination.rglob("*.toml")):
                tomllib.loads(path.read_text(encoding="utf-8"))
            for path in sorted(destination.rglob("*.yaml")):
                yaml.safe_load(path.read_text(encoding="utf-8"))

            documentation = [
                destination / "README.md",
                *sorted((destination / "docs").glob("*.md")),
            ]
            link_pattern = re.compile(r"\[[^]]+\]\(([^)]+)\)")
            for document in documentation:
                for target in link_pattern.findall(
                    document.read_text(encoding="utf-8")
                ):
                    target = target.split("#", 1)[0]
                    if (
                        not target
                        or "://" in target
                        or target.startswith(("#", "/", "~"))
                    ):
                        continue
                    self.assertTrue(
                        (document.parent / target)
                        .resolve()
                        .is_relative_to(destination.resolve())
                        and (document.parent / target).exists(),
                        f"broken portable link in {document}: {target}",
                    )


if __name__ == "__main__":
    unittest.main()
