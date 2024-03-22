{ config, desktop, hostname, inputs, lib, pkgs, platform, username, ... }:
let
  isWorkstation = if (desktop != null) then true else false;
  isStreamstation = if (hostname == "phasma" || hostname == "vader") && (isWorkstation) then true else false;
in
{
  boot = lib.mkIf (isStreamstation) {
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
    extraModprobeConfig = ''
      options v4l2loopback devices=1 video_nr=13 card_label="OBS Virtual Camera" exclusive_caps=1
    '';
  };

  environment = {
    # Desktop environment applications/features I don't use or want
    gnome.excludePackages = with pkgs; [
      baobab
      gnome-console
      gnome-text-editor
      gnome.epiphany
      gnome.geary
      gnome.gnome-music
      gnome.gnome-system-monitor
      gnome.totem
    ];

    mate.excludePackages = with pkgs; [
      mate.caja-dropbox
      mate.eom
      mate.mate-themes
      mate.mate-netbook
      mate.mate-icon-theme
      mate.mate-backgrounds
      mate.mate-icon-theme-faenza
    ];

    pantheon.excludePackages = with pkgs; [
      pantheon.elementary-code
      pantheon.elementary-music
      pantheon.elementary-photos
      pantheon.elementary-videos
      pantheon.epiphany
    ];

    systemPackages = (with pkgs; [
      _1password
      lastpass-cli
    ] ++ lib.optionals (isWorkstation) [
      _1password-gui
      authy
      brave
      chromium
      celluloid
      gimp-with-plugins
      gnome.dconf-editor
      gnome.gnome-sound-recorder
      google-chrome
      halloy
      inkscape
      libreoffice
      meld
      microsoft-edge
      opera
      tenacity
      usbimager
      vivaldi
      vivaldi-ffmpeg-codecs
      wavebox
      yaru-theme
      zoom-us
    ] ++ lib.optionals (isWorkstation && (desktop == "gnome" || desktop == "pantheon")) [
      loupe
      marker
    ] ++ lib.optionals (isWorkstation && (desktop == "mate" || desktop == "pantheon")) [
      tilix
    ] ++ lib.optionals (isWorkstation && desktop == "gnome") [
      blackbox-terminal
      gnome-extension-manager
      gnomeExtensions.start-overlay-in-application-view
      gnomeExtensions.tiling-assistant
      gnomeExtensions.vitals
    ]) ++ (with pkgs.unstable; lib.optionals (isWorkstation) [
      fractal
      pika-backup
      telegram-desktop
    ]) ++ (with inputs; lib.optionals (isWorkstation) [
      antsy-alien-attack-pico.packages.${platform}.default
    ]) ++ (with pkgs; lib.optionals (isStreamstation) [
      # https://nixos.wiki/wiki/OBS_Studio
      blackbox-terminal
      rhythmbox
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
          obs-webkitgtk
          obs-websocket
          pixel-art
          waveform
        ];
      })
    ]);
  };

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
    dconf.profiles.user.databases = [{
      settings = with lib.gvariant; lib.mkIf (isWorkstation) {
      };
    }];
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
