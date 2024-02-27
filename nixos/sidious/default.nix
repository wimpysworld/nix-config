# Lenovo ThinkPad P1 Gen 1

{ inputs, lib, pkgs, platform, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p1
    inputs.nixos-hardware.nixosModules.common-gpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-hidpi
    (import ./disks.nix { })
    ../_mixins/kernel/bcachefs.nix
    ../_mixins/services/filesync.nix
    ../_mixins/services/pipewire.nix
    ../_mixins/services/tailscale.nix
    ../_mixins/virt
  ];

  boot = {
    blacklistedKernelModules = lib.mkDefault [ "nouveau" ];
    initrd.availableKernelModules = [ "xhci_pci" "nvme" "uas" "usb_storage" "sd_mod" ];
    kernelModules = [ "i915" "kvm-intel" "nvidia" ];
  };

  hardware = {
    nvidia = {
      prime = {
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
        # Make the Intel iGP default. The NVIDIA Quadro is for CUDA/NVENC
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
  services = {
    fprintd = {
      enable = lib.mkDefault false;
      #tod.enable = true;
      #tod.driver = pkgs.libfprint-2-tod1-vfs0090;
    };
    kmscon.extraConfig = lib.mkForce ''
      font-size=24
      xkb-layout=gb
    '';
  };
  nixpkgs.hostPlatform = lib.mkDefault "${platform}";
}
