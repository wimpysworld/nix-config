#!/usr/bin/env bash

set -o nounset

app_name="fuzzel-capture"
recording_state_file="${XDG_RUNTIME_DIR:?}/$app_name-recording.state"
recording_lock_file="${XDG_RUNTIME_DIR:?}/$app_name-recording.lock"
recording_log_file="${XDG_RUNTIME_DIR:?}/$app_name.log"
countdown_state_file="${XDG_RUNTIME_DIR:?}/$app_name-countdown.state"
audio_choice_file="${XDG_STATE_HOME:-${HOME:?}/.local/state}/$app_name/audio"
wl_screenrec="$(readlink -f "@wlScreenrec@")"
notify=(fyi "--app-name=$app_name")
# The Waybar custom/recording module refreshes on SIGRTMIN+9.
waybar_signal=9

epoch_ms() {
  local now="${EPOCHREALTIME//[!0-9]/}"

  printf '%s\n' "$((10#$now / 1000))"
}

sleep_until_ms() {
  local remaining

  remaining=$(($1 - $(epoch_ms)))
  if ((remaining > 0)); then
    sleep "$((remaining / 1000)).$(printf '%03d' "$((remaining % 1000))")"
  fi
}

# Show a three second countdown in the SwayOSD on the target output: "3",
# "2" and "1" for 1.25 s each, with a bar that drains from full to empty.
# Each update replaces the OSD and restarts its 400 ms timeout, so the OSD
# hides itself if this script stops. A cancellable countdown ends early
# with status 1 when "stop" removes the countdown state file.
countdown() {
  local cancellable="${2:-}"
  local deadline
  local output="$1"
  local progress
  local start
  local tick=0
  local tick_ms=250
  local ticks=15
  local osd_ms=400
  local gap_ms=300

  start="$(epoch_ms)"
  while ((tick < ticks)); do
    if [[ -n "$cancellable" && ! -f "$countdown_state_file" ]]; then
      return 1
    fi
    progress=$(((ticks - 1 - tick) * 1000 / (ticks - 1)))
    swayosd-client \
      --monitor "$output" \
      --duration "$osd_ms" \
      --custom-icon media-record-symbolic \
      --custom-progress "$((progress / 1000)).$(printf '%03d' "$((progress % 1000))")" \
      --custom-progress-text "$((3 - tick * 3 / ticks))" >/dev/null 2>&1 || true
    ((tick += 1))
    sleep_until_ms "$((start + tick * tick_ms))"
  done

  # Wait until the OSD has hidden itself, plus a short gap, so that the
  # capture does not include it.
  deadline=$((start + (ticks - 1) * tick_ms + osd_ms + gap_ms))
  sleep_until_ms "$deadline"
  [[ -z "$cancellable" || -f "$countdown_state_file" ]]
}

refresh_waybar() {
  systemctl --user kill --kill-whom=main --signal="RTMIN+$waybar_signal" waybar.service \
    >/dev/null 2>&1 || true
}

escape_markup() {
  local text="$1"

  text="${text//&/\&amp;}"
  text="${text//</\&lt;}"
  printf '%s\n' "${text//>/\&gt;}"
}

