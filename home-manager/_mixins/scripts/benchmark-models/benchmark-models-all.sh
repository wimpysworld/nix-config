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
for model in "${suiteModels[@]}"; do
	python3 "${BENCHMARK_COMPARISON_SCRIPT}" "${model}" 3 || status=$?
done
exit "${status}"
