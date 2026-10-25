#!/usr/bin/env bash

selection=$(python3 "$FUZZEL_EMOJI_HELPER" "$FUZZEL_EMOJI_MASTER" "$@")
[[ -n "$selection" ]] || exit 0
wtype "$selection"
wl-copy "$selection"
