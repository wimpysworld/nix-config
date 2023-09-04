{ lib, pkgs, username, ... }:
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
    "L+ /home/${username}/.local/share/org.gnome.SoundRecorder/ - - - - /home/${username}/Audio/"
  ];
}
