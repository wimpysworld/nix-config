{ pkgs, outputs, ...}: {
  imports = [
    ./locale.nix
    ./nano.nix
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
  nixpkgs.config.allowUnfree = true;

  programs = {
    command-not-found.enable = false;
    nix-index.enable = true;
    nix-index.enableBashIntegration = true;
    nix-index.enableFishIntegration = true;
  };
}
