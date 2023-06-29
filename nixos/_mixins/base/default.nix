{ hostname, lib, pkgs, username, ...}: {
  imports = [
    ./locale.nix
    ./nano.nix
    ../services/firewall.nix
    ../services/fwupd.nix
    ../services/openssh.nix
  ];

  # Only install the docs I use
  documentation.enable = true;        # documentation of packages
  documentation.nixos.enable = false; # nixos documentation
  documentation.man.enable = true;    # man pages and the man command
  documentation.info.enable = false;  # info pages and the info command
  documentation.doc.enable = false;   # documentation distributed in packages' /share/doc

  environment.systemPackages = with pkgs; [
    binutils
    curl
    desktop-file-utils
    file
    git
    home-manager
    killall
    man-pages
    mergerfs
    mergerfs-tools
    micro
    pciutils
    rsync
    unzip
    usbutils
    wget
    xdg-utils
  ];

  # Use passed hostname to configure basic networking
  networking = {
    hostName = hostname;
    useDHCP = lib.mkDefault true;
  };

  programs = {
    fish = { 
      enable = true;
      shellAbbrs = {
        nix-gc           = "sudo nix-collect-garbage --delete-older-than 14d";
        rebuild-home     = "home-manager switch -b backup --flake $HOME/Zero/nix-config";
        rebuild-host     = "sudo nixos-rebuild switch --flake $HOME/Zero/nix-config";
        rebuild-lock     = "pushd $HOME/Zero/nix-config && nix flake lock --recreate-lock-file && popd";
        rebuild-iso      = "pushd $HOME/Zero/nix-config && nix build .#nixosConfigurations.iso.config.system.build.isoImage && popd";
        rebuild-iso-mini = "pushd $HOME/Zero/nix-config && nix build .#nixosConfigurations.iso-mini.config.system.build.isoImage && popd";
      };
    };
  };

  security.rtkit.enable = true;

  # Create dirs for home-manager
  systemd.tmpfiles.rules = [
    "d /nix/var/nix/profiles/per-user/${username} 0755 ${username} root"
  ];
}
