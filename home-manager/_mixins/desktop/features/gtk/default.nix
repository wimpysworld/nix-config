{ config, desktop, lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isDarwin isLinux;
  isGnome = if (desktop == "gnome") then true else false;
in
lib.mkIf isLinux {
  gtk = {
    catppuccin.gnomeShellTheme = isGnome;
    cursorTheme = {
      name = "Catppuccin-Mocha-Blue-Cursors";
      package = pkgs.catppuccin-cursors.mochaBlue;
      size = 48;
    };
    enable = true;
    font = {
      name = "Work Sans 12";
      package = pkgs.work-sans;
    };
    gtk2 = {
      configLocation = "${config.xdg.configHome}/.gtkrc-2.0";
      extraConfig = ''
        gtk-application-prefer-dark-theme = 1
        gtk-button-images = 1
        gtk-decoration-layout = "close,minimize,maximize"
      '';
    };
    gtk3 = {
      extraConfig = {
        gtk-application-prefer-dark-theme = 1;
        gtk-button-images = 1;
        gtk-decoration-layout = "close,minimize,maximize";
      };
    };
    gtk4 = {
      extraConfig = {
        gtk-decoration-layout = "close,minimize,maximize";
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.catppuccin-papirus-folders.override {
        flavor = "mocha";
        accent = "blue";
      };
    };
    theme = {
      name = "Catppuccin-Mocha-Standard-Blue-Dark";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "blue" ];
        size = "standard";
        variant = "mocha";
      };
    };
  };
  home = {
    packages = with pkgs; [
      papirus-folders
    ];
    pointerCursor = {
      name = "Catppuccin-Mocha-Blue-Cursors";
      package = pkgs.catppuccin-cursors.mochaBlue;
      size = 48;
      gtk.enable = true;
      x11.enable = true;
    };
  };
}
