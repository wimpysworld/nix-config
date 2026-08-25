#!/usr/bin/env bash

statusline_json=""
IFS= read -r -d "" statusline_json || true

usagebar statusline < <(printf '%s' "$statusline_json") >/dev/null || true
ccstatusline < <(printf '%s' "$statusline_json")
