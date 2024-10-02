#!/usr/bin/env bash

function lima_create() {
  if [ -z "${1}" ]; then
    VM_NAME="default"
    HOSTNAME="recon"
  else
    VM_NAME="${1}"
    HOSTNAME="${VM_NAME}"
  fi

  if [ -d "${HOME}/.lima/${VM_NAME}" ]; then
    echo "lima ${VM_NAME} already exists."
    return 1
  fi

  # Get platform specific values
  case "$(uname -s)" in
    Linux)
      CPUS=$(nproc)
      MEMORY=$(free --giga -h | awk '/^Mem:/ {print $2}' | sed 's/[A-Z]//g')
      LIMA_OPTS="--vm-type=qemu --mount-type=9p --mount-writable"
      ;;
    Darwin)
      CPUS=$(sysctl -n hw.ncpu)
      MEMORY=$(echo "$(sysctl -n hw.memsize) / 1024 / 1024 / 1024" | bc)
      LIMA_OPTS="--vm-type=vz --rosetta --mount-type=virtiofs --mount-writable"
      ;;
  esac

  # Appropriately limit the number of VM CPUs
  if [ "${CPUS}" -ge 32 ]; then
    VM_CPUS=$(echo "${CPUS} / 4" | bc)
  elif [ "${CPUS}" -ge 4 ]; then
    VM_CPUS=$(echo "$CPUS / 2" | bc)
  fi

  # Appropriately limit the VM memory
  if [ "${MEMORY}" -ge 256 ]; then
    VM_MEMORY=$(echo "${MEMORY} / 8" | bc)
  elif [ "${MEMORY}" -ge 64 ]; then
    VM_MEMORY=$(echo "${MEMORY} / 4" | bc)
  else
    VM_MEMORY=$(echo "${MEMORY} / 2" | bc)
  fi

  case "${VM_NAME}" in
    blackace|defender|fighter)
      YAML="${HOME}/.lima/_templates/${VM_NAME}.yaml"
      VM_DISK=64
      ;;
    *)
      TEMPLATE="ubuntu"
      VM_DISK=32
      ;;
  esac

  if [ -n "${YAML}" ]; then
    # shellcheck disable=SC2086
    limactl create ${LIMA_OPTS} --cpus="${VM_CPUS}" --memory="${VM_MEMORY}" --disk="${VM_DISK}" --name="${VM_NAME}" --tty=false "${YAML}"
  else
    # shellcheck disable=SC2086
    limactl create ${LIMA_OPTS} --cpus="${VM_CPUS}" --memory="${VM_MEMORY}" --disk="${VM_DISK}" --name="${VM_NAME}" --containerd=none --tty=false template://"${TEMPLATE}"
  fi
  limactl start "${VM_NAME}"
  limactl stop "${VM_NAME}"
  limactl list
  limactl start "${VM_NAME}"
  limactl shell "${VM_NAME}"
}

# Call the function with the argument passed to the script
lima_create "$@"
