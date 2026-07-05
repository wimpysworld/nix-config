# This file defines overlays
{ inputs, ... }:
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
      # Only the Paseo daemon and CLI come from the upstream Paseo flake now; the
      # desktop client is sourced separately from the llm-agents flake below.
      #
      # The v0.1.103 tag ships a wrong npm-deps fixed-output hash, which breaks
      # the build with a hash mismatch. Correct the hash here until the next
      # upstream release carries a good one.
      fixPaseoNpmDeps =
        pkg:
        pkg.overrideAttrs (oldAttrs: {
          npmDeps = oldAttrs.npmDeps.overrideAttrs {
            outputHash = "sha256-o+VzG7lK0qpyUXF4F5Hk08ooW5CPoZSsOG7DyIReUKQ=";
          };
        });
      paseoAttrs = prev.lib.optionalAttrs ((paseoPackages ? paseo) || (paseoPackages ? default)) {
        paseo = fixPaseoNpmDeps (paseoPackages.paseo or paseoPackages.default);
      };
    in
    rec {
      hermesAgent = inputs.hermes-agent.packages.${final.stdenv.hostPlatform.system}.default;

      # Fresh editor sourced directly from the upstream flake input now that the
      # theme-key-resolution fix has landed there.
      inherit (inputs.fresh.packages.${final.stdenv.hostPlatform.system}) fresh;

      voxtype = inputs.voxtype.packages.${final.stdenv.hostPlatform.system}.default;
      voxtype-vulkan = inputs.voxtype.packages.${final.stdenv.hostPlatform.system}.vulkan;
      voxtype-rocm = inputs.voxtype.packages.${final.stdenv.hostPlatform.system}.rocm;
      voxtype-onnx = inputs.voxtype.packages.${final.stdenv.hostPlatform.system}.onnx;
      voxtype-onnx-cuda = inputs.voxtype.packages.${final.stdenv.hostPlatform.system}.onnx-cuda;
      voxtype-onnx-migraphx = inputs.voxtype.packages.${final.stdenv.hostPlatform.system}.onnx-migraphx;
      voxtype-osd-native = inputs.voxtype.packages.${final.stdenv.hostPlatform.system}.osd-native;
      voxtype-osd-gtk4 = inputs.voxtype.packages.${final.stdenv.hostPlatform.system}.osd-gtk4;

      # Agent-adjacent tools sourced from the same pinned llm-agents flake as the
      # rest of the agent tooling.
      inherit (inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}) herdr;
      inherit (inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}) hunk;

      inherit (final.unstable) ollama;
      inherit (final.unstable) ollama-cuda;
      inherit (final.unstable) ollama-rocm;
      inherit (final.unstable) ollama-vulkan;

      inherit (final.unstable) llama-cpp;
      llama-cpp-rocm = llama-cpp.override { rocmSupport = true; };
      llama-cpp-vulkan = llama-cpp.override { vulkanSupport = true; };

      inherit (final.unstable) llama-swap;
      inherit (final.unstable) playwright-mcp;

      # Packages tracking the unstable channel ahead of their stable releases.
      inherit (final.unstable) bun;
      inherit (final.unstable) zed-editor;
      inherit (final.unstable) lima;

      nh-unwrapped = prev.nh-unwrapped.overrideAttrs (oldAttrs: {
        postPatch = (oldAttrs.postPatch or "") + ''
          substituteInPlace crates/nh-search/src/search.rs \
            --replace-fail "latest-46-" "latest-48-"
        '';
      });

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

      # The Paseo desktop client comes from the llm-agents flake for its numtide
      # cache, so it tracks that pin independently of the upstream paseo daemon.
      # https://github.com/numtide/llm-agents.nix
      paseo-desktop =
        if final.stdenv.hostPlatform.isLinux then
          inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.paseo-desktop
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

      # Track wezterm from unstable, and carry PR 7737, which adds the cursor
      # trail and smear effects, until it lands upstream. Remove the patch after
      # the next wezterm bump that includes the change.
      # https://github.com/wezterm/wezterm/pull/7737
      wezterm = final.unstable.wezterm.overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or [ ]) ++ [
          (final.fetchpatch {
            name = "wezterm-cursor-trail-smear-pr7737.patch";
            url = "https://patch-diff.githubusercontent.com/raw/wezterm/wezterm/pull/7737.diff";
            hash = "sha256-JoYBUmOE0paR/oIfE2YS5xHlTXXHFwbJVsg7KqGFmrs=";
          })
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
    // paseoAttrs;

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstablePackages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    };
  };
}
