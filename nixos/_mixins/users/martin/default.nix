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
    dconf.profiles.user.databases = [{
      settings = with lib.gvariant; {
        "org/gnome/desktop/input-sources" = lib.mkIf (isWorkstation) {
          xkb-options = [ "grp:alt_shift_toggle" "caps:none" ];
        };

        "org/gnome/desktop/wm/preferences" = lib.mkIf (desktop == "gnome") {
          num-workspaces = mkInt32 8;
          workspace-names = [ "Web" "Work" "Chat" "Code" "Virt" "Cast" "Fun" "Stuff" ];
        };

        "org/gnome/shell" = lib.mkIf (desktop == "gnome") {
          disabled-extensions = mkEmptyArray type.string;
        };

        "org/gnome/shell/extensions/auto-move-windows" = lib.mkIf (desktop == "gnome") {
          application-list = [ "brave-browser.desktop:1" "Wavebox.desktop:2" "discord.desktop:2" "org.telegram.desktop.desktop:3" "nheko.desktop:3" "code.desktop:4" "GitKraken.desktop:4" "com.obsproject.Studio.desktop:6" ];
        };

        "org/gnome/shell/extensions/tiling-assistant" = lib.mkIf (desktop == "gnome") {
          show-layout-panel-indicator = true;
        };
      };
    }];
  };

  users.users.martin = {
    description = "Martin Wimpress";
    # mkpasswd -m sha-512
    hashedPassword = "$6$UXNQ20Feu82wCFK9$dnJTeSqoECw1CGMSUdxKREtraO.Nllv3/fW9N3m7lPHYxFKA/Cf8YqYGDmiWNfaKeyx2DKdURo0rPYBrSZRL./";
  };

  services.xserver.desktopManager.gnome = lib.mkIf (desktop == "gnome") {
    favoriteAppsOverride = lib.mkForce ''
      [org.gnome.shell]
      favorite-apps=[ 'brave-browser.desktop', 'authy.desktop', 'Wavebox.desktop', 'org.telegram.desktop.desktop', 'discord.desktop', 'nheko.desktop', 'code.desktop', 'GitKraken.desktop', 'com.obsproject.Studio.desktop' ]
    '';
  };

  systemd.tmpfiles.rules = [
    "d /mnt/snapshot/${username} 0755 ${username} users"
  ];
}
