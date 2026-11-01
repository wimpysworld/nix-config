"""Boundary tests run by the Nix package checkPhase, without live GitHub access."""
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import repo_provision as rp


def repo(name="team/project", node="R_1", **kwargs):
    return dict(dict(full_name=name, node_id=node, archived=False, fork=False), **kwargs)


class Boundaries(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="repo-provision-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.owner = {"login": "team", "kind": "organization", "includeForks": False}
        self.config = {"root": str(self.root), "owners": [self.owner]}

    def planned(self, repositories):
        with patch.object(rp, "inventory", return_value=(repositories, [])):
            return rp.plan(self.config)

    def cli(self, config):
        path = self.root / "config.json"
        path.write_text(json.dumps(config))
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = rp.main(["--config", str(path)])
        return code, json.loads(output.getvalue())

    def test_mapping_only_repository(self):
        result = self.planned([(repo("team/.github"), False)])
        self.assertEqual(result["actions"][0]["path"], str(self.root / "team/_github"))
        self.assertEqual(result["actions"][0]["repository"]["full_name"], "team/.github")
        self.assertEqual(list(self.root.iterdir()), [])
        self.assertFalse(result["executable"])

    def test_mapping_and_case_collisions(self):
        for names in [(".github", "_github"), ("Project", "project")]:
            result = self.planned([(repo("team/" + names[0]), False),
                                   (repo("team/" + names[1], "R_2"), False)])
            self.assertTrue(result["conflicts"])
            self.assertTrue(all(a["action"] == "preserve" for a in result["actions"]))

    def test_exclusions_and_fork_opt_in(self):
        result = self.planned([(repo("wimpysworld/nix-config"), False),
                               (repo(archived=True), False),
                               (repo("team/fork", "R_2", fork=True), False),
                               (repo("team/included", "R_3", fork=True), True)])
        self.assertEqual([a["action"] for a in result["actions"]],
                         ["preserve", "preserve", "preserve", "candidate"])

    def test_paths_symlinks_case_and_non_directory(self):
        (self.root / "Team").mkdir()
        (self.root / "alias").symlink_to(self.root / "Team")
        (self.root / "dangling").symlink_to(self.root / "missing")
        (self.root / "file").write_text("keep")
        for path in [Path("relative"), self.root / "../elsewhere", self.root / "team/project",
                     self.root / "alias/project", self.root / "dangling", self.root / "file/project"]:
            with self.subTest(path=path), self.assertRaises(rp.Blocked):
                rp.safe_path(path)

    def test_zero_ancestors_and_descendants(self):
        home = self.root / "home"
        home.mkdir()
        (home / "Zero").mkdir()
        with patch.object(Path, "home", return_value=home), patch.object(rp, "inventory") as inventory:
            for path in [home, home / "Zero", home / "Zero/repo", self.root]:
                with self.assertRaises(rp.Blocked):
                    rp.plan(dict(self.config, root=str(path)))
            inventory.assert_not_called()

    def test_existing_dirty_detached_multiple_remotes_and_internals_untouched(self):
        # Deliberately untrusted metadata: no Git command may interpret it.
        checkout = self.root / "team/_github"
        (checkout / ".github").mkdir(parents=True)
        (checkout / ".git").mkdir()
        contents = {".git/HEAD": "deadbeef\n", ".git/config":
                    '[remote "origin"]\nurl = invalid\n[remote "upstream"]\nurl = other\n',
                    ".github/workflow.yml": "keep", "dirty.txt": "uncommitted"}
        for name, value in contents.items():
            (checkout / name).write_text(value)
        (checkout / ".git/index").symlink_to(checkout / "dirty.txt")
        with patch.object(rp.subprocess, "run") as run:
            result = self.planned([(repo("team/.github"), False)])
            run.assert_not_called()
        self.assertEqual(result["actions"][0]["action"], "preserve")
        self.assertTrue(result["conflicts"])
        for name, value in contents.items():
            self.assertEqual((checkout / name).read_text(), value)
        self.assertTrue((checkout / ".git/index").is_symlink())

    def test_worktrees_not_descended(self):
        (self.root / "_worktrees").symlink_to(self.root / "missing")
        (self.root / "team").mkdir()
        (self.root / "team/_worktrees").symlink_to(self.root / "missing")
        result = self.planned([])
        self.assertEqual(result["existing"], [])
        self.assertEqual(result["conflicts"], [])

    def test_occupied_and_symlink_destinations(self):
        (self.root / "team").mkdir()
        (self.root / "team/project").symlink_to(self.root / "missing")
        result = self.planned([(repo(), False)])
        self.assertTrue(result["conflicts"])
        self.assertEqual(result["actions"][0]["action"], "preserve")

    def test_pagination_failure_not_empty(self):
        batch = [repo(f"team/r{i}", f"R_{i}") for i in range(100)]
        with patch.object(rp, "api", side_effect=[{"login": "operator"}, {"state": "active"}, batch, rp.Blocked("denied")]):
            code, result = self.cli(self.config)
        self.assertEqual(code, 1)
        self.assertFalse(result["complete"])
        self.assertIsNone(result["actions"])

    def test_pagination_terminal_page(self):
        batch = [repo(f"team/r{i}", f"R_{i}") for i in range(100)]
        with patch.object(rp, "api", side_effect=[{"login": "operator"}, {"state": "active"}, batch, []]):
            repositories, evidence = rp.inventory([self.owner])
        self.assertEqual(len(repositories), 100)
        self.assertEqual(evidence[0]["pages"], 2)
        self.assertEqual(evidence[0]["visibility"], "token-visible only")

    def test_duplicate_pages_and_malformed_responses(self):
        batch = [repo(f"team/r{i}", f"R_{i}") for i in range(100)]
        for batches in [[batch, [batch[0]]], [[None]], [[{"full_name": []}]], [{"error": "denied"}]]:
            with patch.object(rp, "api", side_effect=[{"login": "operator"}, {"state": "active"}, *batches]):
                with self.assertRaises(rp.Blocked):
                    rp.inventory([self.owner])

    def test_permission_failure_and_wrong_personal_owner(self):
        for responses in [[None], [{"login": "operator"}, {"state": "pending"}],
                          [{"login": "operator"}, rp.Blocked("forbidden")]]:
            with patch.object(rp, "api", side_effect=responses), self.assertRaises(rp.Blocked):
                rp.inventory([self.owner])
        with patch.object(rp, "api", return_value={"login": "someone-else"}), self.assertRaises(rp.Blocked):
            rp.inventory([dict(self.owner, kind="user")])

    def test_reserved_names_and_traversal(self):
        for name in ["..", ".GIT", "_worktrees", "../escape", "-option"]:
            with self.assertRaises(rp.Blocked):
                rp.component(name)

    def test_malformed_config_is_structured(self):
        for config in [None, [], {}, dict(self.config, owners=[]), dict(self.config, owners=[None])]:
            code, result = self.cli(config)
            self.assertEqual(code, 1)
            self.assertFalse(result["complete"])
            self.assertIsNone(result["actions"])

    def test_conflict_exit_and_success_exit(self):
        for conflicts, expected in [([], 0), ([{"reason": "occupied"}], 1)]:
            with patch.object(rp, "plan", return_value={"conflicts": conflicts, "complete": True}):
                code, result = self.cli(self.config)
            self.assertEqual(code, expected)
            self.assertTrue(result["complete"])

    def test_apply_is_not_available(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
            rp.main(["--config", "unused", "--apply"])
        self.assertEqual(error.exception.code, 2)
        self.assertFalse(hasattr(rp, "apply"))


if __name__ == "__main__":
    unittest.main()
