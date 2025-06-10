#!/usr/bin/env bash

if [ -e /tmp/virtualcam.pid ]; then
  virtualcam stop
  notify-desktop "󰄀 VirtualCam disabled" "The v4l2loopback virtual camera has been disabled." --urgency=low --app-name="VirtualCam"
else
  virtualcam start
  notify-desktop "󰗟 VirtualCam enabled" "The v4l2loopback virtual camera has been enabled." --urgency=low --app-name="VirtualCam"
fi