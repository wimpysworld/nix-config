{
  catppuccinPalette,
  config,
  hostname,
  isInstall,
  isWorkstation,
  inputs,
  lib,
  modulesPath,
  outputs,
  pkgs,
  stateVersion,
  username,
  ...
}:
{
  imports = [
    # Use modules this flake exports; from modules/nixos
    outputs.nixosModules.falcon-sensor
    outputs.nixosModules.wavebox
    # Use modules from other flakes
    inputs.catppuccin.nixosModules.catppuccin
    inputs.determinate.nixosModules.default
    inputs.disko.nixosModules.disko
    inputs.kolide-launcher.nixosModules.kolide-launcher
    inputs.nix-flatpak.nixosModules.nix-flatpak
    inputs.nix-index-database.nixosModules.nix-index
    inputs.sops-nix.nixosModules.sops
    (modulesPath + "/installer/scan/not-detected.nix")
    ./${hostname}
    ./_mixins/console
    ./_mixins/hardware
    ./_mixins/network
    ./_mixins/policy
    ./_mixins/scripts
    ./_mixins/server
    ./_mixins/users
    ./_mixins/virtualisation
  ]
  ++ lib.optional isWorkstation ./_mixins/desktop;

  boot = {
    binfmt = lib.mkIf isInstall {
      emulatedSystems = [
        "riscv64-linux"
      ]
      ++ lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
        "aarch64-linux"
      ]
      ++ lib.optionals (pkgs.stdenv.hostPlatform.system == "aarch64-linux") [
        "x86_64-linux"
      ];
    };
    consoleLogLevel = lib.mkDefault 0;
    initrd.verbose = false;
    kernelModules = [ "vhost_vsock" ];
    # Only enable the systemd-boot on installs, not live media (.ISO images)
    loader = lib.mkIf isInstall {
      efi.canTouchEfiVariables = true;
      systemd-boot.configurationLimit = lib.mkDefault 10;
      systemd-boot.consoleMode = "max";
      systemd-boot.enable = true;
      systemd-boot.memtest86.enable = true;
      timeout = lib.mkDefault 10;
    };
  };

  catppuccin = {
    accent = catppuccinPalette.accent;
    flavor = catppuccinPalette.flavor;
  };

  # Only install the docs I use
  documentation.enable = true;
  documentation.nixos.enable = false;
  documentation.man.enable = true;
  documentation.info.enable = false;
  documentation.doc.enable = false;

  environment = {
    systemPackages =
      with pkgs;
      [
        inputs.determinate.packages.${pkgs.stdenv.hostPlatform.system}.default
        inputs.fh.packages.${pkgs.stdenv.hostPlatform.system}.default
        git
        just
        micro
        nix-output-monitor
        sops
      ]
      ++ lib.optionals isInstall [
        nvme-cli
        rsync
        smartmontools
      ];

    variables = {
      EDITOR = "micro";
      SYSTEMD_EDITOR = "micro";
      VISUAL = "micro";
    };
  };

  nixpkgs = {
    overlays = [
      # Overlays defined via overlays/default.nix and pkgs/default.nix
      outputs.overlays.localPackages
      outputs.overlays.modifiedPackages
      outputs.overlays.unstablePackages
    ];
    config = {
      allowUnfree = true;
    };
  };

  nix =
    let
      flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
    in
    {
      settings = {
        experimental-features = "nix-command flakes";
        extra-experimental-features = "parallel-eval";
        # Disable global registry
        flake-registry = "";
        lazy-trees = true;
        eval-cores = 0; # Enable parallel evaluation across all cores
        # Workaround for https://github.com/NixOS/nix/issues/9574
        nix-path = config.nix.nixPath;
        warn-dirty = false;
      };
      # Disable channels
      channel.enable = false;
      # Make flake registry and nix path match flake inputs
      registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
      nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
    };

  programs = {
    command-not-found.enable = false;
    fish = {
      enable = true;
    };
    nano.enable = lib.mkDefault false;
    nh = {
      clean = {
        enable = isInstall;
        extraArgs = "--keep-since 15d --keep 10";
      };
      enable = true;
      flake = "/home/${username}/Zero/nix-config";
    };
    nix-index-database.comma.enable = isInstall;
    nix-ld = lib.mkIf isInstall {
      enable = true;
      libraries = with pkgs; [
        # Add any missing dynamic libraries for unpackaged
        # programs here, NOT in environment.systemPackages
      ];
    };
  };

  services = {
    dbus = {
      enable = true;
      implementation = "broker";
    };
  };

  # Only enable sudo-rs on installs, not live media (.ISO images)
  security = lib.mkIf isInstall {
    polkit.enable = true;
    sudo.enable = false;
    sudo-rs = {
      enable = lib.mkDefault true;
    };
  };

  # https://dl.thalheim.io/
  sops = lib.mkIf (isInstall) {
    age = {
      keyFile = "/var/lib/private/sops/age/keys.txt";
      generateKey = false;
      # Disable SSH key scanning - we use the age keyFile and the SSH host keys
      # are themselves managed by sops, creating a circular dependency at boot.
      sshKeyPaths = [ ];
    };
    # Disable GPG SSH key scanning for the same reason.
    gnupg.sshKeyPaths = [ ];
    defaultSopsFile = ../secrets/secrets.yaml;
    secrets = {
      ssh_key = {
        mode = "0600";
        path = "/root/.ssh/id_rsa";
        sopsFile = ../secrets/ssh.yaml;
      };
      ssh_pub = {
        mode = "0644";
        path = "/root/.ssh/id_rsa.pub";
        sopsFile = ../secrets/ssh.yaml;
      };
      # Use `make-host-keys` to enroll new host keys.
      initrd_ssh_host_ed25519_key = {
        mode = "0600";
        path = "/etc/ssh/initrd_ssh_host_ed25519_key";
        sopsFile = ../secrets/ssh.yaml;
      };
      initrd_ssh_host_ed25519_key_pub = {
        mode = "0644";
        path = "/etc/ssh/initrd_ssh_host_ed25519_key.pub";
        sopsFile = ../secrets/ssh.yaml;
      };
      ssh_host_ed25519_key = {
        mode = "0600";
        path = "/etc/ssh/ssh_host_ed25519_key";
        sopsFile = ../secrets/host-${hostname}.yaml;
      };
      ssh_host_ed25519_key_pub = {
        mode = "0644";
        path = "/etc/ssh/ssh_host_ed25519_key.pub";
        sopsFile = ../secrets/host-${hostname}.yaml;
      };
      ssh_host_rsa_key = {
        mode = "0600";
        path = "/etc/ssh/ssh_host_rsa_key";
        sopsFile = ../secrets/host-${hostname}.yaml;
      };
      ssh_host_rsa_key_pub = {
        mode = "0644";
        path = "/etc/ssh/ssh_host_rsa_key.pub";
        sopsFile = ../secrets/host-${hostname}.yaml;
      };
    };
  };

  # Create symlink to /bin/bash
  # - https://github.com/lima-vm/lima/issues/2110
  systemd = {
    settings.Manager = {
      DefaultTimeoutStopSec = "10s";
    };
    tmpfiles.rules = [
      "L+ /bin/bash - - - - ${pkgs.bash}/bin/bash"
      "L+ /bin/sh - - - - ${pkgs.bash}/bin/sh"
      "d /nix/var/nix/profiles/per-user/${username} 0755 ${username} root"
      "d /var/lib/private/sops/age 0755 root root"
    ];
  };

  system = {
    nixos.label = lib.mkIf isInstall "-";
    inherit stateVersion;
  };
}
