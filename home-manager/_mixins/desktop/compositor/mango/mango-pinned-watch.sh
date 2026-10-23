#!/usr/bin/env bash

# The Nix wrapper sets this variable before this text:
#   owners  a JSON object that maps a pinned tag number to its output.
#
# Mango moves the windows of a removed monitor to the focused monitor and keeps
# their tags. On reconnect it returns only the windows that it recorded for that
# monitor, and the new monitor views tag 1. This script waits for the set of
# monitors to change and settle, then puts each window back on the owner of its
# first pinned tag, and makes each owner view one of its own tags. Windows and
# owners stay as they are while an owner is absent. Focus returns to the window
# or monitor that had it before the moves.

settle=1

# Prints one dispatch for each window that sits away from the owner of its first
# pinned tag. Global and scratchpad windows stay where they are.
moves() {
	jq -nr --argjson owners "$owners" --argjson m "$1" --argjson c "$2" '
		($m.monitors | map(.name)) as $names
		| $c.clients[]
		| select(.monitor != "" and ((.is_global or .is_scratchpad or .is_namedscratchpad) | not))
		| ([.tags[] | tostring | $owners[.] // empty][0]) as $owner
		| select($owner != null and ($names | index($owner)) != null and .monitor != $owner)
		| "tagmon,^\($owner)$,1 client,\(.id)"'
}

# Prints one dispatch for each owner that views a tag it does not own. The owner
# views its first own tag with windows, else its first own tag. Overview, with
# tag 0, stays as it is.
views() {
	jq -r --argjson owners "$owners" '
		.monitors[]
		| .name as $name
		| ($owners | to_entries | map(select(.value == $name) | .key | tonumber) | sort) as $own
		| select($own != [] and (.active_tags | length > 0) and (.active_tags | index(0)) == null)
		| select(any(.active_tags[]; . as $t | $own | index($t) == null))
		| .tags as $tags
		| ([$own[] | select(. as $t | $tags | any(.index == $t and .client_count > 0))] + $own)[0] as $tag
		| "viewcrossmon,\($tag),^\($name)$"' <<<"$1"
}

dispatch() {
	# The word splits into the dispatch and its optional client argument.
	# shellcheck disable=SC2086
	mmsg dispatch $1 >/dev/null || true
}

reconcile() {
	local monitors clients focused active command
	local -a commands=()
	local dispatched=0

	monitors="$(mmsg get all-monitors)" || return 0
	clients="$(mmsg get all-clients)" || return 0
	focused="$(mmsg get focusing-client | jq -r '.id // empty')" || focused=""
	active="$(jq -r '.monitors[] | select(.active) | .name' <<<"$monitors")"

	mapfile -t commands < <(moves "$monitors" "$clients")
	for command in "${commands[@]}"; do
		dispatch "$command"
		dispatched=1
	done

	# A move makes the owner view the tag of the window, so read the views again.
	if ((dispatched)); then
		monitors="$(mmsg get all-monitors)" || return 0
	fi
	mapfile -t commands < <(views "$monitors")
	for command in "${commands[@]}"; do
		dispatch "$command"
		dispatched=1
	done

	if ((!dispatched)); then
		return 0
	fi
	if [ -n "$focused" ]; then
		dispatch "focusid client,$focused"
	elif [ -n "$active" ]; then
		dispatch "focusmon,^${active}\$"
	fi
}

previous=""
mmsg watch all-monitors |
	jq --unbuffered -c '[.monitors[].name] | sort' |
	while IFS= read -r names; do
		# Mango sends a burst of events for one change. Act on the last one.
		while IFS= read -r -t "$settle" next; do
			names="$next"
		done
		if [ "$names" = "$previous" ]; then
			continue
		fi
		previous="$names"
		reconcile
	done
