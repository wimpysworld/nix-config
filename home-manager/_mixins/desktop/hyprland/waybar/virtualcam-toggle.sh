#!/usr/bin/env bash

VIRTUALCAM_STATUS=$(virtualcam status | head -n 1 | grep "is running")
if [ -n "${VIRTUALCAM_STATUS}" ] ; then
  virtualcam stop
  notify-desktop "󰄀 VirtualCam disabled" "The v4l2loopback virtual camera has been disabled." --urgency=low --app-name="VirtualCam"
else
  virtualcam start
  notify-desktop "󰗟 VirtualCam enabled" "The v4l2loopback virtual camera has been disabled." --urgency=low --app-name="VirtualCam"
fi