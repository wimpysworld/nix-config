{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
  buttonLayout =
    if config.wayland.windowManager.hyprland.enable then "appmenu" else "close,minimize,maximize";
in
lib.mkIf isLinux {
  # TODO: Migrate to Colloid-gtk-theme 2024-06-18 or newer; now has catppuccin colors
  # - https://github.com/vinceliuice/Colloid-gtk-theme/releases/tag/2024-06-18
  dconf.settings = with lib.hm.gvariant; {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      cursor-size = 32;
      cursor-theme = "catppuccin-mocha-blue-cursors";
      gtk-theme = "catppuccin-mocha-blue-standard";
      icon-theme = "Papirus-Dark";
    };

    "org/gnome/desktop/wm/preferences" = {
      button-layout = "${buttonLayout}";
      theme = "catppuccin-mocha-blue-standard";
    };

    "org/mate/desktop/interface" = {
      gtk-decoration-layout = "${buttonLayout}";
      gtk-theme = "catppuccin-mocha-blue-standard";
      icon-theme = "Papirus-Dark";
    };

    "org/mate/desktop/peripherals/mouse" = {
      cursor-size = mkInt32 32;
      cursor-theme = "catppuccin-mocha-blue-cursors";
    };

    "org/mate/marco/general" = {
      button-layout = "${buttonLayout}";
      theme = "catppuccin-mocha-blue-standard";
    };

    "org/pantheon/desktop/gala/appearance" = {
      button-layout = "${buttonLayout}";
    };
  };

  gtk = {
    cursorTheme = {
      name = "catppuccin-mocha-blue-cursors";
      package = pkgs.catppuccin-cursors.mochaBlue;
      size = 32;
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
        gtk-decoration-layout = "${buttonLayout}"
      '';
    };
    gtk3 = {
      extraConfig = {
        gtk-application-prefer-dark-theme = 1;
        gtk-button-images = 1;
        gtk-decoration-layout = "${buttonLayout}";
      };
    };
    gtk4 = {
      extraConfig = {
        gtk-decoration-layout = "${buttonLayout}";
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
      name = "catppuccin-mocha-blue-standard";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "blue" ];
        size = "standard";
        variant = "mocha";
      };
    };
  };
  home = {
    packages = with pkgs; [ papirus-folders ];
    pointerCursor = {
      name = "catppuccin-mocha-blue-cursors";
      package = pkgs.catppuccin-cursors.mochaBlue;
      size = 32;
      gtk.enable = true;
      x11.enable = true;
    };
  };
}
