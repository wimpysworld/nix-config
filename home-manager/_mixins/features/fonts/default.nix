{ config, desktop, hostname, inputs, lib, outputs, pkgs, stateVersion, username, ... }:
let
  inherit (pkgs.stdenv) isDarwin;
  isOtherOS = if builtins.isString (builtins.getEnv "__NIXOS_SET_ENVIRONMENT_DONE") then false else true;
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
in
lib.mkIf (isDarwin || isOtherOS) {
  home = {
    packages = with pkgs; [
      (nerdfonts.override { fonts = [ "FiraCode" "NerdFontsSymbolsOnly" ]; })
      fira
      liberation_ttf
      noto-fonts-emoji
      source-serif
      symbola
      work-sans
    ] ++ lib.optionals (isInstall) [
      ubuntu_font_family
      twitter-color-emoji
    ];
  };

  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      serif = [ "Source Serif" ];
      sansSerif = [ "Work Sans" "Fira Sans" ];
      monospace = [ "FiraCode Nerd Font Mono" "Symbols Nerd Font Mono" ];
      emoji = [ "Noto Color Emoji" "Twitter Color Emoji" ];
    };
  };
}
