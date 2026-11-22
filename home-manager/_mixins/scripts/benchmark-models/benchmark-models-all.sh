#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 0 ]]; then
	printf 'Usage: benchmark-models-all\n'
	if [[ $# -eq 1 && ( "$1" == --help || "$1" == -h ) ]]; then
		exit 0
	fi
	exit 1
fi

status=0
benchmark-models inkling-2-mini || status=$?
benchmark-models qwen3.8-27b || status=$?
exit "${status}"
