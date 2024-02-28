{ config, desktop, hostname, inputs, lib, pkgs, platform, username, ... }:
let
  isWorkstation = if (desktop != null) then true else false;
  # https://nixos.wiki/wiki/OBS_Studio
  isStreamstation = if (hostname == "phasma" || hostname == "vader") && (isWorkstation) then true else false;
in
{
  boot = lib.mkIf (isStreamstation) {
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
    extraModprobeConfig = ''
      options v4l2loopback devices=1 video_nr=13 card_label="OBS Virtual Camera" exclusive_caps=1
    '';
  };

  environment.systemPackages = (with pkgs; [
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
  ]) ++ (with pkgs.unstable; lib.optionals (isWorkstation) [
    brave
    chromium
    google-chrome
    microsoft-edge
    opera
    telegram-desktop
    vivaldi
    vivaldi-ffmpeg-codecs
  ]) ++ (with inputs; lib.optionals (isWorkstation) [
    antsy-alien-attack-pico.packages.${platform}.default
  ]) ++ (with pkgs; lib.optionals (isStreamstation) [
    (wrapOBS {
      plugins = with obs-studio-plugins; [
        advanced-scene-switcher
        obs-3d-effect
        obs-advanced-masks
        obs-command-source
        obs-composite-blur
        obs-dvd-screensaver
        obs-freeze-filter
        obs-gradient-source
        obs-gstreamer
        obs-markdown
        obs-move-transition
        obs-multi-rtmp
        obs-pipewire-audio-capture
        obs-rgb-levels
        obs-scale-to-sound
        obs-scene-as-transition
        obs-shaderfilter
        obs-source-clone
        obs-source-record
        obs-source-switcher
        obs-stroke-glow-shadow
        obs-teleport
        obs-text-pthread
        obs-transition-table
        obs-urlsource
        obs-vaapi
        obs-vertical-canvas
        obs-vintage-filter
        obs-websocket
        pixel-art
        waveform
      ];
    })
  ]);

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
