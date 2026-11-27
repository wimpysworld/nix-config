#!/usr/bin/env bash

set -euo pipefail

declare -a flags=()
declare -a suite_models=()
read -r -a suite_models <<<"${BENCHMARK_MODELS_SUITE:-}"
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

if [[ ${#suite_models[@]} -eq 0 ]]; then
	printf 'Error: no benchmark models are configured for this host.\n' >&2
	exit 1
fi

exec python3 "${BENCHMARK_COMPARISON_SCRIPT:-$(dirname "${BASH_SOURCE[0]}")/focused.py}" \
	"${flags[@]}" --runs "${runs}" "${suite_models[@]}"
