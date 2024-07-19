#!/usr/bin/env bash

set +e  # Disable errexit
set +o pipefail  # Disable pipefail

VOL=$(rhythmbox-client --no-start --print-volume | cut -d' ' -f4 | cut -c1-4)
if [ -z "${VOL}" ]; then
  echo "--"
else
  echo "$(echo "100 * ${VOL}" | bc -l | cut -d'.' -f1)%"
fi
