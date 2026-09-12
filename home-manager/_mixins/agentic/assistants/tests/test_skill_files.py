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
    def test_root_and_leaf_commands_use_the_same_routes_for_public_and_secret_bodies(self):
        body = "TASK_SENTINEL: keep caller context and delegate checks for $ARGUMENTS."
        files = {
            "instructions/global.md": "Keep caller context.\n",
            "styles/house-style/house-style.md": "Use plain language.\n",
            "skills/communication-rules/SKILL.md": "Use plain language.\n",
            "skills/communication-rules/header.toml":
                '[common]\nname = "communication-rules"\ndescription = "Use plain language."\n',
            "skills/delegate-task/header.toml":
                '[common]\nname = "delegate-task"\ndescription = "Delegate a task."\n',
            "agents/worker/prompt.md": "PERSONA_SENTINEL\n",
            "agents/worker/header.toml": '[common]\ndescription = "Fixture worker."\n',
        }
        cases = {}
        for selection in ("scoped", "bound", "unbound"):
            for mode in ("root", "leaf", "inline"):
                for secret in (False, True):
                    name = f'{selection}-{mode}-{"secret" if secret else "public"}'
                    cases[name] = (selection, mode, secret)
                    directory = (f"agents/worker/commands/{name}" if selection == "scoped"
                                 else f"commands/{name}")
                    header = '[common]\ndescription = "Fixture command."\n[compose]\n'
                    header += f'root = {str(mode == "root").lower()}\n'
                    if selection == "bound":
                        header += 'agent = "worker"\n'
                    header += ('[compose.claude]\nuse-task = true\n'
                               '[compose.pi]\nspawn-agent = true\n'
                               '[compose.codex]\nspawn-agent = '
                               + str(mode != "inline").lower() + '\n')
                    if mode == "root":
                        header += ('[claude]\ncontext = "fork"\nagent = "worker"\n'
                                   '[opencode]\nagent = "worker"\nsubtask = true\n')
                    files[directory + "/header.toml"] = header
                    files[directory + ("/prompt.sops" if secret else "/prompt.md")] = (
                        name if secret else body) + "\n"
        with tempfile.TemporaryDirectory(prefix="assistant-command-routes-") as directory:
            for name in ("default.nix", "compose.nix", "metadata.nix", "owned-deployment.nix"):
                Path(directory, name).write_text((ASSISTANTS / name).read_text())
            for name, content in files.items():
                path = Path(directory, name)
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
            secret_names = [name for name, (_, _, secret) in cases.items() if secret]
            expression = f'''let
              flake = builtins.getFlake {json.dumps(str(REPO))};
              pkgs = import flake.inputs.nixpkgs {{ system = builtins.currentSystem; }};
              inherit (pkgs) lib;
              secretNames = builtins.fromJSON {json.dumps(json.dumps(secret_names))};
              module = import {directory}/default.nix {{
                inherit lib;
                pkgs = pkgs // {{ writeText = name: text: text; }};
                noughtyLib.userHasTag = _: true;
                config = {{
                  home.homeDirectory = "/fixture";
                  home.preferXdgDirectories = false;
                  xdg.configHome = "/fixture/.config";
                  xdg.stateHome = "/fixture/.state";
                  programs.claude-code.enable = true;
                  programs.opencode.enable = true;
                  programs.codex.enable = true;
                  sops.placeholder = lib.genAttrs secretNames (name: "PLACEHOLDER_" + name);
                  sops.secrets = lib.genAttrs secretNames (name: {{ path = "/run/secret/" + name; }});
                  sops.templates = lib.genAttrs
                    (builtins.attrNames module.config.sops.templates)
                    (name: {{ path = "/run/template/" + name; }});
                }};
              }};
              cfg = module.config;
            in {{
              claude = cfg.programs.claude-code.content.commands;
              opencode = cfg.programs.opencode.content.commands;
              pi = lib.filterAttrs (name: _: lib.hasPrefix ".pi/agent/prompts/" name)
                cfg.agentic.assistants.pi.homeFiles;
              templates = cfg.sops.templates;
              owned = cfg.agentic.assistants.ownedSpec.files;
            }}'''
            result = subprocess.run(
                ["nix", "eval", "--impure", "--json", "--expr", expression],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            generated = json.loads(result.stdout)
        owned = {entry["path"]: entry for entry in generated["owned"]}
        self.assertFalse(any("/agents/command-" in path for path in owned))
        for name, (selection, mode, secret) in cases.items():
            for platform in ("claude", "opencode", "pi", "codex"):
                with self.subTest(command=name, platform=platform):
                    expected_body = "PLACEHOLDER_" + name if secret else body
                    if platform == "codex":
                        entry = owned[f"/fixture/.codex/skills/{name}/SKILL.md"]
                        rendered = entry["prefix"] if secret else entry["source"]
                        if secret:
                            self.assertEqual(entry["source"], "/run/secret/" + name)
                            expected_body = ""
                        policy = yaml.safe_load(
                            owned[f"/fixture/.codex/skills/{name}/agents/openai.yaml"]["source"])
                        self.assertIs(policy["policy"]["allow_implicit_invocation"], False)
                    elif secret:
                        rendered = generated["templates"][f"assistant-{platform}-command-{name}"]["content"]
                    elif platform == "pi":
                        rendered = generated["pi"][f".pi/agent/prompts/{name}.md"]["text"]
                    else:
                        rendered = generated[platform][name]
                    frontmatter, task = rendered.split("---", 2)[1:]
                    native = yaml.safe_load(frontmatter)
                    self.assertNotIn("compose", native)
                    self.assertNotIn("root", native)
                    if mode == "root" or selection == "unbound":
                        self.assertEqual(task.strip(), expected_body)
                        self.assertNotIn("PERSONA_SENTINEL", rendered)
                        self.assertNotIn("agent", native)
                        if mode == "root" and platform == "opencode":
                            self.assertIs(native["subtask"], False)
                        if mode == "root" and platform == "claude":
                            self.assertNotIn("context", native)
                    elif platform == "codex":
                        if mode == "inline":
                            self.assertIn("PERSONA_SENTINEL", task)
                            self.assertNotIn("Use the `spawn_agent` tool", task)
                        else:
                            self.assertIn("Use the `spawn_agent` tool to launch the `worker` agent", task)
                            self.assertNotIn("PERSONA_SENTINEL", task)
                    elif platform == "pi":
                        self.assertIn("Use the subagent tool to launch the `worker` agent", task)
                    elif platform == "claude":
                        self.assertIn("Use the Task tool to launch the worker agent", task)
                    else:
                        self.assertEqual(native["agent"], "worker")
                    if expected_body:
                        self.assertIn(expected_body, task)

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
