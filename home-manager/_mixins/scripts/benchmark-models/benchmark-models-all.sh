#!/usr/bin/env bash

set -euo pipefail

declare -a flags=()
runs=3

while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
		printf 'Usage: benchmark-models-all [--llama-only|--ollama-only] [--json] [--runs N]\n'
		exit 0
		;;
	--llama-only | --ollama-only | --json)
		flags+=("$1")
		shift
		;;
	--runs)
		if [[ $# -lt 2 || ! "$2" =~ ^0*[1-9][0-9]*$ ]]; then
			printf 'Error: --runs requires a positive integer.\n' >&2
			exit 1
		fi
		runs="$2"
		shift 2
		;;
	*)
		printf 'Error: unknown option: %s\n' "$1" >&2
		printf 'Usage: benchmark-models-all [--llama-only|--ollama-only] [--json] [--runs N]\n' >&2
		exit 1
		;;
	esac
done

exec python3 "${BENCHMARK_COMPARISON_SCRIPT}" "${flags[@]}" --runs "${runs}" "${suiteModels[@]}"