get_process_start_time() {
  local fields
  local stat_line

  [[ "$1" =~ ^[0-9]+$ ]] || return 1
  stat_line="$(< "/proc/$1/stat")" || return 1
  read -r -a fields <<< "${stat_line##*) }"
  [[ "${fields[19]:-}" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "${fields[19]}"
}

is_expected_recorder() {
  local actual_start_time
  local executable
  local pid="$1"
  local stored_start_time="$2"

  [[ "$pid" =~ ^[0-9]+$ && "$stored_start_time" =~ ^[0-9]+$ ]] || return 1
  executable="$(readlink -f "/proc/$pid/exe" 2>/dev/null)" || return 1
  [[ "$executable" == "$wl_screenrec" ]] || return 1
  actual_start_time="$(get_process_start_time "$pid")" || return 1
  [[ "$actual_start_time" == "$stored_start_time" ]]
}

is_same_process_running() {
  local fields
  local pid="$1"
  local start_time="$2"
  local stat_line

  [[ "$pid" =~ ^[0-9]+$ && "$start_time" =~ ^[0-9]+$ ]] || return 1
  stat_line="$(< "/proc/$pid/stat")" || return 1
  read -r -a fields <<< "${stat_line##*) }"
  [[ "${fields[19]:-}" == "$start_time" ]] || return 1
  [[ "${fields[0]:-}" != "Z" && "${fields[0]:-}" != "X" && "${fields[0]:-}" != "x" ]]
}

reap_recording_child() {
  local checks=10
  local pid="$1"
  local start_time="$2"

  if is_same_process_running "$pid" "$start_time"; then
    kill -TERM "$pid" 2>/dev/null || true
  fi
  while ((checks > 0)) && is_same_process_running "$pid" "$start_time"; do
    sleep 0.1
    ((checks -= 1)) || true
  done
  if is_same_process_running "$pid" "$start_time"; then
    kill -KILL "$pid" 2>/dev/null || true
  fi
  checks=10
  while ((checks > 0)) && is_same_process_running "$pid" "$start_time"; do
    sleep 0.1
    ((checks -= 1)) || true
  done
  if ! is_same_process_running "$pid" "$start_time"; then
    wait "$pid" 2>/dev/null || true
  fi
}

# The state file has two lines: the recorder PID, its process start time and
# the start epoch in seconds, then the video file path.
read_recording_state() {
  [[ -f "$recording_state_file" ]] || return 1
  {
    read -r recording_pid recording_start_time recording_epoch extra &&
      IFS= read -r recording_file &&
      ! read -r _
  } < "$recording_state_file" || return 1
  [[ -n "${recording_pid:-}" && -n "${recording_start_time:-}" &&
    "${recording_epoch:-}" =~ ^[0-9]+$ && -z "${extra:-}" && -n "${recording_file:-}" ]]
}

is_recording_active() {
  local extra=""
  local recording_epoch=""
  local recording_file=""
  local recording_pid=""
  local recording_start_time=""

  if read_recording_state && is_expected_recorder "$recording_pid" "$recording_start_time"; then
    return 0
  fi
  rm -f "$recording_state_file"
  return 1
}

# Print the elapsed recording time as mm:ss for the Waybar indicator, or
# nothing when no recording is active, which hides the module.
print_recording_status() {
  local elapsed
  local extra=""
  local recording_epoch=""
  local recording_file=""
  local recording_pid=""
  local recording_start_time=""

  if ! read_recording_state || ! is_expected_recorder "$recording_pid" "$recording_start_time"; then
    rm -f "$recording_state_file"
    return 0
  fi
  elapsed=$(($(date +%s) - recording_epoch))
  ((elapsed >= 0)) || elapsed=0
  printf '%02d:%02d\n' "$((elapsed / 60))" "$((elapsed % 60))"
}

# The countdown state file holds the PID and process start time of the
# script that runs a cancellable countdown. "stop" removes it to cancel.
is_countdown_active() {
  local extra=""
  local pid=""
  local start_time=""

  [[ -f "$countdown_state_file" ]] || return 1
  read -r pid start_time extra < "$countdown_state_file" || true
  if [[ -z "$extra" ]] && is_same_process_running "$pid" "$start_time"; then
    return 0
  fi
  rm -f "$countdown_state_file"
  return 1
}

get_video_dir() {
  local video_dir="${XDG_VIDEOS_DIR:-${HOME:?}/Videos}"

  mkdir -p "$video_dir"
  printf '%s\n' "$video_dir"
}

generate_video_filename() {
  printf '%s/recording_%s.mp4\n' "$(get_video_dir)" "$(date +%Y-%m-%d_%H-%M-%S_%N)"
}

find_desktop_audio_source() {
  local default_sink
  local fallback=""
  local source_name

  default_sink="$(pactl get-default-sink)"
  while IFS=$'\t' read -r _ source_name _; do
    if [[ "$source_name" == "$default_sink.monitor" ]]; then
      printf '%s\n' "$source_name"
      return
    fi
    if [[ -z "$fallback" && "$source_name" == *monitor* ]]; then
      fallback="$source_name"
    fi
  done < <(pactl list short sources)

  printf '%s\n' "${fallback:-default}"
}

find_microphone_source() {
  local default_source
  local sources

  sources="$(pactl --format=json list sources)" || return 1
  default_source="$(pactl get-default-source)" || return 1
  [[ -n "$default_source" ]] || return 1

  # pactl 17 serialises monitor_of_sink_name as monitor_source. A null
  # pointer becomes an empty string, not JSON null or PA_INVALID_INDEX.
  jq --slurp --raw-output --exit-status --arg default "$default_source" '
    select(length == 1) | .[0]
    | select(type == "array")
    | select(all(.[];
        type == "object"
        and (.name | type == "string")
        and (.name | length > 0)
        and (.name | test("[\u0000-\u001f\u007f]") | not)
        and (.monitor_source | type == "string")
      ))
    | map(select(.monitor_source == "" and .name == $default))
    | select(length == 1)
    | .[0].name
  ' <<< "$sources"
}

get_audio_choice() {
  local choice=""

  [[ -f "$audio_choice_file" ]] && choice="$(< "$audio_choice_file")"
  case "$choice" in
    microphone | none) printf '%s\n' "$choice" ;;
    *) printf 'desktop\n' ;;
  esac
}

