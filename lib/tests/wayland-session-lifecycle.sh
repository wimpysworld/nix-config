#!/usr/bin/env bash

set -euo pipefail

: "${out:?}"

cleanup_source=$1
launcher_source=$2
session_source=$3
fake_path=$4
runtime_path=$5

export PATH="$fake_path/bin:$runtime_path"
export FAKE_EVENT_LOG="$TMPDIR/events"

assert_status() {
	local expected=$1
	local actual=$2

	if (( actual != expected )); then
		printf 'expected status %d, got %d\n' "$expected" "$actual" >&2
		exit 1
	fi
}

assert_log() {
	local expected=$1

	printf '%s' "$expected" >"$TMPDIR/expected"
	diff -u "$TMPDIR/expected" "$FAKE_EVENT_LOG"
}

reset_case() {
	: >"$FAKE_EVENT_LOG"
	unset FAKE_ADAPTER_STATUS FAKE_CLEANUP_FAILURES FAKE_CLEANUP_STATUS
	unset FAKE_DBUS_STATUS FAKE_LAUNCHER_STATUS FAKE_PLAYERCTL_STATUS
	unset FAKE_SYSTEMCTL_FAILURES FAKE_SYSTEMCTL_INACTIVE FAKE_SYSTEMCTL_NOT_FOUND
	unset FAKE_SYSTEMCTL_STATUS FAKE_SYSTEMCTL_WANTS
}

for command in \
	systemctl \
	dbus-update-activation-environment \
	wayland-session-cleanup \
	wayland-session-adapter \
	fake-launcher \
	unbuffer \
	playerctl \
	hostname \
	bluetoothctl; do
	test "$(command -v "$command")" = "$fake_path/bin/$command"
done

reset_case
export FAKE_SYSTEMCTL_WANTS='alpha.service ignored.target beta.service gamma.socket'
bash "$cleanup_source" test-session.target test-portal.service 2 DISPLAY XDG_SESSION_TYPE finalise \
	2>"$TMPDIR/cleanup-finalise.stderr"
assert_log $'systemctl <--user> <stop> <test-session.target>\nsystemctl <--user> <stop> <test-portal.service>\ndbus-update-activation-environment <--systemd> <DISPLAY=> <XDG_SESSION_TYPE=>\nsystemctl <--user> <unset-environment> <DISPLAY> <XDG_SESSION_TYPE>\nsystemctl <--user> <show> <--property=Wants> <--value> <test-session.target>\nsystemctl <--user> <reset-failed> <test-session.target> <test-portal.service> <alpha.service> <beta.service>\n'

reset_case
export FAKE_DBUS_STATUS=8
export FAKE_SYSTEMCTL_FAILURES='--user stop test-session.target|--user show --property=Wants --value test-session.target'
set +e
bash "$cleanup_source" test-session.target test-portal.service 2 DISPLAY XDG_SESSION_TYPE finalise \
	2>"$TMPDIR/cleanup-failures.stderr"
status=$?
set -e
assert_status 1 "$status"
assert_log $'systemctl <--user> <stop> <test-session.target>\nsystemctl <--user> <show> <--property=LoadState> <--value> <test-session.target>\nsystemctl <--user> <show> <--property=ActiveState> <--value> <test-session.target>\nsystemctl <--user> <stop> <test-portal.service>\ndbus-update-activation-environment <--systemd> <DISPLAY=> <XDG_SESSION_TYPE=>\nsystemctl <--user> <unset-environment> <DISPLAY> <XDG_SESSION_TYPE>\nsystemctl <--user> <show> <--property=Wants> <--value> <test-session.target>\nsystemctl <--user> <show> <--property=LoadState> <--value> <test-session.target>\nsystemctl <--user> <reset-failed> <test-session.target> <test-portal.service>\n'
grep -Fx 'wayland-session-cleanup: stop test-session.target failed with code 7' \
	"$TMPDIR/cleanup-failures.stderr" >/dev/null
grep -Fx 'wayland-session-cleanup: neutralise D-Bus activation environment failed with code 8' \
	"$TMPDIR/cleanup-failures.stderr" >/dev/null
