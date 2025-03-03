#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

# Base URL for Magewell downloads
BASE_URL="https://www.magewell.com/files/drivers/ProCaptureForLinux"
#START_VERSION=4390
#START_VERSION=4407
START_VERSION=4418
END_VERSION=$((START_VERSION + 100))

# Function to check if URL exists using curl
check_url() {
    local url=$1
    local version=$2
    local http_code=""

    # Use curl with --head to only get headers
    # -s for silent mode, -L to follow redirects, -w for custom output format
    # -o /dev/null to discard the actual content
    http_code=$(curl -s -L -w "%{http_code}" --head "$url" -o /dev/null)

    if [ "$http_code" = "200" ]; then
        echo "✅ Version $version is available at: $url"
    else
        echo "❌ Version $version not found at: $url"
    fi
    # Add a small delay to be nice to the server
    sleep 0.5
}

echo "Starting version check from $START_VERSION to $END_VERSION"
echo "Results will be saved to found_versions.txt"
echo "----------------------------------------"

# Main loop
for version in $(seq $START_VERSION $END_VERSION); do
    if [ "$version" -le 4407 ]; then
        url="${BASE_URL}_${version}.tar.gz"
    else
        url="${BASE_URL}_1.3.${version}.tar.gz"
    fi
    check_url "$url" "$version"
done

echo "----------------------------------------"
echo "Scan complete! Available versions have been saved to found_versions.txt"
