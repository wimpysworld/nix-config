#!/usr/bin/env bash

# Automate the bootstrap and update process for CrowdStrike Falcon on NixOS.
# Downloads the sensor RPM from a private GitHub repository, extracts it,
# copies the binaries to /opt/CrowdStrike/, and patches all ELF binaries
# with the NixOS glibc interpreter.

REPO_FILE="/run/secrets/falcon-repo"
INSTALL_DIR="/opt/CrowdStrike"
STAGE_DIR="/opt/CrowdStrike.staged"
TAG_PREFIX="falcon-v"
VERSION_PATTERN='[0-9]+\.[0-9]+\.[0-9]+-[0-9]+'
VERSION=""
FORCE=0
DIRECT=0

function usage() {
	echo "Usage: $(basename "$0") [--version VERSION] [--force] [--direct]"
	echo ""
	echo "Bootstrap or update the CrowdStrike Falcon sensor binaries on NixOS."
	echo ""
	echo "When the sensor is running, the update is staged in ${STAGE_DIR}"
	echo "and applied at the next boot, before the sensor starts. When no"
	echo "sensor is running, the binaries are installed in place."
	echo ""
	echo "Options:"
	echo "  --version VERSION  Install a specific version (e.g. 7.29.0-18202)"
	echo "                     Default: latest release"
	echo "  --force            Install even if the same version is already running"
	echo "  --direct           Force an in-place install even while the sensor"
	echo "                     runs, for example after disarming maintenance"
	echo "                     protection with the maintenance token"
	echo ""
	echo "Elevates itself with sudo and takes the GitHub token from your gh"
	echo "session automatically. Authenticate once with: gh auth login"
	exit 1
}

# Parse arguments.
while [[ $# -gt 0 ]]; do
	case "$1" in
	--version)
		if [[ -z "${2:-}" ]]; then
			echo "ERROR: --version requires a value."
			exit 1
		fi
		VERSION="$2"
		shift 2
		;;
	--force)
		FORCE=1
		shift
		;;
	--direct)
		DIRECT=1
		shift
		;;
	--help | -h)
		usage
		;;
	*)
		echo "ERROR: Unknown argument: $1"
		usage
		;;
	esac
done

# Root is required to write to /opt/CrowdStrike/ and stop system services.
# Self-elevate: capture the invoking user's GitHub token from the gh
# keyring while still unprivileged (the keyring is not readable as root),
# then re-exec under sudo with the token preserved.
if [[ "$(id -u)" -ne 0 ]]; then
	if [[ -z "${GH_TOKEN:-}" && -z "${GITHUB_TOKEN:-}" ]]; then
		GH_TOKEN="$(gh auth token 2>/dev/null || true)"
		export GH_TOKEN
	fi
	if [[ -z "${GH_TOKEN:-}" && -z "${GITHUB_TOKEN:-}" ]]; then
		echo "ERROR: No GitHub token available."
		echo "Authenticate the gh CLI first:"
		echo "  gh auth login"
		exit 1
	fi
	echo "Elevating with sudo..."
	exec sudo --preserve-env=GH_TOKEN,GITHUB_TOKEN "$0" "$@"
fi

# Decide between a staged update and a direct install. A running sensor
# must not be disrupted, and an armed one cannot be stopped, so the update
# is staged in the staging directory and a boot-time oneshot
# (falcon-sensor-staged-update.service) applies it before the sensor
# starts. With no sensor running, the binaries are installed in place.
# --direct forces an in-place install, for example after disarming
# maintenance protection with the maintenance token.
STAGE=0
TARGET_DIR="${INSTALL_DIR}"
if [[ "${DIRECT}" -eq 0 ]] && pgrep -x falcond >/dev/null; then
	STAGE=1
	TARGET_DIR="${STAGE_DIR}"
	echo "Falcon sensor is running; the update will be staged and applied at the next boot."
fi

# Read the private repository name from the sops-nix managed secret.
if [[ ! -f "${REPO_FILE}" ]]; then
	echo "ERROR: Repository secret not found at ${REPO_FILE}"
	echo "Add 'falcon-repo' to secrets/policy.yaml via sops."
	echo "  cd ~/Zero/nix-config && sops secrets/policy.yaml"
	exit 1
