# This file defines overlays
{ inputs, ... }:
{
  # This one brings our custom packages from the 'pkgs' directory
  localPackages = final: _prev: import ../pkgs final;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifiedPackages = final: prev: rec {
    hermesAgent = inputs.hermes-agent.packages.${final.stdenv.hostPlatform.system}.default;

    # Fresh editor sourced directly from the upstream flake input now that the
    # theme-key-resolution fix has landed there.
    inherit (inputs.fresh.packages.${final.stdenv.hostPlatform.system}) fresh;

    ferdium = prev.ferdium.overrideAttrs (_old: rec {
      version = "7.1.3-nightly.3";
      src = prev.fetchurl {
        url = "https://github.com/ferdium/ferdium-app/releases/download/v${version}/Ferdium-linux-${version}-${
          {
            x86_64-linux = "amd64";
            aarch64-linux = "arm64";
          }
          .${final.stdenv.hostPlatform.system}
        }.deb";
        hash =
          {
            x86_64-linux = "sha256-FauUQO3FucLpIKxGAalCaD5jPAajXPR1X4yXHBmzqMI=";
            aarch64-linux = "sha256-wAz2Z0QAkcR/oWdE4AaH9kQoMvOSdWHpLGYjqTJIui4=";
          }
          .${final.stdenv.hostPlatform.system};
      };
    });

    inherit (final.unstable) ollama;
    inherit (final.unstable) ollama-cuda;
    inherit (final.unstable) ollama-rocm;
    inherit (final.unstable) ollama-vulkan;

    inherit (final.unstable) llama-cpp;
    llama-cpp-rocm = llama-cpp.override { rocmSupport = true; };
    llama-cpp-vulkan = llama-cpp.override { vulkanSupport = true; };

    inherit (final.unstable) llama-swap;
    inherit (final.unstable) harper;
    inherit (final.unstable) playwright-mcp;

    # Packages tracking the unstable channel ahead of their stable releases.
    inherit (final.unstable) bun;
    inherit (final.unstable) zed-editor;
    inherit (final.unstable) lima;
    inherit (final.unstable) notesnook;
    inherit (final.unstable) superfile;
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

    linuxPackages = prev.linuxPackages.extend (
      _lpself: lpsuper: {
        mwprocapture = lpsuper.mwprocapture.overrideAttrs (_old: rec {
          pname = "mwprocapture";
          subVersion = "4429";
          version = "1.3.${subVersion}";
          src = prev.fetchurl {
            url = "https://www.magewell.com/files/drivers/ProCaptureForLinux_${version}.tar.gz";
            sha256 = "sha256-sYwMVEAvYMKCn4DKQiCtnTxd1chMUd0atgswpC+CZ5g=";
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

    linuxPackages_6_19 = prev.linuxPackages_6_19.extend (
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

    # Override rofi-unwrapped to remove desktop entries (this is where they come from!)
    rofi-unwrapped = prev.rofi-unwrapped.overrideAttrs (oldAttrs: {
      postInstall = (oldAttrs.postInstall or "") + ''
        rm -f $out/share/applications/rofi.desktop
        rm -f $out/share/applications/rofi-theme-selector.desktop
      '';
    });
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstablePackages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    };
  };
}
