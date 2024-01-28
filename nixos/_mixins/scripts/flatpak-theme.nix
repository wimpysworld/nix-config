{ pkgs }:

pkgs.writeScriptBin "flatpak-theme" ''
#!${pkgs.stdenv.shell}
# Best effort to set the GTK theme for Flatpak apps

case "$XDG_CURRENT_DESKTOP" in
  Cinnamon|GNOME|Pantheon)
    COLOR_SCHEME=$(${pkgs.dconf}/bin/dconf read /org/gnome/desktop/interface/color-scheme | ${pkgs.gnused}/bin/sed -e "s/'//g")
    GTK_THEME=$(${pkgs.dconf}/bin/dconf read /org/gnome/desktop/interface/gtk-theme | ${pkgs.gnused}/bin/sed -e "s/'//g")
    ICON_THEME=$(${pkgs.dconf}/bin/dconf read /org/gnome/desktop/interface/icon-theme | ${pkgs.gnused}/bin/sed -e "s/'//g")
    XCURSOR_THEME=$(${pkgs.dconf}/bin/dconf read /org/gnome/desktop/interface/cursor-theme | ${pkgs.gnused}/bin/sed -e "s/'//g")
    if [ "$COLOR_SCHEME" == "prefer-dark" ]; then
      GTK_THEME="$GTK_THEME:dark"
    fi
    ;;
  MATE)
    GTK_THEME=$(${pkgs.dconf}/bin/dconf read /org/mate/desktop/interface/gtk-theme | ${pkgs.gnused}/bin/sed -e "s/'//g")
    ICON_THEME=$(${pkgs.dconf}/bin/dconf read /org/mate/desktop/interface/icon-theme | ${pkgs.gnused}/bin/sed -e "s/'//g")
    XCURSOR_THEME=$(${pkgs.dconf}/bin/dconf read /org/mate/desktop/peripherals/mouse/cursor-theme | ${pkgs.gnused}/bin/sed -e "s/'//g")
    ;;
  *)
    GTK_THEME="Adwaita"
    ICON_THEME="Adwaita"
    XCURSOR_THEME="Adwaita"
    ;;
esac

${pkgs.flatpak}/bin/flatpak override --user --env=GTK_THEME="$GTK_THEME"
${pkgs.flatpak}/bin/flatpak override --user --env=ICON_THEME="$ICON_THEME"
${pkgs.flatpak}/bin/flatpak override --user --env=XCURSOR_THEME="$XCURSOR_THEME"
''
