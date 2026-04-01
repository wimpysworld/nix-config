{
  inputs,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series
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
    kernelParams = [
      "video=DP-1:3440x1440@100"
      "video=DP-2:1920x1080@60"
      "video=HDMI-A-1:2560x1600@120"
    ];
  };

  hardware.mwProCapture.enable = true;

}
