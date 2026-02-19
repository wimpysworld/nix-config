{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  host = config.noughty.host;
in
lib.mkIf
  (noughtyLib.isHost [
    "phasma"
    "vader"
  ])
  {

    catppuccin = {
      obs.enable = config.programs.obs-studio.enable;
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
          obs-aitum-multistream
          obs-command-source
          obs-composite-blur
          obs-dvd-screensaver
          obs-gradient-source
          obs-gstreamer
          obs-markdown
          obs-move-transition
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
          obs-transition-table
          obs-text-pthread
          obs-vaapi
          obs-vintage-filter
          obs-websocket
          pixel-art
          waveform
        ]
        ++ [
          pkgs.obs-urlsource
          pkgs.obs-vertical-canvas
          pkgs.obs-webkitgtk
        ];
    };

    # Linux specific configuration
    systemd.user.tmpfiles = lib.mkIf host.is.linux {
      rules = [
        "L+ ${config.home.homeDirectory}/.config/obs-studio/ - - - - ${config.home.homeDirectory}/Studio/OBS/config/obs-studio/"
      ];
    };

  }
