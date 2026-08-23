#!/usr/bin/env bash

set -euo pipefail

if (( $# < 4 )); then
	echo "wayland-session-cleanup: invalid lifecycle configuration" >&2
	exit 2
fi

session_target=$1
portal_service=$2
environment_count=$3
shift 3

if [[ ! $environment_count =~ ^[0-9]+$ ]] || (( $# != environment_count + 1 )); then
	echo "wayland-session-cleanup: invalid environment configuration" >&2
	exit 2
fi

session_environment=("${@:1:environment_count}")
shift "$environment_count"
operation=$1

status=0

record_failure() {
	local description=$1
	local step_status=$2

	printf 'wayland-session-cleanup: %s failed with code %d\n' "$description" "$step_status" >&2
	status=1
}

attempt() {
	local description=$1
	shift

	"$@" || record_failure "$description" "$?"
}

unit_is_missing() {
	local load_state
	local unit=$1

	load_state=$(systemctl --user show --property=LoadState --value "$unit") || return 1
	[[ $load_state == "not-found" ]]
}

unit_needs_no_stop() {
	local active_state
	local unit=$1

	if unit_is_missing "$unit"; then
		return 0
	fi
	active_state=$(systemctl --user show --property=ActiveState --value "$unit") || return 1
	[[ $active_state == "inactive" || $active_state == "failed" || $active_state == "deactivating" ]]
}

stop_unit() {
	local step_status
	local unit=$1

	if systemctl --user stop "$unit"; then
		return 0
	else
		step_status=$?
	fi
	if unit_needs_no_stop "$unit"; then
		return 0
	fi
	record_failure "stop $unit" "$step_status"
}

stop_session() {
	stop_unit "$session_target"
	stop_unit "$portal_service"
}

reset_start_limits() {
	local load_state
	local service
	local step_status
	local wants
	local -a reset_units=("$session_target" "$portal_service")
	local -a retry_units=()
	local -a wanted_units=()

	if wants=$(systemctl --user show --property=Wants --value "$session_target"); then
		:
	else
		step_status=$?
		if ! unit_is_missing "$session_target"; then
			record_failure "read direct wants for $session_target" "$step_status"
		fi
	fi
	read -r -a wanted_units <<<"${wants:-}"
	for service in "${wanted_units[@]}"; do
		case "$service" in
		*.service) reset_units+=("$service") ;;
		esac
	done

	if systemctl --user reset-failed "${reset_units[@]}"; then
		return 0
	else
		step_status=$?
	fi

	for service in "${reset_units[@]}"; do
		load_state=$(systemctl --user show --property=LoadState --value "$service") || load_state=""
		if [[ $load_state != "not-found" ]]; then
			retry_units+=("$service")
		fi
	done

	if (( ${#retry_units[@]} == ${#reset_units[@]} )); then
		record_failure "reset session failures" "$step_status"
	elif (( ${#retry_units[@]} > 0 )); then
		attempt "reset session failures" systemctl --user reset-failed "${retry_units[@]}"
	fi
}

neutralise_environment() {
	local variable
	local -a empty_environment=()

	for variable in "${session_environment[@]}"; do
		empty_environment+=("${variable}=")
	done

	attempt "neutralise D-Bus activation environment" \
		dbus-update-activation-environment --systemd "${empty_environment[@]}"
	attempt "unset systemd activation environment" \
		systemctl --user unset-environment "${session_environment[@]}"
}

case "$operation" in
prepare)
	stop_session
	;;
finalise)
	stop_session
	neutralise_environment
	reset_start_limits
	;;
recover)
	stop_session
	reset_start_limits
	;;
*)
	echo "wayland-session-cleanup: expected prepare, finalise, or recover" >&2
	exit 2
	;;
esac

exit "$status"
