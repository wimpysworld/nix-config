{ config, desktop, hostname, lib, pkgs, username, ... }:
let
  isWorkstation = if (desktop != null) then true else false;
  isStreamstation = if (hostname == "phasma" || hostname == "vader") && (isWorkstation) then true else false;
in
{
  imports = lib.optional (builtins.pathExists (./. + "/${username}.nix")) ./${username}.nix;

  boot = lib.mkIf (isStreamstation) {
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
    extraModprobeConfig = ''
      options v4l2loopback devices=1 video_nr=13 card_label="OBS Virtual Camera" exclusive_caps=1
    '';
  };

  environment = lib.mkIf (isStreamstation) {
    systemPackages = with pkgs; [
      # https://nixos.wiki/wiki/OBS_Studio
      rhythmbox
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
