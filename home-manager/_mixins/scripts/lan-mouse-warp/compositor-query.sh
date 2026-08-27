# Shared compositor detection and monitor queries for lan-mouse-warp
# and lan-mouse-handoff.  Both scripts run without session environment
# variables, so detection works from the runtime directory alone.

function detect_compositor() {
	local runtime signature candidate
	runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
	signature=$(find "$runtime/hypr" -mindepth 1 -maxdepth 1 -printf '%T@ %f\n' 2> /dev/null | sort -rn | head -n 1 | cut -d ' ' -f 2-)
	if [ -n "$signature" ]; then
		COMPOSITOR="hyprland"
		export HYPRLAND_INSTANCE_SIGNATURE="${HYPRLAND_INSTANCE_SIGNATURE:-$signature}"
		return 0
	fi
	for candidate in "${WAYFIRE_SOCKET:-}" "$runtime"/wayfire-*.socket /tmp/wayfire-*.socket; do
		if [ -S "$candidate" ]; then
			COMPOSITOR="wayfire"
			export WAYFIRE_SOCKET="$candidate"
			return 0
		fi
	done
	echo "${0##*/}: no supported compositor detected" >&2
	return 1
}

# Print the monitor layout as a JSON array of geometries in logical
# layout coordinates.
function compositor_monitors() {
	case "$COMPOSITOR" in
	hyprland)
		# Hyprland reports the physical pixel size plus scale and
		# transform.  The logical extent is the size divided by the
		# scale, with the axes swapped for the 90 and 270 degree
		# transforms (odd values).  Verify against ravi at scale 1.5.
		hyprctl -j monitors | jq -c '[.[] | {
			x,
			y,
			width: (if (.transform % 2) == 1 then (.height / .scale) else (.width / .scale) end),
			height: (if (.transform % 2) == 1 then (.width / .scale) else (.height / .scale) end)
		}]'
		;;
	wayfire)
		# The ipc-rules list-outputs geometry is the layout geometry,
		# already in logical layout coordinates.
		lan-mouse-wayfire-ipc outputs | jq -c '[.[] | .geometry]'
		;;
	esac
}
