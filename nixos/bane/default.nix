{
  inputs,
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
      "usbhid"
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
      width = 2560;
      height = 1600;
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
}
