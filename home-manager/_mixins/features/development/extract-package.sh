#!/usr/bin/env bash
set -eu

# Extract an apk package to a directory of the same name as that package
PACKAGE_FILEPATH=${1:-}
if [ -z "${PACKAGE_FILEPATH}" ]; then
  echo "Usage: ${0} <package-file-path>"
  exit 1
fi

# create a directory to extract the package
extract_directory_name="${PACKAGE_FILEPATH%.apk}"
mkdir --parents "${extract_directory_name}"
tar --extract --verbose --gzip --file="${PACKAGE_FILEPATH}" --directory="${extract_directory_name}"
echo "Package extracted to ${extract_directory_name}"
