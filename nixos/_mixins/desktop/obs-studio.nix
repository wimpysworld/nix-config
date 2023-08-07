{ config, pkgs, ... }: {
  # https://nixos.wiki/wiki/OBS_Studio
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=13 card_label="OBS Virtual Camera" exclusive_caps=1
  '';

  environment.systemPackages = [
    pkgs.bc
    pkgs.google-fonts
    pkgs.libnotify
    (pkgs.unstable.wrapOBS {
      plugins = with pkgs.unstable.obs-studio-plugins; [
        obs-3d-effect
        obs-command-source
        obs-gradient-source
        obs-gstreamer
        obs-nvfbc
        obs-move-transition
        obs-mute-filter
        obs-pipewire-audio-capture
        obs-rgb-levels-filter
        obs-text-pthread
        obs-scale-to-sound
        advanced-scene-switcher
        obs-shaderfilter
        obs-source-clone
        obs-source-record
        obs-source-switcher
        obs-transition-table
        obs-vaapi
        obs-vintage-filter
        obs-websocket
        waveform
      ];
    })
  ];
}
