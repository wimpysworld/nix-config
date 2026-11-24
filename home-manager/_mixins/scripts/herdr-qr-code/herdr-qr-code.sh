#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="${HERDR_QR_REPO_ROOT:-${HOME}/Zero/nix-config}"
SECRETS_FILE="${REPO_ROOT}/secrets/roamgate.yaml"

usage() {
	echo "Usage: herdr-qr-code [--sync | --rotate]"
	echo ""
	echo "  (default)  Verify Tinyauth TOTP alignment and display the QR code"
	echo "  --sync     Re-hash ROAMGATE_PASSWORD with the existing TOTP secret"
	echo "  --rotate   Generate a fresh TOTP secret and re-hash ROAMGATE_PASSWORD"
}

mode="show"
if [[ $# -gt 1 ]]; then
	usage >&2
	exit 1
elif [[ $# -eq 1 ]]; then
	case "$1" in
	--sync)
		mode="sync"
		;;
	--rotate)
		mode="rotate"
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		usage >&2
		exit 1
		;;
	esac
fi

if [[ ! -f "${SECRETS_FILE}" ]]; then
	echo "ERROR: ${SECRETS_FILE} not found." >&2
	exit 1
fi

extract_uri_secret() {
	printf '%s' "$1" | sed -n 's/.*[?&]secret=\([^&]*\).*/\1/p'
}

strip_ansi() {
	sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g'
}

hash_password() {
	local password="$1"
	local raw_output
	raw_output="$(tinyauth user create --username martin --password "${password}")"
	printf '%s\n' "${raw_output}" \
		| strip_ansi \
		| grep -oE 'martin:[$]2[aby][$][0-9]{2}[$][./A-Za-z0-9]{53}' \
		| head -n1
}

validate_tinyauth_users() {
	local users_value="$1"
	TINYAUTH_AUTH_USERS="${users_value}" \
		TINYAUTH_APPURL="https://auth-skrye.wimpys.world" \
		tinyauth config >/dev/null
}

show_qr() {
	local uri="$1"
	echo "Scan this QR code in your authenticator app:"
	echo ""
	printf '%s' "${uri}" | qrencode -t ANSIUTF8
}

case "${mode}" in
show)
	totp_uri="$(sops -d --extract '["TINYAUTH_TOTP_URI"]' "${SECRETS_FILE}")"
	auth_users="$(sops -d --extract '["TINYAUTH_AUTH_USERS"]' "${SECRETS_FILE}")"
	uri_secret="$(extract_uri_secret "${totp_uri}")"
	users_secret="${auth_users##*:}"

	if [[ -z "${uri_secret}" ]]; then
		echo "ERROR: Could not extract secret from TINYAUTH_TOTP_URI." >&2
		exit 1
	fi

	if ! validate_tinyauth_users "${auth_users}"; then
		echo "WARNING: TINYAUTH_AUTH_USERS failed tinyauth config validation. Run: herdr-qr-code --sync" >&2
	elif [[ "${users_secret}" != "${uri_secret}" ]]; then
		echo "WARNING: TINYAUTH_AUTH_USERS TOTP secret does not match TINYAUTH_TOTP_URI. Run: herdr-qr-code --sync" >&2
	else
		echo "OK: TINYAUTH_AUTH_USERS matches TINYAUTH_TOTP_URI."
	fi

	echo ""
	show_qr "${totp_uri}"
	;;

sync)
	password="$(sops -d --extract '["ROAMGATE_PASSWORD"]' "${SECRETS_FILE}")"
	totp_uri="$(sops -d --extract '["TINYAUTH_TOTP_URI"]' "${SECRETS_FILE}")"
	uri_secret="$(extract_uri_secret "${totp_uri}")"

	if [[ -z "${password}" ]]; then
		echo "ERROR: ROAMGATE_PASSWORD is empty in ${SECRETS_FILE}." >&2
		exit 1
	fi
	if [[ -z "${uri_secret}" ]]; then
		echo "ERROR: Could not extract secret from TINYAUTH_TOTP_URI." >&2
		exit 1
	fi

	user_hash="$(hash_password "${password}")"
	if [[ -z "${user_hash}" ]]; then
		echo "ERROR: Failed to generate Tinyauth bcrypt hash." >&2
		exit 1
	fi

	auth_users="${user_hash}:${uri_secret}"
	validate_tinyauth_users "${auth_users}"

	printf '%s' "${auth_users}" \
		| jq -Rs . \
		| sops set --value-stdin "${SECRETS_FILE}" '["TINYAUTH_AUTH_USERS"]'

	echo "Updated TINYAUTH_AUTH_USERS in ${SECRETS_FILE}."
	echo ""
	show_qr "${totp_uri}"
	;;

rotate)
	password="$(sops -d --extract '["ROAMGATE_PASSWORD"]' "${SECRETS_FILE}")"
	if [[ -z "${password}" ]]; then
		echo "ERROR: ROAMGATE_PASSWORD is empty in ${SECRETS_FILE}." >&2
		exit 1
	fi

	user_hash="$(hash_password "${password}")"
	if [[ -z "${user_hash}" ]]; then
		echo "ERROR: Failed to generate Tinyauth bcrypt hash." >&2
		exit 1
	fi

	totp_output="$(tinyauth totp generate --user "${user_hash}" | strip_ansi)"
	new_secret="$(
		printf '%s\n' "${totp_output}" \
			| sed -n 's/.*authenticator app: \([A-Z2-7]\{16,\}\).*/\1/p' \
			| head -n1
	)"
	if [[ -z "${new_secret}" ]]; then
		echo "ERROR: Failed to generate a new TOTP secret." >&2
		exit 1
	fi

	new_uri="otpauth://totp/Herdr:martin?secret=${new_secret}&issuer=Herdr"
	auth_users="${user_hash}:${new_secret}"
	validate_tinyauth_users "${auth_users}"

	printf '%s' "${new_uri}" \
		| jq -Rs . \
		| sops set --value-stdin "${SECRETS_FILE}" '["TINYAUTH_TOTP_URI"]'
	printf '%s' "${auth_users}" \
		| jq -Rs . \
		| sops set --value-stdin "${SECRETS_FILE}" '["TINYAUTH_AUTH_USERS"]'

	echo "Rotated TOTP secret and updated ${SECRETS_FILE}."
	echo "Deploy with 'just switch-host' on skrye and 'just push-host zannah' to activate."
	echo ""
	show_qr "${new_uri}"
	;;
esac
