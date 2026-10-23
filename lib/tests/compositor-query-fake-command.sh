#!/usr/bin/env bash

# A fake compositor tool for lib/tests/compositor-query.sh. The Nix wrapper
# passes the tool name first. Replies come from JSON files in FAKE_STATE.

state=${FAKE_STATE:?}
tool=$1
shift

case "$tool $*" in
"mmsg get all-monitors" | "mmsg watch all-monitors") cat "$state/monitors.json" ;;
"lan-mouse-wayfire-ipc focused-output") cat "$state/focused.json" ;;
"wlr-randr --json") cat "$state/randr.json" ;;
"xrdb -nocpp -merge") cat >>"$state/xrdb" ;;
"wleave "*) printf '%s\n' "$*" >"$state/wleave" ;;
*)
	echo "fake $tool: unexpected arguments: $*" >&2
	exit 1
	;;
esac
