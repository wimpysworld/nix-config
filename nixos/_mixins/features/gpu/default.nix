{ config, desktop, hostname, lib, pkgs, ... }:
let
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
  isWorkstation = if (desktop != null) then true else false;
  hasNvidiaGPU = lib.elem "nvidia" config.services.xserver.videoDrivers;
  hasAmdGPU = config.hardware.amdgpu.initrd.enable;
  hasIntelGPU = builtins.isString config.hardware.intelgpu.driver;
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
    ] ++ lib.optionals (isWorkstation && hasAmdGPU) [
      lact
    ] ++ lib.optionals (isWorkstation && hasNvidiaGPU) [
      gwe
    ] ++ lib.optionals (hasNvidiaGPU) [
      cudaPackages.cudatoolkit
      nvitop
      nvtopPackages.full
    ] ++ lib.optionals (!hasNvidiaGPU) [
      nvtopPackages.amd
    ] ++ lib.optionals (hasAmdGPU) [
      amdgpu_top
    ] ++ lib.optionals (config.hardware.amdgpu.opencl.enable) [
      rocmPackages.rocminfo
      rocmPackages.rocm-smi
    ];
  };
  hardware = {
    amdgpu = lib.mkIf (hasAmdGPU) {
      opencl.enable = lib.mkIf (isInstall) true;
    };
    opengl = {
      enable = true;
      driSupport = true;
      # Enable 32-bit support for Steam
      extraPackages = with pkgs; lib.optionals (hasIntelGPU) [
        intel-compute-runtime
      ];
    };
    nvidia = lib.mkIf (hasNvidiaGPU) {
      nvidiaSettings = lib.mkDefault isWorkstation;
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
    corectrl = lib.mkIf (isInstall && isWorkstation) {
      enable = config.hardware.cpu.amd.updateMicrocode;
      gpuOverclock.enable = hasAmdGPU;
    };
  };

  # Enable `lact` daemon for AMD GPUs
  systemd.services.lactd = lib.mkIf (hasAmdGPU) {
    description = "AMDGPU Control Daemon";
    enable = true;
    serviceConfig = {
      ExecStart = "${pkgs.lact}/bin/lact daemon";
    };
    wantedBy = ["multi-user.target"];
  };
}
