{
  config,
  hostname,
  lib,
  pkgs,
  ...
}:
let
  installOn = [
    "phasma"
    "vader"
  ];
in
lib.mkIf (lib.elem hostname installOn) {
  environment = {
    systemPackages = with pkgs; [
      # https://nixos.wiki/wiki/OBS_Studio
      (wrapOBS {
        plugins = [
          obs-studio-plugins.advanced-scene-switcher
          obs-studio-plugins.obs-3d-effect
          obs-studio-plugins.obs-advanced-masks
          obs-studio-plugins.obs-command-source
          obs-studio-plugins.obs-composite-blur
          obs-studio-plugins.obs-dvd-screensaver
          obs-studio-plugins.obs-freeze-filter
          obs-studio-plugins.obs-gradient-source
          obs-studio-plugins.obs-gstreamer
          obs-studio-plugins.obs-markdown
          obs-studio-plugins.obs-move-transition
          obs-studio-plugins.obs-multi-rtmp
          obs-studio-plugins.obs-pipewire-audio-capture
          obs-studio-plugins.obs-rgb-levels
          obs-studio-plugins.obs-scale-to-sound
          obs-studio-plugins.obs-scene-as-transition
          obs-studio-plugins.obs-shaderfilter
          obs-studio-plugins.obs-source-clone
          obs-studio-plugins.obs-source-record
          obs-studio-plugins.obs-source-switcher
          obs-studio-plugins.obs-stroke-glow-shadow
          obs-studio-plugins.obs-teleport
          obs-studio-plugins.obs-text-pthread
          obs-studio-plugins.obs-transition-table
          obs-studio-plugins.obs-urlsource
          obs-studio-plugins.obs-vaapi
          obs-studio-plugins.obs-vertical-canvas
          obs-studio-plugins.obs-vintage-filter
          obs-studio-plugins.obs-webkitgtk
          obs-studio-plugins.obs-websocket
          obs-studio-plugins.pixel-art
          obs-studio-plugins.waveform
        ];
      })
    ];
  };
}
