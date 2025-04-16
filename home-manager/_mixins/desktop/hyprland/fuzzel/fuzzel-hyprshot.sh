#!/usr/bin/env bash
# A tool to capture screenshots and screen recordings in Hyprland using fuzzel, hyprshot, satty, wl-screenrec, and slurp

set +u  # Disable nounset

APP_NAME="fuzzel-hyprshot"
# Define PID file for tracking recording process
RECORDING_PID_FILE="$XDG_RUNTIME_DIR/$APP_NAME-recording.pid"
NOTIFY="notify-desktop --app-name=$APP_NAME"

# Function to perform countdown before recording
function countdown() {
  local countdown_seconds=5
  while [ $countdown_seconds -gt 0 ]; do
    case $countdown_seconds in
      5) $NOTIFY -t 750 --icon="draw-circle" "" "<big>Five</big>";;
      4) $NOTIFY -t 750 --icon="draw-circle" "" "<big>Four</big>";;
      3) $NOTIFY -t 750 --icon="draw-circle" "" "<big>Three</big>";;
      2) $NOTIFY -t 750 --icon="draw-circle" "" "<big>Two</big>";;
      1) $NOTIFY -t 750 --icon="draw-circle" "" "<big>One</big>";;
    esac
    sleep 1
    countdown_seconds=$((countdown_seconds - 1))
  done
}

# Helper function to check if recording is active
function is_recording_active() {
  if [[ -f "$RECORDING_PID_FILE" ]]; then
    pid=$(cat "$RECORDING_PID_FILE")
    if ps -p "$pid" &>/dev/null; then
      return 0  # Recording is active
    else
      rm -f "$RECORDING_PID_FILE"  # Clean up stale PID file
    fi
  fi
  return 1  # Recording is not active
}

# Helper function to get video directory
function get_video_dir() {
  if [ -n "$XDG_VIDEOS_DIR" ]; then
    video_dir="$XDG_VIDEOS_DIR"
  else
    video_dir="$HOME/Videos"
  fi

  # Create directory if it doesn't exist
  mkdir -p "$video_dir"
  echo "$video_dir"
}

# Helper function to generate video filename
function generate_video_filename() {
  local dir=""
  local timestamp=""
  dir="$(get_video_dir)"
  timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
  echo "${dir}/recording_${timestamp}.mp4"
}

# Function to find the desktop audio monitor source
function find_desktop_audio_source() {
  local default_sink=""
  local default_monitor=""
  local monitor_source=""
  default_sink="$(pactl get-default-sink)"
  default_monitor="$(pactl list short sources | grep "${default_sink}.monitor" | cut -f1)"

  # If found, use the default sink's monitor
  if [[ -n "$default_monitor" ]]; then
    echo "${default_sink}.monitor"
    return
  fi

  # Otherwise, find any monitor source
  monitor_source="$(pactl list short sources | grep "monitor" | head -n1 | cut -f2)"

  if [[ -n "$monitor_source" ]]; then
    echo "$monitor_source"
    return
  fi

  # Fall back to default if no monitor source found
  echo "default"
}

# Stop recording function
function stop_recording() {
  if [[ -f "$RECORDING_PID_FILE" ]]; then
    pid=$(cat "$RECORDING_PID_FILE")
    if ps -p "$pid" &>/dev/null; then
      kill -SIGINT "$pid"
      # Wait for recording to finish
      sleep 0.5
      $NOTIFY --icon="media-record" "Screen Recording Stopped" "Screen recording stopped and saved."
    fi
    rm -f "$RECORDING_PID_FILE"
  else
    $NOTIFY --icon="replay-record-error" "Screen Recording" "No active recording found"
  fi
}

# Build main menu options
function build_menu() {
  local menu="󰩭 Screenshot a Region\n󰖯 Screenshot a Window\n󰹑 Screenshot a Monitor"
  # Add stop recording option if recording is active
  if is_recording_active; then
    menu+="\n󰾊 Stop Recording"
  else
    menu+="\n󰩭 Record a Region\n󰹑 Record a Monitor"
  fi
  echo -e "$menu"
}

# Get main menu options
main_options=$(build_menu)
lines="$(( $(echo "$main_options" | wc -l) + 1 ))"

# Show main menu with fuzzel
selection=$(echo "$main_options" | fuzzel --dmenu --prompt="󱎴 " --lines=$lines --width=24)

# Exit if no selection was made
[[ -z "$selection" ]] && exit 0

