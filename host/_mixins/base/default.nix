{ config, hostid, hostname, inputs, lib, pkgs, ...}: {
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
    home-manager
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

    # This will add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

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
    # You can add overlays here
    overlays = [
      # If you want to use overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
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
