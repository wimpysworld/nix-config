#!/usr/bin/env bash

set +e          # Disable errexit
set +u          # Disable nounset
set +o pipefail # Disable pipefail

if [ -x "$HOME/.nix-profile/bin/hyprctl" ]; then
	HYPRCTL="$HOME/.nix-profile/bin/hyprctl"
elif [ -x /run/current-system/sw/bin/hyprctl ]; then
	HYPRCTL="/run/current-system/sw/bin/hyprctl"
else
	HYPRCTL="hyprctl"
fi

# Single session, fixed filename. Internal functions accept a name parameter
# for future extensibility, but the CLI always passes this constant.
SESSION_NAME="session"

SESSION_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/hypr-sessions"
STATE_DIR="$SESSION_DIR"
DYNAMIC_MAP_FILE="$STATE_DIR/dynamic-classmap.json"
OVERRIDE_MAP_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/hypr-sessions/overrides.json"
CACHE_FINGERPRINT_FILE="$STATE_DIR/classmap-fingerprint"
DAEMON_PID_FILE="$STATE_DIR/daemon.pid"

mkdir -p "$SESSION_DIR"

# -- Dynamic classmap --

function build_dynamic_classmap() {
	# Build a JSON lookup table from installed .desktop files, mapping window class
	# names to launch commands. The result is cached and only rebuilt when Nix profiles
	# change (symlink target changes on rebuild) or when the user's local applications
	# directory is modified.
	local fingerprint
	fingerprint="$(readlink -f ~/.nix-profile 2>/dev/null)$(readlink -f /run/current-system 2>/dev/null)$(stat -c '%Y' ~/.local/share/applications/ 2>/dev/null)"

	if [ -f "$CACHE_FINGERPRINT_FILE" ] && [ -f "$DYNAMIC_MAP_FILE" ]; then
		local cached
		cached="$(cat "$CACHE_FINGERPRINT_FILE")"
		if [ "$fingerprint" = "$cached" ]; then
			return 0
		fi
	fi

	# Scan desktop files from all standard directories, in priority order.
	# First match wins: user profile takes precedence over system, system over local.
	local tsv_file
	tsv_file="$(mktemp)"

	local -A seen
	for dir in "$HOME/.nix-profile/share/applications" \
		"/run/current-system/sw/share/applications" \
		"$HOME/.local/share/applications"; do
		[ -d "$dir" ] || continue
		for f in "$dir"/*.desktop; do
			[ -f "$f" ] || continue

			local basename_noext exec_line wmclass
			basename_noext=$(basename "$f" .desktop)
			exec_line=$(grep -m1 '^Exec=' "$f" 2>/dev/null |
				sed 's/^Exec=//' |
				sed 's/ %[UuFfDdNnickvm]//g' |
				sed 's/ *$//')
			wmclass=$(grep -m1 '^StartupWMClass=' "$f" 2>/dev/null |
				cut -d= -f2-)

			[ -n "$exec_line" ] || continue

			# Normalise Nix store paths to bare binary names where possible.
			# If the binary basename is available in PATH, use the bare name
			# so the command survives Nix rebuilds.
			if [[ "$exec_line" == /nix/store/* ]]; then
				local bin_path bin_name rest
				bin_path=$(echo "$exec_line" | awk '{print $1}')
				bin_name=$(basename "$bin_path")
				if command -v "$bin_name" >/dev/null 2>&1; then
					rest=$(echo "$exec_line" | cut -d' ' -f2- -s)
					exec_line="$bin_name${rest:+ $rest}"
				fi
			fi

			# Register under both the desktop filename and the StartupWMClass.
			# Also register a lowercased version of each key for case-insensitive matching.
			for key in "$basename_noext" "$wmclass"; do
				[ -n "$key" ] || continue
				[ -z "${seen[$key]+x}" ] || continue
				seen[$key]=1
				printf '%s\t%s\n' "$key" "$exec_line" >>"$tsv_file"
				# Add a lowercased key so case-insensitive lookups work directly in jq.
				local lower_key
				lower_key="$(echo "$key" | tr '[:upper:]' '[:lower:]')"
				if [ "$lower_key" != "$key" ] && [ -z "${seen[$lower_key]+x}" ]; then
					seen[$lower_key]=1
					printf '%s\t%s\n' "$lower_key" "$exec_line" >>"$tsv_file"
				fi
			done
		done
	done

	# Convert TSV to JSON with proper escaping, then merge manual overrides on top.
	local base_map
	base_map=$(jq -Rn '[inputs | split("\t") | {(.[0]): .[1]}] | add // {}' "$tsv_file")

	if [ -f "$OVERRIDE_MAP_FILE" ]; then
		echo "$base_map" | jq --slurpfile overrides "$OVERRIDE_MAP_FILE" \
			'. * ($overrides[0] // {})' >"$DYNAMIC_MAP_FILE"
	else
		echo "$base_map" >"$DYNAMIC_MAP_FILE"
	fi

	echo "$fingerprint" >"$CACHE_FINGERPRINT_FILE"
	rm -f "$tsv_file"
}

# -- Window state management --

function save_session() {
	local name="$1"
	local output_file="$SESSION_DIR/${name}.json"

	# Capture hyprctl output once and reuse it for both the early-exit check and the
	# main jq pipeline. This avoids calling hyprctl twice and skips all further work
	# (temp file, classmap build, jq transform) when there are no windows.
	local clients_json
	clients_json="$($HYPRCTL clients -j 2>/dev/null || echo "[]")"

	local visible_count
	visible_count="$(echo "$clients_json" | jq '[.[] | select(.mapped == true and .hidden == false)] | length' 2>/dev/null || echo "0")"
	if [ "${visible_count:-0}" -eq 0 ]; then
		echo "No windows to save, skipping."
		return 0
	fi

	# Atomic write: save to a temporary file then rename, to avoid partial writes.
	local tmp_file
	tmp_file="$(mktemp -p "$SESSION_DIR")"

	# Build or refresh the dynamic classmap (cached, typically a no-op).
	build_dynamic_classmap

	# Resolve launch commands via the classmap for all mapped, visible windows.
	# The entire transformation is a single jq pipeline: read the classmap with --slurpfile,
	# filter windows, look up class in the map (trying exact match, then case-insensitive),
	# and wrap the result with a timestamp.
	echo "$clients_json" | jq --slurpfile cmap "$DYNAMIC_MAP_FILE" '
		($cmap[0] // {}) as $classmap |
		[
			.[] | select(.mapped == true and .hidden == false) |
			{
				class,
				workspace: .workspace.id,
				floating,
				monitor,
				position: .at,
				size: .size,
				command: (
					$classmap[.class] //
					$classmap[(.class | ascii_downcase)] //
					(.class | ascii_downcase)
				)
			}
		] |
		{
			timestamp: (now | todate),
			windows: .
		}
	' >"$tmp_file"

	# Belt-and-braces guard against saving an empty session. The early exit above
	# should prevent reaching here with zero windows, but check anyway to avoid
	# overwriting a good session file with an empty windows array.
	local window_count
	window_count="$(jq '.windows | length' "$tmp_file" 2>/dev/null || echo "0")"
	if [ "${window_count:-0}" -eq 0 ]; then
		rm -f "$tmp_file"
		echo "No windows to save, skipping."
		return 0
	fi

	mv "$tmp_file" "$output_file"

	echo "Session saved: $name ($window_count windows)"
}

function get_window_addresses() {
	$HYPRCTL clients -j | jq -r '.[].address' 2>/dev/null | sort
}

function wait_for_new_window() {
	# Wait for a window to appear that was not in the snapshot.
	# $1 = file containing sorted snapshot of window addresses before launch
	# $2 = (optional) expected window class; when provided, the detected window's
	#       class is verified via hyprctl and non-matching windows are skipped.
	#       This avoids mis-identifying unrelated windows (e.g. notifications) or
	#       splash screens from a different app as the target window.
	# Returns the new window address on stdout, or empty string on timeout.
	local snapshot_file="$1"
	local expected_class="${2:-}"
	local expected_lower=""
	if [ -n "$expected_class" ]; then
		expected_lower="$(echo "$expected_class" | tr '[:upper:]' '[:lower:]')"
	fi

	local new_addr=""
	for _ in {1..20}; do
		local candidates
		candidates="$(comm -13 "$snapshot_file" <(get_window_addresses))"
		for candidate in $candidates; do
			if [ -n "$expected_class" ]; then
				# Verify the window's class matches (case-insensitive).
				local actual_class
				actual_class="$($HYPRCTL clients -j | jq -r \
					--arg addr "$candidate" \
					'.[] | select(.address == $addr) | .class // ""' 2>/dev/null || true)"
				local actual_lower
				actual_lower="$(echo "$actual_class" | tr '[:upper:]' '[:lower:]')"
				if [ "$actual_lower" != "$expected_lower" ]; then
					continue
				fi
			fi
			new_addr="$candidate"
			break
		done
		if [ -n "$new_addr" ]; then
			echo "$new_addr"
			return 0
		fi
		sleep 0.25
	done
	return 1
}

function _do_swaps() {
	# Selection sort: for each rank, swap until the correct window is in place.
	# Uses namerefs to operate on the caller's arrays.
	local -n _want=$1
	local -n _have=$2
	local count=$3

	local batch=""
	for ((i = 0; i < count; i++)); do
		if [ "${_have[$i]}" != "${_want[$i]}" ]; then
			# Find where the wanted address currently sits.
			local j
			for ((j = i + 1; j < count; j++)); do
				if [ "${_have[$j]}" = "${_want[$i]}" ]; then
					break
				fi
			done

			if [ "$j" -lt "$count" ]; then
				# Swap: focus window at rank i, swap with window at rank j.
				if [ -n "$batch" ]; then batch+=" ; "; fi
				batch+="dispatch focuswindow address:${_have[$i]}"
				batch+=" ; dispatch swapwindow address:${_have[$j]}"

				# Update tracking array.
				local tmp="${_have[i]}"
				_have[i]="${_have[j]}"
				_have[j]="$tmp"
			fi
		fi
	done

	if [ -n "$batch" ]; then
		$HYPRCTL --batch "$batch" 2>/dev/null || true
		# Brief pause to let the layout settle.
		sleep 0.1
	fi
}

function arrange_tiled_windows() {
	# Rearrange tiled windows on each workspace to match their saved spatial positions.
	# Uses swap-based sorting: rank windows by (y, x) in both saved and current state,
	# then swap until each rank holds the correct window.
	local session_file="$1"
	shift
	# Remaining args: idx=addr pairs from RESTORED_ADDRS.

	# Build a JSON object mapping saved index to new address.
	local addr_json="{"
	local first=true
	for key in "$@"; do
		IFS='=' read -r idx addr <<<"$key"
		if [ "$first" = true ]; then first=false; else addr_json+=","; fi
		addr_json+="\"$idx\":\"$addr\""
	done
	addr_json+="}"

	# Record the user's current workspace so we can restore it afterwards.
	local original_ws
	original_ws="$($HYPRCTL activeworkspace -j | jq -r '.id' 2>/dev/null || echo "1")"

	# Get current live window state.
	local live_clients
	live_clients="$($HYPRCTL clients -j 2>/dev/null || echo "[]")"

	# Use jq to compute swap and resize operations per workspace.
	# Output is line-oriented: WORKSPACE, WANT, HAVE, and RESIZE directives.
	local swap_commands
	swap_commands="$(jq -r --argjson addr_map "$addr_json" --argjson live "$live_clients" '
		# Build saved tiled windows with their assigned new addresses.
		[.windows | to_entries[] |
			select(.value.floating == false) |
			{
				idx: (.key | tostring),
				class: .value.class,
				workspace: .value.workspace,
				saved_x: (.value.position[0] // 0),
				saved_y: (.value.position[1] // 0),
				saved_w: (.value.size[0] // 0),
				saved_h: (.value.size[1] // 0),
				addr: ($addr_map[.key | tostring] // null)
			} |
			select(.addr != null)
		] as $saved |

		# Build live tiled windows indexed by address.
		[$live[] | select(.floating == false and .mapped == true and .hidden == false) |
			{
				addr: .address,
				workspace: .workspace.id,
				live_x: .at[0],
				live_y: .at[1]
			}
		] as $current |

		# Group saved by workspace.
		($saved | group_by(.workspace)) as $saved_groups |

		# For each workspace group, emit swap directives.
		[
			$saved_groups[] |
			. as $ws_saved |
			(.[0].workspace) as $ws |

			# Sort saved by spatial key (y, x), with class as tiebreaker.
			($ws_saved | sort_by([.saved_y, .saved_x, .class])) as $sorted_saved |

			# Current tiled windows on this workspace, sorted by spatial key.
			([$current[] | select(.workspace == $ws)] | sort_by([.live_y, .live_x])) as $sorted_current |

			# Only proceed if counts match and there is something to arrange.
			if ($sorted_saved | length) == ($sorted_current | length) and ($sorted_saved | length) > 1 then
				"WORKSPACE \($ws) \($sorted_saved | length)",
				($sorted_saved | to_entries[] |
					"WANT \(.key) \(.value.addr)"
				),
				($sorted_current | to_entries[] |
					"HAVE \(.key) \(.value.addr)"
				),
				($sorted_saved | .[] |
					"RESIZE \(.addr) \(.saved_w) \(.saved_h)"
				)
			else
				empty
			end
		] | .[]
	' "$session_file" 2>/dev/null || true)"

	if [ -z "$swap_commands" ]; then
		return 0
	fi

	# Parse the jq output and perform swaps per workspace.
	local -a want_addrs=()
	local -a have_addrs=()
	local ws_count=0

	while IFS=' ' read -r tag arg1 arg2 _; do
		case "$tag" in
		WORKSPACE)
			# Process previous workspace if any.
			if [ "$ws_count" -gt 0 ]; then
				_do_swaps want_addrs have_addrs "$ws_count"
			fi
			ws_count="$arg2"
			want_addrs=()
			have_addrs=()
			;;
		WANT)
			# shellcheck disable=SC2034,SC2004
			want_addrs[$arg1]="$arg2"
			;;
		HAVE)
			# shellcheck disable=SC2034,SC2004
			have_addrs[$arg1]="$arg2"
			;;
		*) ;;
		esac
	done <<<"$swap_commands"

	# Process final workspace.
	if [ "$ws_count" -gt 0 ]; then
		_do_swaps want_addrs have_addrs "$ws_count"
	fi

	# Apply resize commands to fine-tune split ratios.
	local resize_batch=""
	while IFS=' ' read -r tag addr width height; do
		[ "$tag" = "RESIZE" ] || continue
		if [ -n "$resize_batch" ]; then resize_batch+=" ; "; fi
		resize_batch+="dispatch resizewindowpixel exact $width $height,address:$addr"
	done <<<"$swap_commands"

	if [ -n "$resize_batch" ]; then
		$HYPRCTL --batch "$resize_batch" 2>/dev/null || true
	fi

	# Restore the user's original workspace.
	$HYPRCTL dispatch workspace "$original_ws" 2>/dev/null || true
}

function reconcile_windows() {
	# Post-launch reconciliation pass: catch late-appearing windows that were not
	# placed during the initial launch loop. This addresses apps like Discord and
	# other Electron apps that show a splash screen first, then destroy it and
	# create a new main window several seconds later. Without this pass, the main
	# window ends up on the active workspace instead of its saved workspace.
	#
	# Windows that were already detected and moved during the launch loop are
	# excluded via an address exclusion set. This prevents the class -> workspace
	# map (which uses last-wins for duplicate classes) from dragging correctly
	# placed windows to the wrong workspace (e.g. multiple kitty windows on
	# different workspaces all being moved to the last-seen workspace).
	#
	# $1 = session file path
	# $2.. = addresses to exclude (already placed by the launch loop)
	local session_file="$1"
	shift
	local -a exclude_addrs=("$@")

	# Build a JSON array of addresses to skip during reconciliation.
	local exclude_json="[]"
	if [ ${#exclude_addrs[@]} -gt 0 ]; then
		exclude_json="$(printf '%s\n' "${exclude_addrs[@]}" | jq -R . | jq -s .)"
	fi

	# Build a JSON lookup of class (lowercased) -> expected workspace from the session file.
	local class_ws_map
	class_ws_map="$(jq -r '
		[.windows[] | {key: (.class | ascii_downcase), value: .workspace}] |
		from_entries
	' "$session_file" 2>/dev/null || true)"

	if [ -z "$class_ws_map" ] || [ "$class_ws_map" = "null" ]; then
		return 0
	fi

	for _ in {1..15}; do
		sleep 2

		# Get live window state and compute which windows need moving.
		# The jq pipeline outputs one "MOVE address workspace" line per misplaced window.
		# Windows in the exclusion set are skipped; they were already correctly placed
		# during the launch loop and should not be disturbed.
		local move_commands
		move_commands="$($HYPRCTL clients -j 2>/dev/null | jq -r \
			--argjson expected "$class_ws_map" \
			--argjson exclude "$exclude_json" '
			[.[] |
				select(.mapped == true and .hidden == false) |
				select(.address | IN($exclude[]) | not) |
				(.class | ascii_downcase) as $lc |
				select($expected[$lc] != null) |
				select(.workspace.id != $expected[$lc]) |
				"MOVE \(.address) \($expected[$lc])"
			] | .[]
		' 2>/dev/null || true)"

		if [ -z "$move_commands" ]; then
			# All windows are on their expected workspaces.
			return 0
		fi

		# Move each misplaced window to its saved workspace.
		while IFS=' ' read -r _ addr ws; do
			$HYPRCTL dispatch movetoworkspacesilent "$ws,address:$addr" 2>/dev/null || true
		done <<<"$move_commands"
	done
}

function load_session() {
	local name="$1"
	local session_file="$SESSION_DIR/${name}.json"

	# Exit cleanly if no saved state exists (first activation of a session).
	if [ ! -f "$session_file" ]; then
		return 0
	fi

	# Emit one tab-separated line per window so bash can iterate without calling jq N times.
	# Fields: command, workspace, floating, pos_x, pos_y, size_w, size_h, class
	local window_data
	window_data="$(jq -r '
		.windows[] |
		[
			.command,
			.workspace,
			(if .floating then "true" else "false" end),
			(.position[0] // 0),
			(.position[1] // 0),
			(.size[0] // 0),
			(.size[1] // 0),
			.class
		] | @tsv
	' "$session_file" 2>/dev/null || true)"

	if [ -z "$window_data" ]; then
		return 0
	fi

	# Launch each window, then move it to the correct workspace.
	# We cannot rely on hyprctl exec rules (e.g. [workspace N silent]) because
	# single-instance apps may delegate window creation to an existing process.
	# Hyprland tracks the PID of the spawned process for rule matching, so the
	# new window (owned by the old PID) silently ignores the rules.
	# Instead: snapshot addresses, launch, detect the new window, then move it.
	local snapshot_file
	snapshot_file="$(mktemp)"
	trap 'rm -f "$snapshot_file"' RETURN

	# Track restored window addresses: saved_index -> new_address.
	declare -A RESTORED_ADDRS
	local idx=0

	# shellcheck disable=SC2034
	while IFS=$'\t' read -r command workspace floating pos_x pos_y size_w size_h class; do
		get_window_addresses >"$snapshot_file"

		$HYPRCTL dispatch exec "$command" 2>/dev/null || true

		local new_addr=""
		new_addr="$(wait_for_new_window "$snapshot_file" "$class")" || true

		if [ -n "$new_addr" ]; then
			RESTORED_ADDRS[$idx]="$new_addr"
			$HYPRCTL dispatch movetoworkspacesilent "$workspace,address:$new_addr" 2>/dev/null || true

			if [ "$floating" = "true" ]; then
				$HYPRCTL dispatch setfloating "address:$new_addr" 2>/dev/null || true
				$HYPRCTL dispatch movewindowpixel "exact $pos_x $pos_y,address:$new_addr" 2>/dev/null || true
				$HYPRCTL dispatch resizewindowpixel "exact $size_w $size_h,address:$new_addr" 2>/dev/null || true
			fi
		fi

		idx=$((idx + 1))
		sleep 0.5
	done <<<"$window_data"

	# Post-load: arrange tiled windows to match saved positions.
	local addr_args=()
	for key in "${!RESTORED_ADDRS[@]}"; do
		addr_args+=("$key=${RESTORED_ADDRS[$key]}")
	done

	if [ ${#addr_args[@]} -gt 0 ]; then
		# Brief pause for all windows to settle into their tiled positions.
		sleep 1
		arrange_tiled_windows "$session_file" "${addr_args[@]}"
	fi

	# Reconcile any windows that appeared late (e.g. Electron apps replacing their
	# splash screen with a main window after the initial launch loop finished).
	# Pass the addresses of windows already placed by the launch loop so
	# reconciliation skips them (avoids class-map last-wins collapsing
	# multiple same-class windows onto one workspace).
	local placed_addrs=()
	for key in "${!RESTORED_ADDRS[@]}"; do
		placed_addrs+=("${RESTORED_ADDRS[$key]}")
	done

	reconcile_windows "$session_file" "${placed_addrs[@]}"

	echo "Session loaded: $name"
}

function clear_windows() {
	# Optional first argument: a window address to exclude from closing.
	local skip_addr="${1:-}"

	# Switch to Workspace 1 so the user ends on a clean desktop with no open apps.
	$HYPRCTL dispatch workspace 1 2>/dev/null || true

	# Stop daemon first to prevent it saving an empty/partial state.
	stop_daemon

	# Close all Hyprland windows gracefully, then force-kill any survivors.
	# If a skip address is provided, exclude it from both the graceful close
	# and the force-kill fallback.
	local addresses
	if [ -n "$skip_addr" ]; then
		addresses="$($HYPRCTL clients -j | jq -r --arg skip "$skip_addr" \
			'[.[].address] | map(select(. != $skip)) | .[]' 2>/dev/null || true)"
	else
		addresses="$($HYPRCTL clients -j | jq -r '.[].address' 2>/dev/null || true)"
	fi

	for addr in $addresses; do
		$HYPRCTL dispatch closewindow "address:$addr" 2>/dev/null || true
	done

	# Poll up to 10 times (0.5s each = 5 second timeout) waiting for windows to close.
	# When skipping a window, expect exactly one remaining (the skipped window).
	local remaining expected
	expected=0
	if [ -n "$skip_addr" ]; then
		expected=1
	fi
	for _ in {1..10}; do
		remaining="$($HYPRCTL clients -j | jq 'length' 2>/dev/null || echo "0")"
		if [ "${remaining:-0}" -le "$expected" ]; then
			return 0
		fi
		sleep 0.5
	done

	# Force-kill any windows that survived the graceful close, respecting the exclusion.
	if [ -n "$skip_addr" ]; then
		$HYPRCTL clients -j | jq -r --arg skip "$skip_addr" \
			'.[] | select(.address != $skip) | .pid' 2>/dev/null | xargs -r kill -9 2>/dev/null || true
	else
		$HYPRCTL clients -j | jq -r '.[].pid' 2>/dev/null | xargs -r kill -9 2>/dev/null || true
	fi
}

function list_session() {
	local name="$1"
	local session_file="$SESSION_DIR/${name}.json"

	if [ ! -f "$session_file" ]; then
		echo "No saved session found."
		return 0
	fi

	# Pretty-print contents: class, workspace, floating status.
	jq -r '.windows[] | "  \(.class) → workspace \(.workspace)\(if .floating then " (floating)" else "" end)"' \
		"$session_file" 2>/dev/null || true
}

function show_session() {
	local name="$1"
	local session_file="$SESSION_DIR/${name}.json"

	if [ ! -f "$session_file" ]; then
		echo "No saved session found."
		return 0
	fi

	# Pretty-print session contents: timestamp, window count, and per-window details.
	jq -r '
		"Session: \(.timestamp)",
		"Windows: \(.windows | length)",
		"",
		(.windows[] |
			"  \(.class)"
			+ " → workspace \(.workspace)"
			+ (if .floating then " (floating)" else "" end)
			+ " [" + .command + "]"
		)
	' "$session_file" 2>/dev/null || true
}

function show_current() {
	# Show live window state from hyprctl.
	$HYPRCTL clients -j | jq -r '.[] | select(.mapped == true and .hidden == false) | "  \(.class) → workspace \(.workspace.id)\(if .floating then " (floating)" else "" end)"' 2>/dev/null || true
}

# -- Auto-save daemon management --

function start_daemon() {
	# Kill any existing daemon first (idempotent).
	stop_daemon

	(
		while true; do
			sleep 60
			save_session "$SESSION_NAME" 2>/dev/null || true
		done
	) &
	echo $! >"$DAEMON_PID_FILE"
	disown
	echo "Auto-save daemon started (PID $(cat "$DAEMON_PID_FILE"))"
}

function stop_daemon() {
	if [ -f "$DAEMON_PID_FILE" ]; then
		local pid
		pid="$(cat "$DAEMON_PID_FILE")"
		if kill -0 "$pid" 2>/dev/null; then
			kill "$pid" 2>/dev/null || true
			# Wait briefly for clean shutdown.
			for _ in {1..10}; do
				kill -0 "$pid" 2>/dev/null || break
				sleep 0.1
			done
		fi
		rm -f "$DAEMON_PID_FILE"
	fi
}

function daemon_status() {
	if [ -f "$DAEMON_PID_FILE" ]; then
		local pid
		pid="$(cat "$DAEMON_PID_FILE")"
		if kill -0 "$pid" 2>/dev/null; then
			echo "Auto-save daemon running (PID $pid)"
		else
			rm -f "$DAEMON_PID_FILE"
			echo "Auto-save daemon not running (stale PID file removed)"
		fi
	else
		echo "Auto-save daemon not running"
	fi
}

function reload_session() {
	local name="$1"

	# When running interactively in a terminal, capture its window address so
	# clear_windows can skip it (the script's process lives inside that window;
	# closing it would kill the reload mid-flight). After reload completes the
	# terminal is closed.
	# When launched non-interactively (e.g. from fuzzel or a keybind via
	# hyprctl dispatch exec), stdin is not a terminal and there is no hosting
	# window to preserve. Skip the capture so clear_windows closes everything
	# and no unrelated window is held open for the duration of the reload.
	local caller_addr=""
	if [ -t 0 ]; then
		caller_addr="$($HYPRCTL activewindow -j | jq -r '.address // empty' 2>/dev/null || true)"
	fi

	# Stop the daemon so auto-save does not capture partial state during teardown.
	stop_daemon
	# Save current state before clearing, so we have an up-to-date snapshot.
	save_session "$name"
	# Tear down all windows except the caller's terminal, then restore from the saved session.
	clear_windows "$caller_addr"
	load_session "$name"
	# Resume auto-saving.
	start_daemon

	# Close the caller's terminal now that reload is complete.
	if [ -n "$caller_addr" ]; then
		$HYPRCTL dispatch closewindow "address:$caller_addr" 2>/dev/null || true
	fi
}

# -- Main --

case "${1:-help}" in
save)
	save_session "$SESSION_NAME"
	;;
load)
	load_session "$SESSION_NAME"
	;;
clear)
	clear_windows
	;;
reload)
	reload_session "$SESSION_NAME"
	;;
show)
	show_session "$SESSION_NAME"
	;;
list)
	list_session "$SESSION_NAME"
	;;
current)
	show_current
	;;
start-daemon)
	start_daemon
	;;
stop-daemon)
	stop_daemon
	;;
status)
	daemon_status
	;;
*)
	echo "Usage: $(basename "$0") {save|load|clear|reload|show|list|current|start-daemon|stop-daemon|status}"
	exit 1
	;;
esac
