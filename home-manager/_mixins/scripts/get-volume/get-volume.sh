#!/usr/bin/env bash

set +e  # Disable errexit
set +o pipefail  # Disable pipefail

echo "$(pulsemixer --get-volume | cut -d' ' -f1)"%
