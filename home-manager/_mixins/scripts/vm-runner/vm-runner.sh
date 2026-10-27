#!/usr/bin/env bash
set -euo pipefail

prog="$(basename "$0")"

usage() {
	cat <<EOF
Usage: ${prog} [--shutdown] [--kill] [--delete] [--vulkan] [iso_path]

Launch or control the ${prog#vm-} QEMU virtual machine.

Options:
  --shutdown  Send an ACPI powerdown signal to the running VM and wait for exit.
  --kill      Forcefully terminate the running VM process.
  --delete    Stop the VM if running, then delete disk and UEFI NVRAM state.
  --vulkan    Enable Venus Vulkan support on the VirtIO GPU.
  -h, --help  Show this help.
EOF
}

fail() {
	printf '%s: %s\n' "$prog" "$*" >&2
	exit 1
}

case "$prog" in
vm-noughty)
	profile="noughty"
	state_dir="${HOME}/Quickemu/noughty"
	ssh_port="2220"
	;;
vm-wolfi)
	profile="wolfi"
	state_dir="${HOME}/Quickemu/wolfi"
	ssh_port="2221"
	;;
*)
	fail "run this script as vm-noughty or vm-wolfi"
	;;
esac

shutdown_vm=0
kill_vm=0
delete_disk=0
vulkan=0
iso_path=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
		usage
		exit 0
		;;
	--shutdown)
		shutdown_vm=1
		shift
		;;
	--kill)
		kill_vm=1
		shift
		;;
	--delete)
		delete_disk=1
		shift
		;;
	--vulkan)
		vulkan=1
		shift
		;;
	--*)
		fail "unknown option: $1"
		;;
	-*)
		fail "unknown option: $1"
		;;
	*)
		if [[ -n "$iso_path" ]]; then
			fail "unexpected argument: $1"
		fi
		if [[ ! -f "$1" ]]; then
			fail "ISO file not found: $1"
		fi
		iso_path="$(realpath -- "$1")"
		shift
		;;
	esac
done

disk_img="${state_dir}/disk.qcow2"
ovmf_vars="${state_dir}/OVMF_VARS.fd"
pid_file="${state_dir}/qemu.pid"
qmp_sock="${state_dir}/qmp.sock"
spice_sock="${state_dir}/spice.sock"

cleanup_runtime() {
	rm -f -- "$pid_file" "$qmp_sock" "$spice_sock"
}

is_running() {
	if [[ -f "$pid_file" ]]; then
		local pid=""
		read -r pid <"$pid_file" || true
		if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
			return 0
		fi
		cleanup_runtime
	fi
	return 1
}

stop_forcefully() {
	if is_running; then
		local pid=""
		read -r pid <"$pid_file" || true
		if [[ -n "$pid" ]]; then
			kill -TERM "$pid" 2>/dev/null || true
			for _ in {1..15}; do
				if ! kill -0 "$pid" 2>/dev/null; then
					break
				fi
				sleep 0.1
			done
			if kill -0 "$pid" 2>/dev/null; then
				kill -KILL "$pid" 2>/dev/null || true
			fi
		fi
	fi
	cleanup_runtime
}

if ((shutdown_vm == 1)); then
	if ! is_running; then
		printf '%s: VM is not running\n' "$prog"
		exit 0
	fi
	pid=""
	read -r pid <"$pid_file" || true
	printf '{"execute":"qmp_capabilities"}\n{"execute":"system_powerdown"}\n' |
		socat - "UNIX-CONNECT:${qmp_sock}" >/dev/null 2>&1 || true
	for _ in {1..150}; do
		if ! kill -0 "$pid" 2>/dev/null; then
			cleanup_runtime
			printf '%s: VM shut down\n' "$prog"
			exit 0
		fi
		sleep 0.2
	done
	fail "timed out waiting for VM (PID ${pid}) to shut down; use --kill to force stop"
fi

