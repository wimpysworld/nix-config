{ config, desktop, lib, pkgs, ... }:
{
  imports = [
    ../../../desktop/deckmaster-xl.nix
  ];

  home = {
    file = {
      "${config.xdg.configHome}/autostart/screenlayout.desktop".text = lib.mkIf (desktop == "pantheon") "
        [Desktop Entry]
        Name=xrandr screenlayout
        Comment=xrandr screenlayout
        Type=Application
        Exec=${pkgs.xorg.xrandr}/bin/xrandr --output DisplayPort-0 --primary --mode 2560x1440 --pos 0x1080 --rotate normal --output DisplayPort-1 --mode 2560x1440 --pos 2560x1080 --rotate normal --output DisplayPort-2 --mode 1920x1080 --pos 640x2520 --rotate normal --output HDMI-A-0 --mode 1920x1080 --pos 2560x0 --rotate normal --output DP-1-0 --off --output DP-1-1 --off --output DP-1-2 --off --output DP-1-3 --off --output DP-1-4 --off --output DP-1-5 --off --output DP-1-6 --off --output DP-1-7 --off
        Categories=
        Terminal=false
        NoDisplay=true
        StartupNotify=false";
    };

    # Disable unused audio devices
    # pactl list
    # - alsa_card.pci-0000_30_00.1:          NVIDIA (HDA NVidia) T1000
    # - alsa_card.pci-0000_33_00.1:          Navi 21/23 HDMI/DP Audio Controller
    # - alsa_card.pci-0000_26_00.0:          Magewell (00-00 Pro Capture Quad HDMI)
    # - alsa_card.pci-0000_27_00.0:          Magewell (00-01 Pro Capture Quad HDMI)
    # - alsa_card.pci-0000_28_00.0:          Magewell (00-02 Pro Capture Quad HDMI) (keep, device capture is used by OBS Studio)
    # - alsa_card.pci-0000_29_00.0:          Magewell (00-03 Pro Capture Quad HDMI)
    file.".config/wireplumber/main.lua.d/51-disable-cards.lua".text = ''
      rule = {
        matches = {
          {
            { "device.name", "equals", "alsa_card.pci-0000_30_00.1" },
            { "device.name", "equals", "alsa_card.pci-0000_33_00.1" },
            { "device.name", "equals", "alsa_card.pci-0000_26_00.0" },
            { "device.name", "equals", "alsa_card.pci-0000_27_00.0" },
            { "device.name", "equals", "alsa_card.pci-0000_29_00.0" },
          },
        },
        apply_properties = {
          ["device.disabled"] = true,
        },
      }
      table.insert(alsa_monitor.rules,rule)
    '';
  };

  dconf.settings = with lib.hm.gvariant; {
    "org/gnome/desktop/background" = {
      picture-options = "zoom";
      picture-uri = "file://${config.home.homeDirectory}/Pictures/Determinate/DeterminateColorway-2560x1440.png";
    };
  };
}
