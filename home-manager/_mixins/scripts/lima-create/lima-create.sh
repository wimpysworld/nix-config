#!/usr/bin/env bash

function lima_create() {
  if [ -z "${1}" ]; then
    VM_NAME="default"
    HOSTNAME="ubuntu"
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

  if [ "${VM_NAME}" = "grozbok" ]; then
    YAML="${HOME}/.lima/_templates/ubuntu-24.yml"
    VM_DISK=64
  elif [ "${VM_NAME}" = "zeta" ]; then
    YAML="${HOME}/.lima/_templates/ubuntu-22.yml"
    VM_DISK=64
  else
    TEMPLATE="ubuntu"
    VM_DISK=32
  fi

  if [ -n "${YAML}" ]; then
    # shellcheck disable=SC2086
    limactl create ${LIMA_OPTS} --cpus="${VM_CPUS}" --memory="${VM_MEMORY}" --disk="${VM_DISK}" --name="${VM_NAME}" --containerd=none --tty=false "${YAML}"
  else
    # shellcheck disable=SC2086
    limactl create ${LIMA_OPTS} --cpus="${VM_CPUS}" --memory="${VM_MEMORY}" --disk="${VM_DISK}" --name="${VM_NAME}" --containerd=none --tty=false template://"${TEMPLATE}"
  fi
  limactl start "${VM_NAME}"

  # Inject a "munged" bash script as a faux heredoc payload to /tmp/lima/
  cat << EOF > "/tmp/lima/lima-${VM_NAME}.sh"
#!/usr/bin/env bash

# The default Lima VM has a specific hostname
sudo hostnamectl hostname "${HOSTNAME}"

# Upgrade
sudo DEBIAN_FRONTEND=noninteractive apt-get -y update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade

# Install apt-cacher-ng and dev tools
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install \
  build-essential \
  debootstrap \
  debhelper \
  devscripts \
  germinate
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install apt-cacher-ng
echo "DlMaxRetries: 32"       | sudo tee -a /etc/apt-cacher-ng/zzz_local.conf
echo "PassThroughPattern: .*" | sudo tee -a /etc/apt-cacher-ng/zzz_local.conf
sudo snap install snapcraft --classic
sudo snap install lxd --channel=latest/stable
# Add the user to the lxd group
getent group lxd | grep -qwF "\${USER}" || sudo usermod -aG lxd "\${USER}"

# Install Nix
sudo mkdir -p "/nix/var/nix/profiles/per-user/\${USER}"
curl -sSfL https://install.determinate.systems/nix | sh -s -- install --determinate --no-confirm
echo "trusted-users = root \${USER}" | sudo tee -a /etc/nix/nix.conf
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# Clone my Nix configuration
git clone --quiet https://github.com/wimpysworld/nix-config "\${HOME}/Zero/nix-config"

# Configure sops-nix
if [ -e "/home/\${USER}/.config/sops/age/keys.txt" ]; then
  mkdir -p "\${HOME}/.config/sops/age"
  cp "/home/\${USER}/.config/sops/age/keys.txt" "\${HOME}/.config/sops/age/keys.txt"
fi

# Activate home-manager configuration
pushd "\${HOME}/Zero/nix-config"
nix run nixpkgs#home-manager -- switch --flake "\${HOME}/Zero/nix-config"
if [ -e "\${HOME}/.config/sops/age/keys.txt" ]; then
  gpg-restore
fi

# Fake a fish login shell
echo "fish --login" >> "\${HOME}/.bashrc"
echo "exit"         >> "\${HOME}/.bashrc"
echo -e "\n\${HOSTNAME} is now configured\nRestarting...\n"
EOF

  chmod 755 "/tmp/lima/lima-${VM_NAME}.sh"
  limactl shell --workdir "/home/${USER}.linux" "${VM_NAME}" "/tmp/lima/lima-${VM_NAME}.sh"
  rm "/tmp/lima/lima-${VM_NAME}.sh"
  limactl stop "${VM_NAME}"
  limactl start "${VM_NAME}"
  limactl list
  limactl shell "${VM_NAME}"
}

# Call the function with the argument passed to the script
lima_create "$@"
