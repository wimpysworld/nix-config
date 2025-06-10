#!/usr/bin/env bash

VIRTUALCAM_STATUS=$(virtualcam status | head -n 1 | grep "is running")
if [ -n "${VIRTUALCAM_STATUS}" ] ; then
  echo -en "󰄀\n󰄀  VirtualCam enabled\nactive"
else
  echo -en "󰗟\n󰗟  VirtualCam is disabled\ninactive"
fi
