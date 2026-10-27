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
  # Hide the TUI desktop entry from application launchers and drop the
  # "(GUI)" suffix from the GUI entry; all other packaged keys are kept.
  amdgpuTop = pkgs.symlinkJoin {
    name = "amdgpu_top-launcher";
    paths = [ pkgs.amdgpu_top ];
    postBuild = ''
      apps="$out/share/applications"
      src="${pkgs.amdgpu_top}/share/applications"
      rm -f "$apps/amdgpu_top.desktop" "$apps/amdgpu_top-tui.desktop"
      sed 's/^Name=AMDGPU TOP (GUI)$/Name=AMDGPU TOP/' "$src/amdgpu_top.desktop" > "$apps/amdgpu_top.desktop"
      sed '0,/^Type=Application$/s//Type=Application\nNoDisplay=true/' "$src/amdgpu_top-tui.desktop" > "$apps/amdgpu_top-tui.desktop"
    '';
  };
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
      [
        clinfo
        libva-utils
        nvtopPackage
        vdpauinfo
        vulkan-tools
      ]
      ++ lib.optionals host.is.workstation [ gpu-viewer ]
      ++ lib.optionals (host.is.workstation && host.gpu.hasAmd && !host.is.laptop) [ lact ]
      ++ lib.optionals (host.is.workstation && host.gpu.hasNvidia) [ gwe ]
      ++ lib.optionals host.gpu.hasCuda [
        cudaPackages.cudatoolkit
        nvitop
      ]
      ++ lib.optionals (host.gpu.hasAmd && host.is.workstation) [ amdgpuTop ]
      ++ lib.optionals config.hardware.amdgpu.opencl.enable [
        rocmPackages.rocminfo
        rocmPackages.rocm-smi
      ]
      ++ lib.optionals host.gpu.hasIntel [ intel-gpu-tools ];
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
