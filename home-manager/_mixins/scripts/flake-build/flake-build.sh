#!/usr/bin/env bash

# flake-build: Build all flake outputs for the current platform.
# Replaces flake-iter with direct Nix commands to avoid cross-platform
# evaluation failures.

set -euo pipefail

# --- Configuration ---
SYSTEM="${FLAKE_BUILD_SYSTEM:-}"
VERBOSE="${FLAKE_BUILD_VERBOSE:-0}"
FLAKE_DIR="${FLAKE_BUILD_DIR:-.}"
FAILED=()
BUILT=0

# --- Helper Functions ---

log_info() {
	echo "ℹ️  $*"
}

log_error() {
	echo "❌ $*" >&2
}

log_build() {
	echo "🔨 $*"
}

log_success() {
	echo "✅ $*"
}

# Discover attribute names for a given flake output path.
# Returns a JSON array of names, or an empty array on error.
discover_names() {
	local attr_path="$1"
	local result
	if result=$(nix eval "${FLAKE_DIR}#${attr_path}" --apply builtins.attrNames --json --no-write-lock-file 2>/dev/null); then
		echo "${result}"
	else
		echo "[]"
	fi
}

# Build a single flake output, tracking success and failure.
build_output() {
	local label="$1"
	local attr_path="$2"
	log_build "Building ${label} → ${attr_path}"
	if nix build "${FLAKE_DIR}#${attr_path}" --no-link -L; then
		log_success "Built ${label}"
		BUILT=$((BUILT + 1))
	else
		log_error "Failed to build ${label}"
		FAILED+=("${label}")
	fi
}

# --- System Detection ---

if [ -z "${SYSTEM}" ]; then
	log_info "FLAKE_BUILD_SYSTEM not set; detecting current system..."
	SYSTEM=$(nix eval --impure --expr 'builtins.currentSystem' --raw)
fi
log_info "Building for system: ${SYSTEM}"

if [ "${VERBOSE}" = "1" ]; then
	log_info "Verbose mode enabled"
	log_info "Flake directory: ${FLAKE_DIR}"
fi

# --- Platform Classification ---

IS_LINUX=0
IS_DARWIN=0

case "${SYSTEM}" in
*-linux)
	IS_LINUX=1
	;;
*-darwin)
	IS_DARWIN=1
	;;
*)
	log_error "Unsupported system: ${SYSTEM}"
	exit 1
	;;
esac

# --- Discover System Configurations ---
# We need these early so we can cross-reference homeConfigurations later.

NIXOS_NAMES="[]"
DARWIN_NAMES="[]"

if [ "${IS_LINUX}" = "1" ]; then
	log_info "Discovering nixosConfigurations..."
	NIXOS_NAMES=$(discover_names "nixosConfigurations")
	if [ "${VERBOSE}" = "1" ]; then
		log_info "nixosConfigurations: ${NIXOS_NAMES}"
	fi
fi

if [ "${IS_DARWIN}" = "1" ]; then
	log_info "Discovering darwinConfigurations..."
	DARWIN_NAMES=$(discover_names "darwinConfigurations")
	if [ "${VERBOSE}" = "1" ]; then
		log_info "darwinConfigurations: ${DARWIN_NAMES}"
	fi
fi

# --- Build System Configurations ---

if [ "${IS_LINUX}" = "1" ]; then
	mapfile -t nixos_list < <(echo "${NIXOS_NAMES}" | jq -r '.[]')
	log_info "Found ${#nixos_list[@]} nixosConfigurations"
	for name in "${nixos_list[@]}"; do
		[ -z "${name}" ] && continue
		build_output \
			"nixosConfigurations.${name}" \
			"nixosConfigurations.${name}.config.system.build.toplevel"
	done
fi

if [ "${IS_DARWIN}" = "1" ]; then
	mapfile -t darwin_list < <(echo "${DARWIN_NAMES}" | jq -r '.[]')
	log_info "Found ${#darwin_list[@]} darwinConfigurations"
	for name in "${darwin_list[@]}"; do
		[ -z "${name}" ] && continue
		build_output \
			"darwinConfigurations.${name}" \
			"darwinConfigurations.${name}.config.system.build.toplevel"
	done
fi

# --- Build HomeConfigurations (Platform-Filtered) ---

log_info "Discovering homeConfigurations..."
HOME_NAMES=$(discover_names "homeConfigurations")
if [ "${VERBOSE}" = "1" ]; then
	log_info "homeConfigurations: ${HOME_NAMES}"
fi

