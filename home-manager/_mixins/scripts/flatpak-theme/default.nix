{ pkgs, ... }:
let
  flatpak-theme = pkgs.writeShellApplication {
    name = "flatpak-theme";
    runtimeInputs = with pkgs; [
      coreutils-full
      dconf
      flatpak
      gnused
    ];
    text = builtins.readFile ./flatpak-theme.sh;
  };
in
{
  home.packages = with pkgs; [ flatpak-theme ];
}
