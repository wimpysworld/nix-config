#!/usr/bin/env bash

# The compositor-query command, for session tools that do not source
# compositor-query.sh:
#   compositor-query focused-output       name, logical width and height, scale
#   compositor-query output-scale <name>  scale of the named output
#   compositor-query monitors             JSON array of logical geometries

function usage() {
	echo "usage: ${0##*/} focused-output | output-scale <name> | monitors" >&2
	exit 2
}

case "${1:-}" in
focused-output)
	[ $# -eq 1 ] || usage
	detect_compositor
	compositor_focused_output
	;;
output-scale)
	[ $# -eq 2 ] || usage
	detect_compositor
	compositor_output_scale "$2"
	;;
monitors)
	[ $# -eq 1 ] || usage
	detect_compositor
	compositor_monitors
	;;
*)
	usage
	;;
esac