fi
REPO="$(cat "${REPO_FILE}")"

# The gh CLI requires authentication. Self-elevation above carries the
# token across sudo; this fallback covers invocations from a root shell.
if [[ -z "${GH_TOKEN:-}" && -n "${GITHUB_TOKEN:-}" ]]; then
	export GH_TOKEN="${GITHUB_TOKEN}"
fi

if [[ -z "${GH_TOKEN:-}" && -z "${GITHUB_TOKEN:-}" ]]; then
	echo "ERROR: No GitHub authentication token found."
	echo ""
	echo "Run this script as your own user; it elevates itself and takes the"
	echo "token from your gh session. From a root shell, pass one explicitly:"
	echo "  GH_TOKEN=<token> falcon-sensor-install"
	exit 1
fi

# Detect architecture and map to the RPM filename pattern.
ARCH="$(uname -m)"
case "${ARCH}" in
x86_64)
	RPM_ARCH="x86_64"
	;;
aarch64)
	RPM_ARCH="aarch64"
	;;
*)
	echo "ERROR: Unsupported architecture: ${ARCH}"
	exit 1
	;;
esac

# Determine which version to install.
LATEST_TAG=""
if [[ -z "${VERSION}" ]]; then
	echo "Querying latest release from ${REPO}..."
	# Use --json for reliable structured output instead of parsing tab-separated text.
	LATEST_TAG=$(gh release list --repo "${REPO}" --limit 10 --json tagName,isLatest |
		jq -r '[.[] | select(.isLatest)] | first | .tagName // empty')
	if [[ -z "${LATEST_TAG}" ]]; then
		# Fall back to the most recent tag if none is marked latest.
		LATEST_TAG=$(gh release list --repo "${REPO}" --limit 1 --json tagName |
			jq -r 'first | .tagName // empty')
	fi
	if [[ -z "${LATEST_TAG}" ]]; then
		echo "ERROR: Could not determine the latest release tag."
		echo "Check your gh CLI authentication and access to ${REPO}."
		exit 1
	fi
	if [[ ! "${LATEST_TAG}" =~ ^${TAG_PREFIX}${VERSION_PATTERN}$ ]]; then
		echo "ERROR: Unexpected release tag format: ${LATEST_TAG}"
		echo "Expected ${TAG_PREFIX}MAJOR.MINOR.PATCH-BUILD."
		exit 1
	fi
	VERSION="${LATEST_TAG#"${TAG_PREFIX}"}"
	echo "Latest release: ${LATEST_TAG} (version ${VERSION})"
fi

if [[ ! "${VERSION}" =~ ^${VERSION_PATTERN}$ ]]; then
	echo "ERROR: Invalid version: ${VERSION}"
	echo "Expected MAJOR.MINOR.PATCH-BUILD (for example, 7.29.0-18202)."
	exit 1
fi

if [[ -z "${LATEST_TAG}" ]]; then
	LATEST_TAG="${TAG_PREFIX}${VERSION}"
	echo "Using specified version: ${VERSION} (tag ${LATEST_TAG})"
fi

RPM_FILENAME="falcon-sensor-${VERSION}.el10.${RPM_ARCH}.rpm"
echo "RPM filename: ${RPM_FILENAME}"

