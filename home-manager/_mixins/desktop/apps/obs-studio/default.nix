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
  themes = pkgs.lib.cleanSource ./themes;
in
lib.mkIf (lib.elem hostname installOn) {
  # Deckmaster and the utilities I bind to the Stream Deck
  home = {
    file = {
      "/Studio/OBS/config/obs-studio/.keep".text = "";
      "${config.xdg.configHome}/obs-studio/themes" = {
        source = themes;
        recursive = true;
      };
    };
    packages = with pkgs; [
      obs-cli
      obs-cmd
    ];
  };

  # Linux specific configuration
  systemd.user.tmpfiles = {
    rules = [
      "L+ ${config.home.homeDirectory}/.config/obs-studio/ - - - - ${config.home.homeDirectory}/Studio/OBS/config/obs-studio/"
    ];
  };
}
