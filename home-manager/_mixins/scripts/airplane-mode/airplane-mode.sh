#!/usr/bin/env bash
set -euo pipefail

app_name="airplane-mode"
state_dir="${XDG_STATE_HOME:-${HOME:?}/.local/state}/$app_name"
saved_radios_file="$state_dir/unblocked"
notify=(fyi "--app-name=Airplane Mode")

read_rfkill_json() {
  rfkill -J -o ID,TYPE,SOFT,HARD 2>/dev/null
}

has_wireless_radios() {
  local json

  json="$(read_rfkill_json)" || return 1
  jq --exit-status '
    (.rfkilldevices // .[""] // [])
    | any(.[]; .type == "wlan" or .type == "bluetooth")
  ' >/dev/null <<< "$json"
}

is_airplane_mode_on() {
  local json

  json="$(read_rfkill_json)" || return 1
  jq --exit-status '
    (.rfkilldevices // .[""] // []) as $devs
    | ($devs | any(.[]; .type == "wlan" or .type == "bluetooth"))
    and ($devs | all(.[]; .soft == "blocked" or .hard == "blocked"))
  ' >/dev/null <<< "$json"
}

enable_airplane_mode() {
  local json
  local unblocked_types

  if ! json="$(read_rfkill_json)" || ! has_wireless_radios; then
    "${notify[@]}" --urgency=critical --icon=airplane-mode-symbolic \
      "Airplane Mode" "No Wi-Fi or Bluetooth radios found." || true
    return 1
  fi

  unblocked_types="$(
    jq --raw-output '
      (.rfkilldevices // .[""] // [])
      | map(select(.soft == "unblocked") | .type)
      | unique[]
    ' <<< "$json"
  )"

  mkdir -p "$state_dir"
  if [[ -n "$unblocked_types" ]]; then
    printf '%s\n' "$unblocked_types" > "$saved_radios_file"
  else
    rm -f "$saved_radios_file"
  fi

  if ! rfkill block all; then
    "${notify[@]}" --urgency=critical --icon=airplane-mode-symbolic \
      "Airplane Mode" "Failed to disable wireless radios." || true
    return 1
  fi

  "${notify[@]}" --urgency=low --icon=airplane-mode-symbolic \
    "󰀝 Airplane Mode" "Wireless radios disabled." || true
}

disable_airplane_mode() {
  local radio_type
  local restored=0

  if [[ -f "$saved_radios_file" ]]; then
    while IFS= read -r radio_type; do
      case "$radio_type" in
        wlan | bluetooth | uwb | wimax | wwan | gps | fm | nfc)
          if ! rfkill unblock "$radio_type"; then
            "${notify[@]}" --urgency=critical --icon=airplane-mode-symbolic \
              "Airplane Mode" "Failed to restore $radio_type radio." || true
            return 1
          fi
          restored=1
          ;;
      esac
    done < "$saved_radios_file"
    rm -f "$saved_radios_file"
  fi

  if ((restored == 0)); then
    if ! rfkill unblock all; then
      "${notify[@]}" --urgency=critical --icon=airplane-mode-symbolic \
        "Airplane Mode" "Failed to restore wireless radios." || true
      return 1
    fi
  fi

  "${notify[@]}" --urgency=low --icon=airplane-mode-symbolic \
    "󰀞 Airplane Mode" "Wireless radios restored." || true
}

toggle_airplane_mode() {
  if is_airplane_mode_on; then
    disable_airplane_mode
  else
    enable_airplane_mode
  fi
}

case "${1:-status}" in
  available) has_wireless_radios ;;
  status) is_airplane_mode_on ;;
  on) enable_airplane_mode ;;
  off) disable_airplane_mode ;;
  toggle) toggle_airplane_mode ;;
  *)
    printf 'Usage: %s [available|status|on|off|toggle]\n' "$app_name" >&2
    exit 2
    ;;
esac
