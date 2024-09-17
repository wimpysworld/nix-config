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

    #linuxPackages_latest = prev.linuxPackages_latest.extend (_lpself: lpsuper: {
    #  mwprocapture = lpsuper.mwprocapture.overrideAttrs ( old: rec {
    #    pname = "mwprocapture";
    #    subVersion = "4390";
    #    version = "1.3.0.${subVersion}";
    #    src = prev.fetchurl {
    #      url = "https://www.magewell.com/files/drivers/ProCaptureForLinux_${subVersion}.tar.gz";
    #      sha256 = "sha256-a2cU7PYQh1KR5eeMhMNx2Sc3HHd7QvCG9+BoJyVPp1Y=";
    #    };
    #  });
    #});

    # TODO: upgrade-hint; Remove this for >= 24.11
    openasar = prev.openasar.overrideAttrs (_old: rec {
      pname = "openasar";
      version = "0-unstable-2024-09-06";
      src = prev.fetchFromGitHub {
        owner = "GooseMod";
        repo = "OpenAsar";
        rev = "f92ee8c3dc6b6ff9829f69a1339e0f82a877929c";
        hash = "sha256-V2oZ0mQbX+DHDZfTj8sV4XS6r9NOmJYHvYOGK6X/+HU=";
      };
    });

    hyprland = prev.hyprland.overrideAttrs (_old: rec {
      postPatch = _old.postPatch + ''
        sed -i 's|Exec=Hyprland|Exec=hypr-launch|' example/hyprland.desktop
      '';
    });

    wavebox = prev.wavebox.overrideAttrs (_old: rec {
      pname = "wavebox";
      version = "10.128.5-2";
      src = prev.fetchurl {
        url = "https://download.wavebox.app/stable/linux/deb/amd64/wavebox_${version}_amd64.deb";
        sha256 = "sha256-eIiFiRlmnARtyd8YHUHrjDaaF8kQYvcOa2AwT3071Ho=";
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