set_audio_choice() {
  mkdir -p "${audio_choice_file%/*}"
  printf '%s\n' "$1" > "$audio_choice_file"
}

find_audio_source() {
  case "$(get_audio_choice)" in
    microphone) find_microphone_source ;;
    *) find_desktop_audio_source ;;
  esac
}

select_audio_choice() {
  local selection

  selection="$(
    printf '󰕾 Desktop\n󰍬 Microphone\n󰖁 None\n' |
      fuzzel --dmenu --prompt="󰕾 " --lines=3 --width=24
  )" || return 0
  case "$selection" in
    "󰕾 Desktop") set_audio_choice desktop ;;
    "󰍬 Microphone") set_audio_choice microphone ;;
    "󰖁 None") set_audio_choice none ;;
  esac
}

# Show the finished recording with actions. The notification waits for an
# action, so it runs in the background and "stop" returns at once.
notify_recording_saved() {
  local video_file="$1"

  # fyi prints the chosen action as "action=NAME", so strip the prefix.
  # Errors go to the recording log, so a failed action leaves a trace.
  (
    output="$(
      "${notify[@]}" --icon="media-record" \
        --action="open:Open" \
        --action="folder:Show folder" \
        --action="copy:Copy path" \
        "Screen Recording Saved" "$(escape_markup "$video_file")"
    )" || exit 0
    action=""
    while IFS= read -r line; do
      case "$line" in
        action=*) action="${line#action=}" ;;
      esac
    done <<< "$output"
    case "$action" in
      open) xdg-open "$video_file" ;;
      folder) xdg-open "${video_file%/*}" ;;
      copy) wl-copy -- "$video_file" ;;
    esac
  ) </dev/null >/dev/null 2>> "$recording_log_file" &
  disown || true
}

