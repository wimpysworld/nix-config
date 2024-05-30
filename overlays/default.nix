# This file defines overlays
{ inputs, ... }:
{
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs { pkgs = final; };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = _final: prev: {

    librist = prev.librist.overrideAttrs ( _old: rec {
      pname = "librist";
      version = "0.2.10";
      src = prev.fetchFromGitLab {
        domain = "code.videolan.org";
        owner = "rist";
        repo = "librist";
        rev = "v${version}";
        hash = "sha256-8N4wQXxjNZuNGx/c7WVAV5QS48Bff5G3t11UkihT+K0=";
      };
      patches = [ ./darwin.patch ];
    });

    #linuxPackages_latest = prev.linuxPackages_latest.extend (_lpself: lpsuper: {
    #  mwprocapture = lpsuper.mwprocapture.overrideAttrs ( _old: rec {
    #    pname = "mwprocapture";
    #    subVersion = "4390";
    #    version = "1.3.0.${subVersion}";
    #    src = prev.fetchurl {
    #      url = "https://www.magewell.com/files/drivers/ProCaptureForLinux_${subVersion}.tar.gz";
    #      sha256 = "sha256-a2cU7PYQh1KR5eeMhMNx2Sc3HHd7QvCG9+BoJyVPp1Y=";
    #    };
    #  });
    #});

    nelua = prev.nelua.overrideAttrs ( _old: rec {
      pname = "nelua";
      version = "unstable-2024-02-03";

      src = prev.fetchFromGitHub {
        owner = "edubart";
        repo = "nelua-lang";
        rev = "05a2633a18dfdde7389394b9289da582c10e79bc";
        hash = "sha256-oRW+pCB10T0A6fEPP3S+8iurQ2J5WMpQlCYScfIk07c=";
      };
    });

    syncthingtray = prev.syncthingtray.overrideAttrs ( _old: rec {
      pname = "syncthingtray";
      version = "1.4.12";
      src = prev.fetchFromGitHub {
        owner = "Martchus";
        repo = "syncthingtray";
        rev = "v${version}";
        sha256 = "sha256-KfJ/MEgQdvzAM+rnKGMsjnRrbFeFu6F8Or+rgFNLgFI=";
      };
    });

    wavebox = prev.wavebox.overrideAttrs ( _old: rec {
      pname = "wavebox";
      version = "10.124.17-2";
      src = prev.fetchurl {
        url = "https://download.wavebox.app/stable/linux/tar/Wavebox_${version}.tar.gz";
        sha256 = "sha256-RS1/zs/rFWsj29BrT8Mb2IXgy9brBsQypxfvnd7pKl0=";
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
