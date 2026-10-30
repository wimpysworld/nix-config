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
      # Make the password mask dot size and spacing configurable through
      # visuals.input.mask_size and visuals.input.mask_spacing. Add
      # visuals.placeholder.font_size and visuals.placeholder.opacity, so the
      # placeholder can be larger than the input text and fully opaque.
      veilaAttrs = prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        veila = inputs.veila.packages.${prev.stdenv.hostPlatform.system}.default.overrideAttrs (oldAttrs: {
          patches = (oldAttrs.patches or [ ]) ++ [
            ./patches/veila/mask-size.patch
            ./patches/veila/placeholder-style.patch
          ];
        });
      };
    in
    rec {
      cage = prev.cage.overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or [ ]) ++ [ ./patches/cage/teardown-order.patch ];
      });

      fresh = final.unstable.fresh-editor;

      herdr = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.herdr;

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
      inherit (final.unstable) framework-tool;
      inherit (final.unstable) framework-tool-tui;
      inherit (final.unstable) mango;
      inherit (final.unstable) zed-editor;
      inherit (final.unstable) markless;
      inherit (final.unstable) mas;
      inherit (final.unstable) melange;
      inherit (final.unstable) swayosd;
      inherit (final.unstable) tmux;
      inherit (final.unstable) wezterm;

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

      # Prowler 5.12.3 in nixos-26.05 fails to build because python3.13-imageio
      # 2.37.2 fails two tests against pillow 13.0.0, and mcp-nixos 2.4.3 fails
      # to build because python3.13-fastmcp 3.2.3 fails its proxy client tests.
      # Use the cached unstable builds until nixos-26.05 caches the fixes.
      inherit (final.unstable) mcp-nixos prowler;

      # Determinate Nix 3.23 emits unknown activity and result types, which nom
      # 2.2.0 rejects with a ParseNixJSONMessageError. Apply the upstream fix
      # that handles unknown activity and result types gracefully. Remove this
      # override once a nom release that includes the fix reaches nixpkgs.
      # https://github.com/maralorn/nix-output-monitor/issues/320
      # https://github.com/maralorn/nix-output-monitor/pull/321
      nix-output-monitor = prev.nix-output-monitor.override {
        extraComposeFunctions = [
          (prev.haskell.lib.compose.appendPatch (
            prev.fetchpatch2 {
              url = "https://github.com/maralorn/nix-output-monitor/commit/d48ff7935da72a5a5764ee8c5358d38417b0f337.patch";
              relative = "nix-output-monitor";
              hash = "sha256-OVem8p/Q2MAo+fZk2MmqO8cBANDFRJQdtpd6ypUIdP0=";
            }
          ))
        ];
      };

      # Override rofi-unwrapped to remove desktop entries (this is where they come from!)
      rofi-unwrapped = prev.rofi-unwrapped.overrideAttrs (oldAttrs: {
        postInstall = (oldAttrs.postInstall or "") + ''
          rm -f $out/share/applications/rofi.desktop
          rm -f $out/share/applications/rofi-theme-selector.desktop
        '';
      });
    }
    // handyAttrs
    // veilaAttrs;

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstablePackages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    };
  };
}
