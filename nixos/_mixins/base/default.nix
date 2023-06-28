{ hostid, hostname, lib, pkgs, ...}: {
  imports = [
    ./locale.nix
    ./nano.nix
    ../services/fwupd.nix
    ../services/openssh.nix
    ../services/tailscale.nix
    ../services/zerotier.nix
  ];

  # don't install documentation i don't use
  documentation.enable = true; # documentation of packages
  documentation.nixos.enable = false; # nixos documentation
  documentation.man.enable = true; # manual pages and the man command
  documentation.info.enable = false; # info pages and the info command
  documentation.doc.enable = false; # documentation distributed in packages' /share/doc

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
    v4l-utils
    wget
    xdg-utils
  ];

  # Use passed in hostid and hostname to configure basic networking
  networking = {
    hostName = hostname;
    hostId = hostid;
    useDHCP = lib.mkDefault true;
    firewall = {
      enable = true;
    };
  };

  programs = {
    fish.enable = true;
  };

  security.rtkit.enable = true;
}
