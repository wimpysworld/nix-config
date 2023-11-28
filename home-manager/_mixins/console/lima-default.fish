function lima-default
  if test -d "$HOME/.lima/default"
      echo "lima default already exists."
      return 1
  end

  # Set defaults
  set CPUS 2

  # Get the number of cores
  switch (uname -s)
    case Linux
      set CPUS (nproc)
      set MEMORY (free --giga -h | awk '/^Mem:/ {print $2}' | sed s'/[A-Z]//g')
      set LIMA_OPTS --vm-type=qemu --mount-type=9p
    case Darwin
      set CPUS (sysctl -n hw.ncpu)
      set MEMORY (math (sysctl -n hw.memsize) / 1024 / 1024 / 1024)
      set LIMA_OPTS --vm-type=vz --rosetta --mount-type=virtiofs --network=vzNAT
  end

  # Appropriately limit the number of VM CPUs
  if test $CPUS -ge 32
    set VM_CPUS (math $CPUS / 4)
  else if test $CORES -ge 4
    set VM_CPUS (math $CPUS / 2)
  end

  # Appropriately limit the VM memory
  if test $MEMORY -ge 256
    set VM_MEMORY (math $MEMORY / 8)
  else if test $MEMORY -ge 64
    set VM_MEMORY (math $MEMORY / 4)
  else
    set VM_MEMORY (math $MEMORY / 2)
  end

  limactl create $LIMA_OPTS --cpus=$VM_CPUS --memory=$VM_MEMORY --disk=32 --name=default --containerd=none --tty=false template://ubuntu
  return
  limactl start default

  # Inject a "munged" bash script as a faux heredoc payload to /tmp/lima/
  printf '#!/usr/bin/env bash

# Upgrade
sudo DEBIAN_FRONTEND=noninteractive apt-get -y update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade

# Install Nix
sudo mkdir -p "/nix/var/nix/profiles/per-user/${USER}"
export NIX_INSTALLER_NO_CONFIRM="true"
curl --proto "=https" --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# Clone my repos
git clone --quiet https://github.com/wimpysworld/nix-config "${HOME}/Zero/nix-config"

# Activate home-manager configuration
pushd "${HOME}/Zero/nix-config"
git checkout darwin-fixes
nix shell nixpkgs#home-manager --command sh -c "home-manager switch -b backup --flake ${HOME}/Zero/nix-config"

# Fake a fish login shell
echo "fish --login" >> "${HOME}/.bashrc"
echo "exit"         >> "${HOME}/.bashrc"
echo -e "\n${HOSTNAME} is now configured\nRestarting...\n"' > /tmp/lima/lima-default.sh

  chmod 755 /tmp/lima/lima-default.sh
  limactl shell --workdir "/home/$USER.linux" default /tmp/lima/lima-default.sh
  rm /tmp/lima/lima-default.sh
  limactl stop default
  limactl start default
  limactl list
  limactl shell default
end
