#!/usr/bin/env bash

if [ -n "${1}" ]; then
    curl -w "%{url_effective}\n" -I -L -s -S "${1}" -o /dev/null
else
    echo "ERROR! Please provide a URL"
    exit 1
fi
