#!/usr/bin/env bash

# Long-running applier that keeps every lan-mouse client's enter hook
# set to "lan-mouse-handoff <hostname>".  The daemon is the single
# source of truth for topology, so clients added or renamed in the GUI
# are hooked on the fly.  The configuration is never saved: the applier
# re-applies every session and config.toml stays the GUI's file.
#
# A return crossing (the emulated cursor leaves the peer's screen) runs
# no hook.  The peer's "lan-mouse-warp serve" watcher pushes the
# corrected fraction over the held-open channel the moment its cursor
# touches the entry edge, and the channel keeper warps locally.  A
# journal follower stays as the fallback: it watches the daemon log
# and, when no push arrived within the last two seconds, queries the
# peer's frozen cursor over SSH and warps to the matching fraction.
#
# The applier and the follower run as two background jobs because each
# blocks on its own stream.  Bash cannot share arrays across processes,
# so the applier writes one file per client handle in a private runtime
# directory and the follower reads that file on a return.  When either
# job dies the script exits and systemd restarts both together.

runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
lan_mouse_socket="$runtime/lan-mouse-socket.sock"
state_dir=$(mktemp -d "$runtime/lan-mouse-hookd.XXXXXX")

# The same SSH options as lan-mouse-handoff, so the direct fallback
# rides the control master that the channel keeper's connection opens.
ssh_options=(
	-o BatchMode=yes
	-o ConnectTimeout=1
	-o ControlMaster=auto
	-o ControlPath="$runtime/lan-mouse-ssh-%C"
	-o ControlPersist=yes
	-o StrictHostKeyChecking=accept-new
)

# Wait for the daemon socket for up to ten seconds.
for _ in $(seq 1 100); do
	if [ -S "$lan_mouse_socket" ]; then
		break
	fi
	sleep 0.1
done
if [ ! -S "$lan_mouse_socket" ]; then
	echo "lan-mouse-hookd: $lan_mouse_socket did not appear" >&2
	exit 1
fi

# Apply one pushed return from a channel keeper: the controlled peer's
# serve watcher saw its cursor touch the session's entry edge and sent
# the corrected fraction upstream.  The pushed edge must match the
# client's recorded position, so a peer cannot warp an arbitrary edge.
# The marker file makes the journal follower a fallback only.  The
# position is read from the pos-<hostname> file the applier writes,
# because the keeper knows its hostname but not its handle.
function dispatch_return() {
	local hostname="$1" edge="$2" fraction="$3" pos
	if ! read -r pos < "$state_dir/pos-$hostname" 2> /dev/null; then
		echo "lan-mouse-hookd: no recorded position for $hostname" >&2
		return 0
	fi
	case "$edge" in
		left | right | top | bottom) ;;
		*)
			echo "lan-mouse-hookd: invalid pushed edge '$edge' from $hostname" >&2
			return 0
			;;
	esac
	if [[ ! "$fraction" =~ ^(0|1|0?\.[0-9]+|1\.0+)$ ]]; then
		echo "lan-mouse-hookd: invalid pushed fraction '$fraction' from $hostname" >&2
		return 0
	fi
	if [ "$edge" != "$pos" ]; then
		echo "lan-mouse-hookd: pushed edge $edge does not match $hostname at $pos" >&2
		return 0
	fi
	if lan-mouse-warp "$pos" "$fraction"; then
		date +%s > "$state_dir/last-return-$hostname"
	else
		echo "lan-mouse-hookd: local warp for the pushed return failed" >&2
	fi
	return 0
}

