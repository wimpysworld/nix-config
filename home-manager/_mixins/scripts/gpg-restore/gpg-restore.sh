#!/usr/bin/env bash

# shellcheck disable=SC2174
mkdir -p --mode=700 "${HOME}/.gnupg"
gpgconf --kill gpg-agent

temp_dir="${HOME}/.config/sops-nix/secrets"

if [ -e "${temp_dir}/gpg_private" ]; then
    gpg --import --batch "${temp_dir}/gpg_private"
    gpg --import "${temp_dir}/gpg_public"
    gpg --list-secret-keys
    gpg --list-keys
    gpg --import-ownertrust "${temp_dir}/gpg_ownertrust"
else
    echo "GPG keys were not found in: ${temp_dir}"
    exit 1
fi
