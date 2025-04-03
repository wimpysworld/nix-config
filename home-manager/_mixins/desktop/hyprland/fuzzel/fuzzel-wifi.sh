#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

# TODO:
# - Add Disconnect WiFi option
# - Add Reconnect WiFi option by selecting the currently connected network
# - Add support for WPA and WEP networks
# - Add support for hidden networks
# - Add support for 802.1X networks
# - Add Open Captive Portal support
# - Add ! to WEP networks

NMCLI="env LANG=C nmcli --colors no --terse"
NOTIFY="notify-desktop --app-name fuzzel-wifi-menu"

function validate_connection() {
  local CONNECTED=""
  local SSID=""
  SSID="$1"
  CONNECTED="$($NMCLI --fields IN-USE,SSID device wifi | grep -w "$SSID" | awk -F ':' '{print $1}' | sed 's/ //g')"
  echo "CONNECTED: [$CONNECTED]"
  # If the connection is not active, notify the user and clean up
  if [ -z "$CONNECTED" ]; then
    $NOTIFY --category "network.error" --icon "network-error" "Error" "Failed to connect to \"$SSID\"." -t 3000
    nmcli connection down id "$SSID"
    nmcli connection delete id "$SSID"
  fi
}

function check_wifi_enabled() {
  local INTERFACES=""
  # Detect Wi-Fi interfaces
  INTERFACES="$($NMCLI --fields TYPE,DEVICE device status | awk -F ':' '$1 == "wifi" {print $2}')"
  if [ -z "$INTERFACES" ]; then
    $NOTIFY --category "network.error" --icon "network-error" "No Wi-Fi interfaces detected." "Please make sure your Wi-Fi adapter is plugged in and enabled." -t 5000
    exit 2
  fi
}

function get_connected_ssid() {
  # Get the SSID of the currently connected network
  local CONNECTED=""
  CONNECTED="$($NMCLI --fields ACTIVE,SSID device wifi | awk -F ':' '$1 == "yes" {print $2}')"
  echo "$CONNECTED"
}

function get_saved_connections() {
  # Get a list of saved Wi-Fi connections
  local CONNECTIONS=""
  CONNECTIONS="$($NMCLI --fields TYPE,NAME connection show | grep wireless | cut -d':' -f2)"
  echo "$CONNECTIONS"
}

check_wifi_enabled

# Check if the script was called with the rescan-wifi flag
if [ "$1" == "rescan-wifi" ]; then
  shift
else
  $NOTIFY --category "network.connected" --icon "network-wireless" "Scanning WiFi..." "Searching for available Wi-Fi networks." -t 1750 --urgency=low
fi

connected_ssid="$(get_connected_ssid)"
saved_connections="$(get_saved_connections)"
secure_ssids=$(mktemp)

# Clean up temp file
trap 'rm -f "$secure_ssids"' EXIT

