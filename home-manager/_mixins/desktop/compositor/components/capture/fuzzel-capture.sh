#!/usr/bin/env bash

set -o nounset

app_name="fuzzel-capture"
recording_state_file="${XDG_RUNTIME_DIR:?}/$app_name-recording.state"
recording_lock_file="${XDG_RUNTIME_DIR:?}/$app_name-recording.lock"
wl_screenrec="$(readlink -f "@wlScreenrec@")"
notify=(notify-desktop "--app-name=$app_name")

countdown() {
  local seconds=5

  while ((seconds > 0)); do
    case "$seconds" in
      5) "${notify[@]}" -t 750 --icon="draw-circle" "" "<big>Five</big>" ;;
      4) "${notify[@]}" -t 750 --icon="draw-circle" "" "<big>Four</big>" ;;
      3) "${notify[@]}" -t 750 --icon="draw-circle" "" "<big>Three</big>" ;;
      2) "${notify[@]}" -t 750 --icon="draw-circle" "" "<big>Two</big>" ;;
      1) "${notify[@]}" -t 750 --icon="draw-circle" "" "<big>One</big>" ;;
    esac
    sleep 1
    ((seconds -= 1)) || true
  done
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

read_recording_state() {
  local state

  [[ -f "$recording_state_file" ]] || return 1
  state="$(< "$recording_state_file")" || return 1
  read -r recording_pid recording_start_time extra <<< "$state"
  [[ -n "${recording_pid:-}" && -n "${recording_start_time:-}" && -z "${extra:-}" ]]
}

is_recording_active() {
  local extra=""
  local recording_pid=""
  local recording_start_time=""

  if read_recording_state && is_expected_recorder "$recording_pid" "$recording_start_time"; then
    return 0
  fi
  rm -f "$recording_state_file"
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

stop_recording() {
  local checks=50
  local extra=""
  local recording_pid=""
  local recording_start_time=""

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
  "${notify[@]}" --icon="media-record" "Screen Recording Stopped" "Screen recording stopped and saved."
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

capture_region() {
  local geometry

  geometry="$(select_geometry)" || return
  [[ -n "$geometry" ]] || return
  grim -g "$geometry" - | satty --filename -
}

capture_window() {
  local identifier
  local lines
  local selection
  local selection_index
  local toplevel_json
  local window_list

  toplevel_json="$(lswt --json 2>/dev/null || true)"
  if ! jq --exit-status '
    .["supported-data"].identifier == true
    and any(.toplevels[]; .identifier != null)
  ' >/dev/null 2>&1 <<< "$toplevel_json"; then
    capture_region
    return
  fi

  window_list="$(
    jq --raw-output '
      .toplevels
      | to_entries
      | map(select(.value.identifier != null))
      | sort_by(.value.title // "", .value["app-id"] // "")
      | to_entries[]
      | "\(.key + 1)  \(
          (.value.value.title // "(untitled)")
          | gsub("[\\t\\r\\n]"; " ")
        ) - \(
          (.value.value["app-id"] // "unknown")
          | gsub("[\\t\\r\\n]"; " ")
        )"
    ' <<< "$toplevel_json"
  )"
  [[ -n "$window_list" ]] || {
    capture_region
    return
  }

  lines="$(printf '%s\n' "$window_list" | wc -l)"
  ((lines > 16)) && lines=16
  selection="$(
    printf '%s\n' "$window_list" |
      fuzzel --dmenu --prompt="󰖯 " --lines="$lines"
  )" || return
  [[ -n "$selection" ]] || return

  selection_index="${selection%% *}"
  identifier="$(
    jq --raw-output --argjson index "$((selection_index - 1))" '
      .toplevels
      | map(select(.identifier != null))
      | sort_by(.title // "", .["app-id"] // "")
      | .[$index].identifier
    ' <<< "$toplevel_json"
  )"
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
  countdown
  grim -o "$output" - | satty --filename -
}

acquire_recording_lock() {
  exec {recording_lock_fd}> "$recording_lock_file"
  flock --nonblock "$recording_lock_fd"
}

start_recording() {
  local audio_source
  local checks=20
  local mode="$1"
  local target="$2"
  local pid
  local start_time
  local state_file
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
  audio_source="$(find_desktop_audio_source)"
  countdown
  (
    exec {recording_lock_fd}>&-
    exec "$wl_screenrec" \
      "--$mode" "$target" \
      --filename "$video_file" \
      --audio --audio-device "$audio_source" \
      --low-power=off
  ) &
  pid="$!"

  start_time="$(get_process_start_time "$pid")" || true
  while [[ -n "$start_time" ]] && ((checks > 0)) &&
    ! is_expected_recorder "$pid" "$start_time" &&
    is_same_process_running "$pid" "$start_time"; do
    sleep 0.1
    ((checks -= 1)) || true
  done
  if [[ -z "$start_time" ]] || ! is_expected_recorder "$pid" "$start_time"; then
    if [[ -n "$start_time" ]]; then
      reap_recording_child "$pid" "$start_time"
    elif [[ ! -e "/proc/$pid/stat" ]]; then
      wait "$pid" 2>/dev/null || true
    fi
    "${notify[@]}" --icon="replay-record-error" "Screen Recording" "Screen recording failed to start."
    return 1
  fi

  state_file="$(mktemp "$recording_state_file.XXXXXX")"
  printf '%s %s\n' "$pid" "$start_time" > "$state_file"
  mv -f "$state_file" "$recording_state_file"
  "${notify[@]}" -t 850 --icon="media-record" "Screen Recording Started" \
    "Recording $target to $video_file. Select '󰾊 Stop Recording' from the menu to stop."
}

record_region() {
  local geometry

  geometry="$(select_geometry)" || return
  [[ -n "$geometry" ]] || return
  start_recording geometry "$geometry"
}

record_output() {
  local output="${1:-}"

  if [[ -z "$output" ]]; then
    output="$(select_output)" || return
  fi
  start_recording output "$output"
}

show_menu() {
  local lines
  local menu
  local selection

  menu="󰩭 Screenshot a Region\n󰖯 Screenshot a Window\n󰹑 Screenshot a Monitor"
  if is_recording_active; then
    menu+="\n󰾊 Stop Recording"
  else
    menu+="\n󰩭 Record a Region\n󰹑 Record a Monitor"
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
    "󰹑 Record a Monitor") record_output ;;
  esac
}

case "${1:-menu}" in
  menu) show_menu ;;
  region) capture_region ;;
  window) capture_window ;;
  output) capture_output "${2:-}" ;;
  record-region) record_region ;;
  record-output) record_output "${2:-}" ;;
  stop) stop_recording ;;
  *)
    printf 'Usage: %s [menu|region|window|output [name]|record-region|record-output [name]|stop]\n' "$app_name" >&2
    exit 2
    ;;
esac
