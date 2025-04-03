#!/usr/bin/env bash

HYPR_ANIMATIONS=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')
if [ "$HYPR_ANIMATIONS" -eq 1 ] ; then
  echo -en "󱥰\n󱥰  Hyprland eye-candy is enabled\nactive"
else
  echo -en "󱥱\n󱥱  Hyprland eye-candy is disabled\ninactive"
  # Disable opacity on all clients every 4 seconds
  if [ $(( $(date +%S) % 4 )) -eq 0 ]; then
    hyprctl clients -j | jq -r ".[].address" | xargs -I {} hyprctl setprop address:{} forceopaque 1 lock
  fi
fi
