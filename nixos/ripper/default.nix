# Motherboard: Gigabye TRX40 DESIGNARE
# CPU:         AMD Ryzen Threadripper 3970X
# GPU:         Radeon RX 6700
# GPU:         NVIDIA T1000
# CAP:         Magewell Pro Capture Quad HDMI
# RAM:         256GB DDR4
# NVME:        500GB Corsair MP600
# NVME:        1TB Corsair MP600
# NVME:        4TB Corsair MP510
# NVME:        4TB Corsair MP510
# SATA:        12TB
# SATA:        12TB
# Storage:     AORUS Gen4 AIC Adaptor
# NVME:        AORUS NVMe Gen4 SSD 2TB
# NVME:        AORUS NVMe Gen4 SSD 2TB
# NVME:        AORUS NVMe Gen4 SSD 2TB
# NVME:        AORUS NVMe Gen4 SSD 2TB

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

  # disko does manage mounting / and /boot, but I want to mount by-partlabel
  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-partlabel/root";
    fsType = "xfs";
    options = [ "defaults" "relatime" "nodiratime" ];
  };

  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-partlabel/ESP";
    fsType = "vfat";
  };

  fileSystems."/mnt/archive" = {
    device = "/dev/disk/by-label/archive";
    fsType = "xfs";
    options = [ "defaults" "relatime" "nodiratime" ];
  };

  swapDevices = [{
    device = "/swap";
    size = 2048;
  }];

  boot = {
    blacklistedKernelModules = lib.mkDefault [ "nouveau" ];
    initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
    kernelModules = [ "amdgpu" "kvm-amd" "nvidia" ];
    kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
    swraid.enable = true;
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
        # Make the Radeon RX6700 default. The NVIDIA T1000 is on for CUDA/NVENC
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
    cron = {
      enable = true;
      systemCronJobs = [
        "*/30 * * * * martin /home/martin/Scripts/backup/sync-legoworlds.sh >> /home/martin/Games/Steam_Backups/legoworlds.log"
        "42 * * * * martin /home/martin/Scripts/backup/sync-hotshotracing.sh >> /home/martin/Games/Steam_Backups/hotshotracing.log"
      ];
    };
    hardware.openrgb = {
      enable = true;
      motherboard = "amd";
      package = pkgs.openrgb-with-all-plugins;
    };
    xserver.videoDrivers = [ "amdgpu" "nvidia" ];
  };
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
