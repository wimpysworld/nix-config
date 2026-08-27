#!/usr/bin/env bash

# Long-running applier that keeps every lan-mouse client's enter hook
# set to "lan-mouse-handoff <hostname>".  The daemon is the single
# source of truth for topology, so clients added or renamed in the GUI
# are hooked on the fly.  The configuration is never saved: the applier
# re-applies every session and config.toml stays the GUI's file.
#
# A return crossing (the emulated cursor leaves the peer's screen) runs
# no hook, so a journal follower closes the gap: it watches the daemon
# log, queries the peer's frozen cursor over SSH, and warps the local
# cursor to the matching fraction.
#
# The applier and the follower run as two background jobs because each
# blocks on its own stream.  Bash cannot share arrays across processes,
# so the applier writes one file per client handle in a private runtime
# directory and the follower reads that file on a return.  When either
# job dies the script exits and systemd restarts both together.

runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
lan_mouse_socket="$runtime/lan-mouse-socket.sock"
state_dir=$(mktemp -d "$runtime/lan-mouse-hookd.XXXXXX")

# The same SSH options as lan-mouse-handoff, so the follower rides the
# control master that the applier pre-warms.
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

# Best effort: pre-warm one SSH control master per client address so
# the first crossing does not pay connection setup.
function prewarm() {
	local address="$1"
	if [ -z "$address" ] || [ -n "${prewarmed[$address]:-}" ]; then
		return 0
	fi
	prewarmed[$address]=1
	timeout 5 ssh \
		-o BatchMode=yes \
		-o ConnectTimeout=2 \
		-o ControlMaster=auto \
		-o ControlPath="$runtime/lan-mouse-ssh-%C" \
		-o ControlPersist=yes \
		-o StrictHostKeyChecking=accept-new \
		"$address" true > /dev/null 2>&1 || true
}

function apply_hooks() {
	local backoff=1 line handle hostname pos cmd address desired
	declare -A prewarmed
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
				# Record the tuple for the journal follower.
				printf '%s %s %s\n' "$hostname" "$pos" "$address" > "$state_dir/client-$handle"
				desired="lan-mouse-handoff $hostname $pos $address"
				if [ "$cmd" != "$desired" ]; then
					printf '{"UpdateEnterHook":[%s,"%s"]}\n' "$handle" "$desired" >&"${LMSOCK[1]}" || break
				fi
				prewarm "$address" &
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

# Mirror one return crossing: read the peer's frozen cursor as a
# fraction along its exit edge, then warp the local cursor to the same
# fraction on the local edge the client sits on.  Every failure logs
# and returns so the follower never hangs and never crashes.
function handle_return() {
	local hostname pos address opposite fraction
	local state_file="$state_dir/client-$active_handle"
	active_handle=""
	if ! read -r hostname pos address < "$state_file" 2> /dev/null; then
		echo "lan-mouse-hookd: no recorded client for the return" >&2
		return 0
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
