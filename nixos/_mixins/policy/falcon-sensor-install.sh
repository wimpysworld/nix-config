#!/usr/bin/env bash

# Automate the bootstrap and update process for CrowdStrike Falcon on NixOS.
# Downloads the sensor RPM from a private GitHub repository, extracts it,
# copies the binaries to /opt/CrowdStrike/, and patches all ELF binaries
# with the NixOS glibc interpreter.

REPO_FILE="/run/secrets/falcon-repo"
INSTALL_DIR="/opt/CrowdStrike"
VERSION=""
FORCE=0

function usage() {
	echo "Usage: $(basename "$0") [--version VERSION] [--force]"
	echo ""
	echo "Bootstrap or update the CrowdStrike Falcon sensor binaries on NixOS."
	echo ""
	echo "Options:"
	echo "  --version VERSION  Install a specific version (e.g. 7.29.0-18202)"
	echo "                     Default: latest release"
	echo "  --force            Install even if the same version is already running"
	echo ""
	echo "Must be run as root with GH_TOKEN or GITHUB_TOKEN set."
	echo "  sudo --preserve-env=GH_TOKEN falcon-sensor-install"
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
	--help | -h)
		usage
		;;
	*)
		echo "ERROR: Unknown argument: $1"
		usage
		;;
	esac
done

# Must run as root because we write to /opt/CrowdStrike/ and stop system services.
if [[ "$(id -u)" -ne 0 ]]; then
	echo "ERROR: This script must be run as root."
	echo "  sudo --preserve-env=GH_TOKEN falcon-sensor-install"
	exit 1
fi

# Read the private repository name from the sops-nix managed secret.
if [[ ! -f "${REPO_FILE}" ]]; then
	echo "ERROR: Repository secret not found at ${REPO_FILE}"
	echo "Add 'falcon-repo' to secrets/policy.yaml via sops."
	echo "  cd ~/Zero/nix-config && sops secrets/policy.yaml"
	exit 1
fi
REPO="$(cat "${REPO_FILE}")"

# gh CLI requires authentication. When running under sudo, environment
# variables are stripped by default. Pass GH_TOKEN explicitly if needed:
#   sudo --preserve-env=GH_TOKEN falcon-sensor-install
if [[ -z "${GH_TOKEN:-}" && -n "${GITHUB_TOKEN:-}" ]]; then
	export GH_TOKEN="${GITHUB_TOKEN}"
fi

if [[ -z "${GH_TOKEN:-}" && -z "${GITHUB_TOKEN:-}" ]]; then
	echo "ERROR: No GitHub authentication token found."
	echo ""
	echo "The gh CLI requires GH_TOKEN or GITHUB_TOKEN to authenticate."
	echo "When running under sudo, environment variables are stripped."
	echo ""
	echo "Run with:"
	echo "  sudo GH_TOKEN=\$GH_TOKEN falcon-sensor-install"
	echo ""
	echo "Or use --preserve-env:"
	echo "  sudo --preserve-env=GH_TOKEN falcon-sensor-install"
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
	# Strip the leading 'v' to get the version number.
	VERSION="${LATEST_TAG#v}"
	echo "Latest release: ${LATEST_TAG} (version ${VERSION})"
else
	LATEST_TAG="v${VERSION}"
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

# Create a temporary working directory and arrange cleanup on exit.
WORK_DIR=$(mktemp -d --tmpdir falcon-sensor-install.XXXXXXXXXX)
function cleanup() {
	echo "Cleaning up temporary files..."
	rm -rf "${WORK_DIR}"
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

# Stop the falcon-sensor service if it is running.
echo "Stopping falcon-sensor service (if running)..."
systemctl stop falcon-sensor 2>/dev/null || true

# Copy binaries to /opt/CrowdStrike/.
echo "Installing sensor binaries to ${INSTALL_DIR}..."
mkdir -p "${INSTALL_DIR}"
cp -r "${SENSOR_DIR}/." "${INSTALL_DIR}/"
chown -R root:root "${INSTALL_DIR}"
chmod -R 0750 "${INSTALL_DIR}"

# Patch all ELF binaries with the NixOS glibc interpreter.
# NixOS does not have /lib/ld-linux-*.so.1 in the standard location, so all
# dynamically linked binaries need their interpreter set to the Nix store path.
echo "Patching ELF binaries with NixOS interpreter..."
INTERP=$(patchelf --print-interpreter "$(command -v bash)")
PATCHED=0
SKIPPED=0
for binary in "${INSTALL_DIR}"/*; do
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
echo ""
echo "===================================="
echo " Falcon sensor ${VERSION} installed"
echo "===================================="
echo ""
echo "Binaries installed to: ${INSTALL_DIR}"
echo "Architecture: ${RPM_ARCH}"
echo ""
echo "Next steps:"
echo "  Start the service:"
echo "    sudo systemctl start falcon-sensor"
echo ""
echo "  Or rebuild and switch the full configuration:"
echo "    just switch"
echo ""
echo "  Verify the installation:"
echo "    sudo /opt/CrowdStrike/falconctl -g --cid --aid --version"
echo "    systemctl status falcon-sensor"
