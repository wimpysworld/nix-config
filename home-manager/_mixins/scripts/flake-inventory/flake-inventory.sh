#!/usr/bin/env bash

# flake-inventory: Discover flake outputs and emit GitHub Actions matrix outputs.
# Runs on ubuntu-latest during CI to enumerate all buildable outputs without
# deep evaluation, using lazy nix eval to avoid cross-platform failures.

set -euo pipefail

# --- Configuration ---
FLAKE_DIR="${FLAKE_INVENTORY_DIR:-.}"
VERBOSE="${FLAKE_INVENTORY_VERBOSE:-0}"
GITHUB_OUTPUT="${GITHUB_OUTPUT:-/dev/stdout}"

# Runner mapping: nix system → GitHub Actions runner.
RUNNER_MAP='{"aarch64-darwin":"macos-latest","x86_64-linux":"ubuntu-latest"}'

# Platforms to discover outputs for.
PLATFORMS=("x86_64-linux" "aarch64-darwin")

# --- Helper Functions ---

log_info() {
	echo "ℹ️  $*"
}

log_error() {
	echo "❌ $*" >&2
}

log_success() {
	echo "✅ $*"
}

log_debug() {
	if [ "${VERBOSE}" = "1" ]; then
		echo "🔍 $*"
	fi
}

# Discover attribute names for a given flake output path.
# Uses builtins.attrNames which is lazy (~50ms) and never deeply evaluates.
# Returns a JSON array of names, or an empty array on error.
discover_names() {
	local attr_path="$1"
	local result
	if result=$(nix eval "${FLAKE_DIR}#${attr_path}" \
		--apply builtins.attrNames --json --no-write-lock-file 2>/dev/null); then
		echo "${result}"
	else
		echo "[]"
	fi
}

# Look up the GitHub Actions runner for a given nix system string.
# Returns the runner name, or empty string if no mapping exists.
get_runner() {
	local system="$1"
	echo "${RUNNER_MAP}" | jq -r --arg s "${system}" '.[$s] // empty'
}

# Emit a single-line value to $GITHUB_OUTPUT.
emit_output() {
	local name="$1"
	local value="$2"
	echo "${name}=${value}" >>"${GITHUB_OUTPUT}"
}

# --- Discover All Outputs ---

log_info "Discovering flake outputs from ${FLAKE_DIR}..."

# ═══════════════════════════════════════════════════
# 1. DevShells & Formatter (per-platform matrix)
# ═══════════════════════════════════════════════════

log_info "Discovering devShells and formatters..."
devshells_json="[]"

for system in "${PLATFORMS[@]}"; do
	runner=$(get_runner "${system}")
	if [ -z "${runner}" ]; then
		log_debug "No runner mapping for ${system}, skipping"
		continue
	fi

	# Discover devShell names for this platform.
	shell_names=$(discover_names "devShells.${system}")
	has_shells=$(echo "${shell_names}" | jq 'length > 0')
	log_debug "devShells.${system}: ${shell_names}"

	# Check whether a formatter exists for this platform.
	has_formatter="false"
	if nix eval "${FLAKE_DIR}#formatter.${system}" --no-write-lock-file >/dev/null 2>&1; then
		has_formatter="true"
	fi
	log_debug "formatter.${system}: ${has_formatter}"

	if [ "${has_shells}" = "true" ] || [ "${has_formatter}" = "true" ]; then
		entry=$(jq -n -c \
			--arg system "${system}" \
			--arg runner "${runner}" \
			--argjson shells "${shell_names}" \
			--argjson formatter "${has_formatter}" \
			'{system: $system, runner: $runner, shells: $shells, formatter: $formatter}')
		devshells_json=$(echo "${devshells_json}" | jq -c --argjson e "${entry}" '. + [$e]')
	fi
done

devshells_count=$(echo "${devshells_json}" | jq 'length')
log_info "Found ${devshells_count} devShell platform(s)"

# ═══════════════════════════════════════════════════
# 2. Packages (per-platform matrix)
# ═══════════════════════════════════════════════════

log_info "Discovering packages..."
packages_json="[]"

for system in "${PLATFORMS[@]}"; do
	runner=$(get_runner "${system}")
	if [ -z "${runner}" ]; then
		continue
	fi

	pkg_names=$(discover_names "packages.${system}")
	pkg_count=$(echo "${pkg_names}" | jq 'length')
	log_debug "packages.${system}: ${pkg_count} package(s)"

	if [ "${pkg_count}" -gt 0 ]; then
		entry=$(jq -n -c \
			--arg system "${system}" \
			--arg runner "${runner}" \
			--argjson packages "${pkg_names}" \
			'{system: $system, runner: $runner, packages: $packages}')
		packages_json=$(echo "${packages_json}" | jq -c --argjson e "${entry}" '. + [$e]')
	fi
done

packages_count=$(echo "${packages_json}" | jq 'length')
log_info "Found ${packages_count} package platform(s)"

# ═══════════════════════════════════════════════════
# 3. System Configurations (needed for home pairing)
# ═══════════════════════════════════════════════════

log_info "Discovering system configurations..."

nixos_names=$(discover_names "nixosConfigurations")
darwin_names=$(discover_names "darwinConfigurations")
home_names=$(discover_names "homeConfigurations")

nixos_count=$(echo "${nixos_names}" | jq 'length')
darwin_count=$(echo "${darwin_names}" | jq 'length')
home_count=$(echo "${home_names}" | jq 'length')

log_info "Found ${nixos_count} nixosConfigurations"
log_info "Found ${darwin_count} darwinConfigurations"
log_info "Found ${home_count} homeConfigurations"

