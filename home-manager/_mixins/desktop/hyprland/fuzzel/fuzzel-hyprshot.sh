#!/usr/bin/env bash
# A tool to capture screenshots in Hyprland using fuzzel, hyprshot, and satty

set +u  # Disable nounset

# Main menu options
main_options="󰩭 Screenshot a Region
󰖯 Screenshot a Window
󰹑 Screenshot a Monitor"
lines="$(( $(echo "$main_options" | wc -l) + 1 ))"

# Show main menu with fuzzel
selection=$(echo "$main_options" | fuzzel --dmenu --prompt="󱇣 " --lines=$lines --width=24)

# Exit if no selection was made
[[ -z "$selection" ]] && exit 0

case "$selection" in
  "󰩭 Screenshot a Region")
    hyprshot --mode region --raw | satty --filename -
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
    sleep 0.5
    hyprshot --mode active --mode window --raw | satty --filename - &
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

    # Wait a moment to ensure any transitions are complete
    sleep 0.5

    hyprshot --mode output --mode "$monitor_name" --raw | satty --filename -
    ;;
esac
