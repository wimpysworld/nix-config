{
  config,
  lib,
  pkgs,
  ...
}:
let
  host = config.noughty.host;
  username = config.noughty.user.name;
  # Select the lightest nvtop variant that covers the GPUs actually present.
  # nvtopPackages.full pulls in NVIDIA drivers and CUDA build dependencies,
  # which is wasteful and undesirable on systems without NVIDIA hardware.
  nvtopPackage =
    if builtins.length host.gpu.vendors > 1 then
      pkgs.nvtopPackages.full
    else if host.gpu.hasNvidia then
      pkgs.nvtopPackages.nvidia
    else if host.gpu.hasAmd then
      pkgs.nvtopPackages.amd
    else if host.gpu.hasIntel then
      pkgs.nvtopPackages.intel
    else
      pkgs.nvtopPackages.amd;
in
lib.mkIf (!host.is.iso) {

  boot = {
    # If an NVIDIA GPU is present, blacklist the nouveau driver.
    blacklistedKernelModules = lib.optionals host.gpu.hasNvidia [ "nouveau" ];
    # Unlock access to adjust AMD GPU clocks and voltages via sysfs.
    kernelParams = lib.optionals host.gpu.hasAmd [ "amdgpu.ppfeaturemask=0xfff7ffff" ];
  };

  environment = {
    systemPackages =
      with pkgs;
      [
        clinfo
        libva-utils
        nvtopPackage
        vdpauinfo
        vulkan-tools
      ]
      ++ lib.optionals host.is.workstation [ gpu-viewer ]
      ++ lib.optionals (host.is.workstation && host.gpu.hasAmd) [ lact ]
      ++ lib.optionals (host.is.workstation && host.gpu.hasNvidia) [ gwe ]
      ++ lib.optionals host.gpu.hasCuda [
        cudaPackages.cudatoolkit
        nvitop
      ]
      ++ lib.optionals (host.gpu.hasAmd && host.is.workstation) [ amdgpu_top ]
      ++ lib.optionals config.hardware.amdgpu.opencl.enable [
        rocmPackages.rocminfo
        rocmPackages.rocm-smi
      ]
      ++ lib.optionals host.gpu.hasIntel [ intel-gpu-tools ];
  };
  hardware = {
    amdgpu = lib.mkIf host.gpu.hasAmd { opencl.enable = true; };
    graphics = {
      enable = true;
      enable32Bit = lib.mkForce true;
      extraPackages = with pkgs; lib.optionals host.gpu.hasIntel [ intel-compute-runtime ];
    };
    nvidia = lib.mkIf host.gpu.hasNvidia {
      nvidiaSettings = lib.mkDefault host.is.workstation;
    };
  };

  # Allow power and thermal control for NVIDIA GPUs.
  services.xserver = lib.mkIf host.gpu.hasNvidia {
    deviceSection = ''
      Option "Coolbits" "28"
    '';
  };

  # Enable lact daemon for AMD GPU control on workstations.
  systemd.services.lactd = lib.mkIf (host.gpu.hasAmd && host.is.workstation) {
    description = "AMDGPU Control Daemon";
    enable = true;
    serviceConfig = {
      ExecStart = "${pkgs.lact}/bin/lact daemon";
    };
    wantedBy = [ "multi-user.target" ];
  };

  users.users.${username}.extraGroups = lib.optionals config.hardware.graphics.enable [
    "render"
    "video"
  ];
}
