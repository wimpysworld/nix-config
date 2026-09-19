#!/usr/bin/env bash

statusline_json=""
IFS= read -r -d "" statusline_json || true

ccstatusline < <(printf '%s' "$statusline_json")
