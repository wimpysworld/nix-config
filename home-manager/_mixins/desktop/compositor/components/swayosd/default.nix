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
  # only overrides the rules that it sets. The size follows the old avizo
  # OSD: about 480 px wide, 32 px padding, a 16 px bar and a 1 px blue
  # border. The background uses the scrim level, so the blurred desktop
  # shows through. The 8px radius matches the Mango blur corners and Fuzzel.
  style = pkgs.writeText "swayosd-style.css" ''
    window#osd {
      border-radius: 8px;
      border: 1px solid ${palette.mkRgba "blue" palette.alpha.opaque};
      background: ${palette.mkRgba "base" palette.alpha.scrim};
    }

    window#osd #container {
      margin: 32px;
    }

    window#osd image,
    window#osd label {
      color: ${textColor};
    }

    /* SwayOSD fixes the icon at 32 px in code. Scale it when drawn, and
       add a margin so that the box makes room for the larger icon. The
       scaled icon fills a 16 px margin exactly, so the right margin is
       wider to leave a gap before the bar. */
    window#osd image {
      -gtk-icon-transform: scale(2);
      margin: 16px 32px 16px 16px;
    }

    window#osd progressbar,
    window#osd segmentedprogress {
      min-width: 340px;
      min-height: 16px;
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
