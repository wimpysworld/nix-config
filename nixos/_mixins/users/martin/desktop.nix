{ pkgs, ... }: {
  imports = [
    ../../desktop/brave.nix
    #../../desktop/firefox.nix
    #../../desktop/evolution.nix
    ../../desktop/google-chrome.nix
    ../../desktop/microsoft-edge.nix
    ../../desktop/obs-studio.nix
    ../../desktop/opera.nix
    ../../desktop/quickemu.nix
    ../../desktop/tilix.nix
    ../../desktop/vivaldi.nix
  ];

  environment.systemPackages = with pkgs; [
    authy
    cider
    gimp-with-plugins
    gnome.dconf-editor
    inkscape
    libreoffice
    maestral-gui
    meld
    netflix
    pavucontrol
    rhythmbox
    shotcut
    slack

    # Fast moving apps use the unstable branch
    unstable.discord
    unstable.gitkraken
    unstable.tdesktop
    unstable.vscode-fhs
    unstable.wavebox
    unstable.zoom-us
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
