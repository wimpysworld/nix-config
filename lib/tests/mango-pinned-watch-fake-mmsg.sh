#!/usr/bin/env bash

# A fake mmsg for lib/tests/mango-pinned-watch.sh. It reads the Mango state from
# JSON files in FAKE_STATE and appends each dispatch to FAKE_STATE/dispatches.

state=${FAKE_STATE:?}

case "$1 ${2:-}" in
"watch all-monitors") cat "$state/monitors.json" ;;
"get all-monitors") cat "$state/monitors.json" ;;
"get all-clients") cat "$state/clients.json" ;;
"get focusing-client") cat "$state/focus.json" ;;
"dispatch "*)
	shift
	echo "$*" >>"$state/dispatches"
	echo '{"success":true}'
	;;
*)
	echo "fake mmsg: unexpected command: $*" >&2
	exit 1
	;;
esac
