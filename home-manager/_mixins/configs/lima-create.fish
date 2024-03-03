function lima-create
  if test -z $argv[1]
    set VM_NAME "default"
  else
    set VM_NAME $argv[1]
  end

  if test -d "$HOME/.lima/$VM_NAME"
      echo "lima $VM_NAME already exists."
      return 1
  end

  # Get platform specific values
  switch (uname -s)
    case Linux
      set CPUS (nproc)
      set MEMORY (free --giga -h | awk '/^Mem:/ {print $2}' | sed s'/[A-Z]//g')
      if test "$VM_NAME" = "builder"
        set LIMA_OPTS --arch=x86_64 --vm-type=qemu --mount-type=9p
      else
        set LIMA_OPTS --vm-type=qemu --mount-type=9p
      end
    case Darwin
      set CPUS (sysctl -n hw.ncpu)
      set MEMORY (math (sysctl -n hw.memsize) / 1024 / 1024 / 1024)
      if test "$VM_NAME" = "builder"
        set LIMA_OPTS --arch=x86_64
      else
        set LIMA_OPTS --vm-type=qemu
      end
  end

  # Appropriately limit the number of VM CPUs
  if test $CPUS -ge 32
    set VM_CPUS (math $CPUS / 4)
  else if test $CPUS -ge 4
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

  if test "$VM_NAME" = "builder"
    set TEMPLATE "ubuntu-lts"
    set VM_DISK 64
  else
    set TEMPLATE "ubuntu"
    set VM_DISK 32
  end

  limactl create $LIMA_OPTS --cpus=$VM_CPUS --memory=$VM_MEMORY --disk=$VM_DISK --name=$VM_NAME --containerd=none --tty=false template://$TEMPLATE
  limactl start $VM_NAME

  # Inject a "munged" bash script as a faux heredoc payload to /tmp/lima/
  printf '#!/usr/bin/env bash

# Upgrade
sudo DEBIAN_FRONTEND=noninteractive apt-get -y update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade

# Install apt-cacher-ng and devscripts
if [ "${HOSTNAME}" == "lima-builder" ]; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y install apt-cacher-ng devscripts
  echo "DlMaxRetries: 32"       | sudo tee -a /etc/apt-cacher-ng/zzz_local.conf
  echo "PassThroughPattern: .*" | sudo tee -a /etc/apt-cacher-ng/zzz_local.conf
fi

# Install Nix
sudo mkdir -p "/nix/var/nix/profiles/per-user/${USER}"
curl -sSfL https://install.determinate.systems/nix | sh -s -- install --no-confirm
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# Clone my repos
git clone --quiet https://github.com/wimpysworld/nix-config "${HOME}/Zero/nix-config"
if [ "${HOSTNAME}" == "lima-builder" ]; then
  git clone --quiet https://github.com/wimpysworld/obs-studio-portable "${HOME}/Development/github.com/wimpysworld/obs-studio-portable"
fi

# Activate home-manager configuration
pushd "${HOME}/Zero/nix-config"
nix run nixpkgs#home-manager -- switch --flake "${HOME}/Zero/nix-config"

# Fake a fish login shell
echo "fish --login" >> "${HOME}/.bashrc"
echo "exit"         >> "${HOME}/.bashrc"
echo -e "\n${HOSTNAME} is now configured\nRestarting...\n"' > /tmp/lima/lima-$VM_NAME.sh

  chmod 755 /tmp/lima/lima-$VM_NAME.sh
  limactl shell --workdir "/home/$USER.linux" $VM_NAME /tmp/lima/lima-$VM_NAME.sh
  rm /tmp/lima/lima-$VM_NAME.sh
  limactl stop $VM_NAME
  limactl start $VM_NAME
  limactl list
  limactl shell $VM_NAME
end
