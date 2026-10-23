#!/usr/bin/env bash

# Each case writes the Mango state, runs the watcher once, and compares the
# recorded dispatches. lib/tests/mango-pinned-watch.nix runs this script.

set -euo pipefail

: "${out:?}"

watcher=$1
export FAKE_STATE="$TMPDIR/state"

monitor() {
	local name=$1 active=$2 view=$3
	jq -nc --arg name "$name" --argjson active "$active" --argjson view "$view" '{
		name: $name,
		active: $active,
		active_tags: [$view],
		tags: [range(1; 9) | {index: ., is_active: (. == $view), client_count: 0}]
	}'
}

client() {
	jq -nc --argjson id "$1" --arg monitor "$2" --argjson tags "$3" '{
		id: $id, monitor: $monitor, tags: $tags,
		is_global: false, is_scratchpad: false, is_namedscratchpad: false
	}'
}

run_case() {
	local name=$1 monitors=$2 clients=$3 expected=$4

	rm -rf "$FAKE_STATE"
	mkdir -p "$FAKE_STATE"
	jq -sc '{monitors: .}' <<<"$monitors" >"$FAKE_STATE/monitors.json"
	jq -sc '{clients: .}' <<<"$clients" >"$FAKE_STATE/clients.json"
	echo '{"id":12}' >"$FAKE_STATE/focus.json"
	touch "$FAKE_STATE/dispatches"

	"$watcher"
	if ! diff -u <(printf '%s' "$expected") "$FAKE_STATE/dispatches"; then
		echo "FAIL: $name" >&2
		exit 1
	fi
	echo "PASS: $name"
}

edp=$(monitor eDP-1 true 1)
windows="$(client 11 eDP-1 '[8]')
$(client 12 eDP-1 '[1]')
$(client 13 eDP-1 '[3]')"

run_case "a tag 8 window moves to DP-3, and DP-3 views tag 8" \
	"$edp
$(monitor DP-3 false 1)" \
	"$windows" \
	'tagmon,^DP-3$,1 client,11
viewcrossmon,8,^DP-3$
focusid client,12
'

run_case "nothing happens while DP-3 is absent" \
	"$edp" \
	"$windows" \
	''

run_case "nothing happens when every window and view is on its owner" \
	"$edp
$(monitor DP-3 false 8)" \
	"$(client 11 DP-3 '[8]')
$(client 12 eDP-1 '[1]')
$(client 13 eDP-1 '[3]')" \
	''

touch "$out"
