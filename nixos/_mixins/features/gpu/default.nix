{ config, desktop, hostname, lib, pkgs, username, ... }:
let
  isInstall = builtins.substring 0 4 hostname != "iso-";
  isWorkstation = builtins.isString desktop;
  hasNvidiaGPU = lib.elem "nvidia" config.services.xserver.videoDrivers;
  hasAmdGPU = config.hardware.amdgpu.initrd.enable;
  hasIntelGPU = lib.any (mod: lib.elem mod config.boot.initrd.kernelModules) ["i915" "xe"];
in
lib.mkIf (isInstall) {

  # If the "nvidia" driver is enabled, blacklist the "nouveau" driver
  boot = lib.mkIf (hasNvidiaGPU) {
    blacklistedKernelModules = lib.mkDefault [ "nouveau" ];
  };

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
      opencl.enable = isInstall;
    };
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = lib.mkForce isInstall;
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
  #    enable32Bit = lib.mkForce isInstall;
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

  users.users.${username}.extraGroups = lib.optional (config.hardware.opengl.enable) "video";
}
