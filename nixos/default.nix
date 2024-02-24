{ config, desktop, hostname, inputs, lib, modulesPath, outputs, pkgs, platform, stateVersion, username, ... }: {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.nix-index-database.nixosModules.nix-index
    inputs.sops-nix.nixosModules.sops
    (modulesPath + "/installer/scan/not-detected.nix")
    ./${hostname}
    ./_mixins/base
    ./_mixins/kernel
    ./_mixins/scripts
    ./_mixins/services/firewall.nix
    ./_mixins/services/openssh.nix
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
      coreutils-full
      micro
      util-linux
    ];
    systemPackages = with pkgs; [
      age
      git
      ssh-to-age
      sops
    ] ++ [
      inputs.fh.packages.${platform}.default
    ];
    variables = {
      EDITOR = "micro";
      SYSTEMD_EDITOR = "micro";
      VISUAL = "micro";
    };
  };

  # Use passed hostname to configure basic networking
  networking = {
    extraHosts = ''
      192.168.2.1     router
      192.168.2.6     vader-wifi vader
      192.168.2.7     vader-lan
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

      # Add overlays exported from other flakes:
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
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
        captive-portal = "${pkgs.xdg-utils}/bin/xdg-open http://$(${pkgs.iproute2}/bin/ip --oneline route get 1.1.1.1 | ${pkgs.gawk}/bin/awk '{print $3}'";
        nix-gc = "sudo ${pkgs.unstable.nix}/bin/nix-collect-garbage --delete-older-than 10d && ${pkgs.unstable.nix}/bin/nix-collect-garbage --delete-older-than 10d";
        update-lock = "pushd $HOME/Zero/nix-config && ${pkgs.unstable.nix}/bin/nix flake update && popd";
      };
      shellAliases = {
        nano = "micro";
      };
    };
    nano.enable = lib.mkDefault false;
  };

  sops = {
    age = {
      keyFile = "/home/${username}/.config/sops/age/keys.txt";
      generateKey = false;
    };
    defaultSopsFile = ../secrets/secrets.yaml;
    # sops-nix options: https://dl.thalheim.io/
    secrets.test-key = {};
  };

  # Enable Multi-Gen LRU:
  # - https://docs.kernel.org/next/admin-guide/mm/multigen_lru.html
  # - Inspired by: https://github.com/hakavlad/mg-lru-helper
  systemd.services."mglru" = {
    enable = true;
    wantedBy = ["basic.target"];
    script = ''
      ${pkgs.coreutils-full}/bin/echo 1000 > /sys/kernel/mm/lru_gen/min_ttl_ms
    '';
    serviceConfig = {
      Type = "oneshot";
    };
    unitConfig = {
      ConditionPathExists = "/sys/kernel/mm/lru_gen/enabled";
      Description = "Configure Enable Multi-Gen LRU";
    };
  };

  systemd.tmpfiles.rules = [
    "d /nix/var/nix/profiles/per-user/${username} 0755 ${username} root"
    "d /mnt/snapshot/${username} 0755 ${username} users"
  ];

  system.stateVersion = stateVersion;
}
