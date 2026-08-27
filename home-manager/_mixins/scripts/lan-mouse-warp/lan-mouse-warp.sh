#!/usr/bin/env bash

# Receiver-side warp for lan-mouse, invoked over SSH with no session
# environment.  Maps an entry edge and a fraction along that edge to
# the edge-most monitor, then warps the cursor to the matching point.
# The report mode is the reverse read: it prints the current cursor's
# fraction along an edge so the peer can mirror a return crossing.
# The serve mode reads warp and report lines from stdin over one
# held-open SSH session, so a crossing costs no process spawn.  It
# also watches the local lan-mouse daemon for incoming sessions and
# pushes the return correction upstream the moment the cursor touches
# the entry edge, because the controlled machine knows about a return
# before anyone else.

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

# Both arguments arrive over the network, so validate them strictly.
function valid_edge() {
	case "$1" in
		left | right | top | bottom) return 0 ;;
		*) return 1 ;;
	esac
}

function valid_fraction() {
	[[ "$1" =~ ^(0|1|0?\.[0-9]+|1\.0+)$ ]]
}

# Detect the compositor and read the monitor layout before every
# command, so a compositor restart between serve lines does not wedge
# the server.
function read_layout() {
	detect_compositor || return 1
	monitors=$(compositor_monitors)
	if [ -z "$monitors" ] || [ "$monitors" = "[]" ]; then
		echo "lan-mouse-warp: no monitors reported" >&2
		return 1
	fi
}

# Print the cursor's rounded perpendicular distance from the edge and
# its fraction along the edge axis, both on the edge-most monitor for
# that edge.  The fraction is clamped to the unit interval.  The
# report mode and the serve watcher share this read.
function cursor_metrics() {
	local edge="$1"
	read_layout || return 1
	if ! read -r cursor_x cursor_y < <(compositor_cursor); then
		echo "lan-mouse-warp: cannot read the cursor position" >&2
		return 1
	fi
	jq -n --argjson monitors "$monitors" --argjson x "$cursor_x" --argjson y "$cursor_y" --arg edge "$edge" -r '
		(if $edge == "left" then $monitors | min_by(.x)
		 elif $edge == "right" then $monitors | max_by(.x + .width)
		 elif $edge == "top" then $monitors | min_by(.y)
		 else $monitors | max_by(.y + .height) end) as $m
		| (if $edge == "left" then $x - $m.x
		   elif $edge == "right" then $m.x + $m.width - $x
		   elif $edge == "top" then $y - $m.y
		   else $m.y + $m.height - $y end) as $distance
		| ((if $edge == "left" or $edge == "right" then ($y - $m.y) / $m.height else ($x - $m.x) / $m.width end)
		   | if . < 0 then 0 elif . > 1 then 1 else . end) as $fraction
		| "\($distance | round) \($fraction)"
	'
}

# Read-only report mode: print the cursor's fraction along the edge
# axis on the edge-most monitor for that edge.  The peer's hookd
# queries this mode on a return.  The printf keeps the output at four
# decimal places with no scientific notation, so it always matches the
# fraction validation above.
function do_report() {
	local fraction
	if ! read -r _ fraction < <(cursor_metrics "$1"); then
		return 1
	fi
	LC_ALL=C printf '%.4f\n' "$fraction"
}

# Select the edge-most monitor for the entry edge, then place the
# target two logical pixels inside that edge, the fraction along the
# edge axis, clamped inside the monitor.
function do_warp() {
	local edge="$1" fraction="$2"
	read_layout || return 1
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
		return 1
	fi
	compositor_warp "$target_x" "$target_y" || return 1
	# Log one line per warp for the latency measurement.
	mkdir -p "$HOME/.cache"
	printf '%s %s %s %s %s\n' "$(date +%s.%3N)" "$edge" "$fraction" "$target_x" "$target_y" >> "$HOME/.cache/lan-mouse-warp.log"
}

function opposite_edge() {
	case "$1" in
		left) echo "right" ;;
		right) echo "left" ;;
		top) echo "bottom" ;;
		bottom) echo "top" ;;
	esac
}

# The serve watcher state.  A DeviceEntered event from the local
# daemon arms the watcher with the entry edge.  The guard stays
# closed until the cursor moves more than 15 logical pixels inward,
# because the peer's entry warp parks the cursor 2 pixels inside that
# same edge and must not fire a push.
armed_edge=""
guard_open=0
events_fd=""
events_pid=""
events_backoff=1
events_retry_at=0

# Connect a socat coproc to the local lan-mouse daemon socket.  The
# daemon pushes newline-delimited JSON events; serve only reads.  The
# coproc fd is duplicated because bash closes its own copy when the
# coproc dies, and the duplicate keeps buffered events readable.
function events_connect() {
	local socket="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/lan-mouse-socket.sock"
	if [ ! -S "$socket" ]; then
		return 1
	fi
	coproc LMEVENTS { socat -u "UNIX-CONNECT:$socket" -; }
	events_pid="$LMEVENTS_PID"
	exec {events_fd}<&"${LMEVENTS[0]}"
}

