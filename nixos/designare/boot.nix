{ config, lib, pkgs, ... }: {
  boot = {
    blacklistedKernelModules = lib.mkDefault [ "nouveau" ];
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
    extraModprobeConfig = lib.mkDefault ''
    blacklist nouveau
    options v4l2loopback devices=1 video_nr=13 card_label="OBS Virtual Camera" exclusive_caps=1
    '';
    initrd = {
      availableKernelModules = [
        "ahci"
        "nvme"
        "uas"
        "usbhid"
        "sd_mod"
        "xhci_pci"
      ];
      kernelModules = [
        "amdgpu"
      ];
    };

    kernelModules = [
      "kvm-intel"
      "nvidia"
      "vhost_vsock"
    ];

    kernelPackages = pkgs.linuxPackages_6_3;

    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.configurationLimit = 10;
      systemd-boot.enable = true;
      systemd-boot.memtest86.enable = true;
      timeout = 10;
    };
  };
}
