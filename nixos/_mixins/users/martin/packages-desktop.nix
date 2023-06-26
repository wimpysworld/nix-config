{ lib, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    authy
    cider
    gimp-with-plugins
    gnome.dconf-editor
    inkscape
    libreoffice
    maestral-gui
    meld
    pavucontrol
    rhythmbox
    shotcut
    slack
    # Fast moving apps use the unstable branch
    unstable.brave
    unstable.discord
    unstable.gitkraken
    unstable.google-chrome
    unstable.microsoft-edge
    unstable.netflix
    unstable.opera
    unstable.obs-studio
    unstable.obs-studio-plugins.obs-3d-effect
    unstable.obs-studio-plugins.obs-command-source
    unstable.obs-studio-plugins.obs-gradient-source
    unstable.obs-studio-plugins.obs-gstreamer
    unstable.obs-studio-plugins.obs-nvfbc
    unstable.obs-studio-plugins.obs-move-transition
    unstable.obs-studio-plugins.obs-mute-filter
    unstable.obs-studio-plugins.obs-pipewire-audio-capture
    #unstable.obs-studio-plugins.obs-rgb-levels-filter
    unstable.obs-studio-plugins.obs-text-pthread
    unstable.obs-studio-plugins.obs-scale-to-sound
    unstable.obs-studio-plugins.advanced-scene-switcher
    unstable.obs-studio-plugins.obs-shaderfilter
    unstable.obs-studio-plugins.obs-source-clone
    unstable.obs-studio-plugins.obs-source-record
    unstable.obs-studio-plugins.obs-source-switcher
    unstable.obs-studio-plugins.obs-transition-table
    unstable.obs-studio-plugins.obs-vaapi
    unstable.obs-studio-plugins.obs-vintage-filter
    unstable.obs-studio-plugins.obs-websocket
    unstable.tdesktop
    unstable.vivaldi
    unstable.vivaldi-ffmpeg-codecs
    unstable.vscode-fhs
    unstable.wavebox
    unstable.zoom-us
  ];

  programs = {
    chromium = {
      enable = true;
      extensions = [
        "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
        "mdjildafknihdffpkfmmpnpoiajfjnjd" # Consent-O-Matic
        "mnjggcdmjocbbbhaepdhchncahnbgone" # SponsorBlock for YouTube
        "gebbhagfogifgggkldgodflihgfeippi" # Return YouTube Dislike
        "edlifbnjlicfpckhgjhflgkeeibhhcii" # Screenshot Tool
      ];
    };
    firefox = {
      enable = lib.mkDefault true;
      languagePacks = ["en-GB"];
      package = pkgs.unstable.firefox;
    };
  };
}
