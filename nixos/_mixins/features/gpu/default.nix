{
  config,
  isInstall,
  isWorkstation,
  lib,
  pkgs,
  username,
  ...
}:
let
  hasNvidiaGPU = lib.elem "nvidia" config.services.xserver.videoDrivers;
  hasAmdGPU = config.hardware.amdgpu.initrd.enable;
  hasIntelGPU = lib.any (mod: lib.elem mod config.boot.initrd.kernelModules) [
    "i915"
    "xe"
  ];
in
lib.mkIf isInstall {

  boot = {
    # If the "nvidia" driver is enabled, blacklist the "nouveau" driver
    blacklistedKernelModules = lib.optionals hasNvidiaGPU [ "nouveau" ];
    # Unlock access to adjust AMD GPU clocks and voltages via sysfs
    kernelParams = lib.optionals hasAmdGPU [ "amdgpu.ppfeaturemask=0xfff7ffff" ];
  };

  environment = {
    systemPackages =
      with pkgs;
      [
        clinfo
        libva-utils
        vdpauinfo
        vulkan-tools
      ]
      ++ lib.optionals isWorkstation [ gpu-viewer ]
      ++ lib.optionals (isWorkstation && hasAmdGPU) [ lact ]
      ++ lib.optionals (isWorkstation && hasNvidiaGPU) [ gwe ]
      ++ lib.optionals hasNvidiaGPU [
        cudaPackages.cudatoolkit
        nvitop
        nvtopPackages.full
      ]
      ++ lib.optionals (!hasNvidiaGPU) [ nvtopPackages.amd ]
      ++ lib.optionals hasAmdGPU [ amdgpu_top ]
      ++ lib.optionals config.hardware.amdgpu.opencl.enable [
        rocmPackages.rocminfo
        rocmPackages.rocm-smi
      ]
      ++ lib.optionals hasIntelGPU [ intel-gpu-tools ];
  };
  hardware = {
    amdgpu = lib.mkIf hasAmdGPU { opencl.enable = isInstall; };
    graphics = {
      enable = true;
      enable32Bit = lib.mkForce isInstall;
      extraPackages = with pkgs; lib.optionals hasIntelGPU [ intel-compute-runtime ];
    };
    nvidia = lib.mkIf hasNvidiaGPU {
      nvidiaSettings = lib.mkDefault isWorkstation;
    };
  };

  # Allow power and thermal control for NVIDIA GPUs
  services.xserver = lib.mkIf hasNvidiaGPU {
    deviceSection = ''
      Option "Coolbits" "28"
    '';
  };

  # Enable `lact` daemon for AMD GPUs
  systemd.services.lactd = lib.mkIf hasAmdGPU {
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
