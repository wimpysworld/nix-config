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

stop_session() {
	attempt "stop $session_target" systemctl --user stop "$session_target"
	attempt "stop $portal_service" systemctl --user stop "$portal_service"
}

reset_start_limits() {
	local service
	local wants
	local -a reset_units=("$session_target" "$portal_service")
	local -a wanted_units=()

	wants=$(systemctl --user show --property=Wants --value "$session_target") \
		|| record_failure "read direct wants for $session_target" "$?"
	read -r -a wanted_units <<<"${wants:-}"
	for service in "${wanted_units[@]}"; do
		case "$service" in
		*.service) reset_units+=("$service") ;;
		esac
	done

	attempt "reset session failures" systemctl --user reset-failed "${reset_units[@]}"
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
