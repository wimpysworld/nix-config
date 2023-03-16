#!/usr/bin/env bash

# Best effort to set the GTK theme for Flatpak apps

case "${XDG_CURRENT_DESKTOP}" in
  Cinnamon|GNOME|Pantheon)
    COLOR_SCHEME=$(dconf read /org/gnome/desktop/interface/color-scheme | sed -e "s/'//g")
    GTK_THEME=$(dconf read /org/gnome/desktop/interface/gtk-theme | sed -e "s/'//g")
    ICON_THEME=$(dconf read /org/gnome/desktop/interface/icon-theme | sed -e "s/'//g")
    XCURSOR_THEME=$(dconf read /org/gnome/desktop/interface/cursor-theme | sed -e "s/'//g")
    if [ "${COLOR_SCHEME}" == "prefer-dark" ]; then
      GTK_THEME="${GTK_THEME}:dark"
    fi
    ;;
  MATE)
    GTK_THEME=$(dconf read /org/mate/desktop/interface/gtk-theme | sed -e "s/'//g")
    ICON_THEME=$(dconf read /org/mate/desktop/interface/icon-theme | sed -e "s/'//g")
    XCURSOR_THEME=$(dconf read /org/mate/desktop/peripherals/mouse/cursor-theme | sed -e "s/'//g")
    ;;
  *)
    GTK_THEME="Adwaita"
    ICON_THEME="Adwaita"
    XCURSOR_THEME="Adwaita"
    ;;
esac

flatpak override --user --env=GTK_THEME="${GTK_THEME}"
flatpak override --user --env=ICON_THEME="${ICON_THEME}"
flatpak override --user --env=XCURSOR_THEME="${XCURSOR_THEME}"
