#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

for UNIT in pipewire pipewire-pulse wireplumber mpris-proxy; do
    systemctl --user restart "$UNIT"
done
