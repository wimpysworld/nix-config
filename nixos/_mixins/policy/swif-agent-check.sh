#!/usr/bin/env bash

# Check the health and status of the Swif.ai agent on NixOS.
# Read-only: reports enrolment, services, the hidden admin user, generated
# policy files, the device lock and the state size. Changes nothing.

STATE_DIR="/var/lib/swifteam"
INSTALL_FLAG="${STATE_DIR}/installed.flag"
LOCK_FILE="/tmp/swif-device-lock-pin-code.txt"
GENERATED_DIR="${SWIF_NIX_ROOT_PATH}/swifteam"
STATE_WARN_BYTES=$((1024 * 1024 * 1024))
PASS="PASS"
FAIL="FAIL"
WARN="WARN"
INFO="INFO"
ERRORS=0

# Root is required to read the state and generated directories.
# Self-elevate so a plain swif-agent-check works.
if [[ "$(id -u)" -ne 0 ]]; then
	exec sudo "$0" "$@"
fi

echo "===================================="
echo " Swif.ai Agent Check"
echo "===================================="
echo ""

# Check enrolment.
echo "--- Enrolment ---"
if [[ -f "${INSTALL_FLAG}" ]]; then
	echo "  ${PASS}: ${INSTALL_FLAG} exists"
else
	echo "  ${FAIL}: ${INSTALL_FLAG} does not exist"
	echo "         Read: journalctl -u swif-agent-installer -b"
	ERRORS=$((ERRORS + 1))
fi
INSTALLER_RESULT=$(systemctl show -p Result --value swif-agent-installer 2>&1) || true
echo "  ${INFO}: swif-agent-installer.service result is ${INSTALLER_RESULT}"
echo ""

# Check the agent and watchdog services.
echo "--- Services ---"
for unit in swif-agent syscheck; do
	if systemctl is-active --quiet "${unit}"; then
		echo "  ${PASS}: ${unit}.service is active"
	else
		STATE=$(systemctl is-active "${unit}" 2>&1) || true
		echo "  ${FAIL}: ${unit}.service is ${STATE}"
		ERRORS=$((ERRORS + 1))
		if [[ -f "${INSTALL_FLAG}" ]]; then
			echo "         Reboot, or run: sudo systemctl start swif-agent syscheck"
		fi
	fi
	if systemctl is-enabled --quiet "${unit}"; then
		echo "  ${PASS}: ${unit}.service is enabled"
	else
		echo "  ${WARN}: ${unit}.service is not enabled"
	fi
	EXEC_START=$(systemctl show -p ExecStart --value "${unit}" 2>&1 | grep -o 'path=[^ ;]*' || true)
	echo "  ${INFO}: ${unit} ${EXEC_START:-ExecStart unknown}"
done
echo ""

# Check the hidden admin user. Print no password content.
echo "--- Hidden Admin User ---"
if USER_ENTRY=$(getent passwd swifteam); then
	echo "  ${INFO}: swifteam exists with UID $(echo "${USER_ENTRY}" | cut -d: -f3)"
else
	echo "  ${WARN}: swifteam user does not exist"
fi
if [[ -f "${STATE_DIR}/passwords/swifteam" ]]; then
	echo "  ${INFO}: Password file exists"
else
	echo "  ${INFO}: Password file does not exist"
fi
echo ""

# Report generated policy modules. Nothing imports them.
echo "--- Generated Configuration ---"
if [[ -d "${GENERATED_DIR}" ]]; then
	NIX_FILES=$(find "${GENERATED_DIR}" -type f -name '*.nix' | wc -l)
	NEWEST=$(find "${GENERATED_DIR}" -type f -printf '%TY-%Tm-%Td %TH:%TM\n' | sort | tail -n 1)
	echo "  ${INFO}: ${GENERATED_DIR} holds ${NIX_FILES} .nix file(s), newest ${NEWEST:-none}"
	echo "         Review before any import."
else
	echo "  ${INFO}: ${GENERATED_DIR} does not exist"
fi
echo ""

# Check for a pending device lock.
echo "--- Device Lock ---"
if [[ -e "${LOCK_FILE}" ]]; then
	echo "  ${WARN}: ${LOCK_FILE} exists"
	echo "         The next boot locks the console until the PIN is entered."
else
	echo "  ${PASS}: No device lock pending"
fi
echo ""

# Check the state size.
echo "--- State Size ---"
if [[ -d "${STATE_DIR}" ]]; then
	STATE_BYTES=$(du -sb "${STATE_DIR}" | cut -f1)
	STATE_HUMAN=$(du -sh "${STATE_DIR}" | cut -f1)
	if [[ "${STATE_BYTES}" -gt "${STATE_WARN_BYTES}" ]]; then
		echo "  ${WARN}: ${STATE_DIR} is ${STATE_HUMAN}"
	else
		echo "  ${PASS}: ${STATE_DIR} is ${STATE_HUMAN}"
	fi
else
	echo "  ${WARN}: ${STATE_DIR} does not exist"
fi
echo ""

# Report neighbouring policy agents.
echo "--- Neighbours ---"
for unit in falcon-sensor kolide-launcher; do
	STATE=$(systemctl is-active "${unit}" 2>&1) || true
	echo "  ${INFO}: ${unit}.service is ${STATE}"
done
echo ""

# Summary.
echo "===================================="
if [[ "${ERRORS}" -eq 0 ]]; then
	echo " All checks passed"
else
	echo " ${ERRORS} check(s) failed"
fi
echo "===================================="
exit "${ERRORS}"
