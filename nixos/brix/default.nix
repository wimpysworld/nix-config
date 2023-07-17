# Gigabyte GB-BXCEH-2955 (Celeron 2955U: Haswell)

{ inputs, lib, pkgs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-intel
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    (import ./disks.nix { })
    ../_mixins/hardware/systemd-boot.nix
    ../_mixins/services/bluetooth.nix
    ../_mixins/services/zerotier.nix
    ../_mixins/virt
  ];

  # disko does manage mounting of / /boot /home, but I want to mount by-partlabel
  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-partlabel/root";
    fsType = "xfs";
    options = [ "defaults" "relatime" "nodiratime" ];
  };

  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-partlabel/ESP";
    fsType = "vfat";
  };

  fileSystems."/home" = lib.mkForce {
    device = "/dev/disk/by-partlabel/home";
    fsType = "xfs";
    options = [ "defaults" "relatime" "nodiratime" ];
  };

  swapDevices = [{
    device = "/swap";
    size = 2048;
  }];

  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usbhid" "uas" "sd_nod" ];
    kernelModules = [ "kvm-intel" ];
    kernelPackages = lib.mkDefault pkgs.linuxPackages_5_15;
  };

  # Use passed hostname to configure basic networking
  networking = {
    defaultGateway = "192.168.2.1";
    interfaces.enp3s0.ipv4.addresses = [{
      address = "192.168.2.10";
      prefixLength = 24;
    }];
    nameservers = [ "192.168.2.1" ];
    useDHCP = lib.mkForce false;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
