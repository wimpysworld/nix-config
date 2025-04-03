#!/usr/bin/env bash

TS_JSON="$XDG_RUNTIME_DIR/tailscale-status.json"
if tailscale status --json > "$TS_JSON"; then
  version="$(jq -r '.Version' "$TS_JSON")"
  if [[ "$(jq -r '.BackendState' "$TS_JSON")" == "Running" ]]; then
    dnsname="$(jq -r '.Self.DNSName' "$TS_JSON")"
    if [[ "$(jq -r '.ExitNodeStatus.Online' "$TS_JSON")" == "true" ]]; then
      exitnode="$(jq -r '.ExitNodeStatus.TailscaleIPs[0]' "$TS_JSON")"
      echo -en "󰦝\n󰖂  Tailscale (v$version) connected via $exitnode as $dnsname\nexitnode"
    else
      tailnet="$(jq -r '.CurrentTailnet.Name' "$TS_JSON")"
      echo -en "󰴳\n󰖂  Tailscale (v$version) connected to $tailnet as $dnsname\nconnected"
    fi
  else
    echo -en "󰦞\n󰖂  Tailscale (v$version) is disconnected\ndisconnected"
  fi
else
  echo -en "󰻌\n󰖂  Tailscale is not available\ndisconnected"
fi