# Generate a list of available Wi-Fi networks
wifi_list=$($NMCLI --fields "SIGNAL,SECURITY,SSID" device wifi list | awk -F ':' -v connected="$connected_ssid" -v secure_file="$secure_ssids" -v saved_list="$saved_connections" '
  BEGIN {
    connected_line = "";
    count = 0;
    # Define icon arrays for signal strength
    secure_icons[0] = "󰤡"; secure_icons[1] = "󰤤"; secure_icons[2] = "󰤧"; secure_icons[3] = "󰤪";
    open_icons[0] = "󰤟"; open_icons[1] = "󰤢"; open_icons[2] = "󰤥"; open_icons[3] = "󰤨";

    # Process saved connections into an array for easier lookup
    split(saved_list, saved_array, "\n");
    for (i in saved_array) saved_networks[saved_array[i]] = 1;
  }
  {
    # Process signal strength into an icon
    signal = $1;
    security = $2;

    # Handle SSIDs that might contain colons by joining fields 3+
    ssid = $3;
    for(i=4; i<=NF; i++) ssid = ssid ":" $i;

    # Record secure networks in the temp file
    is_secure = (security ~ /WPA|802\.1X/);
    if (is_secure) print ssid > secure_file;

    # Map signal strength to icon index (0-3)
    if (signal < 0) icon_index = -1;
    else icon_index = int(signal / 25) > 3 ? 3 : int(signal / 25);

    # Select appropriate icon
    signal_icon = (icon_index == -1) ? "󰤯" : (is_secure ? secure_icons[icon_index] : open_icons[icon_index]);

    # Store in appropriate array
    if (ssid == connected) {
      connected_line = signal_icon "󰹴" ssid;
    } else {
      if (ssid in saved_networks) {
        other_lines[++count] = signal_icon "" ssid;
      } else {
        other_lines[++count] = signal_icon " " ssid;
      }
    }
  }
  END {
    # Print connected network first if it exists
    if (connected_line != "") print connected_line;

    # Then print all other networks
    for (i=1; i<=count; i++) print other_lines[i];
  }
')

dmenu="dmenu"
wifi_enabled=$($NMCLI --fields WIFI general)
if [[ "$wifi_enabled" =~ "enabled" ]]; then
  menu_list="󱛄 Rescan WiFi\n󱚼 Disable Wi-Fi\n"
elif [[ "$wifi_enabled" =~ "disabled" ]]; then
  menu_list="󱚽 Enable Wi-Fi"
  dmenu="dmenu0"
fi
complete_list="$menu_list\n$wifi_list"

# Determine the number of lines and width of the menu
lines=$(echo -e "$complete_list" | wc -l)
if [ "$lines" -gt 16 ]; then
  lines=16
fi

width=$(echo -e "$complete_list" | awk '{ if (length > max) max = length } END { print max }')
width=$((width + 3))
if [ "$width" -gt 56 ]; then
  width=56
fi

# Select an item from the list
selected_item=$(echo -e "$complete_list" | fuzzel --"$dmenu" --prompt "󱚾 " --width "$width" --lines "$lines" --no-sort)
# Get selected item ID
read -r selected_id <<< "${selected_item:2}"

if [ -z "$selected_id" ]; then
  exit 0
elif [ "$selected_id" == "Enable Wi-Fi" ]; then
  nmcli radio wifi on
elif [ "$selected_id" == "Disable Wi-Fi" ]; then
  nmcli radio wifi off
elif [ "$selected_id" == "Rescan WiFi" ]; then
  $NOTIFY --category "network.connected" --icon "network-wireless" "Rescanning WiFi..." "Searching for available networks." -t 1750 --urgency=low
  nmcli device wifi rescan
  sleep 0.75
  exec "$0" rescan-wifi
else
  # Check if we're selecting the currently connected network
  if [ "$selected_id" == "$connected_ssid" ]; then
    if nmcli connection down id "$selected_id"; then
      $NOTIFY --category "network.disconnected" --icon "network-offline" "WiFi disconnected" "You have disconnected from \"$selected_id\"." -t 3000
    fi
  else
    if [[ $(echo "$saved_connections" | grep -w "$selected_id") = "$selected_id" ]]; then
      $NOTIFY --category "network.connected" --icon "network-wireless" "Reconnecting..." "Attempting to reconnect to \"$selected_id\"."  -t 1500 --urgency=low
      if nmcli connection up id "$selected_id"; then
        $NOTIFY --category "network.connected" --icon "network-wireless" "WiFi reconnected" "You have been reconnected to \"$selected_id\"."  -t 3000
      fi
      validate_connection "$selected_id"
    else
      if grep -q "^$selected_id$" "$secure_ssids"; then
        wifi_password="$(fuzzel --password --prompt-only=" " --lines 0 --dmenu0)"
      fi
      $NOTIFY --category "network.connected" --icon "network-wireless" "Connecting..." "Attempting to connect to \"$selected_id\"."  -t 1500 --urgency=low
      if nmcli device wifi connect "$selected_id" password "$wifi_password"; then
        $NOTIFY --category "network.connected" --icon "network-wireless" "WiFi connected" "You have been connected to \"$selected_id\"." -t 3000
      fi
      validate_connection "$selected_id"
    fi
  fi
fi
