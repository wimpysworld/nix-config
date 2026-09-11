"""Deploy a built Home Manager specification into a temporary home."""

import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest


@unittest.skipUnless(os.environ.get("ASSISTANT_OWNED_SPEC"), "Set ASSISTANT_OWNED_SPEC to a built specification.")
class GeneratedDeploymentTests(unittest.TestCase):
    def test_generated_spec_install_repeat_and_disable(self):
        spec = json.loads(Path(os.environ["ASSISTANT_OWNED_SPEC"]).read_text())
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
            codex = home / ".codex/skills"
            self.assertTrue(stat.S_ISREG((codex / "love/SKILL.md").lstat().st_mode))
            nested = codex / "love/references/api/love-window/SKILL.md"
            self.assertTrue(stat.S_ISREG(nested.lstat().st_mode))
            manual = codex / "love/manual.md"
            manual.write_text("Manual content.\n")
            former = [Path(entry["path"]) for entry in spec["files"]]
            spec["files"] = []
            activate()
            for path in former:
                self.assertFalse(path.exists() or path.is_symlink(), str(path))
            self.assertEqual(manual.read_text(), "Manual content.\n")


if __name__ == "__main__":
    unittest.main()
