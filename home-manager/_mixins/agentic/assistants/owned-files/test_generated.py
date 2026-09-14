"""Check generated and synthetic specifications in temporary homes."""

import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


class GeneratedDeploymentTests(unittest.TestCase):
    def check_specification(self, spec):
        with tempfile.TemporaryDirectory(prefix="generated-owned-files-") as directory:
            base = Path(directory)
            home = base / "home"
            home.mkdir()
            old_home = Path(spec["home"])

            def relocate(path):
                return str(home / Path(path).relative_to(old_home))

            spec["home"] = str(home)
            spec["stateDir"] = relocate(spec["stateDir"])
            spec["roots"] = [relocate(path) for path in spec["roots"]]
            spec["retire"] = [relocate(path) for path in spec.get("retire", [])]
            for number, entry in enumerate(spec["files"]):
                entry["path"] = relocate(entry["path"])
                source = Path(entry["source"])
                if not source.is_relative_to("/nix/store"):
                    fake = base / "fake-secrets" / str(number)
                    fake.parent.mkdir(exist_ok=True)
                    fake.write_text("Fake secret for activation tests.\n")
                    entry["source"] = str(fake)
                self.assertNotIn("bootstrapSources", entry)

            fixture_root = home / ".codex/skills/catalogue-test-fixture"
            spec["roots"].append(str(fixture_root))
            for number, name in enumerate(("SKILL.md", "references/nested/SKILL.md")):
                source = base / f"fixture-{number}.md"
                source.write_text("Synthetic skill resource.\n")
                spec["files"].append({
                    "path": str(fixture_root / name),
                    "source": str(source),
                    "kind": "file",
                    "mode": "0600",
                })

            desired = base / "desired.json"
            helper = Path(__file__).with_name("deploy.py")

            def activate():
                desired.write_text(json.dumps(spec))
                result = subprocess.run([sys.executable, str(helper), str(desired)], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)

            activate()
            for entry in spec["files"]:
                path = Path(entry["path"])
                with self.subTest(path=path):
                    if entry["kind"] == "file":
                        self.assertTrue(stat.S_ISREG(path.lstat().st_mode))
                        self.assertEqual(path.read_bytes(), entry.get("prefix", "").encode() + Path(entry["source"]).read_bytes())
                    else:
                        self.assertEqual(os.readlink(path), entry["source"])
            manifest = Path(spec["stateDir"]) / "manifest.json"
            before = manifest.read_bytes()
            activate()
            self.assertEqual(manifest.read_bytes(), before)
            self.assertEqual({p.name for p in manifest.parent.iterdir()}, {"manifest.json"})
            for name in ("SKILL.md", "references/nested/SKILL.md"):
                self.assertTrue(stat.S_ISREG((fixture_root / name).lstat().st_mode))
            manual = fixture_root / "manual.md"
            manual.write_text("Manual content.\n")
            former = [Path(entry["path"]) for entry in spec["files"]]
            spec["files"] = []
            activate()
            for path in former:
                self.assertFalse(path.exists() or path.is_symlink(), str(path))
            self.assertEqual(manual.read_text(), "Manual content.\n")

    def test_synthetic_nested_resources_install_repeat_and_disable(self):
        self.check_specification({
            "version": 1,
            "home": "/fixture",
            "stateDir": "/fixture/.local/state/agentic-owned-files",
            "roots": [],
            "files": [],
            "retire": [],
        })

    @unittest.skipUnless(os.environ.get("ASSISTANT_OWNED_SPEC"), "Set ASSISTANT_OWNED_SPEC to a built specification.")
    def test_generated_spec_install_repeat_and_disable(self):
        spec = json.loads(Path(os.environ["ASSISTANT_OWNED_SPEC"]).read_text())
        self.check_specification(spec)


if __name__ == "__main__":
    unittest.main()
