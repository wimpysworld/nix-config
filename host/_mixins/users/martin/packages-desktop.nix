{ pkgs, ... }: {
  # Desktop application momentum follows the unstable channel.
  programs = {
    firefox = {
      enable = true;
      package = pkgs.unstable.firefox;
    };
  };

  environment.systemPackages = with pkgs.unstable; [
    authy
    brave
    discord
    gimp-with-plugins
    gitkraken
    gnome.dconf-editor
    inkscape
    libreoffice
    maestral-gui
    meld
    microsoft-edge
    netflix
    obs-studio
    obs-studio-plugins.obs-vaapi
    obs-studio-plugins.obs-nvfbc
    obs-studio-plugins.obs-gstreamer
    obs-studio-plugins.obs-source-record
    obs-studio-plugins.obs-move-transition
    obs-studio-plugins.obs-pipewire-audio-capture
    opera
    pavucontrol
    pods
    tdesktop
    shotcut
    slack
    spotify
    ungoogled-chromium
    unigine-heaven
    unigine-superposition
    vivaldi
    vivaldi-ffmpeg-codecs
    vscode-fhs
    zoom-us
  ];
}
