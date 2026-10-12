#!/usr/bin/env bash

# The Nix wrapper sets opencode_key_file before this text. It is empty on hosts
# without OpenCode Go. Waybar can start before sops-nix renders the secret, so a
# missing, unreadable, or empty file only leaves OpenCode Go without a key for
# this run. The key goes through the environment, never through argv.
if [[ -n "${opencode_key_file}" && -r "${opencode_key_file}" ]]; then
  opencode_key="$(<"${opencode_key_file}")" || opencode_key=""
  if [[ -n "${opencode_key}" ]]; then
    export OPENCODE_GO_API_KEY="${opencode_key}"
  fi
  unset opencode_key
fi

# Scroll commands such as --cycle-next pass through unchanged. A plain run
# prints the Waybar JSON, and its tooltip is already Pango markup with escaped
# vendor text, so a span sets the monospace font of the Waybar CSS for this
# tooltip only. The box drawing in the tooltip then lines up.
if [[ $# -gt 0 ]]; then
  exec ai-usagebar "$@"
fi

ai-usagebar | jq --compact-output --unbuffered '
  if (.tooltip // "") != "" then
    .tooltip = "<span font_family=\"FiraCode Nerd Font Mono\">\(.tooltip)</span>"
  end'
