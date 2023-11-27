function lima-default
  if test -d "$HOME/.lima/default"
      echo "lima default already exists."
      return 1
  end

  # Set defaults
  set CORES 2
  set TWEAKS ""

  # Detect Operating System
  set KERNEL (uname -s)

  # Get the number of cores
  switch $KERNEL
    case Linux
      set CORES (nproc)
      set TWEAKS "--vm-type qemu"
    case Darwin
      set CORES (sysctl -n hw.ncpu)
      set TWEAKS "--vm-type=vz --mount-type=virtiofs --rosetta --network=vzNAT"
  end

  # Appropriately limit the number of cores
  if test $CORES -ge 32
    set CORES (math $CORES / 4)
  else if test $CORES -ge 4
    set CORES (math $CORES / 2)
  end

  limactl create --cpus=$CORES --memory=4 --disk=32 --name=default --containerd=none --tty=false $TWEAKS template://default
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
