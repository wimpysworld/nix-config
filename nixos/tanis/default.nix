{
  inputs,
  lib,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-z13-gen1
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

  noughty.host.displays = [
    {
      output = "eDP-1";
      width = 1920;
      height = 1200;
      primary = true;
      workspaces = [
        1
        2
        3
        4
        5
        6
        7
        8
      ];
    }
  ];

  services.fprintd.enable = lib.mkForce false;
}
