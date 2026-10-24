#!/usr/bin/env bash

# Each case writes the compositor replies, runs one command, and compares its
# output. lib/tests/compositor-query.nix runs this script.

set -euo pipefail

: "${out:?}"

query=$1
wleave_session=$2
xwayland_dpi=$3
capture_mapping=$4

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

# Both compositors report the same ravi layout with name and logical
# geometry. DP-2 is a 2560x1440 display rotated by 90 degrees at scale 1.25,
# so its logical box is 1152x2048. fuzzel-capture maps a region or a window
# to the outputs that it overlaps, and clips a window to its output.
ravi_monitors='[{"name":"eDP-1","x":0,"y":0,"width":1920,"height":1280},{"name":"DP-2","x":1920,"y":0,"width":1152,"height":2048}]'

capture_case() {
	local host=$1
	expect "$host monitors" "$ravi_monitors" "$("$query" monitors)"
	expect "$host region on eDP-1" "eDP-1" "$("$capture_mapping" outputs "100,100 200x200")"
	expect "$host region on rotated DP-2" "DP-2" "$("$capture_mapping" outputs "2000,1500 100x100")"
	expect "$host region on two outputs" $'eDP-1\nDP-2' "$("$capture_mapping" outputs "1900,100 100x100")"
	expect "$host region at the eDP-1 corner" "eDP-1" "$("$capture_mapping" outputs "1919,1279 1x1")"
	expect "$host region off the outputs" "" "$("$capture_mapping" outputs "4000,0 10x10")"
	expect "$host window clipped to DP-2" "1920,1200 280x848" "$("$capture_mapping" clamp "1800,1200 400x900" DP-2)"
	if "$capture_mapping" clamp "100,100 10x10" DP-2 >/dev/null; then
		fail "$host clamp: expected failure for a window outside the output"
	fi
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

mango <<<"$(
	monitor eDP-1 true 0 0 1920 1280 1.5
	monitor DP-2 false 1920 0 1152 2048 1.25
)"
capture_case ravi-mango

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

# Wayfire reports view geometry relative to the current workspace of the
# output, so windows gain the output position, and a view on another
# workspace is not visible. Panels and unmapped views are not windows.
jq -nc '[
	{name: "eDP-1", geometry: {x: 0, y: 0, width: 2048, height: 1280}},
	{name: "DP-4", geometry: {x: 2048, y: 0, width: 2560, height: 1440}}
]' >"$FAKE_STATE/outputs.json"
jq -nc '[
	{id: 7, title: "Terminal", "app-id": "foot", "output-name": "DP-4", role: "toplevel", type: "toplevel", mapped: true, minimized: false, geometry: {x: 10, y: 20, width: 800, height: 600}},
	{id: 8, title: "Mail", "app-id": "thunderbird", "output-name": "eDP-1", role: "toplevel", type: "toplevel", mapped: true, minimized: false, geometry: {x: 2100, y: 0, width: 900, height: 700}},
	{id: 9, title: "Notes", "app-id": "gedit", "output-name": "eDP-1", role: "toplevel", type: "toplevel", mapped: true, minimized: true, geometry: {x: 0, y: 0, width: 500, height: 500}},
	{id: 3, title: "waybar", "app-id": "waybar", "output-name": "DP-4", role: "desktop-environment", type: "panel", mapped: true, minimized: false, geometry: {x: 0, y: 0, width: 2560, height: 40}},
	{id: 4, title: "", "app-id": "", "output-name": "null", role: "toplevel", type: "toplevel", mapped: false, minimized: false, geometry: {x: 0, y: 0, width: 0, height: 0}}
]' >"$FAKE_STATE/views.json"
expect "bane windows" \
	"$(jq -c '.' <<<'[
		{"id":7,"title":"Terminal","app-id":"foot","output":"DP-4","x":2058,"y":20,"width":800,"height":600,"visible":true},
		{"id":8,"title":"Mail","app-id":"thunderbird","output":"eDP-1","x":2100,"y":0,"width":900,"height":700,"visible":false},
		{"id":9,"title":"Notes","app-id":"gedit","output":"eDP-1","x":0,"y":0,"width":500,"height":500,"visible":false}
	]')" \
	"$("$query" windows)"
echo '{"result": "ok"}' >"$FAKE_STATE/focus-reply.json"
"$query" focus-window 8 || fail "bane focus-window: expected success"
expect "bane focus-window request" 'compositor-wayfire-ipc focus-view {"id": 8}' "$(cat "$FAKE_STATE/focus")"
echo '{"error": "no such view"}' >"$FAKE_STATE/focus-reply.json"
if "$query" focus-window 99 >/dev/null 2>&1; then
	fail "bane focus-window: expected failure for an absent view"
fi
if "$query" focus-window '1}' >/dev/null 2>&1; then
	fail "focus-window: expected a usage error for a non-numeric id"
fi

jq -nc '[
	{name: "eDP-1", geometry: {x: 0, y: 0, width: 1920, height: 1280}},
	{name: "DP-2", geometry: {x: 1920, y: 0, width: 1152, height: 2048}}
]' >"$FAKE_STATE/outputs.json"
capture_case ravi-wayfire

# Mango reports client geometry in layout coordinates and its own
# visibility. A client without a monitor is not a window.
compositor mango-1.sock
jq -nc '{clients: [
	{id: 4, title: "Terminal", appid: "foot", monitor: "DP-4", x: 2560, y: 0, width: 1280, height: 2880, is_visible: true, tags: [1]},
	{id: 5, title: "Mail", appid: "thunderbird", monitor: "DP-1", x: 100, y: 100, width: 900, height: 700, is_visible: false, tags: [3]},
	{id: 6, title: "Parked", appid: "foot", monitor: "", x: 0, y: 0, width: 10, height: 10, is_visible: false, tags: []}
]}' >"$FAKE_STATE/clients.json"
expect "skrye windows" \
	'[{"id":4,"title":"Terminal","app-id":"foot","output":"DP-4","x":2560,"y":0,"width":1280,"height":2880,"visible":true},{"id":5,"title":"Mail","app-id":"thunderbird","output":"DP-1","x":100,"y":100,"width":900,"height":700,"visible":false}]' \
	"$("$query" windows)"
echo '{"success":true}' >"$FAKE_STATE/focus-reply.json"
"$query" focus-window 5 || fail "skrye focus-window: expected success"
expect "skrye focus-window request" "mmsg dispatch focusid client,5" "$(cat "$FAKE_STATE/focus")"
echo '{"error":"no client found"}' >"$FAKE_STATE/focus-reply.json"
if "$query" focus-window 99 >/dev/null 2>&1; then
	fail "skrye focus-window: expected failure for an absent client"
fi

# Without a compositor, wleave keeps its default margins.
compositor unrelated.sock
expect "no compositor wleave" "$(margins "")" "$(wleave_margins)"

if [ "$failures" -gt 0 ]; then
	exit 1
fi
touch "$out"
