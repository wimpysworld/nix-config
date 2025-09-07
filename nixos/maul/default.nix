{
  inputs,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    ./disks.nix
  ];

  boot = {
    initrd = {
      availableKernelModules = [
        "nvme"
        "ahci"
        "xhci_pci"
        "usbhid"
        "uas"
        "usb_storage"
        "sd_mod"
      ];
      kernelModules = [
        "kvm-amd"
        "nvidia"
      ];
    };
  };

  hardware = {
    nvidia = {
      open = false;
      prime.offload.enable = false;
    };
  };

  services = {
    xserver.videoDrivers = [
      "nvidia"
    ];
  };
}
