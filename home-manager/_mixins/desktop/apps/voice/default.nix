{
  catppuccinPalette,
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  palette = catppuccinPalette;
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
        position = "bottom-center";
        top_margin = 0.72;
        width_px = 720;
        height_px = 120;
        margin_px = 64;
        waveform_gain = 2.0;
      };
      whisper = {
        language = "en";
        translate = false;
        on_demand_loading = modelName != "large-v3";
      };
    };
  };

  home.packages = [ pkgs.voxtype-osd-gtk4 ];

  # The voxtype GTK4 OSD paints with Cairo and is not GTK-CSS themeable.
  # It reads colours only from this Omarchy theme file, so map the six keys
  # it parses to the Catppuccin Mocha palette to match the desktop shell.
  xdg.configFile."omarchy/current/theme/colors.toml".text = ''
    background = "${palette.getColor "base"}"
    foreground = "${palette.getColor "text"}"
    accent     = "${palette.getColor "blue"}"
    color1     = "${palette.getColor "red"}"
    color2     = "${palette.getColor "green"}"
    color3     = "${palette.getColor "yellow"}"
  '';

  wayland.windowManager.hyprland = lib.mkIf config.wayland.windowManager.hyprland.enable {
    # Laptops toggle voice with Super+V; desktops use the Pause/Break key.
    # Bind the Pause key by keycode (xkb 127 = evdev KEY_PAUSE 119 + 8) because
    # Hyprland does not reliably match the Pause keysym by name.
    settings.bind = [
      (
        if host.is.laptop then
          "$mod, V, exec, ${lib.getExe config.programs.voxtype.package} record toggle"
        else
          ", code:127, exec, ${lib.getExe config.programs.voxtype.package} record toggle"
      )
    ];
  };
}
