#!/usr/bin/env bash

if [ -e /tmp/virtualcam.pid ]; then
  virtualcam stop
  fyi --urgency=low --app-name="VirtualCam" "󰄀 VirtualCam disabled" "The v4l2loopback virtual camera has been disabled."
else
  virtualcam start
  fyi --urgency=low --app-name="VirtualCam" "󰗟 VirtualCam enabled" "The v4l2loopback virtual camera has been enabled."
fi
