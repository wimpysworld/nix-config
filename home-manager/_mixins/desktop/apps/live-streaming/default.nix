{
  config,
  hostname,
  lib,
  pkgs,
  ...
}:
let
  installOn = [
    "phasma"
    "vader"
  ];
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf (lib.elem hostname installOn) {

  catppuccin = {
    obs.enable = config.programs.obs-studio.enable;
  };

  dconf.settings = with lib.hm.gvariant; {
    "org/gnome/rhythmbox/plugins" = {
      active-plugins = [
        "rb"
        "power-manager"
        "mpris"
        "iradio"
        "generic-player"
        "audiocd"
        "android"
      ];
    };

    "org/gnome/rhythmbox/podcast" = {
      download-interval = "manual";
    };

    "org/gnome/rhythmbox/rhythmdb" = {
      locations = [ "file://${config.home.homeDirectory}/Studio/Music" ];
      monitor-library = true;
    };

    "org/gnome/rhythmbox/sources" = {
      browser-views = "genres-artists-albums";
      visible-columns = [
        "post-time"
        "duration"
        "track-number"
        "album"
        "genre"
        "beats-per-minute"
        "play-count"
        "artist"
      ];
    };
  };

  home = {
    file = {
      "/Studio/OBS/config/obs-studio/.keep".text = "";
      "${config.home.homeDirectory}/.local/share/chatterino/Themes/mocha-blue.json".text =
        builtins.readFile ./chatterino-mocha-blue.json;
    };
    packages = with pkgs; [
      chatterino2
      obs-cli
      obs-cmd
      rhythmbox
    ];
  };

  programs.obs-studio = {
    enable = true;
    plugins =
      with pkgs.obs-studio-plugins;
      [
        advanced-scene-switcher
        obs-3d-effect
        obs-advanced-masks
        obs-command-source
        obs-composite-blur
        obs-gradient-source
        obs-gstreamer
        obs-move-transition
        obs-pipewire-audio-capture
        obs-scale-to-sound
        obs-shaderfilter
        obs-source-clone
        obs-source-record
        obs-source-switcher
        obs-teleport
        obs-transition-table
        obs-text-pthread
        obs-vaapi
        obs-vintage-filter
        obs-webkitgtk
        obs-websocket
        waveform
      ]
      ++ [
        pkgs.obs-aitum-multistream
        pkgs.obs-dvd-screensaver
        pkgs.obs-markdown
        pkgs.obs-rgb-levels
        pkgs.obs-scene-as-transition
        pkgs.obs-stroke-glow-shadow
        pkgs.obs-urlsource
        pkgs.obs-vertical-canvas
        pkgs.pixel-art
      ];
  };

  # Linux specific configuration
  systemd.user.tmpfiles = lib.mkIf isLinux {
    rules = [
      "L+ ${config.home.homeDirectory}/.config/obs-studio/ - - - - ${config.home.homeDirectory}/Studio/OBS/config/obs-studio/"
    ];
  };

}
