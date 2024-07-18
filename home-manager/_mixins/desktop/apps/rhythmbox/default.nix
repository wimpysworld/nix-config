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
in
lib.mkIf (lib.elem hostname installOn) {
  home = {
    packages = with pkgs; [ rhythmbox ];
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
}