log_debug "nixosConfigurations: ${nixos_names}"
log_debug "darwinConfigurations: ${darwin_names}"
log_debug "homeConfigurations: ${home_names}"

# ═══════════════════════════════════════════════════
# 4. NixOS matrix (per-host, with paired home config)
# ═══════════════════════════════════════════════════

log_info "Building NixOS matrix..."
nixos_json="[]"
runner=$(get_runner "x86_64-linux")

while IFS= read -r name; do
	[ -z "${name}" ] && continue

	# Find the matching homeConfiguration (username@hostname pattern).
	home_match=$(echo "${home_names}" | jq -r --arg h "${name}" \
		'[.[] | select(endswith("@" + $h))] | first // empty')

	entry=$(jq -n -c \
		--arg name "${name}" \
		--arg runner "${runner}" \
		--arg home "${home_match}" \
		'{name: $name, runner: $runner, home: $home}')
	nixos_json=$(echo "${nixos_json}" | jq -c --argjson e "${entry}" '. + [$e]')

	log_debug "nixos: ${name} → home: ${home_match:-none}"
done < <(echo "${nixos_names}" | jq -r '.[]')

nixos_matrix_count=$(echo "${nixos_json}" | jq 'length')
log_info "NixOS matrix: ${nixos_matrix_count} host(s)"

# ═══════════════════════════════════════════════════
# 5. Darwin matrix (per-host, with paired home config)
# ═══════════════════════════════════════════════════

log_info "Building Darwin matrix..."
darwin_json="[]"
runner=$(get_runner "aarch64-darwin")

while IFS= read -r name; do
	[ -z "${name}" ] && continue

	# Find the matching homeConfiguration.
	home_match=$(echo "${home_names}" | jq -r --arg h "${name}" \
		'[.[] | select(endswith("@" + $h))] | first // empty')

	entry=$(jq -n -c \
		--arg name "${name}" \
		--arg runner "${runner}" \
		--arg home "${home_match}" \
		'{name: $name, runner: $runner, home: $home}')
	darwin_json=$(echo "${darwin_json}" | jq -c --argjson e "${entry}" '. + [$e]')

	log_debug "darwin: ${name} → home: ${home_match:-none}"
done < <(echo "${darwin_names}" | jq -r '.[]')

darwin_matrix_count=$(echo "${darwin_json}" | jq 'length')
log_info "Darwin matrix: ${darwin_matrix_count} host(s)"

# ═══════════════════════════════════════════════════
# 6. Orphan homeConfigurations (not paired with any system config)
#    These are lima, wsl, gaming types that only have Home Manager configs.
#    All are x86_64-linux in this flake.
# ═══════════════════════════════════════════════════

log_info "Discovering orphan homeConfigurations..."
orphan_homes_json="[]"

# Combine all system hostnames for cross-reference.
all_system_hosts=$(echo "${nixos_names} ${darwin_names}" | jq -s 'add')

while IFS= read -r home; do
	[ -z "${home}" ] && continue

	# Extract hostname from "user@hostname" format.
	hostname="${home#*@}"

	# Check whether this hostname belongs to a system configuration.
	is_paired=$(echo "${all_system_hosts}" | jq -r --arg h "${hostname}" \
		'if index($h) then "yes" else "no" end')

	if [ "${is_paired}" = "no" ]; then
		# Orphan home config; assume x86_64-linux (all lima/wsl/gaming are Linux).
		orphan_runner=$(get_runner "x86_64-linux")
		entry=$(jq -n -c \
			--arg name "${home}" \
			--arg runner "${orphan_runner}" \
			'{name: $name, runner: $runner}')
		orphan_homes_json=$(echo "${orphan_homes_json}" | jq -c --argjson e "${entry}" '. + [$e]')

		log_debug "orphan home: ${home}"
	fi
done < <(echo "${home_names}" | jq -r '.[]')

orphan_count=$(echo "${orphan_homes_json}" | jq 'length')
log_info "Orphan homeConfigurations: ${orphan_count}"

# ═══════════════════════════════════════════════════
# Emit GitHub Actions Outputs
# ═══════════════════════════════════════════════════

log_info "Emitting GitHub Actions outputs..."

# Matrix outputs (single-line JSON arrays).
emit_output "devshells" "${devshells_json}"
emit_output "packages" "${packages_json}"
emit_output "nixos" "${nixos_json}"
emit_output "darwin" "${darwin_json}"
emit_output "orphan_homes" "${orphan_homes_json}"

# Boolean guards to prevent empty-matrix failures in downstream jobs.
emit_output "has_devshells" "$(echo "${devshells_json}" | jq 'length > 0')"
emit_output "has_packages" "$(echo "${packages_json}" | jq 'length > 0')"
emit_output "has_nixos" "$(echo "${nixos_json}" | jq 'length > 0')"
emit_output "has_darwin" "$(echo "${darwin_json}" | jq 'length > 0')"
emit_output "has_orphan_homes" "$(echo "${orphan_homes_json}" | jq 'length > 0')"

# --- Summary ---

echo ""
echo "════════════════════════════════════════════════"
echo "  Inventory Summary"
echo "════════════════════════════════════════════════"
echo "  DevShell platforms:    ${devshells_count}"
echo "  Package platforms:     ${packages_count}"
echo "  NixOS hosts:           ${nixos_matrix_count}"
echo "  Darwin hosts:          ${darwin_matrix_count}"
echo "  Orphan homes:          ${orphan_count}"
echo "════════════════════════════════════════════════"
echo ""

log_debug "devshells=${devshells_json}"
log_debug "packages=${packages_json}"
log_debug "nixos=${nixos_json}"
log_debug "darwin=${darwin_json}"
log_debug "orphan_homes=${orphan_homes_json}"

log_success "Inventory complete!"
echo ""
