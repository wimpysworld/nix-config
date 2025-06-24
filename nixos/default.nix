{
  config,
  hostname,
  isInstall,
  isISO,
  isWorkstation,
  inputs,
  lib,
  modulesPath,
  outputs,
  pkgs,
  platform,
  stateVersion,
  username,
  ...
}:
let
  coreUtils = if isISO then [
    pkgs.coreutils-full
    pkgs.diffutils
    pkgs.findutils
    pkgs.sudo
  ] else [
    (lib.hiPrio pkgs.uutils-coreutils-noprefix)
    (lib.hiPrio pkgs.uutils-diffutils)
    (lib.hiPrio pkgs.uutils-findutils)
    (lib.hiPrio pkgs.sudo-rs)
  ];
in
{
  imports = [
    # Use module this flake exports; from modules/nixos
    #outputs.nixosModules.my-module
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
    ./_mixins/configs
    ./_mixins/features
    ./_mixins/scripts
    ./_mixins/services
    ./_mixins/users
  ] ++ lib.optional isWorkstation ./_mixins/desktop;

  boot = {
    binfmt = lib.mkIf isInstall {
      emulatedSystems = [
        "riscv64-linux"
      ] ++ lib.optionals (platform == "x86_64-linux") [
        "aarch64-linux"
      ] ++ lib.optionals (platform == "aarch64-linux") [
        "x86_64-linux"
      ];
    };
    consoleLogLevel = lib.mkDefault 0;
    initrd.verbose = false;
    kernelModules = [ "vhost_vsock" ];
    kernelPackages = lib.mkForce pkgs.linuxPackages_6_12;
    # Only enable the systemd-boot on installs, not live media (.ISO images)
    loader = lib.mkIf isInstall {
      efi.canTouchEfiVariables = true;
      systemd-boot.configurationLimit = 10;
      systemd-boot.consoleMode = "max";
      systemd-boot.enable = true;
      systemd-boot.memtest86.enable = true;
      timeout = 10;
    };
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
        inputs.determinate.packages.${platform}.default
        inputs.fh.packages.${platform}.default
        inputs.nixos-needsreboot.packages.${platform}.default
        git
        just
        micro
        nix-output-monitor
        sops
      ]
      ++ lib.optionals isInstall [
        nvd
        nvme-cli
        rsync
        smartmontools

      ] ++ coreUtils;

    variables = {
      EDITOR = "micro";
      SYSTEMD_EDITOR = "micro";
      VISUAL = "micro";
    };
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
      # Disable global registry
      flake-registry = "";
      lazy-trees = true;
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

  nixpkgs.hostPlatform = lib.mkDefault "${platform}";

  programs = {
    command-not-found.enable = false;
    fish = {
      enable = true;
      shellAliases = {
        nano = "micro";
      };
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

  # Only enable sudo-rs on installs, not live media (.ISO images)
  security = lib.mkIf isInstall {
    sudo.enable = false;
    sudo-rs = {
      enable = lib.mkDefault true;
    };
  };

  services = {
    fwupd.enable = isInstall;
    hardware.bolt.enable = true;
    irqbalance = lib.mkIf (! config.services.qemuGuest.enable) {
      enable = true;
    };
    smartd.enable = isInstall;
  };

  # https://dl.thalheim.io/
  sops = lib.mkIf (isInstall) {
    age = {
      keyFile = "/var/lib/private/sops/age/keys.txt";
      generateKey = false;
    };
    defaultSopsFile = ../secrets/secrets.yaml;
    secrets = {
      test-key = { };
      ssh_key = {
        mode = "0600";
        path = "/root/.ssh/id_rsa";
      };
      ssh_pub = {
        mode = "0644";
        path = "/root/.ssh/id_rsa.pub";
      };
      # Use `make-host-keys` to enroll new host keys.
      initrd_ssh_host_ed25519_key = {
        mode = "0600";
        path = "/etc/ssh/initrd_ssh_host_ed25519_key";
        sopsFile = ../secrets/initrd.yaml;
      };
      initrd_ssh_host_ed25519_key_pub = {
        mode = "0644";
        path = "/etc/ssh/initrd_ssh_host_ed25519_key.pub";
        sopsFile = ../secrets/initrd.yaml;
      };
      ssh_host_ed25519_key = {
        mode = "0600";
        path = "/etc/ssh/ssh_host_ed25519_key";
        sopsFile = ../secrets/${hostname}.yaml;
      };
      ssh_host_ed25519_key_pub = {
        mode = "0644";
        path = "/etc/ssh/ssh_host_ed25519_key.pub";
        sopsFile = ../secrets/${hostname}.yaml;
      };
      ssh_host_rsa_key = {
        mode = "0600";
        path = "/etc/ssh/ssh_host_rsa_key";
        sopsFile = ../secrets/${hostname}.yaml;
      };
      ssh_host_rsa_key_pub = {
        mode = "0644";
        path = "/etc/ssh/ssh_host_rsa_key.pub";
        sopsFile = ../secrets/${hostname}.yaml;
      };
      malak_enc.sopsFile = ../secrets/disks.yaml;
      maul_enc.sopsFile = ../secrets/disks.yaml;
      tanis_enc.sopsFile = ../secrets/disks.yaml;
      shaa_enc.sopsFile = ../secrets/disks.yaml;
      atrius_enc.sopsFile = ../secrets/disks.yaml;
      sidious_enc.sopsFile = ../secrets/disks.yaml;
      phasma_enc.sopsFile = ../secrets/disks.yaml;
      vader_enc.sopsFile = ../secrets/disks.yaml;
    };
  };

  # Create symlink to /bin/bash
  # - https://github.com/lima-vm/lima/issues/2110
  systemd = {
    extraConfig = "DefaultTimeoutStopSec=10s";
    tmpfiles.rules = [
      "L+ /bin/bash - - - - ${pkgs.bash}/bin/bash"
      "d /nix/var/nix/profiles/per-user/${username} 0755 ${username} root"
      "d /var/lib/private/sops/age 0755 root root"
    ];
  };

  system = {
    activationScripts = {
      nixos-needsreboot = lib.mkIf (isInstall) {
        supportsDryActivation = true;
        text = "${lib.getExe inputs.nixos-needsreboot.packages.${pkgs.system}.default} \"$systemConfig\" || true";
      };
    };
    nixos.label = lib.mkIf isInstall "-";
    inherit stateVersion;
  };
}
