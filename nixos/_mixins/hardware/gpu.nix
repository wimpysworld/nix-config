{ config, lib, pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    clinfo
    libva-utils
    python311Packages.gpustat
    vdpauinfo
  ]
  ++ (if lib.elem "nvidia" config.services.xserver.videoDrivers then [ nvtop ] else [  nvtop-amd ]);
}