# Check if the target version is already installed.
if [[ -x "${INSTALL_DIR}/falconctl" ]]; then
	INSTALLED_VERSION=$("${INSTALL_DIR}/falconctl" -g --version 2>&1) || true
	# Extract the version number from output like: version = 7.29.18202.0
	INSTALLED_VERSION=$(echo "${INSTALLED_VERSION}" | grep -oP 'version = \K[0-9.]+' || true)
	if [[ -n "${INSTALLED_VERSION}" ]]; then
		# Convert target version (7.29.0-18202) to falconctl format (7.29.18202.0).
		# The RPM version is MAJOR.MINOR.PATCH-BUILD; falconctl reports MAJOR.MINOR.BUILD.PATCH.
		TARGET_COMPARABLE="${VERSION}"
		IFS='.-' read -r T_MAJOR T_MINOR T_PATCH T_BUILD <<<"${TARGET_COMPARABLE}"
		TARGET_NORMALISED="${T_MAJOR}.${T_MINOR}.${T_BUILD}.${T_PATCH}"

		echo "Installed version: ${INSTALLED_VERSION}"
		echo "Available version: ${TARGET_NORMALISED}"

		if [[ "${INSTALLED_VERSION}" == "${TARGET_NORMALISED}" ]]; then
			if [[ "${FORCE}" -eq 1 ]]; then
				echo "Same version already installed, but --force was specified."
			else
				echo ""
				echo "Falcon sensor ${INSTALLED_VERSION} is already installed and up to date."
				echo "Use --force to reinstall the same version."
				exit 0
			fi
		else
			echo "Version differs, proceeding with install."
		fi
	else
		echo "Unable to determine installed version, proceeding with install."
	fi
else
	echo "Falcon sensor not found, proceeding with fresh install."
fi

# Sensor 7.38+ arms maintenance (tamper) protection while it runs. An armed
# sensor blocks kill signals (even from systemd) and write access to
# /opt/CrowdStrike (even for root), so an in-place update is impossible.
# Refuse early with instructions rather than fail part-way through the copy.
# Staging is unaffected: it writes only to the staging directory, which the
# sensor does not protect.
if [[ "${STAGE}" -eq 0 && -x "${INSTALL_DIR}/falconctl" ]]; then
	PROTECTION_STATUS=$("${INSTALL_DIR}/falconctl" -g --protection-status 2>/dev/null | grep -i 'Maintenance Protection' || true)
	if [[ "${PROTECTION_STATUS,,}" == *"armed=true"* ]]; then
		echo "ERROR: Sensor maintenance protection is armed:"
		echo "  ${PROTECTION_STATUS}"
		echo ""
		echo "An armed sensor cannot be stopped or updated in place. Either:"
		echo "  1. Re-run without --direct to stage the update; it is applied"
		echo "     at the next boot:"
		echo "       falcon-sensor-install"
		echo "  2. Disarm it with the per-host maintenance token from infosec,"
		echo "     then re-run with --direct:"
		echo "       sudo ${INSTALL_DIR}/falconctl -s --maintenance-token"
		echo "       falcon-sensor-install --direct"
		exit 1
	fi
fi

# Create a temporary working directory and arrange cleanup on exit.
WORK_DIR=$(mktemp -d --tmpdir falcon-sensor-install.XXXXXXXXXX)
function cleanup() {
	local status=$?
	echo "Cleaning up temporary files..."
	rm -rf "${WORK_DIR}"
	if [[ "${status}" -ne 0 ]]; then
		echo ""
		echo "ERROR: Installation did not complete (exit ${status})."
		echo "Check the messages above; ${TARGET_DIR} may be unchanged or incomplete."
	fi
}
trap cleanup EXIT

# Download the RPM.
echo "Downloading ${RPM_FILENAME} from ${REPO} release ${LATEST_TAG}..."
gh release download "${LATEST_TAG}" \
	--repo "${REPO}" \
	--pattern "${RPM_FILENAME}" \
	--dir "${WORK_DIR}"

RPM_PATH="${WORK_DIR}/${RPM_FILENAME}"
if [[ ! -f "${RPM_PATH}" ]]; then
	echo "ERROR: Download failed. ${RPM_PATH} not found."
	echo "Check the release tag (${LATEST_TAG}) and RPM filename (${RPM_FILENAME})."
	exit 1
fi
echo "Downloaded: ${RPM_PATH}"

# Extract the RPM contents.
echo "Extracting RPM..."
EXTRACT_DIR="${WORK_DIR}/extracted"
mkdir -p "${EXTRACT_DIR}"
rpm2cpio "${RPM_PATH}" | cpio -idm --quiet --directory="${EXTRACT_DIR}"

# Verify the expected directory structure exists.
SENSOR_DIR="${EXTRACT_DIR}/opt/CrowdStrike"
if [[ ! -d "${SENSOR_DIR}" ]]; then
	echo "ERROR: Expected directory opt/CrowdStrike/ not found in RPM."
	echo "Contents of extraction:"
	ls -la "${EXTRACT_DIR}"
	exit 1
