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

    bemoji = prev.bemoji.overrideAttrs (_old: rec {
      postPatch = ''
        sed -i 's/🔍/"󰞅 "/g' bemoji
        sed -i 's/fuzzel -d/fuzzel -d -w 48/' bemoji
      '';
    });

    custom-caddy = import ./custom-caddy.nix { pkgs = prev; };

    gitkraken = prev.gitkraken.overrideAttrs (old: rec {
      version = "10.7.0";

      src = {
        x86_64-linux = prev.fetchzip {
          url = "https://release.axocdn.com/linux/GitKraken-v${version}.tar.gz";
          hash = "sha256-fNx3mZnoMkEd1RlvcEmnncX0cLJhRjbf2t4CfB5eRl4=";
        };

        x86_64-darwin = prev.fetchzip {
          url = "https://release.axocdn.com/darwin/GitKraken-v${version}.zip";
          hash = "sha256-FLNzB1MvW943DDBs5EmxOWx31CMm2KWXrXp6EjfkPeQ=";
        };

        aarch64-darwin = prev.fetchzip {
          url = "https://release.axocdn.com/darwin-arm64/GitKraken-v${version}.zip";
          hash = "sha256-+uEpm9A9zkTMWL2XccWFTkuhFdZMJUZHSD3FinNsRyA=";
        };
      }.${prev.stdenv.hostPlatform.system} or (throw "Unsupported system: ${prev.stdenv.hostPlatform.system}");
    });

    linuxPackages_6_12 = prev.linuxPackages_6_12.extend (_lpself: lpsuper: {
      mwprocapture = lpsuper.mwprocapture.overrideAttrs ( old: rec {
        pname = "mwprocapture";
        subVersion = "4407";
        version = "1.3.0.${subVersion}";
        src = prev.fetchurl {
          url = "https://www.magewell.com/files/drivers/ProCaptureForLinux_${subVersion}.tar.gz";
          sha256 = "sha256-wzOwnaxaD4Cm/cdc/sXHEzYZoN6b/kivDPvXRsC+Aig=";
        };
        postPatch = let
          kernelVersion = lpsuper.kernel.version;
          needsPatch = prev.lib.versionAtLeast kernelVersion "6.12";
        in ''
          ${old.postPatch or ""}
          ${if needsPatch then ''
            sed -i 's/no_llseek/noop_llseek/' src/sources/avstream/mw-event-dev.c
          '' else ""}
        '';
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
      version = "10.133.4-2";
      src = prev.fetchurl {
        url = "https://download.wavebox.app/stable/linux/deb/amd64/wavebox_${version}_amd64.deb";
        sha256 = "sha256-E7Hvz8HrWLTs7H6wPVN89PVTPWL0T+DjpnIGS17xw2s=";
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
