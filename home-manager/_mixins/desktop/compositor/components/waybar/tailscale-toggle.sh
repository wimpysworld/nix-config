#!/usr/bin/env bash

case "$1" in
  toggle)
    if [[ "$(tailscale status --json | jq -r '.BackendState')" == "Stopped" ]]; then
      tailscale up --operator="$USER" --reset
      notify-desktop "Tailscale connected" "Your Tailscale connection has been established successfully. You are now connected to your tailnet." --urgency=low --app-name="Tailscale Toggle" --icon=network-connect
    else
      tailscale down
      notify-desktop "Tailscale disconnected" "Your Tailscale connection has been terminated. You are no longer connected to your tailnet." --urgency=low --app-name="Tailscale Toggle" --icon=network-disconnect
    fi
    ;;
  toggle-mullvad)
    if [[ "$(tailscale status --json | jq -r '.ExitNodeStatus.Online')" == "true" ]]; then
      tailscale set --exit-node=
      notify-desktop "Mullvad VPN disconnected" "Tailscale connection has been disconnected from Mullvad VPN." --urgency=low --app-name="Tailscale Toggle" --icon=changes-allow
    else
      SUGGESTED="$(tailscale exit-node suggest | head -n 1 | cut -d':' -f 2 | sed s'/ //g')"
      tailscale set --exit-node="$SUGGESTED"
      notify-desktop "Mullvad VPN connected" "Tailscale has been connected to Mullvad VPN." --urgency=low --app-name="Tailscale Toggle" --icon=changes-prevent
    fi
    ;;
esac
