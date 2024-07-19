#!/usr/bin/env bash

set +u  # Disable nounset

WINDOW_ID="$(xdotool search '^Meet ' 2>/dev/null)"
if [ -n "${WINDOW_ID}" ]; then
  case "${1}" in
      camera)
        xdotool windowfocus "${WINDOW_ID}"
        xdotool getactivewindow key ctrl+e
        ;;
      mic)
        xdotool windowfocus "${WINDOW_ID}"
        xdotool getactivewindow key ctrl+d
        ;;
      *) echo "Usage: ${0} {camera|mic}";;
  esac
fi
