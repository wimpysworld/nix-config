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
      libsForQt5.qtstyleplugin-kvantum
      libsForQt5.qt5ct
    ];
  };

  qt = {
    enable = true;
    platformTheme.name = "kvantum";
    style = {
      name = "kvantum";
    };
  };

  systemd.user.sessionVariables = {
    QT_STYLE_OVERRIDE = "kvantum";
  };

  xdg.configFile = {
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
