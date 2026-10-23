#!/usr/bin/env bash

# The Nix wrapper sets this variable before this text:
#   primary  the registry primary output.
#
# Mango sets xwayland_ignore_scale, so X11 clients render in device pixels.
# Xft.dpi at 96 times the live scale of the primary output gives Xft clients
# the size of Wayland clients on that output. Mango reports each output
# change on the all-monitors stream, and also each focus change, so the
# script waits for a burst to settle, then queries the scale once. A failed
# query or xrdb call leaves Xft.dpi as it is, and the next event retries.

settle=1
applied=""

apply() {
	local scale dpi
	scale=$(compositor-query output-scale "$primary") || return 0
	dpi=$(jq -n --argjson scale "$scale" '96 * $scale | round') || return 0
	[ "$dpi" = "$applied" ] && return 0
	if printf 'Xft.dpi: %s\n' "$dpi" | xrdb -nocpp -merge; then
		applied=$dpi
		echo "Xft.dpi ${dpi} for ${primary} at scale ${scale}"
	fi
}

apply
while read -r _; do
	while read -r -t "$settle" _; do :; done
	apply
done < <(mmsg watch all-monitors)

# The stream ends when Mango exits. systemd restarts the service if Mango
# still runs.
exit 1
