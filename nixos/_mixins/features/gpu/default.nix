{ config, desktop, hostname, lib, pkgs, ... }:
let
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
  isWorkstation = if (desktop != null) then true else false;
  hasNvidiaGPU = lib.elem "nvidia" config.services.xserver.videoDrivers;
  hasAmdGPU = lib.elem "amdgpu" config.services.xserver.videoDrivers;
in
lib.mkIf (isInstall) {
  environment = {
    systemPackages = with pkgs; [
      clinfo
      libva-utils
      vdpauinfo
      vulkan-tools
    ] ++ lib.optionals (isWorkstation) [
      gpu-viewer
    ] ++ lib.optionals (hasNvidiaGPU) [
      nvitop
      nvtopPackages.full
    ] ++ lib.optionals (!hasNvidiaGPU) [
      nvtopPackages.amd
    ];
  };
  hardware = {
    opengl = {
      enable = true;
      driSupport = true;
      # Enable 32-bit support for Steam
      driSupport32Bit = config.programs.steam.enable;
    };
  };
  # TODO: Change to this for >= 24.11
  #hardware
  #  graphics = {
  #    enable = true;
  #    enable32Bit = config.programs.steam.enable;
  #  };
  #};
  programs = {
    corectrl = lib.mkIf (isWorkstation) {
      enable = config.hardware.cpu.amd.updateMicrocode;
      gpuOverclock.enable = hasAmdGPU;
    };
  };
}
