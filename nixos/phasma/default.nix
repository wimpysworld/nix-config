{ config, inputs, lib, pkgs, platform, username, ... }:
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

  # Mount bcachefs using UUID and via initrd to workaround issues with systemd
  # - https://www.reddit.com/r/bcachefs/comments/17y0ydd/psa_for_those_having_trouble_with_mountingbooting/
  # - https://discourse.nixos.org/t/how-can-i-install-specifically-util-linux-from-unstable/38637/7?u=wimpy
  # - https://github.com/systemd/systemd/issues/8234
  fileSystems."/" = lib.mkForce {
    #device = "UUID=caf2a42b-ae3e-4e1d-bc1f-b9a881403b73";
    device = "/dev/nvme0n1p2:/dev/nvme1n1:/dev/nvme2n1";
    fsType = "bcachefs";
    neededForBoot = true;
    options = [ "defaults" "relatime" "nodiratime" "background_compression=lz4:0" "compression=lz4:1" "discard" ];
  };

  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };

  fileSystems."/mnt/borg" = lib.mkForce {
    #device = "UUID=bef8c5bb-1fa6-4106-b546-0ebf1fc00c3a";
    device = "/dev/sda:/dev/sdb:/dev/sdc";
    fsType = "bcachefs";
    neededForBoot = true;
    options = [ "defaults" "relatime" "nodiratime" "discard" "nofail" ];
  };

  boot = {
    blacklistedKernelModules = lib.mkDefault [ "nouveau" ];
    initrd.availableKernelModules = [ "nvme" "ahci" "xhci_pci" "usbhid" "uas" "sd_mod" ];
    kernelModules = [ "amdgpu" "kvm-amd" "nvidia" ];
    kernelParams = [ "video=3440x1440@60" ];
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
        # Make the Radeon RX6700 XT default; the NVIDIA T600 is for CUDA/NVENC
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
    # Auto login because bcachefs unlocking is the authentication mechanism
    xserver.displayManager.autoLogin.user = "${username}";
  };
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
