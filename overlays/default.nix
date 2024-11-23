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
