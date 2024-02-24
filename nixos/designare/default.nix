# Motherboard: Gigabye Z390 Designare
# CPU:         Intel i9 9900K
# GPU:         Radeon RX6800
# GPU:         NVIDIA T600
# CAP:         Magewell Pro Capture Dual HDMI 11080
# RAM:         128GB DDR4
# NVME:        512GB Samsung 960 Pro
# NVME:        2TB Samsung 960 Pro
# Storage:     Sedna PCIe Dual 2.5 Inch SATA III (6G) SSD Adapter
# SATA:        1TB SanDisk SSD Plus
# SATA:        1TB SanDisk SSD Plus

{ config, inputs, lib, pkgs, platform, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    (import ./disks.nix { })
    ../_mixins/hardware/gpu.nix
    ../_mixins/hardware/systemd-boot.nix
    ../_mixins/services/bluetooth.nix
    ../_mixins/services/filesync.nix
    ../_mixins/services/openrazer.nix
    ../_mixins/services/pipewire.nix
    ../_mixins/services/tailscale.nix
    ../_mixins/virt
  ];

  swapDevices = [{
    device = "/swap";
    size = 2048;
  }];

  boot = {
    blacklistedKernelModules = lib.mkDefault [ "nouveau" ];
    initrd.availableKernelModules = [ "ahci" "nvme" "uas" "usbhid" "sd_mod" "xhci_pci" ];
    kernelModules = [ "amdgpu" "kvm-intel" "nvidia" ];
  };

  hardware = {
    mwProCapture.enable = true;
    nvidia = {
      package = lib.mkForce config.boot.kernelPackages.nvidiaPackages.production;
      prime = {
        amdgpuBusId = "PCI:3:0:0";
        nvidiaBusId = "PCI:4:0:0";
        # Make the Radeon RX6800 default. The NVIDIA T600 is for CUDA/NVENC
        reverseSync.enable = true;
      };
      nvidiaSettings = false;
    };
  };

  # Adjust MTU for Virgin Fibre
  # - https://search.nixos.org/options?channel=23.11&show=networking.networkmanager.connectionConfig&from=0&size=50&sort=relevance&type=packages&query=networkmanager
  networking.networkmanager.connectionConfig = {
    "ethernet.mtu" = 1462;
    "wifi.mtu" = 1462;
  };

  services = {
    hardware.openrgb = {
      enable = true;
      motherboard = "intel";
      package = pkgs.openrgb-with-all-plugins;
    };
    xserver.videoDrivers = [ "amdgpu" "nvidia" ];
  };
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
