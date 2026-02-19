#!/usr/bin/env bash

# Exit on error, undefined variable, and error in pipes
set -euo pipefail

# Show help message
show_help() {
	cat <<'EOF'
Usage: noughty <command> [args...]

Nøughty Linux utility collection - tools for working with Nix.

Commands:
  path <executable>           Show the Nix store path for an executable
  run [--unstable] <package>  Run a single package from Nixpkgs
  shell [--unstable] <pkg...> Spawn shell with multiple packages
  channel                     Show current stable Nixpkgs channel
  spawn <program> [args...]   Launch program detached from session
  facts                       Show system attributes and configuration

Options:
  -h, --help                  Show this help message

Examples:
  noughty path firefox        # Show where firefox is in the Nix store
  noughty run hello           # Run hello from stable channel
  noughty run --unstable git  # Run git from unstable channel
  noughty shell git vim       # Shell with git and vim
  noughty channel             # Show current stable channel
  noughty spawn firefox       # Launch firefox detached
  noughty facts               # Show system attributes
EOF
}

# Source the shared stable channel detection
get_stable_nixpkgs() {
	local cache_file="${XDG_CACHE_HOME:-$HOME/.cache}/noughty-linux-stable-channel"
	local cache_expiry=604800 # 1 week
	local current_time cache_time

	current_time=$(date +%s)

	# Check if cache exists and is still valid
	if [ -f "$cache_file" ]; then
		cache_time=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
		if [ $((current_time - cache_time)) -lt $cache_expiry ]; then
			cat "$cache_file"
			return 0
		fi
	fi

	# Query nixpkgs repository for release branches
	local stable_branches
	stable_branches=$(git ls-remote --heads https://github.com/NixOS/nixpkgs.git 2>/dev/null |
		grep -o 'refs/heads/nixos-[0-9][0-9]\.[0-9][0-9]$' |
		sed 's|refs/heads/||' |
		sort -V |
		tail -1 || echo "")

	if [ -n "$stable_branches" ]; then
		mkdir -p "$(dirname "$cache_file")"
		echo "$stable_branches" >"$cache_file"
		echo "$stable_branches"
		return 0
	fi

	# Fallback
	echo "nixos-unstable"
}

# Command: noughty path (was nook)
cmd_path() {
	if [ $# -ne 1 ]; then
		echo "Usage: noughty path <executable>" >&2
		echo "Shows the Nix store path for an executable in your PATH" >&2
		exit 1
	fi

	local executable="$1"
	local exec_path
	exec_path=$(which "$executable" 2>/dev/null)

	if [ -z "$exec_path" ]; then
		echo "Error: '$executable' not found in PATH" >&2
		exit 1
	fi

	# Extract store path
	local current_path="$exec_path"
	local seen_paths=()

	while [ -n "$current_path" ]; do
		# Check for loops
		for seen in "${seen_paths[@]}"; do
			if [ "$current_path" = "$seen" ]; then
				break 2
			fi
		done
		seen_paths+=("$current_path")

		# If in /nix/store, extract and return
		if [[ "$current_path" =~ ^/nix/store/ ]]; then
			echo "$current_path" | sed -n 's|^\(/nix/store/[^/]*\).*|\1|p'
			return 0
		fi

		# Follow symlinks
		if [ -L "$current_path" ]; then
			current_path=$(readlink "$current_path")
			if [[ ! "$current_path" =~ ^/ ]]; then
				current_path="$(dirname "${seen_paths[-1]}")/$current_path"
			fi
		# Check wrapper scripts
		elif [ -f "$current_path" ] && [ -r "$current_path" ]; then
			local wrapped_path
			wrapped_path=$(grep -oE '/nix/store/[^[:space:]"'\'']+' "$current_path" 2>/dev/null | head -1)
			if [ -n "$wrapped_path" ]; then
				current_path="$wrapped_path"
			else
				break
			fi
		else
			break
		fi
	done

	echo "Warning: Could not resolve to /nix/store path" >&2
	echo "$exec_path"
	return 1
}

# Command: noughty run (was nout)
cmd_run() {
	local use_unstable=false

	# Parse flags
	while [[ $# -gt 0 ]]; do
		case $1 in
		--unstable)
			use_unstable=true
			shift
			;;
		-h | --help)
			cat <<'EOF'
Usage: noughty run [--unstable] <package> [args...]

Run a single package from Nixpkgs in an isolated environment.

Options:
  --unstable         Use nixos-unstable channel instead of stable

Examples:
  noughty run hello
  noughty run --unstable git --version
EOF
			return 0
			;;
		-*)
			echo "Unknown option $1" >&2
			return 1
			;;
		*)
			break
			;;
		esac
	done

	if [ $# -eq 0 ]; then
		echo "Usage: noughty run [--unstable] <package> [args...]" >&2
		return 1
	fi

	local nixpkgs_channel
	if [ "$use_unstable" = true ]; then
		nixpkgs_channel="nixos-unstable"
	else
		nixpkgs_channel=$(get_stable_nixpkgs)
	fi

	local package_name="$1"
	shift

	# Get main program name
	local main_program
	echo "Determining main program for '$package_name' from '$nixpkgs_channel'..." >&2
	main_program=$(nix eval --impure "github:nixos/nixpkgs/$nixpkgs_channel#$package_name.meta.mainProgram" --raw 2>/dev/null || echo "$package_name")

	export NIXPKGS_ALLOW_UNFREE=1
	exec nom shell --impure "github:nixos/nixpkgs/${nixpkgs_channel}#${package_name}" --command "$main_program" "$@"
}

