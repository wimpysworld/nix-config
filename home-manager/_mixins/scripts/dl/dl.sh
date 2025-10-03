#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

# checks if a URL is reachable
function web_check() {
    local HEADERS=()
    local URL="${1}"
    # Process any headers
    while (( "$#" )); do
        if [ "${1}" == "--header" ]; then
            HEADERS+=("${1}" "${2}")
            shift 2
        else
            shift
        fi
    done
    curl --disable --silent --location --head --output /dev/null --fail --connect-timeout 30 --max-time 30 --retry 3 "${HEADERS[@]}" "${URL}"
}

# checks if a URL needs to be redirected and returns the final URL
function web_redirect() {
    local REDIRECT_URL=""
    local URL="${1}"
    # Check for URL redirections
    # Output to nonexistent directory so the download fails fast
    REDIRECT_URL=$(curl --disable --silent --location --fail --write-out '%{url_effective}' --output /var/cache/${RANDOM}/${RANDOM} "${URL}" )
    if [ "${REDIRECT_URL}" != "${URL}" ]; then
        echo "${REDIRECT_URL}"
    else
        echo "${URL}"
    fi
}

# Download a file from the web
function web_get() {
    local DIR=""
    local FILE=""
    local HEADERS=()
    local URL="${1}"
    local USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"

    if [ -n "${2}" ]; then
        FILE="${2}"
        # Make sure the directory exists
        DIR="$(dirname "${FILE}")"
        if [ ! -d "${DIR}" ]; then
            mkdir -p "${DIR}"
        fi
    else
        FILE="${URL##*/}"
        DIR="$(pwd)"
    fi

    # Process any URL redirections after the file name has been extracted
    URL=$(web_redirect "${URL}")

    # Process any headers
    while (( "$#" )); do
        if [ "${1}" == "--header" ]; then
            HEADERS+=("${1}" "${2}")
            shift 2
        else
            shift
        fi
    done

    if ! curl --disable --progress-bar --location --output "${DIR}/${FILE}" --continue-at - --user-agent "${USER_AGENT}" "${HEADERS[@]}" -- "${URL}"; then
        echo "ERROR! Failed to download ${URL} with curl."
        rm -f "${DIR}/${FILE}"
    fi
}

if [ -n "${1}" ]; then
  web_get "${1}"
else
  echo "Usage: $(basename "${0}") <URL> [<FILE>]"
fi
