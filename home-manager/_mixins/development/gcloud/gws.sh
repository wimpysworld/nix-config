#!/usr/bin/env bash
set -euo pipefail

if ! token=$(timeout --signal=TERM --kill-after=1s 30s "@gcloud@" auth print-access-token </dev/null 2>/dev/null) ||
    [[ -z "${token//[[:space:]]/}" ]]; then
    echo 'gws: Could not obtain a nonempty gcloud token within 30 seconds. Check connectivity and run mint-tokens to repair login.' >&2
    exit 1
fi
export GOOGLE_WORKSPACE_CLI_TOKEN="$token"
exec "@gws@" "$@"
