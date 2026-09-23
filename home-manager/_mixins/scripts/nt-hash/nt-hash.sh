#!/usr/bin/env bash

# Print the NT hash of a password, for iwd's EAP-*-Password-Hash settings.
# The NT hash is the MD4 digest of the UTF-16LE password, in lowercase hex.
# Read the password from a hidden prompt, or from standard input when it is
# not a terminal. Never take it as an argument, which would expose it in the
# process list and the shell history.

if [ -t 0 ]; then
    read -rsp "Password: " PASSWORD
    echo >&2
else
    IFS= read -r PASSWORD || true
fi

if [ -z "${PASSWORD}" ]; then
    echo "ERROR! The password is empty." >&2
    exit 1
fi

# OpenSSL 3 keeps MD4 in the legacy provider.
printf '%s' "${PASSWORD}" |
    iconv -f UTF-8 -t UTF-16LE |
    openssl dgst -md4 -provider legacy -provider default -r |
    cut -d' ' -f1
unset PASSWORD
