# Motherboard: ROG Crosshair VIII Impact
# CPU:         AMD Ryzen 9 5950X
# GPU:         NVIDIA RTX 3080Ti
# RAM:         64GB DDR4
# NVME:        2TB Corsair MP600
# NVME:        4TB Corsair MP600
# SATA:        4TB Samsung 870 QVO
# SATA:        4TB Samsung 870 QVO

{ config, inputs, lib, pkgs, platform, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    (import ./disks.nix { })
    ../_mixins/hardware/gpu.nix
    ../_mixins/hardware/systemd-boot.nix
    ../_mixins/hardware/streamdeck.nix
    ../_mixins/services/bluetooth.nix
    ../_mixins/services/filesync.nix
    ../_mixins/services/openrazer.nix
    ../_mixins/services/pipewire.nix
    ../_mixins/services/tailscale.nix
    ../_mixins/services/zerotier-gaming.nix
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

  # UUID=ac6a2f42-bf5b-42bf-bbb2-2bb83a6af615 /mnt/snapshot auto defaults,x-parent=0f904a98:9d3109df:867172aa:c68c98f0 0 0
  fileSystems."/mnt/snapshot" = {
    device = "/dev/disk/by-label/snapshot";
    fsType = "xfs";
    options = [ "defaults" "relatime" "nodiratime" ];
  };

  swapDevices = [{
    device = "/swap";
    size = 2048;
  }];

  boot = {
    blacklistedKernelModules = lib.mkDefault [ "nouveau" ];
    initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "sd_mod" ];
    initrd.kernelModules = [ "nvidia" ];
    kernelModules = [ "kvm-amd" "nvidia" ];
    kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
    swraid.enable = true;
  };

  # https://nixos.wiki/wiki/PipeWire
  # Debugging
  #  - pw-top                              # see live stats
  #  - journalctl -b0 --user -u pipewire   # see logs (spa resync in "bad")
  #  - See Scripts/pw-quantum.sh for runtime tweaking
  environment.etc = {
    "pipewire/pipewire.conf.d/92-fix-resync.conf".text = ''
      context.properties = {
        default.clock.rate = 48000
        default.clock.quantum = 1024
        default.clock.min-quantum = 1024
        default.clock.max-quantum = 1024
      }
    '';
  };

  hardware = {
    nvidia = {
      package = lib.mkForce config.boot.kernelPackages.nvidiaPackages.production;
      prime.offload.enable = false;
    };
    xone.enable = true;
  };

  services = {
    hardware.openrgb = {
      enable = true;
      motherboard = "amd";
      package = pkgs.openrgb-with-all-plugins;
    };
  };
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