grep -Fx 'wayland-session-cleanup: read direct wants for test-session.target failed with code 7' \
	"$TMPDIR/cleanup-failures.stderr" >/dev/null

reset_case
export FAKE_SYSTEMCTL_WANTS='alpha.service ignored.target beta.service'
bash "$cleanup_source" test-session.target test-portal.service 2 DISPLAY XDG_SESSION_TYPE prepare
assert_log $'systemctl <--user> <stop> <test-session.target>\nsystemctl <--user> <stop> <test-portal.service>\n'

reset_case
export FAKE_SYSTEMCTL_WANTS='alpha.service ignored.target beta.service'
bash "$cleanup_source" test-session.target test-portal.service 2 DISPLAY XDG_SESSION_TYPE recover
assert_log $'systemctl <--user> <stop> <test-session.target>\nsystemctl <--user> <stop> <test-portal.service>\nsystemctl <--user> <show> <--property=Wants> <--value> <test-session.target>\nsystemctl <--user> <reset-failed> <test-session.target> <test-portal.service> <alpha.service> <beta.service>\n'

reset_case
export FAKE_SYSTEMCTL_FAILURES='--user stop missing.target|--user stop inactive.service|--user show --property=Wants --value missing.target|--user reset-failed missing.target inactive.service'
export FAKE_SYSTEMCTL_INACTIVE=inactive.service
export FAKE_SYSTEMCTL_NOT_FOUND=missing.target
bash "$cleanup_source" missing.target inactive.service 0 recover
assert_log $'systemctl <--user> <stop> <missing.target>\nsystemctl <--user> <show> <--property=LoadState> <--value> <missing.target>\nsystemctl <--user> <stop> <inactive.service>\nsystemctl <--user> <show> <--property=LoadState> <--value> <inactive.service>\nsystemctl <--user> <show> <--property=ActiveState> <--value> <inactive.service>\nsystemctl <--user> <show> <--property=Wants> <--value> <missing.target>\nsystemctl <--user> <show> <--property=LoadState> <--value> <missing.target>\nsystemctl <--user> <reset-failed> <missing.target> <inactive.service>\nsystemctl <--user> <show> <--property=LoadState> <--value> <missing.target>\nsystemctl <--user> <show> <--property=LoadState> <--value> <inactive.service>\nsystemctl <--user> <reset-failed> <inactive.service>\n'

reset_case
bash "$session_source" test-session.target 2 DISPLAY XDG_SESSION_TYPE start
assert_log $'wayland-session-cleanup <recover>\ndbus-update-activation-environment <--systemd> <DISPLAY> <XDG_SESSION_TYPE>\nsystemctl <--user> <start> <test-session.target>\n'

reset_case
export FAKE_CLEANUP_FAILURES=recover
bash "$session_source" test-session.target 2 DISPLAY XDG_SESSION_TYPE start \
	2>"$TMPDIR/start-failure.stderr"
assert_log $'wayland-session-cleanup <recover>\ndbus-update-activation-environment <--systemd> <DISPLAY> <XDG_SESSION_TYPE>\nsystemctl <--user> <start> <test-session.target>\n'
grep -Fx 'wayland-session-cleanup: fake recover warning' "$TMPDIR/start-failure.stderr" >/dev/null
grep -Fx 'wayland-session: recovery failed with code 9, startup will continue' \
	"$TMPDIR/start-failure.stderr" >/dev/null

reset_case
export FAKE_DBUS_STATUS=6
set +e
bash "$session_source" test-session.target 2 DISPLAY XDG_SESSION_TYPE start
status=$?
set -e
assert_status 6 "$status"
assert_log $'wayland-session-cleanup <recover>\ndbus-update-activation-environment <--systemd> <DISPLAY> <XDG_SESSION_TYPE>\n'

reset_case
export FAKE_SYSTEMCTL_FAILURES='--user start test-session.target'
set +e
bash "$session_source" test-session.target 2 DISPLAY XDG_SESSION_TYPE start
status=$?
set -e
assert_status 7 "$status"
assert_log $'wayland-session-cleanup <recover>\ndbus-update-activation-environment <--systemd> <DISPLAY> <XDG_SESSION_TYPE>\nsystemctl <--user> <start> <test-session.target>\n'

