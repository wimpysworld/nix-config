#!/usr/bin/env bash

# Sender-side enter hook for lan-mouse.  The daemon runs this script
# when the cursor is captured for a client.  It reads the crossing
# point from the local compositor and asks the peer to warp its cursor
# to the matching fraction along the opposite edge.

# Print the cursor position in logical layout coordinates.
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

# The position and address are baked into the hook command by
# lan-mouse-hookd, which rewrites the hook whenever the daemon reports
# a change.  Querying the daemon here would stall the hot path: the
# state-push read holds its socket open until a timeout, and every
# millisecond before the warp is a visible cursor jump on the peer.
if [ $# -ne 3 ]; then
	echo "Usage: lan-mouse-handoff <client-hostname> <position> <address>" >&2
	exit 2
fi
client="$1"
position="$2"
address="$3"
runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# The entry edge on the peer is the opposite of the client position.
case "$position" in
	left) entry_edge="right" ;;
	right) entry_edge="left" ;;
	top) entry_edge="bottom" ;;
	bottom) entry_edge="top" ;;
	*)
		echo "lan-mouse-handoff: unknown position $position" >&2
		exit 1
		;;
esac

detect_compositor || exit 1
if ! read -r cursor_x cursor_y < <(compositor_cursor); then
	echo "lan-mouse-handoff: cannot read the cursor position" >&2
	exit 1
fi
monitors=$(compositor_monitors)
if [ -z "$monitors" ] || [ "$monitors" = "[]" ]; then
	echo "lan-mouse-handoff: no monitors reported" >&2
	exit 1
fi

# The fraction is measured along the exit edge of the monitor that
# contains the cursor: the x axis for top and bottom, the y axis for
# left and right, clamped to the unit interval.  Four decimal places
# keep jq away from scientific notation, which the receiver rejects.
fraction=$(jq -n --argjson monitors "$monitors" --argjson x "$cursor_x" --argjson y "$cursor_y" --arg pos "$position" '
	(first($monitors[] | select($x >= .x and $x <= (.x + .width) and $y >= .y and $y <= (.y + .height))) // $monitors[0]) as $m
	| if $pos == "top" or $pos == "bottom" then ($x - $m.x) / $m.width else ($y - $m.y) / $m.height end
	| if . < 0 then 0 elif . > 1 then 1 else . end
	| . * 10000 | round | . / 10000
')

# Hard timeout so a dead peer degrades to current behaviour.  The
# remote login shell is fish, so the command is one plain line.
if ! timeout 0.25s ssh \
	-o BatchMode=yes \
	-o ConnectTimeout=1 \
	-o ControlMaster=auto \
	-o ControlPath="$runtime/lan-mouse-ssh-%C" \
	-o ControlPersist=yes \
	-o StrictHostKeyChecking=accept-new \
	"$address" "lan-mouse-warp $entry_edge $fraction"; then
	echo "lan-mouse-handoff: warp on $client ($address) failed" >&2
	exit 1
fi
