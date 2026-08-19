#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

PORTALS=(@portalService@ xdg-desktop-portal-gtk xdg-desktop-portal)

# Restart the desktop portal services in the correct order
for ACTION in stop start; do
    for PORTAL in "${PORTALS[@]}"; do
        systemctl --user "$ACTION" "$PORTAL"
    done;
done
