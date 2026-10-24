{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  palette = catppuccinPalette;
  textColor = palette.mkRgba "text" palette.alpha.opaque;
  # The user stylesheet loads above the SwayOSD default stylesheet, so it
  # only overrides the rules that it sets. The 8px radius matches the Mango
  # blur corners and the Fuzzel border.
  style = pkgs.writeText "swayosd-style.css" ''
    window#osd {
      border-radius: 8px;
      border: none;
      background: ${palette.mkRgba "base" palette.alpha.surface};
    }

    window#osd #container {
      margin: 16px;
    }

    window#osd image,
    window#osd label {
      color: ${textColor};
    }

    window#osd trough,
    window#osd segment {
      background: ${palette.mkRgba "surface1" palette.alpha.opaque};
    }

    window#osd progress,
    window#osd segment.active {
      background: ${palette.mkRgba "blue" palette.alpha.opaque};
    }
  '';
in
lib.mkIf (host.is.linux && host.is.workstation) {
  # SwayOSD shows the volume, brightness and caps lock on-screen display. The
  # Home Manager service binds to wayland.systemd.target, which the compositor
  # hub sets to the selected compositor's session target. The default maximum
  # volume is already 100, which matches the Waybar max-volume.
  services.swayosd = {
    enable = true;
    stylePath = style;
    # The bottom edge of the OSD sits at 80 per cent of the screen height.
    topMargin = 0.8;
  };
}
