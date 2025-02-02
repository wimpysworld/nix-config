#!/usr/bin/env bash

set +e  # Disable errexit
set +u  # Disable nounset
set +o pipefail  # Disable pipefail

IS_NUM='^[0-9]+$'
BRIGHT=""
COLOR=""

HOST="$(hostnamectl hostname)"
if [[ "${HOST}" != *"vader"* ]]; then
  exit
fi

function make_json() {
    if [ -n "${BRIGHT}" ] && [ -n "${COLOR}" ]; then
        cat <<EOF
{"numberOfLights":1,"lights":[{"on":${POWER},"brightness":${BRIGHT},"temperature":${COLOR}}]}
EOF
    elif [ -n "${BRIGHT}" ] && [ -z "${COLOR}" ]; then
        cat <<EOF
{"numberOfLights":1,"lights":[{"on":${POWER},"brightness":${BRIGHT}}]}
EOF
    elif [ -z "${BRIGHT}" ] && [ -n "${COLOR}" ]; then
        cat <<EOF
{"numberOfLights":1,"lights":[{"on":${POWER},"temperature":${COLOR}}]}
EOF
    else
        cat <<EOF
{"numberOfLights":1,"lights":[{"on":${POWER}}]}
EOF
    fi
}

function get_json() {
    for LIGHT in 20 21; do
        echo "${LIGHT}:"
        curl --silent --location --request GET "http://10.10.10.${LIGHT}:9123/elgato/lights" | jq .
    done
    exit
}

function put_json() {
    for LIGHT in 20 21; do
        echo "${LIGHT}:"
        curl --silent --location --request PUT "http://10.10.10.${LIGHT}:9123/elgato/lights" \
            --header "Content-Type: application/json" \
            --data-raw "$(make_json)"
        echo
    done
}

function get_info() {
  for LIGHT in left right; do
    curl --silent --request GET "http://10.10.10.${LIGHT}:9123/elgato/accessory-info" | jq .
  done
  exit
}

case ${1} in
    default) POWER=1
             BRIGHT=15
             COLOR=144
             ;;
    get) get_json;;
    info) get_info;;
    1|on|ON) POWER=1;;
    *) POWER=0;;
esac

if [ -n "${2}" ]; then
    BRIGHT="${2}"
    if ! [[ ${2} =~ ${IS_NUM} ]]; then
        echo "ERROR! Brightness must be a number between 3 and 100"
        exit 1
    fi

    if [ "${BRIGHT}" -lt 2 ]; then
        BRIGHT=2
    elif [ "${BRIGHT}" -gt 100 ]; then
        BRIGHT=100
    fi
fi

# The actual range is 143 to 344
# So present this as a simple 1 to 200 scale
if [ -n "${3}" ]; then
    COLOR="${3}"
    if ! [[ ${3} =~ ${IS_NUM} ]]; then
        echo "ERROR! Color must be a number between 1 and 200"
        exit 1
    fi

    if [ "${COLOR}" -lt 0 ]; then
        COLOR=0
    elif [ "${COLOR}" -gt 200 ]; then
        COLOR=200
    fi
    COLOR=$((COLOR + 144))
fi

put_json
