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
    cider
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
    opera
    pavucontrol
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
    wavebox
    zoom-us
  ];
}
