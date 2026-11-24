#!/usr/bin/env bash
set -euo pipefail

# Syncs Tinyauth's user entry in secrets/roamgate.yaml from ROAMGATE_PASSWORD
# and the shared TOTP secret in secrets/roamgate.yaml. Pass --qr to display
# the TOTP QR code in the terminal.

show_qr=false
if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [--qr]" >&2
  exit 1
elif [[ $# -eq 1 ]]; then
  if [[ "$1" == "--qr" ]]; then
    show_qr=true
  else
    echo "Usage: $0 [--qr]" >&2
    exit 1
  fi
fi

repo_root="$(git rev-parse --show-toplevel)"
roamgate_secrets="${repo_root}/secrets/roamgate.yaml"

password="$(sops -d --extract '["ROAMGATE_PASSWORD"]' "${roamgate_secrets}")"
totp_uri="$(sops -d --extract '["TINYAUTH_TOTP_URI"]' "${roamgate_secrets}")"
totp_secret="$(printf '%s' "${totp_uri}" | sed -n 's/.*[?&]secret=\([^&]*\).*/\1/p')"

if [[ -z "${password}" ]]; then
  echo "Error: ROAMGATE_PASSWORD is empty in ${roamgate_secrets}." >&2
  exit 1
fi

if [[ -z "${totp_secret}" ]]; then
  echo "Error: Could not extract TOTP secret from TINYAUTH_TOTP_URI in ${roamgate_secrets}." >&2
  exit 1
fi

raw_output="$(nix run nixpkgs#tinyauth -- user create --username martin --password "${password}")"
user_hash="$(
  printf '%s\n' "${raw_output}" \
    | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g' \
    | grep -oE 'martin:[$]2[aby][$][0-9]{2}[$][./A-Za-z0-9]{53}' \
    | head -n1
)"

if [[ -z "${user_hash}" ]]; then
  echo "Error: Failed to generate Tinyauth bcrypt hash." >&2
  exit 1
fi

printf '"%s:%s"' "${user_hash}" "${totp_secret}" \
  | sops set --value-stdin "${roamgate_secrets}" '["TINYAUTH_AUTH_USERS"]'

echo "Updated TINYAUTH_AUTH_USERS in ${roamgate_secrets}."

if [[ "${show_qr}" == true ]]; then
  echo "Scan this QR code in your authenticator app:"
  echo
  printf '%s' "${totp_uri}" | nix run nixpkgs#qrencode -- -t ANSIUTF8
else
  echo "TOTP secret unchanged (pass --qr to display the QR code again)."
fi