# Drain pending daemon events without blocking.  When the coproc is
# dead (daemon restart), reconnect with capped backoff so command
# handling never stalls.  When the socket stays unavailable, serve
# degrades to the plain command loop.
function events_poll() {
	local event pos
	if [ -z "$events_fd" ]; then
		if [ "$SECONDS" -lt "$events_retry_at" ]; then
			return 0
		fi
		if ! events_connect; then
			events_retry_at=$((SECONDS + events_backoff))
			if [ "$events_backoff" -lt 30 ]; then
				events_backoff=$((events_backoff * 2))
			fi
			return 0
		fi
	fi
	# read -t 0 only checks for input; the blocking read that follows
	# consumes one whole line.
	while read -r -t 0 -u "$events_fd"; do
		if ! read -r -u "$events_fd" event; then
			exec {events_fd}<&-
			events_fd=""
			wait "$events_pid" 2> /dev/null || true
			events_pid=""
			events_retry_at=$((SECONDS + events_backoff))
			if [ "$events_backoff" -lt 30 ]; then
				events_backoff=$((events_backoff * 2))
			fi
			return 0
		fi
		events_backoff=1
		pos=$(jq -r '.DeviceEntered.pos // empty' <<< "$event" 2> /dev/null || true)
		if [ -n "$pos" ] && valid_edge "$pos"; then
			# Re-arm on every DeviceEntered.
			armed_edge="$pos"
			guard_open=0
		fi
	done
}

# One armed cursor poll.  Open the guard once the cursor is more than
# 15 logical pixels from the armed edge; then, when the distance drops
# to 2 pixels or less, emit one return line and disarm.  A failed
# compositor read skips this poll.
function watch_poll() {
	local distance fraction
	if ! read -r distance fraction < <(cursor_metrics "$armed_edge"); then
		return 0
	fi
	if [ "$guard_open" -eq 0 ]; then
		if [ "$distance" -gt 15 ]; then
			guard_open=1
		fi
		return 0
	fi
	if [ "$distance" -le 2 ]; then
		LC_ALL=C printf 'return %s %.4f\n' "$(opposite_edge "$armed_edge")" "$fraction"
		armed_edge=""
		guard_open=0
	fi
}

# Serve mode: the peer's hookd bridges stdin to a named pipe over one
# held-open SSH session and reads this stdout.  A warp line answers
# nothing, a report line answers one fraction line, an invalid line
# logs and the loop continues, and EOF on stdin ends the session
# cleanly.  Between commands the loop drains local daemon events and,
# when armed, polls the cursor so a return crossing pushes one
# "return <edge> <fraction>" line upstream.  An idle unarmed serve
# spawns nothing.
function serve() {
	local cmd a b rest rc interval
	while true; do
		if [ -n "$armed_edge" ]; then
			interval=0.04
		else
			interval=0.5
		fi
		cmd="" a="" b="" rest="" rc=0
		IFS=' ' read -r -t "$interval" cmd a b rest || rc=$?
		if [ "$rc" -eq 0 ]; then
			case "$cmd" in
				warp)
					if [ -z "$rest" ] && valid_edge "$a" && valid_fraction "$b"; then
						do_warp "$a" "$b" || true
					else
						echo "lan-mouse-warp: invalid serve line: $cmd $a $b $rest" >&2
					fi
					;;
				report)
					if [ -z "$b$rest" ] && valid_edge "$a"; then
						# A failed report answers nothing; the peer's read
						# timeout covers it.
						do_report "$a" || true
					else
						echo "lan-mouse-warp: invalid serve line: $cmd $a $b $rest" >&2
					fi
					;;
				*)
					echo "lan-mouse-warp: invalid serve line: $cmd $a $b $rest" >&2
					;;
			esac
		elif [ "$rc" -le 128 ]; then
			# EOF: the peer closed the channel.
			break
		fi
		events_poll
		if [ -n "$armed_edge" ]; then
			watch_poll
		fi
	done
}

if [ $# -eq 1 ] && [ "$1" = "serve" ]; then
	serve
	exit 0
fi
if [ $# -ne 2 ]; then
	echo "Usage: lan-mouse-warp <left|right|top|bottom> <fraction>" >&2
	echo "       lan-mouse-warp report <left|right|top|bottom>" >&2
	echo "       lan-mouse-warp serve" >&2
	exit 2
fi
if [ "$1" = "report" ]; then
	if ! valid_edge "$2"; then
		echo "lan-mouse-warp: invalid edge $2" >&2
		exit 2
	fi
	do_report "$2"
else
	if ! valid_edge "$1"; then
		echo "lan-mouse-warp: invalid edge $1" >&2
		exit 2
	fi
	if ! valid_fraction "$2"; then
		echo "lan-mouse-warp: invalid fraction $2" >&2
		exit 2
	fi
	do_warp "$1" "$2"
fi
