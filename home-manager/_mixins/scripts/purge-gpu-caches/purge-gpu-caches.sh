#!/usr/bin/env bash
CACHES=$(fd GPUCache "${HOME}/.config")

# Set IFS to split on newline instead of space
IFS=$'\n'

for CACHE in ${CACHES}; do
    echo "Purging ${CACHE}"
    rm -v "${CACHE}"*
done
