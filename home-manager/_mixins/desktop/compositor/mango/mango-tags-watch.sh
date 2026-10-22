#!/usr/bin/env bash

# The Nix wrapper sets these variables before this text:
#   mode     synced or pinned.
#   primary  the primary output.
#   owners   a JSON object that maps a pinned tag number to its output.
#   signal   the Waybar signal number of the custom/tagN modules.
#
# Each Mango event gives the tags of every monitor. This script merges them
# into one state for each tag 1-8 and writes one Waybar JSON line per tag.
# Synced tags merge all monitors. A pinned tag reads its own output. A tag
# without an output, or with an absent output, reads the primary output.
# Waybar gets the signal only when the merged state changes.

state="${XDG_RUNTIME_DIR:?}/mango-tags"
previous=""

mmsg watch all-tags |
	jq --unbuffered -c --arg mode "$mode" --arg primary "$primary" --argjson owners "$owners" '
		.all_tags as $monitors
		| ($monitors | map(.monitor)) as $names
		| (if ($names | any(. == $primary)) then $primary else ($names[0] // "") end) as $fallback
		| [range(1; 9) as $n
			| ($n | tostring) as $tag
			| (if $mode == "synced" then $monitors
				else
					($owners[$tag] // $fallback) as $owner
					| (if ($names | any(. == $owner)) then $owner else $fallback end) as $output
					| $monitors | map(select(.monitor == $output))
				end
				| map(.tags[] | select(.index == $n))) as $states
			| {
				text: $tag,
				class: [
					(if any($states[]; .is_active) then "active" else empty end),
					(if any($states[]; .is_urgent) then "urgent" else empty end),
					(if ($states | map(.client_count) | add // 0) > 0 then "occupied" else empty end)
				]
			}]' |
	while IFS= read -r line; do
		if [ "$line" = "$previous" ]; then
			continue
		fi
		previous="$line"
		tmp="$(mktemp "$state.XXXXXX")"
		jq -c '.[]' <<<"$line" >"$tmp"
		mv -f "$tmp" "$state"
		# Only the main process handles the signal. Its children, for example
		# module scripts, would end on an unhandled real-time signal.
		systemctl --user kill --kill-whom=main --signal="RTMIN+$signal" waybar.service 2>/dev/null || true
	done
