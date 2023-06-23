{ pkgs, ... }: {
  # OBS Studio follows the unstable channel.
  programs.obs-studio.enable = true;
  programs.obs-studio.plugins = with pkgs.unstable; [
    obs-studio-plugins.obs-gstreamer
    obs-studio-plugins.obs-nvfbc
    obs-studio-plugins.obs-move-transition
    obs-studio-plugins.obs-pipewire-audio-capture
    obs-studio-plugins.obs-source-record
    obs-studio-plugins.obs-vaapi
    obs-studio-plugins.obs-websocket
  ];
}
