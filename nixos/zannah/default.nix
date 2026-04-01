{
  config,
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

  systemd.tmpfiles.rules = [
    "d /home/${config.noughty.user.name}/.cache 0755 ${config.noughty.user.name} users -"
    "d /home/${config.noughty.user.name}/.lima 0755 ${config.noughty.user.name} users -"
    "d /home/${config.noughty.user.name}/.local 0755 ${config.noughty.user.name} users -"
    "d /home/${config.noughty.user.name}/.local/share 0755 ${config.noughty.user.name} users -"
    "d /home/${config.noughty.user.name}/.local/share/containers 0700 ${config.noughty.user.name} users -"
    "d /home/${config.noughty.user.name}/Quickemu 0755 ${config.noughty.user.name} users -"
    "d /home/${config.noughty.user.name}/Development 0755 ${config.noughty.user.name} users -"
    "d /home/${config.noughty.user.name}/Volatile 0755 ${config.noughty.user.name} users -"
  ];

}