stop_recording() {
  local checks=50
  local extra=""
  local recording_epoch=""
  local recording_file=""
  local recording_pid=""
  local recording_start_time=""

  if is_countdown_active; then
    rm -f "$countdown_state_file"
    return
  fi

  if ! read_recording_state; then
    rm -f "$recording_state_file"
    "${notify[@]}" --icon="replay-record-error" "Screen Recording" "No active recording found"
    return
  fi

  if ! is_expected_recorder "$recording_pid" "$recording_start_time"; then
    rm -f "$recording_state_file"
    "${notify[@]}" --icon="replay-record-error" "Screen Recording" "No active recording found"
    return
  fi

  if ! kill -INT "$recording_pid" 2>/dev/null &&
    is_same_process_running "$recording_pid" "$recording_start_time"; then
    "${notify[@]}" --icon="replay-record-error" "Screen Recording" "Screen recording could not be stopped."
    return 1
  fi
  while ((checks > 0)) && is_same_process_running "$recording_pid" "$recording_start_time"; do
    sleep 0.1
    ((checks -= 1)) || true
  done
  if is_same_process_running "$recording_pid" "$recording_start_time"; then
    "${notify[@]}" --icon="media-record" "Screen Recording" \
      "Screen recording is still stopping. Try again."
    return 1
  fi

  rm -f "$recording_state_file"
  refresh_waybar
  notify_recording_saved "$recording_file"
}

select_geometry() {
  slurp -d
}

select_output() {
  local lines
  local output_list
  local selection

  output_list="$(
    wlr-randr --json |
      jq --raw-output '
        sort_by(.name)[]
        | select(.enabled == true)
        | "\(.name) (\(.description // "Unknown output"))"
      '
  )"
  [[ -n "$output_list" ]] || return 1

  lines="$(printf '%s\n' "$output_list" | wc -l)"
  selection="$(
    printf '%s\n' "$output_list" |
      fuzzel --dmenu --prompt="󰹑 " --lines="$lines"
  )" || return 1
  [[ -n "$selection" ]] || return 1

  printf '%s\n' "${selection%% *}"
}

# Print the outputs as compact JSON lines with name, x, y, width and height
# in logical layout coordinates. The compositor reports the layout box,
# which already accounts for the scale and the transform.
list_output_boxes() {
  compositor-query monitors | jq --compact-output '.[]'
}

# Print the enabled outputs that a slurp region ("x,y wxh" in logical layout
# coordinates) overlaps by at least one logical pixel, one name per line.
find_region_outputs() {
  [[ "$1" =~ ^(-?[0-9]+),(-?[0-9]+)\ ([0-9]+)x([0-9]+)$ ]] || return 1
  list_output_boxes |
    jq --raw-output \
      --argjson x "${BASH_REMATCH[1]}" \
      --argjson y "${BASH_REMATCH[2]}" \
      --argjson w "${BASH_REMATCH[3]}" \
      --argjson h "${BASH_REMATCH[4]}" '
      def overlap(a; al; b; bl): ([a + al, b + bl] | min) - ([a, b] | max);
      select(overlap($x; $w; .x; .width) >= 1 and overlap($y; $h; .y; .height) >= 1)
      | .name
    '
}

# Print a region clipped to the box of the named output, in the slurp
# format "x,y wxh". The clipped region stays inside the output.
clamp_region_to_output() {
  [[ "$1" =~ ^(-?[0-9]+),(-?[0-9]+)\ ([0-9]+)x([0-9]+)$ ]] || return 1
  list_output_boxes |
    jq --raw-output --exit-status \
      --arg name "$2" \
      --argjson x "${BASH_REMATCH[1]}" \
      --argjson y "${BASH_REMATCH[2]}" \
      --argjson w "${BASH_REMATCH[3]}" \
      --argjson h "${BASH_REMATCH[4]}" '
      select(.name == $name)
      | ([$x, .x] | max | ceil) as $left
      | ([$y, .y] | max | ceil) as $top
      | ([$x + $w, .x + .width] | min | floor) as $right
      | ([$y + $h, .y + .height] | min | floor) as $bottom
      | select($right > $left and $bottom > $top)
      | "\($left),\($top) \($right - $left)x\($bottom - $top)"
    '
}

