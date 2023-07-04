{ pkgs, ... }: {
  imports = [
    ../../desktop/brave.nix
    #../../desktop/firefox.nix
    #../../desktop/evolution.nix
    ../../desktop/google-chrome.nix
    ../../desktop/microsoft-edge.nix
    ../../desktop/obs-studio.nix
    ../../desktop/opera.nix
    ../../desktop/tilix.nix
    ../../desktop/vivaldi.nix
  ];

  environment.systemPackages = with pkgs; [
    audio-recorder
    authy
    chatterino2
    cider
    gimp-with-plugins
    gnome.gnome-clocks
    gnome.dconf-editor
    gnome.gnome-sound-recorder
    irccloud
    inkscape
    keybase-gui
    libreoffice
    maestral-gui
    meld
    netflix
    pavucontrol
    pick-colour-picker
    rhythmbox
    shotcut
    slack
    zoom-us

    # Fast moving apps use the unstable branch
    unstable.discord
    unstable.fluffychat
    unstable.gitkraken
    unstable.tdesktop
    unstable.vscode-fhs
    unstable.wavebox
  ];

  programs = {
    chromium = {
      extensions = [
        "kbfnbcaeplbcioakkpcpgfkobkghlhen" # Grammarly
        "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
        "mdjildafknihdffpkfmmpnpoiajfjnjd" # Consent-O-Matic
        "mnjggcdmjocbbbhaepdhchncahnbgone" # SponsorBlock for YouTube
        "gebbhagfogifgggkldgodflihgfeippi" # Return YouTube Dislike
        "edlifbnjlicfpckhgjhflgkeeibhhcii" # Screenshot Tool
      ];
    };
  };
}
