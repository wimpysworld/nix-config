{
  config,
  hostname,
  inputs,
  lib,
  pkgs,
  platform,
  ...
}:
let
  installOn = [
    "phasma"
    "vader"
  ];
  themes = pkgs.lib.cleanSource ./themes;
in
lib.mkIf (lib.elem hostname installOn) {
  home = {
    file = {
      "/Studio/OBS/config/obs-studio/.keep".text = "";
      "/Studio/OBS/config/obs-studio/themes" = {
        source = themes;
        recursive = true;
      };
    };
    packages = with pkgs; [
      inputs.stream-sprout.packages.${platform}.default
      obs-cli
      obs-cmd
    ];
  };

  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      advanced-scene-switcher
      obs-aitum-multistream
      obs-3d-effect
      obs-advanced-masks
      obs-command-source
      obs-composite-blur
      obs-dvd-screensaver
      obs-freeze-filter
      obs-gradient-source
      obs-gstreamer
      obs-markdown
      obs-move-transition
      obs-pipewire-audio-capture
      obs-rgb-levels
      obs-scale-to-sound
      obs-scene-as-transition
      obs-shaderfilter
      obs-source-clone
      obs-source-record
      obs-source-switcher
      obs-stroke-glow-shadow
      obs-teleport
      obs-text-pthread
      obs-transition-table
      obs-urlsource
      obs-vaapi
      obs-vertical-canvas
      obs-vintage-filter
      obs-webkitgtk
      obs-websocket
      pixel-art
      waveform
    ];
  };

  # Linux specific configuration
  systemd.user.tmpfiles = {
    rules = [
      "L+ ${config.home.homeDirectory}/.config/obs-studio/ - - - - ${config.home.homeDirectory}/Studio/OBS/config/obs-studio/"
    ];
  };
}