get_output_transform() {
  wlr-randr --json |
    jq --raw-output --arg name "$1" '
      first(.[] | select(.name == $name) | .transform // "normal") // "normal"
    '
}

capture_region() {
  local geometry

  geometry="$(select_geometry)" || return
  [[ -n "$geometry" ]] || return
  grim -g "$geometry" - | satty --filename -
}

# Show a Fuzzel list of windows and print the selected window as JSON.
# The argument is a JSON array of objects with title and app-id. Entries
# read "N  title - app-id", sorted by title and then app-id. "Screenshot a
# Window" and "Record a Window" share this list.
select_window() {
  local lines
  local selection
  local window_list
  local windows

  windows="$(jq --compact-output 'sort_by(.title // "", .["app-id"] // "")' <<< "$1")" || return 1
  window_list="$(
    jq --raw-output '
      to_entries[]
      | "\(.key + 1)  \(
          (.value.title // "(untitled)")
          | gsub("[\\t\\r\\n]"; " ")
        ) - \(
          (.value["app-id"] // "unknown")
          | gsub("[\\t\\r\\n]"; " ")
        )"
    ' <<< "$windows"
  )"
  [[ -n "$window_list" ]] || return 1

  lines="$(printf '%s\n' "$window_list" | wc -l)"
  ((lines > 16)) && lines=16
  selection="$(
    printf '%s\n' "$window_list" |
      fuzzel --dmenu --prompt="󰖯 " --lines="$lines"
  )" || return 1
  [[ "${selection%% *}" =~ ^[0-9]+$ ]] || return 1

  jq --compact-output --exit-status --argjson index "$((${selection%% *} - 1))" \
    '.[$index] // empty' <<< "$windows"
}

capture_window() {
  local identifier
  local selection
  local toplevel_json
  local windows

  toplevel_json="$(lswt --json 2>/dev/null || true)"
  if ! jq --exit-status '
    .["supported-data"].identifier == true
    and any(.toplevels[]; .identifier != null)
  ' >/dev/null 2>&1 <<< "$toplevel_json"; then
    capture_region
    return
  fi

  windows="$(jq --compact-output '.toplevels | map(select(.identifier != null))' <<< "$toplevel_json")"
  selection="$(select_window "$windows")" || return
  identifier="$(jq --raw-output '.identifier' <<< "$selection")"
  [[ -n "$identifier" && "$identifier" != "null" ]] || {
    capture_region
    return
  }

  grim -T "$identifier" - | satty --filename -
}

capture_output() {
  local output="${1:-}"

  if [[ -z "$output" ]]; then
    output="$(select_output)" || return
  fi
  countdown "$output"
  grim -o "$output" - | satty --filename -
}

acquire_recording_lock() {
  exec {recording_lock_fd}> "$recording_lock_file"
  flock --nonblock "$recording_lock_fd"
}

