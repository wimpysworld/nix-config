#!/bin/bash -eu

# Copy package from remote repo to local directory
# Similar to "wolfictl apk copy" but you don't need to know the package repository
# This currently only works for the latest version of the package or the versions
# that are in the same repository as the latest version
# Default values
PACKAGE_NAME=""
PACKAGE_VERSION="latest"
ARCH="x86_64"
EXTRACT_PACKAGE="false"
DOWNLOAD_SUBPAKCAGES="false"

usage() {
  echo "Usage: ${0} --package-name <package-name> [--package-version <package-version>] [--package-arch <arch>] [--extract-package] [--include-subpackages]"
}
bad_usage() {
  usage
  exit 1
}

if [ "$#" -eq 0 ]; then
  bad_usage
else
  # Parse flags
  while [ "$#" -gt 0 ]; do
      FLAG=${1:-}
      VALUE=${2:-}  # play nice with nounset
      case ${FLAG} in
          --package-name)
              if [[ -n "${VALUE}" ]]; then
                PACKAGE_NAME="${VALUE}";
                shift;
              else
                bad_usage
              fi;;
          --package-version)
              if [[ -n "${VALUE}" ]]; then
                PACKAGE_VERSION="${VALUE}";
                shift;
              else
                bad_usage
              fi;;
          --package-arch)
              if [[ -n "${VALUE}" ]]; then
                ARCH="${VALUE}";
                shift;
              else
                bad_usage
              fi;;
          --extract-package)
              EXTRACT_PACKAGE="true" ;;
          --include-subpackages)
              DOWNLOAD_SUBPAKCAGES="true" ;;
          --help|-h)
              usage; exit 0 ;;
          *)
              echo "${0##*/}: Unknown parameter: ${FLAG}"; bad_usage ;;
      esac
      shift
  done
  test -n "${PACKAGE_NAME}" || bad_usage
fi

OS_REPO_URL_BASE="https://packages.wolfi.dev/os/"
ENTERPRISE_REPO_URL_BASE="https://apk.cgr.dev/chainguard-private/"
EXTRA_REPO_URL_BASE="https://apk.cgr.dev/extra-packages/"

_download_package_version () {
    _PACKAGE_NAME=${1}
    _PACKAGE_VERSION=${2}
    _PACKAGE_URL=${3}
    _PACKAGE_FILENAME=${4}
    _EXTRACT_PACKAGE=${5}
    echo "Package Version: ${_PACKAGE_VERSION}"
    echo "Downloading package from ${_PACKAGE_URL}"
    if [[ "${_PACKAGE_URL}" == *"${OS_REPO_URL_BASE}"* ]]; then
        curl --location --output "${_PACKAGE_FILENAME}" "${_PACKAGE_URL}"
    else
        curl --location --user "user:$(chainctl auth token --audience apk.cgr.dev)" --output "${_PACKAGE_FILENAME}" "${_PACKAGE_URL}"
    fi

    if [ "${_EXTRACT_PACKAGE}" == "true" ]; then
      # create a directory to extract the package
      extract_directory_name="${_PACKAGE_NAME}-${_PACKAGE_VERSION}"
      mkdir --parents "${extract_directory_name}"
      tar -xvzf  "${_PACKAGE_FILENAME}" -C "${extract_directory_name}"
      echo "Package extracted to ${extract_directory_name}"
    fi
}

DOWNLOAD_SUBPAKCAGES_ARG=""
if [ "${DOWNLOAD_SUBPAKCAGES}" == "true" ]; then
    DOWNLOAD_SUBPAKCAGES_ARG="--show-sub-packages"
fi
# First find which repo the package is in and get the latest version if not provided
package_status_json=$(HTTP_AUTH=$(chainctl auth token --audience apk.cgr.dev) wolfi-package-status --all-versions ${DOWNLOAD_SUBPAKCAGES_ARG} --json "${PACKAGE_NAME}")
if [ "${PACKAGE_VERSION}" == "latest" ]; then
  # Find the version from the package_status_json with the last index as the versions are sorted ascending order
  package_repository=$(echo "${package_status_json}" | jq --raw-output ".[].versions | last | .Repository")
  PACKAGE_VERSION=$(echo "${package_status_json}" | jq --raw-output ".[].versions | last | .Version")
else
  # Find the version from the package_status_json where Version value is equal to ${PACKAGE_VERSION}
  package_repository=$(echo "${package_status_json}" | jq --raw-output ".[].versions[] | select(.Version == \"${PACKAGE_VERSION}\") | .Repository")
  if [ -z "${package_repository}" ]; then
    echo "Package version ${PACKAGE_VERSION} not found in any repository"
    exit 1
  fi
fi

echo "Latest origin package Repository: ${package_repository}"
REPO_URL_BASE=""
if [ "${package_repository}" == "wolfi os" ]; then
  REPO_URL_BASE=${OS_REPO_URL_BASE}
elif [ "${package_repository}" == "extra packages" ]; then
  REPO_URL_BASE=${EXTRA_REPO_URL_BASE}
elif [ "${package_repository}" == "enterprise packages" ]; then
  REPO_URL_BASE=${ENTERPRISE_REPO_URL_BASE}
fi
PACKAGE_FILENAME="${PACKAGE_NAME}-${PACKAGE_VERSION}.apk"
PACKAGE_URL="${REPO_URL_BASE}${ARCH}/${PACKAGE_FILENAME}"

_download_package_version "${PACKAGE_NAME}" "${PACKAGE_VERSION}" "${PACKAGE_URL}" "${PACKAGE_FILENAME}" "${EXTRACT_PACKAGE}"

if [ "${DOWNLOAD_SUBPAKCAGES}" == "true" ]; then
    echo "Downloading subpackages..."
    # redirect to dev/null and force true should there be no subpackages in the json
    SUBPAKCAGES=$(echo "${package_status_json}" | jq --raw-output ".[].subpackages[]" 2>/dev/null  || true )
    if [ -z "${SUBPAKCAGES}" ]; then
        echo "No subpackages found for ${PACKAGE_NAME}"
    else
      for SUBPACKAGE_NAME in ${SUBPAKCAGES}; do
          echo "Downloading subpackage ${SUBPACKAGE_NAME}..."
          SUBPACKAGE_FILENAME="${SUBPACKAGE_NAME}-${PACKAGE_VERSION}.apk"
          SUBPACKAGE_URL="${REPO_URL_BASE}${ARCH}/${SUBPACKAGE_FILENAME}"
          _download_package_version "${SUBPACKAGE_NAME}" "${PACKAGE_VERSION}" "${SUBPACKAGE_URL}" "${SUBPACKAGE_FILENAME}" "${EXTRACT_PACKAGE}"
      done
    fi
fi
