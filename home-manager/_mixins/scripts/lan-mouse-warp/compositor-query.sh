# Shared compositor detection and monitor queries for lan-mouse-warp
# and lan-mouse-handoff.  Both scripts run without session environment
# variables, so detection works from the runtime directory alone.

function detect_compositor() {
	local runtime signature candidate
	runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
	# Mango unlinks its socket on exit, so a match is a live instance.
	signature="${MANGO_INSTANCE_SIGNATURE:-}"
	if [ ! -S "$signature" ]; then
		signature=$(find "$runtime" -mindepth 1 -maxdepth 1 -name 'mango-*.sock' -type s -printf '%T@ %p\n' 2> /dev/null | sort -rn | head -n 1 | cut -d ' ' -f 2-)
	fi
	if [ -S "$signature" ]; then
		COMPOSITOR="mango"
		export MANGO_INSTANCE_SIGNATURE="$signature"
		# wlrctl needs the Wayland display, which SSH sessions lack.
		if [ -z "${WAYLAND_DISPLAY:-}" ]; then
			WAYLAND_DISPLAY=$(find "$runtime" -mindepth 1 -maxdepth 1 -name 'wayland-*' ! -name '*.lock' -type s -printf '%T@ %f\n' 2> /dev/null | sort -rn | head -n 1 | cut -d ' ' -f 2-)
			export WAYLAND_DISPLAY
		fi
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
	mango)
		# mmsg reports the output layout box, already in logical
		# layout coordinates.
		mmsg get all-monitors | jq -c '[.monitors[] | {x, y, width, height}]'
		;;
	wayfire)
		# The ipc-rules list-outputs geometry is the layout geometry,
		# already in logical layout coordinates.
		lan-mouse-wayfire-ipc outputs | jq -c '[.[] | .geometry]'
		;;
	esac
}
