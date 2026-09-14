"""Run the graphical-session dependency cleanup only in temporary homes."""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

MODULE = Path(__file__).resolve().parents[2] / "default.nix"
ROOT = next(parent for parent in MODULE.parents if (parent / "flake.nix").is_file())
SERVICES = (
    "wpaperd.service",
    "avizo.service",
    "kanshi.service",
    "reframe-session.service",
    "swaync.service",
    "veilad.service",
    "veila-idle.service",
)
DEPENDENCIES = Path("systemd/user/graphical-session.target.wants")
STORE_FILES = "/nix/store/ljih5kpjd0al1jm5ylc1zhfdqry1lyd3-home-manager-files/"


class MigrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        expression = r"""
          let
            flake = builtins.getFlake REPO;
            baseLib = flake.inputs.nixpkgs.lib;
            lib = baseLib.extend (_: _: {
              hm = import (flake.inputs.home-manager + "/modules/lib") { lib = baseLib; };
            });
            evaluate = {
              desktop ? "hyprland",
              target ? "${desktop}-session.target",
              linux ? true,
              workstation ? true,
              configHome ? "/fixture-home/.config",
            }:
              let
                module = import MODULE {
                  inherit lib;
                  pkgs = flake.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
                  config = {
                    noughty.host = { inherit desktop; is = { inherit linux workstation; }; };
                    home.homeDirectory = "/fixture-home";
                    xdg = { inherit configHome; };
                    services = builtins.listToAttrs (map (name: {
                      inherit name;
                      value.enable = false;
                    }) [ "wpaperd" "avizo" "kanshi" "reframe-session" "swaync" "veilad" "veila-idle" ]);
                    wayland.systemd.target = target;
                  };
                };
                entry = module.config.content.home.activation.removeObsoleteGraphicalSessionDependencies;
              in if module.config.condition && entry.condition then entry.content else null;
          in {
            hyprland = evaluate {};
            wayfire = evaluate { desktop = "wayfire"; };
            graphical = evaluate { target = "graphical-session.target"; };
            outside = evaluate { configHome = "/outside-home/.config"; };
            sibling = evaluate { configHome = "/fixture-home-other/.config"; };
            home = evaluate { configHome = "/fixture-home"; };
            custom = evaluate { configHome = "/fixture-home/config dir's"; };
            unsupported = evaluate { desktop = "unsupported"; };
            nonLinux = evaluate { linux = false; };
            nonWorkstation = evaluate { workstation = false; };
          }
        """.replace("REPO", json.dumps(str(ROOT))).replace("MODULE", str(MODULE))
        result = subprocess.run(
            ["nix", "eval", "--impure", "--json", "--expr", expression],
            check=True,
            capture_output=True,
            text=True,
        )
        cls.entries = json.loads(result.stdout)

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="session-migration-")
        self.addCleanup(self.directory.cleanup)
        self.home = Path(self.directory.name) / "home"
        self.config_home = self.home / ".config"
        (self.config_home / DEPENDENCIES).mkdir(parents=True)
        self.generation = Path(self.directory.name) / "generation"
        (self.generation / "home-files").mkdir(parents=True)

    def links(self):
        return [self.config_home / DEPENDENCIES / service for service in SERVICES]

    def owned(self, link):
        return STORE_FILES + str(link.relative_to(self.home))

    def stale_links(self):
        for link in self.links():
            link.symlink_to(self.owned(link))

    def assert_stale_links_preserved(self):
        for link in self.links():
            self.assertEqual(os.readlink(link), self.owned(link))

    def activate(self, target="hyprland", dry_run=False):
        entry = self.entries[target]
        if entry is None:
            return ""
        self.assertEqual(entry["before"], ["linkGeneration"])
        self.assertEqual(entry["after"], ["writeBoundary"])
        script = entry["data"].replace("/fixture-home", str(self.home))
        run = "run() { printf '%s\\n' \"$@\"; }\n" if dry_run else 'run() { "$@"; }\n'
        result = subprocess.run(
            ["bash", "-euc", run + script],
            check=True,
            env={
                **os.environ,
                "HOME": str(self.home),
                "newGenPath": str(self.generation),
            },
            capture_output=True,
            text=True,
        )
        return result.stdout

    def test_stale_owned_links_removed_and_repeat_safe(self):
        for target in ("hyprland", "wayfire"):
            with self.subTest(target=target):
                self.stale_links()
                self.activate(target)
                self.activate(target)
                for link in self.links():
                    self.assertFalse(link.is_symlink())

    def test_unrelated_dependencies_preserved(self):
        self.stale_links()
        other = self.links()[0].with_name("unrelated.service")
        other.symlink_to(self.owned(other))
        self.activate()
        self.assertEqual(os.readlink(other), self.owned(other))

    def test_arbitrary_symlinks_preserved(self):
        for link in self.links():
            owned = self.owned(link)
            for destination in (
                "../" + link.name,
                str(self.home / ("user-" + link.name)),
                owned.replace("home-manager-files", "user-files"),
                STORE_FILES + "different/" + link.name,
                owned.replace("ljih5kpjd0al1jm5ylc1zhfdqry1lyd3", "not-a-store-hash"),
                owned.replace("ljih5kpjd0al1jm5ylc1zhfdqry1lyd3", "e" * 32),
                "/foreign" + owned,
                owned + ".extra",
                owned + "/extra",
            ):
                with self.subTest(service=link.name, destination=destination):
                    link.symlink_to(destination)
                    self.activate()
                    self.assertEqual(os.readlink(link), destination)
                    link.unlink()

    def test_regular_files_preserved(self):
        for link in self.links():
            link.write_text("user unit\n")
        self.activate()
        for link in self.links():
            self.assertEqual(link.read_text(), "user unit\n")

    def test_existing_user_symlinks_preserved(self):
        for link in self.links():
            unit = self.home / ("user-" + link.name)
            unit.write_text("user unit\n")
            link.symlink_to(unit)
        self.activate()
        for link in self.links():
            self.assertEqual(link.read_text(), "user unit\n")
            self.assertEqual(os.readlink(link), str(self.home / ("user-" + link.name)))

    def test_selected_dependencies_preserved(self):
        for target in ("hyprland", "wayfire"):
            with self.subTest(target=target):
                self.stale_links()
                selected = []
                for link in self.links():
                    dependency = Path(
                        str(link).replace("graphical-session", target + "-session")
                    )
                    dependency.parent.mkdir(exist_ok=True)
                    dependency.symlink_to(self.owned(dependency))
                    selected.append(dependency)
                self.activate(target)
                for dependency in selected:
                    self.assertEqual(os.readlink(dependency), self.owned(dependency))
                for link in self.links():
                    self.assertFalse(link.is_symlink())

    def test_gates_preserve_dependencies(self):
        self.stale_links()
        for target in (
            "graphical",
            "outside",
            "sibling",
            "home",
            "unsupported",
            "nonLinux",
            "nonWorkstation",
        ):
            with self.subTest(target=target):
                self.assertIsNone(self.entries[target])
                self.activate(target)
                self.assert_stale_links_preserved()

    def test_new_generation_dependencies_preserved(self):
        self.stale_links()
        for kind in ("dangling", "regular", "symlink"):
            with self.subTest(kind=kind):
                for link in self.links():
                    desired = (
                        self.generation / "home-files" / link.relative_to(self.home)
                    )
                    desired.parent.mkdir(parents=True, exist_ok=True)
                    if kind == "regular":
                        desired.write_text("new unit\n")
                    else:
                        desired.symlink_to(
                            "../" + link.name if kind == "dangling" else MODULE
                        )
                self.activate()
                self.assert_stale_links_preserved()
                for link in self.links():
                    (
                        self.generation / "home-files" / link.relative_to(self.home)
                    ).unlink()

    def test_dry_run_preserves_dependencies(self):
        self.stale_links()
        output = self.activate(dry_run=True)
        self.assert_stale_links_preserved()
        for link in self.links():
            self.assertIn("/bin/rm\n--\n" + str(link) + "\n", output)

    def test_symlinked_parents_preserved(self):
        for relative in (".", "systemd", "systemd/user", str(DEPENDENCIES)):
            with self.subTest(parent=relative):
                parent = (
                    self.config_home if relative == "." else self.config_home / relative
                )
                elsewhere = Path(self.directory.name) / "user-directory"
                parent.rename(elsewhere)
                parent.symlink_to(elsewhere, target_is_directory=True)
                self.stale_links()
                self.activate()
                self.assert_stale_links_preserved()
                for link in self.links():
                    link.unlink()
                parent.unlink()
                elsewhere.rename(parent)

    def test_custom_config_home(self):
        self.config_home = self.home / "config dir's"
        (self.config_home / DEPENDENCIES).mkdir(parents=True)
        self.stale_links()
        self.activate("custom")
        for link in self.links():
            self.assertFalse(link.is_symlink())


if __name__ == "__main__":
    unittest.main()
