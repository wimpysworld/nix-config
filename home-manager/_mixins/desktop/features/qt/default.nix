{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isDarwin isLinux;
in
lib.mkIf isLinux {
  # https://discourse.nixos.org/t/struggling-to-configure-gtk-qt-theme-on-laptop/42268/
  home = {
    packages = with pkgs; [
      (catppuccin-kvantum.override {
        accent = "Blue";
        variant = "Mocha";
      })
      libsForQt5.qtstyleplugin-kvantum
      libsForQt5.qt5ct
    ];
  };

  qt = {
    enable = true;
    platformTheme = "qtct";
    style = {
      name = "kvantum";
    };
  };

  systemd.user.sessionVariables = {
    QT_STYLE_OVERRIDE = "kvantum";
  };

  xdg.configFile = {
    kvantum = {
      target = "Kvantum/kvantum.kvconfig";
      text = lib.generators.toINI { } {
        General.theme = "Catppuccin-Mocha-Blue";
      };
    };
    qt5ct = {
      target = "qt5ct/qt5ct.conf";
      text = lib.generators.toINI { } {
        Appearance = {
          icon_theme = "Papirus-Dark";
        };
      };
    };
    qt6ct = {
      target = "qt6ct/qt6ct.conf";
      text = lib.generators.toINI { } {
        Appearance = {
          icon_theme = "Papirus-Dark";
        };
      };
    };
  };
}
