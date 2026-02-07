#!/usr/bin/env bash

# Check the health and status of the CrowdStrike Falcon sensor on NixOS.
# Displays service status, sensor configuration, cloud connectivity,
# and Reduced Functionality Mode (RFM) state.

INSTALL_DIR="/opt/CrowdStrike"
FALCONCTL="${INSTALL_DIR}/falconctl"
PASS="PASS"
FAIL="FAIL"
WARN="WARN"
ERRORS=0

# Must run as root to query falconctl.
if [[ "$(id -u)" -ne 0 ]]; then
	echo "ERROR: This script must be run as root."
	echo "  sudo falcon-sensor-check"
	exit 1
fi

echo "===================================="
echo " CrowdStrike Falcon Sensor Check"
echo "===================================="
echo ""

# Check binaries are installed.
echo "--- Installation ---"
if [[ -x "${FALCONCTL}" ]]; then
	echo "  ${PASS}: falconctl found at ${FALCONCTL}"
else
	echo "  ${FAIL}: falconctl not found at ${FALCONCTL}"
	echo ""
	echo "Run falcon-sensor-install to bootstrap the sensor binaries."
	exit 1
fi

if [[ -x "${INSTALL_DIR}/falcond" ]]; then
	echo "  ${PASS}: falcond found"
else
	echo "  ${FAIL}: falcond not found"
	ERRORS=$((ERRORS + 1))
fi
echo ""

# Query sensor version, CID, and AID.
echo "--- Sensor Identity ---"
VERSION_OUTPUT=$("${FALCONCTL}" -g --version 2>&1) || true
if [[ "${VERSION_OUTPUT}" == *"version ="* ]]; then
	echo "  ${PASS}: ${VERSION_OUTPUT}"
else
	echo "  ${FAIL}: Unable to query sensor version"
	ERRORS=$((ERRORS + 1))
fi

CID_OUTPUT=$("${FALCONCTL}" -g --cid 2>&1) || true
if [[ "${CID_OUTPUT}" == *"cid="* ]]; then
	echo "  ${PASS}: ${CID_OUTPUT}"
else
	echo "  ${FAIL}: CID is not set"
	ERRORS=$((ERRORS + 1))
fi

AID_OUTPUT=$("${FALCONCTL}" -g --aid 2>&1) || true
if [[ "${AID_OUTPUT}" == *"aid="* && "${AID_OUTPUT}" != *"aid=\"\"" ]]; then
	echo "  ${PASS}: ${AID_OUTPUT}"
else
	echo "  ${WARN}: Agent ID not yet assigned (sensor may still be registering)"
fi
echo ""

# Check RFM state.
echo "--- Reduced Functionality Mode ---"
RFM_OUTPUT=$("${FALCONCTL}" -g --rfm-state 2>&1) || true
if [[ "${RFM_OUTPUT}" == *"rfm-state=false"* ]]; then
	echo "  ${PASS}: RFM is disabled (full functionality)"
elif [[ "${RFM_OUTPUT}" == *"rfm-state=true"* ]]; then
	echo "  ${FAIL}: RFM is ENABLED (reduced functionality)"
	echo "         The sensor cannot fully protect this system."
	echo "         Check kernel compatibility and BPF backend status."
	ERRORS=$((ERRORS + 1))
else
	echo "  ${WARN}: Unable to determine RFM state"
	echo "         ${RFM_OUTPUT}"
fi

RFM_REASON=$("${FALCONCTL}" -g --rfm-reason 2>&1) || true
if [[ "${RFM_REASON}" == *"rfm-reason="* && "${RFM_REASON}" != *"rfm-reason=\"\"" ]]; then
	echo "  INFO: ${RFM_REASON}"
fi
echo ""

# Check backend mode.
echo "--- Backend ---"
BACKEND_OUTPUT=$("${FALCONCTL}" -g --backend 2>&1) || true
if [[ "${BACKEND_OUTPUT}" == *"backend=bpf"* ]]; then
	echo "  ${PASS}: Using BPF backend (recommended for NixOS)"
elif [[ "${BACKEND_OUTPUT}" == *"backend="* ]]; then
	echo "  ${WARN}: ${BACKEND_OUTPUT}"
	echo "         BPF backend is recommended for NixOS."
else
	echo "  ${WARN}: Unable to determine backend"
fi
echo ""

# Check tags.
echo "--- Tags ---"
TAGS_OUTPUT=$("${FALCONCTL}" -g --tags 2>&1) || true
if [[ "${TAGS_OUTPUT}" == *"tags="* ]]; then
	echo "  INFO: ${TAGS_OUTPUT}"
else
	echo "  INFO: No tags configured"
fi
echo ""

# Check systemd service status.
echo "--- Service Status ---"
if systemctl is-active --quiet falcon-sensor; then
	echo "  ${PASS}: falcon-sensor.service is active"
else
	STATE=$(systemctl is-active falcon-sensor 2>&1) || true
	echo "  ${FAIL}: falcon-sensor.service is ${STATE}"
	ERRORS=$((ERRORS + 1))
fi

if systemctl is-enabled --quiet falcon-sensor; then
	echo "  ${PASS}: falcon-sensor.service is enabled"
else
	echo "  ${WARN}: falcon-sensor.service is not enabled"
fi
echo ""

# Check log file.
echo "--- Log File ---"
if [[ -L /var/log/falconctl.log ]]; then
	echo "  ${WARN}: /var/log/falconctl.log is a symlink (should be a regular file)"
	echo "         Target: $(readlink /var/log/falconctl.log)"
	echo "         Restart falcon-sensor to fix this automatically."
elif [[ -f /var/log/falconctl.log ]]; then
	echo "  ${PASS}: /var/log/falconctl.log exists"
else
	echo "  ${WARN}: /var/log/falconctl.log does not exist"
fi
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
