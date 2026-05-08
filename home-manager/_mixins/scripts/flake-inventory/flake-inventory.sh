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
RUNNER_MAP='{"x86_64-linux":"ubuntu-latest","aarch64-linux":"ubuntu-24.04-arm","aarch64-darwin":"macos-latest"}'

# Platforms to discover outputs for.
PLATFORMS=("x86_64-linux" "aarch64-linux" "aarch64-darwin")

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
# 4. NixOS matrix (per-host)
# ═══════════════════════════════════════════════════

log_info "Building NixOS matrix..."
nixos_json="[]"

while IFS= read -r name; do
	[ -z "${name}" ] && continue

	# Derive the platform from the configuration itself.
	host_system=$(nix eval "${FLAKE_DIR}#nixosConfigurations.${name}.pkgs.stdenv.hostPlatform.system" --raw --no-write-lock-file 2>/dev/null || echo "unknown")
	runner=$(get_runner "${host_system}")
	if [ -z "${runner}" ]; then
		log_debug "nixos: ${name} → platform ${host_system} has no runner, skipping"
		continue
	fi

	entry=$(jq -n -c \
		--arg name "${name}" \
		--arg runner "${runner}" \
		'{name: $name, runner: $runner}')
	nixos_json=$(echo "${nixos_json}" | jq -c --argjson e "${entry}" '. + [$e]')

	log_debug "nixos: ${name} → ${host_system} (${runner})"
done < <(echo "${nixos_names}" | jq -r '.[]')

nixos_matrix_count=$(echo "${nixos_json}" | jq 'length')
log_info "NixOS matrix: ${nixos_matrix_count} host(s)"

# ═══════════════════════════════════════════════════
# 5. Darwin matrix (per-host)
# ═══════════════════════════════════════════════════

log_info "Building Darwin matrix..."
darwin_json="[]"

while IFS= read -r name; do
	[ -z "${name}" ] && continue

	# Derive the platform from the configuration itself.
	host_system=$(nix eval "${FLAKE_DIR}#darwinConfigurations.${name}.pkgs.stdenv.hostPlatform.system" --raw --no-write-lock-file 2>/dev/null || echo "unknown")
	runner=$(get_runner "${host_system}")
	if [ -z "${runner}" ]; then
		log_debug "darwin: ${name} → platform ${host_system} has no runner, skipping"
		continue
	fi

	entry=$(jq -n -c \
		--arg name "${name}" \
		--arg runner "${runner}" \
		'{name: $name, runner: $runner}')
	darwin_json=$(echo "${darwin_json}" | jq -c --argjson e "${entry}" '. + [$e]')

	log_debug "darwin: ${name} → ${host_system} (${runner})"
done < <(echo "${darwin_names}" | jq -r '.[]')

darwin_matrix_count=$(echo "${darwin_json}" | jq 'length')
log_info "Darwin matrix: ${darwin_matrix_count} host(s)"

# ═══════════════════════════════════════════════════
# 6. Home Manager configurations
#    Run all Home Manager builds independently from NixOS and nix-darwin
#    builds so each configuration gets a fresh runner and Nix store.
# ═══════════════════════════════════════════════════

log_info "Building Home Manager matrix..."
homes_json="[]"

while IFS= read -r home; do
	[ -z "${home}" ] && continue

	home_system=$(nix eval "${FLAKE_DIR}#homeConfigurations.\"${home}\".pkgs.stdenv.hostPlatform.system" --raw --no-write-lock-file 2>/dev/null || echo "unknown")

	# Some cross-platform Home Manager configurations cannot expose their
	# hostPlatform cleanly from the Linux inventory runner. Fall back to the
	# paired system host when the home name follows the usual user@host shape.
	if [ "${home_system}" = "unknown" ] && [[ "${home}" == *@* ]]; then
		host="${home##*@}"
		if echo "${darwin_names}" | jq -e --arg host "${host}" 'index($host) != null' >/dev/null; then
			home_system=$(nix eval "${FLAKE_DIR}#darwinConfigurations.${host}.pkgs.stdenv.hostPlatform.system" --raw --no-write-lock-file 2>/dev/null || echo "unknown")
		elif echo "${nixos_names}" | jq -e --arg host "${host}" 'index($host) != null' >/dev/null; then
			home_system=$(nix eval "${FLAKE_DIR}#nixosConfigurations.${host}.pkgs.stdenv.hostPlatform.system" --raw --no-write-lock-file 2>/dev/null || echo "unknown")
		fi
	fi

	home_runner=$(get_runner "${home_system}")
	if [ -z "${home_runner}" ]; then
		log_debug "home: ${home} → platform ${home_system} has no runner, skipping"
		continue
	fi

	entry=$(jq -n -c \
		--arg name "${home}" \
		--arg runner "${home_runner}" \
		'{name: $name, runner: $runner}')
	homes_json=$(echo "${homes_json}" | jq -c --argjson e "${entry}" '. + [$e]')

	log_debug "home: ${home} → ${home_system} (${home_runner})"
done < <(echo "${home_names}" | jq -r '.[]')

homes_count=$(echo "${homes_json}" | jq 'length')
log_info "Home Manager matrix: ${homes_count} configuration(s)"

# ═══════════════════════════════════════════════════
# Emit GitHub Actions Outputs
# ═══════════════════════════════════════════════════

log_info "Emitting GitHub Actions outputs..."

# Matrix outputs (single-line JSON arrays).
emit_output "devshells" "${devshells_json}"
emit_output "packages" "${packages_json}"
emit_output "nixos" "${nixos_json}"
emit_output "darwin" "${darwin_json}"
emit_output "homes" "${homes_json}"

# Boolean guards to prevent empty-matrix failures in downstream jobs.
emit_output "has_devshells" "$(echo "${devshells_json}" | jq 'length > 0')"
emit_output "has_packages" "$(echo "${packages_json}" | jq 'length > 0')"
emit_output "has_nixos" "$(echo "${nixos_json}" | jq 'length > 0')"
emit_output "has_darwin" "$(echo "${darwin_json}" | jq 'length > 0')"
emit_output "has_homes" "$(echo "${homes_json}" | jq 'length > 0')"

# --- Summary ---

echo ""
echo "════════════════════════════════════════════════"
echo "  Inventory Summary"
echo "════════════════════════════════════════════════"
echo "  DevShell platforms:    ${devshells_count}"
echo "  Package platforms:     ${packages_count}"
echo "  NixOS hosts:           ${nixos_matrix_count}"
echo "  Darwin hosts:          ${darwin_matrix_count}"
echo "  Home configurations:   ${homes_count}"
echo "════════════════════════════════════════════════"
echo ""

log_debug "devshells=${devshells_json}"
log_debug "packages=${packages_json}"
log_debug "nixos=${nixos_json}"
log_debug "darwin=${darwin_json}"
log_debug "homes=${homes_json}"

log_success "Inventory complete!"
echo ""
