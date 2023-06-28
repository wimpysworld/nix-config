{ lib, pkgs, ... }: {
  environment.systemPackages = with pkgs.unstable; [
    brave
    google-chrome
    microsoft-edge
    netflix
    opera
    vivaldi
    vivaldi-ffmpeg-codecs
    wavebox
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
