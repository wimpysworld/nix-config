{ config, desktop, lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isDarwin isLinux;
in
lib.mkIf isLinux {
  # TODO: Migrate to Colloid-gtk-theme 2024-06-18 or newer; now has catppuccin colors
  # - https://github.com/vinceliuice/Colloid-gtk-theme/releases/tag/2024-06-18
  dconf.settings = with lib.hm.gvariant; {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      cursor-size = 48;
      cursor-theme = "Catppuccin-Mocha-Blue-Cursors";
      gtk-theme = "catppuccin-mocha-blue-standard+default";
      icon-theme = "Papirus-Dark";
    };

    "org/gnome/desktop/wm/preferences" = {
      button-layout = "close,minimize,maximize";
      theme = "catppuccin-mocha-blue-standard+default";
    };

    "org/mate/desktop/interface" = {
      gtk-decoration-layout = "close,minimize,maximize";
      gtk-theme = "catppuccin-mocha-blue-standard+default";
      icon-theme = "Papirus-Dark";
    };

    "org/mate/desktop/peripherals/mouse" = {
      cursor-size = mkInt32 48;
      cursor-theme = "Catppuccin-Mocha-Blue-Cursors";
    };

    "org/mate/marco/general" = {
      button-layout = "close,minimize,maximize";
      theme = "catppuccin-mocha-blue-standard+default";
    };

    "org/pantheon/desktop/gala/appearance" = {
      button-layout = "close,minimize,maximize";
    };
  };

  gtk = {
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
      name = "catppuccin-mocha-blue-standard+default";
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
