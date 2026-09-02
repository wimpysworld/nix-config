# This file defines overlays
{ inputs, ... }:
let
  inherit (inputs) handy;
  upstreamBun2nix = handy.inputs.bun2nix;
  bun2nixInputs = upstreamBun2nix.inputs // {
    self = bun2nix;
  };
  bun2nixModules = upstreamBun2nix.inputs.import-tree (upstreamBun2nix.outPath + "/nix");
  bun2nixOutputs =
    upstreamBun2nix.inputs.flake-parts.lib.mkFlake
      {
        inputs = bun2nixInputs;
        self = bun2nix;
        moduleLocation = upstreamBun2nix.outPath + "/flake.nix";
      }
      (
        bun2nixModules
        // {
          # Handy only supports Linux. Exclude unsupported systems before bun2nix
          # creates its flake-parts package sets.
          systems = inputs.nixpkgs.lib.mkForce [
            "aarch64-linux"
            "x86_64-linux"
          ];
        }
      );
  bun2nix = upstreamBun2nix // bun2nixOutputs // { inputs = bun2nixInputs; };
  handyPackages =
    ((import (handy.outPath + "/flake.nix")).outputs {
      self = handy;
      inherit (inputs) nixpkgs;
      inherit bun2nix;
    }).packages;
in
{
  # This one brings our custom packages from the 'pkgs' directory
  localPackages = final: _prev: import ../pkgs final;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, and more.
  # https://nixos.wiki/wiki/Overlays
  modifiedPackages =
    final: prev:
    let
      paseoPackages = inputs.paseo.packages.${prev.stdenv.hostPlatform.system} or { };
      # Paseo packages come from the upstream Paseo flake; the desktop client
      # reuses the patched daemon npm closure below.
      #
      # The v0.7.0 tag ships a wrong npm-deps fixed-output hash, which breaks
      # the build with a hash mismatch. Correct the hash here until the next
      # upstream release carries a good one.
      fixPaseoNpmDeps =
        pkg:
        pkg.override {
          npmDepsHash = "sha256-HFYBrCP62r6ZofazBIGSOnMhk8IIEmv+TFJMpqTIJQ8=";
        };
      paseoAttrs = prev.lib.optionalAttrs ((paseoPackages ? paseo) || (paseoPackages ? default)) {
        paseo = fixPaseoNpmDeps (paseoPackages.paseo or paseoPackages.default);
      };
      catppuccinPalette = builtins.fromJSON (builtins.readFile ../lib/catppuccin-palette.json);
      handyAttrs = prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        handy = handyPackages.${prev.stdenv.hostPlatform.system}.handy.overrideAttrs (oldAttrs: {
          postPatch = (oldAttrs.postPatch or "") + ''
            patch -p1 < ${
              prev.runCommand "handy-scale-and-catppuccin.patch"
                {
                  src = ./patches/handy/scale-and-catppuccin.patch;
                  mochaBase = catppuccinPalette.mocha.colors.base.hex;
                  mochaBlue = catppuccinPalette.mocha.colors.blue.hex;
                  mochaCrust = catppuccinPalette.mocha.colors.crust.hex;
                  mochaLavender = catppuccinPalette.mocha.colors.lavender.hex;
                  mochaOverlay0 = catppuccinPalette.mocha.colors.overlay0.hex;
                  mochaRed = catppuccinPalette.mocha.colors.red.hex;
                  mochaSubtext0 = catppuccinPalette.mocha.colors.subtext0.hex;
                  mochaText = catppuccinPalette.mocha.colors.text.hex;
                  mochaYellow = catppuccinPalette.mocha.colors.yellow.hex;
                }
                ''
                  substituteAll "$src" "$out"
                ''
            }
          '';
        });
      };
      hermesStdenv = final.unstable.stdenv // {
        isLinux = final.unstable.stdenv.hostPlatform.isLinux;
      };
    in
    rec {
      # The host module selects its dependency groups, so avoid the upstream
      # full-package Linux predicate until Hermes adopts hostPlatform.
      hermesAgent = inputs.hermes-agent.packages.${final.stdenv.hostPlatform.system}.minimal.override {
        stdenv = hermesStdenv;
      };

      fresh = final.unstable.fresh-editor;

      # Agent-adjacent tools sourced from the same pinned llm-agents flake as the
      # rest of the agent tooling.
      inherit (inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}) herdr;

      inherit (final.unstable) ollama;
      inherit (final.unstable) ollama-cuda;
      inherit (final.unstable) ollama-rocm;
      inherit (final.unstable) ollama-vulkan;

      inherit (final.unstable) llama-cpp;
      llama-cpp-rocm = llama-cpp.override { rocmSupport = true; };
      llama-cpp-vulkan = llama-cpp.override { vulkanSupport = true; };

      inherit (final.unstable) llama-swap;

      # Packages tracking the unstable channel ahead of their stable releases.
      inherit (final.unstable) apko;
      inherit (final.unstable) bun;
      inherit (final.unstable) cosign;
      inherit (final.unstable) hyprland;
      inherit (final.unstable) zed-editor;
      inherit (final.unstable) lima;
      inherit (final.unstable) melange;
      inherit (final.unstable) tmux;

      # Claude Code tracks the llm-agents flake on Linux (pinned alongside the
      # other agent tooling there) and unstable nixpkgs elsewhere.
      # https://github.com/numtide/llm-agents.nix
      claude-code =
        if final.stdenv.hostPlatform.isLinux then
          inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.claude-code
        else
          final.unstable.claude-code;
      inherit (final.unstable) librechat;
      inherit (final.unstable) playwright-driver;

      # The Claude desktop client comes from the llm-agents flake for its numtide
      # cache, so it tracks that pin alongside the rest of the agent tooling.
      # https://github.com/numtide/llm-agents.nix
      claude-desktop =
        if final.stdenv.hostPlatform.isLinux then
          inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.claude-desktop
        else
          throw "claude-desktop is only available on Linux";

      # The upstream desktop client reuses the patched paseo npm closure above.
      # The llm-agents package builds a separate large npm-deps derivation that
      # is brittle against registry fetch failures.
      paseo-desktop =
        if final.stdenv.hostPlatform.isLinux then
          inputs.paseo.packages.${final.stdenv.hostPlatform.system}.desktop.override {
            inherit (final) paseo;
          }
        else
          throw "paseo-desktop is only available on Linux";

      linuxPackages_6_12 = prev.linuxPackages_6_12.extend (
        _lpself: lpsuper: {
          mwprocapture = lpsuper.mwprocapture.overrideAttrs (_old: rec {
            pname = "mwprocapture";
            subVersion = "4420";
            version = "1.3.${subVersion}";
            src = prev.fetchurl {
              url = "http://www.magewell.com/files/support/ProCaptureForLinux_${version}.tar.gz";
              sha256 = "sha256-aX8vhousQQ48QPgfLjESGbBw26egDB46AmSkruUaM5g=";
            };
          });
        }
      );

      linuxPackages_6_18 = prev.linuxPackages_6_18.extend (
        _lpself: lpsuper: {
          mwprocapture = lpsuper.mwprocapture.overrideAttrs (old: rec {
            pname = "mwprocapture";
            subVersion = "4429";
            version = "1.3.${subVersion}";
            src = prev.fetchurl {
              url = "https://www.magewell.com/files/drivers/ProCaptureForLinux_${version}.tar.gz";
              sha256 = "sha256-sYwMVEAvYMKCn4DKQiCtnTxd1chMUd0atgswpC+CZ5g=";
            };
            meta = old.meta // {
              broken = false;
            };
          });
        }
      );

      linuxPackages = prev.linuxPackages.extend (
        _lpself: lpsuper: {
          mwprocapture = lpsuper.mwprocapture.overrideAttrs (old: rec {
            pname = "mwprocapture";
            subVersion = "4429";
            version = "1.3.${subVersion}";
            src = prev.fetchurl {
              url = "https://www.magewell.com/files/drivers/ProCaptureForLinux_${version}.tar.gz";
              sha256 = "sha256-sYwMVEAvYMKCn4DKQiCtnTxd1chMUd0atgswpC+CZ5g=";
            };
            meta = old.meta // {
              broken = false;
            };
          });
        }
      );

      linuxPackages_latest = prev.linuxPackages_latest.extend (
        _lpself: lpsuper: {
          mwprocapture = lpsuper.mwprocapture.overrideAttrs (old: rec {
            pname = "mwprocapture";
            subVersion = "4429";
            version = "1.3.${subVersion}";
            src = prev.fetchurl {
              url = "https://www.magewell.com/files/drivers/ProCaptureForLinux_${version}.tar.gz";
              sha256 = "sha256-sYwMVEAvYMKCn4DKQiCtnTxd1chMUd0atgswpC+CZ5g=";
            };
            meta = old.meta // {
              broken = false;
            };
          });
        }
      );

      # Gleam fails to build from source on Linux because a checked test makes a
      # network request that is unavailable in the sandbox. Append the upstream
      # skip flag from nixpkgs#529582. Remove this override once the fix reaches
      # the pinned nixos-26.05 channel.
      gleam = prev.gleam.overrideAttrs (oldAttrs: {
        checkFlags = (oldAttrs.checkFlags or [ ]) ++ [
          "--skip=tests::escript_success_with_dependency"
        ];
      });

      # Override rofi-unwrapped to remove desktop entries (this is where they come from!)
      rofi-unwrapped = prev.rofi-unwrapped.overrideAttrs (oldAttrs: {
        postInstall = (oldAttrs.postInstall or "") + ''
          rm -f $out/share/applications/rofi.desktop
          rm -f $out/share/applications/rofi-theme-selector.desktop
        '';
      });
    }
    // paseoAttrs
    // handyAttrs;

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstablePackages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    };
  };
}
