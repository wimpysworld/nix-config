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

    gitkraken = prev.gitkraken.overrideAttrs (old: rec {
      version = "11.1.1";

      src = {
        x86_64-linux = prev.fetchzip {
          url = "https://api.gitkraken.dev/releases/production/linux/x64/${version}/gitkraken-amd64.tar.gz";
          hash = "sha256-VKJjwWAhN53h9KU06OviIEL5SiIDwPtb7cKJSR4L9YA=";
        };

        x86_64-darwin = prev.fetchzip {
          url = "https://api.gitkraken.dev/releases/production/darwin/x64/${version}/installGitKraken.dmg";
          hash = "";
        };

        aarch64-darwin = prev.fetchzip {
          url = "https://api.gitkraken.dev/releases/production/darwin/arm64/${version}/installGitKraken.dmg";
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
