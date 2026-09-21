{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  blenderEnabled = host.is.workstation && noughtyLib.hostHasTag "gamedev";
  blenderConfigHome =
    if host.is.darwin then
      "${config.home.homeDirectory}/Library/Application Support/Blender"
    else
      "${config.xdg.configHome}/blender";
  blenderVersion = lib.versions.majorMinor blenderPackage.version;
  davinciResolve = pkgs.davinci-resolve.override { studioVariant = true; };
  # Blender's GPU render backend follows the host's compute GPU vendor:
  # AMD uses HIP (rocmSupport), NVIDIA uses CUDA/OptiX (cudaSupport). Other
  # vendors (Apple Metal, Intel) fall back to the default build. Derived from
  # gpu.compute.vendor rather than hasROCm/hasCuda, because those track
  # compute.acceleration, which the strix-halo hosts set to "vulkan" (a backend
  # Blender's renderer does not provide).
  blenderPackage =
    if host.gpu.compute.vendor == "amd" then
      pkgs.blender.override { rocmSupport = true; }
    else if host.gpu.compute.vendor == "nvidia" then
      pkgs.blender.override { cudaSupport = true; }
    else
      pkgs.blender;
in
{
  dconf = lib.mkIf (host.is.linux && host.is.workstation) {
    settings = {
      "org/gnome/SoundRecorder" = {
        audio-channel = "mono";
        audio-profile = "flac";
      };
    };
  };

  home.file = {
    "${blenderConfigHome}/${blenderVersion}/scripts/startup/agent_bridge.py" = lib.mkIf blenderEnabled {
      source = ./blender-agent-bridge.py;
    };
    "${blenderConfigHome}/${blenderVersion}/extensions/user_default/claude_blender" =
      lib.mkIf blenderEnabled
        {
          source = "${pkgs.blender-agent-bridge}/share/blender-agent-bridge/claude_blender";
        };
  };

  home.packages =
    with pkgs;
    lib.optionals (host.is.workstation && !(noughtyLib.hostHasTag "lima")) [
      audacity
    ]
    ++ lib.optionals (host.is.workstation && !(noughtyLib.hostHasTag "lima") && host.is.linux) [
      gimp3
      inkscape
    ]
    ++ lib.optionals blenderEnabled [
      blenderPackage
      blender-agent-bridge
    ]
    ++ lib.optionals (host.is.workstation && noughtyLib.hostHasTag "davinci") [
      davinciResolve
    ];
}
