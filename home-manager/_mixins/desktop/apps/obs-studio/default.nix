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
  inherit (pkgs.stdenv) isLinux;
  themes = pkgs.lib.cleanSource ./themes;
in
lib.mkIf (lib.elem hostname installOn) {
  home = {
    file = {
      "/Studio/OBS/config/obs-studio/.keep".text = "";
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
      pkgs.obs-advanced-masks
      pkgs.obs-aitum-multistream
      pkgs.obs-dvd-screensaver
      pkgs.obs-markdown
      pkgs.obs-rgb-levels
      pkgs.obs-scale-to-sound
      pkgs.obs-scene-as-transition
      pkgs.obs-source-clone
      pkgs.obs-stroke-glow-shadow
      pkgs.obs-transition-table
      pkgs.obs-urlsource
      pkgs.obs-vertical-canvas
      pkgs.obs-webkitgtk
      pkgs.pixel-art
    ];
  };

  # Linux specific configuration
  systemd.user.tmpfiles = lib.mkIf isLinux {
    rules = [
      "L+ ${config.home.homeDirectory}/.config/obs-studio/ - - - - ${config.home.homeDirectory}/Studio/OBS/config/obs-studio/"
    ];
  };
}
