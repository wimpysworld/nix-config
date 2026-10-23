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

# Print the focused output as one line: name, logical width, logical
# height and scale.  lan-mouse does not call this, so shellcheck sees
# it as unused there.
# shellcheck disable=SC2329
function compositor_focused_output() {
	case "$COMPOSITOR" in
	mango)
		# mmsg marks the selected monitor active, and reports the
		# output layout box in logical layout coordinates.
		mmsg get all-monitors | jq -er 'first(.monitors[] | select(.active)) | "\(.name) \(.width) \(.height) \(.scale)"'
		;;
	wayfire)
		# Wayfire IPC reports no scale, so wlr-randr supplies it.
		local output scale
		output=$(lan-mouse-wayfire-ipc focused-output | jq -er '.info | select(. != null) | "\(.name) \(.geometry.width) \(.geometry.height)"') || return 1
		scale=$(compositor_output_scale "${output%% *}") || return 1
		echo "$output $scale"
		;;
	esac
}

# Print the scale of the named output.  lan-mouse does not call this,
# so shellcheck sees it as unused there.
# shellcheck disable=SC2329
function compositor_output_scale() {
	case "$COMPOSITOR" in
	mango)
		mmsg get all-monitors | jq -er --arg name "$1" 'first(.monitors[] | select(.name == $name)) | .scale'
		;;
	wayfire)
		wlr-randr --json | jq -er --arg name "$1" 'first(.[] | select(.name == $name and .enabled)) | .scale'
		;;
	esac
}
