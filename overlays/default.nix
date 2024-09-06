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
      '';
    });

    blueman = prev.blueman.overrideAttrs (_old: rec {
      pname = "blueman";
      version = "2.4.3";
      src = prev.fetchurl {
        url = "https://github.com/blueman-project/blueman/releases/download/${version}/${pname}-${version}.tar.xz";
        sha256 = "sha256-vfxJkJdCy3koj4oR1vZmt1wnE7kcCF5tDdMpQ0eT/oU=";
      };
    });

    # https://discourse.nixos.org/t/davinci-resolve-studio-install-issues/37699/44
    # https://theholytachanka.com/posts/setting-up-resolve/
    davinci-resolve = prev.davinci-resolve.override (old: {
      buildFHSEnv =
        a:
        (old.buildFHSEnv (
          a
          // {
            extraBwrapArgs = a.extraBwrapArgs ++ [ "--bind /run/opengl-driver/etc/OpenCL /etc/OpenCL" ];
          }
        ));
    });
    davinci-resolve-studio = prev.davinci-resolve-studio.override (old: {
      buildFHSEnv =
        a:
        (old.buildFHSEnv (
          a
          // {
            extraBwrapArgs = a.extraBwrapArgs ++ [ "--bind /run/opengl-driver/etc/OpenCL /etc/OpenCL" ];
          }
        ));
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

    openasar = prev.openasar.overrideAttrs (_old: rec {
      pname = "openasar";
      version = "0-unstable-2024-06-30";
      src = prev.fetchFromGitHub {
        owner = "GooseMod";
        repo = "OpenAsar";
        rev = "5c875eb048e96543f1ec711fae522ace5e4a836c";
        hash = "sha256-dlf4X+2W2GfL2E46ZM35PqpcoKHoZ4fhroOCLpye1D0=";
      };
    });

    hyprland = prev.hyprland.overrideAttrs (_old: rec {
      postPatch = _old.postPatch + ''
        sed -i 's|Exec=Hyprland|Exec=hypr-launch|' example/hyprland.desktop
      '';
    });

    #wavebox = prev.wavebox.overrideAttrs ( old: rec {
    #  pname = "wavebox";
    #  version = "10.125.53-2";
    #  src = prev.fetchurl {
    #    url = "https://download.wavebox.app/stable/linux/tar/Wavebox_${version}.tar.gz";
    #    sha256 = "sha256-ymmo0SaE71wJe8i7qAiEvPdWIA5ePUfOS8JmhxFmQvI=";
    #  };
    #});
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
