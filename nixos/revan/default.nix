# Motherboard:       Gigabye Z390 Designare
# CPU:               Intel i9 9900K
# GPU:               NVIDIA T400
# RAM:               64GB DDR4
# NVME0:             512GB Corsair Force MP600
# NVME1:             1TB Corsair Force MP600
# SATA2:             12TB Ultrastar He12
# SATA3:             12TB Ultrastar He12
# Slot 1 (PCIEX16):  Sedna PCIe Quad M.2 SATA III (6G) SSD Adapter (12TB)
# Slot 2 (PCIEX1_1): Sedna PCIe Dual M.2 SATA III (6G) SSD Adapter (4TB)
# Slot 3 (PCIEX8):   NVIDIA T400
# Slot 4 (PCIEX1_2): Sedna PCIe Dual M.2 SATA III (6G) SSD Adapter (4TB)
# Slot 5 (PCIEX4):   Sedna PCIe Quad M.2 SATA III (6G) SSD Adapter (12TB)

{ config, inputs, lib, pkgs, platform, username, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    ./disks.nix
    ./disks-home.nix
    ./disks-snapraid.nix
    ./disks-snapshot.nix
    ../_mixins/services/filesync.nix
    ../_mixins/services/tailscale
  ];

  boot = {
    blacklistedKernelModules = lib.mkDefault [ "nouveau" ];
    initrd.availableKernelModules = [ "ahci" "nvme" "uas" "usbhid" "sd_mod" "xhci_pci" ];
    kernelModules = [ "kvm-intel" "nvidia" ];
    swraid = {
      enable = true;
      mdadmConf = "PROGRAM=true";
    };
  };

  environment.systemPackages = with pkgs; [
    mergerfs
    mergerfs-tools
  ];

  fileSystems."/srv/pool" = {
    fsType = "fuse.mergerfs";
    device = "/mnt/data_*";
    options = [
      "cache.files=partial"
      "category.create=mspmfs"
      "dropcacheonclose=true"
      "fsname=pool"
      "minfreespace=16G"
      "moveonenospc=true"
    ];
  };

  # Use passed hostname to configure basic networking
  networking = {
    defaultGateway = "192.168.2.1";
    firewall = {
      trustedInterfaces = [ "eth0" ];
    };
    interfaces.eth0.mtu = 1462;
    interfaces.eth0.ipv4.addresses = [{
      address = "192.168.2.18";
      prefixLength = 24;
    }];
    useDHCP = lib.mkForce false;
    usePredictableInterfaceNames = false;
  };

  hardware = {
    nvidia = {
      package = lib.mkForce config.boot.kernelPackages.nvidiaPackages.production;
      prime = {
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:2:0:0";
        # Make the Intel iGPU default. The NVIDIA T400 is for CUDA/NVENC
        reverseSync.enable = true;
      };
      nvidiaSettings = false;
    };
  };

  services = {
    snapraid = {
      enable = true;
      exclude = [
        "/.state_data/"
      ];
      extraConfig = ''
        autosave 256
        pool /srv/pool_ro
      '';
      contentFiles = [
        "/home/${username}/.snapraid.content"
        "/mnt/data_01/.snapraid.content"
        "/mnt/data_06/.snapraid.content"
      ];
      dataDisks = {
        d1 = "/mnt/data_01/";
        d2 = "/mnt/data_02/";
        d3 = "/mnt/data_03/";
        d4 = "/mnt/data_04/";
        d5 = "/mnt/data_05/";
        d6 = "/mnt/data_06/";
        d7 = "/mnt/data_07/";
        d8 = "/mnt/data_08/";
      };
      parityFiles = [
        "/mnt/parity_01/snapraid.parity"
        "/mnt/parity_02/snapraid.parity"
      ];
      touchBeforeSync = true;
    };
    udev.extraRules = ''
      # Remove NVIDIA Audio devices, if present
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto", ATTR{remove}="1"
    '';
  };

  #Seed the initial directories to coerce mergerfs epmfs
  # - data_01 and data_06 are the largest directories (4TB)
  systemd.tmpfiles.rules = [
    "d /mnt/data_01/Films           0755 ${username} users"
    "d /mnt/data_02/Films_Education 0755 ${username} users"
    "d /mnt/data_02/TV              0755 ${username} users"
    "d /mnt/data_03/Films_Home      0755 ${username} users"
    "d /mnt/data_03/Projects        0755 ${username} users"
    "d /mnt/data_03/Internet        0755 ${username} users"
    "d /mnt/data_04/Retro           0755 ${username} users"
    "d /mnt/data_05/Retro           0755 ${username} users"
    "d /mnt/data_06/Films           0755 ${username} users"
    "d /mnt/data_07/Films_Short     0755 ${username} users"
    "d /mnt/data_07/TV              0755 ${username} users"
    "d /mnt/data_08/TV_Kids         0755 ${username} users"
    "d /mnt/data_08/Films_Kids      0755 ${username} users"
    "d /mnt/data_08/Internet_Kids   0755 ${username} users"
    "d /mnt/parity_01 0755 ${username} users"
    "d /mnt/parity_02 0755 ${username} users"
    "d /srv/pool_ro   0755 ${username} users"
    "d /srv/pool      0755 ${username} users"
  ];
}
