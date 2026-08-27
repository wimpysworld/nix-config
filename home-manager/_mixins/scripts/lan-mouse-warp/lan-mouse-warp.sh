#!/usr/bin/env bash

# Receiver-side warp for lan-mouse, invoked over SSH with no session
# environment.  Maps an entry edge and a fraction along that edge to
# the edge-most monitor, then warps the cursor to the matching point.
# The report mode is the reverse read: it prints the current cursor's
# fraction along an edge so the peer can mirror a return crossing.

# Print the cursor position in logical layout coordinates, as in
# lan-mouse-handoff.  Shellcheck rejects a shared copy in
# compositor-query.sh as unused there, so each script keeps its own.
function compositor_cursor() {
	case "$COMPOSITOR" in
	hyprland)
		hyprctl -j cursorpos | jq -r '"\(.x) \(.y)"'
		;;
	wayfire)
		lan-mouse-wayfire-ipc cursor | jq -r '"\(.pos.x) \(.pos.y)"'
		;;
	esac
}

# Warp the cursor to a point in global layout coordinates.
function compositor_warp() {
	case "$COMPOSITOR" in
	hyprland)
		hyprctl dispatch movecursor "$1" "$2" > /dev/null
		;;
	wayfire)
		# The stipc do_motion handler subtracts the global cursor
		# position, so move_cursor takes global layout coordinates.
		# Confirm at runtime on felkor.
		lan-mouse-wayfire-ipc move-cursor "{\"x\": $1, \"y\": $2}" > /dev/null
		;;
	esac
}

if [ $# -ne 2 ]; then
	echo "Usage: lan-mouse-warp <left|right|top|bottom> <fraction>" >&2
	echo "       lan-mouse-warp report <left|right|top|bottom>" >&2
	exit 2
fi
if [ "$1" = "report" ]; then
	mode="report"
	edge="$2"
else
	mode="warp"
	edge="$1"
	fraction="$2"
fi

# Both arguments arrive over the network, so validate them strictly.
case "$edge" in
	left | right | top | bottom) ;;
	*)
		echo "lan-mouse-warp: invalid edge $edge" >&2
		exit 2
		;;
esac
if [ "$mode" = "warp" ] && [[ ! "$fraction" =~ ^(0|1|0?\.[0-9]+|1\.0+)$ ]]; then
	echo "lan-mouse-warp: invalid fraction $fraction" >&2
	exit 2
fi

detect_compositor || exit 1
monitors=$(compositor_monitors)
if [ -z "$monitors" ] || [ "$monitors" = "[]" ]; then
	echo "lan-mouse-warp: no monitors reported" >&2
	exit 1
fi

# Read-only report mode: print the cursor's fraction along the edge
# axis on the edge-most monitor for that edge, clamped to the unit
# interval.  The peer's hookd queries this mode on a return.  The
# printf keeps the output at four decimal places with no scientific
# notation, so it always matches the fraction validation above.
if [ "$mode" = "report" ]; then
	if ! read -r cursor_x cursor_y < <(compositor_cursor); then
		echo "lan-mouse-warp: cannot read the cursor position" >&2
		exit 1
	fi
	fraction=$(jq -n --argjson monitors "$monitors" --argjson x "$cursor_x" --argjson y "$cursor_y" --arg edge "$edge" '
		(if $edge == "left" then $monitors | min_by(.x)
		 elif $edge == "right" then $monitors | max_by(.x + .width)
		 elif $edge == "top" then $monitors | min_by(.y)
		 else $monitors | max_by(.y + .height) end) as $m
		| (if $edge == "left" or $edge == "right" then ($y - $m.y) / $m.height else ($x - $m.x) / $m.width end)
		| if . < 0 then 0 elif . > 1 then 1 else . end
	')
	LC_ALL=C printf '%.4f\n' "$fraction"
	exit 0
fi

# Select the edge-most monitor for the entry edge, then place the
# target two logical pixels inside that edge, the fraction along the
# edge axis, clamped inside the monitor.
if ! read -r target_x target_y < <(jq -r --arg edge "$edge" --argjson fraction "$fraction" '
	def clamp($lo; $hi): if . < $lo then $lo elif . > $hi then $hi else . end;
	(if $edge == "left" then min_by(.x)
	 elif $edge == "right" then max_by(.x + .width)
	 elif $edge == "top" then min_by(.y)
	 else max_by(.y + .height) end) as $m
	| (if $edge == "left" then $m.x + 2
	   elif $edge == "right" then $m.x + $m.width - 2
	   else $m.x + ($fraction * $m.width) end) as $tx
	| (if $edge == "top" then $m.y + 2
	   elif $edge == "bottom" then $m.y + $m.height - 2
	   else $m.y + ($fraction * $m.height) end) as $ty
	| "\($tx | clamp($m.x + 2; $m.x + $m.width - 2) | round) \($ty | clamp($m.y + 2; $m.y + $m.height - 2) | round)"
' <<< "$monitors"); then
	echo "lan-mouse-warp: cannot compute the target point" >&2
	exit 1
fi

compositor_warp "$target_x" "$target_y"

# Log one line per warp for the latency measurement.
mkdir -p "$HOME/.cache"
printf '%s %s %s %s %s\n' "$(date +%s.%3N)" "$edge" "$fraction" "$target_x" "$target_y" >> "$HOME/.cache/lan-mouse-warp.log"
