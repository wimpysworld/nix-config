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
      obs-3d-effect
      obs-command-source
      obs-composite-blur
      obs-gradient-source
      obs-gstreamer
      obs-move-transition
      obs-pipewire-audio-capture
      obs-shaderfilter
      obs-source-record
      obs-source-switcher
      obs-teleport
      obs-text-pthread
      obs-vaapi
      obs-vintage-filter
      obs-websocket
      waveform
    ] ++ [
      pkgs.local-obs.obs-advanced-masks
      # FTBFS - Needs a find_qt patch
      # https://github.com/sorayuki/obs-multi-rtmp/commit/a1289fdef404b08a7acbbf0d6d0f93da4c9fc087.patch
      #pkgs.local-obs.obs-aitum-multistream     #FTBFS
      pkgs.local-obs.obs-dvd-screensaver
      pkgs.local-obs.obs-markdown
      pkgs.local-obs.obs-rgb-levels
      pkgs.local-obs.obs-scale-to-sound
      pkgs.local-obs.obs-scene-as-transition
      pkgs.local-obs.obs-source-clone
      pkgs.local-obs.obs-stroke-glow-shadow
      pkgs.local-obs.obs-transition-table
      #pkgs.local-obs.obs-urlsource             #FTBFS
      pkgs.local-obs.obs-vertical-canvas
      pkgs.local-obs.obs-webkitgtk
      pkgs.local-obs.pixel-art
    ];
  };

  # Linux specific configuration
  systemd.user.tmpfiles = {
    rules = [
      "L+ ${config.home.homeDirectory}/.config/obs-studio/ - - - - ${config.home.homeDirectory}/Studio/OBS/config/obs-studio/"
    ];
  };
}
