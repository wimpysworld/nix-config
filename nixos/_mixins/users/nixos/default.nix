{
  config,
  desktop,
  hostname,
  inputs,
  isInstall,
  isISO,
  isWorkstation,
  lib,
  pkgs,
  platform,
  username,
  ...
}:
let
  isWorkstationISO = (isISO && isWorkstation);
  install-system = pkgs.writeScriptBin "install-system" ''
    #!${pkgs.stdenv.shell}

    #set -euo pipefail

    TARGET_HOST="''${1:-}"
    TARGET_USER="''${2:-martin}"
    TARGET_BRANCH="''${3:-main}"

    function run_disko() {
      local DISKO_CONFIG="$1"
      local REPLY="n"

      # If the requested config doesn't exist, skip it.
      if [ ! -e "$DISKO_CONFIG" ]; then
        return
      fi

      ${pkgs.coreutils-full}/bin/echo "ALERT! Found $DISKO_CONFIG"
      ${pkgs.coreutils-full}/bin/echo "       Do you want to format the disks in $DISKO_CONFIG"
      ${pkgs.coreutils-full}/bin/echo "       This is a destructive operation!"
      ${pkgs.coreutils-full}/bin/echo
      read -p "Proceed with $DISKO_CONFIG format? [y/N]" -n 1 -r
      ${pkgs.coreutils-full}/bin/echo

      sudo true
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Workaround for mounting encrypted bcachefs filesystems.
        # - https://nixos.wiki/wiki/Bcachefs#NixOS_installation_on_bcachefs
        # - https://github.com/NixOS/nixpkgs/issues/32279
        sudo ${pkgs.keyutils}/bin/keyctl link @u @s
        sudo disko --mode disko "$DISKO_CONFIG"
      else
        sudo disko --mode mount "$DISKO_CONFIG"
      fi
    }

    sudo umount -R /mnt || true

    if [ "$(${pkgs.coreutils-full}/bin/id -u)" -eq 0 ]; then
      ${pkgs.coreutils-full}/bin/echo "ERROR! $(${pkgs.coreutils}/bin/basename "$0") should be run as a regular user"
      exit 1
    fi

    if [ ! -d "$HOME/Zero/nix-config/.git" ]; then
      ${pkgs.git}/bin/git clone https://github.com/wimpysworld/nix-config.git "$HOME/Zero/nix-config"
    fi

    pushd "$HOME/Zero/nix-config"

    if [[ -n "$TARGET_BRANCH" ]]; then
      ${pkgs.git}/bin/git checkout "$TARGET_BRANCH"
    fi

    if [[ -z "$TARGET_HOST" ]]; then
      ${pkgs.coreutils-full}/bin/echo "ERROR! $(basename "$0") requires a hostname as the first argument"
      ${pkgs.coreutils-full}/bin/echo "       The following hosts are available"
      ${pkgs.coreutils-full}/bin/ls -1 nixos/*/default.nix | ${pkgs.coreutils-full}/bin/cut -d'/' -f2 | ${pkgs.gnugrep}/bin/grep -v iso
      exit 1
    fi

    if [[ -z "$TARGET_USER" ]]; then
      ${pkgs.coreutils-full}/bin/echo "ERROR! $(basename "$0") requires a username as the second argument"
      ${pkgs.coreutils-full}/bin/echo "       The following users are available"
      ${pkgs.coreutils-full}/bin/ls -1 nixos/_mixins/users/ | ${pkgs.gnugrep}/bin/grep -v -E "nixos|root"
      exit 1
    fi

    if [ ! -e "$HOME/.config/sops/age/keys.txt" ]; then
      ${pkgs.coreutils-full}/bin/echo "WARNING! $HOME/.config/sops/age/keys.txt was not found."
      ${pkgs.coreutils-full}/bin/echo "         Do you want to continue without it?"
      ${pkgs.coreutils-full}/bin/echo
      read -p "Are you sure? [y/N]" -n 1 -r
      ${pkgs.coreutils-full}/bin/echo
      if [[ $REPLY =~ ^[Nn]$ ]]; then
        IP=$(${pkgs.iproute2}/bin/ip route get 1.1.1.1 | ${pkgs.gawk}/bin/awk '{print $7}' | ${pkgs.coreutils-full}/bin/head -n 1)
        ${pkgs.coreutils-full}/bin/mkdir -p "$HOME/.config/sops/age"
        ${pkgs.coreutils-full}/bin/echo "From a trusted host run:"
        ${pkgs.coreutils-full}/bin/echo "scp ~/.config/sops/age/keys.txt $USER@$IP:.config/sops/age/keys.txt"
        exit
      fi
    fi

    if [ -x "nixos/$TARGET_HOST/disks.sh" ]; then
      if ! sudo nixos/$TARGET_HOST/disks.sh "$TARGET_USER"; then
        ${pkgs.coreutils-full}/bin/echo "ERROR! Failed to prepare disks; stopping here!"
        exit 1
      fi
    else
      if [ ! -e "nixos/$TARGET_HOST/disks.nix" ]; then
        ${pkgs.coreutils-full}/bin/echo "ERROR! $(basename "$0") could not find the required nixos/$TARGET_HOST/disks.nix"
        exit 1
      fi

      if ${pkgs.gnugrep}/bin/grep -q "data.passwordFile" "nixos/$TARGET_HOST/disks.nix"; then
        # If the machine we're provisioning expects a password to unlock a disk, prompt for it.
        while true; do
          # Prompt for the password, input is hidden
          read -rsp "Enter password:   " password
          echo
          # Prompt for the password again for confirmation
          read -rsp "Confirm password: " password_confirm
          echo
          # Check if both entered passwords match
          if [ "$password" == "$password_confirm" ]; then
              break
          else
              echo "Passwords do not match, please try again."
          fi
        done

        # Write the password to /tmp/data.passwordFile with no trailing newline
        ${pkgs.coreutils-full}/bin/echo -n "$password" > /tmp/data.passwordFile
      fi

      if ${pkgs.gnugrep}/bin/grep -q "data.keyFile" "nixos/$TARGET_HOST/disks.nix"; then
        # Check if the machine we're provisioning expects a keyfile to unlock a disk.
        # If it does, generate a new key, and write to a known location.
        ${pkgs.coreutils-full}/bin/echo -n "$(head -c32 /dev/random | base64)" > /tmp/data.keyFile
      fi

      run_disko "nixos/$TARGET_HOST/disks.nix"

      for CONFIG in $(${pkgs.findutils}/bin/find "nixos/$TARGET_HOST" -name "disks-*.nix" | ${pkgs.coreutils-full}/bin/sort); do
        run_disko "$CONFIG"
      done
    fi

    if ! ${pkgs.util-linux}/bin/mountpoint -q /mnt; then
      ${pkgs.coreutils-full}/bin/echo "ERROR! /mnt is not mounted; make sure the disk preparation was successful."
      exit 1
    fi

    ${pkgs.coreutils-full}/bin/echo "WARNING! NixOS will be re-installed"
    ${pkgs.coreutils-full}/bin/echo "         This is a destructive operation!"
    ${pkgs.coreutils-full}/bin/echo
    read -p "Are you sure? [y/N]" -n 1 -r
    ${pkgs.coreutils-full}/bin/echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      # Copy the sops keys.txt to the target install
      sudo nixos-install --no-root-password --flake ".#$TARGET_HOST"

      # Rsync nix-config to the target install and set the remote origin to SSH.
      ${pkgs.rsync}/bin/rsync -a --delete "$HOME/Zero/" "/mnt/home/$TARGET_USER/Zero/"
      if [ "$TARGET_HOST" != "minimech" ] && [ "$TARGET_HOST" != "scrubber" ]; then
        pushd "/mnt/home/$TARGET_USER/Zero/nix-config"
        ${pkgs.git}/bin/git remote set-url origin git@github.com:wimpysworld/nix-config.git
        popd
      fi

      # Copy the sops keys.txt to the target install
      if [ -e "$HOME/.config/sops/age/keys.txt" ]; then
        ${pkgs.coreutils-full}/bin/mkdir -p /mnt/home/$TARGET_USER/.config/sops/age
        ${pkgs.coreutils-full}/bin/cp "$HOME/.config/sops/age/keys.txt" /mnt/home/$TARGET_USER/.config/sops/age/keys.txt
        ${pkgs.coreutils-full}/bin/chmod 600 /mnt/home/$TARGET_USER/.config/sops/age/keys.txt
      fi

      # Enter to the new install and apply the home-manager configuration.
      sudo nixos-enter --root /mnt --command "${pkgs.coreutils-full}/bin/chown -R $TARGET_USER:users /home/$TARGET_USER"
      sudo nixos-enter --root /mnt --command "cd /home/$TARGET_USER/Zero/nix-config; env USER=$TARGET_USER HOME=/home/$TARGET_USER ${pkgs.home-manager}/bin/home-manager switch --flake \".#$TARGET_USER@$TARGET_HOST\""
      sudo nixos-enter --root /mnt --command "${pkgs.coreutils-full}/bin/chown -R $TARGET_USER:users /home/$TARGET_USER"

      # If there is a keyfile for a data disk, put copy it to the root partition and
      # ensure the permissions are set appropriately.
      if [[ -f "/tmp/data.keyFile" ]]; then
        sudo ${pkgs.coreutils-full}/bin/cp /tmp/data.keyFile /mnt/etc/data.keyFile
        sudo ${pkgs.coreutils-full}/bin/chmod 0400 /mnt/etc/data.keyFile
      fi
    fi
  '';
in
{
  config.users.users.nixos.description = "NixOS";

  # All configurations for live media are below:
  config.system = lib.mkIf (isISO) { stateVersion = lib.mkForce lib.trivial.release; };

  config.environment = {
    etc = lib.mkIf (isWorkstationISO) {
      "firefox.dockitem".source = pkgs.writeText "firefox.dockitem" ''
        [PlankDockItemPreferences]
        Launcher=file:///run/current-system/sw/share/applications/firefox.desktop
      '';
      "firefox.dockitem".target = "/plank/firefox.dockitem";

      "io.elementary.files.dockitem".source = pkgs.writeText "io.elementary.files.dockitem" ''
        [PlankDockItemPreferences]
        Launcher=file:///run/current-system/sw/share/applications/io.elementary.files.desktop
      '';
      "io.elementary.files.dockitem".target = "/plank/io.elementary.files.dockitem";

      "io.elementary.terminal.dockitem".source = pkgs.writeText "io.elementary.terminal.dockitem" ''
        [PlankDockItemPreferences]
        Launcher=file:///run/current-system/sw/share/applications/io.elementary.terminal.desktop
      '';
      "io.elementary.terminal.dockitem".target = "/plank/io.elementary.terminal.dockitem";

      "gparted.dockitem".source = pkgs.writeText "gparted.dockitem" ''
        [PlankDockItemPreferences]
        Launcher=file:///run/current-system/sw/share/applications/gparted.desktop
      '';
      "gparted.dockitem".target = "/plank/gparted.dockitem";
    };
    systemPackages =
      lib.optionals (isISO) [
        install-system
        inputs.disko.packages.${platform}.default
      ]
      ++ lib.optionals (isWorkstationISO) [ pkgs.gparted ];
  };

  # All workstation configurations for live media are below.
  config.isoImage = lib.mkIf (isWorkstationISO) { edition = lib.mkForce "${desktop}"; };

  config.programs = {
    dconf.profiles.user.databases = [
      {
        settings =
          with lib.gvariant;
          lib.mkIf (isWorkstationISO) {
            "net/launchpad/plank/docks/dock1" = {
              dock-items = [
                "firefox.dockitem"
                "io.elementary.files.dockitem"
                "io.elementary.terminal.dockitem"
                "gparted.dockitem"
              ];
            };
            "org/gnome/shell" = {
              disabled-extensions = mkEmptyArray type.string;
              favorite-apps = [
                "firefox.desktop"
                "org.gnome.Nautilus.desktop"
                "org.gnome.Console.desktop"
                "io.calamares.calamares.desktop"
                "gparted.desktop"
              ];
              welcome-dialog-last-shown-version = "9999999999";
            };
            "org/gnome/desktop/background" = {
              picture-options = "zoom";
              picture-uri = "file:///etc/backgrounds/DeterminateColorway-3840x2160.png";
              picture-uri-dark = "file:///etc/backgrounds/DeterminateColorway-3840x2160.png";
            };
            "org/gnome/desktop/screensaver" = {
              picture-uri = "file:///etc/backgrounds/DeterminateColorway-3840x2160.png";
            };
          };
      }
    ];
  };

  config.services.xserver = {
    displayManager.autoLogin = lib.mkIf (isWorkstationISO) { user = "${username}"; };
  };

  # Create desktop shortcuts and dock items for the live media
  config.systemd.tmpfiles = lib.mkIf (isWorkstationISO) {
    rules =
      [
        "d /home/${username}/Desktop 0755 ${username} users"
        "d /home/${username}/.config 0755 ${username} users"
        "d /home/${username}/.config/plank 0755 ${username} users"
        "d /home/${username}/.config/plank/dock1 0755 ${username} users"
        "d /home/${username}/.config/plank/dock1/launchers 0755 ${username} users"
        "L+ /home/${username}/.config/plank/dock1/launchers/firefox.dockitem - - - - /etc/plank/firefox.dockitem"
        "L+ /home/${username}/.config/plank/dock1/launchers/io.elementary.files.dockitem - - - - /etc/plank/io.elementary.files.dockitem"
        "L+ /home/${username}/.config/plank/dock1/launchers/io.elementary.terminal.dockitem - - - - /etc/plank/io.elementary.terminal.dockitem"
        "L+ /home/${username}/.config/plank/dock1/launchers/gparted.dockitem - - - - /etc/plank/gparted.dockitem"
        "L+ /home/${username}/Desktop/firefox.desktop - - - - ${pkgs.firefox}/share/applications/firefox.desktop"
        "L+ /home/${username}/Desktop/io.calamares.calamares.desktop - - - - ${pkgs.calamares-nixos}/share/applications/io.calamares.calamares.desktop"
        "L+ /home/${username}/Desktop/gparted.desktop - - - - ${pkgs.gparted}/share/applications/gparted.desktop"
      ]
      ++ lib.optionals (isWorkstationISO && desktop == "mate") [
        "L+ /home/${username}/Desktop/caja.desktop - - - - ${pkgs.mate.caja}/share/applications/caja.desktop"
        "L+ /home/${username}/Desktop/mate-terminal.desktop - - - - ${pkgs.mate.mate-terminal}/share/applications/mate-terminal.desktop"
      ];
  };
}
