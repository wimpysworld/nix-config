{ config, desktop, lib, pkgs, username, ... }:
let
  isWorkstation = if (desktop != null) then true else false;
  stable-packages = with pkgs;  [
    _1password
    lastpass-cli
  ] ++ lib.optionals (isWorkstation) [
    _1password-gui
    authy
    gimp-with-plugins
    irccloud
    inkscape
    libreoffice
    tenacity
    wavebox
    zoom-us
  ];

  # For fast moving apps; use the unstable branch
  unstable-packages = with pkgs.unstable; lib.optionals (isWorkstation) [
    brave
    google-chrome
    microsoft-edge
    opera
    telegram-desktop
    vivaldi
    vivaldi-ffmpeg-codecs
  ];
in
{
  imports = lib.optionals (isWorkstation) [
    ../../desktop/games.nix
    ../../desktop/obs-studio.nix
  ];

  environment.systemPackages = stable-packages ++ unstable-packages;

  programs = {
    chromium = lib.mkIf (isWorkstation) {
      extensions = [
        "hdokiejnpimakedhajhdlcegeplioahd" # LastPass
        "kbfnbcaeplbcioakkpcpgfkobkghlhen" # Grammarly
        "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
        "mdjildafknihdffpkfmmpnpoiajfjnjd" # Consent-O-Matic
        "mnjggcdmjocbbbhaepdhchncahnbgone" # SponsorBlock for YouTube
        "gebbhagfogifgggkldgodflihgfeippi" # Return YouTube Dislike
        "fdpohaocaechififmbbbbbknoalclacl" # GoFullPage
        "clpapnmmlmecieknddelobgikompchkk" # Disable Automatic Gain Control
      ];
    };
  };

  users.users.martin = {
    description = "Martin Wimpress";
    # mkpasswd -m sha-512
    hashedPassword = "$6$UXNQ20Feu82wCFK9$dnJTeSqoECw1CGMSUdxKREtraO.Nllv3/fW9N3m7lPHYxFKA/Cf8YqYGDmiWNfaKeyx2DKdURo0rPYBrSZRL./";
  };

  systemd.tmpfiles.rules = [
    "d /mnt/snapshot/${username} 0755 ${username} users"
  ];
}
