{ hostid, hostname, lib, pkgs, outputs, ...}: {
  imports = [
    ./locale.nix
    ./nano.nix
    ../services/fwupd.nix
    ../services/openssh.nix
    ../services/tailscale.nix
  ];

  console = {
    earlySetup = true;
    font = "ter-powerline-v28n"; # Number indicates pixel size of the font
    packages = [ pkgs.terminus_font pkgs.powerline-fonts ];
    keyMap = "uk";
  };

  environment.systemPackages = with pkgs; [
    binutils
    curl
    desktop-file-utils
    file
    ffmpeg
    git
    killall
    man-pages
    mergerfs
    mergerfs-tools
    nano
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

  nix = {
    gc = {
      automatic = true;
      options = "--delete-older-than 14d";
    };
    optimise.automatic = true;
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = (_: true);
    };
  };

  programs = {
    command-not-found.enable = false;
    dconf.enable = true;
    nix-index.enable = true;
    nix-index.enableBashIntegration = true;
    nix-index.enableFishIntegration = true;
  };

  security.rtkit.enable = true;
}
