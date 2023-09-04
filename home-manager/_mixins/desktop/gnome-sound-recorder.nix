{ config, lib, pkgs, username, ... }:
with lib.hm.gvariant;
{
  home.packages = with pkgs; [
    gnome.gnome-sound-recorder
  ];
  
  dconf.settings = {
    "org/gnome/SoundRecorder" = {
      audio-channel = "mono";
      audio-profile = "flac";
    };
  };

  systemd.user.tmpfiles.rules = [
    "d ${config.home.homeDirectory}/Audio 0755 ${username} users - -"
    "L+ ${config.home.homeDirectory}/.local/share/org.gnome.SoundRecorder/ - - - - ${config.home.homeDirectory}/Audio/"
  ];
}
