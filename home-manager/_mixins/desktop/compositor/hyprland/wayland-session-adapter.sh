#!/usr/bin/env bash

set +e
set +u
set +o pipefail

case "${1:-}" in
close-windows)
	hyprctl dispatch workspace 1 2>/dev/null || true

	addresses="$(hyprctl clients -j | jq -r '.[].address' 2>/dev/null || true)"
	for address in $addresses; do
		hyprctl dispatch closewindow "address:$address" 2>/dev/null || true
	done

	for _ in {1..10}; do
		remaining="$(hyprctl clients -j | jq 'length' 2>/dev/null || echo "0")"
		if [ "${remaining:-0}" -eq 0 ]; then
			exit 0
		fi
		sleep 0.5
	done

	hyprctl clients -j | jq -r '.[].pid' 2>/dev/null | xargs -r kill -9 2>/dev/null || true
	;;
logout)
	exec hyprctl dispatch exit
	;;
*)
	echo "Usage: $(basename "$0") {close-windows|logout}"
	exit 1
	;;
esac
