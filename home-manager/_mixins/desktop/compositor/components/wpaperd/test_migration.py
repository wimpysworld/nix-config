"""Run the wpaperd activation cleanup only in temporary homes."""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

MODULE = Path(__file__).resolve().with_name("default.nix")
ROOT = next(parent for parent in MODULE.parents if (parent / "flake.nix").is_file())
RELATIVE = ".config/systemd/user/graphical-session.target.wants/wpaperd.service"
OWNED = "/nix/store/ljih5kpjd0al1jm5ylc1zhfdqry1lyd3-home-manager-files/" + RELATIVE


class MigrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        expression = r'''
          let
            flake = builtins.getFlake REPO;
            baseLib = flake.inputs.nixpkgs.lib;
            lib = baseLib.extend (_: _: {
              hm = import (flake.inputs.home-manager + "/modules/lib") { lib = baseLib; };
            });
            evaluate = target:
              let
                module = import MODULE {
                  inherit lib;
                  pkgs = flake.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
                  noughtyLib = {};
                  config = {
                    noughty.host = { displays = []; is = { linux = true; workstation = true; }; };
                    home.homeDirectory = "/fixture-home";
                    xdg.configHome = "/fixture-home/.config";
                    services.wpaperd.enable = true;
                    wayland.systemd.target = target;
                  };
                };
                entry = module.content.home.activation.removeObsoleteWpaperdDependency;
              in if entry.condition then entry.content else null;
          in {
            hyprland = evaluate "hyprland-session.target";
            wayfire = evaluate "wayfire-session.target";
            graphical = evaluate "graphical-session.target";
          }
        '''.replace("REPO", json.dumps(str(ROOT))).replace("MODULE", str(MODULE))
        result = subprocess.run(
            ["nix", "eval", "--impure", "--json", "--expr", expression],
            check=True, capture_output=True, text=True,
        )
        cls.entries = json.loads(result.stdout)

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="wpaperd-migration-")
        self.addCleanup(self.directory.cleanup)
        self.home = Path(self.directory.name) / "home"
        self.link = self.home / RELATIVE
        self.link.parent.mkdir(parents=True)
        self.generation = Path(self.directory.name) / "generation"
        (self.generation / "home-files").mkdir(parents=True)

    def activate(self, target="hyprland", dry_run=False):
        entry = self.entries[target]
        if entry is None:
            return
        self.assertEqual(entry["before"], ["linkGeneration"])
        self.assertEqual(entry["after"], ["writeBoundary"])
        script = entry["data"].replace("/fixture-home", str(self.home))
        run = 'run() { :; }\n' if dry_run else 'run() { "$@"; }\n'
        subprocess.run(
            ["bash", "-euc", run + script], check=True,
            env={**os.environ, "HOME": str(self.home), "newGenPath": str(self.generation)},
            capture_output=True, text=True,
        )

    def test_stale_owned_link_removed_and_repeat_safe(self):
        self.link.symlink_to(OWNED)
        other = self.link.with_name("unrelated.service")
        other.symlink_to(OWNED)
        self.activate()
        self.activate()
        self.assertFalse(self.link.is_symlink())
        self.assertEqual(os.readlink(other), OWNED)

    def test_arbitrary_symlinks_preserved(self):
        for destination in (
            "../wpaperd.service", str(self.home / "user-wpaperd.service"),
            OWNED.replace("home-manager-files", "user-files"),
            OWNED.replace("/" + RELATIVE, "/different/wpaperd.service"),
            OWNED.replace("ljih5kpjd0al1jm5ylc1zhfdqry1lyd3", "not-a-store-hash"),
        ):
            with self.subTest(destination=destination):
                self.link.symlink_to(destination)
                self.activate()
                self.assertEqual(os.readlink(self.link), destination)
                self.link.unlink()

    def test_regular_file_preserved(self):
        self.link.write_text("user unit\n")
        self.activate()
        self.assertEqual(self.link.read_text(), "user unit\n")

    def test_existing_user_symlink_preserved(self):
        unit = self.home / "user-wpaperd.service"
        unit.write_text("user unit\n")
        self.link.symlink_to(unit)
        self.activate()
        self.assertEqual(self.link.read_text(), "user unit\n")
        self.assertEqual(os.readlink(self.link), str(unit))

    def test_selected_dependency_preserved(self):
        selected = self.home / RELATIVE.replace("graphical-session", "hyprland-session")
        selected.parent.mkdir()
        selected.symlink_to(OWNED.replace("graphical-session", "hyprland-session"))
        self.link.symlink_to(OWNED)
        self.activate()
        self.assertTrue(selected.is_symlink())
        self.assertFalse(self.link.is_symlink())

    def test_selected_graphical_target_preserved(self):
        self.link.symlink_to(OWNED)
        self.activate("graphical")
        self.assertEqual(os.readlink(self.link), OWNED)

    def test_new_generation_dependency_preserved(self):
        self.link.symlink_to(OWNED)
        desired = self.generation / "home-files" / RELATIVE
        desired.parent.mkdir(parents=True)
        desired.symlink_to("../wpaperd.service")
        self.activate()
        self.assertEqual(os.readlink(self.link), OWNED)

    def test_dry_run_preserved(self):
        self.link.symlink_to(OWNED)
        self.activate(dry_run=True)
        self.assertEqual(os.readlink(self.link), OWNED)

    def test_wayfire_cleanup(self):
        self.link.symlink_to(OWNED)
        self.activate("wayfire")
        self.assertFalse(self.link.is_symlink())

    def test_symlinked_parent_preserved(self):
        self.link.parent.rmdir()
        elsewhere = Path(self.directory.name) / "user-directory"
        elsewhere.mkdir()
        self.link.parent.symlink_to(elsewhere, target_is_directory=True)
        self.link.symlink_to(OWNED)
        self.activate()
        self.assertEqual(os.readlink(self.link), OWNED)


if __name__ == "__main__":
    unittest.main()
