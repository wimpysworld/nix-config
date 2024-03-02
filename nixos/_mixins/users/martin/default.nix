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

  environment.systemPackages = (with pkgs; [
    _1password
    lastpass-cli
  ] ++ lib.optionals (isWorkstation) [
    _1password-gui
    authy
    celluloid
    gimp-with-plugins
    gnome.dconf-editor
    halloy
    inkscape
    libreoffice
    tenacity
    tilix
    wavebox
    zoom-us
  ]) ++ (with pkgs.unstable; lib.optionals (isWorkstation) [
    brave
    chromium
    fractal
    google-chrome
    microsoft-edge
    opera
    telegram-desktop
    vivaldi
    vivaldi-ffmpeg-codecs
  ]) ++ (with inputs; lib.optionals (isWorkstation) [
    antsy-alien-attack-pico.packages.${platform}.default
  ]) ++ (with pkgs; lib.optionals (isStreamstation) [
    # https://nixos.wiki/wiki/OBS_Studio
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
      settings = with lib.gvariant; lib.mkIf (isWorkstation) {
        "io/elementary/terminal/settings" = {
          unsafe-paste-alert = false;
        };

        "net/launchpad/plank/docks/dock1" = {
          dock-items = [ "brave-browser.dockitem" "authy.dockitem" "Wavebox.dockitem" "org.telegram.desktop.dockitem" "discord.dockitem" "org.gnome.Fractal.dockitem" "org.squidowl.halloy.dockitem" "code.dockitem" "GitKraken.dockitem" "com.obsproject.Studio.dockitem" ];
        };

        "org/gnome/desktop/input-sources" = {
          xkb-options = [ "grp:alt_shift_toggle" "caps:none" ];
        };

        "org/gnome/desktop/wm/preferences" = {
          num-workspaces = mkInt32 8;
          workspace-names = [ "Web" "Work" "Chat" "Code" "Virt" "Cast" "Fun" "Stuff" ];
        };

        "org/gnome/shell" = {
          disabled-extensions = mkEmptyArray type.string;
          favorite-apps = [ "brave-browser.desktop" "authy.desktop" "Wavebox.desktop" "org.telegram.desktop.desktop" "discord.desktop" "org.gnome.Fractal.desktop" "org.squidowl.halloy.desktop" "code.desktop" "GitKraken.desktop" "com.obsproject.Studio.desktop" ];
        };

        "org/gnome/shell/extensions/auto-move-windows" = {
          application-list = [ "brave-browser.desktop:1" "Wavebox.desktop:2" "discord.desktop:2" "org.telegram.desktop.desktop:3" "nheko.desktop:3" "code.desktop:4" "GitKraken.desktop:4" "com.obsproject.Studio.desktop:6" ];
        };

        "org/gnome/shell/extensions/tiling-assistant" = {
          show-layout-panel-indicator = true;
        };

        "org/mate/desktop/peripherals/keyboard/kbd" = {
          options = [ "terminate\tterminate:ctrl_alt_bksp" "caps\tcaps:none" ];
        };

        "org/mate/marco/general" = {
          num-workspaces = mkInt32 8;
        };

        "org/mate/marco/workspace-names" = {
          name-1 = " Web ";
          name-2 = " Work ";
          name-3 = " Chat ";
          name-4 = " Code ";
          name-5 = " Virt ";
          name-6 = " Cast ";
          name-7 = " Fun ";
          name-8 = " Stuff ";
        };
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
