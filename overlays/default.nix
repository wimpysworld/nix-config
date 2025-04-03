# This file defines overlays
{ inputs, ... }:
{
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = _final: prev: {
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

    custom-caddy = import ./custom-caddy.nix { pkgs = prev; };

    gitkraken = prev.gitkraken.overrideAttrs (old: rec {
      version = "11.0.0";

      src = {
        x86_64-linux = prev.fetchzip {
          url = "https://release.axocdn.com/linux/GitKraken-v${version}.tar.gz";
          hash = "sha256-rUOBCxquTw5wh5cK0AEGmIMq808tZQe5E90V7lGRuNY=";
        };

        x86_64-darwin = prev.fetchzip {
          url = "https://release.axocdn.com/darwin/GitKraken-v${version}.zip";
          hash = "";
        };

        aarch64-darwin = prev.fetchzip {
          url = "https://release.axocdn.com/darwin-arm64/GitKraken-v${version}.zip";
          hash = "";
        };
      }.${prev.stdenv.hostPlatform.system} or (throw "Unsupported system: ${prev.stdenv.hostPlatform.system}");
    });

    linuxPackages_6_12 = prev.linuxPackages_6_12.extend (_lpself: lpsuper: {
      mwprocapture = lpsuper.mwprocapture.overrideAttrs ( old: rec {
        pname = "mwprocapture";
        subVersion = "4418";
        version = "1.3.${subVersion}";
        src = prev.fetchurl {
          url = "https://www.magewell.com/files/drivers/ProCaptureForLinux_${version}.tar.gz";
          sha256 = "sha256-ZUqJkARhaMo9aZOtUMEdiHEbEq10lJO6MkGjEDnfx1g=";
        };
      });
    });

    resources = prev.resources.overrideAttrs (_old: rec {
      pname = "resources";
      version = "1.7.1";
      src = prev.fetchFromGitHub {
        owner = "nokyan";
        repo = "resources";
        rev = "refs/tags/v${version}";
        hash = "sha256-SHawaH09+mDovFiznZ+ZkUgUbv5tQGcXBgUGrdetOcA=";
      };

      cargoDeps = prev.rustPlatform.fetchCargoTarball {
        inherit src;
        name = "resources-${version}";
        hash = "sha256-tUD+gx9nQiGWKKRPcR7OHbPvU2j1dQjYck7FF9vYqSQ=";
      };
    });

    wavebox = prev.wavebox.overrideAttrs (_old: rec {
      pname = "wavebox";
      version = "10.134.18-2";
      src = prev.fetchurl {
        url = "https://download.wavebox.app/stable/linux/deb/amd64/wavebox_${version}_amd64.deb";
        sha256 = "sha256-L2EXQuDHpHzqIeWeDl3rYzwrF/1sMtRIQSuGaVUEW5o=";
      };
    });
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final) system;
      config.allowUnfree = true;
    };
  };
}
