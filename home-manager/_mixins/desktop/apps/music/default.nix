{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  hasOBS = config.programs.obs-studio.enable;
  host = config.noughty.host;
in
lib.mkIf (noughtyLib.isUser [ "martin" ]) {

  dconf.settings =
    with lib.hm.gvariant;
    lib.mkIf hasOBS {
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

  home.packages =
    with pkgs;
    lib.optionals host.is.linux [
      cider
    ]
    ++ lib.optionals hasOBS [
      rhythmbox # Music player for streaming
    ];
}
