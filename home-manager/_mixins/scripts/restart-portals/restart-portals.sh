#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

case "$XDG_CURRENT_DESKTOP" in
    Hyprland) PORTALS=(xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-desktop-portal);;
    *) PORTALS=(xdg-desktop-portal-gtk xdg-desktop-portal);;
esac;

# Restart the desktop portal services in the correct order
for ACTION in stop start; do
    for PORTAL in "${PORTALS[@]}"; do
        systemctl --user "$ACTION" "$PORTAL"
    done;
done
