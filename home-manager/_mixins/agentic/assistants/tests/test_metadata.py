"""Regression tests for generated provider metadata.

Run with: python -m unittest discover -s home-manager/_mixins/agentic/assistants/tests
Requires Nix and PyYAML. No configuration is built or activated.
"""

import json
import re
import shlex
import subprocess
import tempfile
import unittest
from pathlib import Path
from typing import Any

import tomllib
import yaml

ASSISTANTS = Path(__file__).resolve().parents[1]
REPO = ASSISTANTS.parents[3]


class MetadataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        result = subprocess.run(
            [
                "nix",
                "eval",
                "--impure",
                "--raw",
                "--expr",
                f"(builtins.getFlake {json.dumps(str(REPO))}).inputs.nixpkgs.outPath",
            ],
            capture_output=True,
            text=True,
            check=True,
        )
        cls.nixpkgs = result.stdout

    def evaluate(self, expression, header=None, success=True, files=None) -> Any:
        with tempfile.TemporaryDirectory(
            prefix="assistant-metadata-test-"
        ) as directory:
            if header is not None:
                Path(directory, "header.toml").write_text(header)
            for name, content in (files or {}).items():
                path = Path(directory, name)
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
            expression = (
                f"let lib = import {self.nixpkgs}/lib; "
                f"m = import {ASSISTANTS}/metadata.nix {{ inherit lib; }}; "
                f"c = import {ASSISTANTS}/compose.nix {{ inherit lib; }}; "
                f"fixture = builtins.toPath {json.dumps(directory)}; "
                f"h = m.readHeader fixture; "
                f"in {expression}"
            )
            result = subprocess.run(
                ["nix", "eval", "--impure", "--json", "--expr", expression],
                capture_output=True,
                text=True,
            )
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
            return json.loads(result.stdout)
        self.assertNotEqual(result.returncode, 0, "Invalid metadata was accepted")
        return result.stderr

    def test_source_names_are_specific_to_commands(self):
        header = '[common]\ndescription = "Fixture."\n'
        files = {
            "agents/worker/header.toml": header,
            "agents/worker/prompt.md": "AGENT_BODY\n",
            "commands/standalone/command.toml": header,
            "commands/standalone/command.md": "STANDALONE_BODY\n",
            "agents/worker/commands/owned/command.toml": header,
            "agents/worker/commands/owned/command.md": "OWNED_BODY\n",
            "skills/fixture/header.toml": header + 'name = "fixture"\n',
            "skills/fixture/SKILL.md": "SKILL_BODY\n",
        }
        composer = f"import {ASSISTANTS}/compose.nix {{ inherit lib; basePath = fixture; }}"
        expression = f'''let composer = {composer}; in {{
          commands = composer.composeCommands "claude";
          agents = composer.composeAgents "claude";
          skill = composer.headerFor "skill" "claude" "fixture" (fixture + "/skills/fixture");
        }}'''
        result = self.evaluate(expression, files=files)
        self.assertEqual(set(result["commands"]), {"standalone", "owned"})
        self.assertIn("AGENT_BODY", result["agents"]["worker"])
        self.assertEqual(result["skill"]["name"], "fixture")
        for source in ("commands/standalone", "agents/worker/commands/owned"):
            for new, old in (("command.toml", "header.toml"), ("command.md", "prompt.md")):
                with self.subTest(source=source, missing=new):
                    legacy = dict(files)
                    legacy[f"{source}/{old}"] = legacy.pop(f"{source}/{new}")
                    error = self.evaluate(expression, files=legacy, success=False)
                    self.assertIn(new, error)
        duplicate = dict(files)
        duplicate["commands/owned/command.toml"] = header
        duplicate["commands/owned/command.md"] = "DUPLICATE\n"
        error = self.evaluate(expression, files=duplicate, success=False)
        self.assertIn("collision", error)
        self.assertIn("owned", error)
        for source in ("commands/standalone", "agents/worker/commands/owned"):
            with self.subTest(secret_source=source):
                secret = dict(files)
                secret[f"{source}/command.sops"] = "fixture-secret\n"
                error = self.evaluate(expression, files=secret, success=False)
                self.assertIn("both command.sops and command.md", error)

    def test_repository_command_pairs_keep_agent_and_skill_names(self):
        directories = list((ASSISTANTS / "commands").iterdir())
        directories += list(ASSISTANTS.glob("agents/*/commands/*"))
        names = []
        for directory in directories:
            if not directory.is_dir():
                continue
            names.append(directory.name)
            with self.subTest(directory=directory):
                self.assertTrue((directory / "command.toml").is_file())
                self.assertTrue((directory / "command.md").is_file() or (directory / "command.sops").is_file())
                self.assertFalse((directory / "prompt.md").exists())
                self.assertFalse((directory / "header.toml").exists())
        self.assertEqual(len(names), len(set(names)))
        for directory in (ASSISTANTS / "agents").iterdir():
            if directory.is_dir():
                self.assertTrue((directory / "prompt.md").is_file())
                self.assertTrue((directory / "header.toml").is_file())
                self.assertFalse((directory / "command.toml").exists())
        for body in (ASSISTANTS / "skills").rglob("SKILL.md"):
            self.assertTrue(body.with_name("header.toml").is_file(), body)
            self.assertFalse(body.with_name("command.toml").exists(), body)

    def test_command_metadata_errors_name_the_command_file(self):
        error = self.evaluate(
            "m.readCommandHeader fixture",
            files={"command.toml": "[unknown]\nvalue = true\n"},
            success=False,
        )
        self.assertIn("/command.toml: Unknown tables", error)

    def test_nested_values_and_false_survive_both_output_formats(self):
        header = """
[common]
name = "fixture"
description = "A description: with # punctuation and \\"quotes\\"."
[pi]
skills = false
maxDepth = 0
[pi.extension]
enabled = false
labels = ["first", "second"]
"""
        result = self.evaluate(
            'let p = m.project "agent" "pi" "fixture" h; in '
            "{ yaml = m.renderYaml p; toml = m.renderToml p; }",
            header,
        )
        expected = {
            "name": "fixture",
            "description": 'A description: with # punctuation and "quotes".',
            "prompt_mode": "replace",
            "extensions": True,
            "exclude_extensions": "pi-cc-header",
            "isolated": False,
            "skills": False,
            "maxDepth": 0,
            "extension": {"enabled": False, "labels": ["first", "second"]},
        }
        self.assertEqual(yaml.safe_load(result["yaml"]), expected)
        self.assertEqual(tomllib.loads(result["toml"]), expected)

    def test_only_selected_provider_fields_reach_frontmatter(self):
        header = """
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
"""
        result = self.evaluate(
            '{ claude = m.project "command" "claude" "task" h; '
            'pi = m.project "command" "pi" "task" h; '
            'codex = m.project "command" "codex" "task" h; }',
            header,
        )
        self.assertEqual(
            result["claude"],
            {
                "description": "Task description",
                "argument-hint": "<path>",
                "context": "fork",
            },
        )
        self.assertEqual(
            result["pi"],
            {
                "description": "Task description",
                "argument-hint": "<path>",
                "extension": "pi-only",
            },
        )
        self.assertEqual(result["codex"], {"description": "Task description"})

    def test_pi_defaults_and_explicit_overrides(self):
        result = self.evaluate(
            '{ defaults = m.project "agent" "pi" "worker" {}; '
            'overrides = m.project "agent" "pi" "worker" h; }',
            """
[pi]
prompt_mode = "append"
inherit_context = true
skills = false
""",
        )
        self.assertEqual(
            result["defaults"],
            {
                "name": "worker",
                "prompt_mode": "replace",
                "extensions": True,
                "exclude_extensions": "pi-cc-header",
                "isolated": False,
                "skills": True,
            },
        )
        self.assertEqual(
            result["overrides"],
            {
                "name": "worker",
                "prompt_mode": "append",
                "extensions": True,
                "exclude_extensions": "pi-cc-header",
                "isolated": False,
                "inherit_context": True,
                "skills": False,
            },
        )

    def test_header_exclusion_is_only_a_pi_agent_default(self):
        for provider in ("claude", "opencode", "codex", "pi"):
            for kind in ("agent", "command", "skill", "instructions"):
                with self.subTest(provider=provider, kind=kind):
                    result = self.evaluate(
                        f'm.project "{kind}" "{provider}" "fixture" h',
                        '[common]\nname = "fixture"\ndescription = "Fixture."\n',
                    )
                    if provider == "pi" and kind == "agent":
                        self.assertEqual(result["exclude_extensions"], "pi-cc-header")
                    else:
                        self.assertNotIn("exclude_extensions", result)

    def test_native_model_settings_cannot_compete_with_routing(self):
        for provider in ("common", "claude", "opencode", "codex", "pi"):
            with self.subTest(provider=provider):
                error = self.evaluate(
                    "h",
                    f'[{provider}]\nmodel = "native-model"\n'
                    '[routing.codex]\nmodel = "route-model"\n',
                    success=False,
                )
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
        for value in ('"false"', "0", "[]", "{}"):
            with self.subTest(value=value):
                error = self.evaluate(
                    "h", f"[compose.pi]\nspawn-agent = {value}\n", success=False
                )
                self.assertIn("Composition switches must be booleans.", error)

    def test_root_control_requires_a_boolean_and_overrides_spawn(self):
        for value in ('"true"', "0", "[]", "{}"):
            with self.subTest(value=value):
                self.evaluate("h", f"[compose]\nroot = {value}\n", success=False)
        for value in (None, "false", "true"):
            with self.subTest(value=value):
                header = '[compose]\nagent = "worker"\n'
                if value is not None:
                    header += f"root = {value}\n"
                header += "[compose.codex]\nspawn-agent = true\n"
                result = self.evaluate(
                    'm.commandDispatch { worker = true; } "fixture" null h', header
                )
                self.assertEqual(result["spawn"], value != "true")
        self.evaluate(
            'm.commandDispatch { worker = true; } "fixture" "worker" h',
            '[compose]\nroot = true\n[routing.codex]\nmodel = "pinned"\n',
            success=False,
        )

    def test_root_commands_override_native_bindings_and_preserve_the_task(self):
        body = "Keep caller context. Delegate independent checks for $ARGUMENTS."
        files = {"agents/worker/prompt.md": "PERSONA_SENTINEL\n"}
        for selection in ("scoped", "bound", "unbound"):
            for mode in ("absent", "false", "true"):
                name = f"{selection}-{mode}"
                directory = (
                    f"agents/worker/commands/{name}"
                    if selection == "scoped"
                    else f"commands/{name}"
                )
                header = '[common]\ndescription = "Check caller context."\n[compose]\n'
                if selection == "bound":
                    header += 'agent = "worker"\n'
                if mode != "absent":
                    header += f"root = {mode}\n"
                header += (
                    "[compose.claude]\nuse-task = true\n"
                    "[compose.pi]\nspawn-agent = true\n"
                    "[compose.codex]\nspawn-agent = true\n"
                    '[claude]\ncontext = "fork"\nagent = "worker"\n'
                    '[opencode]\nagent = "worker"\nsubtask = true\n'
                )
                files[directory + "/command.toml"] = header
                files[directory + "/command.md"] = body + "\n"
        result = self.evaluate(
            """let
          composer = import """
            + str(ASSISTANTS)
            + """/compose.nix {
            inherit lib; basePath = fixture;
          };
        in lib.genAttrs [ "claude" "opencode" "pi" "codex" ] composer.composeCommands""",
            files=files,
        )
        for platform, commands in result.items():
            for selection in ("scoped", "bound", "unbound"):
                with self.subTest(platform=platform, selection=selection):
                    self.assertEqual(
                        commands[selection + "-absent"], commands[selection + "-false"]
                    )
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
                            self.assertIn(
                                "Use the Task tool to launch the worker agent", leaf
                            )
                        elif platform == "pi":
                            self.assertIn(
                                'Use the Agent tool with `subagent_type: "worker"`',
                                leaf,
                            )
                        elif platform == "opencode":
                            self.assertEqual(
                                yaml.safe_load(leaf.split("---", 2)[1])["agent"],
                                "worker",
                            )

    def test_real_command_inventory_keeps_root_orchestrators_and_leaf_specialists(self):
        result = self.evaluate("""lib.listToAttrs (map (entry: {
          name = entry.name;
          value = let header = c.commandMetadata entry.agentName entry.name; in {
            root = header.compose.root or false;
            dispatch = m.commandDispatch c.agentDirs entry.name entry.agentName header;
            rendered = lib.genAttrs [ "claude" "opencode" "pi" ]
              (platform: c.composeCommandFromPrompt platform entry.agentName entry.name
                "INVENTORY_TASK_SENTINEL");
            policy = m.commandPolicy header;
          };
        }) c.commandSources)""")
        for name in (
            "address-code-review",
            "implement-task",
            "implement-plan",
            "finish-pr",
            "babysit-pr",
            "handover-fresh",
            "handover-fork",
            "review-code-mine",
            "project-tests-review",
            "gather-review-data",
            "audit-code-security",
        ):
            with self.subTest(root_command=name):
                self.assertTrue(result[name]["root"])
        self.assertFalse(result["create-agents-md"]["root"])
        for name, command in result.items():
            with self.subTest(command=name):
                self.assertIs(
                    command["policy"]["policy"]["allow_implicit_invocation"], False
                )
                self.assertNotIn("route", command["dispatch"])
                if command["root"]:
                    self.assertFalse(command["dispatch"]["spawn"])
                    self.assertIsNone(command["dispatch"]["role"])
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
                            child = (
                                task
                                if platform == "opencode"
                                else task.split("\n## Task\n", 1)[1]
                            )
                            self.assertIn("You are a leaf worker.", child)
                            self.assertTrue(
                                child.rstrip().endswith("INVENTORY_TASK_SENTINEL")
                            )
                            self.assertNotIn("Use the Task tool to launch", child)
                            self.assertNotIn("Use the Agent tool with", child)

    def test_git_commands_are_unique_garfield_leaves_with_context_handover(self):
        result = self.evaluate("""{
          sources = c.commandSources;
          commands = lib.genAttrs [ "claude" "opencode" "pi" ] c.composeCommands;
          metadata = lib.genAttrs [ "make-commit" "make-pr" ]
            (name: c.commandMetadata "garfield" name);
          skills = lib.genAttrs [ "claude" "codex" "opencode" "pi" ]
            (platform: (c.composeSkillsFor platform).delegate-task.content);
        }""")
        for name in ("make-commit", "make-pr"):
            with self.subTest(command=name):
                sources = [s for s in result["sources"] if s["name"] == name]
                self.assertEqual(len(sources), 1)
                self.assertEqual(sources[0]["agentName"], "garfield")
                self.assertFalse((ASSISTANTS / "commands" / name).exists())
                metadata = result["metadata"][name]
                self.assertNotIn("root", metadata["compose"])
                self.assertNotIn("routing", metadata)
                self.assertEqual(metadata["common"]["argument-hint"], "[context]")
                for platform, commands in result["commands"].items():
                    rendered = commands[name]
                    native = yaml.safe_load(rendered.split("---", 2)[1])
                    self.assertEqual(native["argument-hint"], "[context]")
                    self.assertNotIn("model", native)
                    task = rendered.split("---", 2)[2]
                    if platform == "opencode":
                        self.assertEqual(native["agent"], "garfield")
                        self.assertNotIn("Before launch, add", task)
                        child = task
                    else:
                        launch, child = task.split("\n## Task\n", 1)
                        self.assertIn("Before launch, add the known intent", launch)
                        self.assertIn("exclusions, and validation evidence", launch)
                        self.assertIn("explicit mutation authority", launch)
                        self.assertIn(
                            "not the general conversation or transcript", launch
                        )
                        self.assertIn("Launch only one Garfield worker", launch)
                    self.assertIn("You are a leaf worker.", child)
                    self.assertIn("accompanying invocation text", child)
                    self.assertIn(
                        "require explicit context or clarify missing decisions", child
                    )
                    self.assertIn("stop before dependent writes", child)
                    self.assertNotIn("Use the Task tool to launch", child)
                    self.assertNotIn("Use the Agent tool with", child)
        for skill in result["skills"].values():
            self.assertIn("Directly invoked `make-commit` and `make-pr`", skill)
            self.assertIn("one garfield leaf worker", skill)
            self.assertIn("The root retains index ownership", skill)
            self.assertIn("Garfield never launches monitoring", skill)
            self.assertNotIn("staged diff is large", skill)

    def test_git_command_collisions_are_rejected_for_every_client(self):
        for platform in ("claude", "opencode", "pi", "codex"):
            for name in ("make-commit", "make-pr"):
                with self.subTest(platform=platform, command=name):
                    error = self.evaluate(
                        f'''c.assertNoCommandCollisions {{
                          context = "{platform} commands";
                          sources = c.commandSources ++ [ {{
                            name = "{name}"; source = "duplicate source";
                          }} ];
                        }}''',
                        success=False,
                    )
                    self.assertIn(f"{platform} commands name collision", error)
                    self.assertIn(name, error)
                    self.assertIn("duplicate source", error)

    def test_git_bodies_preserve_safety_and_root_inline_reuse(self):
        garfield = ASSISTANTS / "agents/garfield"
        commit = (garfield / "commands/make-commit/command.md").read_text()
        pr = (garfield / "commands/make-pr/command.md").read_text()
        for text in (
            "Keep all already-staged content included",
            "Do not reset, unstage, restore, or edit staged content",
            "git add -- <path>",
            "git diff --staged --check",
            "It never pushes",
            "without its generated launch wrapper",
        ):
            self.assertIn(text, commit)
        self.assertNotIn("One exception", commit)
        for text in (
            "Read its body directly",
            "`draft-pr-message`",
            "supplied parent evidence supports for the committed changes",
            "A delegated task must restate push, PR creation, review metadata, and tracker mutation authority",
            "Never report success from `gh pr create` alone",
            "Watch handover: ROOT can offer babysit-pr",
            "Never invoke `babysit-pr`",
        ):
            self.assertIn(text, pr)
        self.assertNotIn("invoke the provider-specific command", pr)
        root_paths = {
            "agents/donatello/commands/address-code-review": (
                "without generated launch wrappers",
                "Follow the `make-commit` body and its direct draft phase",
                "Commit from this context only",
            ),
            "commands/implement-task": (
                "Read and follow the `draft-commit-message` body in this context",
                "Commit from this context so workers never contend for the index",
                "Claiming an issue, writing its durable record, staging, and committing happen in this context only",
            ),
        }
        for path, instructions in root_paths.items():
            header = tomllib.loads((ASSISTANTS / path / "command.toml").read_text())
            self.assertTrue(header["compose"]["root"])
            body = (ASSISTANTS / path / "command.md").read_text()
            for instruction in instructions:
                self.assertIn(instruction, body)
            self.assertNotIn("garfield", body)

    def test_pi_command_spawn_control_preserves_body_and_other_providers(self):
        body = (
            "Delegate independent checks.\n\nReview $ARGUMENTS and return the report."
        )
        for selection in ("scoped", "standalone"):
            with self.subTest(selection=selection):
                files = {"agents/worker/prompt.md": "Check the task.\n"}
                for switch in ("absent", "true", "false"):
                    directory = (
                        f"agents/worker/commands/{switch}"
                        if selection == "scoped"
                        else f"commands/{switch}"
                    )
                    header = '[common]\ndescription = "Check a task."\n'
                    if selection == "standalone":
                        header += '[compose]\nagent = "worker"\n'
                    if switch != "absent":
                        header += f"[compose.pi]\nspawn-agent = {switch}\n"
                    files[directory + "/command.toml"] = header
                    files[directory + "/command.md"] = body + "\n"
                result = self.evaluate(
                    """let
                  fixtureComposer = import """
                    + str(ASSISTANTS)
                    + """/compose.nix {
                    inherit lib;
                    basePath = fixture;
                  };
                in lib.genAttrs [ "pi" "claude" "opencode" "codex" ]
                  fixtureComposer.composeCommands""",
                    files=files,
                )
                for platform, commands in result.items():
                    with self.subTest(platform=platform):
                        self.assertEqual(commands["absent"], commands["true"])
                        for rendered in commands.values():
                            frontmatter = yaml.safe_load(rendered.split("---", 2)[1])
                            self.assertNotIn("compose", frontmatter)
                            self.assertNotIn("spawn-agent", frontmatter)
                            self.assertTrue(rendered.endswith(body + "\n"))
                        if platform == "pi":
                            self.assertEqual(
                                commands["false"].split("---", 2)[2],
                                "\n\n" + body + "\n",
                            )
                            self.assertIn(
                                'Use the Agent tool with `subagent_type: "worker"`',
                                commands["true"],
                            )
                            self.assertIn(
                                "Set `inherit_context` to `false`", commands["true"]
                            )
                        else:
                            self.assertEqual(commands["absent"], commands["false"])

    def test_opencode_options_cannot_bypass_routing(self):
        error = self.evaluate(
            "h",
            """
[opencode.options]
reasoningEffort = "low"
""",
            success=False,
        )
        self.assertIn("Model settings belong exclusively in routing tables.", error)
        result = self.evaluate(
            'm.project "agent" "opencode" "fixture" h',
            """
[opencode.options]
textVerbosity = "low"
store = false
[opencode.metadata]
model = "A descriptive label"
[routing.opencode]
reasoningEffort = "high"
""",
        )
        self.assertEqual(
            result,
            {
                "options": {"textVerbosity": "low", "store": False},
                "metadata": {"model": "A descriptive label"},
                "reasoningEffort": "high",
            },
        )

    def test_only_child_dispatch_gets_the_leaf_contract(self):
        body = "Review $ARGUMENTS. Return the report."
        files = {"agents/worker/prompt.md": "PERSONA_SENTINEL\n"}
        for name, controls in {
            "default": "",
            "inline": (
                "[compose.claude]\nuse-task = false\n"
                "[compose.pi]\nspawn-agent = false\n"
                "[opencode]\nsubtask = false\n"
            ),
        }.items():
            directory = f"agents/worker/commands/{name}"
            files[directory + "/command.toml"] = (
                '[common]\ndescription = "Check a task."\n' + controls
            )
            files[directory + "/command.md"] = body
        result = self.evaluate(
            """let composer = import """
            + str(ASSISTANTS)
            + """/compose.nix {
          inherit lib; basePath = fixture;
        }; in lib.genAttrs [ "claude" "opencode" "pi" ] composer.composeCommands""",
            files=files,
        )
        for platform, commands in result.items():
            with self.subTest(platform=platform):
                inline = commands["inline"].split("---", 2)[2].strip()
                self.assertEqual(
                    inline, ("@worker\n\n" if platform == "claude" else "") + body
                )
                delegated = commands["default"].split("---", 2)[2]
                child = (
                    delegated
                    if platform == "opencode"
                    else delegated.split("\n## Task\n", 1)[1]
                )
                self.assertIn("You are a leaf worker.", child)
                self.assertTrue(child.rstrip().endswith(body))

    def test_native_specialists_keep_routes_and_tools_without_nested_dispatch(self):
        result = self.evaluate("""lib.genAttrs [ "claude" "opencode" "pi" ]
          (platform: lib.mapAttrs (name: _: c.composeAgentFromPrompt platform name
            "PERSONA_SENTINEL") c.agentDirs)""")
        for platform, agents in result.items():
            for name, rendered in agents.items():
                with self.subTest(platform=platform, agent=name):
                    native = yaml.safe_load(rendered.split("---", 2)[1])
                    body = rendered.split("---", 2)[2].strip()
                    if platform == "pi":
                        self.assertTrue(body.startswith("PERSONA_SENTINEL\n"))
                        self.assertIn("You are a leaf worker.", body)
                        self.assertIn("## Shared safety rules", body)
                        self.assertIn("## Sentences", body)
                    else:
                        self.assertEqual(body, "PERSONA_SENTINEL")
                        self.assertNotIn("exclude_extensions", native)
                    original = tomllib.loads(
                        (ASSISTANTS / "agents" / name / "header.toml").read_text()
                    )
                    for key, value in (
                        original.get("routing", {}).get(platform, {}).items()
                    ):
                        if platform != "pi" and key != "providers":
                            self.assertEqual(native[key], value)
                    self.assertNotIn("providers", native)
                    if platform == "claude":
                        self.assertIn("Agent", native["disallowedTools"])
                    elif platform == "opencode":
                        self.assertEqual(native["mode"], "subagent")
                        self.assertEqual(native["permission"]["task"], "deny")
                        self.assertEqual(native["permission"]["question"], "allow")
                    else:
                        self.assertEqual(native["prompt_mode"], "replace")
                        self.assertTrue(native["skills"])
                        self.assertTrue(native["extensions"])
                        self.assertEqual(native["exclude_extensions"], "pi-cc-header")
                        self.assertFalse(native["isolated"])
                        self.assertNotIn("allowed_subagents", native)
                        self.assertNotIn("inherit_context", native)
                        self.assertNotIn("inheritSkills", native)
                        self.assertNotIn("systemPromptMode", native)

    def project_runtime(self, client, projection):
        # Evaluate the original let bindings without packages, activation or secrets.
        source = (ASSISTANTS.parent / client / "default.nix").read_text()
        source = re.sub(
            r"(?<=import )\.\./[\w./-]+",
            lambda match: str((ASSISTANTS.parent / client / match[0]).resolve()),
            source,
        )
        bindings, module = source.rsplit("\nin\n", 1)
        projected = bindings + "\n  runtimeModule = " + module + ";\nin " + projection
        return self.evaluate(
            """let
          runtime = import (fixture + "/runtime-projection.nix") {
            inherit lib;
            pkgs = import """
            + self.nixpkgs
            + """ { system = builtins.currentSystem; };
            config.noughty.host.tags = [];
            config.noughty.host.is.linux = false;
            inputs = {}; noughtyLib = {}; catppuccinPalette = {};
          };
        in runtime""",
            files={"runtime-projection.nix": projected},
        )

    def test_runtime_depth_keeps_root_dispatch_available(self):
        codex = self.project_runtime(
            "codex",
            """{
          inherit (codexSettings) agents;
          inherit (codexSettings.features) multi_agent multi_agent_v2;
        }""",
        )
        self.assertEqual(codex["agents"]["max_depth"], 1)
        self.assertEqual(codex["agents"]["max_concurrent_threads_per_session"], 12)
        self.assertNotIn("max_threads", codex["agents"])
        self.assertIs(codex["multi_agent"], True)
        self.assertIs(codex["multi_agent_v2"], False)
        claude = self.project_runtime(
            "claude-code",
            """{
          environment = claudeEnvironment;
          teammateMode = (lib.evalModules {
            modules = [{ options.teammateMode = lib.mkOption { type = lib.types.str; }; }]
              ++ map (settings: lib.filterAttrs (name: _: name == "teammateMode") settings)
                runtimeModule.config.content.programs.claude-code.settings.contents;
          }).config.teammateMode;
        }""",
        )
        self.assertEqual(
            claude["environment"]["CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH"], "1"
        )
        self.assertEqual(
            claude["environment"]["CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS"], "12"
        )
        self.assertEqual(
            claude["environment"]["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"], "1"
        )
        self.assertEqual(claude["teammateMode"], "in-process")

    def test_pi_uses_native_subagent_settings(self):
        result = self.project_runtime(
            "pi", "{ inherit piSubagentsSource piSubagentsConfig; }"
        )
        self.assertEqual(
            result["piSubagentsSource"], "npm:@tintinweb/pi-subagents@0.19.0"
        )
        settings = result["piSubagentsConfig"]
        self.assertEqual(settings["maxSubagentDepth"], 1)
        self.assertEqual(settings["maxConcurrent"], 12)
        self.assertEqual(settings["maxConcurrentForeground"], 12)
        self.assertTrue(settings["workflowsEnabled"])
        self.assertTrue(settings["disableDefaultAgents"])
        self.assertTrue(settings["strictAgentFiles"])
        self.assertFalse(settings["worktreeIsolation"])
        self.assertFalse(settings["schedulingEnabled"])
        self.assertEqual(settings["fallbackSubagent"], "none")
        self.assertNotIn("asyncByDefault", settings)
        self.assertEqual(settings["defaultMaxTurns"], 50)
        self.assertEqual(settings["graceTurns"], 5)
        self.assertEqual(settings["agentMentions"], "off")

    def test_pi_delegation_guidance_keeps_separate_limits_and_selective_verification(
        self,
    ):
        skills = self.evaluate(
            'let skills = c.composeSkillsFor "pi"; in { '
            "delegate = skills.delegate-task.content; "
            "review = skills.review-code.content; }"
        )
        for instruction in (
            "twelve active calls",
            "native runtime retains its 1000-call limit per workflow",
            "separate limits of twelve",
            "Native CPU-based capacity can lower workflow concurrency",
            "not nested `workflow()` calls",
            "not one global aggregate cap",
            "launch no agents through sub-agent or task tools",
            "follow `review-code` for selective verification",
            "empty findings array for clean results, never `null`",
        ):
            self.assertIn(instruction, skills["delegate"])
        for instruction in (
            "Deduplicate overlapping findings before verification",
            "Do not launch verifiers for reports with no actionable findings",
            "concrete unresolved question or an explicit user request",
            "resume its existing context",
        ):
            self.assertIn(instruction, skills["review"])

    def test_shared_root_limit_and_leaf_rule_reach_every_client(self):
        instructions = self.evaluate(
            'lib.genAttrs [ "claude" "codex" "opencode" "pi" ] c.composeInstructions'
        )
        for platform, body in instructions.items():
            with self.subTest(platform=platform):
                self.assertIn(
                    "at most twelve workers active across all delegation tools and workflows combined",
                    body,
                )
                self.assertIn("wait for capacity before another launch", body)
                self.assertIn(
                    "Never launch another agent through a sub-agent or task tool from a worker",
                    body,
                )
                self.assertIn(
                    "Loading a command or skill never changes a worker into an orchestrator",
                    body,
                )

    def test_claude_hook_blocks_workers_but_keeps_root_and_messages(self):
        groups = self.project_runtime(
            "claude-code", "claudeLeafHooks.PreToolUse.content"
        )
        self.assertEqual(len(groups), 1)
        group = groups[0]
        for tool in ("Agent", "Task"):
            self.assertIsNotNone(re.fullmatch(group["matcher"], tool))
        for tool in ("SendMessage", "Read", "Bash", "TaskOutput", "TaskStop"):
            self.assertIsNone(re.fullmatch(group["matcher"], tool))
        command = shlex.split(group["hooks"][0]["command"])
        for identity in (
            {},
            {"agent_id": None},
            {"agent_id": ""},
            {"agent_id": "worker-123"},
            {"agent_id": "reviewer@team"},
        ):
            with self.subTest(identity=identity):
                payload = {
                    "hook_event_name": "PreToolUse",
                    "tool_name": "Agent",
                    "tool_input": {"prompt": "Delegate another task."},
                    **identity,
                }
                result = subprocess.run(
                    command, input=json.dumps(payload), capture_output=True, text=True
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                response = json.loads(result.stdout)
                if identity.get("agent_id"):
                    self.assertEqual(
                        response["hookSpecificOutput"]["permissionDecision"], "deny"
                    )
                    self.assertEqual(
                        response["hookSpecificOutput"]["hookEventName"], "PreToolUse"
                    )
                else:
                    self.assertEqual(response, {})

    def test_commands_and_skills_reject_non_agent_routing(self):
        routes = {
            "claude": '[routing.claude]\nmodel = "sonnet"\n',
            "codex": '[routing.codex]\nmodel = "test-model"\n',
            "pi": '[routing.pi.openai-codex]\nmodel = "test-model"\n',
        }
        for kind in ("command", "skill"):
            for provider, route in routes.items():
                with self.subTest(kind=kind, provider=provider):
                    error = self.evaluate(
                        f'm.project "{kind}" "{provider}" "fixture" h',
                        '[common]\nname = "fixture"\ndescription = "Fixture."\n'
                        + route,
                        success=False,
                    )
                    self.assertIn(
                        f"Unsupported {provider} routing for {kind} fixture.", error
                    )

    def test_empty_command_and_skill_routes_remain_valid(self):
        for kind in ("command", "skill"):
            for provider in ("claude", "codex", "pi", "opencode"):
                with self.subTest(kind=kind, provider=provider):
                    result = self.evaluate(
                        f'm.project "{kind}" "{provider}" "fixture" h',
                        '[common]\nname = "fixture"\ndescription = "Fixture."\n'
                        f"[routing.{provider}]\n",
                    )
                    self.assertEqual(result["description"], "Fixture.")
                    self.assertNotIn("model", result)

    def test_opencode_command_routing_rules_remain_unchanged(self):
        result = self.evaluate(
            'm.project "command" "opencode" "fixture" h',
            '[routing.opencode]\nmodel = "test-model"\n',
        )
        self.assertEqual(result, {"model": "test-model"})
        for kind, route in (
            ("command", '[routing.opencode]\nreasoningEffort = "high"\n'),
            ("skill", '[routing.opencode]\nmodel = "test-model"\n'),
        ):
            with self.subTest(kind=kind):
                error = self.evaluate(
                    f'm.project "{kind}" "opencode" "fixture" h',
                    '[common]\nname = "fixture"\ndescription = "Fixture."\n' + route,
                    success=False,
                )
                self.assertIn(f"Unsupported opencode routing for {kind}", error)

    def test_opencode_provider_routes_are_agent_only_and_not_native_fields(self):
        header = '[routing.opencode.providers.openai]\nmodel = "gpt-5.6-terra"\n'
        result = self.evaluate(
            'lib.genAttrs [ "claude" "codex" "opencode" "pi" ] '
            '(platform: m.project "agent" platform "fixture" h)',
            header,
        )
        for native in result.values():
            self.assertNotIn("providers", native)
            self.assertNotIn("model", native)
        for kind in ("command", "skill", "instructions"):
            with self.subTest(kind=kind):
                self.evaluate(
                    f'm.project "{kind}" "opencode" "fixture" h', header, success=False
                )
        self.assertEqual(
            self.evaluate('c.extractOpenCodeProviderModels "garfield"'),
            {"openai": "gpt-5.6-terra", "anthropic": "claude-sonnet-5"},
        )

    def test_invalid_opencode_provider_routes_fail_schema_validation(self):
        for header in (
            '[routing.opencode.providers.openai]\nmodel = ""\n',
            '[routing.opencode.providers.openai]\nmodel = "anthropic/claude-sonnet-5"\n',
            '[routing.opencode.providers.openai]\nmodel = "with space"\n',
            "[routing.opencode.providers.openai]\nmodel = 42\n",
            '[routing.opencode.providers.openai]\nthinking = "high"\n',
            '[routing.opencode.providers.openai]\nmodel = "ok"\nvariant = "high"\n',
            '[routing.opencode.providers."bad/provider"]\nmodel = "ok"\n',
            '[routing.opencode]\nproviders = "openai"\n',
            '[routing.opencode]\nmodel = "pin"\n[routing.opencode.providers.openai]\nmodel = "ok"\n',
        ):
            with self.subTest(header=header):
                self.evaluate("h", header, success=False)

    def test_migrated_garfield_routes_preserve_model_pins(self):
        result = self.evaluate(
            '{ models = c.extractAgentProviderModels "garfield"; '
            'thinking = c.extractAgentProviderThinking "garfield"; }'
        )
        self.assertEqual(
            result,
            {
                "models": {
                    "anthropic": "claude-sonnet-5",
                    "google": "gemini-3-flash",
                    "openai-codex": "gpt-5.6-terra",
                },
                "thinking": {"openai-codex": "medium"},
            },
        )

    def test_codex_dispatch_rejects_routing_without_projection(self):
        for route in (
            '{ model = "command-model"; }',
            '{ model_reasoning_effort = "high"; }',
        ):
            with self.subTest(route=route):
                error = self.evaluate(
                    'm.commandDispatch { worker = true; } "review" "worker" '
                    f"{{ routing.codex = {route}; }}",
                    success=False,
                )
                self.assertIn("Unsupported codex routing for command review.", error)
        result = self.evaluate(
            'm.commandDispatch { worker = true; } "inspect" "worker" {}'
        )
        self.assertEqual(result["role"], "worker")
        self.assertNotIn("route", result)

    def test_standalone_codex_commands_remain_inline_unless_an_agent_is_selected(self):
        result = self.evaluate(
            """{
          inline = m.commandDispatch { worker = true; } "plain" null {};
          delegated = m.commandDispatch { worker = true; } "review" null h;
        }""",
            """
[compose]
agent = "worker"
""",
        )
        self.assertIsNone(result["inline"]["selectedAgent"])
        self.assertIsNone(result["inline"]["role"])
        self.assertEqual(result["delegated"]["selectedAgent"], "worker")
        self.assertEqual(result["delegated"]["role"], "worker")
        self.assertTrue(result["delegated"]["spawn"])

    def test_codex_inline_routes_and_unknown_agents_fail(self):
        for agent, header in (
            ("null", '[routing.codex]\nmodel = "test-model"\n'),
            (
                '"worker"',
                "[compose.codex]\nspawn-agent = false\n"
                '[routing.codex]\nmodel = "test-model"\n',
            ),
            ('"worker"', '[compose]\nagent = "missing"\n'),
        ):
            with self.subTest(agent=agent, header=header):
                self.evaluate(
                    f'm.commandDispatch {{ worker = true; }} "review" {agent} h',
                    header,
                    success=False,
                )

    def test_codex_commands_cannot_enable_implicit_invocation(self):
        result = self.evaluate(
            "m.commandPolicy h",
            """
[codex]
allow-implicit-invocation = false
""",
        )
        self.assertFalse(result["policy"]["allow_implicit_invocation"])
        self.assertFalse(
            self.evaluate("m.commandPolicy {}")["policy"]["allow_implicit_invocation"]
        )
        for value in ("true", '"false"'):
            with self.subTest(value=value):
                self.evaluate(
                    "m.commandPolicy h",
                    f"[codex]\nallow-implicit-invocation = {value}\n",
                    success=False,
                )

    def test_codex_skill_companion_fields_do_not_leak_into_frontmatter(self):
        result = self.evaluate(
            """{
          frontmatter = m.project "skill" "codex" "fixture" h;
          companion = m.renderYaml (m.skillCompanion fixture);
        }""",
            """
[common]
name = "fixture"
description = "A directly invoked skill."
[codex.interface]
display_name = "Fixture skill"
[codex.policy]
allow_implicit_invocation = false
[codex.dependencies]
tools = [{ type = "mcp", value = "fixture-service" }]
""",
        )
        self.assertEqual(
            result["frontmatter"],
            {
                "name": "fixture",
                "description": "A directly invoked skill.",
            },
        )
        self.assertEqual(
            yaml.safe_load(result["companion"]),
            {
                "interface": {"display_name": "Fixture skill"},
                "policy": {"allow_implicit_invocation": False},
                "dependencies": {
                    "tools": [{"type": "mcp", "value": "fixture-service"}]
                },
            },
        )

    def test_codex_companion_is_deployable_for_root_and_nested_skills(self):
        header = """
[common]
name = "NAME"
description = "A directly invoked skill."
[codex.policy]
allow_implicit_invocation = false
"""
        files = {
            "styles/house-style/house-style.md": "Use plain language.\n",
            "skills/communication-rules/SKILL.md": "Use plain language.\n",
            "skills/fixture/header.toml": header.replace("NAME", "fixture"),
            "skills/fixture/SKILL.md": "Run the fixture.\n",
            "skills/fixture/references/nested/header.toml": header.replace(
                "NAME", "nested"
            ),
            "skills/fixture/references/nested/SKILL.md": "Run the nested fixture.\n",
        }
        result = self.evaluate(
            """let
          fixtureComposer = import """
            + str(ASSISTANTS)
            + """/compose.nix {
            inherit lib;
            basePath = fixture;
            pkgs = {
              writeText = name: text: text;
              linkFarm = name: entries: { overrideAttrs = _: entries; };
            };
          };
          skill = (fixtureComposer.composeSkillsFor "codex").fixture;
        in { inherit (skill) content extras path; }""",
            files=files,
        )
        self.assertEqual(result["extras"]["agents"], "directory")
        self.assertEqual(result["extras"]["references"], "directory")
        self.assertNotIn("header.toml", result["extras"])
        entries = {entry["name"]: entry["path"] for entry in result["path"]}
        for prefix in ("", "references/nested/"):
            with self.subTest(prefix=prefix):
                companion = yaml.safe_load(entries[prefix + "agents/openai.yaml"])
                self.assertIs(companion["policy"]["allow_implicit_invocation"], False)
                frontmatter = yaml.safe_load(
                    entries[prefix + "SKILL.md"].split("---", 2)[1]
                )
                self.assertNotIn("policy", frontmatter)
                self.assertNotIn(prefix + "header.toml", entries)


if __name__ == "__main__":
    unittest.main()
