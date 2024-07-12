{
  hostname,
  lib,
  pkgs,
  ...
}:
let
  homeDirectory = builtins.getEnv "HOME";
  installOn = [
    "phasma"
    "vader"
  ];
in
lib.mkIf (lib.elem hostname installOn) {
  environment = {
    systemPackages = with pkgs; [ rhythmbox ];
  };

  programs = {
    dconf.profiles.user.databases = [
      {
        settings = with lib.gvariant; {
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
            locations = [ "file://${homeDirectory}/Studio/Music" ];
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
    ];
  };
}
