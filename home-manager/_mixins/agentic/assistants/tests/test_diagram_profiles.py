"""Check profile selection and Home Manager output without activation."""

import importlib.util
import json
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ASSISTANTS = Path(__file__).resolve().parents[1]
REPO = ASSISTANTS.parents[3]
SKILL = ASSISTANTS / "skills/diagram-design"
SPEC = importlib.util.spec_from_file_location(
    "resolve_profile", SKILL / "scripts/resolve_profile.py"
)
assert SPEC is not None and SPEC.loader is not None
RESOLVER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RESOLVER)


class DiagramProfileTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.project = self.home / "project"
        self.project.mkdir()
        self.library = self.home / ".diagram-design/profiles"
        self.library.mkdir(parents=True)
        self.preference = self.home / ".diagram-design/preferences"
        self.marker = self.project / ".diagram-design"
        for slug in ("catppuccin-blue", "client"):
            (self.library / f"{slug}.md").write_text("profile fixture")

    def resolve(self, requested=None):
        return RESOLVER.resolve(self.project, self.home, SKILL, requested)

    def test_precedence_and_no_writes(self):
        self.assertEqual(self.resolve()["source"], "setup")
        self.preference.write_text("profile: catppuccin-blue\n")
        self.assertEqual(self.resolve()["source"], "user")
        self.marker.write_text("profile: client\n")
        self.assertEqual(self.resolve()["profile"], "client")
        self.assertEqual(self.resolve("catppuccin-blue")["source"], "request")
        self.assertEqual(self.marker.read_text(), "profile: client\n")
        self.assertEqual(self.preference.read_text(), "profile: catppuccin-blue\n")

    def test_default_is_installed_even_with_external_snapshot(self):
        (self.library / "default.md").write_text("not the installed guide")
        self.preference.write_text("profile: catppuccin-blue\n")
        self.marker.write_text("profile: default\n")
        self.assertEqual(
            self.resolve()["path"], str(SKILL / "references/style-guide.md")
        )
        self.assertEqual(self.resolve()["source"], "project")

    def test_invalid_selectors_warn_and_fall_through(self):
        self.preference.write_text("profile: catppuccin-blue\n")
        for content in (
            "profile: ../escape",
            "profile: client\nmode: dark",
            "profile: client\n\n",
            "profile: client\nprofile: client",
            "profile: $(id)",
        ):
            with self.subTest(content=content):
                self.marker.write_text(content)
                result = self.resolve()
                self.assertEqual(result["source"], "user")
                self.assertEqual(len(result["warnings"]), 1)
        self.preference.write_text("mode: dark")
        self.assertEqual(self.resolve()["source"], "setup")
        self.assertEqual(len(self.resolve()["warnings"]), 2)

    def test_missing_profile_never_falls_through(self):
        self.preference.write_text("profile: catppuccin-blue\n")
        self.marker.write_text("profile: missing\n")
        with self.assertRaisesRegex(ValueError, "Missing profile missing"):
            self.resolve()
        self.assertEqual(self.resolve("client")["profile"], "client")
        with self.assertRaisesRegex(ValueError, "Invalid requested"):
            self.resolve("../escape")

    def test_managed_selector_symlink_is_readable(self):
        target = self.home / "managed"
        target.write_text("profile: catppuccin-blue\n")
        self.preference.symlink_to(target)
        self.assertEqual(self.resolve()["source"], "user")
        self.assertTrue(self.preference.is_symlink())

    def test_generated_home_files(self):
        expression = f"""let
          flake = builtins.getFlake {json.dumps(str(REPO))};
          lib = flake.inputs.nixpkgs.lib;
          entry = user: builtins.head (import {ASSISTANTS}/default.nix {{
            inherit lib;
            pkgs = {{}};
            config = {{}};
            noughtyLib.isUser = names: builtins.elem user names;
          }}).config.home.file.contents;
        in {{
          martin = (entry "martin").condition;
          other = (entry "other").condition;
          profile = (entry "martin").content.".diagram-design/profiles/catppuccin-blue.md".text;
          preference = (entry "martin").content.".diagram-design/preferences".text.content;
          paths = builtins.attrNames (entry "martin").content;
        }}"""
        result = subprocess.run(
            ["nix", "eval", "--impure", "--json", "--expr", expression],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        generated = json.loads(result.stdout)
        self.assertTrue(generated["martin"])
        self.assertFalse(generated["other"])
        self.assertEqual(generated["preference"], "profile: catppuccin-blue\n")
        self.assertEqual(len(generated["paths"]), 2)
        profile = generated["profile"]
        self.assertNotRegex(profile, r"@(latte|mocha)\.")
        for colour in (
            "#eff1f5",
            "#1e1e2e",
            "#1e66f5",
            "#89b4fa",
            "#4c4f69",
            "#cdd6f4",
        ):
            self.assertIn(colour, profile)
        self.assertEqual(profile.count("<!-- diagram-design-profile"), 1)
        original = (SKILL / "references/style-guide.md").read_text()
        for heading, end in (
            ("### Semantic roles", "### Inversion"),
            ("## Typography", "### Font stack"),
        ):
            section = original.split(heading, 1)[1].split(end, 1)[0]
            for role in re.findall(r"^\| `([^`]+)`", section, re.MULTILINE):
                self.assertIn(f"| `{role}` |", profile)


if __name__ == "__main__":
    unittest.main()
