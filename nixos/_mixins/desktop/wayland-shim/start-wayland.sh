#!/usr/bin/env bash

set -euo pipefail

if (( $# < 5 )); then
	echo "start-wayland: invalid launcher configuration" >&2
	exit 2
fi

native_launcher=$1
desktop_name=$2
log_name=$3
cleanup_command=$4
prefix_arg_count=$5
shift 5

if [[ ! $prefix_arg_count =~ ^[0-9]+$ ]] || (( $# < prefix_arg_count )); then
	echo "start-wayland: invalid launcher prefix" >&2
	exit 2
fi

launcher_prefix_args=("${@:1:prefix_arg_count}")
shift "$prefix_arg_count"

log_dir="$HOME/.local/log"
log_file="$log_dir/$log_name.log"
mkdir -p "$log_dir"

if [[ -f $log_file ]]; then
	rm -f "$log_file.10"
	for ((index = 9; index >= 1; index--)); do
		if [[ -f $log_file.$index ]]; then
			mv "$log_file.$index" "$log_file.$((index + 1))"
		fi
	done
	mv "$log_file" "$log_file.1"
fi

set +e
unbuffer "$native_launcher" "${launcher_prefix_args[@]}" "$@" 2>&1 | tee -a "$log_file" >/dev/null
launcher_status=${PIPESTATUS[0]}

cleanup_status=0
"$cleanup_command" finalise || cleanup_status=$?

if (( cleanup_status != 0 )); then
	printf '[%s] Session cleanup failed with code %d\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$cleanup_status" \
		| tee -a "$log_file" >/dev/null
fi

printf '[%s] %s exited with code %d\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$desktop_name" "$launcher_status" \
	| tee -a "$log_file" >/dev/null

exit "$launcher_status"
