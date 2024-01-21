{ config, desktop, hostname, inputs, lib, modulesPath, outputs, pkgs, platform, stateVersion, username, ... }: {
  imports = [
    inputs.disko.nixosModules.disko
    (modulesPath + "/installer/scan/not-detected.nix")
    ./${hostname}
    ./_mixins/console
    ./_mixins/services/firewall.nix
    ./_mixins/services/kmscon.nix
    ./_mixins/services/openssh.nix
    ./_mixins/services/smartmon.nix
    ./_mixins/users/root
  ]
  ++ lib.optional (builtins.pathExists (./. + "/_mixins/users/${username}")) ./_mixins/users/${username}
  ++ lib.optional (desktop != null) ./_mixins/desktop;

  boot = {
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelModules = [ "vhost_vsock" ];
    kernelParams = [
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
    kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
  };

  console = {
    font = "${pkgs.tamzen}/share/consolefonts/TamzenForPowerline10x20.psf";
    keyMap = "uk";
    packages = with pkgs; [ tamzen ];
  };

  i18n = {
    defaultLocale = "en_GB.utf8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_GB.utf8";
      LC_IDENTIFICATION = "en_GB.utf8";
      LC_MEASUREMENT = "en_GB.utf8";
      LC_MONETARY = "en_GB.utf8";
      LC_NAME = "en_GB.utf8";
      LC_NUMERIC = "en_GB.utf8";
      LC_PAPER = "en_GB.utf8";
      LC_TELEPHONE = "en_GB.utf8";
      LC_TIME = "en_GB.utf8";
    };
  };
  services.xserver.layout = "gb";
  time.timeZone = "Europe/London";

  # Only install the docs I use
  documentation.enable = true;
  documentation.nixos.enable = false;
  documentation.man.enable = true;
  documentation.info.enable = false;
  documentation.doc.enable = false;

  environment = {
    # Eject nano and perl from the system
    defaultPackages = with pkgs; lib.mkForce [
      gitMinimal
      home-manager
      micro
      rsync
    ];
    systemPackages = with pkgs; [
      agenix
      pciutils
      psmisc
      unzip
      usbutils
      wget
    ] ++ [
      inputs.fh.packages.${platform}.default
    ];
    variables = {
      EDITOR = "micro";
      SYSTEMD_EDITOR = "micro";
      VISUAL = "micro";
    };
  };

  fonts = {
    # Enable a basic set of fonts providing several font styles and families and reasonable coverage of Unicode.
    enableDefaultPackages = false;
    fontDir.enable = true;
    packages = with pkgs; [
      (nerdfonts.override { fonts = [ "FiraCode" "SourceCodePro" "UbuntuMono" ]; })
      fira
      fira-go
      joypixels
      liberation_ttf
      noto-fonts-emoji
      source-serif
      ubuntu_font_family
      work-sans
    ];

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
        style = "slight";
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
      192.168.2.1     router
      192.168.2.8     ripper-wifi ripper
      192.168.2.9     ripper-lan1
      192.168.2.10    ripper-lan2
      192.168.2.11    printer
      192.168.2.15	  nuc
      192.168.2.17    skull
      192.168.2.20	  keylight-light key-left Elgato_Key_Light_Air_DAD4
      192.168.2.21    keylight-right key-right Elgato_Key_Light_Air_EEE9
      192.168.2.23    moodlamp
      192.168.2.30    chimeraos-lan
      192.168.2.31	  chimeraos-wifi chimeraos
      192.168.2.58    vonage Vonage-HT801
      192.168.2.184   lametric LaMetric-LM2144
      192.168.2.250   hue-bridge

      192.168.192.40  skull-zt
      192.168.192.59  trooper trooper-zt
      192.168.193.59  trooper-gaming
      192.168.192.104 steamdeck-zt
      192.168.193.104 steamdeck-gaming
      192.168.192.181 zed-zt
      192.168.192.220 ripper-zt
      192.168.193.220 ripper-gaming
      192.168.192.162 p1-zt
    '';
    hostName = hostname;
    useDHCP = lib.mkDefault true;
  };

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      inputs.agenix.overlays.default

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
      # Accept the joypixels license
      joypixels.acceptLicense = true;
    };
  };

  nix = {
    gc = {
      automatic = true;
      options = "--delete-older-than 10d";
    };

    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    # This will additionally add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    optimise.automatic = true;
    package = pkgs.unstable.nix;
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];

      # Avoid unwanted garbage collection when using nix-direnv
      keep-outputs = true;
      keep-derivations = true;

      warn-dirty = false;
    };
  };

  programs = {
    command-not-found.enable = false;
    fish = {
      enable = true;
      interactiveShellInit = ''
        set fish_cursor_default block blink
        set fish_cursor_insert line blink
        set fish_cursor_replace_one underscore blink
        set fish_cursor_visual block
        set -U fish_color_autosuggestion brblack
        set -U fish_color_cancel -r
        set -U fish_color_command green
        set -U fish_color_comment brblack
        set -U fish_color_cwd brgreen
        set -U fish_color_cwd_root brred
        set -U fish_color_end brmagenta
        set -U fish_color_error red
        set -U fish_color_escape brcyan
        set -U fish_color_history_current --bold
        set -U fish_color_host normal
        set -U fish_color_match --background=brblue
        set -U fish_color_normal normal
        set -U fish_color_operator cyan
        set -U fish_color_param blue
        set -U fish_color_quote yellow
        set -U fish_color_redirection magenta
        set -U fish_color_search_match bryellow '--background=brblack'
        set -U fish_color_selection white --bold '--background=brblack'
        set -U fish_color_status red
        set -U fish_color_user brwhite
        set -U fish_color_valid_path --underline
        set -U fish_pager_color_completion normal
        set -U fish_pager_color_description yellow
        set -U fish_pager_color_prefix white --bold --underline
        set -U fish_pager_color_progress brwhite '--background=cyan'
      '';
      shellAbbrs = {
        build-all = "pushd $HOME/Zero/nix-config && home-manager build --flake $HOME/Zero/nix-config && nixos-rebuild build --flake $HOME/Zero/nix-config && popd";
        build-host = "pushd $HOME/Zero/nix-config && nixos-rebuild build --flake $HOME/Zero/nix-config && popd";
        build-iso-console = "pushd $HOME/Zero/nix-config && nix build .#nixosConfigurations.iso-console.config.system.build.isoImage && set ISO (head -n1 result/nix-support/hydra-build-products | cut -d'/' -f6) && cp result/iso/$ISO $HOME/Quickemu/nixos-console/nixos.iso && popd";
        build-iso-desktop = "pushd $HOME/Zero/nix-config && nix build .#nixosConfigurations.iso-desktop.config.system.build.isoImage && set ISO (head -n1 result/nix-support/hydra-build-products | cut -d'/' -f6) && cp result/iso/$ISO $HOME/Quickemu/nixos-desktop/nixos.iso && popd";
        captive-portal = "xdg-open http://$(ip --oneline route get 1.1.1.1 | awk '{print $3}'";
        nix-gc = "sudo nix-collect-garbage --delete-older-than 10d && nix-collect-garbage --delete-older-than 10d";
        switch-all  = "sudo true && pushd $HOME/Zero/nix-config && home-manager switch -b backup --flake $HOME/Zero/nix-config && sudo nixos-rebuild switch --flake $HOME/Zero/nix-config && popd";
        switch-host = "pushd $HOME/Zero/nix-config && sudo nixos-rebuild switch --flake $HOME/Zero/nix-config && popd";
        update-lock = "pushd $HOME/Zero/nix-config && nix flake update && popd";
      };
      shellAliases = {
        nano = "micro";
      };
    };
    nano.enable = lib.mkDefault false;
    nix-ld.enable = true;
  };

  services.fwupd.enable = true;

  systemd.tmpfiles.rules = [
    "d /nix/var/nix/profiles/per-user/${username} 0755 ${username} root"
    "d /mnt/snapshot/${username} 0755 ${username} users"
  ];

  system = {
    activationScripts.diff = {
      supportsDryActivation = true;
      text = ''
        ${pkgs.nvd}/bin/nvd --nix-bin-dir=${pkgs.nix}/bin diff /run/current-system "$systemConfig"
      '';
    };
    stateVersion = stateVersion;
  };
}
