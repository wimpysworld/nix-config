"""Regression tests for generated provider metadata.

Run with: python -m unittest discover -s home-manager/_mixins/agentic/assistants/tests
Requires Nix and PyYAML. No configuration is built or activated.
"""

import json
from pathlib import Path
import re
import shlex
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

    def test_pi_spawn_control_rejects_non_boolean_values(self):
        for value in ('"false"', '0', '[]', '{}'):
            with self.subTest(value=value):
                error = self.evaluate("h", f'[compose.pi]\nspawn-agent = {value}\n',
                                      success=False)
                self.assertIn("Composition switches must be booleans.", error)

    def test_root_control_requires_a_boolean_and_overrides_spawn(self):
        for value in ('"true"', '0', '[]', '{}'):
            with self.subTest(value=value):
                self.evaluate("h", f'[compose]\nroot = {value}\n', success=False)
        for value in (None, "false", "true"):
            with self.subTest(value=value):
                header = '[compose]\nagent = "worker"\n'
                if value is not None:
                    header += f'root = {value}\n'
                header += '[compose.codex]\nspawn-agent = true\n'
                result = self.evaluate(
                    'm.commandDispatch { worker = true; } "fixture" null h', header)
                self.assertEqual(result["spawn"], value != "true")
        self.evaluate('m.commandDispatch { worker = true; } "fixture" "worker" h',
                      '[compose]\nroot = true\n[routing.codex]\nmodel = "pinned"\n',
                      success=False)

    def test_root_commands_override_native_bindings_and_preserve_the_task(self):
        body = "Keep caller context. Delegate independent checks for $ARGUMENTS."
        files = {"agents/worker/prompt.md": "PERSONA_SENTINEL\n"}
        for selection in ("scoped", "bound", "unbound"):
            for mode in ("absent", "false", "true"):
                name = f"{selection}-{mode}"
                directory = (f"agents/worker/commands/{name}" if selection == "scoped"
                             else f"commands/{name}")
                header = '[common]\ndescription = "Check caller context."\n[compose]\n'
                if selection == "bound":
                    header += 'agent = "worker"\n'
                if mode != "absent":
                    header += f'root = {mode}\n'
                header += ('[compose.claude]\nuse-task = true\n'
                           '[compose.pi]\nspawn-agent = true\n'
                           '[compose.codex]\nspawn-agent = true\n'
                           '[claude]\ncontext = "fork"\nagent = "worker"\n'
                           '[opencode]\nagent = "worker"\nsubtask = true\n')
                files[directory + "/header.toml"] = header
                files[directory + "/prompt.md"] = body + "\n"
        result = self.evaluate('''let
          composer = import ''' + str(ASSISTANTS) + '''/compose.nix {
            inherit lib; basePath = fixture;
          };
        in lib.genAttrs [ "claude" "opencode" "pi" "codex" ] composer.composeCommands''',
                               files=files)
        for platform, commands in result.items():
            for selection in ("scoped", "bound", "unbound"):
                with self.subTest(platform=platform, selection=selection):
                    self.assertEqual(commands[selection + "-absent"],
                                     commands[selection + "-false"])
                    rendered = commands[selection + "-true"]
                    header, task = rendered.split("---", 2)[1:]
                    native = yaml.safe_load(header)
                    self.assertEqual(task.strip(), body)
                    self.assertNotIn("compose", native)
                    self.assertNotIn("root", native)
                    self.assertNotIn("agent", native)
                    if platform == "claude":
                        self.assertNotIn("context", native)
                    if platform == "opencode":
                        self.assertIs(native["subtask"], False)
                    if selection != "unbound":
                        leaf = commands[selection + "-false"]
                        if platform == "claude":
                            self.assertIn("Use the Task tool to launch the worker agent", leaf)
                        elif platform == "pi":
                            self.assertIn("Use the subagent tool to launch the `worker` agent", leaf)
                        elif platform == "opencode":
                            self.assertEqual(yaml.safe_load(leaf.split("---", 2)[1])["agent"],
                                             "worker")

    def test_real_command_inventory_keeps_root_orchestrators_and_leaf_specialists(self):
        result = self.evaluate('''lib.listToAttrs (map (entry: {
          name = entry.name;
          value = let header = c.commandMetadata entry.agentName entry.name; in {
            root = header.compose.root or false;
            dispatch = m.commandDispatch c.agentDirs entry.name entry.agentName header;
            rendered = lib.genAttrs [ "claude" "opencode" "pi" ]
              (platform: c.composeCommandFromPrompt platform entry.agentName entry.name
                "INVENTORY_TASK_SENTINEL");
            policy = m.commandPolicy header;
          };
        }) c.commandSources)''')
        for name in ("address-code-review", "make-commit", "make-pr", "implement-task",
                     "implement-plan", "finish-pr", "babysit-pr", "handover-fresh",
                     "handover-fork", "review-code-mine", "project-tests-review",
                     "gather-review-data", "audit-code-security"):
            with self.subTest(root_command=name):
                self.assertTrue(result[name]["root"])
        self.assertFalse(result["create-agents-md"]["root"])
        for name, command in result.items():
            with self.subTest(command=name):
                self.assertIs(command["policy"]["policy"]["allow_implicit_invocation"], False)
                if command["root"]:
                    self.assertFalse(command["dispatch"]["spawn"])
                    self.assertEqual(command["dispatch"]["route"], {})
                    for platform, rendered in command["rendered"].items():
                        with self.subTest(platform=platform):
                            header, task = rendered.split("---", 2)[1:]
                            native = yaml.safe_load(header)
                            self.assertEqual(task.strip(), "INVENTORY_TASK_SENTINEL")
                            self.assertNotIn("agent", native)
                            if platform == "claude":
                                self.assertNotIn("context", native)
                            if platform == "opencode":
                                self.assertIs(native["subtask"], False)
                elif command["dispatch"]["selectedAgent"] is not None:
                    self.assertTrue(command["dispatch"]["spawn"])
                    for platform, rendered in command["rendered"].items():
                        with self.subTest(platform=platform):
                            task = rendered.split("---", 2)[2]
                            child = (task if platform == "opencode"
                                     else task.split("\n## Task\n", 1)[1])
                            self.assertIn("You are a leaf worker.", child)
                            self.assertTrue(child.rstrip().endswith("INVENTORY_TASK_SENTINEL"))
                            self.assertNotIn("Use the Task tool to launch", child)
                            self.assertNotIn("Use the subagent tool to launch", child)

    def test_pi_command_spawn_control_preserves_body_and_other_providers(self):
        body = "Delegate independent checks.\n\nReview $ARGUMENTS and return the report."
        for selection in ("scoped", "standalone"):
            with self.subTest(selection=selection):
                files = {"agents/worker/prompt.md": "Check the task.\n"}
                for switch in ("absent", "true", "false"):
                    directory = (f"agents/worker/commands/{switch}" if selection == "scoped"
                                 else f"commands/{switch}")
                    header = '[common]\ndescription = "Check a task."\n'
                    if selection == "standalone":
                        header += '[compose]\nagent = "worker"\n'
                    if switch != "absent":
                        header += f'[compose.pi]\nspawn-agent = {switch}\n'
                    files[directory + "/header.toml"] = header
                    files[directory + "/prompt.md"] = body + "\n"
                result = self.evaluate('''let
                  fixtureComposer = import ''' + str(ASSISTANTS) + '''/compose.nix {
                    inherit lib;
                    basePath = fixture;
                  };
                in lib.genAttrs [ "pi" "claude" "opencode" "codex" ]
                  fixtureComposer.composeCommands''', files=files)
                for platform, commands in result.items():
                    with self.subTest(platform=platform):
                        self.assertEqual(commands["absent"], commands["true"])
                        for rendered in commands.values():
                            frontmatter = yaml.safe_load(rendered.split("---", 2)[1])
                            self.assertNotIn("compose", frontmatter)
                            self.assertNotIn("spawn-agent", frontmatter)
                            self.assertTrue(rendered.endswith(body + "\n"))
                        if platform == "pi":
                            self.assertEqual(commands["false"].split("---", 2)[2],
                                             "\n\n" + body + "\n")
                            self.assertIn("Use the subagent tool to launch the `worker` agent",
                                          commands["true"])
                            self.assertIn('Set `context` to `"fresh"`.', commands["true"])
                        else:
                            self.assertEqual(commands["absent"], commands["false"])

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

    def test_only_child_dispatch_gets_the_leaf_contract(self):
        body = "Review $ARGUMENTS. Return the report."
        files = {"agents/worker/prompt.md": "PERSONA_SENTINEL\n"}
        for name, controls in {
            "default": "",
            "inline": ('[compose.claude]\nuse-task = false\n'
                       '[compose.pi]\nspawn-agent = false\n'
                       '[opencode]\nsubtask = false\n'),
        }.items():
            directory = f"agents/worker/commands/{name}"
            files[directory + "/header.toml"] = (
                '[common]\ndescription = "Check a task."\n' + controls)
            files[directory + "/prompt.md"] = body
        result = self.evaluate('''let composer = import ''' + str(ASSISTANTS) + '''/compose.nix {
          inherit lib; basePath = fixture;
        }; in lib.genAttrs [ "claude" "opencode" "pi" ] composer.composeCommands''',
                               files=files)
        for platform, commands in result.items():
            with self.subTest(platform=platform):
                inline = commands["inline"].split("---", 2)[2].strip()
                self.assertEqual(inline, ("@worker\n\n" if platform == "claude" else "") + body)
                delegated = commands["default"].split("---", 2)[2]
                child = (delegated if platform == "opencode"
                         else delegated.split("\n## Task\n", 1)[1])
                self.assertIn("You are a leaf worker.", child)
                self.assertTrue(child.rstrip().endswith(body))

    def test_native_specialists_keep_routes_and_tools_without_nested_dispatch(self):
        result = self.evaluate('''lib.genAttrs [ "claude" "opencode" "pi" ]
          (platform: lib.mapAttrs (name: _: c.composeAgentFromPrompt platform name
            "PERSONA_SENTINEL") c.agentDirs)''')
        for platform, agents in result.items():
            for name, rendered in agents.items():
                with self.subTest(platform=platform, agent=name):
                    native = yaml.safe_load(rendered.split("---", 2)[1])
                    self.assertEqual(rendered.split("---", 2)[2].strip(), "PERSONA_SENTINEL")
                    original = tomllib.loads((ASSISTANTS / "agents" / name / "header.toml").read_text())
                    for key, value in original.get("routing", {}).get(platform, {}).items():
                        if platform != "pi":
                            self.assertEqual(native[key], value)
                    if platform == "claude":
                        self.assertIn("Agent", native["disallowedTools"])
                    elif platform == "opencode":
                        self.assertEqual(native["mode"], "subagent")
                        self.assertEqual(native["permission"]["task"], "deny")
                        self.assertEqual(native["permission"]["question"], "allow")
                    else:
                        self.assertFalse(native["inheritProjectContext"])
                        self.assertTrue(native["inheritSkills"])

    def project_runtime(self, client, projection):
        # Evaluate the original let bindings without packages, activation or secrets.
        source = (ASSISTANTS.parent / client / "default.nix").read_text()
        source = re.sub(r"(?<=import )\.\./[\w./-]+",
                        lambda match: str((ASSISTANTS.parent / client / match[0]).resolve()),
                        source)
        bindings, module = source.rsplit("\nin\n", 1)
        projected = bindings + "\n  runtimeModule = " + module + ";\nin " + projection
        return self.evaluate('''let
          runtime = import (fixture + "/runtime-projection.nix") {
            inherit lib;
            pkgs = import ''' + self.nixpkgs + ''' { system = builtins.currentSystem; };
            config.noughty.host.tags = [];
            config.noughty.host.is.linux = false;
            inputs = {}; noughtyLib = {}; catppuccinPalette = {};
          };
        in runtime''', files={"runtime-projection.nix": projected})

    def test_runtime_depth_keeps_root_dispatch_available(self):
        codex = self.project_runtime("codex", '''{
          inherit (codexSettings) agents;
          inherit (codexSettings.features) multi_agent multi_agent_v2;
        }''')
        self.assertEqual(codex["agents"]["max_depth"], 1)
        self.assertGreater(codex["agents"]["max_threads"], 1)
        self.assertIs(codex["multi_agent"], True)
        self.assertIs(codex["multi_agent_v2"], False)
        claude = self.project_runtime("claude-code", '''{
          environment = claudeEnvironment;
          teammateMode = (lib.evalModules {
            modules = [{ options.teammateMode = lib.mkOption { type = lib.types.str; }; }]
              ++ map (settings: lib.filterAttrs (name: _: name == "teammateMode") settings)
                runtimeModule.config.content.programs.claude-code.settings.contents;
          }).config.teammateMode;
        }''')
        self.assertEqual(claude["environment"]["CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH"], "1")
        self.assertEqual(claude["environment"]["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"], "1")
        self.assertEqual(claude["teammateMode"], "in-process")

    def test_claude_hook_blocks_workers_but_keeps_root_and_messages(self):
        groups = self.project_runtime("claude-code", "claudeLeafHooks.PreToolUse.content")
        self.assertEqual(len(groups), 1)
        group = groups[0]
        for tool in ("Agent", "Task"):
            self.assertIsNotNone(re.fullmatch(group["matcher"], tool))
        for tool in ("SendMessage", "Read", "Bash", "TaskOutput", "TaskStop"):
            self.assertIsNone(re.fullmatch(group["matcher"], tool))
        command = shlex.split(group["hooks"][0]["command"])
        for identity in ({}, {"agent_id": None}, {"agent_id": ""},
                         {"agent_id": "worker-123"}, {"agent_id": "reviewer@team"}):
            with self.subTest(identity=identity):
                payload = {"hook_event_name": "PreToolUse", "tool_name": "Agent",
                           "tool_input": {"prompt": "Delegate another task."}, **identity}
                result = subprocess.run(command, input=json.dumps(payload),
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                response = json.loads(result.stdout)
                if identity.get("agent_id"):
                    self.assertEqual(response["hookSpecificOutput"]["permissionDecision"], "deny")
                    self.assertEqual(response["hookSpecificOutput"]["hookEventName"], "PreToolUse")
                else:
                    self.assertEqual(response, {})

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
