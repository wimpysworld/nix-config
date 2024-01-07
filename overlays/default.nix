# This file defines overlays
{ inputs, ... }:
{
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs { pkgs = final; };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = _final: prev: {
    # https://github.com/NixOS/nixpkgs/issues/278277#issuecomment-1878292158
    keybase = prev.keybase.overrideAttrs ( _old: rec {
      pname = "keybase";
      version = "6.2.4";
      src = prev.fetchFromGitHub {
        owner = "keybase";
        repo = "client";
        rev = "v${version}";
        hash = "sha256-z7vpCUK+NU7xU9sNBlQnSy9sjXD7/m8jSRKfJAgyyN8=";
      };
    });

    keybase-gui = prev.keybase-gui.overrideAttrs ( _old: rec {
      pname = "keybase-gui";
      version = "6.2.4";
      versionSuffix = "20240101011938.ae7e4a1c15";
      src = prev.fetchurl {
        url = "https://s3.amazonaws.com/prerelease.keybase.io/linux_binaries/deb/keybase_${version + "-" + versionSuffix}_amd64.deb";
        hash = "sha256-XyGb9F83z8+OSjxOaO5k+h2qIY78ofS/ZfTXki54E5Q=";
      };
    });

    nelua = prev.nelua.overrideAttrs ( _old: rec {
      pname = "nelua";
      version = "unstable-2023-11-19";
      src = prev.fetchFromGitHub {
        owner = "edubart";
        repo = "nelua-lang";
        rev = "e82695abf0a68a30a593cefb0bf1143cf9e14b6b";
        hash = "sha256-Srgoq07JQirxmZcDvw4UdfoYZ5HFT0PbYPoHY99BW/c=";
      };
    });

    wavebox = prev.wavebox.overrideAttrs ( _old: rec {
      pname = "wavebox";
      version = "10.120.20-2";
      src = prev.fetchurl {
        url = "https://download.wavebox.app/stable/linux/tar/Wavebox_${version}.tar.gz";
        sha256 = "sha256-ICi/0sWze7+oYEnhsU9ZnlDSRmnG3QgD0tQ3FRRgjeQ=";
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