# Command: noughty shell (was nosh)
cmd_shell() {
	local use_unstable=false

	# Parse flags
	while [[ $# -gt 0 ]]; do
		case $1 in
		--unstable)
			use_unstable=true
			shift
			;;
		-h | --help)
			cat <<'EOF'
Usage: noughty shell [--unstable] <package1> [package2] ...

Spawn an interactive shell with multiple packages from Nixpkgs.

Options:
  --unstable         Use nixos-unstable channel instead of stable

Examples:
  noughty shell git vim
  noughty shell --unstable nodejs npm
EOF
			return 0
			;;
		-*)
			echo "Unknown option $1" >&2
			return 1
			;;
		*)
			break
			;;
		esac
	done

	if [ $# -eq 0 ]; then
		echo "Usage: noughty shell [--unstable] <package1> [package2] ..." >&2
		return 1
	fi

	local nixpkgs_channel
	if [ "$use_unstable" = true ]; then
		nixpkgs_channel="nixos-unstable"
	else
		nixpkgs_channel=$(get_stable_nixpkgs)
	fi

	local cmd="nom shell --impure"
	for pkg in "$@"; do
		cmd+=" github:nixos/nixpkgs/${nixpkgs_channel}#${pkg}"
	done

	export NIXPKGS_ALLOW_UNFREE=1
	exec $cmd
}

# Command: noughty channel (was norm)
cmd_channel() {
	get_stable_nixpkgs
}

