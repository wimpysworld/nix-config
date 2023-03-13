#!/usr/bin/env bash

flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

case "${XDG_CURRENT_DESKTOP}" in
  Pantheon)
    flatpak override --user --env=GTK_THEME=io.elementary.stylesheet.bubblegum:dark
    flatpak remote-add --user --if-not-exists appcenter  https://flatpak.elementary.io/appcenter.flatpakrepo
    #flatpak remote-add --user --if-not-exists elementary https://flatpak.elementary.io/elementary.flatpakrepo
    ;;
  MATE)
    flatpak override --user --env=GTK_THEME=Yaru-magenta-dark
    ;;
esac
