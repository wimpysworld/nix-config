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
    micro
    pciutils
    rsync
    unzip
    usbutils
    wget
    xdg-utils
  ];

  fonts = {
    fontDir.enable = true;
    fonts = with pkgs; [
      (nerdfonts.override { fonts = [ "FiraCode" "SourceCodePro" "UbuntuMono"]; })
      fira
      fira-go
      joypixels
      liberation_ttf
      noto-fonts-emoji
      source-serif
      ubuntu_font_family
      work-sans
    ];

    # Enable a basic set of fonts providing several font styles and families and reasonable coverage of Unicode.
    enableDefaultFonts = false;

    fontconfig = {
      antialias = true;
      defaultFonts = {
        serif = [ "Source Serif" ];
        sansSerif = [ "Work Sans" "Fira Sans" "FiraGO" ];
        monospace = [ "FiraCode Nerd Font Mono" "SauceCodePro Nerd Font Mono" ];
        emoji = [ "Joypixels" "Noto Color Emoji" ];
      };
      enable = true;
      hinting = {
        autohint = false;
        enable = true;
        style = "hintslight";
      };
      subpixel = {
        rgba = "rgb";
        lcdfilter = "light";
      };
    };
  };

  # Use passed hostname to configure basic networking
  networking = {
    extraHosts = ''
    192.168.192.59  trooper-zt
    192.168.192.220 ripper-zt
    192.168.192.249 p2-max-zt
    '';
    hostName = hostname;
    useDHCP = lib.mkDefault true;
  };

  programs = {
    command-not-found.enable = false;
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
    "d /mnt/snapshot/${username} 0755 ${username} users"
  ];
}
