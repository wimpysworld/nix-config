"""Check pure catalogue generation without reading prompt bodies or secret keys."""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from typing import Any

ASSISTANTS = Path(__file__).resolve().parents[1]
REPO = ASSISTANTS.parents[3]


class CatalogueTests(unittest.TestCase):
    def evaluate(self, files=None, success=True) -> Any:
        with tempfile.TemporaryDirectory(prefix="assistant-catalogue-") as directory:
            base = Path(directory) if files is not None else ASSISTANTS
            for name, content in (files or {}).items():
                path = base / name
                path.parent.mkdir(parents=True, exist_ok=True)
                if content is None:
                    path.mkdir()
                else:
                    path.write_text(content)
            expression = f"""let
              flake = builtins.getFlake {json.dumps(str(REPO))};
              catalogue = import {ASSISTANTS}/catalogue.nix {{
                inherit (flake.inputs.nixpkgs) lib;
                basePath = builtins.toPath {json.dumps(str(base))};
              }};
            in catalogue"""
            result = subprocess.run(
                ["nix", "eval", "--impure", "--json", "--expr", expression],
                capture_output=True,
                text=True,
            )
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
            return json.loads(result.stdout)
        self.assertNotEqual(result.returncode, 0)
        return result.stderr

    def fixture(self):
        return {
            "agents/worker/header.toml": '[common]\ndescription = "Worker."\n[routing.pi.provider]\nmodel = "agent-model"\nthinking = "high"\n',
            "skills/delegate-task/header.toml": '[common]\nname = "delegate-task"\ndescription = "Delegate a task."\n',
            "commands/zulu/command.toml": '[common]\ndescription = "Pipe | newline\\n<text>"\n[compose]\nagent = "worker"\ncaller-context = true\n[compose.coordinator]\nbefore-launch = "PRIVATE_COORDINATOR"\n[routing.opencode]\nmodel = "command-model"\n',
            "commands/zulu/command.sops": "PRIVATE_KEY",
            "commands/alpha/command.toml": '[common]\ndescription = "Alpha."\n[compose]\nagent = "worker"\n',
            "commands/alpha/command.md": "PRIVATE_BODY",
        }

    def test_deterministic_safe_catalogue_and_routes(self):
        files = self.fixture()
        data = self.evaluate(files)
        self.assertEqual(data, self.evaluate(dict(reversed(list(files.items())))))
        self.assertEqual([row["name"] for row in data["commands"]], ["alpha", "zulu"])
        serialised = json.dumps(data)
        for private in ("PRIVATE_BODY", "PRIVATE_KEY", "PRIVATE_COORDINATOR"):
            self.assertNotIn(private, serialised)
        self.assertIn("Pipe \\| newline &lt;text&gt;", data["markdown"])
        zulu = data["commands"][1]
        self.assertEqual(zulu["agent"], "worker")
        self.assertEqual(zulu["visibility"], "secret")
        for client in zulu["clients"].values():
            self.assertTrue(client["behaviour"].startswith("Caller context"))
        self.assertEqual(zulu["clients"]["opencode"]["model"], "command-model")
        self.assertIsNone(zulu["clients"]["pi"]["model"])
        self.assertIn(
            {
                "agent": "worker",
                "client": "pi",
                "provider": "provider",
                "model": "agent-model",
                "effort": "high",
            },
            data["agents"],
        )

    def test_client_metadata_differences_and_absent_hints(self):
        files = self.fixture()
        files["commands/alpha/command.toml"] += (
            '[claude]\ndescription = "CLIENT_DESCRIPTION | <text>\\nnext"\n'
            'argument-hint = "CLIENT_HINT | <arg>\\nnext"\n'
            '[pi]\nargument-hint = "CLIENT_HINT | <arg>\\nnext"\n'
        )
        markdown = self.evaluate(files)["markdown"]
        table = markdown.split("## Client metadata differences\n", 1)[1].split(
            "## Agent model defaults\n", 1
        )[0]
        link = "[alpha](./alpha/command.toml)"
        self.assertIn(
            f"| {link} | claude | CLIENT_DESCRIPTION \\| &lt;text&gt; next | "
            "CLIENT_HINT \\| &lt;arg&gt; next |",
            table,
        )
        self.assertIn(
            f"| {link} | pi | Same as common | CLIENT_HINT \\| &lt;arg&gt; next |",
            table,
        )
        for client in ("opencode", "codex"):
            self.assertIn(f"| {link} | {client} | Same as common | Unset |", table)
        self.assertIn("Unset means that the argument hint is absent.", table)
        self.assertNotIn("Alpha.", table)
        self.assertNotIn("[zulu]", table)

    def test_description_override_without_hints(self):
        files = self.fixture()
        files["commands/alpha/command.toml"] += (
            '[claude]\ndescription = "CLIENT_DESCRIPTION"\n'
        )
        markdown = self.evaluate(files)["markdown"]
        table = markdown.split("## Client metadata differences\n", 1)[1].split(
            "## Agent model defaults\n", 1
        )[0]
        self.assertIn(
            "| [alpha](./alpha/command.toml) | claude | CLIENT_DESCRIPTION | Unset |",
            table,
        )
        self.assertEqual(table.count("[alpha]"), 1)
        self.assertNotIn("Alpha.", table)

    def test_opencode_provider_route_boundary_in_legend(self):
        data = self.evaluate(self.fixture())
        self.assertNotIn("## Agent model defaults", data["commandsMarkdown"])
        self.assertIn("../agents/README.md", data["commandsMarkdown"])
        legend = data["agentsMarkdown"].split("## Agent model defaults\n", 1)[1]
        self.assertIn(
            "OpenCode provider routes apply only to direct-root native task children, "
            "not direct slash-command bindings.",
            legend,
        )

    def test_invalid_metadata_and_sources_fail(self):
        for suffix in (
            '[common]\ndescription = ""\n',
            "[common]\ndescription = 2\n",
            '[common]\ndescription = "Check."\nargument-hint = false\n',
            '[common]\ndescription = "Check."\n[compose]\nagent = "missing"\n',
            '[common]\ndescription = "Check."\n[routing.pi.provider]\nmodel = "forbidden"\n',
            '[common]\ndescription = "Check."\n[codex.policy]\nallow_implicit_invocation = true\n',
        ):
            with self.subTest(header=suffix):
                files = self.fixture()
                files["commands/alpha/command.toml"] = suffix
                self.evaluate(files, success=False)
        for addition in (
            {"commands/alpha/command.sops": "PRIVATE_KEY"},
            {"agents/worker/commands/old/command.md": "OLD"},
            {
                "commands/delegate-task/command.toml": '[common]\ndescription = "Collision."\n',
                "commands/delegate-task/command.md": "BODY",
            },
        ):
            self.evaluate(self.fixture() | addition, success=False)
        files = self.fixture()
        del files["commands/alpha/command.md"]
        self.evaluate(files, success=False)

    def test_update_recipe_evaluates_all_outputs_before_replacement(self):
        for failure in (1, 2, 3, 0):
            with (
                self.subTest(failure=failure),
                tempfile.TemporaryDirectory(prefix="assistant-update-") as directory,
            ):
                root = Path(directory)
                targets = [
                    root / f"home-manager/_mixins/agentic/assistants/{kind}/README.md"
                    for kind in ("commands", "agents", "skills")
                ]
                for target in targets:
                    target.parent.mkdir(parents=True)
                    target.write_text("Keep the existing catalogue.\n")
                fake_nix = root / "nix"
                fake_nix.write_text(
                    "#!/bin/sh\n"
                    "count=$(cat count 2>/dev/null || printf 0)\n"
                    'count=$((count + 1))\nprintf "%s" "$count" > count\n'
                    'printf "OUTPUT %s\\n" "$count"\n'
                    f'if [ "$count" -eq {failure} ]; then exit 1; fi\n'
                )
                fake_nix.chmod(0o700)
                recipe = root / "justfile"
                recipe.write_text((REPO / "justfile").read_text())
                result = subprocess.run(
                    [
                        "just",
                        "--justfile",
                        str(recipe),
                        "--working-directory",
                        directory,
                        "update-assistant-catalogue",
                    ],
                    env=os.environ
                    | {
                        "PATH": directory + os.pathsep + os.environ["PATH"],
                        "BASH_ENV": "",
                    },
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(result.returncode == 0, failure == 0, result.stderr)
                self.assertEqual((root / "count").read_text(), str(failure or 3))
                for number, target in enumerate(targets, 1):
                    expected = (
                        "Keep the existing catalogue.\n"
                        if failure
                        else f"OUTPUT {number}\n"
                    )
                    self.assertEqual(target.read_text(), expected)
                    self.assertEqual(list(target.parent.iterdir()), [target])

    def test_skill_discovery_includes_conditional_secret_and_generated_sources(self):
        files = self.fixture() | {
            "skills/README.md": "PRIVATE_ROOT_CATALOGUE",
            "agents/README.md": "PRIVATE_ROOT_CATALOGUE",
            "commands/README.md": "PRIVATE_ROOT_CATALOGUE",
            "skills/gws-fixture/header.toml": '[common]\nname = "gws-fixture"\ndescription = "Workspace."\n',
            "skills/gws-fixture/SKILL.md": "PRIVATE_SKILL_BODY",
            "skills/gws-fixture/references/nested/SKILL.md": "PRIVATE_NESTED_BODY",
            "skills/gws-fixture/references/nested/header.toml": "INVALID_NESTED_HEADER",
            "skills/self-review/SKILL.sops": "PRIVATE_SKILL_KEY",
            "skills/self-review/references/context.md.sops": "PRIVATE_SUPPORT_KEY",
            "skills/empty/header.toml": "INVALID_EMPTY_HEADER",
            "skills/delegate-task/SKILL.md": "PRIVATE_IGNORED_GENERATED_BODY",
        }
        data = self.evaluate(files)
        records = {entry["name"]: entry for entry in data["skillRecords"]}
        self.assertEqual(set(records), {"delegate-task", "gws-fixture", "self-review"})
        self.assertEqual(records["delegate-task"]["sourceType"], "generated")
        self.assertIn(
            "developer user and cg host", records["gws-fixture"]["availability"]
        )
        secret = records["self-review"]
        self.assertEqual(secret["visibility"], "secret")
        self.assertIsNone(secret["description"])
        for client in secret["clients"].values():
            self.assertIsNone(client["invocationPolicy"])
            self.assertIsNone(client["controls"])
        self.assertNotIn("PRIVATE_", json.dumps(data))
        self.assertEqual(data, self.evaluate(dict(reversed(list(files.items())))))
        files["commands/gws-fixture/command.toml"] = (
            '[common]\ndescription = "Collision."\n'
        )
        files["commands/gws-fixture/command.md"] = "PRIVATE_COMMAND"
        self.evaluate(files, success=False)

    def test_catalogue_does_not_read_bodies_or_secret_markers(self):
        data = self.evaluate(
            self.fixture()
            | {
                "commands/alpha/command.md": None,
                "commands/zulu/command.sops": None,
                "skills/plain/header.toml": '[common]\nname = "plain"\ndescription = "Public skill."\n',
                "skills/plain/SKILL.md": None,
                "skills/self-review/SKILL.sops": None,
            }
        )
        self.assertEqual(len(data["skillRecords"]), 3)
        self.assertEqual(len(data["agentRecords"]), 1)
        self.assertTrue(
            all(data[f"{kind}Markdown"] for kind in ("commands", "agents", "skills"))
        )

    def test_client_projections_policies_escaping_and_no_prompt_export(self):
        files = self.fixture()
        files["agents/worker/header.toml"] += (
            '[claude]\ndescription = "Worker | <override>\\nnext"\n'
            'disallowedTools = ["Agent"]\n'
            'prompt = "PRIVATE_AGENT_PROMPT"\n'
            '[codex]\ndeveloper_instructions = "PRIVATE_INSTRUCTIONS"\n'
            '[opencode]\nmode = "subagent"\n'
            '[opencode.permission]\ntask = "deny"\n'
        )
        files["skills/delegate-task/header.toml"] += (
            "[claude]\nuser-invocable = false\ndisable-model-invocation = true\n"
            'description = "Skill | <override>\\nnext"\n'
            "[codex.policy]\nallow_implicit_invocation = false\n"
            '[codex.interface]\ndisplay_name = "PRIVATE_INTERFACE"\n'
            "[pi]\ndisable-model-invocation = true\n"
        )
        data = self.evaluate(files)
        agent = data["agentRecords"][0]
        self.assertEqual(agent["description"], "Worker.")
        self.assertEqual(
            agent["clients"]["claude"]["controls"], {"disallowedTools": ["Agent"]}
        )
        self.assertEqual(
            agent["clients"]["opencode"]["controls"]["permission"], {"task": "deny"}
        )
        self.assertEqual(agent["clients"]["codex"]["controls"], {})
        self.assertEqual(agent["clients"]["pi"]["controls"]["prompt_mode"], "replace")
        policies = data["skillRecords"][0]["clients"]
        self.assertEqual(
            policies["claude"]["invocationPolicy"],
            {
                "user-invocable": False,
                "disable-model-invocation": True,
            },
        )
        self.assertEqual(
            policies["codex"]["invocationPolicy"], {"allow_implicit_invocation": False}
        )
        self.assertEqual(
            policies["pi"]["invocationPolicy"], {"disable-model-invocation": True}
        )
        self.assertEqual(policies["opencode"]["invocationPolicy"], {})
        self.assertIn("Worker \\| &lt;override&gt; next", data["agentsMarkdown"])
        self.assertIn("Skill \\| &lt;override&gt; next", data["skillsMarkdown"])
        self.assertIn("No metadata override", data["agentsMarkdown"])
        self.assertNotIn("PRIVATE_", json.dumps(data))
        files["skills/delegate-task/header.toml"] = self.fixture()[
            "skills/delegate-task/header.toml"
        ]
        ordinary = self.evaluate(files)["skillRecords"][0]
        self.assertEqual(ordinary["clients"]["codex"]["invocationPolicy"], {})

    def test_invalid_skill_metadata_and_companion_fail(self):
        for header in (
            '[common]\nname = "wrong"\ndescription = "Skill."\n',
            '[common]\nname = "delegate-task"\ndescription = ""\n',
            '[common]\nname = "delegate-task"\ndescription = "Skill."\n[routing.pi.provider]\nmodel = "forbidden"\n',
            '[common]\nname = "delegate-task"\ndescription = "Skill."\n[codex.policy]\nallow_implicit_invocation = "false"\n',
        ):
            with self.subTest(header=header):
                files = self.fixture()
                files["skills/delegate-task/header.toml"] = header
                self.evaluate(files, success=False)
        files = self.fixture()
        files["skills/delegate-task/header.toml"] += (
            "[codex.policy]\nallow_implicit_invocation = false\n"
        )
        for source in ("agents/openai.yaml", "agents"):
            with self.subTest(source=source):
                self.evaluate(
                    files | {f"skills/delegate-task/{source}": "CONFLICT"},
                    success=False,
                )
        self.evaluate(
            self.fixture()
            | {
                "skills/both/SKILL.md": "PRIVATE_BODY",
                "skills/both/SKILL.sops": "PRIVATE_KEY",
            },
            success=False,
        )
        files = self.fixture()
        files["agents/worker/header.toml"] = '[common]\ndescription = ""\n'
        self.evaluate(files, success=False)

    def test_tracked_readme_has_no_drift(self):
        data = self.evaluate()
        self.assertEqual(data["markdown"], data["commandsMarkdown"])
        for kind in ("commands", "agents", "skills"):
            self.assertEqual(
                (ASSISTANTS / kind / "README.md").read_text(), data[f"{kind}Markdown"]
            )
        self.assertEqual(
            [row["name"] for row in data["commands"]],
            sorted(
                path.parent.name
                for path in (ASSISTANTS / "commands").glob("*/command.toml")
            ),
        )


if __name__ == "__main__":
    unittest.main()
