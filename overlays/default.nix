# This file defines overlays
{ inputs, ... }:
{
  # This one brings our custom packages from the 'pkgs' directory
  localPackages = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifiedPackages = final: prev: {
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

    # Override avizo to use a specific commit that includes these fixes:
    # - https://github.com/heyjuvi/avizo/pull/76 (fix options of lightctl)
    # - https://github.com/heyjuvi/avizo/pull/73 (chore: fix size of dark theme icons)
    avizo = prev.avizo.overrideAttrs (_old: rec {
      pname = "avizo";
      version = "1.3-unstable-2024-11-03";
      src = prev.fetchFromGitHub {
        owner = "misterdanb";
        repo = "avizo";
        rev = "5efaa22968b2cc1a3c15a304cac3f22ec2727b17";
        sha256 = "sha256-KYQPHVxjvqKt4d7BabplnrXP30FuBQ6jQ1NxzR5U7qI=";
      };
    });

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
          subVersion = "4490";
          version = "1.3.${subVersion}";
          src = prev.fetchurl {
            url = "https://www.magewell.com/files/drivers/ProCaptureForLinuxPUBLIC_${version}.tar.gz";
            sha256 = "sha256-W/HqTQsJKnIUMC13bFuwdMiNABftmKv0qLSFU3bCFAc=";
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
