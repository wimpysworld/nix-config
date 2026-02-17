#!/usr/bin/env bash

if [ -e /tmp/virtualcam.pid ]; then
  echo -en "󰄀\n󰄀  VirtualCam enabled\nconnected"
else
  echo -en "󰗟\n󰗟  VirtualCam is disabled\ndisconnected"
fi