# One channel keeper per client hostname holds a persistent
# "lan-mouse-warp serve" session on the peer.  The handoff and the
# return mirror write one line to the .in pipe instead of spawning
# ssh, so a crossing costs one round trip.  The keeper is the only
# reader of ssh stdout: the peer's serve watcher pushes
# "return <edge> <fraction>" lines there and the keeper warps locally.
# The keeper restarts the channel with capped backoff when it dies
# (peer reboot, laptop sleep).
function channel_keeper() {
	local hostname="$1" address="$2" backoff=1 in_hold ssh_out ssh_pid
	local cmd edge fraction rest
	local in_fifo="$runtime/lan-mouse-chan-$hostname.in"
	if [ ! -p "$in_fifo" ]; then
		rm -f "$in_fifo"
		mkfifo "$in_fifo"
	fi
	# Hold the pipe open read-write from here: a writer on .in never
	# blocks waiting for a reader while ssh restarts, and ssh never
	# sees EOF between crossings.
	exec {in_hold}<> "$in_fifo"
	# The applier kills the keeper on an address change; take the
	# bridged ssh down with it so the pipe keeps a single reader.
	trap 'if [ -n "${ssh_pid:-}" ]; then kill "$ssh_pid" 2> /dev/null; fi; exit 0' TERM
	while true; do
		# Drop lines queued while the channel was down; a warp
		# delivered seconds late would move the cursor unprompted.
		while read -r -t 0.01 -u "$in_hold" _; do :; done
		SECONDS=0
		exec {ssh_out}< <(ssh "${ssh_options[@]}" "$address" "lan-mouse-warp serve" < "$in_fifo")
		ssh_pid=$!
		while IFS=' ' read -r -u "$ssh_out" cmd edge fraction rest; do
			if [ "$cmd" = "return" ] && [ -z "$rest" ]; then
				dispatch_return "$hostname" "$edge" "$fraction"
			else
				echo "lan-mouse-hookd: unexpected channel line from $hostname: $cmd $edge $fraction $rest" >&2
			fi
		done
		exec {ssh_out}<&-
		wait "$ssh_pid" 2> /dev/null || true
		ssh_pid=""
		# A channel that lived a while earns a fast reconnect.
		if [ "$SECONDS" -ge 30 ]; then
			backoff=1
		fi
		sleep "$backoff"
		if [ "$backoff" -lt 30 ]; then
			backoff=$((backoff * 2))
		fi
	done
}

