{ config, desktop, lib, pkgs, ... }:
{
  home = {
    file = {
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
