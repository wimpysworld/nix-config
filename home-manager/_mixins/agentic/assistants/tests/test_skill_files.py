"""Build skill trees and check Codex discovery without activating a configuration."""

import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest

import yaml


ASSISTANTS = Path(__file__).resolve().parents[1]
REPO = ASSISTANTS.parents[3]


class SkillFileTests(unittest.TestCase):
    def test_pi_routes_include_secret_skills_with_public_headers(self):
        files = {
            "skills/routed/SKILL.sops": "fixture-routed\n",
            "skills/routed/header.toml": '''[common]
name = "routed"
description = "An encrypted fixture skill."
[routing.pi.openai]
model = "fixture-model"
thinking = "high"
''',
            "skills/self-review/SKILL.sops": "fixture-headerless\n",
            "skills/public/SKILL.md": "Run the public fixture.\n",
            "skills/public/header.toml": '''[common]
name = "public"
description = "A public fixture skill."
''',
        }
        with tempfile.TemporaryDirectory(prefix="assistant-skill-routes-") as directory:
            for name in ("default.nix", "compose.nix", "metadata.nix"):
                Path(directory, name).write_text((ASSISTANTS / name).read_text())
            for name, content in files.items():
                path = Path(directory, name)
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
            expression = f'''let
              flake = builtins.getFlake {json.dumps(str(REPO))};
              pkgs = import flake.inputs.nixpkgs {{ system = builtins.currentSystem; }};
              assistants = import {directory}/default.nix {{
                inherit pkgs;
                inherit (pkgs) lib;
                config = {{}};
                noughtyLib = {{}};
              }};
            in assistants.config.agentic.assistants.pi.invocationRoutes.skills'''
            result = subprocess.run(
                ["nix", "eval", "--impure", "--json", "--expr", expression],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout), {
                "public": {"providers": {}},
                "routed": {"providers": {
                    "openai": {"model": "fixture-model", "thinking": "high"},
                }},
            })

    def test_codex_discovers_regular_root_and_nested_skill_files(self):
        header = '''[common]
name = "NAME"
description = "A fixture skill."
[codex.policy]
allow_implicit_invocation = false
'''
        files = {
            "styles/house-style/house-style.md": "Use plain language.\n",
            "skills/communication-rules/SKILL.md": "Use plain language.\n",
            "skills/delegate-task/header.toml": header.replace("NAME", "delegate-task"),
            "skills/fixture/header.toml": header.replace("NAME", "fixture"),
            "skills/fixture/SKILL.md": "Run the fixture.\n",
            "skills/fixture/references/nested/header.toml": header.replace("NAME", "nested"),
            "skills/fixture/references/nested/SKILL.md": "Run the nested fixture.\n",
            "skills/fixture/references/nested/guide.md": "Keep this supporting file.\n",
            "skills/fixture/references/legacy/SKILL.md":
                "---\nname: legacy\ndescription: Legacy fixture.\n---\n\nKeep this skill.\n",
        }
        with tempfile.TemporaryDirectory(prefix="assistant-skill-files-") as directory:
            for name, content in files.items():
                path = Path(directory, name)
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
            expression = f'''let
              flake = builtins.getFlake {json.dumps(str(REPO))};
              pkgs = import flake.inputs.nixpkgs {{ system = builtins.currentSystem; }};
              composer = import {ASSISTANTS}/compose.nix {{
                inherit pkgs;
                inherit (pkgs) lib;
                basePath = builtins.path {{ path = {json.dumps(directory)}; }};
              }};
              skills = composer.composeSkillsFor "codex";
            in [ skills.fixture.path skills.delegate-task.path ]'''
            result = subprocess.run(
                ["nix", "build", "--impure", "--json", "--no-link", "--expr", expression],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            trees = [Path(item["outputs"]["out"]) for item in json.loads(result.stdout)]
            tree = next(path for path in trees if path.name.endswith("-skill-fixture"))
            generated = next(path for path in trees if path.name.endswith("-skill-delegate-task"))
            deployed = Path(directory, "deployed")
            deployed.mkdir()
            (deployed / "SKILL.md").write_text((tree / "SKILL.md").read_text())
            (deployed / "references").symlink_to(tree / "references", target_is_directory=True)
            discovered = set()
            pending = [deployed]
            while pending:
                with os.scandir(pending.pop()) as entries:
                    for entry in entries:
                        if entry.is_dir():
                            pending.append(Path(entry.path))
                        elif entry.name == "SKILL.md" and entry.is_file(follow_symlinks=False):
                            discovered.add(Path(entry.path).relative_to(deployed).as_posix())
            self.assertEqual(discovered, {
                "SKILL.md", "references/nested/SKILL.md", "references/legacy/SKILL.md",
            })
            self.assertTrue(stat.S_ISREG((generated / "SKILL.md").lstat().st_mode))
            for name in discovered:
                self.assertTrue(stat.S_ISREG((tree / name).lstat().st_mode), name)
            for prefix in ("", "references/nested/"):
                with self.subTest(prefix=prefix):
                    skill = (tree / prefix / "SKILL.md").read_text()
                    self.assertNotIn("policy", yaml.safe_load(skill.split("---", 2)[1]))
                    companion = yaml.safe_load((tree / prefix / "agents/openai.yaml").read_text())
                    self.assertIs(companion["policy"]["allow_implicit_invocation"], False)
                    self.assertFalse((tree / prefix / "header.toml").exists())
            for name in ("references/nested/guide.md", "references/legacy/SKILL.md"):
                self.assertEqual((tree / name).read_text(), files["skills/fixture/" + name])
            self.assertTrue((tree / "references/nested/guide.md").is_symlink())


if __name__ == "__main__":
    unittest.main()
