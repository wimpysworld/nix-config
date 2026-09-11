"""Regression tests for generated provider metadata.

Run with: python -m unittest discover -s home-manager/_mixins/agentic/assistants/tests
Requires Nix and PyYAML. No configuration is built or activated.
"""

import json
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest

import yaml


ASSISTANTS = Path(__file__).resolve().parents[1]
REPO = ASSISTANTS.parents[3]


class MetadataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        result = subprocess.run(
            ["nix", "eval", "--impure", "--raw", "--expr",
             f'(builtins.getFlake {json.dumps(str(REPO))}).inputs.nixpkgs.outPath'],
            capture_output=True, text=True, check=True,
        )
        cls.nixpkgs = result.stdout

    def evaluate(self, expression, header=None, success=True, files=None):
        with tempfile.TemporaryDirectory(prefix="assistant-metadata-test-") as directory:
            if header is not None:
                Path(directory, "header.toml").write_text(header)
            for name, content in (files or {}).items():
                path = Path(directory, name)
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
            expression = (
                f'let lib = import {self.nixpkgs}/lib; '
                f'm = import {ASSISTANTS}/metadata.nix {{ inherit lib; }}; '
                f'c = import {ASSISTANTS}/compose.nix {{ inherit lib; }}; '
                f'fixture = builtins.toPath {json.dumps(directory)}; '
                f'h = m.readHeader fixture; '
                f'in {expression}'
            )
            result = subprocess.run(
                ["nix", "eval", "--impure", "--json", "--expr", expression],
                capture_output=True, text=True,
            )
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
            return json.loads(result.stdout)
        self.assertNotEqual(result.returncode, 0, "Invalid metadata was accepted")
        return result.stderr

    def test_nested_values_and_false_survive_both_output_formats(self):
        header = '''
[common]
name = "fixture"
description = "A description: with # punctuation and \\"quotes\\"."
[pi]
inheritSkills = false
maxDepth = 0
[pi.extension]
enabled = false
labels = ["first", "second"]
'''
        result = self.evaluate('let p = m.project "agent" "pi" "fixture" h; in '
                               '{ yaml = m.renderYaml p; toml = m.renderToml p; }', header)
        expected = {
            "name": "fixture", "description": 'A description: with # punctuation and "quotes".',
            "systemPromptMode": "append", "inheritProjectContext": False,
            "inheritSkills": False, "maxDepth": 0,
            "extension": {"enabled": False, "labels": ["first", "second"]},
        }
        self.assertEqual(yaml.safe_load(result["yaml"]), expected)
        self.assertEqual(tomllib.loads(result["toml"]), expected)

    def test_only_selected_provider_fields_reach_frontmatter(self):
        header = '''
[common]
description = "Task description"
argument-hint = "<path>"
[claude]
context = "fork"
[opencode]
subtask = false
[pi]
extension = "pi-only"
[compose.claude]
use-task = true
[routing.claude]
model = "sonnet"
effort = "high"
[routing.pi.openai-codex]
model = "gpt-5.6-terra"
thinking = "medium"
'''
        result = self.evaluate('{ claude = m.project "command" "claude" "task" h; '
                               'pi = m.project "command" "pi" "task" h; '
                               'codex = m.project "command" "codex" "task" h; }', header)
        self.assertEqual(result["claude"], {
            "description": "Task description", "argument-hint": "<path>",
            "context": "fork", "model": "sonnet", "effort": "high",
        })
        self.assertEqual(result["pi"], {
            "description": "Task description", "argument-hint": "<path>", "extension": "pi-only",
        })
        self.assertEqual(result["codex"], {"description": "Task description"})

    def test_pi_defaults_and_explicit_overrides(self):
        result = self.evaluate('{ defaults = m.project "agent" "pi" "worker" {}; '
                               'overrides = m.project "agent" "pi" "worker" h; }', '''
[pi]
systemPromptMode = "replace"
inheritProjectContext = true
inheritSkills = false
''')
        self.assertEqual(result["defaults"], {
            "name": "worker", "systemPromptMode": "append",
            "inheritProjectContext": False, "inheritSkills": True,
        })
        self.assertEqual(result["overrides"], {
            "name": "worker", "systemPromptMode": "replace",
            "inheritProjectContext": True, "inheritSkills": False,
        })

    def test_native_model_settings_cannot_compete_with_routing(self):
        for provider in ("common", "claude", "opencode", "codex", "pi"):
            with self.subTest(provider=provider):
                error = self.evaluate("h", f'[{provider}]\nmodel = "native-model"\n'
                                      '[routing.codex]\nmodel = "route-model"\n', success=False)
                self.assertIn("routing", error)

    def test_invalid_routing_and_non_boolean_controls_fail(self):
        for header in (
            '[routing.pi.openai-codex]\nthinking = "ultra"\n',
            '[routing.codex]\nmodel = ""\n',
            '[routing.codex]\nreasoningEffort = "high"\n',
            '[compose.codex]\nspawn-agent = "false"\n',
        ):
            with self.subTest(header=header):
                self.evaluate("h", header, success=False)

    def test_opencode_options_cannot_bypass_routing(self):
        error = self.evaluate("h", '''
[opencode.options]
reasoningEffort = "low"
''', success=False)
        self.assertIn("Model settings belong exclusively in routing tables.", error)
        result = self.evaluate('m.project "agent" "opencode" "fixture" h', '''
[opencode.options]
textVerbosity = "low"
store = false
[opencode.metadata]
model = "A descriptive label"
[routing.opencode]
reasoningEffort = "high"
''')
        self.assertEqual(result, {
            "options": {"textVerbosity": "low", "store": False},
            "metadata": {"model": "A descriptive label"},
            "reasoningEffort": "high",
        })

    def test_pi_skill_routing_is_absent_from_native_frontmatter(self):
        result = self.evaluate('m.project "skill" "pi" "fixture" h', '''
[common]
name = "fixture"
description = "A directly invoked skill."
[routing.pi.openai-codex]
model = "test-model"
thinking = "high"
''')
        self.assertEqual(result, {"name": "fixture", "description": "A directly invoked skill."})

    def test_unsupported_skill_routing_fails_instead_of_disappearing(self):
        for provider in ("codex", "opencode"):
            with self.subTest(provider=provider):
                self.evaluate(f'm.project "skill" "{provider}" "fixture" h',
                              '[common]\nname = "fixture"\ndescription = "Fixture."\n'
                              f'[routing.{provider}]\nmodel = "test-model"\n', success=False)

    def test_migrated_garfield_routes_preserve_model_pins(self):
        result = self.evaluate('{ models = c.extractAgentProviderModels "garfield"; '
                               'thinking = c.extractAgentProviderThinking "garfield"; }')
        self.assertEqual(result, {
            "models": {"anthropic": "claude-sonnet-5", "google": "gemini-3-flash",
                       "openai-codex": "gpt-5.6-terra"},
            "thinking": {"openai-codex": "medium"},
        })

    def test_codex_command_pin_uses_a_separate_role(self):
        result = self.evaluate('''{
          pinned = m.commandDispatch { worker = true; } "review" "worker" h;
          ordinary = m.commandDispatch { worker = true; } "inspect" "worker" {};
        }''', '''
[routing.codex]
model = "command-model"
model_reasoning_effort = "high"
''')
        self.assertEqual(result["pinned"]["role"], "command-review")
        self.assertEqual(result["pinned"]["selectedAgent"], "worker")
        self.assertEqual(result["pinned"]["route"], {
            "model": "command-model", "model_reasoning_effort": "high",
        })
        self.assertEqual(result["ordinary"]["role"], "worker")
        self.assertEqual(result["ordinary"]["route"], {})

    def test_standalone_codex_commands_remain_inline_unless_an_agent_is_selected(self):
        result = self.evaluate('''{
          inline = m.commandDispatch { worker = true; } "plain" null {};
          delegated = m.commandDispatch { worker = true; } "review" null h;
        }''', '''
[compose]
agent = "worker"
[routing.codex]
model = "command-model"
''')
        self.assertIsNone(result["inline"]["selectedAgent"])
        self.assertIsNone(result["inline"]["role"])
        self.assertEqual(result["delegated"]["selectedAgent"], "worker")
        self.assertEqual(result["delegated"]["role"], "command-review")
        self.assertTrue(result["delegated"]["spawn"])

    def test_codex_inline_routes_and_unknown_agents_fail(self):
        for agent, header in (
            ("null", '[routing.codex]\nmodel = "test-model"\n'),
            ('"worker"', '[compose.codex]\nspawn-agent = false\n'
                         '[routing.codex]\nmodel = "test-model"\n'),
            ('"worker"', '[compose]\nagent = "missing"\n'),
        ):
            with self.subTest(agent=agent, header=header):
                self.evaluate(f'm.commandDispatch {{ worker = true; }} "review" {agent} h',
                              header, success=False)

    def test_codex_commands_cannot_enable_implicit_invocation(self):
        result = self.evaluate('m.commandPolicy h', '''
[codex]
allow-implicit-invocation = false
''')
        self.assertFalse(result["policy"]["allow_implicit_invocation"])
        self.assertFalse(self.evaluate('m.commandPolicy {}')["policy"]["allow_implicit_invocation"])
        for value in ("true", '\"false\"'):
            with self.subTest(value=value):
                self.evaluate('m.commandPolicy h',
                              f'[codex]\nallow-implicit-invocation = {value}\n', success=False)

    def test_codex_skill_companion_fields_do_not_leak_into_frontmatter(self):
        result = self.evaluate('''{
          frontmatter = m.project "skill" "codex" "fixture" h;
          companion = m.renderYaml (m.skillCompanion fixture);
        }''', '''
[common]
name = "fixture"
description = "A directly invoked skill."
[codex.interface]
display_name = "Fixture skill"
[codex.policy]
allow_implicit_invocation = false
[codex.dependencies]
tools = [{ type = "mcp", value = "fixture-service" }]
''')
        self.assertEqual(result["frontmatter"], {
            "name": "fixture", "description": "A directly invoked skill.",
        })
        self.assertEqual(yaml.safe_load(result["companion"]), {
            "interface": {"display_name": "Fixture skill"},
            "policy": {"allow_implicit_invocation": False},
            "dependencies": {"tools": [{"type": "mcp", "value": "fixture-service"}]},
        })

    def test_codex_companion_is_deployable_for_root_and_nested_skills(self):
        header = '''
[common]
name = "NAME"
description = "A directly invoked skill."
[codex.policy]
allow_implicit_invocation = false
'''
        files = {
            "styles/house-style/house-style.md": "Use plain language.\n",
            "skills/communication-rules/SKILL.md": "Use plain language.\n",
            "skills/fixture/header.toml": header.replace("NAME", "fixture"),
            "skills/fixture/SKILL.md": "Run the fixture.\n",
            "skills/fixture/references/nested/header.toml": header.replace("NAME", "nested"),
            "skills/fixture/references/nested/SKILL.md": "Run the nested fixture.\n",
        }
        result = self.evaluate('''let
          fixtureComposer = import ''' + str(ASSISTANTS) + '''/compose.nix {
            inherit lib;
            basePath = fixture;
            pkgs = {
              writeText = name: text: text;
              linkFarm = name: entries: { overrideAttrs = _: entries; };
            };
          };
          skill = (fixtureComposer.composeSkillsFor "codex").fixture;
        in { inherit (skill) content extras path; }''', files=files)
        self.assertEqual(result["extras"]["agents"], "directory")
        self.assertEqual(result["extras"]["references"], "directory")
        self.assertNotIn("header.toml", result["extras"])
        entries = {entry["name"]: entry["path"] for entry in result["path"]}
        for prefix in ("", "references/nested/"):
            with self.subTest(prefix=prefix):
                companion = yaml.safe_load(entries[prefix + "agents/openai.yaml"])
                self.assertIs(companion["policy"]["allow_implicit_invocation"], False)
                frontmatter = yaml.safe_load(entries[prefix + "SKILL.md"].split("---", 2)[1])
                self.assertNotIn("policy", frontmatter)
                self.assertNotIn(prefix + "header.toml", entries)


if __name__ == "__main__":
    unittest.main()