start_recording() {
  local audio_source
  local checks=20
  local log_tail
  local mode="$1"
  local output="$3"
  local pid
  local recorder_args
  local start_time
  local state_file
  local target="$2"
  local transform
  local video_file

  if ! acquire_recording_lock; then
    "${notify[@]}" --icon="media-record" "Screen Recording" "Another recording start is in progress."
    return
  fi
  if is_recording_active; then
    "${notify[@]}" --icon="media-record" "Screen Recording" "A screen recording is already active."
    return
  fi

  video_file="$(generate_video_filename)"
  transform="$(get_output_transform "$output")" || transform="normal"
  recorder_args=(
    "--$mode" "$target"
    --filename "$video_file"
    --low-power=off
    --max-fps 60
  )
  : > "$recording_log_file"
  # Mesa VAAPI does not support output transforms, so a rotated output
  # needs the software encoder.
  if [[ "$transform" != "normal" ]]; then
    recorder_args+=(--no-hw)
    printf '%s: %s uses transform %s, so the recording uses the software encoder (--no-hw).\n' \
      "$app_name" "$output" "$transform" >> "$recording_log_file"
  fi

  printf '%s %s\n' "$$" "$(get_process_start_time "$$")" > "$countdown_state_file"
  if ! countdown "$output" cancellable; then
    rm -f "$countdown_state_file"
    return
  fi
  # Resolve audio after the countdown, when the available inputs can differ.
  # The "none" audio choice records video only.
  if [[ "$(get_audio_choice)" != "none" ]]; then
    if ! audio_source="$(find_audio_source 2>> "$recording_log_file")"; then
      rm -f "$countdown_state_file"
      "${notify[@]}" --icon="replay-record-error" "Screen Recording Failed" \
        "No valid default microphone is available. Check the audio input and try again."
      return 1
    fi
    recorder_args+=(--audio --audio-device "$audio_source")
  fi
  (
    exec {recording_lock_fd}>&-
    exec "$wl_screenrec" "${recorder_args[@]}" 2>> "$recording_log_file"
  ) &
  pid="$!"

  start_time="$(get_process_start_time "$pid")" || true
  while [[ -n "$start_time" ]] && ((checks > 0)) &&
    ! is_expected_recorder "$pid" "$start_time" &&
    is_same_process_running "$pid" "$start_time"; do
    sleep 0.1
    ((checks -= 1)) || true
  done
  if [[ -n "$start_time" ]] && is_expected_recorder "$pid" "$start_time"; then
    # A recorder that cannot capture or encode exits soon after it starts.
    sleep 0.5
  fi
  if [[ -z "$start_time" ]] || ! is_expected_recorder "$pid" "$start_time"; then
    rm -f "$countdown_state_file"
    if [[ -n "$start_time" ]]; then
      reap_recording_child "$pid" "$start_time"
    elif [[ ! -e "/proc/$pid/stat" ]]; then
      wait "$pid" 2>/dev/null || true
    fi
    log_tail="$(tail -n 3 "$recording_log_file" 2>/dev/null)" || log_tail=""
    "${notify[@]}" --icon="replay-record-error" "Screen Recording Failed" \
      "$(escape_markup "${log_tail:-Screen recording failed to start.}")"
    return 1
  fi

  state_file="$(mktemp "$recording_state_file.XXXXXX")"
  printf '%s %s %s\n%s\n' "$pid" "$start_time" "$(date +%s)" "$video_file" > "$state_file"
  mv -f "$state_file" "$recording_state_file"
  refresh_waybar
  # "stop" removes the countdown state file when it runs before the
  # recording state exists, so stop the recording now.
  if [[ -f "$countdown_state_file" ]]; then
    rm -f "$countdown_state_file"
  else
    stop_recording
  fi
}

record_region() {
  local geometry
  local outputs

  geometry="$(select_geometry)" || return
  [[ -n "$geometry" ]] || return
  outputs="$(find_region_outputs "$geometry")" || outputs=""
  if [[ -z "$outputs" ]]; then
    "${notify[@]}" --icon="replay-record-error" "Screen Recording" \
      "The selected region is not on a display."
    return 1
  fi
  if [[ "$outputs" == *$'\n'* ]]; then
    "${notify[@]}" --icon="replay-record-error" "Screen Recording" \
      "The selected region spans more than one display. Select a region on one display."
    return 1
  fi
  start_recording geometry "$geometry" "$outputs"
}

