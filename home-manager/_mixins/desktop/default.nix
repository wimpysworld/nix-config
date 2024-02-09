{ config, desktop, lib, pkgs, username, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
{
  imports = [
    (./. + "/${desktop}.nix")
  ] ++ lib.optional (builtins.pathExists (./. + "/../users/${username}/desktop.nix")) ../users/${username}/desktop.nix;

  # https://nixos.wiki/wiki/Bluetooth#Using_Bluetooth_headsets_with_PulseAudio
  services.mpris-proxy.enable = isLinux;
  services.gpg-agent = lib.mkIf isLinux {
    pinentryFlavor = lib.mkForce "gnome3";
  };

  xdg = {
    desktopEntries = {
      # Create a desktop entry for the Cider AppImage.
      cider = lib.mkIf isLinux {
        name = "Cider";
        exec = "${lib.getExe pkgs.appimage-run} -- ${config.home.homeDirectory}/Apps/Cider.AppImage";
        terminal = false;
        icon = "cider";
        type = "Application";
        categories = [ "Audio" "Application" ];
      };
    };
  };

  xresources.properties = {
    "XTerm*background" = "#121214";
    "XTerm*foreground" = "#c8c8c8";
    "XTerm*cursorBlink" = true;
    "XTerm*cursorColor" = "#FFC560";
    "XTerm*boldColors" = false;

    #Black + DarkGrey
    "*color0" = "#141417";
    "*color8" = "#434345";
    #DarkRed + Red
    "*color1" = "#D62C2C";
    "*color9" = "#DE5656";
    #DarkGreen + Green
    "*color2" = "#42DD76";
    "*color10" = "#A1EEBB";
    #DarkYellow + Yellow
    "*color3" = "#FFB638";
    "*color11" = "#FFC560";
    #DarkBlue + Blue
    "*color4" = "#28A9FF";
    "*color12" = "#94D4FF";
    #DarkMagenta + Magenta
    "*color5" = "#E66DFF";
    "*color13" = "#F3B6FF";
    #DarkCyan + Cyan
    "*color6" = "#14E5D4";
    "*color14" = "#A1F5EE";
    #LightGrey + White
    "*color7" = "#c8c8c8";
    "*color15" = "#e9e9e9";
    "XTerm*faceName" = "FiraCode Nerd Font:size=13:style=Medium:antialias=true";
    "XTerm*boldFont" = "FiraCode Nerd Font:size=13:style=Bold:antialias=true";
    "XTerm*geometry" = "132x50";
    "XTerm.termName" = "xterm-256color";
    "XTerm*locale" = false;
    "XTerm*utf8" = true;
  };
}
