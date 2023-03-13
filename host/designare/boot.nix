{ config, lib, pkgs, ... }: {
  boot = {
    blacklistedKernelModules = lib.mkDefault [ "nouveau" ];
    consoleLogLevel = 3;
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
    extraModprobeConfig = lib.mkDefault ''
    blacklist nouveau
    options v4l2loopback devices=1 video_nr=13 card_label="OBS Virtual Camera" exclusive_caps=1
    '';
    initrd = {
      availableKernelModules = [
        "ahci"
        "nvme"
        "rtsx_pci_sdmmc"
        "sd_mod"
        "sdhci_pci"
        "uas"
        "usbhid"
        "usb_storage"
        "xhci_pci"
      ];
      kernelModules = [
        "amdgpu"
      ];
      verbose = false;
    };

    kernelModules = [
      "kvm-intel"
      "nvidia"
      "vhost_vsock"
    ];
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [ "quiet" "mitigations=off" ];
    kernel.sysctl = {
      "kernel.sysrq" = 1;
      "kernel.printk" = "3 3 3 3";
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.configurationLimit = 10;
      systemd-boot.enable = true;
      systemd-boot.memtest86.enable = true;
      timeout = 10;
    };
    plymouth.enable = true;
  };
}
