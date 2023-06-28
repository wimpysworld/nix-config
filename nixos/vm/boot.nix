{ config, lib, pkgs, ... }: {
  boot = {
    blacklistedKernelModules = lib.mkDefault [ ];
    consoleLogLevel = 3;
    extraModulePackages = with config.boot.kernelPackages; [ ];
    extraModprobeConfig = lib.mkDefault ''
    '';
    initrd = {
      availableKernelModules = [
        "ahci"
        "ehci_pci"
        "ohci_pci"
        "sr_mod"
        "usbhid"
        "virtio_blk"
        "virtio_pci"
        "xhci_pci"
      ];
      kernelModules = [ ];
      verbose = false;
    };

    kernelModules = [
      "vhost_vsock"
    ];

    kernelPackages = pkgs.linuxPackages_latest;
    kernel.sysctl = {
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
  };
}
