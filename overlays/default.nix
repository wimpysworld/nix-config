# This file defines overlays
{ inputs, ... }:
{
  # This one brings our custom packages from the 'pkgs' directory
  localPackages = final: _prev: import ../pkgs final;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifiedPackages = final: prev: {
    inherit (final.unstable) ollama ollama-cuda ollama-rocm ollama-vulkan;
    # Override Python packages to fix Darwin-specific issues
    python3 = prev.python3.override {
      packageOverrides = _pyfinal: pyprev: {
        # Fix setproctitle test failures on Darwin with multiprocessing fork
        # See: https://github.com/NixOS/nixpkgs/issues/479313
        setproctitle = pyprev.setproctitle.overridePythonAttrs (old: {
          disabledTests =
            (old.disabledTests or [ ])
            ++ prev.lib.optionals prev.stdenv.isDarwin [
              "test_fork_segfault"
              "test_thread_fork_segfault"
            ];
        });
      };
    };

    python313 = prev.python313.override {
      packageOverrides = _pyfinal: pyprev: {
        # Fix setproctitle test failures on Darwin with multiprocessing fork
        # See: https://github.com/NixOS/nixpkgs/issues/479313
        setproctitle = pyprev.setproctitle.overridePythonAttrs (old: {
          disabledTests =
            (old.disabledTests or [ ])
            ++ prev.lib.optionals prev.stdenv.isDarwin [
              "test_fork_segfault"
              "test_thread_fork_segfault"
            ];
        });
      };
    };

    # Fix inetutils build failure on Darwin with clang 21
    # gnulib's error() macro passes dgettext() results as format strings,
    # triggering -Werror,-Wformat-security in openat-die.c
    # See: https://github.com/NixOS/nixpkgs/issues/488689
    inetutils = prev.inetutils.overrideAttrs (
      old:
      prev.lib.optionalAttrs prev.stdenv.isDarwin {
        env = (old.env or { }) // {
          NIX_CFLAGS_COMPILE = toString [
            (old.env.NIX_CFLAGS_COMPILE or "")
            "-Wno-format-security"
          ];
        };
      }
    );

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
          meta = old.meta // { broken = false; };
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
