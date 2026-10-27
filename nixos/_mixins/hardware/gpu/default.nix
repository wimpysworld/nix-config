{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  username = config.noughty.user.name;
  initrdGpuKernelModulesByVendor = {
    amd = [ "amdgpu" ];
    intel = [ "i915" ];
    nvidia = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];
  };
  initrdGpuKernelModules =
    if host.gpu.primaryVendor == null then
      [ ]
    else
      initrdGpuKernelModulesByVendor.${host.gpu.primaryVendor} or [ ];
in
lib.mkIf (!host.is.iso && (host.is.workstation || host.gpu.hasAny)) {

  boot = {
    initrd.kernelModules = initrdGpuKernelModules;
    # If an NVIDIA GPU is present, blacklist the nouveau driver.
    blacklistedKernelModules = lib.optionals host.gpu.hasNvidia [ "nouveau" ];
    # Unlock access to adjust AMD GPU clocks and voltages via sysfs on desktops.
    kernelParams = lib.optionals (host.gpu.hasAmd && !host.is.laptop) [
      "amdgpu.ppfeaturemask=0xfff7ffff"
    ];
  };

  environment = {
    systemPackages =
      with pkgs;
      lib.optionals (host.is.workstation && host.gpu.hasAmd && !host.is.laptop) [ lact ]
      ++ lib.optionals host.gpu.hasCuda [
        cudaPackages.cudatoolkit
      ];
  };
  hardware = {
    amdgpu = lib.mkIf (host.gpu.hasAmd && (host.gpu.hasROCm || !host.is.laptop)) {
      opencl.enable = true;
    };
    graphics = {
      enable = true;
      enable32Bit = lib.mkForce host.is.workstation;
      extraPackages =
        with pkgs;
        lib.optionals host.gpu.hasIntel [
          intel-compute-runtime
          intel-media-driver
        ];
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

  # Enable lact daemon for AMD GPU control on desktop workstations.
  systemd.services.lactd = lib.mkIf (host.gpu.hasAmd && host.is.workstation && !host.is.laptop) {
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
