function builder-create
  if test -d "$HOME/.lima/builder"
      echo "builder already exists."
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
      set TWEAKS "--vm-type vz --mount-type virtiofs --rosetta --network vzNAT"
  end

  # Appropriately limit the number of cores
  if test $CORES -ge 32
    set CORES (math $CORES / 4)
  else if test $CORES -ge 4
    set CORES (math $CORES / 2)
  end

  limactl create --arch=x86_64 --cpus=$CORES --memory 16 --disk 64 --name=builder --containerd none --tty=false $TWEAKS template://ubuntu-lts
  # Remove home directory mount
  sed -i '/- location: "~"/d' $HOME/.lima/builder/lima.yaml
  limactl start builder

  # Inject a "munged" bash script as a faux heredoc payload to /tmp/lima/
  printf '#!/usr/bin/env bash

# Hack the home directory; usermod will not work because the user is logged in
sudo mv "/home/${USER}.linux" "/home/${USER}"
sudo sed -i "s/${USER}\.linux/${USER}/g" /etc/passwd
sudo sed -i "s/${USER}\.linux/${USER}/g" /etc/passwd-
export HOME="/home/${USER}"
cd "${HOME}"

# Upgrade, install apt-cacher-ng and devscripts
sudo DEBIAN_FRONTEND=noninteractive apt-get -y update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install apt-cacher-ng devscripts
echo "DlMaxRetries: 32"       | sudo tee -a /etc/apt-cacher-ng/zzz_local.conf
echo "PassThroughPattern: .*" | sudo tee -a /etc/apt-cacher-ng/zzz_local.conf

# Install Nix
sudo mkdir -p "/nix/var/nix/profiles/per-user/${USER}"
export NIX_INSTALLER_NO_CONFIRM="true"
curl --proto "=https" --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# Clone my repos
git clone --quiet https://github.com/wimpysworld/nix-config "${HOME}/Zero/nix-config"
git clone --quiet https://github.com/wimpysworld/obs-studio-portable "${HOME}/Development/github.com/wimpysworld/obs-studio-portable"

# Activate home-manager configuration
pushd "${HOME}/Zero/nix-config"
nix shell nixpkgs#home-manager --command sh -c "home-manager switch -b backup --flake ${HOME}/Zero/nix-config"

# Fake a fish login shell
echo "fish --login" >> "/home/${USER}/.bashrc"
echo "exit"         >> "/home/${USER}/.bashrc"
echo -e "\n${HOSTNAME} is now configured and rebooting\n"
sudo reboot' > /tmp/lima/builder.sh

  chmod 755 /tmp/lima/builder.sh
  limactl shell --workdir "/home/$USER.linux" builder /tmp/lima/builder.sh
  rm /tmp/lima/builder.sh
  limactl list
end
