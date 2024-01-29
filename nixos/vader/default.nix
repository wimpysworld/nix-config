{ config, inputs, lib, pkgs, platform, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
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

  # Mount bcachefs using multi-device path via initrd to workaround issues with systemd
  # - https://www.reddit.com/r/bcachefs/comments/17y0ydd/psa_for_those_having_trouble_with_mountingbooting/
  # - https://discourse.nixos.org/t/how-can-i-install-specifically-util-linux-from-unstable/38637/7?u=wimpy
  # - https://github.com/systemd/systemd/issues/8234
  fileSystems = {
    "/" = lib.mkForce {
      #device = "UUID=cafeface-b007-b007-b007-0c278079e5e6";
      device = "/dev/disk/by-label/root";
      fsType = "bcachefs";
      neededForBoot = true;
      options = [ "defaults" "relatime" "nodiratime" "background_compression=lz4:0" "compression=lz4:1" "discard" ];
    };
    "/boot" = lib.mkForce {
      device = "/dev/disk/by-label/ESP";
      fsType = "vfat";
    };
    "/home" = lib.mkForce {
      #device = "UUID=deadbeef-da7a-da7a-da7a-ab86f7c169a6";
      device = "/dev/nvme1n1:/dev/nvme2n1:/dev/sda:/dev/sdb:/dev/sdc";
      fsType = "bcachefs";
      neededForBoot = true;
      options = [ "defaults" "relatime" "nodiratime" "background_compression=lz4:0" "compression=lz4:1" "discard" ];
    };
  };

  boot = {
    blacklistedKernelModules = lib.mkDefault [ "nouveau" ];
    initrd.availableKernelModules = [ "nvme" "ahci" "xhci_pci" "usbhid" "uas" "sd_mod" ];
    kernelModules = [ "amdgpu" "kvm-amd" "nvidia" ];
    kernelParams = [ "video=2560x1440@60" ];
    # Disable Plymouth because bcachefs unlocking doesn't work with it via initrd
    plymouth = {
      enable = lib.mkForce false;
    };
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
        amdgpuBusId = "PCI:34:0:0";
        nvidiaBusId = "PCI:31:0:0";
        # Make the Radeon RX6700 XT default; the NVIDIA T1000 is for CUDA/NVENC
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
    xserver.videoDrivers = [ "amdgpu" "nvidia" ];
  };
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
