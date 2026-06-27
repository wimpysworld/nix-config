{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  isVoxtypeHost = host.is.linux && host.is.workstation && noughtyLib.hostHasTag "voxtype";
  modelName =
    if host.gpu.compute.vram >= 64 then
      "large-v3"
    else if host.gpu.compute.vram >= 16 then
      "medium.en"
    else
      "small.en";
  voxtypePackage =
    if host.gpu.compute.acceleration == "cuda" then
      pkgs.voxtype-onnx-cuda
    else if host.gpu.compute.acceleration == "rocm" then
      pkgs.voxtype-rocm
    else
      pkgs.voxtype-vulkan;
in
lib.mkIf isVoxtypeHost {
  programs.voxtype = {
    enable = true;
    engine = "whisper";
    package = voxtypePackage;
    model.name = modelName;
    service.enable = true;
    settings = {
      state_file = "auto";
      audio.device = "default";
      hotkey.enabled = false;
      osd = {
        enabled = true;
        frontend = "gtk4";
        width_px = 400;
        height_px = 48;
        position = "bottom-center";
        margin_px = 24;
        top_margin = 0.85;
        opacity = 0.95;
        waveform_window_secs = 3.0;
        peak_decay_db_per_sec = 6.0;
        waveform_gain = 10.0;
      };
      whisper = {
        language = "en";
        translate = false;
        on_demand_loading = modelName != "large-v3";
      };
    };
  };

  home.packages = [ pkgs.voxtype-osd-gtk4 ];

  systemd.user.services.voxtype.Service.Environment = "PATH=${
    lib.makeBinPath [
      config.programs.voxtype.package
      pkgs.voxtype-osd-gtk4
    ]
  }";

  wayland.windowManager.hyprland = lib.mkIf config.wayland.windowManager.hyprland.enable {
    settings.bind = [
      "$mod, V, exec, ${lib.getExe config.programs.voxtype.package} record toggle"
    ];
  };
}
