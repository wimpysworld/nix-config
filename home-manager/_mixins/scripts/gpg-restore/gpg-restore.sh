#!/usr/bin/env bash

# shellcheck disable=SC2174
mkdir -p --mode=700 "${HOME}/.gnupg"
gpgconf --kill gpg-agent

if [ "$(uname)" = "Darwin" ]; then
    base_temp_dir=$(getconf DARWIN_USER_TEMP_DIR)/secrets.d/
else
    base_temp_dir="/run/user/$(id -u)/secrets.d"
fi

if [ -d "${base_temp_dir}" ]; then
    # Find the numerically highest sub-directory
    temp_dir=$(find "${base_temp_dir}" -type d -maxdepth 1 -exec basename {} \; | sort -n | tail -n 1)
    temp_dir="${base_temp_dir}/${temp_dir}"
else
    echo "Directory ${base_temp_dir} does not exist."
    exit 1
fi

if [ -d "${temp_dir}" ]; then
    gpg --import --batch "${temp_dir}/gpg_private"
    gpg --import "${temp_dir}/gpg_public"
    gpg --list-secret-keys
    gpg --list-keys
    gpg --import-ownertrust "${temp_dir}/gpg_ownertrust"
else
    echo "Secrets directory ${temp_dir} does not exist."
    exit 1
fi
