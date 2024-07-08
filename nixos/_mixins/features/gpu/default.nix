{ config, desktop, hostname, lib, pkgs, ... }:
let
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
  isGamestation = if (hostname == "phasma" || hostname == "vader") && (desktop != null) then true else false;
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
    ] ++ lib.optionals (hasNvidiaGPU) [
      nvtopPackages.full
    ] ++ lib.optionals (!hasNvidiaGPU) [
      nvtopPackages.amd
    ];
  };
  hardware = {
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };
  };
  # TODO: Change to this for >= 24.11
  #hardware
  #  graphics = {
  #    enable = true;
  #    enable32Bit = true;
  #  };
  #};

}
