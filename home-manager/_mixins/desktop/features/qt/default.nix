{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf isLinux {
  catppuccin = {
    kvantum.enable = config.qt.enable;
  };

  # https://discourse.nixos.org/t/struggling-to-configure-gtk-qt-theme-on-laptop/42268/
  home = {
    packages = with pkgs; [
      (catppuccin-kvantum.override {
        accent = config.catppuccin.accent;
        variant = config.catppuccin.flavor;
      })
      kdePackages.qt6ct
      kdePackages.qtstyleplugin-kvantum
      libsForQt5.qt5ct
      libsForQt5.qtstyleplugin-kvantum
    ];
    sessionVariables = {
      QT_STYLE_OVERRIDE = "kvantum";
    };
  };

  qt = {
    enable = true;
    platformTheme.name = config.qt.style.name;
    style = {
      name = "kvantum";
    };
  };

  xdg = {
    configFile = {
      qt5ct = {
        target = "qt5ct/qt5ct.conf";
        text = lib.generators.toINI { } {
          Appearance = {
            icon_theme = config.gtk.iconTheme.name;
          };
        };
      };
      qt6ct = {
        target = "qt6ct/qt6ct.conf";
        text = lib.generators.toINI { } {
          Appearance = {
            icon_theme = config.gtk.iconTheme.name;
          };
        };
      };
    };
    desktopEntries = {
      kvantummanager = {
        name = "Kvantum Manager";
        noDisplay = true;
      };
      qt5ct = {
        name = "Qt5 Settings";
        noDisplay = true;
      };
      qt6ct = {
        name = "Qt6 Settings";
        noDisplay = true;
      };
    };
  };
}
