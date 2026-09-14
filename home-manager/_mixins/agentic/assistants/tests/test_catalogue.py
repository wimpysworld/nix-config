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
        markdown = self.evaluate(self.fixture())["markdown"]
        legend = markdown.split("## Agent model defaults\n", 1)[1]
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

    def test_update_recipe_preserves_readme_on_evaluation_failure(self):
        with tempfile.TemporaryDirectory(prefix="assistant-update-") as directory:
            root = Path(directory)
            target = root / "home-manager/_mixins/agentic/assistants/commands/README.md"
            target.parent.mkdir(parents=True)
            target.write_text("Keep the existing catalogue.\n")
            fake_nix = root / "nix"
            fake_nix.write_text("#!/bin/sh\nprintf 'PARTIAL OUTPUT'\nexit 1\n")
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
                env=os.environ | {"PATH": directory + os.pathsep + os.environ["PATH"]},
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(target.read_text(), "Keep the existing catalogue.\n")
            self.assertEqual(list(target.parent.iterdir()), [target])

    def test_tracked_readme_has_no_drift(self):
        data = self.evaluate()
        self.assertEqual(
            (ASSISTANTS / "commands/README.md").read_text(), data["markdown"]
        )
        self.assertEqual(len(data["commands"]), 68)


if __name__ == "__main__":
    unittest.main()