mapfile -t home_list < <(echo "${HOME_NAMES}" | jq -r '.[]')
log_info "Found ${#home_list[@]} homeConfigurations total"

for name in "${home_list[@]}"; do
	[ -z "${name}" ] && continue

	# Extract hostname from "user@hostname" format.
	hostname="${name#*@}"

	# Determine whether this homeConfiguration belongs to the current platform
	# by cross-referencing against the discovered system configurations.
	is_nixos=$(echo "${NIXOS_NAMES}" | jq -r --arg h "${hostname}" 'if index($h) then "yes" else "no" end')
	is_darwin=$(echo "${DARWIN_NAMES}" | jq -r --arg h "${hostname}" 'if index($h) then "yes" else "no" end')

	belongs_here=0
	if [ "${IS_LINUX}" = "1" ] && [ "${is_nixos}" = "yes" ]; then
		belongs_here=1
	elif [ "${IS_DARWIN}" = "1" ] && [ "${is_darwin}" = "yes" ]; then
		belongs_here=1
	elif [ "${is_nixos}" = "no" ] && [ "${is_darwin}" = "no" ]; then
		# Orphan configuration: hostname doesn't match any system config.
		# Evaluate its platform directly.
		log_info "Orphan homeConfiguration '${name}' - evaluating platform..."
		home_system=$(nix eval "${FLAKE_DIR}#homeConfigurations.\"${name}\".pkgs.stdenv.hostPlatform.system" --raw --no-write-lock-file 2>/dev/null || echo "unknown")
		if [ "${VERBOSE}" = "1" ]; then
			log_info "  → platform: ${home_system}"
		fi
		if [ "${home_system}" = "${SYSTEM}" ]; then
			belongs_here=1
		fi
	fi

	if [ "${belongs_here}" = "1" ]; then
		build_output \
			"homeConfigurations.\"${name}\"" \
			"homeConfigurations.\"${name}\".activationPackage"
	else
		if [ "${VERBOSE}" = "1" ]; then
			log_info "Skipping homeConfiguration '${name}' (not for ${SYSTEM})"
		fi
	fi
done

# --- Build Packages ---

log_info "Discovering packages.${SYSTEM}..."
PKG_NAMES=$(discover_names "packages.${SYSTEM}")
if [ "${VERBOSE}" = "1" ]; then
	log_info "packages.${SYSTEM}: ${PKG_NAMES}"
fi

mapfile -t pkg_list < <(echo "${PKG_NAMES}" | jq -r '.[]')
log_info "Found ${#pkg_list[@]} packages for ${SYSTEM}"

for name in "${pkg_list[@]}"; do
	[ -z "${name}" ] && continue
	build_output \
		"packages.${SYSTEM}.${name}" \
		"packages.${SYSTEM}.${name}"
done

# --- Build DevShells ---

log_info "Discovering devShells.${SYSTEM}..."
SHELL_NAMES=$(discover_names "devShells.${SYSTEM}")
if [ "${VERBOSE}" = "1" ]; then
	log_info "devShells.${SYSTEM}: ${SHELL_NAMES}"
fi

mapfile -t shell_list < <(echo "${SHELL_NAMES}" | jq -r '.[]')
log_info "Found ${#shell_list[@]} devShells for ${SYSTEM}"

for name in "${shell_list[@]}"; do
	[ -z "${name}" ] && continue
	build_output \
		"devShells.${SYSTEM}.${name}" \
		"devShells.${SYSTEM}.${name}"
done

# --- Build Formatter ---

log_info "Checking for formatter.${SYSTEM}..."
if nix eval "${FLAKE_DIR}#formatter.${SYSTEM}" --no-write-lock-file >/dev/null 2>&1; then
	build_output \
		"formatter.${SYSTEM}" \
		"formatter.${SYSTEM}"
else
	log_info "No formatter found for ${SYSTEM}"
fi

# --- Summary ---

echo ""
echo "════════════════════════════════════════════════"
echo "  Build Summary"
echo "════════════════════════════════════════════════"
echo "  System:    ${SYSTEM}"
echo "  Built:     ${BUILT}"
echo "  Failed:    ${#FAILED[@]}"
echo "════════════════════════════════════════════════"

if [ "${#FAILED[@]}" -gt 0 ]; then
	echo ""
	echo "  Failed outputs:"
	for f in "${FAILED[@]}"; do
		echo "    ✗ ${f}"
	done
	echo ""
	exit 1
else
	echo ""
	log_success "All outputs built successfully!"
	echo ""
fi
