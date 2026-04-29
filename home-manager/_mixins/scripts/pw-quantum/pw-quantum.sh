#!/usr/bin/env bash
# Obsolete as the pipewire configuration is now tuned in the NixOS configuration

set +u

# Use pw-top to monitor
HOST="$(hostnamectl hostname)"
case "${HOST}" in
  skrye|zannah) QUANT=1024;;
  *) QUANT=2048;;
esac


#pw-metadata -n settings 0 clock.min-quantum $((${QUANT} / 2))
#pw-metadata -n settings 0 clock.quantum     ${QUANT}
#pw-metadata -n settings 0 clock.max-quantum $((${QUANT} * 2))

pw-metadata -n settings 0 clock.min-quantum "${QUANT}"
pw-metadata -n settings 0 clock.quantum     "${QUANT}"
pw-metadata -n settings 0 clock.max-quantum "${QUANT}"
