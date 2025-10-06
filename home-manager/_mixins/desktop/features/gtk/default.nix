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
      cursor-theme = "catppuccin-${config.catppuccin.flavor}-${config.catppuccin.accent}-cursors";
      gtk-theme = "catppuccin-${config.catppuccin.flavor}-${config.catppuccin.accent}-standard";
      icon-theme = "Papirus-Dark";
    };

    "org/gnome/desktop/wm/preferences" = {
      button-layout = "${buttonLayout}";
      theme = "catppuccin-${config.catppuccin.flavor}-${config.catppuccin.accent}-standard";
    };

    "org/pantheon/desktop/gala/appearance" = {
      button-layout = "${buttonLayout}";
    };
  };

  gtk = {
    cursorTheme = {
      name = "catppuccin-${config.catppuccin.flavor}-${config.catppuccin.accent}-cursors";
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
        flavor = config.catppuccin.flavor;
        accent = config.catppuccin.accent;
      };
    };
    theme = {
      name = "catppuccin-${config.catppuccin.flavor}-${config.catppuccin.accent}-standard";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "${config.catppuccin.accent}" ];
        size = "standard";
        variant = config.catppuccin.flavor;
      };
    };
  };
  home = {
    packages = with pkgs; [ papirus-folders ];
    pointerCursor = {
      dotIcons.enable = true;
      gtk.enable = true;
      hyprcursor = {
        enable = config.wayland.windowManager.hyprland.enable;
        size = 32;
      };
      name = "catppuccin-${config.catppuccin.flavor}-${config.catppuccin.accent}-cursors";
      package = pkgs.catppuccin-cursors.mochaBlue;
      size = 32;
      x11.enable = true;
    };
  };
}
