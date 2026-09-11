"""Check owned-file deployment in temporary homes, without reading real secrets."""

import importlib.util
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


HELPER = Path(__file__).with_name("deploy.py")


class DeploymentTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="owned-file-tests-")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.home = self.base / "home"
        self.home.mkdir()
        self.sources = self.base / "sources"
        self.sources.mkdir()
        self.state = self.home / ".local/state/agentic-owned-files"
        self.root = self.home / ".codex/skills"
        self.pi = self.home / ".pi/agent/agents"
        self.spec = {
            "version": 1,
            "stateDir": str(self.state),
            "roots": [str(self.root), str(self.pi)],
            "files": [],
            "retire": [],
        }

    def source(self, name, content):
        path = self.sources / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def entry(self, name, content="Generated content.\n", kind="file", **extra):
        source = self.source(name, content)
        return {
            "path": str(self.root / name),
            "source": str(source),
            "kind": kind,
            "mode": "0600",
            **extra,
        }

    def activate(self, success=True, dry_run=False):
        spec = self.base / "desired.json"
        spec.write_text(json.dumps(self.spec))
        command = [sys.executable, str(HELPER), str(spec)]
        if dry_run:
            command.append("--dry-run")
        result = subprocess.run(command, capture_output=True, text=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result

    def snapshot(self):
        result = {}
        for path in self.home.rglob("*"):
            info = path.lstat()
            name = str(path.relative_to(self.home))
            if stat.S_ISLNK(info.st_mode):
                result[name] = ("symlink", os.readlink(path))
            elif stat.S_ISREG(info.st_mode):
                result[name] = ("file", stat.S_IMODE(info.st_mode), path.read_bytes())
            else:
                result[name] = ("directory", stat.S_IMODE(info.st_mode))
        return result

    def test_rename_remove_and_disable_preserve_manual_siblings(self):
        self.spec["files"] = [self.entry("old/SKILL.md"), self.entry("old/references/guide.md")]
        self.activate()
        manual = self.root / "old/references/manual.md"
        manual.write_text("User content.\n")
        plugin = self.root / "plugin/SKILL.md"
        plugin.parent.mkdir()
        plugin.write_text("Plugin content.\n")
        self.spec["files"] = [self.entry("renamed/SKILL.md", "New content.\n")]
        self.activate()
        self.assertFalse((self.root / "old/SKILL.md").exists())
        self.assertFalse((self.root / "old/references/guide.md").exists())
        self.assertEqual(manual.read_text(), "User content.\n")
        self.assertEqual(plugin.read_text(), "Plugin content.\n")
        self.assertEqual((self.root / "renamed/SKILL.md").read_text(), "New content.\n")
        self.spec["files"] = []
        self.activate()
        self.assertFalse((self.root / "renamed").exists())
        self.assertTrue(manual.exists())
        self.assertTrue(plugin.exists())

    def test_repeated_activation_has_no_history_and_keeps_regular_skill_files(self):
        self.spec["files"] = [self.entry("fixture/SKILL.md"), self.entry("fixture/references/nested/SKILL.md")]
        self.activate()
        before = self.snapshot()
        for _ in range(3):
            self.activate()
            self.assertEqual(self.snapshot(), before)
        self.assertEqual({p.name for p in self.state.iterdir()}, {"manifest.json"})
        for entry in self.spec["files"]:
            path = Path(entry["path"])
            self.assertTrue(stat.S_ISREG(path.lstat().st_mode))
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.state.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE((self.state / "manifest.json").stat().st_mode), 0o600)

    def test_unknown_destination_conflict_leaves_everything_unchanged(self):
        self.spec["files"] = [self.entry("existing/SKILL.md")]
        self.activate()
        unknown = self.root / "unknown.md"
        unknown.write_text("Not owned.\n")
        self.spec["files"] = [self.entry("new.md"), self.entry("unknown.md")]
        before = self.snapshot()
        self.activate(success=False)
        self.assertEqual(self.snapshot(), before)

    def test_modified_desired_file_conflicts_but_modified_stale_file_survives(self):
        self.spec["files"] = [self.entry("fixture/SKILL.md")]
        self.activate()
        path = self.root / "fixture/SKILL.md"
        path.write_text("User modification.\n")
        before = self.snapshot()
        self.activate(success=False)
        self.assertEqual(self.snapshot(), before)
        self.spec["files"] = []
        self.activate()
        self.assertEqual(path.read_text(), "User modification.\n")
        manifest = json.loads((self.state / "manifest.json").read_text())
        self.assertNotIn(str(path), manifest["files"])

    def test_changed_owned_symlink_conflicts_without_touching_its_target(self):
        self.spec["files"] = [self.entry("guide.md", kind="symlink")]
        self.activate()
        path = self.root / "guide.md"
        outside = self.source("manual.md", "Do not touch.\n")
        path.unlink()
        path.symlink_to(outside)
        before = self.snapshot()
        self.activate(success=False)
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(outside.read_text(), "Do not touch.\n")

    def test_symlink_parent_cannot_escape_the_owned_root(self):
        self.root.mkdir(parents=True)
        outside = self.base / "outside"
        outside.mkdir()
        (self.root / "escape").symlink_to(outside, target_is_directory=True)
        self.spec["files"] = [self.entry("safe.md"), self.entry("escape/SKILL.md")]
        before = self.snapshot()
        self.activate(success=False)
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(list(outside.iterdir()), [])

    def test_missing_or_invalid_sources_prevent_all_mutations(self):
        self.spec["files"] = [self.entry("existing/SKILL.md")]
        self.activate()
        before = self.snapshot()
        for source in (self.sources / "missing", self.sources):
            with self.subTest(source=source):
                self.spec["files"] = [self.entry("new.md"), {
                    "path": str(self.root / "secret.md"), "source": str(source), "kind": "file",
                }]
                self.activate(success=False)
                self.assertEqual(self.snapshot(), before)

    @unittest.skipIf(os.geteuid() == 0, "Root bypasses source read permissions.")
    def test_unreadable_secret_leaves_files_and_manifest_unchanged(self):
        self.spec["files"] = [self.entry("existing/SKILL.md")]
        self.activate()
        before = self.snapshot()
        secret = self.entry("secret.md", "Fake secret.\n")
        source = Path(secret["source"])
        source.chmod(0)
        try:
            self.spec["files"] = [self.entry("new.md"), secret]
            self.activate(success=False)
            self.assertEqual(self.snapshot(), before)
        finally:
            source.chmod(0o600)

    def test_dry_run_leaves_the_home_and_manifest_unchanged(self):
        self.spec["files"] = [self.entry("existing/SKILL.md")]
        self.activate(dry_run=True)
        self.assertEqual(self.snapshot(), {})
        self.activate()
        before = self.snapshot()
        self.spec["files"] = [self.entry("new/SKILL.md")]
        self.activate(dry_run=True)
        self.assertEqual(self.snapshot(), before)

    def test_invalid_manifest_cannot_authorise_removal(self):
        self.spec["files"] = [self.entry("existing/SKILL.md")]
        self.activate()
        manifest = self.state / "manifest.json"
        manifest.write_text("{invalid json\n")
        self.spec["files"] = []
        before = self.snapshot()
        self.activate(success=False)
        self.assertEqual(self.snapshot(), before)

    def test_stale_symlink_changed_by_user_is_preserved(self):
        self.spec["files"] = [self.entry("guide.md", kind="symlink")]
        self.activate()
        path = self.root / "guide.md"
        target = self.source("user.md", "User content.\n")
        path.unlink()
        path.symlink_to(target)
        self.spec["files"] = []
        self.activate()
        self.assertEqual(os.readlink(path), str(target))
        self.assertEqual(target.read_text(), "User content.\n")

    def test_existing_symlink_to_legacy_name_is_not_retired(self):
        self.pi.mkdir(parents=True)
        target = self.source("user-agent.md", "User agent.\n")
        legacy = self.pi / "traya.md"
        legacy.symlink_to(target)
        self.spec["retire"] = [str(legacy)]
        self.activate()
        self.assertEqual(os.readlink(legacy), str(target))
        self.assertEqual(target.read_text(), "User agent.\n")

    def test_secret_prefix_is_combined_before_deployment(self):
        self.spec["files"] = [self.entry("secret/SKILL.md", "Fake secret body.\n", prefix="---\nname: secret\n---\n")]
        self.activate()
        self.assertEqual((self.root / "secret/SKILL.md").read_text(), "---\nname: secret\n---\nFake secret body.\n")

    def test_commit_failure_restores_files_manifest_and_directories(self):
        self.spec["files"] = [self.entry("old/SKILL.md"), self.entry("kept.md")]
        self.activate()
        empty = self.root / "old-empty"
        empty.mkdir(mode=0o755)
        captured = self.state / "bootstrap.json"
        captured.write_text(json.dumps({"version": 1, "files": {}, "directories": [str(empty)]}))
        captured.chmod(0o600)
        before = self.snapshot()
        self.spec["files"] = [self.entry("new/SKILL.md"), self.entry("kept.md", "Updated content.\n")]
        module_spec = importlib.util.spec_from_file_location("owned_deploy", HELPER)
        helper = importlib.util.module_from_spec(module_spec)
        module_spec.loader.exec_module(helper)
        real_replace = os.replace

        def fail_manifest(source, destination):
            if Path(destination) == self.state / "manifest.json":
                raise OSError("Injected manifest write failure.")
            return real_replace(source, destination)

        with mock.patch.object(helper.os, "replace", side_effect=fail_manifest):
            with self.assertRaises(OSError):
                helper.deploy(self.spec, bootstrap_manifest=str(captured))
        self.assertEqual(self.snapshot(), before)

    def test_bootstrap_requires_matching_old_source_content(self):
        self.root.mkdir(parents=True)
        old = self.source("old-generation.md", "Old generated content.\n")
        destination = self.root / "SKILL.md"
        destination.write_text(old.read_text())
        self.spec["files"] = [self.entry("SKILL.md", "New generated content.\n", bootstrapSources=[str(old)])]
        self.activate()
        self.assertEqual(destination.read_text(), "New generated content.\n")

    def test_bootstrap_owned_directories_are_pruned_but_manual_siblings_survive(self):
        obsolete = self.root / "obsolete"
        obsolete.mkdir(parents=True)
        former = obsolete / "SKILL.md"
        former.write_text("Old generated skill.\n")
        mixed = self.root / "mixed"
        mixed.mkdir()
        manual = mixed / "manual.md"
        manual.write_text("Manual content.\n")
        unknown = self.root / "unknown-empty"
        unknown.mkdir()
        self.state.mkdir(parents=True, mode=0o700)
        captured = self.state / "bootstrap.json"
        captured.write_text(json.dumps({
            "version": 1,
            "files": {str(former): {"kind": "file", "sha256": hashlib.sha256(former.read_bytes()).hexdigest()}},
            "directories": [str(obsolete), str(mixed)],
        }))
        captured.chmod(0o600)
        module_spec = importlib.util.spec_from_file_location("deploy_directories", HELPER)
        helper = importlib.util.module_from_spec(module_spec)
        module_spec.loader.exec_module(helper)
        helper.deploy(self.spec, bootstrap_manifest=str(captured))
        self.assertFalse(obsolete.exists())
        self.assertEqual(manual.read_text(), "Manual content.\n")
        self.assertTrue(unknown.is_dir())

    def test_bootstrap_does_not_adopt_a_filename_match_or_unverified_backup(self):
        self.root.mkdir(parents=True)
        old = self.source("old-generation.md", "Old generated content.\n")
        destination = self.root / "SKILL.md"
        destination.write_text("User content.\n")
        backup = self.root / "SKILL.md.backup-20260101"
        backup.write_text(old.read_text())
        self.spec["files"] = [self.entry("SKILL.md", bootstrapSources=[str(old)])]
        before = self.snapshot()
        self.activate(success=False)
        self.assertEqual(self.snapshot(), before)

    def test_legacy_retirement_is_exact_and_not_repeated(self):
        self.pi.mkdir(parents=True)
        legacy = self.pi / "traya.md"
        sibling = self.pi / "traya.md.backup"
        other = self.root / "traya.md"
        self.root.mkdir(parents=True)
        for path in (legacy, sibling, other):
            path.write_text("Legacy or user content.\n")
        self.spec["retire"] = [str(legacy)]
        self.activate()
        self.assertFalse(legacy.exists())
        self.assertTrue(sibling.exists())
        self.assertTrue(other.exists())
        legacy.write_text("Recreated by the user.\n")
        self.activate()
        self.assertEqual(legacy.read_text(), "Recreated by the user.\n")


if __name__ == "__main__":
    unittest.main()
