#!/usr/bin/env bash
set -euo pipefail

prog="$(basename "$0")"

usage() {
	cat <<EOF
Usage: ${prog} [--delete] [--vulkan] [iso_path]

Launch the ${prog#vm-} QEMU virtual machine.

Options:
  --delete    Delete the virtual disk and UEFI NVRAM state.
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

delete_disk=0
vulkan=0
iso_path=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
		usage
		exit 0
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

if ((delete_disk == 1)); then
	rm -f -- "$disk_img" "$ovmf_vars"
	if [[ -z "$iso_path" ]]; then
		printf '%s: deleted state in %s\n' "$prog" "$state_dir"
		exit 0
	fi
fi

mkdir -p -- "$state_dir"

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
	-machine "q35,accel=kvm,smm=on,memory-backend=mem"
	-cpu host
	-smp "${cpus}"
	-m 16G
	-object "memory-backend-memfd,id=mem,size=16G,share=on"
	-drive "if=pflash,format=raw,unit=0,file=${OVMF_CODE},readonly=on"
	-drive "if=pflash,format=raw,unit=1,file=${ovmf_vars}"
	-display "gtk,gl=on,grab-on-hover=on,zoom-to-fit=off"
	-device "${gpu_dev}"
	-device "qemu-xhci,id=xhci"
	-device "usb-tablet,bus=xhci.0"
	-device "usb-kbd,bus=xhci.0"
	-device "virtio-rng-pci"
	-device "virtio-net-pci,netdev=net0"
	-netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${ssh_port}-:22"
	-device "virtio-serial-pci"
	-chardev "qemu-vdagent,id=vdagent,name=vdagent,clipboard=on,mouse=on"
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

exec qemu-system-x86_64 "${qemu_args[@]}"
