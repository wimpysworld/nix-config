#!/usr/bin/env bash

set +e
set +u
set +o pipefail

client_pids() {
	mmsg get all-clients 2>/dev/null | jq -r '.clients[].pid | select(. > 1)' 2>/dev/null
}

case "${1:-}" in
close-windows)
	wlrctl toplevel close
	if timeout 5 wlrctl toplevel wait 2>/dev/null; then
		exit 0
	fi

	pids="$(client_pids)"
	for pid in $pids; do
		kill -TERM "$pid" 2>/dev/null
	done
	for _ in {1..6}; do
		remaining=""
		for pid in $pids; do
			if kill -0 "$pid" 2>/dev/null; then
				remaining="$remaining $pid"
			fi
		done
		if [ -z "$remaining" ]; then
			break
		fi
		sleep 0.5
	done
	for pid in $remaining; do
		kill -KILL "$pid" 2>/dev/null
	done

	sleep 0.5
	count="$(mmsg get all-clients 2>/dev/null | jq '.clients | length' 2>/dev/null)"
	if [ "${count:-0}" -gt 0 ]; then
		echo "wayland-session-adapter: $count windows remain" >&2
		exit 1
	fi
	;;
logout)
	if ! mmsg dispatch quit; then
		exec wayland-logout
	fi
	;;
*)
	echo "Usage: $(basename "$0") {close-windows|logout}"
	exit 1
	;;
esac