function apply_hooks() {
	local backoff=1 line handle hostname pos cmd address desired
	declare -A keeper_pids keeper_addresses
	while true; do
		coproc LMSOCK { socat - "UNIX-CONNECT:$lan_mouse_socket"; }
		while IFS= read -r line <&"${LMSOCK[0]}"; do
			backoff=1
			# Enumerate carries a list of [handle, config, state] tuples;
			# Created and State carry a single tuple of the same shape.
			# Setting a hook triggers a State event whose cmd then matches,
			# so re-application converges instead of looping.  The position
			# and address are baked into the hook command so that the hook
			# never has to query the daemon on the crossing hot path; a
			# position or address change raises a State event and the hook
			# is rewritten here.
			while IFS=$'\t' read -r handle hostname pos cmd address; do
				if [[ ! "$handle" =~ ^[0-9]+$ ]] || [[ ! "$hostname" =~ ^[A-Za-z0-9._-]+$ ]]; then
					continue
				fi
				case "$pos" in
					left | right | top | bottom) ;;
					*) continue ;;
				esac
				if [[ ! "$address" =~ ^[0-9A-Fa-f.:]+$ ]]; then
					# No resolved address yet; a State event follows once
					# DNS resolves, and the hook is set then.
					continue
				fi
				# Record the tuple for the journal follower, and the
				# position keyed by hostname for the channel keeper's
				# push dispatch, which knows no handle.
				printf '%s %s %s\n' "$hostname" "$pos" "$address" > "$state_dir/client-$handle"
				printf '%s\n' "$pos" > "$state_dir/pos-$hostname"
				desired="lan-mouse-handoff $hostname $pos $address"
				if [ "$cmd" != "$desired" ]; then
					printf '{"UpdateEnterHook":[%s,"%s"]}\n' "$handle" "$desired" >&"${LMSOCK[1]}" || break
				fi
				# Keepers are tracked by hostname so repeated State
				# events never spawn duplicates.  An address change
				# replaces the keeper; a client removed in the GUI
				# leaves a harmless keeper that retries with backoff
				# until the next hookd restart.
				if [ "${keeper_addresses[$hostname]:-}" != "$address" ]; then
					if [ -n "${keeper_pids[$hostname]:-}" ]; then
						kill "${keeper_pids[$hostname]}" 2> /dev/null || true
					fi
					channel_keeper "$hostname" "$address" &
					keeper_pids[$hostname]=$!
					keeper_addresses[$hostname]="$address"
				fi
			done < <(jq -r '
				select(type == "object")
				| (.Enumerate // empty)[], (.Created // empty), (.State // empty)
				| [(.[0] | tostring), .[1].hostname, (.[1].pos // ""), (.[1].cmd // ""), (.[2].ips[0] // "")]
				| @tsv
			' <<< "$line" 2> /dev/null || true)
		done
		# Reconnect with backoff when the daemon closes the socket.
		wait "$LMSOCK_PID" 2> /dev/null || true
		sleep "$backoff"
		if [ "$backoff" -lt 10 ]; then
			backoff=$((backoff * 2))
		fi
	done
}

# Mirror one return crossing that the channel keeper's push missed:
# read the peer's frozen cursor as a fraction along its exit edge over
# a direct ssh exec, then warp the local cursor to the same fraction
# on the local edge the client sits on.  The keeper's marker file
# skips the mirror when a push already handled this return, so the
# journal follower is the fallback only.  Every failure logs and
# returns so the follower never hangs and never crashes.
function handle_return() {
	local hostname pos address opposite fraction marker now
	local state_file="$state_dir/client-$active_handle"
	active_handle=""
	if ! read -r hostname pos address < "$state_file" 2> /dev/null; then
		echo "lan-mouse-hookd: no recorded client for the return" >&2
		return 0
	fi
	if read -r marker < "$state_dir/last-return-$hostname" 2> /dev/null &&
		[[ "$marker" =~ ^[0-9]+$ ]]; then
		now=$(date +%s)
		if [ $((now - marker)) -lt 2 ]; then
			return 0
		fi
	fi
	case "$pos" in
		left) opposite="right" ;;
		right) opposite="left" ;;
		top) opposite="bottom" ;;
		bottom) opposite="top" ;;
		*) return 0 ;;
	esac
	if ! fraction=$(timeout 1s ssh "${ssh_options[@]}" "$address" "lan-mouse-warp report $opposite"); then
		echo "lan-mouse-hookd: cursor report from $hostname ($address) failed" >&2
		return 0
	fi
	if [[ ! "$fraction" =~ ^(0|1|0?\.[0-9]+|1\.0+)$ ]]; then
		echo "lan-mouse-hookd: invalid fraction '$fraction' from $hostname" >&2
		return 0
	fi
	if ! lan-mouse-warp "$pos" "$fraction"; then
		echo "lan-mouse-hookd: local warp for the return failed" >&2
	fi
	return 0
}

function follow_returns() {
	local active_handle="" line
	while true; do
		# Follow the daemon journal from now on, never replaying old
		# lines.  "entering client <handle>" opens an outgoing session;
		# "releasing capture: left remote client device region" is a
		# return from that session.
		while IFS= read -r line; do
			if [[ "$line" =~ entering\ client\ ([0-9]+) ]]; then
				active_handle="${BASH_REMATCH[1]}"
			elif [[ "$line" == *"left remote client device region"* ]] && [ -n "$active_handle" ]; then
				handle_return
			fi
		done < <(journalctl --user -u lan-mouse -o cat -n 0 -f)
		# journalctl exited; restart the follower after a pause.
		sleep 2
	done
}

apply_hooks &
applier_pid=$!
follow_returns &
follower_pid=$!
trap 'kill "$applier_pid" "$follower_pid" 2> /dev/null; rm -rf "$state_dir"' EXIT

# Exit when the first job dies so systemd restarts the pair.
wait -n
exit 1
