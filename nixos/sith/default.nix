# Motherboard:
# CPU:         AMD Ryzen 5900X
# GPU:         Radeon RX 6700
# GPU:         NVIDIA T6000
# CAP:         Magewell Pro Capture Dual HDMI
# RAM:         128GB DDR4
# NVME:        2TB Corsair MP600
# NVME:        4TB Corsair MP600
# NVME:        4TB Corsair MP510
# SATA:        4TB Samsung 860 EVO

{ config, inputs, lib, pkgs, platform, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    (import ./disks.nix { })
    (import ./disks-home.nix { })
    ../_mixins/linux/latest.nix
    ../_mixins/hardware/gpu.nix
    ../_mixins/hardware/systemd-boot.nix
    ../_mixins/hardware/streamdeck.nix
    ../_mixins/services/bluetooth.nix
    ../_mixins/services/clamav.nix
    ../_mixins/services/filesync.nix
    ../_mixins/services/openrazer.nix
    ../_mixins/services/pipewire.nix
    ../_mixins/services/tailscale.nix
    ../_mixins/services/zerotier-gaming.nix
    ../_mixins/virt
  ];

  # disko does handle mounting but I want to mount by-partlabel
  #fileSystems."/" = lib.mkForce {
  #  device = "/dev/disk/by-partlabel/root";
  #  fsType = "xfs";
  #  options = [ "defaults" "relatime" "nodiratime" ];
  #};

  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-partlabel/ESP";
    fsType = "vfat";
    options = [ "defaults" "umask=0077" ];
  };

  fileSystems."/home" = lib.mkForce {
    device = "/dev/disk/by-label/home";
    fsType = "bcachefs";
    options = [ "defaults" "relatime" "discard" ];
  };

  swapDevices = [{
    device = "/.swap";
    size = 2048;
  }];

  boot = {
    blacklistedKernelModules = lib.mkDefault [ "nouveau" ];
    initrd.availableKernelModules = [ "nvme" "ahci" "xhci_pci" "usbhid" "uas" "sd_mod" ];
    kernelModules = [ "amdgpu" "kvm-amd" "nvidia" ];
  };

  # https://nixos.wiki/wiki/PipeWire
  # Debugging
  #  - pw-top                              # see live stats
  #  - journalctl -b0 --user -u pipewire   # see logs (spa resync in "bad")
  # default.clock.quantum = 512
  # default.clock.max-quantum = 2048
  environment.etc = {
    "pipewire/pipewire.conf.d/92-fix-resync.conf".text = ''
      context.properties = {
        default.clock.rate = 48000
        default.clock.min-quantum = 64
      }
    '';
  };
  hardware = {
    mwProCapture.enable = true;
    nvidia = {
      package = lib.mkForce config.boot.kernelPackages.nvidiaPackages.production;
      prime = {
        amdgpuBusId = "PCI:23:0:0";
        nvidiaBusId = "PCI:3:0:0";
        # Make the Radeon RX6700 default. The NVIDIA T600 is on for CUDA/NVENC
        reverseSync.enable = true;
      };
      nvidiaSettings = false;
    };
  };

  services = {
    hardware.openrgb = {
      enable = true;
      motherboard = "amd";
      package = pkgs.openrgb-with-all-plugins;
    };
    xserver.videoDrivers = [ "amdgpu" "nvidia" ];
  };
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
