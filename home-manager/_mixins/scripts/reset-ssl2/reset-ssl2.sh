#!/usr/bin/env bash

HOST=$(hostnamectl hostname)
case "${HOST}" in
  phasma) usb-reset 31e9:0002;;
  vader) usb-reset 31e9:0001;;
  *) echo "This script is only meant to be run on phasma or vader";;
esac
