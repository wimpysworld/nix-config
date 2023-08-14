{ desktop, pkgs, lib, ... }: {
  imports = [
    ../../desktop/brave.nix
    ../../desktop/chromium.nix
    #../../desktop/firefox.nix
    #../../desktop/evolution.nix
    ../../desktop/google-chrome.nix
    ../../desktop/microsoft-edge.nix
    ../../desktop/obs-studio.nix
    ../../desktop/opera.nix
    ../../desktop/tilix.nix
    ../../desktop/vivaldi.nix
    ../../desktop/vscode.nix
  ] ++ lib.optional (builtins.pathExists (../.. + "/desktop/${desktop}-apps.nix")) ../../desktop/${desktop}-apps.nix;

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
    libreoffice
    meld
    netflix
    pick-colour-picker
    rhythmbox
    slack
    zoom-us

    # Fast moving apps use the unstable branch
    unstable.discord
    unstable.fluffychat
    unstable.gitkraken
    unstable.tdesktop
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
