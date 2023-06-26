{ pkgs, ... }: {
  environment.systemPackages = with pkgs.unstable; [
    obs-studio
    obs-studio-plugins.obs-3d-effect
    obs-studio-plugins.obs-command-source
    obs-studio-plugins.obs-gradient-source
    obs-studio-plugins.obs-gstreamer
    obs-studio-plugins.obs-nvfbc
    obs-studio-plugins.obs-move-transition
    obs-studio-plugins.obs-mute-filter
    obs-studio-plugins.obs-pipewire-audio-capture
    #obs-studio-plugins.obs-rgb-levels-filter
    obs-studio-plugins.obs-text-pthread
    obs-studio-plugins.obs-scale-to-sound
    obs-studio-plugins.advanced-scene-switcher
    obs-studio-plugins.obs-shaderfilter
    obs-studio-plugins.obs-source-clone
    obs-studio-plugins.obs-source-record
    obs-studio-plugins.obs-source-switcher
    obs-studio-plugins.obs-transition-table
    obs-studio-plugins.obs-vaapi
    obs-studio-plugins.obs-vintage-filter
    obs-studio-plugins.obs-websocket
  ];
}
