{ pkgs, ... }: {
  # https://nixos.wiki/wiki/OBS_Studio
  environment.systemPackages = [
    pkgs.unstable.obs-studio
    (pkgs.wrapOBS {
      plugins = with pkgs.unstable.obs-studio-plugins; [
        obs-3d-effect
        obs-command-source
        obs-gradient-source
        obs-gstreamer
        obs-nvfbc
        obs-move-transition
        obs-mute-filter
        obs-pipewire-audio-capture
        #obs-rgb-levels-filter
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
      ];
    })
  ];
}
