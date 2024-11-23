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
      pkgs.local-plugins.obs-advanced-masks
      # FTBFS - Needs a find_qt patch
      # https://github.com/sorayuki/obs-multi-rtmp/commit/a1289fdef404b08a7acbbf0d6d0f93da4c9fc087.patch
      #pkgs.local-plugins.obs-aitum-multistream     #FTBFS
      pkgs.local-plugins.obs-dvd-screensaver
      pkgs.local-plugins.obs-markdown
      pkgs.local-plugins.obs-rgb-levels
      pkgs.local-plugins.obs-scale-to-sound
      pkgs.local-plugins.obs-scene-as-transition
      pkgs.local-plugins.obs-source-clone
      pkgs.local-plugins.obs-stroke-glow-shadow
      pkgs.local-plugins.obs-transition-table
      #pkgs.local-plugins.obs-urlsource             #FTBFS
      pkgs.local-plugins.obs-vertical-canvas
      pkgs.local-plugins.obs-webkitgtk
      pkgs.local-plugins.pixel-art
    ];
  };

  # Linux specific configuration
  systemd.user.tmpfiles = {
    rules = [
      "L+ ${config.home.homeDirectory}/.config/obs-studio/ - - - - ${config.home.homeDirectory}/Studio/OBS/config/obs-studio/"
    ];
  };
}
