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
    echo "ERROR! ${VM_NAME} already exists."
    return 1
  fi

  # Get platform specific values
  case "$(uname -s)" in
    Linux)  CPUS=$(nproc);;
    Darwin) CPUS=$(sysctl -n hw.logicalcpu);;
  esac

  # Appropriately limit the number of VM CPUs
  if [ "${CPUS}" -ge 32 ]; then
    VM_CPUS=$(echo "${CPUS} / 4" | bc)
  elif [ "${CPUS}" -ge 4 ]; then
    VM_CPUS=$(echo "${CPUS} / 2" | bc)
  fi

  case "${VM_NAME}" in
    blackace|defender|fighter) YAML="${HOME}/.lima/_templates/${VM_NAME}.yaml";;
    *) TEMPLATE="ubuntu";;
  esac

  if [ -n "${YAML}" ]; then
    # shellcheck disable=SC2086
    limactl create --tty=false \
      --cpus="${VM_CPUS}" \
      --name="${VM_NAME}" \
      "${YAML}"
  else
    # shellcheck disable=SC2086
    limactl create --tty=false \
      --cpus="${VM_CPUS}" \
      --name="${VM_NAME}" \
      template://"${TEMPLATE}"
  fi
  limactl start "${VM_NAME}"
  limactl shell "${VM_NAME}"
}

# Call the function with the argument passed to the script
lima_create "$@"
