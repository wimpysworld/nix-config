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

exec ai-usagebar "$@"
