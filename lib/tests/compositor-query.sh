#!/usr/bin/env bash

# Each case writes the compositor replies, runs one command, and compares its
# output. lib/tests/compositor-query.nix runs this script.

set -euo pipefail

: "${out:?}"

query=$1
wleave_session=$2
xwayland_dpi=$3

export FAKE_STATE="$TMPDIR/state"
export XDG_RUNTIME_DIR="$TMPDIR/run"
unset MANGO_INSTANCE_SIGNATURE WAYFIRE_SOCKET WAYLAND_DISPLAY
mkdir -p "$XDG_RUNTIME_DIR"
failures=0

fail() {
	echo "FAIL: $*" >&2
	failures=$((failures + 1))
}

expect() {
	local name=$1 expected=$2 actual=$3
	if [ "$actual" != "$expected" ]; then
		fail "$name: expected '$expected', got '$actual'"
	fi
}

# Detection needs a live socket in the runtime directory.
compositor() {
	rm -rf "$FAKE_STATE" "${XDG_RUNTIME_DIR:?}"/*
	mkdir -p "$FAKE_STATE"
	python3 -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' \
		"$XDG_RUNTIME_DIR/$1"
}

# Arguments: name, active, x, y, logical width, logical height, scale.
monitor() {
	jq -nc --arg name "$1" --argjson active "$2" --argjson x "$3" --argjson y "$4" \
		--argjson width "$5" --argjson height "$6" --argjson scale "$7" \
		'{name: $name, active: $active, x: $x, y: $y, width: $width, height: $height, scale: $scale}'
}

mango() {
	compositor mango-1.sock
	jq -sc '{monitors: .}' >"$FAKE_STATE/monitors.json"
}

wleave_margins() {
	rm -f "$FAKE_STATE/wleave"
	"$wleave_session" 2>/dev/null
	cat "$FAKE_STATE/wleave"
}

margins() {
	echo "--no-version-info --buttons-per-row 6 ${1:+$1 }--layout layout.json --css style.css"
}

# Arguments: host, monitors, expected focused output, expected margins,
# primary output, expected Xft.dpi.
mango_case() {
	local host=$1 monitors=$2 focused=$3 expected_margins=$4 primary=$5 dpi=$6
	mango <<<"$monitors"
	expect "$host focused-output" "$focused" "$("$query" focused-output)"
	expect "$host wleave" "$(margins "$expected_margins")" "$(wleave_margins)"
	if TEST_PRIMARY=$primary "$xwayland_dpi" >/dev/null; then
		fail "$host xwayland-dpi: expected exit 1 when the stream ends"
	fi
	expect "$host Xft.dpi" "Xft.dpi: $dpi" "$(cat "$FAKE_STATE/xrdb")"
}

mango_case skrye "$(
	monitor DP-1 true 0 0 2560 2880 1
	monitor DP-4 false 2560 0 2560 2880 1
)" "DP-1 2560 2880 1" \
	"--margin-left 512 --margin-right 512 --margin-top 960 --margin-bottom 960" DP-1 96

mango_case zannah "$(monitor DP-1 true 0 0 3440 1440 1)" "DP-1 3440 1440 1" \
	"--margin-left 952 --margin-right 952 --margin-top 240 --margin-bottom 240" DP-1 96

mango_case ravi "$(
	monitor eDP-1 true 0 0 1920 1280 1.5
	monitor DP-3 false 1920 0 2048 1280 1.25
)" "eDP-1 1920 1280 1.5" \
	"--margin-left 192 --margin-right 192 --margin-top 160 --margin-bottom 160" eDP-1 144

# The menu follows the focused output, and Xft.dpi follows the primary.
mango_case ravi-external "$(
	monitor eDP-1 false 0 0 1920 1280 1.5
	monitor DP-3 true 1920 0 2048 1280 1.25
)" "DP-3 2048 1280 1.25" \
	"--margin-left 256 --margin-right 256 --margin-top 160 --margin-bottom 160" eDP-1 144

mango_case tanis "$(monitor eDP-1 true 0 0 1920 1200 1)" "eDP-1 1920 1200 1" \
	"--margin-left 192 --margin-right 192 --margin-top 120 --margin-bottom 120" eDP-1 96

# Margins never go below zero, and an odd remainder goes to the far edge.
mango_case small "$(monitor eDP-1 true 0 0 1280 800 1.25)" "eDP-1 1280 800 1.25" \
	"--margin-left 0 --margin-right 0 --margin-top 0 --margin-bottom 0" eDP-1 120
mango_case odd "$(monitor eDP-1 true 0 0 1537 961 1)" "eDP-1 1537 961 1" \
	"--margin-left 0 --margin-right 1 --margin-top 0 --margin-bottom 1" eDP-1 96

mango <<<"$(monitor eDP-1 true 0 0 1920 1200 1)"
if "$query" output-scale DP-9 >/dev/null 2>&1; then
	fail "output-scale: expected failure for an absent output"
fi
if "$query" focused-output extra >/dev/null 2>&1; then
	fail "focused-output: expected a usage error for an extra argument"
fi

# bane runs Wayfire. Its IPC gives the focused output and wlr-randr the scale.
compositor wayfire-1.socket
jq -nc '{result: "ok", info: {name: "eDP-1", geometry: {x: 0, y: 0, width: 2048, height: 1280}}}' \
	>"$FAKE_STATE/focused.json"
jq -nc '[{name: "DP-4", enabled: true, scale: 1.0}, {name: "eDP-1", enabled: true, scale: 1.25}]' \
	>"$FAKE_STATE/randr.json"
expect "bane focused-output" "eDP-1 2048 1280 1.25" "$("$query" focused-output)"
expect "bane output-scale" "1.0" "$("$query" output-scale DP-4)"
expect "bane wleave" \
	"$(margins "--margin-left 256 --margin-right 256 --margin-top 160 --margin-bottom 160")" \
	"$(wleave_margins)"

jq -nc '{result: "ok", info: null}' >"$FAKE_STATE/focused.json"
if "$query" focused-output >/dev/null 2>&1; then
	fail "bane focused-output: expected failure without a focused output"
fi
expect "bane wleave without a focused output" "$(margins "")" "$(wleave_margins)"

# Without a compositor, wleave keeps its default margins.
compositor unrelated.sock
expect "no compositor wleave" "$(margins "")" "$(wleave_margins)"

if [ "$failures" -gt 0 ]; then
	exit 1
fi
touch "$out"
