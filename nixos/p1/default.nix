# Lenovo ThinkPad P1 Gen 1

{ inputs, lib, pkgs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p1
    inputs.nixos-hardware.nixosModules.common-gpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-hidpi
    (import ./disks.nix { })
    ../_mixins/hardware/systemd-boot.nix
    ../_mixins/services/bluetooth.nix
    ../_mixins/services/maestral.nix
    ../_mixins/services/pipewire.nix
    ../_mixins/services/tailscale.nix
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
    blacklistedKernelModules = lib.mkDefault [ "nouveau" ];
    initrd.availableKernelModules = [ "xhci_pci" "nvme" "uas" "usb_storage" "sd_mod" ];
    kernelModules = [ "i915" "kvm-intel" "nvidia" ];
    kernelPackages = pkgs.linuxPackages_latest;
    loader.systemd-boot.consoleMode = "max";
  };

  environment.systemPackages = with pkgs; [
    nvtop
  ];

  hardware = {
    nvidia = {
      prime = {
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
        # Make the Intel iGPP default. The NVIDIA Quadro is for CUDA/NVENC
        reverseSync.enable = true;
      };
      nvidiaSettings = false;
    };
  };

  # libfprint-2-tod1-vfs0090 in nixpkgs is from https://gitlab.freedesktop.org/3v1n0/libfprint-tod-vfs0090
  # - Supports Validity Sensor 138a:0090 and 138a:0097
  # The ThinkPad P1 Gen 1 has a Synaptics Sensor 06cb:009a; the project below supports it
  # - https://gitlab.com/bingch/libfprint-tod-vfs0090
  # - https://github.com/uunicorn/python-validity
  # - https://github.com/tester1969/pam-validity
  # TODO: Package the above project as libfprint-2-tod1-vfs009a
  services.fprintd = {
    enable = lib.mkDefault false;
    #tod.enable = true;
    #tod.driver = pkgs.libfprint-2-tod1-vfs0090;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
