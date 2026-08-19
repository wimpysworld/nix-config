#!/usr/bin/env bash

set +e
set +u

case "${1:-}" in
close-windows)
	wlrctl toplevel close
	timeout 5 wlrctl toplevel wait 2>/dev/null
	status=$?
	if [ "$status" -eq 124 ]; then
		echo "wayland-session-adapter: windows remain after five seconds" >&2
	fi
	exit "$status"
	;;
logout)
	exec wayland-logout
	;;
*)
	echo "Usage: $(basename "$0") {close-windows|logout}"
	exit 1
	;;
esac
