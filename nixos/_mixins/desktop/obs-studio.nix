{ config, pkgs, ... }: {
  # https://nixos.wiki/wiki/OBS_Studio
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=13 card_label="OBS Virtual Camera" exclusive_caps=1
  '';

  environment.systemPackages = with pkgs; [
    (wrapOBS {
      plugins = with obs-studio-plugins; [
        advanced-scene-switcher
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
        obs-multi-rtmp
        obs-pipewire-audio-capture
        obs-rgb-levels
        obs-scale-to-sound
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
        obs-websocket
        pixel-art
        waveform
      ];
    })
  ];
}