if ((kill_vm == 1)); then
	if is_running; then
		stop_forcefully
		printf '%s: killed running VM\n' "$prog"
	else
		cleanup_runtime
		printf '%s: VM is not running\n' "$prog"
	fi
	exit 0
fi

if ((delete_disk == 1)); then
	stop_forcefully
	rm -f -- "$disk_img" "$ovmf_vars"
	if [[ -z "$iso_path" ]]; then
		printf '%s: deleted state in %s\n' "$prog" "$state_dir"
		exit 0
	fi
fi

if is_running; then
	if [[ -n "$iso_path" ]]; then
		fail "VM is already running; use --shutdown, --kill, or --delete before booting an ISO"
	fi
	printf '%s: reconnecting to running VM\n' "$prog"
	exec spicy --uri="spice+unix://${spice_sock}" --title="vm-${profile}" >/dev/null 2>&1
fi

mkdir -p -- "$state_dir"
cleanup_runtime

if [[ ! -f "$ovmf_vars" ]]; then
	cp -- "$OVMF_VARS" "$ovmf_vars"
	chmod 0644 -- "$ovmf_vars"
fi

if [[ ! -f "$disk_img" ]]; then
	if [[ -z "$iso_path" ]]; then
		fail "disk image not found at ${disk_img}. Pass an ISO path to install."
	fi
	qemu-img create -q -f qcow2 -o preallocation=off "$disk_img" 64G
fi

cpus=$(($(nproc) / 2))
if ((cpus < 2)); then
	cpus=2
fi

gpu_dev="virtio-vga-gl,hostmem=4G,blob=true"
if ((vulkan == 1)); then
	gpu_dev="virtio-vga-gl,hostmem=4G,blob=true,venus=true"
fi

disk_bootindex=1
if [[ -n "$iso_path" ]]; then
	disk_bootindex=2
fi

qemu_args=(
	-name "${profile},process=vm-${profile}"
	-daemonize
	-pidfile "${pid_file}"
	-qmp "unix:${qmp_sock},server=on,wait=off"
	-machine "q35,accel=kvm,smm=on,memory-backend=mem"
	-cpu host
	-smp "${cpus}"
	-m 16G
	-object "memory-backend-memfd,id=mem,size=16G,share=on"
	-drive "if=pflash,format=raw,unit=0,file=${OVMF_CODE},readonly=on"
	-drive "if=pflash,format=raw,unit=1,file=${ovmf_vars}"
	-display none
	-spice "unix=on,addr=${spice_sock},disable-ticketing=on,image-compression=off,streaming-video=off,gl=on"
	-device "${gpu_dev}"
	-device "qemu-xhci,id=xhci"
	-device "usb-tablet,bus=xhci.0"
	-device "usb-kbd,bus=xhci.0"
	-device "virtio-rng-pci"
	-device "virtio-net-pci,netdev=net0"
	-netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${ssh_port}-:22"
	-device "virtio-serial-pci"
	-chardev "spicevmc,id=vdagent,name=vdagent"
	-device "virtserialport,chardev=vdagent,name=com.redhat.spice.0"
	-drive "id=disk0,file=${disk_img},format=qcow2,if=none,discard=unmap,detect-zeroes=unmap"
	-device "virtio-blk-pci,drive=disk0,bootindex=${disk_bootindex}"
)

if [[ -n "${XDG_RUNTIME_DIR:-}" && -d "${XDG_RUNTIME_DIR}" ]]; then
	qemu_args+=(
		-audiodev "pipewire,id=snd0"
		-device "ich9-intel-hda"
		-device "hda-duplex,audiodev=snd0"
	)
fi

if [[ -n "$iso_path" ]]; then
	qemu_args+=(
		-drive "id=cdrom0,file=${iso_path},format=raw,if=none,readonly=on"
		-device "virtio-blk-pci,drive=cdrom0,bootindex=1"
	)
fi

qemu-system-x86_64 "${qemu_args[@]}"
exec spicy --uri="spice+unix://${spice_sock}" --title="vm-${profile}" >/dev/null 2>&1
