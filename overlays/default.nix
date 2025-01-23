# This file defines overlays
{ inputs, ... }:
{
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = _final: prev: {
    bemoji = prev.bemoji.overrideAttrs (_old: rec {
      postPatch = ''
        sed -i 's/🔍/"󰞅 "/g' bemoji
        sed -i 's/fuzzel -d/fuzzel -d -w 48/' bemoji
      '';
    });

    custom-caddy = import ./custom-caddy.nix { pkgs = prev; };

    gitkraken = prev.gitkraken.overrideAttrs (old: rec {
      version = "10.6.2";

      src = {
        x86_64-linux = prev.fetchzip {
          url = "https://release.axocdn.com/linux/GitKraken-v${version}.tar.gz";
          hash = "sha256-E/9BR4PE5QF075+NgJZTtgDoShHEqeRcoICnMLt3RuY=";
        };

        x86_64-darwin = prev.fetchzip {
          url = "https://release.axocdn.com/darwin/GitKraken-v${version}.zip";
          hash = "sha256-gCiZN+ivXEF5KLas7eZn9iWfXcDGwf1gXK1ejY2C4xs=";
        };

        aarch64-darwin = prev.fetchzip {
          url = "https://release.axocdn.com/darwin-arm64/GitKraken-v${version}.zip";
          hash = "sha256-1zd57Kqi5iKHw/dNqLQ7jVAkNFvkFeqQbZPN32kF9IU=";
        };
      }.${prev.stdenv.hostPlatform.system} or (throw "Unsupported system: ${prev.stdenv.hostPlatform.system}");
    });

    hyprland = prev.hyprland.overrideAttrs (_old: rec {
      postPatch = _old.postPatch + ''
        sed -i 's|Exec=Hyprland|Exec=hypr-launch|' example/hyprland.desktop
      '';
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
      version = "1.7.0";
      src = prev.fetchFromGitHub {
        owner = "nokyan";
        repo = "resources";
        rev = "refs/tags/v${version}";
        hash = "sha256-mnOpWVJTNGNdGd6fMIZl3AOF4NbtMm1XS8QFqfAF/18=";
      };

      cargoDeps = prev.rustPlatform.fetchCargoTarball {
        inherit src;
        name = "resources-${version}";
        hash = "sha256-vIqtKJxKQ/mHFcB6IxfX27Lk2ID/W+M4hQnPB/aExa4=";
      };
    });

    wavebox = prev.wavebox.overrideAttrs (_old: rec {
      pname = "wavebox";
      version = "10.131.15-2";
      src = prev.fetchurl {
        url = "https://download.wavebox.app/stable/linux/deb/amd64/wavebox_${version}_amd64.deb";
        sha256 = "sha256-rGMkXs5w/NrIYOKPArCLBMUDoMnvQqggo91viyJUfj4=";
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
