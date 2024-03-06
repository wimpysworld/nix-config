{ config, desktop, lib, pkgs, ... }:
{
  home = {
    # Disable unused audio devices
    # pactl list
    # - alsa_card.pci-0000_34_00.1: NVIDIA (HDA NVidia) T600
    # - alsa_card.pci-0000_26_00.0: Magewell (00-00 Pro Capture Quad HDMI)
    # - sa_card.usb-AVerMedia_Technologies__Inc._Live_Streamer_CAM_513_5203711200146-00
    file = {
      "${config.xdg.configHome}/wireplumber/main.lua.d/51-disable-cards.lua".text = ''
        rule = {
        matches = {
            {
              { "device.name", "equals", "alsa_card.pci-0000_34_00.1" },
              { "device.name", "equals", "alsa_card.pci-0000_26_00.0" },
              { "device.name", "equals", "alsa_card.usb-AVerMedia_Technologies__Inc._Live_Streamer_CAM_513_5203711200146-00" },
            },
          },
          apply_properties = {
            ["device.disabled"] = true,
          },
        }
        table.insert(alsa_monitor.rules,rule)
      '';

      "${config.xdg.configHome}/autostart/screenlayout.desktop".text = lib.mkIf (desktop == "pantheon") ''
          [Desktop Entry]
          Name=xrandr screenlayout
          Comment=xrandr screenlayout
          Type=Application
          Exec=${pkgs.xorg.xrandr}/bin/xrandr --output DisplayPort-0 --primary --mode 3440x1440 --pos 0x1280 --rotate normal --output DisplayPort-1 --mode 1920x1080 --pos 760x2720 --rotate normal --output DisplayPort-2 --off --output HDMI-A-0 --mode 1920x1280 --pos 1520x0 --rotate normal --output DP-1-0 --off --output DP-1-1 --off --output DP-1-2 --off --output DP-1-3 --off --output DP-1-4 --off --output DP-1-5 --off --output DP-1-6 --off --output DP-1-7 --off
          Categories=
          Terminal=false
          NoDisplay=true
          StartupNotify=false
      '';
    };
  };
}
