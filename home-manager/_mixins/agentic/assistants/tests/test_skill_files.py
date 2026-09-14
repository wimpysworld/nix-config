"""Build skill trees and check Codex discovery without activating a configuration."""

import json
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

import yaml

ASSISTANTS = Path(__file__).resolve().parents[1]
REPO = ASSISTANTS.parents[3]


class SkillFileTests(unittest.TestCase):
    def test_caller_context_and_worker_commands_use_the_same_routes_for_public_and_secret_bodies(
        self,
    ):
        body = "TASK_SENTINEL: keep caller context and delegate checks for $ARGUMENTS."
        files = {
            "instructions/global.md": "Keep caller context.\n",
            "styles/house-style/house-style.md": "Use plain language.\n",
            "skills/communication-rules/SKILL.md": "Use plain language.\n",
            "skills/communication-rules/header.toml": '[common]\nname = "communication-rules"\ndescription = "Use plain language."\n',
            "skills/delegate-task/header.toml": '[common]\nname = "delegate-task"\ndescription = "Delegate a task."\n',
            "agents/owner/prompt.md": "OWNER_PERSONA_SENTINEL\n",
            "agents/owner/header.toml": '[common]\ndescription = "Command owner."\n',
            "agents/worker/prompt.md": "PERSONA_SENTINEL\n",
            "agents/worker/header.toml": '[common]\ndescription = "Fixture worker."\n',
        }
        cases = {}
        for selection in ("scoped", "bound", "unbound", "override"):
            for mode in ("caller-context", "worker", "inline"):
                for secret in (False, True):
                    name = f"{selection}-{mode}-{'secret' if secret else 'public'}"
                    cases[name] = (selection, mode, secret)
                    directory = (
                        f"commands/{name}"
                        if selection in ("scoped", "override")
                        else f"commands/{name}"
                    )
                    header = '[common]\ndescription = "Fixture command."\n[compose]\n'
                    header += (
                        f"caller-context = {str(mode == 'caller-context').lower()}\n"
                    )
                    if selection in ("bound", "override", "scoped"):
                        header += 'agent = "worker"\n'
                    for provider, key in (
                        ("claude", "use-task"),
                        ("pi", "spawn-agent"),
                        ("codex", "spawn-agent"),
                    ):
                        header += f"[compose.{provider}]\n{key} = {str(mode != 'inline').lower()}\n"
                    header += (
                        "[compose.coordinator]\n"
                        'before-launch = """\nBEFORE_SENTINEL\nPrepare the packet.\n"""\n'
                        'after-return = """\nAFTER_SENTINEL\nWait for consent.\n"""\n'
                    )
                    if mode == "caller-context":
                        header += (
                            '[claude]\ncontext = "fork"\nagent = "worker"\n'
                            '[opencode]\nagent = "worker"\nsubtask = true\n'
                        )
                    files[directory + "/command.toml"] = header
                    files[
                        directory + ("/command.sops" if secret else "/command.md")
                    ] = (name if secret else body) + "\n"
        for name in ("make-commit", "make-pr"):
            cases[name] = ("garfield", "worker", False)
            for filename in ("command.toml", "command.md"):
                path = f"commands/{name}/{filename}"
                files[path] = (ASSISTANTS / path).read_text()
        for suffix in ("community", "colleague", "mine", "again"):
            name = f"review-code-{suffix}"
            cases[name] = ("donatello", "worker", False)
            for filename in ("command.toml", "command.md"):
                path = f"commands/{name}/{filename}"
                files[path] = (ASSISTANTS / path).read_text()
        for agent in ("garfield", "donatello"):
            for filename in ("header.toml", "prompt.md"):
                path = f"agents/{agent}/{filename}"
                files[path] = (ASSISTANTS / path).read_text()
        with tempfile.TemporaryDirectory(
            prefix="assistant-command-routes-"
        ) as directory:
            for name in (
                "default.nix",
                "compose.nix",
                "metadata.nix",
                "owned-deployment.nix",
            ):
                Path(directory, name).write_text((ASSISTANTS / name).read_text())
            for name, content in files.items():
                path = Path(directory, name)
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
            secret_names = [name for name, (_, _, secret) in cases.items() if secret]
            expression = f"""let
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
            }}"""
            result = subprocess.run(
                ["nix", "eval", "--impure", "--json", "--expr", expression],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            generated = json.loads(result.stdout)
        owned = {entry["path"]: entry for entry in generated["owned"]}
        self.assertFalse(any("/agents/command-" in path for path in owned))
        for name, (selection, mode, secret) in cases.items():
            for platform in ("claude", "opencode", "pi", "codex"):
                with self.subTest(command=name, platform=platform):
                    expected_body = "PLACEHOLDER_" + name if secret else body
                    agent = (
                        selection
                        if selection in ("garfield", "donatello")
                        else "worker"
                    )
                    if selection == "donatello" or selection == "garfield":
                        expected_body = files[f"commands/{name}/command.md"].strip()
                    if platform == "codex":
                        entry = owned[f"/fixture/.codex/skills/{name}/SKILL.md"]
                        rendered = entry["prefix"] if secret else entry["source"]
                        if secret:
                            self.assertEqual(entry["source"], "/run/secret/" + name)
                            expected_body = ""
                        policy = yaml.safe_load(
                            owned[f"/fixture/.codex/skills/{name}/agents/openai.yaml"][
                                "source"
                            ]
                        )
                        self.assertIs(
                            policy["policy"]["allow_implicit_invocation"], False
                        )
                    elif secret:
                        rendered = generated["templates"][
                            f"assistant-{platform}-command-{name}"
                        ]["content"]
                    elif platform == "pi":
                        rendered = generated["pi"][f".pi/agent/prompts/{name}.md"][
                            "text"
                        ]
                    else:
                        rendered = generated[platform][name]
                    frontmatter, task = rendered.split("---", 2)[1:]
                    native = yaml.safe_load(frontmatter)
                    self.assertNotIn("compose", native)
                    self.assertNotIn("caller-context", native)
                    self.assertNotIn("coordinator", native)
                    self.assertNotIn("before-launch", native)
                    self.assertNotIn("after-return", native)
                    wrapped = (
                        selection != "unbound"
                        and mode == "worker"
                        and platform != "opencode"
                    )
                    if selection not in ("garfield", "donatello"):
                        for marker in ("BEFORE_SENTINEL", "AFTER_SENTINEL"):
                            self.assertEqual(rendered.count(marker), int(wrapped))
                        if wrapped:
                            launch, child_task = task.split("\n## Task\n", 1)
                            self.assertIn(
                                "BEFORE_SENTINEL\nPrepare the packet.", launch
                            )
                            self.assertIn("AFTER_SENTINEL\nWait for consent.", launch)
                            self.assertLess(
                                launch.index("BEFORE_SENTINEL"),
                                launch.index("AFTER_SENTINEL"),
                            )
                            self.assertNotIn("BEFORE_SENTINEL", child_task)
                            self.assertNotIn("AFTER_SENTINEL", child_task)
                    if mode == "caller-context" or selection == "unbound":
                        self.assertEqual(task.strip(), expected_body)
                        self.assertNotIn("PERSONA_SENTINEL", rendered)
                        self.assertNotIn("agent", native)
                        if mode == "caller-context" and platform == "opencode":
                            self.assertIs(native["subtask"], False)
                        if mode == "caller-context" and platform == "claude":
                            self.assertNotIn("context", native)
                    elif platform == "codex":
                        if mode == "inline":
                            self.assertIn("PERSONA_SENTINEL", task)
                            self.assertNotIn("Use the `spawn_agent` tool", task)
                        else:
                            self.assertIn(
                                f"Use the `spawn_agent` tool to launch the `{agent}` agent",
                                task,
                            )
                            self.assertNotIn("PERSONA_SENTINEL", task)
                    elif platform == "pi":
                        if mode == "inline":
                            self.assertEqual(task.strip(), expected_body)
                        else:
                            self.assertIn(
                                f'Use the Agent tool with `subagent_type: "{agent}"`',
                                task,
                            )
                    elif platform == "claude":
                        if mode == "inline":
                            self.assertEqual(
                                task.strip(), f"@{agent}\n\n{expected_body}".strip()
                            )
                        else:
                            self.assertIn(
                                f"Use the Task tool to launch the {agent} agent", task
                            )
                    else:
                        self.assertEqual(native["agent"], agent)
                    child = (
                        selection != "unbound"
                        and mode != "caller-context"
                        and not (platform != "opencode" and mode == "inline")
                    )
                    if child:
                        launch = ""
                        if platform == "opencode":
                            self.assertIs(native.get("subtask", True), True)
                            child_task = task
                        else:
                            launch, child_task = task.split("\n## Task\n", 1)
                            self.assertNotIn("You are a worker.", launch)
                            if expected_body:
                                self.assertNotIn(expected_body, launch)
                        self.assertIn("You are a worker.", child_task)
                        if selection == "donatello":
                            skill = (
                                "review-code-follow-up"
                                if name == "review-code-again"
                                else "review-code"
                            )
                            self.assertIn(
                                f"Load the `{skill}` skill in direct worker mode.",
                                child_task,
                            )
                            self.assertIn(
                                "Do not launch agents or execute generated launch wrappers.",
                                child_task,
                            )
                            self.assertNotIn("model", native)
                            if platform != "codex":
                                hint = (
                                    "[target|report]"
                                    if name == "review-code-again"
                                    else "[pr|branch|worktree|commit]"
                                )
                                self.assertEqual(native["argument-hint"], hint)
                        if selection == "garfield":
                            self.assertNotIn("Before launch, add", child_task)
                            self.assertNotIn("model", native)
                            if platform != "codex":
                                self.assertEqual(native["argument-hint"], "[context]")
                            self.assertIn("accompanying invocation text", child_task)
                            if platform != "opencode":
                                self.assertIn(
                                    "Before launch, add the known intent", launch
                                )
                                self.assertIn("explicit mutation authority", launch)
                                self.assertIn(
                                    "not the general conversation or transcript", launch
                                )
                                if name == "make-pr":
                                    self.assertIn("Only after explicit consent", launch)
                                    self.assertIn(
                                        "Do not send monitoring to Garfield", launch
                                    )
                            if name == "make-pr":
                                self.assertIn("Watch handover: Coordinator", child_task)
                                self.assertIn("Never invoke `babysit-pr`", child_task)
                        for wrapper in (
                            "Use the `spawn_agent` tool to launch",
                            "Use the Agent tool with",
                            "Use the Task tool to launch",
                        ):
                            self.assertNotIn(wrapper, child_task)
                    else:
                        self.assertNotIn("You are a worker.", task)
                    if expected_body:
                        self.assertIn(expected_body, task)

    def test_review_modes_keep_coverage_and_coordinator_boundaries(self):
        review = (ASSISTANTS / "skills/review-code/SKILL.md").read_text()
        execution, process = review.split("### Process", 1)
        fanout = review.split("### Fan-out", 1)[1].split(
            "### Adversarial pressure-test", 1
        )[0]
        for instruction in (
            "Direct worker mode applies when the caller selects it",
            "Complete all assigned concerns directly, including security",
            "Do not launch agents or execute generated launch wrappers",
            "read surrounding source, verify evidence, deduplicate findings",
            "build and run relevant tests",
            "distinguish environmental failures from change-caused failures",
            "Coordinator mode applies only to a coordinator",
            "Loading this skill grants no coordinator authority",
            "For a complete review in either mode, add a topic sweep",
            "Search Linear for related issues and Slack for recent conversations",
            "Keep the sweep read-only, with no comments or posts",
        ):
            self.assertIn(instruction, execution)
        for instruction in (
            "The parent owns the final report for those lanes",
            "In coordinator mode only, fan out to workers",
            "In coordinator mode only, re-request once",
            "In direct worker mode, use your own verified evidence",
            "Deduplicate overlapping findings before verification",
            "In direct worker mode, perform this check yourself without delegation",
            "In coordinator mode only, send one follow-up",
            "In coordinator mode only, use an independent verifier",
            "`Target`, `Reviewed SHA`, `Lens`, and `Severity bar`",
            "A finding is three sentences at most",
            "Do not draft a review comment and do not state a verdict",
        ):
            self.assertIn(instruction, process)
        for instruction in (
            "This section applies only in coordinator mode",
            "Route the security concern to `dibble` workers",
            "Each worker's delegation packet",
            "Copy the findings to the file its packet names as a fallback",
            "Never launch another agent",
        ):
            self.assertIn(instruction, fanout)
        community = (
            ASSISTANTS / "commands/review-code-community/command.md"
        ).read_text()
        for threat in (
            "All of equal weight",
            "obfuscated logic",
            "unexpected network calls",
            "exfiltration of secrets or environment",
            "dependency additions that pull unvetted code",
            "install or build hooks",
            "CI changes that widen permissions or leak secrets",
            "anything whose stated purpose does not match its effect",
            "Inspect the code directly for every listed malicious-code threat",
        ):
            self.assertIn(threat, community)
        self.assertNotIn("dibble", community)

    def test_follow_up_keeps_direct_execution_and_delta_only_contract(self):
        follow_up = (ASSISTANTS / "skills/review-code-follow-up/SKILL.md").read_text()
        for instruction in (
            "In direct worker mode, complete this method yourself without delegation",
            "Do not launch agents or execute generated launch wrappers",
            "A review-lane worker reuses the parent's paths",
            "use the sole report in the latest timestamped run",
            "Follow its `Source report` chain only to validate the chain",
            "Reject a missing, unsafe, or cyclic source path",
            "do not run the wide fan-out or topic sweep",
            "| `resolved` |",
            "| `partly resolved` |",
            "| `unresolved` |",
            "| `withdrawn` |",
            "Review changed lines and directly affected callers or tests only",
            "serious security, data-loss, outage, or production-correctness risk",
            "Adversarially verify the preconditions and deployment impact",
            "Do not restart the full review",
            "Use the supplied new run for the same target",
            "Source report: <exact direct source path>",
            "Previous reviewed SHA: <sha or unavailable>",
            "Current reviewed SHA: <sha>",
            "Keep resolved and withdrawn items only in `Prior Findings`",
            "Do not draft or post a GitHub comment",
        ):
            self.assertIn(instruction, follow_up)

    def test_report_run_ownership_distinguishes_complete_and_lane_workers(self):
        report = (ASSISTANTS / "skills/review-report-path/SKILL.md").read_text()
        for instruction in (
            "Lookup creates no directories or files",
            "A worker assigned a complete review is that owner",
            "allocates one exclusive run when none is supplied",
            "When the parent supplies a run, the complete-review worker reuses it",
            "A review-lane worker always uses the parent's supplied run and fallback paths, never a new run",
            "`mktemp -d` creates the run directory exclusively",
            "Never overwrite an existing report or findings file",
            "never select the newest report when several reports match",
        ):
            self.assertIn(instruction, report)

    def test_pi_secret_skills_preserve_output_without_agent_routes(self):
        files = {
            "styles/house-style/house-style.md": "Use plain language.\n",
            "skills/communication-rules/SKILL.md": "Use plain language.\n",
            "skills/routed/SKILL.sops": "fixture-routed\n",
            "skills/routed/header.toml": """[common]
name = "routed"
description = "An encrypted fixture skill."
[routing.pi.openai]
model = "fixture-model"
thinking = "high"
""",
            "skills/self-review/SKILL.sops": "fixture-headerless\n",
            "skills/public/SKILL.md": "Run the public fixture.\n",
            "skills/public/header.toml": """[common]
name = "public"
description = "A public fixture skill."
""",
        }
        with tempfile.TemporaryDirectory(prefix="assistant-skill-routes-") as directory:
            for name in ("default.nix", "compose.nix", "metadata.nix"):
                Path(directory, name).write_text((ASSISTANTS / name).read_text())
            for name, content in files.items():
                path = Path(directory, name)
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
            expression = f"""let
              flake = builtins.getFlake {json.dumps(str(REPO))};
              pkgs = import flake.inputs.nixpkgs {{ system = builtins.currentSystem; }};
              assistants = import {directory}/default.nix {{
                inherit pkgs;
                inherit (pkgs) lib;
                config = {{
                  home.homeDirectory = "/fixture";
                  programs.claude-code.enable = false;
                  programs.opencode.enable = false;
                  sops.placeholder = {{
                    fixture-routed = "PLACEHOLDER_ROUTED";
                    fixture-headerless = "PLACEHOLDER_HEADERLESS";
                  }};
                }};
                noughtyLib = {{ userHasTag = _: true; hostHasTag = _: false; }};
              }};
            in {{
              models = assistants.config.agentic.assistants.pi.providerRouterMap;
              thinking = assistants.config.agentic.assistants.pi.providerRouterThinkingMap;
              templates = assistants.config.sops.templates;
              public = assistants.config.agentic.assistants.pi.homeFiles.
                ".pi/agent/skills/public".source;
            }}"""
            result = subprocess.run(
                ["nix", "eval", "--impure", "--json", "--expr", expression],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            generated = json.loads(result.stdout)
            self.assertEqual(generated["models"], {})
            self.assertEqual(generated["thinking"], {})
            self.assertEqual(
                generated["templates"],
                {
                    "assistant-pi-skill-routed": {
                        "content": "PLACEHOLDER_ROUTED",
                    },
                    "assistant-pi-skill-self-review": {
                        "content": "PLACEHOLDER_HEADERLESS",
                    },
                },
            )
            self.assertTrue(generated["public"].endswith("-pi-skill-public"))

    def test_codex_discovers_regular_root_and_nested_skill_files(self):
        header = """[common]
name = "NAME"
description = "A fixture skill."
[codex.policy]
allow_implicit_invocation = false
"""
        files = {
            "styles/house-style/house-style.md": "Use plain language.\n",
            "skills/communication-rules/SKILL.md": "Use plain language.\n",
            "skills/delegate-task/header.toml": header.replace("NAME", "delegate-task"),
            "skills/fixture/header.toml": header.replace("NAME", "fixture"),
            "skills/fixture/SKILL.md": "Run the fixture.\n",
            "skills/fixture/references/nested/header.toml": header.replace(
                "NAME", "nested"
            ),
            "skills/fixture/references/nested/SKILL.md": "Run the nested fixture.\n",
            "skills/fixture/references/nested/guide.md": "Keep this supporting file.\n",
            "skills/fixture/references/legacy/SKILL.md": "---\nname: legacy\ndescription: Legacy fixture.\n---\n\nKeep this skill.\n",
        }
        with tempfile.TemporaryDirectory(prefix="assistant-skill-files-") as directory:
            for name, content in files.items():
                path = Path(directory, name)
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
            expression = f"""let
              flake = builtins.getFlake {json.dumps(str(REPO))};
              pkgs = import flake.inputs.nixpkgs {{ system = builtins.currentSystem; }};
              composer = import {ASSISTANTS}/compose.nix {{
                inherit pkgs;
                inherit (pkgs) lib;
                basePath = builtins.path {{ path = {json.dumps(directory)}; }};
              }};
              skills = composer.composeSkillsFor "codex";
            in [ skills.fixture.path skills.delegate-task.path ]"""
            result = subprocess.run(
                [
                    "nix",
                    "build",
                    "--impure",
                    "--json",
                    "--no-link",
                    "--expr",
                    expression,
                ],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            trees = [Path(item["outputs"]["out"]) for item in json.loads(result.stdout)]
            tree = next(path for path in trees if path.name.endswith("-skill-fixture"))
            generated = next(
                path for path in trees if path.name.endswith("-skill-delegate-task")
            )
            deployed = Path(directory, "deployed")
            deployed.mkdir()
            (deployed / "SKILL.md").write_text((tree / "SKILL.md").read_text())
            (deployed / "references").symlink_to(
                tree / "references", target_is_directory=True
            )
            discovered = set()
            pending = [deployed]
            while pending:
                with os.scandir(pending.pop()) as entries:
                    for entry in entries:
                        if entry.is_dir():
                            pending.append(Path(entry.path))
                        elif entry.name == "SKILL.md" and entry.is_file(
                            follow_symlinks=False
                        ):
                            discovered.add(
                                Path(entry.path).relative_to(deployed).as_posix()
                            )
            self.assertEqual(
                discovered,
                {
                    "SKILL.md",
                    "references/nested/SKILL.md",
                    "references/legacy/SKILL.md",
                },
            )
            self.assertTrue(stat.S_ISREG((generated / "SKILL.md").lstat().st_mode))
            for name in discovered:
                self.assertTrue(stat.S_ISREG((tree / name).lstat().st_mode), name)
            for prefix in ("", "references/nested/"):
                with self.subTest(prefix=prefix):
                    skill = (tree / prefix / "SKILL.md").read_text()
                    self.assertNotIn("policy", yaml.safe_load(skill.split("---", 2)[1]))
                    companion = yaml.safe_load(
                        (tree / prefix / "agents/openai.yaml").read_text()
                    )
                    self.assertIs(
                        companion["policy"]["allow_implicit_invocation"], False
                    )
                    self.assertFalse((tree / prefix / "header.toml").exists())
            for name in ("references/nested/guide.md", "references/legacy/SKILL.md"):
                self.assertEqual(
                    (tree / name).read_text(), files["skills/fixture/" + name]
                )
            self.assertTrue((tree / "references/nested/guide.md").is_symlink())


if __name__ == "__main__":
    unittest.main()
