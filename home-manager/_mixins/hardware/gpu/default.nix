{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
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
  # Remove the TUI desktop entry and drop the "(GUI)" suffix from the GUI
  # entry; all other packaged keys are kept.
  amdgpuTop = pkgs.symlinkJoin {
    name = "amdgpu_top-launcher";
    paths = [ pkgs.amdgpu_top ];
    postBuild = ''
      apps="$out/share/applications"
      src="${pkgs.amdgpu_top}/share/applications"
      rm -f "$apps/amdgpu_top.desktop" "$apps/amdgpu_top-tui.desktop"
      sed 's/^Name=AMDGPU TOP (GUI)$/Name=AMDGPU TOP/' "$src/amdgpu_top.desktop" > "$apps/amdgpu_top.desktop"
    '';
  };
in
lib.mkIf (host.is.linux && (host.is.workstation || host.gpu.hasAny)) {
  home.packages =
    with pkgs;
    [
      clinfo
      libva-utils
      nvtopPackage
      vdpauinfo
      vulkan-tools
    ]
    ++ lib.optionals (host.is.workstation && host.gpu.hasNvidia) [ gwe ]
    ++ lib.optionals host.gpu.hasNvidia [ nvitop ]
    ++ lib.optionals host.gpu.hasAmd [
      amdgpuTop
      rocmPackages.rocminfo
      rocmPackages.rocm-smi
    ]
    ++ lib.optionals (!host.gpu.hasAmd) [ intel-gpu-tools ];

  xdg = lib.mkIf host.is.workstation {
    desktopEntries = {
      nvtop = {
        name = "nvtop";
        noDisplay = true;
      };
    };
  };
}