case "$selection" in
  "󰩭 Screenshot a Region")
    hyprshot --mode region --raw --silent | satty --filename -
    ;;
  "󰖯 Screenshot a Window")
    # Remember current workspace and monitor before switching
    current_workspace=$(hyprctl activeworkspace -j | jq --raw-output '.id')
    current_monitor=$(hyprctl monitors -j | jq --raw-output '.[] | select(.focused == true) | .name')

    # Create a window selection menu
    window_json=$(hyprctl clients -j)
    # Create a temporary associative array of titles to addresses
    declare -A title_to_address
    readarray -t titles < <(echo "$window_json" | jq --raw-output '.[] | select(.mapped == true) | "\(.title)//ADDR//\(.address)"')
    # Build the list of just titles for display
    lines=0
    window_list=""
    for entry in "${titles[@]}"; do
      title="${entry%%//ADDR//*}"
      address="${entry##*//ADDR//}"
      title_to_address["$title"]="$address"
      window_list+="$title"$'\n'
      lines=$((lines + 1))
    done

    if [[ $lines -gt 16 ]]; then
      lines=16
    fi
    window_selection=$(echo "$window_list" | grep -v "^$" | sort | fuzzel --dmenu --prompt="󰖯 " --lines=$lines)
    [[ -z "$window_selection" ]] && exit 0

    # Get the address for the selected window title
    window_address="${title_to_address[$window_selection]}"

    # Focus the selected window
    hyprctl dispatch focuswindow "address:$window_address"

    # Wait a moment to ensure any transitions are complete
    sleep 0.75
    hyprshot --mode active --mode window --raw --silent | satty --filename - &
    # Wait a moment for satty to initialize
    sleep 0.25

    # Return to original workspace and monitor
    hyprctl dispatch movetoworkspace "$current_workspace,satty"
    hyprctl dispatch focusmonitor "$current_monitor"
    hyprctl dispatch workspace "$current_workspace"
    ;;
  "󰹑 Screenshot a Monitor")
    # Format monitor information for display and selection
    monitor_list=$(hyprctl monitors -j | jq --raw-output '.[] | "\(.name) (\(.width)x\(.height)): \(.description)"')

    # Show monitor selection menu
    lines=$(( $(echo "$monitor_list" | wc -l) + 1 ))
    monitor_selection=$(echo "$monitor_list" | sort | fuzzel --dmenu --prompt="󰹑 " --lines=$lines)
    [[ -z "$monitor_selection" ]] && exit 0

    # Extract monitor name from selection - get everything before the first space or parenthesis
    monitor_name=$(echo "$monitor_selection" | grep --only-matching '^[^ (]*')

    countdown
    hyprshot --mode output --mode "$monitor_name" --raw --silent | satty --filename -
    ;;
  "󰾊 Stop Recording") stop_recording;;
  "󰩭 Record a Region")
    # Use slurp to select a region
    geometry=$(slurp -d)
    [[ -z "$geometry" ]] && exit 0

    video_file=$(generate_video_filename)
    countdown
    $NOTIFY -t 850 --icon="media-record" "Screen Recording Started" "Recording $geometry to $video_file. Select '󰾊  Stop Recording' from the menu to stop."
    sleep 1

    # Start recording in background and save PID
    wl-screenrec \
      --geometry "$geometry" \
      --filename "$video_file" \
      --audio --audio-device "$(find_desktop_audio_source)" \
      --low-power=off &
    echo $! > "$RECORDING_PID_FILE"
    ;;
  "󰹑 Record a Monitor")
    # Format monitor information for display and selection
    monitor_list=$(hyprctl monitors -j | jq --raw-output '.[] | "\(.name) (\(.width)x\(.height)): \(.description)"')

    # Show monitor selection menu
    lines=$(( $(echo "$monitor_list" | wc -l) + 1 ))
    monitor_selection=$(echo "$monitor_list" | sort | fuzzel --dmenu --prompt="󰹑 " --lines=$lines)
    [[ -z "$monitor_selection" ]] && exit 0

    # Extract monitor name from selection - get everything before the first space or parenthesis
    monitor_name=$(echo "$monitor_selection" | grep --only-matching '^[^ (]*')

    video_file=$(generate_video_filename)
    countdown
    $NOTIFY -t 850 --icon="media-record" "Screen Recording Starting" "Recording $monitor_name to $video_file. Select '󰾊  Stop Recording' from the menu to stop."
    sleep 1

    # Start recording in background and save PID
    wl-screenrec \
      --output "$monitor_name" \
      --filename "$video_file" \
      --audio --audio-device "$(find_desktop_audio_source)" \
      --low-power=off &
    echo $! > "$RECORDING_PID_FILE"
    ;;
esac