# Command: noughty spawn (was nope)
cmd_spawn() {
	if [ $# -lt 1 ]; then
		echo "Usage: noughty spawn <program> [args...]" >&2
		echo "Launch a program detached from the current session" >&2
		return 1
	fi

	local program="$1"
	shift

	if ! command -v "$program" &>/dev/null; then
		echo "$program: is not in the PATH." >&2
		return 1
	fi

	setsid --fork "$program" "$@" &>/dev/null
}

# Command: noughty facts (alias: nofx)
cmd_facts() {
	# ANSI colour codes
	local dim='\033[2m'
	local bold='\033[1m'
	local reset='\033[0m'
	local cyan='\033[36m'
	local green='\033[32m'

	# Format a label-value pair; skip if value is empty or "none"
	print_field() {
		local label="$1"
		local value="$2"
		if [ -n "$value" ] && [ "$value" != "none" ]; then
			printf "  %s%-12s%s %s\n" "$dim" "$label" "$reset" "$value"
		fi
	}

	echo ""
	printf "  %s%snøughty%s %sfacts%s\n" "$cyan" "$bold" "$reset" "$dim" "$reset"
	echo ""

	# Identity
	printf "  %s%-12s%s %s%s%s\n" "$dim" "Host" "$reset" "$bold" "$NOUGHTY_HOST_NAME" "$reset"
	print_field "Kind" "$NOUGHTY_HOST_KIND"
	print_field "OS" "$NOUGHTY_HOST_OS ($NOUGHTY_HOST_PLATFORM)"
	print_field "Form" "$NOUGHTY_HOST_FORM_FACTOR"

	# Configuration
	print_field "Desktop" "$NOUGHTY_HOST_DESKTOP"
	if [ -n "$NOUGHTY_HOST_GPU_VENDORS" ]; then
		print_field "GPU" "${NOUGHTY_HOST_GPU_VENDORS// /, }"
	fi
	if [ -n "$NOUGHTY_HOST_TAGS" ]; then
		print_field "Tags" "${NOUGHTY_HOST_TAGS// /, }"
	fi

	echo ""

	# User
	print_field "User" "$NOUGHTY_USER_NAME"
	if [ -n "$NOUGHTY_USER_TAGS" ]; then
		print_field "User tags" "${NOUGHTY_USER_TAGS// /, }"
	fi
	print_field "Tailnet" "$NOUGHTY_NETWORK_TAILNET"

	# Display (only if configured)
	if [ -n "$NOUGHTY_HOST_DISPLAY_PRIMARY" ]; then
		echo ""
		if [ "$NOUGHTY_HOST_DISPLAY_MULTI" = "true" ]; then
			local outputs_formatted="${NOUGHTY_HOST_DISPLAY_OUTPUTS// /, }"
			print_field "Displays" "$outputs_formatted"
			print_field "Primary" "$NOUGHTY_HOST_DISPLAY_PRIMARY ($NOUGHTY_HOST_DISPLAY_RESOLUTION)"
		else
			print_field "Display" "$NOUGHTY_HOST_DISPLAY_PRIMARY ($NOUGHTY_HOST_DISPLAY_RESOLUTION)"
		fi
	fi

	# Active flags (compact line, only true values)
	local flags=""
	[ "$NOUGHTY_HOST_IS_WORKSTATION" = "true" ] && flags+="workstation, "
	[ "$NOUGHTY_HOST_IS_SERVER" = "true" ] && flags+="server, "
	[ "$NOUGHTY_HOST_IS_LAPTOP" = "true" ] && flags+="laptop, "
	[ "$NOUGHTY_HOST_IS_VM" = "true" ] && flags+="vm, "
	[ "$NOUGHTY_HOST_IS_ISO" = "true" ] && flags+="iso, "
	[ "$NOUGHTY_HOST_IS_DARWIN" = "true" ] && flags+="darwin, "
	[ "$NOUGHTY_HOST_IS_LINUX" = "true" ] && flags+="linux, "

	if [ -n "$flags" ]; then
		# Remove trailing ", "
		flags="${flags%, }"
		echo ""
		printf "  %s%-12s%s %s%s%s\n" "$dim" "Flags" "$reset" "$green" "$flags" "$reset"
	fi

	echo ""
}

# Main dispatcher
main() {
	if [ $# -eq 0 ]; then
		show_help
		exit 0
	fi

	case $1 in
	-h | --help | help)
		show_help
		exit 0
		;;
	path)
		shift
		cmd_path "$@"
		;;
	run)
		shift
		cmd_run "$@"
		;;
	shell)
		shift
		cmd_shell "$@"
		;;
	channel)
		shift
		cmd_channel "$@"
		;;
	spawn)
		shift
		cmd_spawn "$@"
		;;
	facts)
		shift
		cmd_facts "$@"
		;;
	*)
		echo "Unknown command: $1" >&2
		echo "Run 'noughty --help' for usage information." >&2
		exit 1
		;;
	esac
}

main "$@"
