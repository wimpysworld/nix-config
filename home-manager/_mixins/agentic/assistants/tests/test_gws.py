"""Check the Workspace skill set without credentials or API calls."""

import json
import re
import subprocess
import unittest
from pathlib import Path

import tomllib
import yaml

ASSISTANTS = Path(__file__).resolve().parents[1]
REPO = ASSISTANTS.parents[3]
NAMES = {
    "gws-shared",
    "gws-gmail",
    "gws-gmail-forward",
    "gws-gmail-read",
    "gws-gmail-reply",
    "gws-gmail-reply-all",
    "gws-gmail-send",
    "gws-gmail-triage",
    "gws-gmail-watch",
    "gws-calendar",
    "gws-calendar-agenda",
    "gws-calendar-insert",
    "gws-drive",
    "gws-drive-upload",
    "gws-docs",
    "gws-docs-write",
    "gws-sheets",
    "gws-sheets-append",
    "gws-sheets-read",
    "gws-slides",
}


class GwsTests(unittest.TestCase):
    def test_sources_dependencies_and_licence(self):
        self.assertEqual({p.name for p in (ASSISTANTS / "skills").glob("gws-*")}, NAMES)
        for name in NAMES:
            directory = ASSISTANTS / "skills" / name
            for source in directory.rglob("*"):
                if source.is_file():
                    self.assertNotIn(b"\r", source.read_bytes(), str(source))
                    self.assertTrue(
                        all(
                            line == line.rstrip()
                            for line in source.read_text().splitlines()
                        ),
                        str(source),
                    )
            header = tomllib.loads((directory / "header.toml").read_text())["common"]
            self.assertEqual(header["name"], name)
            self.assertEqual(header["license"], "Apache-2.0")
            self.assertEqual(
                header["metadata"]["revision"],
                "a3768d0e82ad83cca2da97724e46bea4ff0e6dbd",
            )
            self.assertEqual(
                header["metadata"]["openclaw"]["requires"]["bins"], ["gws"]
            )
            self.assertIn("Apache License", (directory / "LICENSE").read_text())
            body = (directory / "SKILL.md").read_text()
            self.assertFalse(body.startswith("---"))
            self.assertNotIn("gws generate-skills", body)
            self.assertNotIn(b"\r", (directory / "SKILL.md").read_bytes())
            self.assertTrue(all(line == line.rstrip() for line in body.splitlines()))
            for dependency in re.findall(r"\.\./(gws-[a-z-]+)/SKILL\.md", body):
                self.assertIn(dependency, NAMES)

    def test_package_client_gates_preserve_agent_routing(self):
        expression = f"""let
          flake = builtins.getFlake {json.dumps(str(REPO))};
          pkgs = import flake.inputs.nixpkgs {{ system = builtins.currentSystem; }};
          inherit (pkgs) lib;
          check = developer: workHost: let
            noughtyLib = {{
              userHasTag = tag: developer && tag == "developer";
              hostHasTag = tag: workHost && tag == "cg";
            }};
            composer = import {ASSISTANTS}/compose.nix {{
              inherit lib pkgs;
              gwsEnabled = developer && workHost;
            }};
            assistants = import {ASSISTANTS}/default.nix {{
              inherit lib pkgs noughtyLib;
              config = {{}};
            }};
            gcloud = import {REPO}/home-manager/_mixins/development/gcloud/default.nix {{
              inherit lib noughtyLib;
              pkgs = {{
                google-cloud-sdk = {{
                  type = "derivation";
                  outPath = "gcloud";
                  meta.mainProgram = "gcloud";
                }};
                gws = {{
                  type = "derivation";
                  outPath = "gws";
                  meta.mainProgram = "gws";
                }};
                coreutils = "coreutils";
                jq = "jq";
                writeShellApplication = args: builtins.deepSeq args args.name;
              }};
              config.xdg.configHome = "/fixture/.config";
            }};
            fence = import {REPO}/home-manager/_mixins/agentic/fence/default.nix {{
              inherit lib pkgs noughtyLib;
              inherit (flake) inputs;
              config = {{
                noughty.host.is = {{ server = false; linux = true; darwin = false; }};
                home = {{ homeDirectory = "/fixture"; profileDirectory = "/fixture/.nix-profile"; }};
                xdg = {{
                  configHome = "/fixture/.config";
                  cacheHome = "/fixture/.cache";
                  dataHome = "/fixture/.local/share";
                  stateHome = "/fixture/.local/state";
                }};
              }};
            }};
          in {{
            fencePolicy = builtins.fromJSON fence.config.content.xdg.configFile."fence/fence.jsonc".text;
            enabled = gcloud.condition;
            packages = if gcloud.condition then gcloud.content.home.packages else [];
            environment = if gcloud.condition then gcloud.content.home.sessionVariables else {{}};
            names = builtins.attrNames composer.skillDirs;
            agentModels = assistants.config.agentic.assistants.pi.providerRouterMap;
            agentThinking = assistants.config.agentic.assistants.pi.providerRouterThinkingMap;
            clients = lib.genAttrs [ "claude" "codex" "opencode" "pi" ] (platform:
              lib.mapAttrs (_: skill: skill.content)
                (lib.filterAttrs (name: _: lib.hasPrefix "gws-" name)
                  (composer.composeSkillsFor platform)));
          }};
        in [ (check false false) (check false true) (check true false) (check true true) ]"""
        result = subprocess.run(
            ["nix", "eval", "--impure", "--json", "--expr", expression],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        cases = json.loads(result.stdout)
        baseline = set(cases[0]["names"])
        for index, case in enumerate(cases):
            enabled = index == 3
            expected = NAMES if enabled else set()
            self.assertEqual(case["enabled"], enabled)
            policy = case["fencePolicy"]
            self.assertEqual(
                {p for p in policy["filesystem"]["allowWrite"] if "/gws" in p},
                {"/fixture/.config/gws", "/fixture/.config/gws/**"}
                if enabled
                else set(),
            )
            self.assertEqual(policy["network"], cases[0]["fencePolicy"]["network"])
            self.assertEqual(policy["command"], cases[0]["fencePolicy"]["command"])
            self.assertEqual(policy["filesystem"]["allowExecute"], ["/nix"])
            self.assertEqual(
                case["packages"], ["gcloud", "gws", "jq"] if enabled else []
            )
            self.assertEqual(
                case["environment"],
                {
                    "GOOGLE_WORKSPACE_CLI_CONFIG_DIR": "/fixture/.config/gws",
                }
                if enabled
                else {},
            )
            self.assertEqual(set(case["names"]), baseline | expected)
            self.assertEqual(case["agentModels"], cases[0]["agentModels"])
            self.assertEqual(case["agentThinking"], cases[0]["agentThinking"])
            self.assertTrue(NAMES.isdisjoint(case["agentModels"]))
            self.assertTrue(NAMES.isdisjoint(case["agentThinking"]))
            for platform, skills in case["clients"].items():
                self.assertEqual(set(skills), expected, platform)
                for name, content in skills.items():
                    header = yaml.safe_load(content.split("---", 2)[1])
                    self.assertEqual(header["name"], name)
                    self.assertEqual(header["license"], "Apache-2.0")
                    self.assertNotIn("[common]", content)
        codex = (ASSISTANTS.parent / "codex/default.nix").read_text()
        self.assertIn('gwsEnabled = isDeveloper && noughtyLib.hostHasTag "cg";', codex)
        self.assertIn(
            "sharedSkillNames = builtins.attrNames assistantCompose.skillDirs;", codex
        )

    def test_generated_client_trees(self):
        expression = f"""let
          flake = builtins.getFlake {json.dumps(str(REPO))};
          pkgs = import flake.inputs.nixpkgs {{ system = builtins.currentSystem; }};
          inherit (pkgs) lib;
          composer = import {ASSISTANTS}/compose.nix {{
            inherit lib pkgs;
            gwsEnabled = true;
          }};
        in lib.concatMap (platform:
          lib.mapAttrsToList (_: skill: skill.path)
            (lib.filterAttrs (name: _: lib.hasPrefix "gws-" name)
              (composer.composeSkillsFor platform)))
          [ "claude" "codex" "opencode" "pi" ]"""
        result = subprocess.run(
            ["nix", "build", "--impure", "--json", "--no-link", "--expr", expression],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        trees = [Path(item["outputs"]["out"]) for item in json.loads(result.stdout)]
        self.assertEqual(len(trees), 4 * len(NAMES))
        for tree in trees:
            content = (tree / "SKILL.md").read_text()
            header = yaml.safe_load(content.split("---", 2)[1])
            name = header["name"]
            self.assertIn(name, NAMES)
            self.assertEqual(
                content.split("---", 2)[2].strip(),
                (ASSISTANTS / "skills" / name / "SKILL.md").read_text().strip(),
            )
            self.assertEqual(
                (tree / "LICENSE").read_bytes(),
                (ASSISTANTS / "skills" / name / "LICENSE").read_bytes(),
            )
            self.assertFalse((tree / "header.toml").exists())
            if "-codex-skill-" in tree.name:
                self.assertFalse((tree / "SKILL.md").is_symlink())


if __name__ == "__main__":
    unittest.main()
