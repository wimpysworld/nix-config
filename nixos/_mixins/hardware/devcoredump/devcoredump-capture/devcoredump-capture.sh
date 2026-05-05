#!/usr/bin/env bash
# Capture a kernel devcoredump artefact before the kernel's auto-expiry
# consumes it. Invoked by the devcoredump-capture@.service systemd unit,
# which is itself triggered by a udev rule on devcoredump SUBSYSTEM "add"
# events. The instance argument is the kernel name (e.g. devcd0).

set -euo pipefail

devname="${1:?missing devcoredump kernel name}"
syspath="/sys/class/devcoredump/${devname}"
datafile="${syspath}/data"
outdir="/var/lib/devcoredump"

# Bail out gracefully if the entry has already disappeared. The kernel
# expires devcoredump entries five minutes after creation, and this
# service may race against expiry on a slow boot.
if [ ! -e "${datafile}" ]; then
    logger -t devcoredump-capture "no data at ${datafile}, nothing to capture"
    exit 0
fi

timestamp=$(date -u +%Y%m%dT%H%M%SZ)
host=$(hostname)

# Identify the failing device (driver-relative path) for the filename
# stem. This makes it obvious at a glance whether the dump came from
# amdgpu, iwlwifi, or another driver that emits devcoredumps.
failing=""
if [ -L "${syspath}/failing_device" ]; then
    failing=$(readlink -f "${syspath}/failing_device" \
        | sed 's|/sys/devices/||; s|/|-|g')
fi
if [ -z "${failing}" ]; then
    failing="unknown"
fi

stem="devcoredump-${timestamp}-${host}-${failing}"

mkdir -p "${outdir}"
chmod 0750 "${outdir}"

# Capture the dump first (compressed). Use zstd -19 for a strong
# compression ratio: devcoredump payloads are mostly register state and
# memory snapshots that compress well, and we are not on a hot path.
zstd -q -19 -o "${outdir}/${stem}.bin.zst" "${datafile}"

# Capture the recent kernel ring buffer for context. The hang messages
# typically land here just before the GPU reset that produces the dump.
journalctl -k -n 2000 --no-pager | zstd -q -19 -o "${outdir}/${stem}.dmesg.zst"

# Capture the recent journal so userspace context (compositor, browser,
# affected services) is preserved alongside the kernel state.
journalctl -b -n 2000 --no-pager | zstd -q -19 -o "${outdir}/${stem}.journal.zst" || true

# Mark the kernel entry consumed so the kernel reclaims its slot. Any
# write to data triggers cleanup; "0" is the conventional value.
echo 0 > "${datafile}" || true

logger -t devcoredump-capture "captured ${stem} (failing=${failing})"
