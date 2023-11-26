function lima-create
  limactl create --arch=x86_64 --cpus=(math (nproc) / 2) --memory 16 --disk 128 --name=default --tty=false template://ubuntu-lts
  # Remove home directory mount
  sed -i '/- location: "~"/d' $HOME/.lima/default/lima.yaml
  limactl start default

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
sudo systemctl restart apt-cacher-ng

# Install nix and home-manager
sudo mkdir -p "/nix/var/nix/profiles/per-user/${USER}"
export NIX_INSTALLER_NO_CONFIRM="true"
curl --proto "=https" --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
nix profile install nixpkgs#home-manager

# Apply my nix-config
mkdir -p "${HOME}/Zero"
git clone https://github.com/wimpysworld/nix-config "${HOME}/Zero/nix-config"
pushd "${HOME}/Zero/nix-config"
home-manager switch -b backup --flake "${HOME}/Zero/nix-config"
git clone https://github.com/wimpysworld/obs-studio-portable "${HOME}/Development/github.com/wimpysworld/obs-studio-portable"

# Fake a fish login shell
echo "fish --login" >> "/home/${USER}/.bashrc"
echo "exit"         >> "/home/${USER}/.bashrc"
echo "${HOSTNAME} is now configured and rebooting"
sudo reboot' > /tmp/lima/lima-default.sh

  chmod 755 /tmp/lima/lima-default.sh
  limactl shell --workdir "/home/$USER.linux" default /tmp/lima/lima-default.sh
  limactl list
end