reset_case
bash "$session_source" test-session.target 2 DISPLAY XDG_SESSION_TYPE logout
assert_log $'systemctl <--user> <start> <--no-block> <wayland-session-logout.service>\n'

reset_case
bash "$session_source" test-session.target 2 DISPLAY XDG_SESSION_TYPE logout
bash "$session_source" test-session.target 2 DISPLAY XDG_SESSION_TYPE logout
assert_log $'systemctl <--user> <start> <--no-block> <wayland-session-logout.service>\nsystemctl <--user> <start> <--no-block> <wayland-session-logout.service>\n'

reset_case
export FAKE_SYSTEMCTL_FAILURES='--user start --no-block wayland-session-logout.service'
set +e
bash "$session_source" test-session.target 2 DISPLAY XDG_SESSION_TYPE logout
status=$?
set -e
assert_status 7 "$status"
assert_log $'systemctl <--user> <start> <--no-block> <wayland-session-logout.service>\n'

reset_case
export FAKE_PLAYERCTL_STATUS=13
set +e
bash "$session_source" test-session.target 2 DISPLAY XDG_SESSION_TYPE logout-action
status=$?
set -e
assert_status 13 "$status"
assert_log $'playerctl <--all-players> <pause>\nwayland-session-cleanup <prepare>\nwayland-session-adapter <logout>\n'

reset_case
export FAKE_ADAPTER_STATUS=17
set +e
bash "$session_source" test-session.target 2 DISPLAY XDG_SESSION_TYPE logout-action
status=$?
set -e
assert_status 17 "$status"
assert_log $'playerctl <--all-players> <pause>\nwayland-session-cleanup <prepare>\nwayland-session-adapter <logout>\n'

reset_case
export FAKE_CLEANUP_FAILURES=prepare
export FAKE_CLEANUP_STATUS=19
export FAKE_ADAPTER_STATUS=17
set +e
bash "$session_source" test-session.target 2 DISPLAY XDG_SESSION_TYPE logout-action \
	2>"$TMPDIR/logout-failure.stderr"
status=$?
set -e
assert_status 17 "$status"
assert_log $'playerctl <--all-players> <pause>\nwayland-session-cleanup <prepare>\nwayland-session-adapter <logout>\n'
grep -Fx 'wayland-session-cleanup: fake prepare warning' "$TMPDIR/logout-failure.stderr" >/dev/null

reset_case
export FAKE_PLAYERCTL_STATUS=13
export FAKE_CLEANUP_FAILURES=prepare
export FAKE_CLEANUP_STATUS=19
set +e
bash "$session_source" test-session.target 2 DISPLAY XDG_SESSION_TYPE logout-action \
	2>"$TMPDIR/logout-precedence.stderr"
status=$?
set -e
assert_status 13 "$status"
assert_log $'playerctl <--all-players> <pause>\nwayland-session-cleanup <prepare>\nwayland-session-adapter <logout>\n'
grep -Fx 'wayland-session-cleanup: fake prepare warning' "$TMPDIR/logout-precedence.stderr" >/dev/null

reset_case
export FAKE_CLEANUP_FAILURES=finalise
export FAKE_CLEANUP_STATUS=29
export FAKE_LAUNCHER_STATUS=23
mkdir -p "$TMPDIR/home"
set +e
HOME="$TMPDIR/home" bash "$launcher_source" \
	"$fake_path/bin/fake-launcher" 'Test compositor' test-session \
	"$fake_path/bin/wayland-session-cleanup" 1 --prefix session-argument \
	2>"$TMPDIR/launcher.stderr"
status=$?
set -e
assert_status 23 "$status"
assert_log $'fake-launcher <--prefix> <session-argument>\nwayland-session-cleanup <finalise>\n'
grep -F 'Session cleanup failed with code 29' "$TMPDIR/home/.local/log/test-session.log" >/dev/null
grep -F 'Test compositor exited with code 23' "$TMPDIR/home/.local/log/test-session.log" >/dev/null

touch "$out"
