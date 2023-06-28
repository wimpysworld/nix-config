{ lib, pkgs, ... }: {
  environment = {
    systemPackages = with pkgs; [
      libsForQt5.qtstyleplugins   # Qt5 style plugins
    ];
    
    # Required to coerce dark theme that works with Yaru
    # TODO: Set this in the user-session
    variables = lib.mkForce {
      QT_QPA_PLATFORMTHEME = "gnome";
      QT_STYLE_OVERRIDE = "Adwaita-Dark";
    };
  };

  qt = {
    enable = true;
  };
}
