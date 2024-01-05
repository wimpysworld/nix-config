# This file defines overlays
{ inputs, ... }:
{
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: prev: import ../pkgs { pkgs = final; };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = _final: prev: {
    # https://github.com/NixOS/nixpkgs/issues/278277#issuecomment-1878292158
    keybase = prev.keybase.overrideAttrs ( old: rec {
      pname = "keybase";
      version = "6.2.4";
      src = prev.fetchFromGitHub {
        owner = "keybase";
        repo = "client";
        rev = "v${version}";
        hash = "sha256-z7vpCUK+NU7xU9sNBlQnSy9sjXD7/m8jSRKfJAgyyN8=";
      };
    });

	keybase-gui = prev.keybase-gui.overrideAttrs ( old: rec {
      pname = "keybase-gui";
      version = "6.2.4";
      versionSuffix = "20240101011938.ae7e4a1c15";
      src = prev.fetchurl {
        url = "https://s3.amazonaws.com/prerelease.keybase.io/linux_binaries/deb/keybase_${version + "-" + versionSuffix}_amd64.deb";
        hash = "sha256-XyGb9F83z8+OSjxOaO5k+h2qIY78ofS/ZfTXki54E5Q=";
      };
    });
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final) system;
      config.allowUnfree = true;
    };
  };
}
