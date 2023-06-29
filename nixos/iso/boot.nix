{ lib, pkgs, ... }: {
  boot = {
    blacklistedKernelModules = lib.mkDefault [ ];
    consoleLogLevel = 3;
    extraModulePackages = with config.boot.kernelPackages; [ ];
    extraModprobeConfig = lib.mkDefault ''
    '';
    initrd = {
      availableKernelModules = [ ];
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
  };
}