fi

if [[ "${STAGE}" -eq 0 ]]; then
	# Stop the falcon-sensor service if it is running.
	echo "Stopping falcon-sensor service (if running)..."
	systemctl stop falcon-sensor 2>/dev/null || true

	# Verify the sensor processes actually exited. Tamper protection can
	# leave falcond running after a "successful" systemctl stop, and copying
	# over binaries that are still executing fails part-way through.
	for _ in $(seq 1 30); do
		pgrep -x falcond >/dev/null || break
		sleep 1
	done
	if pgrep -x falcond >/dev/null; then
		echo "ERROR: falcond is still running after systemctl stop."
		echo "The sensor processes survived the stop request, so ${INSTALL_DIR} is not safe to modify."
		echo "Re-run this script to stage the update instead, reboot the host,"
		echo "or disarm maintenance protection first."
		exit 1
	fi
else
	# Discard any previous stage so the staging directory only ever holds
	# one complete, freshly patched tree.
	rm -rf "${STAGE_DIR}"
fi

# Copy binaries to the target directory.
echo "Installing sensor binaries to ${TARGET_DIR}..."
mkdir -p "${TARGET_DIR}"
cp -r "${SENSOR_DIR}/." "${TARGET_DIR}/"
chown -R root:root "${TARGET_DIR}"
chmod -R 0750 "${TARGET_DIR}"

# Patch all ELF binaries with the NixOS glibc interpreter.
# NixOS does not have /lib/ld-linux-*.so.1 in the standard location, so all
# dynamically linked binaries need their interpreter set to the Nix store path.
echo "Patching ELF binaries with NixOS interpreter..."
INTERP=$(patchelf --print-interpreter "$(command -v bash)")
PATCHED=0
SKIPPED=0
for binary in "${TARGET_DIR}"/*; do
	if [[ -x "${binary}" && -f "${binary}" ]]; then
		if patchelf --set-interpreter "${INTERP}" "${binary}" 2>/dev/null; then
			PATCHED=$((PATCHED + 1))
		else
			SKIPPED=$((SKIPPED + 1))
		fi
	fi
done
echo "Patched ${PATCHED} binaries, skipped ${SKIPPED} (non-ELF or static)."

# Summary and next steps.
if [[ "${STAGE}" -eq 1 ]]; then
	# Mark the stage as complete only after patching, so the boot-time
	# oneshot never applies a partially prepared tree.
	echo "${VERSION}" >"${STAGE_DIR}/.staged-version"
	touch "${STAGE_DIR}/.stage-complete"
	echo ""
	echo "===================================="
	echo " Falcon sensor ${VERSION} staged"
	echo "===================================="
	echo ""
	echo "Staged to: ${STAGE_DIR}"
	echo "Architecture: ${RPM_ARCH}"
	echo ""
	echo "The update is applied automatically at the next boot, before the"
	echo "sensor starts. Reboot whenever convenient, then verify with:"
	echo "    falcon-sensor-check"
else
	echo ""
	echo "===================================="
	echo " Falcon sensor ${VERSION} installed"
	echo "===================================="
	echo ""
	echo "Binaries installed to: ${INSTALL_DIR}"
	echo "Architecture: ${RPM_ARCH}"
	echo ""
	# Start the service when this host defines it. On a host that has not
	# enabled the module yet, leave startup to the first rebuild.
	if systemctl cat falcon-sensor.service >/dev/null 2>&1; then
		echo "Starting falcon-sensor.service..."
		if systemctl start falcon-sensor.service; then
			STATE=$(systemctl is-active falcon-sensor.service || true)
			echo "falcon-sensor.service is ${STATE}."
			echo "Verify with: falcon-sensor-check"
		else
			echo "WARNING: falcon-sensor.service failed to start."
			echo "Inspect with: journalctl -u falcon-sensor"
		fi
	else
		echo "falcon-sensor.service is not defined on this host yet."
		echo "Enable the policy module and rebuild: just switch"
	fi
fi
