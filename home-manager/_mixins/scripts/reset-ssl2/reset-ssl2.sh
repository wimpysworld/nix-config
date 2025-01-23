#!/usr/bin/env bash

VENDOR="31e9"
PRODUCT="0001"
HOST=$(hostnamectl hostname)
case "${HOST}" in
  phasma) PRODUCT="0002";;
  *) echo "This script is only meant to be run on phasma or vader";;
esac

sudo true
# If usb-reset is installed, use it
if [ -x "$(command -v usb-reset)" ]; then
    sudo usb-reset "${VENDOR}":"${PRODUCT}"
elif [ -x "$(command -v usbreset)" ]; then
    # Get the bus and device number of the SSL 2
    SSL2="$(lsusb -d ${VENDOR}: | grep "SSL 2")"
    #Bus 001 Device 007: ID 31e9:0001 Solid State Logic SSL 2
    #Bus 001 Device 009: ID 31e9:0002 Solid State Logic SSL 2+
    BUS="$(echo "${SSL2}" | cut -d' ' -f 2)"
    DEV="$(echo "${SSL2}" | cut -d' ' -f 4 | cut -d':' -f 1)"
    sudo usbreset "${BUS}"/"${DEV}"
else
    echo "ERROR! usb-reset or usbreset is not installed. Please install it."
    exit 1
fi
