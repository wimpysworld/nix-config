{ lib, username, ... }:
with lib.hm.gvariant;
{
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
