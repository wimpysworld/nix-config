{ config, lib, pkgs, ... }: {
  boot = {
    blacklistedKernelModules = lib.mkDefault [ ];
    extraModulePackages = with config.boot.kernelPackages; [ ];
    extraModprobeConfig = lib.mkDefault ''
    '';
    initrd = {
      availableKernelModules = [ ];
      kernelModules = [ ];
    };

    kernelModules = [
      "vhost_vsock"
    ];
  };
}
