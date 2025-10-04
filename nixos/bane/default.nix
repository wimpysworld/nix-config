{
  inputs,
  lib,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.framework-16-7040-amd
    ./disks.nix
  ];

  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "sd_mod"
      "thunderbolt"
      "uas"
      "xhci_pci"
    ];
    initrd.systemd.enable = true;
    kernelModules = [
      "amdgpu"
      "kvm-amd"
    ];
  };
}