# Record the screen area of a window. wl-screenrec cannot follow a window,
# so the recording keeps the area that the window covers when it starts.
record_window() {
  local checks=10
  local geometry
  local id
  local outputs
  local selection
  local window
  local windows

  windows="$(compositor-query windows 2>/dev/null)" || windows=""
  if ! jq --exit-status 'length > 0' >/dev/null 2>&1 <<< "$windows"; then
    record_region
    return
  fi

  selection="$(select_window "$windows")" || return
  id="$(jq --raw-output '.id' <<< "$selection")"
  if ! compositor-query focus-window "$id" >/dev/null 2>&1; then
    "${notify[@]}" --icon="replay-record-error" "Screen Recording" \
      "The selected window could not be focused."
    return 1
  fi

  # The tag or workspace switch can finish after focus-window returns, so
  # wait for the window to show before reading its geometry.
  while :; do
    window="$(
      compositor-query windows 2>/dev/null |
        jq --compact-output --exit-status --argjson id "$id" 'first(.[] | select(.id == $id))'
    )" || window=""
    if [[ -n "$window" ]] && jq --exit-status '.visible' >/dev/null <<< "$window"; then
      break
    fi
    if ((checks == 0)); then
      "${notify[@]}" --icon="replay-record-error" "Screen Recording" \
        "The selected window is not visible."
      return 1
    fi
    sleep 0.1
    ((checks -= 1)) || true
  done

  geometry="$(
    jq --raw-output '"\(.x | floor),\(.y | floor) \(.width | floor)x\(.height | floor)"' <<< "$window"
  )"
  outputs="$(find_region_outputs "$geometry")" || outputs=""
  if [[ -z "$outputs" ]]; then
    "${notify[@]}" --icon="replay-record-error" "Screen Recording" \
      "The selected window is not on a display."
    return 1
  fi
  if [[ "$outputs" == *$'\n'* ]]; then
    "${notify[@]}" --icon="replay-record-error" "Screen Recording" \
      "The selected window spans more than one display. Move the window to one display."
    return 1
  fi
  geometry="$(clamp_region_to_output "$geometry" "$outputs")" || return 1
  start_recording geometry "$geometry" "$outputs"
}

record_output() {
  local output="${1:-}"

  if [[ -z "$output" ]]; then
    output="$(select_output)" || return
  fi
  start_recording output "$output" "$output"
}

show_menu() {
  local lines
  local menu
  local selection

  menu="󰩭 Screenshot a Region\n󰖯 Screenshot a Window\n󰹑 Screenshot a Monitor"
  if is_recording_active || is_countdown_active; then
    menu+="\n󰾊 Stop Recording"
  else
    menu+="\n󰩭 Record a Region\n󰖯 Record a Window\n󰹑 Record a Monitor"
    case "$(get_audio_choice)" in
      microphone) menu+="\n󰍬 Audio: Microphone" ;;
      none) menu+="\n󰖁 Audio: None" ;;
      *) menu+="\n󰕾 Audio: Desktop" ;;
    esac
  fi

  lines="$(printf '%b\n' "$menu" | wc -l)"
  selection="$(
    printf '%b\n' "$menu" |
      fuzzel --dmenu --prompt="󱎴 " --lines="$lines" --width=24
  )" || return

  case "$selection" in
    "󰩭 Screenshot a Region") capture_region ;;
    "󰖯 Screenshot a Window") capture_window ;;
    "󰹑 Screenshot a Monitor") capture_output ;;
    "󰾊 Stop Recording") stop_recording ;;
    "󰩭 Record a Region") record_region ;;
    "󰖯 Record a Window") record_window ;;
    "󰹑 Record a Monitor") record_output ;;
    "󰕾 Audio: Desktop" | "󰍬 Audio: Microphone" | "󰖁 Audio: None")
      select_audio_choice
      show_menu
      ;;
  esac
}

case "${1:-menu}" in
  menu) show_menu ;;
  region) capture_region ;;
  window) capture_window ;;
  output) capture_output "${2:-}" ;;
  record-region) record_region ;;
  record-window) record_window ;;
  record-output) record_output "${2:-}" ;;
  stop) stop_recording ;;
  status) print_recording_status ;;
  *)
    printf 'Usage: %s [menu|region|window|output [name]|record-region|record-window|record-output [name]|stop|status]\n' "$app_name" >&2
    exit 2
    ;;
esac
